
const db = require("../config/db");

// Find existing check-in
const findCheckin = async (activityId, userId) => {
    const [rows] = await db.query(
        `SELECT *
         FROM activity_checkins
         WHERE activity_id = ?
         AND user_id = ?
         AND verification_status = 'verified'`,
        [activityId, userId]
    );

    return rows[0];
};

// Create check-in, update registration and award points
const createCheckin = async ({
    activityId,
    userId,
    registrationId,
    qrId,
    verifiedIp,
    points
}) => {
    const connection = await db.getConnection();

    try {
        await connection.beginTransaction();

        // Lock registration to prevent concurrent check-ins
        const [registrations] = await connection.query(
            `SELECT registration_id
             FROM activity_registrations
             WHERE registration_id = ?
             AND activity_id = ?
             AND user_id = ?
             AND status = 'registered'
             FOR UPDATE`,
            [registrationId, activityId, userId]
        );

        if (registrations.length === 0) {
            const error = new Error("Registration is no longer available");
            error.code = "REGISTRATION_NOT_AVAILABLE";
            throw error;
        }

        // Save check-in
        const [checkinResult] = await connection.query(
            `INSERT INTO activity_checkins
            (
                activity_id,
                user_id,
                registration_id,
                qr_id,
                verified_ip,
                verification_status
            )
            VALUES (?, ?, ?, ?, ?, 'verified')`,
            [
                activityId,
                userId,
                registrationId,
                qrId,
                verifiedIp
            ]
        );

        const checkinId = checkinResult.insertId;

        // Update registration status
        await connection.query(
            `UPDATE activity_registrations
             SET status = 'attended'
             WHERE registration_id = ?`,
            [registrationId]
        );

        // Award points
        await connection.query(
            `INSERT INTO point_transactions
            (
                user_id,
                activity_id,
                checkin_id,
                points,
                transaction_type,
                description
            )
            VALUES (?, ?, ?, ?, 'earn', ?)`,
            [
                userId,
                activityId,
                checkinId,
                points,
                "Points earned from activity check-in"
            ]
        );

        await connection.commit();

        return {
            checkin_id: checkinId,
            points
        };

    } catch (error) {
        await connection.rollback();
        throw error;

    } finally {
        connection.release();
    }
};

module.exports = {
    findCheckin,
    createCheckin
};
