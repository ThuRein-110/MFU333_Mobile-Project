const { isIPv4 } = require('node:net');
const settings = require('../models/settingsModel');

const failure = (res, status, message) => res.status(status).json({ success: false, message });
const validId = value => (typeof value === 'number' || typeof value === 'string' && /^\d+$/.test(value)) &&
    Number.isSafeInteger(Number(value)) && Number(value) > 0;

// Use one canonical representation so duplicate CIDRs cannot be saved with different host bits.
const normalizeRange = value => {
    if (typeof value !== 'string') return null;
    const parts = value.trim().split('/');
    const address = parts[0];
    const prefix = parts.length === 1 ? 32 : Number(parts[1]);
    if (parts.length > 2 || !isIPv4(address) || !Number.isInteger(prefix) || prefix < 1 || prefix > 32) return null;
    const number = address.split('.').reduce((result, part) => (result << 8) + Number(part), 0) >>> 0;
    const mask = (0xFFFFFFFF << (32 - prefix)) >>> 0;
    const network = (number & mask) >>> 0;
    return `${[24, 16, 8, 0].map(shift => (network >>> shift) & 255).join('.')}/${prefix}`;
};

const getSettings = async (_req, res) => {
    try { return res.json({ success: true, data: await settings.getSettings() }); }
    catch (_) { return failure(res, 500, 'Failed to load system settings'); }
};

const saveResource = (kind, updating) => async (req, res) => {
    try {
        const id = updating ? Number(req.params.id) : null;
        if (updating && !validId(req.params.id)) return failure(res, 400, 'Invalid settings ID');
        const previous = updating ? await settings.find(kind, id) : {};
        if (!previous) return failure(res, 404, 'Settings item not found');
        const input = { ...previous, ...req.body };
        const description = input.description == null ? null : input.description;
        if (description !== null && typeof description !== 'string') return failure(res, 400, 'Invalid description');
        const values = { description: description?.trim() || null };
        if (kind === 'ips') {
            const range = normalizeRange(input.ip_range);
            if (!range) return failure(res, 400, 'Enter a valid IPv4 address or CIDR range with prefix 1 to 32');
            if (!validId(input.zone_id) || !(await settings.find('zones', Number(input.zone_id)))) {
                return failure(res, 400, 'Invalid network zone');
            }
            values.zone_id = Number(input.zone_id);
            values.ip_range = range;
        } else {
            const nameField = kind === 'categories' ? 'category_name' : 'zone_name';
            if (typeof input[nameField] !== 'string' || !input[nameField].trim() || input[nameField].trim().length > 100) {
                return failure(res, 400, 'Enter a name between 1 and 100 characters');
            }
            const active = input.is_active === undefined ? 1 : input.is_active;
            if (![true, false, 0, 1].includes(active)) return failure(res, 400, 'Invalid active status');
            values[nameField] = input[nameField].trim();
            values.is_active = Number(active);
        }
        const savedId = await settings.save(kind, id, values);
        return res.status(updating ? 200 : 201).json({ success: true, message: 'Settings saved successfully', data: { id: savedId } });
    } catch (error) {
        if (error.code === 'ER_DUP_ENTRY') return failure(res, 409, 'This settings item already exists');
        return failure(res, 500, 'Failed to save system settings');
    }
};

const removeIp = async (req, res) => {
    if (!validId(req.params.id)) return failure(res, 400, 'Invalid settings ID');
    try {
        if (!(await settings.removeIp(Number(req.params.id)))) return failure(res, 404, 'Settings item not found');
        return res.json({ success: true, message: 'Allowed IP removed successfully' });
    } catch (_) { return failure(res, 500, 'Failed to save system settings'); }
};

module.exports = {
    getSettings,
    createCategory: saveResource('categories', false), updateCategory: saveResource('categories', true),
    createZone: saveResource('zones', false), updateZone: saveResource('zones', true),
    createIp: saveResource('ips', false), updateIp: saveResource('ips', true), removeIp,
    normalizeRange
};
