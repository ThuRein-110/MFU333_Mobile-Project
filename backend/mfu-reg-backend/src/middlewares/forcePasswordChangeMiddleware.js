const forcePasswordChange = (req, res, next) => {
    if (req.user.must_change_password) {
        return res.status(403).json({
            success: false,
            message: "You must change your password before accessing this resource",
            code: "PASSWORD_CHANGE_REQUIRED"
        });
    }

    next();
};

module.exports = forcePasswordChange;