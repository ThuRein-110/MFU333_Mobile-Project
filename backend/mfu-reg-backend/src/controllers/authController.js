const bcrypt = require("bcrypt");
const userModel = require("../models/userModel");
const jwt = require("jsonwebtoken");

// Register
const register = async (req, res) => {
    try {
        const { student_code, full_name, email, password } = req.body;

        // ตรวจสอบข้อมูลที่ส่งมา
        if (!student_code || !full_name || !email || !password) {
            return res.status(400).json({
                success: false,
                message: "Please fill in all required fields"
            });
        }

        // ตรวจสอบความยาว Password
        if (password.length < 8) {
            return res.status(400).json({
                success: false,
                message: "Password must be at least 8 characters"
            });
        }

        // ตรวจสอบ Email ซ้ำ
        const existingUser = await userModel.findUserByEmail(email);

        if (existingUser) {
            return res.status(409).json({
                success: false,
                message: "Email already exists"
            });
        }

        // เข้ารหัส Password
        const passwordHash = await bcrypt.hash(password, 10);

        // บันทึก User
        const userId = await userModel.createUser(
            student_code,
            full_name,
            email,
            passwordHash
        );

        return res.status(201).json({
            success: true,
            message: "Registration successful",
            data: {
                user_id: userId,
                student_code,
                full_name,
                email,
                role: "student"
            }
        });

    } catch (error) {
        console.error("Register Error:", error);

        return res.status(500).json({
            success: false,
            message: "Internal server error"
        });
    }
};
// Login
const login = async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({
                success: false,
                message: "Email and password are required"
            });
        }

        const user = await userModel.findUserByEmail(email);

        if (!user) {
            return res.status(401).json({
                success: false,
                message: "Invalid email or password"
            });
        }

        if (!user.is_active) {
            return res.status(403).json({
                success: false,
                message: "Account is inactive"
            });
        }

        const isMatch = await bcrypt.compare(
            password,
            user.password_hash
        );

        if (!isMatch) {
            return res.status(401).json({
                success: false,
                message: "Invalid email or password"
            });
        }

       const token = jwt.sign(
    {
        user_id: user.user_id,
        role: user.role,
        must_change_password: Boolean(user.must_change_password)
    },
    process.env.JWT_SECRET,
    { expiresIn: "1d" }
);

        return res.status(200).json({
            success: true,
            message: "Login successful",
            data: {
                token,
               user: {
    user_id: user.user_id,
    full_name: user.full_name,
    email: user.email,
    role: user.role,
    must_change_password: Boolean(user.must_change_password)
}
            }
        });

    } catch (error) {
        console.error("Login Error:", error);

        return res.status(500).json({
            success: false,
            message: "Internal server error"
        });
    }
};
// Change password
const changePassword = async (req, res) => {
    try {
        const { current_password, new_password, confirm_password } = req.body;
        const userId = req.user.user_id;

        if (!current_password || !new_password || !confirm_password) {
            return res.status(400).json({
                success: false,
                message: "Please fill in all required fields"
            });
        }

        if (new_password.length < 8) {
            return res.status(400).json({
                success: false,
                message: "New password must be at least 8 characters"
            });
        }

        if (new_password !== confirm_password) {
            return res.status(400).json({
                success: false,
                message: "New password and confirmation do not match"
            });
        }

        const user = await userModel.findUserById(userId);

        if (!user) {
            return res.status(404).json({
                success: false,
                message: "User not found"
            });
        }

        const isMatch = await bcrypt.compare(
            current_password,
            user.password_hash
        );

        if (!isMatch) {
            return res.status(401).json({
                success: false,
                message: "Current password is incorrect"
            });
        }

        const passwordHash = await bcrypt.hash(new_password, 10);

        await userModel.changePassword(userId, passwordHash);

        return res.json({
            success: true,
            message: "Password changed successfully. Please login again."
        });

    } catch (error) {
        console.error("Change Password Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to change password"
        });
    }
};

module.exports = {
    register,
    login,
    changePassword
};