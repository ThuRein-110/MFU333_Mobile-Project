
const express = require("express");
const router = express.Router();

const activityController = require("../controllers/activityController");
const { verifyToken } = require("../middlewares/authMiddleware");
const authorizeRoles = require("../middlewares/roleMiddleware");
const { uploadActivityImage } = require('../controllers/imageController');

router.post('/image', authorizeRoles('lecturer', 'admin'), uploadActivityImage);

// GET all activities
router.get("/", activityController.getAllActivities);

// GET activity by ID
router.get("/options", authorizeRoles("lecturer", "admin"), activityController.getFormOptions);
router.get("/:id", activityController.getActivityById);

// CREATE activity
router.post(
    "/",
    verifyToken,
    authorizeRoles("lecturer", "admin"),
    activityController.createActivity
);

// UPDATE activity
router.put(
    "/:id",
    verifyToken,
    authorizeRoles("lecturer", "admin"),
    activityController.updateActivity
);

// CANCEL activity
router.delete(
    "/:id",
    verifyToken,
    authorizeRoles("lecturer", "admin"),
    activityController.cancelActivity
);

module.exports = router;
