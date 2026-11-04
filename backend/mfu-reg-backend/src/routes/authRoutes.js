const express = require("express");
const router = express.Router();

const authController = require("../controllers/authController");
const { verifyToken } = require("../middlewares/authMiddleware");

// สมัครสมาชิก
router.post("/register", authController.register);

// เข้าสู่ระบบ
router.post("/login", authController.login);

// เปลี่ยนรหัสผ่าน
router.patch(
    "/change-password",
    verifyToken,
    authController.changePassword
);

module.exports = router;