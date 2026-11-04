
const express = require("express");
const router = express.Router();

const pointController = require("../controllers/pointController");
const { verifyToken } = require("../middlewares/authMiddleware");
const authorizeRoles = require("../middlewares/roleMiddleware");

// Get my total points (Student only)
router.get(
    "/my",
    verifyToken,
    authorizeRoles("student"),
    pointController.getMyPoints
);

// Get my point history (Student only)
router.get(
    "/history",
    verifyToken,
    authorizeRoles("student"),
    pointController.getPointHistory
);

module.exports = router;
