
const crypto = require("crypto");
const qrModel = require("../models/qrModel");

// Generate secure QR token
const generateQrToken = () => {
    return crypto.randomBytes(32).toString("hex");
};

// Hash QR token
const hashQrToken = (token) => {
    return crypto
        .createHash("sha256")
        .update(token)
        .digest("hex");
};

// Create QR token for activity
const createActivityQr = async (activityId, startsAt, expiresAt) => {
    const token = generateQrToken();
    const tokenHash = hashQrToken(token);

    const qrId = await qrModel.createQrToken(
        activityId,
        tokenHash,
        startsAt,
        expiresAt
    );

    return {
        qr_id: qrId,
        activity_id: activityId,
        token,
        starts_at: startsAt,
        expires_at: expiresAt
    };
};

// Verify QR token
const verifyActivityQr = async (token, activityId) => {
    const tokenHash = hashQrToken(token);

    return await qrModel.findValidQrToken(
        tokenHash,
        activityId
    );
};

module.exports = {
    createActivityQr,
    verifyActivityQr
};
