
const db = require("../config/db");

// Get lecturer's activity statistics
const getMyActivityStats = async (lecturerId) => {
    const [rows] = await db.query(
        `SELECT
            COUNT(*) AS total_activities,
            COALESCE(SUM(status = 'published'), 0) AS published_activities,
            COALESCE(SUM(status = 'ongoing'), 0) AS ongoing_activities,
            COALESCE(SUM(status = 'completed'), 0) AS completed_activities,
            COALESCE(SUM(status = 'cancelled'), 0) AS cancelled_activities
         FROM activities
         WHERE organizer_id = ?`,
        [lecturerId]
    );

    const stats = rows[0];

    return {
        total_activities: Number(stats.total_activities),
        published_activities: Number(stats.published_activities),
        ongoing_activities: Number(stats.ongoing_activities),
        completed_activities: Number(stats.completed_activities),
        cancelled_activities: Number(stats.cancelled_activities)
    };
};

// Get lecturer's activities with registration and check-in counts
const getMyActivities = async (lecturerId) => {
    const [rows] = await db.query(
        `SELECT
            a.activity_id,
            a.title,
            a.status,
            a.start_at,
            a.end_at,
            a.points,
            a.max_participants,
            COUNT(DISTINCT ar.registration_id) AS total_registrations,
            COUNT(DISTINCT CASE
                WHEN ar.status = 'attended'
                THEN ar.registration_id
            END) AS total_attended
         FROM activities a
         LEFT JOIN activity_registrations ar
            ON a.activity_id = ar.activity_id
         WHERE a.organizer_id = ?
         GROUP BY a.activity_id
         ORDER BY a.created_at DESC`,
        [lecturerId]
    );

    return rows;
};
// Get students registered in an activity
const getActivityParticipants = async (activityId, lecturerId) => {
    const [rows] = await db.query(
        `SELECT
            ar.registration_id,
            ar.status AS registration_status,
            ar.registered_at,
            u.user_id,
            u.student_code,
            u.full_name,
            u.email,
            ac.checked_in_at
         FROM activities a
         JOIN activity_registrations ar
            ON a.activity_id = ar.activity_id
         JOIN users u
            ON ar.user_id = u.user_id
         LEFT JOIN activity_checkins ac
            ON ac.registration_id = ar.registration_id
            AND ac.verification_status = 'verified'
         WHERE a.activity_id = ?
         AND a.organizer_id = ?
         ORDER BY ar.registered_at DESC`,
        [activityId, lecturerId]
    );

    return rows;
};
// Get activity details owned by lecturer
const getMyActivityById = async (activityId, lecturerId) => {
    const [rows] = await db.query(
        `SELECT
            a.*,
            ac.category_name,
            nz.zone_name,
            u.full_name AS organizer_name,
            (
                SELECT COUNT(*)
                FROM activity_registrations ar
                WHERE ar.activity_id = a.activity_id
                AND ar.status IN ('registered', 'attended')
            ) AS total_registrations,
            (
                SELECT COUNT(*)
                FROM activity_registrations ar
                WHERE ar.activity_id = a.activity_id
                AND ar.status = 'attended'
            ) AS total_attended
         FROM activities a
         LEFT JOIN activity_categories ac
            ON a.category_id = ac.category_id
         LEFT JOIN network_zones nz
            ON a.zone_id = nz.zone_id
         JOIN users u
            ON a.organizer_id = u.user_id
         WHERE a.activity_id = ?
         AND a.organizer_id = ?
         LIMIT 1`,
        [activityId, lecturerId]
    );

    return rows[0];
};
// Update activity status owned by lecturer
const updateMyActivityStatus = async (
    activityId,
    lecturerId,
    status
) => {
    const [result] = await db.query(
        `UPDATE activities
         SET status = ?,
             updated_at = CURRENT_TIMESTAMP
         WHERE activity_id = ?
         AND organizer_id = ?
         AND status != 'cancelled'`,
        [status, activityId, lecturerId]
    );

    return result.affectedRows;
};

module.exports = {
    getMyActivityStats,
    getMyActivities,
    getActivityParticipants,
    getMyActivityById,
    updateMyActivityStatus
};
