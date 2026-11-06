const express = require("express");
const cors = require("cors");
const path = require("node:path");
const fs = require("node:fs");
const db = require("./src/config/db");

const authRoutes = require("./src/routes/authRoutes");
const { verifyToken } = require("./src/middlewares/authMiddleware");
const authorizeRoles = require("./src/middlewares/roleMiddleware");
const forcePasswordChange = require("./src/middlewares/forcePasswordChangeMiddleware");

const activityRoutes = require("./src/routes/activityRoutes");
const registrationRoutes = require("./src/routes/registrationRoutes");
const qrRoutes = require("./src/routes/qrRoutes");
const checkinRoutes = require("./src/routes/checkinRoutes");
const pointRoutes = require("./src/routes/pointRoutes");
const adminRoutes = require("./src/routes/adminRoutes");
const lecturerRoutes = require("./src/routes/lecturerRoutes");

const app = express();

app.use(cors());
app.use(express.json());

// The Flutter release build and API share one HTTPS origin when hosted.
const publicDirectory = path.join(__dirname, "public");
app.use(express.static(publicDirectory, {
    setHeaders: (res, filePath) => {
        if (/\.(html|js|json)$/.test(filePath)) {
            res.setHeader("Cache-Control", "no-cache");
        }
    }
}));

app.get("/api/health", async (req, res) => {
    res.setHeader("Cache-Control", "no-store");
    if (!process.env.DATABASE_URL && !process.env.DB_HOST) {
        return res.status(503).json({ success: false, database: "not_configured" });
    }
    try {
        await db.query("SELECT 1");
        return res.json({ success: true, database: "connected" });
    } catch (_) {
        return res.status(503).json({ success: false, database: "unavailable" });
    }
});

// Authentication
app.use("/api/auth", authRoutes);

// Protected APIs: require password change check
// Protected APIs
app.use("/api/activities", verifyToken, forcePasswordChange, activityRoutes);
app.use("/api/registrations", verifyToken, forcePasswordChange, registrationRoutes);
app.use("/api/qr", verifyToken, forcePasswordChange, qrRoutes);
app.use("/api/checkins", verifyToken, forcePasswordChange, checkinRoutes);
app.use("/api/points", verifyToken, forcePasswordChange, pointRoutes);
app.use("/api/admin", verifyToken, forcePasswordChange, adminRoutes);
app.use("/api/lecturer", verifyToken, forcePasswordChange, lecturerRoutes);
app.get("/", (req, res) => {
    if (fs.existsSync(path.join(publicDirectory, "index.html"))) {
        return res.sendFile(path.join(publicDirectory, "index.html"));
    }
    res.json({
        success: true,
        message: "MFU Campus Activity API is running"
    });
});

app.get("/test-db", async (req, res) => {
    try {
        const [rows] = await db.query("SELECT 1 AS result");

        res.json({
            success: true,
            message: "Database connected successfully",
            data: rows
        });
    } catch (error) {
        console.error(error);

        res.status(500).json({
            success: false,
            message: "Database connection failed"
        });
    }
});

// Authenticated user information
app.get("/api/auth/me", verifyToken, (req, res) => {
    res.json({
        success: true,
        message: "Authenticated successfully",
        user: req.user
    });
});

// Student only
app.get(
    "/api/test/student",
    verifyToken,
    forcePasswordChange,
    authorizeRoles("student"),
    (req, res) => {
        res.json({
            success: true,
            message: "Welcome Student",
            user: req.user
        });
    }
);

// Lecturer only
app.get(
    "/api/test/lecturer",
    verifyToken,
    forcePasswordChange,
    authorizeRoles("lecturer"),
    (req, res) => {
        res.json({
            success: true,
            message: "Welcome Lecturer",
            user: req.user
        });
    }
);

// Admin only
app.get(
    "/api/test/admin",
    verifyToken,
    forcePasswordChange,
    authorizeRoles("admin"),
    (req, res) => {
        res.json({
            success: true,
            message: "Welcome Admin",
            user: req.user
        });
    }
);

if (require.main === module) {
    const PORT = process.env.PORT || 3000;

    app.listen(PORT, "0.0.0.0", () => {
        console.log(`Server listening on port ${PORT}`);
    });
}

module.exports = app;
