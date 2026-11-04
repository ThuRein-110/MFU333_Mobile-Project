
const db = require("../config/db");

// Get user statistics
const getUserStats = async () => {
    const [rows] = await db.query(`
        SELECT
            COUNT(*) AS total_users,
            SUM(role = 'student') AS total_students,
            SUM(role = 'lecturer') AS total_lecturers,
            SUM(role = 'admin') AS total_admins,
            SUM(is_active = 1) AS active_users
        FROM users
    `);

    return rows[0];
};

// Get activity statistics
const getActivityStats = async () => {
    const [rows] = await db.query(`
        SELECT
            COUNT(*) AS total_activities,
            SUM(status = 'draft') AS draft_activities,
            SUM(status = 'published') AS published_activities,
            SUM(status = 'ongoing') AS ongoing_activities,
            SUM(status = 'completed') AS completed_activities,
            SUM(status = 'cancelled') AS cancelled_activities
        FROM activities
    `);

    return rows[0];
};

// Get check-in statistics
const getCheckinStats = async () => {
    const [rows] = await db.query(`
        SELECT
            COUNT(*) AS total_checkins,
            SUM(verification_status = 'verified') AS successful_checkins,
            SUM(verification_status = 'rejected') AS rejected_checkins
        FROM activity_checkins
    `);

    return rows[0];
};

// Get point statistics
const getPointStats = async () => {
    const [rows] = await db.query(`
        SELECT
            COALESCE(SUM(
                CASE
                    WHEN transaction_type = 'earn' THEN points
                    WHEN transaction_type = 'revoke' THEN -points
                    WHEN transaction_type = 'adjust' THEN points
                    ELSE 0
                END
            ), 0) AS total_points_awarded
        FROM point_transactions
    `);

    return rows[0];
};

// Get dashboard summary
const getDashboardSummary = async () => {
    const [
        users,
        activities,
        checkins,
        points
    ] = await Promise.all([
        getUserStats(),
        getActivityStats(),
        getCheckinStats(),
        getPointStats()
    ]);

    return {
        users,
        activities,
        checkins,
        points
    };
};

// Get all users with optional search and role filter
const getAllUsers = async (search, role) => {
    let sql = `
        SELECT
            user_id,
            student_code,
            full_name,
            email,
            role,
            is_active,
            created_at
        FROM users
        WHERE 1 = 1
    `;

    const params = [];

    if (search) {
        sql += `
            AND (
                student_code LIKE ?
                OR full_name LIKE ?
                OR email LIKE ?
            )
        `;

        const keyword = `%${search}%`;
        params.push(keyword, keyword, keyword);
    }

    if (role) {
        sql += ` AND role = ?`;
        params.push(role);
    }

    sql += ` ORDER BY created_at DESC`;

    const [rows] = await db.query(sql, params);

    return rows;
};
// Update user active status
const updateUserStatus = async (userId, isActive) => {
    const [result] = await db.query(
        `UPDATE users
         SET is_active = ?
         WHERE user_id = ?`,
        [isActive, userId]
    );

    return result.affectedRows;
};
// Get user details by ID
const getUserById = async (userId) => {
    const [rows] = await db.query(
        `SELECT
            user_id,
            student_code,
            full_name,
            email,
            role,
            is_active,
            created_at,
            updated_at
         FROM users
         WHERE user_id = ?`,
        [userId]
    );

    return rows[0];
};
module.exports = {
    getDashboardSummary,
    getAllUsers,
    updateUserStatus,
    getUserById
};