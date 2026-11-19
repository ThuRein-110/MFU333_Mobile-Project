const sharp = require('sharp');

const imageInput = async (value) => {
    if (typeof value !== 'string' || !value || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) {
        throw Object.assign(new Error('Choose a valid JPEG, PNG or WebP image'), { status: 400 });
    }
    if (value.length > 4 * 1024 * 1024) {
        throw Object.assign(new Error('Choose an image smaller than 3 MB'), { status: 413 });
    }
    const buffer = Buffer.from(value, 'base64');
    if (buffer.length > 3 * 1024 * 1024) {
        throw Object.assign(new Error('Choose an image smaller than 3 MB'), { status: 413 });
    }
    try {
        const image = sharp(buffer, { limitInputPixels: 24000000 }).rotate();
        const metadata = await image.metadata();
        if (!['jpeg', 'png', 'webp'].includes(metadata.format)) throw new Error('Unsupported format');
        return image;
    } catch {
        throw Object.assign(new Error('Choose a valid JPEG, PNG or WebP image'), { status: 400 });
    }
};

module.exports = { imageInput };
