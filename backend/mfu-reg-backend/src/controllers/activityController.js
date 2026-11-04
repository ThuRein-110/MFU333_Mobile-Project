
const activityModel = require("../models/activityModel");

// GET all activities
const getAllActivities = async (req, res) => {
    try {
        const activities = await activityModel.getAllActivities();

        return res.status(200).json({
            success: true,
            message: "Activities retrieved successfully",
            data: activities
        });
    } catch (error) {
        console.error("Get Activities Error:", error);

        return res.status(500).json({
            success: false,
            message: "Internal server error"
        });
    }
};

// GET activity by ID
const getActivityById = async (req, res) => {
    try {
        const { id } = req.params;
        const activity = await activityModel.getActivityById(id);

        if (!activity) {
            return res.status(404).json({
                success: false,
                message: "Activity not found"
            });
        }

        return res.status(200).json({
            success: true,
            data: activity
        });
    } catch (error) {
        console.error("Get Activity Error:", error);

        return res.status(500).json({
            success: false,
            message: "Internal server error"
        });
    }
};

// CREATE activity
const createActivity = async (req, res) => {
    try {
        const {
            category_id,
            zone_id,
            title,
            description,
            cover_image,
            location,
            start_at,
            end_at,
            registration_deadline,
            max_participants,
            points,
            requires_registration,
            requires_wifi,
            status
        } = req.body;

        if (!category_id || !title || !location || !start_at || !end_at) {
            return res.status(400).json({
                success: false,
                message: "Please fill in all required fields"
            });
        }

        if (
            Number.isNaN(Date.parse(start_at)) ||
            Number.isNaN(Date.parse(end_at)) ||
            new Date(end_at) <= new Date(start_at)
        ) {
            return res.status(400).json({
                success: false,
                message: "Invalid activity date"
            });
        }

        const activityId = await activityModel.createActivity({
            organizer_id: req.user.user_id,
            category_id,
            zone_id,
            title,
            description,
            cover_image,
            location,
            start_at,
            end_at,
            registration_deadline,
            max_participants,
            points,
            requires_registration,
            requires_wifi,
            status: status || "draft"
        });

        return res.status(201).json({
            success: true,
            message: "Activity created successfully",
            data: {
                activity_id: activityId,
                organizer_id: req.user.user_id,
                title
            }
        });
    } catch (error) {
        console.error("Create Activity Error:", error);

        return res.status(500).json({
            success: false,
            message: "Internal server error"
        });
    }
};

// UPDATE activity
const updateActivity = async (req, res) => {
    try {
        const { id } = req.params;

        const activity = await activityModel.getActivityById(id);

        if (!activity) {
            return res.status(404).json({
                success: false,
                message: "Activity not found"
            });
        }

        const isAdmin = req.user.role === "admin";
        const isOwner = Number(activity.organizer_id) === Number(req.user.user_id);

        if (!isAdmin && !isOwner) {
            return res.status(403).json({
                success: false,
                message: "You cannot edit this activity"
            });
        }

        const {
            category_id,
            title,
            location,
            start_at,
            end_at
        } = req.body;

        if (!category_id || !title || !location || !start_at || !end_at) {
            return res.status(400).json({
                success: false,
                message: "Please fill in all required fields"
            });
        }

        if (
            Number.isNaN(Date.parse(start_at)) ||
            Number.isNaN(Date.parse(end_at)) ||
            new Date(end_at) <= new Date(start_at)
        ) {
            return res.status(400).json({
                success: false,
                message: "Invalid activity date"
            });
        }

        const updatedData = {
            ...activity,
            ...req.body
        };

        delete updatedData.organizer_id;

        await activityModel.updateActivity(id, updatedData);

        return res.status(200).json({
            success: true,
            message: "Activity updated successfully"
        });
    } catch (error) {
        console.error("Update Activity Error:", error);

        return res.status(500).json({
            success: false,
            message: "Internal server error"
        });
    }
};

// CANCEL activity (Soft Delete)
const cancelActivity = async (req, res) => {
    try {
        const { id } = req.params;

        const activity = await activityModel.getActivityById(id);

        if (!activity) {
            return res.status(404).json({
                success: false,
                message: "Activity not found"
            });
        }

        const isAdmin = req.user.role === "admin";
        const isOwner = Number(activity.organizer_id) === Number(req.user.user_id);

        if (!isAdmin && !isOwner) {
            return res.status(403).json({
                success: false,
                message: "You cannot cancel this activity"
            });
        }

        if (activity.status === "cancelled") {
            return res.status(400).json({
                success: false,
                message: "Activity is already cancelled"
            });
        }

        await activityModel.cancelActivity(id);

        return res.status(200).json({
            success: true,
            message: "Activity cancelled successfully"
        });
    } catch (error) {
        console.error("Cancel Activity Error:", error);

        return res.status(500).json({
            success: false,
            message: "Internal server error"
        });
    }
};

module.exports = {
    getAllActivities,
    getActivityById,
    createActivity,
    updateActivity,
    cancelActivity
};
