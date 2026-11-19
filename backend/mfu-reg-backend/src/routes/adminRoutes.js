
const express = require("express");
const router = express.Router();

const adminController = require("../controllers/adminController");
const { verifyToken } = require("../middlewares/authMiddleware");
const authorizeRoles = require("../middlewares/roleMiddleware");
const settingsController = require("../controllers/settingsController");

const settingsGuard = [verifyToken, authorizeRoles("admin")];
router.get("/settings", ...settingsGuard, settingsController.getSettings);
router.post("/settings/categories", ...settingsGuard, settingsController.createCategory);
router.patch("/settings/categories/:id", ...settingsGuard, settingsController.updateCategory);
router.post("/settings/zones", ...settingsGuard, settingsController.createZone);
router.patch("/settings/zones/:id", ...settingsGuard, settingsController.updateZone);
router.post("/settings/ips", ...settingsGuard, settingsController.createIp);
router.patch("/settings/ips/:id", ...settingsGuard, settingsController.updateIp);
router.delete("/settings/ips/:id", ...settingsGuard, settingsController.removeIp);

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
