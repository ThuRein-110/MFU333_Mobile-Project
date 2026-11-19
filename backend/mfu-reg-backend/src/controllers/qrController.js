
const qrService = require("../services/qrService");
const activityModel = require("../models/activityModel");
const qrModel = require("../models/qrModel");

const listActivityQr = async (req, res) => {
    try {
        const activity = await activityModel.getActivityById(req.params.activityId);
        if (!activity) return res.status(404).json({ success: false, message: 'Activity not found' });
        if (req.user.role !== 'admin' && Number(activity.organizer_id) !== Number(req.user.user_id)) {
            return res.status(403).json({ success: false, message: 'You cannot view QR codes for this activity' });
        }
        res.setHeader('Cache-Control', 'no-store');
        return res.json({ success: true, data: await qrService.listActivityQr(activity.activity_id) });
    } catch (error) {
        console.error('List QR Error:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
};

const listStudentAlerts = async (req, res) => {
    try {
        res.setHeader('Cache-Control', 'no-store');
        return res.json({ success: true, data: await qrModel.listStudentAlerts() });
    } catch (error) {
        console.error('Activity alerts error:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
};

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

        if (!["published", "ongoing"].includes(activity.status)) {
            return res.status(400).json({ success: false, message: "Publish the activity before creating a QR code" });
        }

        if (!starts_at || !expires_at ||
            Number.isNaN(Date.parse(starts_at)) || Number.isNaN(Date.parse(expires_at)) ||
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

        res.setHeader('Cache-Control', 'no-store');
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
    createActivityQr,
    listActivityQr,
    listStudentAlerts
};
