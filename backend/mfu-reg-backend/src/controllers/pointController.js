
const pointModel = require("../models/pointModel");

// Get my total points
const getMyPoints = async (req, res) => {
    try {
        const userId = req.user.user_id;

        const totalPoints = await pointModel.getMyPoints(userId);

        return res.json({
            success: true,
            data: {
                total_points: Number(totalPoints)
            }
        });

    } catch (error) {
        console.error("Get My Points Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve points"
        });
    }
};

// Get my point history
const getPointHistory = async (req, res) => {
    try {
        const userId = req.user.user_id;

        const history = await pointModel.getPointHistory(userId);

        return res.json({
            success: true,
            data: history
        });

    } catch (error) {
        console.error("Get Point History Error:", error);

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve point history"
        });
    }
};

module.exports = {
    getMyPoints,
    getPointHistory
};
