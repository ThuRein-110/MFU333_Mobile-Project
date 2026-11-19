
const db = require("../config/db");

const getFormOptions = async () => {
    const [[categories], [zones]] = await Promise.all([
        db.query("SELECT category_id, category_name FROM activity_categories WHERE is_active = 1 ORDER BY category_name"),
        db.query("SELECT zone_id, zone_name FROM network_zones WHERE is_active = 1 ORDER BY zone_name")
    ]);
    return { categories, zones };
};

// Get all activities
const getAllActivities = async () => {
    const [rows] = await db.query(`
        SELECT
            a.*,
            u.full_name AS organizer_name
        FROM activities a
        JOIN users u ON a.organizer_id = u.user_id
        ORDER BY a.created_at DESC
    `);

    return rows;
};

// Get activity by ID
const getActivityById = async (activityId) => {
    const [rows] = await db.query(
        "SELECT * FROM activities WHERE activity_id = ?",
        [activityId]
    );

    return rows[0];
};

// Create activity
const createActivity = async (activityData) => {
    const {
        organizer_id,
        category_id,
        zone_id,
        title,
        description,
        cover_image,
        location,
        start_at,
        end_at,
        registration_deadline,
        max_participants,
        points,
        requires_registration,
        requires_wifi,
        status
    } = activityData;

    const [result] = await db.query(
        `INSERT INTO activities (
            organizer_id, category_id, zone_id,
            title, description, cover_image, location,
            start_at, end_at, registration_deadline,
            max_participants, points,
            requires_registration, requires_wifi, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
            organizer_id,
            category_id,
            zone_id ?? null,
            title,
            description || null,
            cover_image || null,
            location,
            start_at,
            end_at,
            registration_deadline || null,
            max_participants ?? null,
            points ?? 0,
            requires_registration ?? 1,
            requires_wifi ?? 0,
            status || "draft"
        ]
    );

    return result.insertId;
};

// Update activity
const updateActivity = async (activityId, activityData) => {
    const {
        category_id,
        zone_id,
        title,
        description,
        cover_image,
        location,
        start_at,
        end_at,
        registration_deadline,
        max_participants,
        points,
        requires_registration,
        requires_wifi,
        status
    } = activityData;

    const [result] = await db.query(
        `UPDATE activities SET
            category_id = ?,
            zone_id = ?,
            title = ?,
            description = ?,
            cover_image = ?,
            location = ?,
            start_at = ?,
            end_at = ?,
            registration_deadline = ?,
            max_participants = ?,
            points = ?,
            requires_registration = ?,
            requires_wifi = ?,
            status = ?
        WHERE activity_id = ?`,
        [
            category_id,
            zone_id ?? null,
            title,
            description ?? null,
            cover_image ?? null,
            location,
            start_at,
            end_at,
            registration_deadline ?? null,
            max_participants ?? null,
            points ?? 0,
            requires_registration ?? 1,
            requires_wifi ?? 1,
            status ?? "draft",
            activityId
        ]
    );

    return result.affectedRows;
};

// Cancel activity (Soft Delete)
const cancelActivity = async (activityId) => {
    const [result] = await db.query(
        `UPDATE activities
         SET status = 'cancelled'
         WHERE activity_id = ?`,
        [activityId]
    );

    return result.affectedRows;
};

module.exports = {
    getFormOptions,
    getAllActivities,
    getActivityById,
    createActivity,
    updateActivity,
    cancelActivity
};
