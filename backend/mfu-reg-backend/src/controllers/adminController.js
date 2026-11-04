
const adminModel = require("../models/adminModel");
const bcrypt = require("bcrypt");
const userModel = require("../models/userModel");

// Get admin dashboard summary
const getDashboardSummary = async (req, res) => {
    try {
        const summary = await adminModel.getDashboardSummary();

        return res.json({
            success: true,
            message: "Dashboard summary retrieved successfully",
            data: summary
        });

    } catch (error) {
        console.error("Admin Dashboard Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve dashboard summary"
        });
    }
};

// Get all users
const getAllUsers = async (req, res) => {
    try {
        const search = req.query.search || "";
        const role = req.query.role || "";

        const allowedRoles = ["student", "lecturer", "admin"];

        if (role && !allowedRoles.includes(role)) {
            return res.status(400).json({
                success: false,
                message: "Invalid user role"
            });
        }

        const users = await adminModel.getAllUsers(search, role);

        return res.json({
            success: true,
            message: "Users retrieved successfully",
            data: users
        });

    } catch (error) {
        console.error("Get All Users Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve users"
        });
    }
};
// Update user active status
const updateUserStatus = async (req, res) => {
    try {
        const userId = Number(req.params.userId);
        const { is_active } = req.body;

        // Validate user ID
        if (!Number.isInteger(userId) || userId <= 0) {
            return res.status(400).json({
                success: false,
                message: "Invalid user ID"
            });
        }

        // Validate active status
        if (typeof is_active !== "boolean" &&
            ![0, 1].includes(is_active)) {
            return res.status(400).json({
                success: false,
                message: "is_active must be true, false, 1 or 0"
            });
        }

        const activeStatus = Number(is_active);

        // Prevent admin from deactivating own account
        if (userId === req.user.user_id && activeStatus === 0) {
            return res.status(403).json({
                success: false,
                message: "You cannot deactivate your own account"
            });
        }

        const affectedRows = await adminModel.updateUserStatus(
            userId,
            activeStatus
        );

        if (affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: "User not found"
            });
        }

        return res.json({
            success: true,
            message: activeStatus === 1
                ? "User activated successfully"
                : "User deactivated successfully"
        });

    } catch (error) {
        console.error("Update User Status Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to update user status"
        });
    }
};
// Get user details by ID
const getUserById = async (req, res) => {
    try {
        const userId = Number(req.params.userId);

        if (!Number.isInteger(userId) || userId <= 0) {
            return res.status(400).json({
                success: false,
                message: "Invalid user ID"
            });
        }

        const user = await adminModel.getUserById(userId);

        if (!user) {
            return res.status(404).json({
                success: false,
                message: "User not found"
            });
        }

        return res.json({
            success: true,
            message: "User details retrieved successfully",
            data: user
        });

    } catch (error) {
        console.error("Get User Details Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve user details"
        });
    }
};
// Admin creates lecturer account
const createLecturer = async (req, res) => {
    try {
        const { full_name, email, password } = req.body;

        if (!full_name || !email || !password) {
            return res.status(400).json({
                success: false,
                message: "Please fill in all required fields"
            });
        }

        if (password.length < 8) {
            return res.status(400).json({
                success: false,
                message: "Password must be at least 8 characters"
            });
        }

        const existingUser = await userModel.findUserByEmail(email);

        if (existingUser) {
            return res.status(409).json({
                success: false,
                message: "Email already exists"
            });
        }

        const passwordHash = await bcrypt.hash(password, 10);

        const userId = await userModel.createLecturer(
            full_name,
            email,
            passwordHash
        );

        return res.status(201).json({
            success: true,
            message: "Lecturer account created successfully",
            data: {
                user_id: userId,
                full_name,
                email,
                role: "lecturer"
            }
        });

    } catch (error) {
        console.error("Create Lecturer Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to create lecturer account"
        });
    }
};
module.exports = {
    getDashboardSummary,
    getAllUsers,
    updateUserStatus,
    getUserById,
    createLecturer
};