
const lecturerModel = require("../models/lecturerModel");

// Get student details for the lecturer's student directory
const getStudents = async (req, res) => {
    try {
        const students = await lecturerModel.getStudents();

        return res.json({
            success: true,
            message: "Student details retrieved successfully",
            data: students
        });
    } catch (error) {
        console.error("Get Lecturer Students Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve student details"
        });
    }
};

// Get lecturer dashboard
const getDashboard = async (req, res) => {
    try {
        const lecturerId = req.user.user_id;

        const [stats, activities] = await Promise.all([
            lecturerModel.getMyActivityStats(lecturerId),
            lecturerModel.getMyActivities(lecturerId)
        ]);

        return res.json({
            success: true,
            message: "Lecturer dashboard retrieved successfully",
            data: {
                stats,
                activities
            }
        });

    } catch (error) {
        console.error("Lecturer Dashboard Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve lecturer dashboard"
        });
    }
};
// Get participants of lecturer's activity
const getActivityParticipants = async (req, res) => {
    try {
        const activityId = Number(req.params.activityId);
        const lecturerId = req.user.user_id;

        if (!Number.isInteger(activityId) || activityId <= 0) {
            return res.status(400).json({
                success: false,
                message: "Invalid activity ID"
            });
        }

        const activity = await lecturerModel.getMyActivityById(activityId, lecturerId);
        if (!activity) {
            return res.status(404).json({ success: false, message: "Activity not found" });
        }

        const participants =
            await lecturerModel.getActivityParticipants(
                activityId,
                lecturerId
            );

        return res.json({
            success: true,
            message: "Activity participants retrieved successfully",
            data: participants
        });

    } catch (error) {
        console.error("Get Activity Participants Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve activity participants"
        });
    }
};
// Get lecturer's activity details
const getMyActivityById = async (req, res) => {
    try {
        const activityId = Number(req.params.activityId);
        const lecturerId = req.user.user_id;

        if (!Number.isInteger(activityId) || activityId <= 0) {
            return res.status(400).json({
                success: false,
                message: "Invalid activity ID"
            });
        }

        const activity = await lecturerModel.getMyActivityById(
            activityId,
            lecturerId
        );

        if (!activity) {
            return res.status(404).json({
                success: false,
                message: "Activity not found"
            });
        }

        return res.json({
            success: true,
            message: "Activity details retrieved successfully",
            data: activity
        });

    } catch (error) {
        console.error("Get Lecturer Activity Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve activity details"
        });
    }
};

// Update lecturer's activity status
const updateMyActivityStatus = async (req, res) => {
    try {
        const activityId = Number(req.params.activityId);
        const lecturerId = req.user.user_id;
        const { status } = req.body;

        if (!Number.isInteger(activityId) || activityId <= 0) {
            return res.status(400).json({
                success: false,
                message: "Invalid activity ID"
            });
        }

        const allowedStatuses = [
            "published",
            "ongoing",
            "completed"
        ];

        if (!allowedStatuses.includes(status)) {
            return res.status(400).json({
                success: false,
                message: "Invalid activity status"
            });
        }

        const affectedRows =
            await lecturerModel.updateMyActivityStatus(
                activityId,
                lecturerId,
                status
            );

        if (affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: "Activity not found or cannot be updated"
            });
        }

        return res.json({
            success: true,
            message: "Activity status updated successfully",
            data: {
                activity_id: activityId,
                status
            }
        });

    } catch (error) {
        console.error("Update Activity Status Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to update activity status"
        });
    }
};

module.exports = {
    getStudents,
    getDashboard,
    getActivityParticipants,
    getMyActivityById,
    updateMyActivityStatus
};
