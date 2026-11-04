
const express = require("express");
const router = express.Router();

const checkinController = require("../controllers/checkinController");
const { verifyToken } = require("../middlewares/authMiddleware");
const authorizeRoles = require("../middlewares/roleMiddleware");
const { verifyWifi } = require("../middlewares/wifiMiddleware");

// Student check-in (JWT + Wi-Fi)
router.post(
    "/",
    verifyToken,
    authorizeRoles("student"),
    verifyWifi,
    checkinController.createCheckin
);

module.exports = router;
