const { randomUUID } = require('node:crypto');
const { put } = require('@vercel/blob');
const jsQR = require('jsqr');
const { imageInput } = require('../services/imageService');

// Vercel provides this variable in production. Load the ignored CLI-generated
// development file locally without overriding the existing database settings.
if (!process.env.VERCEL) {
    require('dotenv').config({ path: require('node:path').join(__dirname, '../../.env.local'), quiet: true });
}

const uploadActivityImage = async (req, res) => {
    try {
        const image = await imageInput(req.body.image);
        const buffer = await image.resize({ width: 1600, height: 1000, fit: 'inside', withoutEnlargement: true })
            .flatten({ background: '#ffffff' }).jpeg({ quality: 82 }).toBuffer();
        if (!process.env.BLOB_READ_WRITE_TOKEN) {
            return res.status(503).json({ success: false, message: 'Image uploads are temporarily unavailable. Please try again.' });
        }
        const result = await put(`activities/${req.user.user_id}/${randomUUID()}.jpg`, buffer, {
            access: 'public', contentType: 'image/jpeg', addRandomSuffix: false,
        });
        res.setHeader('Cache-Control', 'no-store');
        return res.status(201).json({ success: true, data: { url: result.url } });
    } catch (error) {
        if (!error.status) console.error('Image upload failed:', error.name);
        return res.status(error.status || 502).json({ success: false,
            message: error.status ? error.message : 'Image upload failed. Please try again.' });
    }
};

const readQrImage = async (req, res) => {
    try {
        const image = await imageInput(req.body.image);
        const { data, info } = await image.resize({ width: 1800, height: 1800, fit: 'inside', withoutEnlargement: true })
            .flatten({ background: '#ffffff' }).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
        const result = jsQR(new Uint8ClampedArray(data), info.width, info.height);
        if (!result) return res.status(400).json({ success: false, message: 'No QR code found. Choose a clear photo showing the whole QR code.' });
        res.setHeader('Cache-Control', 'no-store');
        return res.json({ success: true, data: { payload: result.data } });
    } catch (error) {
        return res.status(error.status || 400).json({ success: false,
            message: error.status ? error.message : 'Could not read this QR image. Please try another photo.' });
    }
};

module.exports = { uploadActivityImage, readQrImage };
