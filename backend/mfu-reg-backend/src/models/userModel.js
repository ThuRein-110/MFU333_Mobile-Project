const db = require("../config/db");

// ค้นหาผู้ใช้จาก Email
const findUserByEmail = async (email) => {
    const [rows] = await db.query(
        "SELECT * FROM users WHERE email = ?",
        [email]
    );

    return rows[0];
};

// สร้างผู้ใช้ใหม่
const createUser = async (studentCode, fullName, email, passwordHash) => {
    const [result] = await db.query(
        `INSERT INTO users
        (student_code, full_name, email, password_hash, role)
        VALUES (?, ?, ?, ?, 'student')`,
        [studentCode, fullName, email, passwordHash]
    );

    return result.insertId;
};
// Admin creates a lecturer account
const createLecturer = async (fullName, email, passwordHash) => {
    const [result] = await db.query(
        `INSERT INTO users
        (student_code, full_name, email, password_hash, role, must_change_password)
        VALUES (NULL, ?, ?, ?, 'lecturer', TRUE)`,
        [fullName, email, passwordHash]
    );

    return result.insertId;
};
// Change user password and clear first-login requirement
const changePassword = async (userId, passwordHash) => {
    const [result] = await db.query(
        `UPDATE users
         SET password_hash = ?,
             must_change_password = FALSE,
             updated_at = CURRENT_TIMESTAMP
         WHERE user_id = ?`,
        [passwordHash, userId]
    );

    return result.affectedRows;
};
const findUserById = async (userId) => {
    const [rows] = await db.query(
        "SELECT * FROM users WHERE user_id = ?",
        [userId]
    );

    return rows[0];
};

module.exports = {
    findUserByEmail,
    findUserById,
    createUser,
    createLecturer,
    changePassword
};