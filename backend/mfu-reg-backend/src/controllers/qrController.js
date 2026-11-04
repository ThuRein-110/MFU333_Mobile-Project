
const qrService = require("../services/qrService");
const activityModel = require("../models/activityModel");

// Create QR for activity
const createActivityQr = async (req, res) => {
    try {
        const { activityId } = req.params;
        const { starts_at, expires_at } = req.body;

        const activity = await activityModel.getActivityById(activityId);

        if (!activity) {
            return res.status(404).json({
                success: false,
                message: "Activity not found"
            });
        }

        const isAdmin = req.user.role === "admin";
        const isOwner =
            Number(activity.organizer_id) === Number(req.user.user_id);

        if (!isAdmin && !isOwner) {
            return res.status(403).json({
                success: false,
                message: "You cannot create QR for this activity"
            });
        }

        if (!starts_at || !expires_at ||
            new Date(expires_at) <= new Date(starts_at)) {
            return res.status(400).json({
                success: false,
                message: "Invalid QR validity period"
            });
        }

        const qr = await qrService.createActivityQr(
            activityId,
            starts_at,
            expires_at
        );

        return res.status(201).json({
            success: true,
            message: "QR token created successfully",
            data: qr
        });

    } catch (error) {
        console.error("Create QR Error:", error);

        return res.status(500).json({
            success: false,
            message: "Internal server error"
        });
    }
};

module.exports = {
    createActivityQr
};
