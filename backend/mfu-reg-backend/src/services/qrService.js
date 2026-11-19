
const crypto = require("crypto");
const qrModel = require("../models/qrModel");
const db = require("../config/db");

// Generate secure QR token
const generateQrToken = (activityId, qrId) => {
    if (!process.env.JWT_SECRET) throw new Error('QR signing key is not configured');
    // Domain separation keeps these credentials separate from session tokens.
    // IDs are stable, so staff can reopen a QR without storing its plaintext.
    return crypto.createHmac('sha256', process.env.JWT_SECRET)
        .update(`mfu333:attendance-qr:v2:${Number(activityId)}:${Number(qrId)}`)
        .digest('hex');
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
    const connection = await db.getConnection();
    try {
        await connection.beginTransaction();
        const qrId = await qrModel.createQrToken(
            activityId, `pending:${crypto.randomUUID()}`, startsAt, expiresAt, connection
        );
        const token = generateQrToken(activityId, qrId);
        await qrModel.setTokenHash(qrId, `v2:${hashQrToken(token)}`, connection);
        await connection.commit();
        return { qr_id: qrId, activity_id: Number(activityId), token,
            starts_at: startsAt, expires_at: expiresAt, is_active: 1 };
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
};

const listActivityQr = async (activityId) => {
    const rows = await qrModel.listActivityQr(activityId);
    return rows.map(({ token_hash, ...row }) => {
        const candidate = token_hash.startsWith('v2:')
            ? generateQrToken(row.activity_id, row.qr_id) : null;
        // A rotated signing key cannot reproduce an earlier image. Its original
        // token still verifies against the saved hash, just like legacy codes.
        const token = candidate && `v2:${hashQrToken(candidate)}` === token_hash ? candidate : null;
        return { ...row, token };
    });
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
    verifyActivityQr,
    listActivityQr
};
