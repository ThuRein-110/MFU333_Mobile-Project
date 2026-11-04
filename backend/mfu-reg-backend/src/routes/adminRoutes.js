
const express = require("express");
const router = express.Router();

const adminController = require("../controllers/adminController");
const { verifyToken } = require("../middlewares/authMiddleware");
const authorizeRoles = require("../middlewares/roleMiddleware");

// Admin dashboard summary
router.get(
    "/dashboard",
    verifyToken,
    authorizeRoles("admin"),
    adminController.getDashboardSummary
);
// Get all users
router.get(
    "/users",
    verifyToken,
    authorizeRoles("admin"),
    adminController.getAllUsers
);
// Update user active status
router.patch(
    "/users/:userId/status",
    verifyToken,
    authorizeRoles("admin"),
    adminController.updateUserStatus
);
// Get user details by ID
router.get(
    "/users/:userId",
    verifyToken,
    authorizeRoles("admin"),
    adminController.getUserById
);
// Create lecturer account
router.post(
    "/lecturers",
    verifyToken,
    authorizeRoles("admin"),
    adminController.createLecturer
);

module.exports = router;
