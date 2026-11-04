
const express = require("express");
const router = express.Router();

const registrationController = require("../controllers/registrationController");
const { verifyToken } = require("../middlewares/authMiddleware");
const authorizeRoles = require("../middlewares/roleMiddleware");


// Get my registrations (Student only)
router.get(
    "/my",
    verifyToken,
    authorizeRoles("student"),
    registrationController.getMyRegistrations
);
// Register for activity (Student only)
router.post(
    "/:activityId",
    verifyToken,
    authorizeRoles("student"),
    registrationController.registerActivity
);
// Cancel my registration (Student only)
router.delete(
    "/:activityId",
    verifyToken,
    authorizeRoles("student"),
    registrationController.cancelMyRegistration
);

module.exports = router;
