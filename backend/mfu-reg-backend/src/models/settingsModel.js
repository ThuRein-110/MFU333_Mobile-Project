const db = require('../config/db');

// Identifiers come only from this fixed server-side map, never from request data.
const resources = {
    categories: { table: 'activity_categories', id: 'category_id', fields: ['category_name', 'description', 'is_active'] },
    zones: { table: 'network_zones', id: 'zone_id', fields: ['zone_name', 'description', 'is_active'] },
    ips: { table: 'allowed_ips', id: 'ip_id', fields: ['zone_id', 'ip_range', 'description'] }
};

const getSettings = async () => {
    const [[categories], [zones], [allowed_ips]] = await Promise.all([
        db.query('SELECT category_id, category_name, description, is_active FROM activity_categories ORDER BY category_name'),
        db.query('SELECT zone_id, zone_name, description, is_active FROM network_zones ORDER BY zone_name'),
        db.query('SELECT ip_id, zone_id, ip_range, description FROM allowed_ips ORDER BY zone_id, ip_id')
    ]);
    return { categories, zones, allowed_ips };
};

const find = async (kind, id) => {
    const resource = resources[kind];
    const [rows] = await db.query(`SELECT * FROM ${resource.table} WHERE ${resource.id} = ?`, [id]);
    return rows[0];
};

const save = async (kind, id, values) => {
    const resource = resources[kind];
    const parameters = resource.fields.map(field => values[field]);
    if (id !== null) {
        await db.query(`UPDATE ${resource.table} SET ${resource.fields.map(field => `${field} = ?`).join(', ')} WHERE ${resource.id} = ?`, [...parameters, id]);
        return id;
    }
    const [result] = await db.query(`INSERT INTO ${resource.table} (${resource.fields.join(', ')}) VALUES (${resource.fields.map(() => '?').join(', ')})`, parameters);
    return result.insertId;
};

const removeIp = async (id) => {
    const [result] = await db.query('DELETE FROM allowed_ips WHERE ip_id = ?', [id]);
    return result.affectedRows;
};

module.exports = { getSettings, find, save, removeIp };
