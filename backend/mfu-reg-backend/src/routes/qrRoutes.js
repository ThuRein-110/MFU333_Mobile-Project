
const express = require("express");
const router = express.Router();

const qrController = require("../controllers/qrController");
const { verifyToken } = require("../middlewares/authMiddleware");
const authorizeRoles = require("../middlewares/roleMiddleware");

// Create QR for activity (Lecturer / Admin)
router.post(
    "/:activityId",
    verifyToken,
    authorizeRoles("lecturer", "admin"),
    qrController.createActivityQr
);

module.exports = router;
