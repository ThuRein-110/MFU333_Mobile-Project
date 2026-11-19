
const db = require("../config/db");
const checkinModel = require("../models/checkinModel");
const qrService = require("../services/qrService");
const { getClientIp } = require('../middlewares/wifiMiddleware');

const createCheckin = async (req, res) => {
    try {
        const { activity_id, token } = req.body;
        const userId = req.user.user_id;

        if (!activity_id || !token) {
            return res.status(400).json({
                success: false,
                message: "Activity ID and QR token are required"
            });
        }

        // Find activity
        const [activities] = await db.query(
            `SELECT *
             FROM activities
             WHERE activity_id = ?`,
            [activity_id]
        );

        const activity = activities[0];

        if (!activity) {
            return res.status(404).json({
                success: false,
                message: "Activity not found"
            });
        }

        if (
            activity.status !== "published" &&
            activity.status !== "ongoing"
        ) {
            return res.status(400).json({
                success: false,
                message: "Activity is not available for check-in"
            });
        }

        // Verify QR token
        const qr = await qrService.verifyActivityQr(
            token,
            activity_id
        );

        if (!qr) {
            return res.status(400).json({
                success: false,
                message: "Invalid or expired QR code"
            });
        }

        // Prevent duplicate check-in
        const existingCheckin = await checkinModel.findCheckin(
            activity_id,
            userId
        );

        if (existingCheckin) {
            return res.status(409).json({
                success: false,
                message: "You have already checked in"
            });
        }

        // Check registration
        const [registrations] = await db.query(
            `SELECT *
             FROM activity_registrations
             WHERE activity_id = ?
             AND user_id = ?
             AND status = 'registered'`,
            [activity_id, userId]
        );

        const registration = registrations[0];

        if (!registration) {
            return res.status(403).json({
                success: false,
                message: "You are not registered for this activity"
            });
        }

        // Save check-in, update registration and award points
        const result = await checkinModel.createCheckin({
            activityId: activity_id,
            userId,
            registrationId: registration.registration_id,
            qrId: qr.qr_id,
            verifiedIp: getClientIp(req) || null,
            points: activity.points
        });

        return res.status(201).json({
            success: true,
            message: "Check-in successful",
            data: {
                ...result,
                activity_id,
                activity_title: activity.title
            }
        });

    } catch (error) {
        console.error("Check-in Error:", error);

        if (error.code === "REGISTRATION_NOT_AVAILABLE") {
            return res.status(409).json({
                success: false,
                message: "Registration is no longer available"
            });
        }

        if (error.code === "ER_DUP_ENTRY") {
            return res.status(409).json({
                success: false,
                message: "You have already checked in"
            });
        }

        return res.status(500).json({
            success: false,
            message: "Check-in failed"
        });
    }
};

module.exports = {
    createCheckin
};
