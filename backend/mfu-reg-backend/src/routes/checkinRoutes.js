
const express = require("express");
const router = express.Router();

const checkinController = require("../controllers/checkinController");
const { verifyToken } = require("../middlewares/authMiddleware");
const authorizeRoles = require("../middlewares/roleMiddleware");
const { readQrImage } = require('../controllers/imageController');

// Reading a photo does not record attendance.
router.post('/read-qr', verifyToken, authorizeRoles('student'), readQrImage);

// Student check-in: registration and a valid QR are required on any network.
router.post(
    "/",
    verifyToken,
    authorizeRoles("student"),
    checkinController.createCheckin
);

module.exports = router;
