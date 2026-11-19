
const db = require("../config/db");

// Create QR token
const createQrToken = async (
    activityId,
    tokenHash,
    startsAt,
    expiresAt,
    connection = db
) => {
    const [result] = await connection.query(
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
         WHERE token_hash IN (?, ?)
         AND activity_id = ?
         AND is_active = 1
         AND starts_at <= NOW()
         AND expires_at >= NOW()`,
        [tokenHash, `v2:${tokenHash}`, activityId]
    );

    return rows[0];
};

const setTokenHash = async (qrId, tokenHash, connection) => {
    await connection.query('UPDATE qr_tokens SET token_hash = ? WHERE qr_id = ?', [tokenHash, qrId]);
};

const listActivityQr = async (activityId) => {
    const [rows] = await db.query(
        `SELECT qr_id, activity_id, token_hash, starts_at, expires_at, is_active, created_at
         FROM qr_tokens WHERE activity_id = ? ORDER BY qr_id DESC`, [activityId]
    );
    return rows;
};

// Student-safe feed: never include the token or its hash. Scheduled codes also
// announce an activity, but expired, inactive and unpublished activities do not.
const listStudentAlerts = async () => {
    const [rows] = await db.query(
        `SELECT q.qr_id, q.activity_id, q.created_at, q.starts_at, q.expires_at,
                a.title AS activity_title, a.location
         FROM qr_tokens q JOIN activities a ON a.activity_id = q.activity_id
         WHERE q.is_active = 1 AND q.expires_at > NOW()
           AND a.status IN ('published', 'ongoing')
           AND q.token_hash NOT LIKE 'pending:%'
         ORDER BY q.qr_id DESC LIMIT 100`
    );
    return rows;
};

module.exports = {
    createQrToken,
    findValidQrToken,
    setTokenHash,
    listActivityQr,
    listStudentAlerts
};
