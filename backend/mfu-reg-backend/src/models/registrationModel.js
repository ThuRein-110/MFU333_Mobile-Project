
const db = require("../config/db");

// Check existing registration
const findRegistration = async (activityId, userId) => {
    const [rows] = await db.query(
        `SELECT * FROM activity_registrations
         WHERE activity_id = ? AND user_id = ?`,
        [activityId, userId]
    );

    return rows[0];
};

// Register student for activity
const createRegistration = async (activityId, userId) => {
    const [result] = await db.query(
        `INSERT INTO activity_registrations
         (activity_id, user_id, status)
         VALUES (?, ?, 'registered')`,
        [activityId, userId]
    );

    return result.insertId;
};

// Re-activate a previously cancelled registration instead of inserting a duplicate row.
const reactivateRegistration = async (activityId, userId) => {
    const [result] = await db.query(
        `UPDATE activity_registrations
         SET status = 'registered', registered_at = NOW()
         WHERE activity_id = ?
           AND user_id = ?
           AND status = 'cancelled'`,
        [activityId, userId]
    );

    return result.affectedRows;
};

// Count active registrations
const countRegistrations = async (activityId) => {
    const [rows] = await db.query(
        `SELECT COUNT(*) AS total
         FROM activity_registrations
         WHERE activity_id = ?
         AND status IN ('registered', 'attended')`,
        [activityId]
    );

    return rows[0].total;
};

// Get registrations of a student
const getMyRegistrations = async (userId) => {
    const [rows] = await db.query(
        `SELECT
            ar.registration_id,
            ar.activity_id,
            ar.user_id,
            ar.status AS registration_status,
            ar.registered_at,
            a.title,
            a.description,
            a.location,
            a.start_at,
            a.end_at,
            a.points,
            a.status AS activity_status
         FROM activity_registrations ar
         JOIN activities a
            ON ar.activity_id = a.activity_id
         WHERE ar.user_id = ?
         ORDER BY ar.registered_at DESC`,
        [userId]
    );

    return rows;
};
// Cancel student registration
const cancelRegistration = async (activityId, userId) => {
    const [result] = await db.query(
        `UPDATE activity_registrations
         SET status = 'cancelled'
         WHERE activity_id = ?
         AND user_id = ?
         AND status = 'registered'`,
        [activityId, userId]
    );

    return result.affectedRows;
};

module.exports = {
    findRegistration,
    createRegistration,
    reactivateRegistration,
    countRegistrations,
    getMyRegistrations,
    cancelRegistration
};