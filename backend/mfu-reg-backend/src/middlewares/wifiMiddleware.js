
const db = require("../config/db");
const { isIpInRange } = require("../services/ipUtils");
const { isIP } = require("node:net");

const getClientIp = (req) => {
    // On Vercel, the socket belongs to its proxy. The platform overwrites these
    // client-IP headers: https://vercel.com/docs/headers/request-headers
    // Local servers ignore forwarded headers supplied by arbitrary clients.
    const forwarded = process.env.VERCEL === "1"
        ? req.headers["x-vercel-forwarded-for"] ?? req.headers["x-forwarded-for"]
        : undefined;
    let ip = forwarded === undefined
        ? req.ip || req.socket.remoteAddress || ""
        : typeof forwarded === "string" ? forwarded.trim() : "";

    if (ip.startsWith("::ffff:")) {
        ip = ip.replace("::ffff:", "");
    }

    return isIP(ip) ? ip : "";
};

const verifyWifi = async (req, res, next) => {
    try {
        const mockMode = process.env.WIFI_MOCK_MODE === "true";

        // Mock IP is controlled by the server, never by the client
        const clientIp = mockMode
            ? "10.20.5.25"
            : getClientIp(req);

        const [allowedRanges] = await db.query(`
            SELECT
                ai.ip_range,
                nz.zone_id,
                nz.zone_name
            FROM allowed_ips ai
            JOIN network_zones nz
                ON ai.zone_id = nz.zone_id
            WHERE nz.is_active = 1
        `);

        const matchedZone = allowedRanges.find((item) =>
            isIpInRange(clientIp, item.ip_range)
        );

        if (!matchedZone) {
            return res.status(403).json({
                success: false,
                message: "Please connect to campus Wi-Fi"
            });
        }

        req.wifi = {
            verified: true,
            client_ip: clientIp,
            zone_id: matchedZone.zone_id,
            zone_name: matchedZone.zone_name,
            mode: mockMode ? "mock" : "production"
        };

        next();

    } catch (error) {
        console.error("WiFi Verification Error:", error);

        return res.status(500).json({
            success: false,
            message: "Wi-Fi verification failed"
        });
    }
};

module.exports = { verifyWifi, getClientIp };
