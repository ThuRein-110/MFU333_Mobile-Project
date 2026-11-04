const authorizeRoles = (...allowedRoles) => {
    return (req, res, next) => {

        // ตรวจสอบว่ามีข้อมูล User หรือไม่
        if (!req.user) {
            return res.status(401).json({
                success: false,
                message: "Authentication required"
            });
        }

        // ตรวจสอบ Role
        if (!allowedRoles.includes(req.user.role)) {
            return res.status(403).json({
                success: false,
                message: "You do not have permission"
            });
        }

        next();
    };
};

module.exports = authorizeRoles;