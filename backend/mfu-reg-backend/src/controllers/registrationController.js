
const registrationModel = require("../models/registrationModel");
const activityModel = require("../models/activityModel");

// Register student for activity
const registerActivity = async (req, res) => {
    try {
        const { activityId } = req.params;
        const userId = req.user.user_id;

        // Check activity exists
        const activity = await activityModel.getActivityById(activityId);

        if (!activity) {
            return res.status(404).json({
                success: false,
                message: "Activity not found"
            });
        }

        // Check activity status
        if (activity.status !== "published") {
            return res.status(400).json({
                success: false,
                message: "This activity is not available for registration"
            });
        }

        // Check registration requirement
        if (!activity.requires_registration) {
            return res.status(400).json({
                success: false,
                message: "This activity does not require registration"
            });
        }

        // Check registration deadline
        if (
            activity.registration_deadline &&
            new Date() > new Date(activity.registration_deadline)
        ) {
            return res.status(400).json({
                success: false,
                message: "Registration deadline has passed"
            });
        }

        // Check duplicate registration
        const existing = await registrationModel.findRegistration(
            activityId,
            userId
        );

        // Prevent duplicate active registrations and re-activate cancelled ones.
        if (existing && existing.status !== "cancelled") {
            return res.status(409).json({
                success: false,
                message: existing.status === "attended"
                    ? "You have already attended this activity"
                    : "You have already registered for this activity"
            });
        }

        // Cancelled registrations are excluded from the active participant count.
        const total = await registrationModel.countRegistrations(activityId);

        if (
            activity.max_participants !== null &&
            total >= activity.max_participants
        ) {
            return res.status(400).json({
                success: false,
                message: "Activity is full"
            });
        }

        let registrationId;
        if (existing && existing.status === "cancelled") {
            const affectedRows = await registrationModel.reactivateRegistration(
                activityId,
                userId
            );

            if (!affectedRows) {
                return res.status(409).json({
                    success: false,
                    message: "Unable to re-activate this registration"
                });
            }
            registrationId = existing.registration_id;
        } else {
            registrationId = await registrationModel.createRegistration(
                activityId,
                userId
            );
        }

        return res.status(existing ? 200 : 201).json({
            success: true,
            message: "Registered successfully",
            data: {
                registration_id: registrationId,
                activity_id: Number(activityId),
                user_id: userId,
                status: "registered"
            }
        });

    } catch (error) {
        console.error("Register Activity Error:", error);

        if (error.code === "ER_DUP_ENTRY") {
            return res.status(409).json({
                success: false,
                message: "You have already registered for this activity"
            });
        }

        return res.status(500).json({
            success: false,
            message: "Internal server error"
        });
    }
};

// Get registrations of logged-in student
const getMyRegistrations = async (req, res) => {
    try {
        const userId = req.user.user_id;

        const registrations =
            await registrationModel.getMyRegistrations(userId);

        return res.status(200).json({
            success: true,
            message: "My registrations retrieved successfully",
            data: registrations
        });

    } catch (error) {
        console.error("Get My Registrations Error:", error);

        return res.status(500).json({
            success: false,
            message: "Internal server error"
        });
    }
};

// Cancel student registration
const cancelMyRegistration = async (req, res) => {
    try {
        const { activityId } = req.params;
        const userId = req.user.user_id;

        // Check existing registration
        const registration = await registrationModel.findRegistration(
            activityId,
            userId
        );

        if (!registration) {
            return res.status(404).json({
                success: false,
                message: "Registration not found"
            });
        }

        if (registration.status === "cancelled") {
            return res.status(400).json({
                success: false,
                message: "Registration is already cancelled"
            });
        }

        if (registration.status !== "registered") {
            return res.status(400).json({
                success: false,
                message: "This registration cannot be cancelled"
            });
        }

        await registrationModel.cancelRegistration(activityId, userId);

        return res.status(200).json({
            success: true,
            message: "Registration cancelled successfully"
        });

    } catch (error) {
        console.error("Cancel Registration Error:", error);

        return res.status(500).json({
            success: false,
            message: "Internal server error"
        });
    }
};


module.exports = {
    registerActivity,
    getMyRegistrations,
    cancelMyRegistration
};