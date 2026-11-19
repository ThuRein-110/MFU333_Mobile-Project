const { test } = require('node:test');
const assert = require('node:assert/strict');
// These tests exercise IP extraction only, without opening a database connection.
const dbPath = require.resolve('../src/config/db');
require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: {} };
const { getClientIp } = require('../src/middlewares/wifiMiddleware');

test('local requests use the peer address and ignore forged forwarding headers', () => {
    const original = process.env.VERCEL;
    delete process.env.VERCEL;
    try {
        assert.equal(getClientIp({ ip: '::ffff:127.0.0.1', socket: {}, headers: {
            'x-forwarded-for': '10.20.5.25', 'x-vercel-forwarded-for': '10.20.5.25'
        } }), '127.0.0.1');
    } finally { if (original === undefined) delete process.env.VERCEL; else process.env.VERCEL = original; }
});

test('Vercel check-in uses the platform client IP instead of the internal socket', () => {
    const original = process.env.VERCEL;
    process.env.VERCEL = '1';
    try {
        const request = { ip: '127.0.0.1', socket: {}, headers: {
            'x-vercel-forwarded-for': '203.0.113.7', 'x-forwarded-for': '198.51.100.8'
        } };
        assert.equal(getClientIp(request), '203.0.113.7');
        request.headers['x-vercel-forwarded-for'] = 'not-an-ip';
        assert.equal(getClientIp(request), '');
    } finally { if (original === undefined) delete process.env.VERCEL; else process.env.VERCEL = original; }
});
