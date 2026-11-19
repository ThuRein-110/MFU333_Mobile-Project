const jwt = require("jsonwebtoken");
const userModel = require("../models/userModel");
const verified = Symbol("verifiedCurrentUser");

const verifyToken = async (req, res, next) => {
    // Routers may also use this middleware after the application-level guard.
    if (req[verified]) return next();
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return res.status(401).json({ success: false, message: "Access token is required" });
    }
    let decoded;
    try {
        decoded = jwt.verify(authHeader.split(" ")[1], process.env.JWT_SECRET);
    } catch (_) {
        return res.status(401).json({ success: false, message: "Invalid or expired token" });
    }
    try {
        const user = await userModel.findUserById(decoded.user_id);
        if (!user || Number(user.is_active) !== 1) {
            return res.status(401).json({ success: false, message: "Account is inactive" });
        }
        req.user = {
            user_id: user.user_id, role: user.role, email: user.email,
            full_name: user.full_name, student_code: user.student_code,
            must_change_password: Number(user.must_change_password) === 1
        };
        req[verified] = true;
        return next();
    } catch (_) {
        return res.status(503).json({ success: false, message: "Unable to verify account" });
    }
};

module.exports = { verifyToken };
