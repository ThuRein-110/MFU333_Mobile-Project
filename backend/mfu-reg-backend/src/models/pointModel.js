
const db = require("../config/db");

// Get total points of a student
const getMyPoints = async (userId) => {
    const [rows] = await db.query(
        `SELECT
            COALESCE(SUM(
                CASE
                    WHEN transaction_type = 'earn' THEN points
                    WHEN transaction_type = 'revoke' THEN -points
                    WHEN transaction_type = 'adjust' THEN points
                    ELSE 0
                END
            ), 0) AS total_points
         FROM point_transactions
         WHERE user_id = ?`,
        [userId]
    );

    return rows[0].total_points;
};

// Get point transaction history
const getPointHistory = async (userId) => {
    const [rows] = await db.query(
        `SELECT
            pt.transaction_id,
            pt.activity_id,
            pt.checkin_id,
            pt.points,
            pt.transaction_type,
            pt.description,
            pt.created_at,
            a.title AS activity_title
         FROM point_transactions pt
         LEFT JOIN activities a ON a.activity_id = pt.activity_id
         WHERE pt.user_id = ?
         ORDER BY pt.created_at DESC`,
        [userId]
    );

    return rows;
};

module.exports = {
    getMyPoints,
    getPointHistory
};
