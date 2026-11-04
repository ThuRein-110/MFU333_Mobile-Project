
const express = require("express");
const router = express.Router();

const lecturerController = require("../controllers/lecturerController");
const { verifyToken } = require("../middlewares/authMiddleware");
const authorizeRoles = require("../middlewares/roleMiddleware");

// Lecturer dashboard
router.get(
    "/dashboard",
    verifyToken,
    authorizeRoles("lecturer"),
    lecturerController.getDashboard
);

// Get students registered in lecturer's activity
router.get(
    "/activities/:activityId/participants",
    verifyToken,
    authorizeRoles("lecturer"),
    lecturerController.getActivityParticipants
);
// Get lecturer's activity details
router.get(
    "/activities/:activityId",
    verifyToken,
    authorizeRoles("lecturer"),
    lecturerController.getMyActivityById
);
// Update lecturer's activity status
router.patch(
    "/activities/:activityId/status",
    verifyToken,
    authorizeRoles("lecturer"),
    lecturerController.updateMyActivityStatus
);
module.exports = router;
