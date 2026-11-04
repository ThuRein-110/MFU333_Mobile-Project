
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
            transaction_id,
            activity_id,
            checkin_id,
            points,
            transaction_type,
            description,
            created_at
         FROM point_transactions
         WHERE user_id = ?
         ORDER BY created_at DESC`,
        [userId]
    );

    return rows;
};

module.exports = {
    getMyPoints,
    getPointHistory
};
