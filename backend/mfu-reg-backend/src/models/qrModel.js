
const db = require("../config/db");

// Create QR token
const createQrToken = async (
    activityId,
    tokenHash,
    startsAt,
    expiresAt
) => {
    const [result] = await db.query(
        `INSERT INTO qr_tokens
        (activity_id, token_hash, starts_at, expires_at, is_active)
        VALUES (?, ?, ?, ?, 1)`,
        [activityId, tokenHash, startsAt, expiresAt]
    );

    return result.insertId;
};

// Find valid QR token
const findValidQrToken = async (tokenHash, activityId) => {
    const [rows] = await db.query(
        `SELECT *
         FROM qr_tokens
         WHERE token_hash = ?
         AND activity_id = ?
         AND is_active = 1
         AND starts_at <= NOW()
         AND expires_at >= NOW()`,
        [tokenHash, activityId]
    );

    return rows[0];
};

module.exports = {
    createQrToken,
    findValidQrToken
};
