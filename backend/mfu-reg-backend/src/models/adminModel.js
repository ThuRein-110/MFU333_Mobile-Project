
const db = require("../config/db");

// Get user statistics
const getUserStats = async () => {
    const [rows] = await db.query(`
        SELECT
            COUNT(*) AS total_users,
            SUM(CASE WHEN role = 'student' THEN 1 ELSE 0 END) AS total_students,
            SUM(CASE WHEN role = 'lecturer' THEN 1 ELSE 0 END) AS total_lecturers,
            SUM(CASE WHEN role = 'admin' THEN 1 ELSE 0 END) AS total_admins,
            SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) AS active_users
        FROM users
    `);

    return rows[0];
};

// Get activity statistics
const getActivityStats = async () => {
    const [rows] = await db.query(`
        SELECT
            COUNT(*) AS total_activities,
            SUM(CASE WHEN status = 'draft' THEN 1 ELSE 0 END) AS draft_activities,
            SUM(CASE WHEN status = 'published' THEN 1 ELSE 0 END) AS published_activities,
            SUM(CASE WHEN status = 'ongoing' THEN 1 ELSE 0 END) AS ongoing_activities,
            SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_activities,
            SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_activities
        FROM activities
    `);

    return rows[0];
};

// Get check-in statistics
const getCheckinStats = async () => {
    const [rows] = await db.query(`
        SELECT
            COUNT(*) AS total_checkins,
            SUM(CASE WHEN verification_status = 'verified' THEN 1 ELSE 0 END) AS successful_checkins,
            SUM(CASE WHEN verification_status = 'rejected' THEN 1 ELSE 0 END) AS rejected_checkins
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
            COALESCE((
                SELECT SUM(
                    CASE
                        WHEN pt.transaction_type = 'earn' THEN pt.points
                        WHEN pt.transaction_type = 'revoke' THEN -pt.points
                        WHEN pt.transaction_type = 'adjust' THEN pt.points
                        ELSE 0
                    END
                )
                FROM point_transactions pt
                WHERE pt.user_id = users.user_id
            ), 0) AS total_points,
            is_active,
            created_at
        FROM users
        WHERE 1 = 1
    `;

    const params = [];

    if (search) {
        sql += `
            AND (
                LOWER(student_code) LIKE LOWER(?)
                OR LOWER(full_name) LIKE LOWER(?)
                OR LOWER(email) LIKE LOWER(?)
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