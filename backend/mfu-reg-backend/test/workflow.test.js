const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const bcrypt = require('bcrypt');
const sharp = require('sharp');
const QRCode = require('qrcode');
const { PGlite } = require('@electric-sql/pglite');
const { createPostgresAdapter } = require('../src/config/postgresAdapter');

test('admin, two lecturers and two students share one complete activity workflow', async (t) => {
    const engine = new PGlite();
    await engine.exec(await fs.readFile(path.join(__dirname, '../scripts/schema-postgres.sql'), 'utf8'));
    const client = {
        async query(sql, params) {
            const result = await engine.query(sql, params);
            return { ...result, rowCount: result.affectedRows || 0, command: sql.trim().split(/\s+/)[0].toUpperCase() };
        },
        release() {}
    };
    const db = createPostgresAdapter({ ...client, connect: async () => client, end: () => engine.close() });
    const dbPath = require.resolve('../src/config/db');
    require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };
    process.env.JWT_SECRET = 'isolated-cross-role-workflow-test';
    process.env.BLOB_READ_WRITE_TOKEN = 'vercel_blob_rw_isolated_test_token';
    const uploads = [];
    const blobPath = require.resolve('@vercel/blob');
    require.cache[blobPath] = { id: blobPath, filename: blobPath, loaded: true, exports: {
        put: async (pathname, buffer, options) => {
            uploads.push({ pathname, buffer, options });
            return { url: `https://fixture.public.blob.vercel-storage.com/${pathname}` };
        }
    } };
    process.env.WIFI_MOCK_MODE = 'false';
    const password = 'Workflow-test-password-27';
    const changedPassword = 'Changed-workflow-password-27';
    const hash = await bcrypt.hash(password, 4);
    await engine.query("INSERT INTO users (full_name,email,password_hash,role) VALUES ('Admin','admin@workflow.invalid',$1,'admin'),('Other Lecturer','other@workflow.invalid',$1,'lecturer')", [hash]);
    await engine.exec("INSERT INTO activity_categories (category_name) VALUES ('Workshop'); INSERT INTO network_zones (zone_name) VALUES ('Campus'); INSERT INTO allowed_ips (zone_id,ip_range) VALUES (1,'10.20.0.0/16')");
    const server = require('../server').listen(0, '127.0.0.1');
    await new Promise(resolve => server.once('listening', resolve));
    const base = `http://127.0.0.1:${server.address().port}`;
    const sessions = {};
    const request = async (role, method, url, body) => {
        const response = await fetch(base + url, {
            method,
            headers: { 'Content-Type': 'application/json', ...(sessions[role] ? { Authorization: `Bearer ${sessions[role]}` } : {}) },
            body: body ? JSON.stringify(body) : undefined,
        });
        return { status: response.status, body: await response.json() };
    };
    const login = async (name, email, secret = password) => {
        const result = await request(null, 'POST', '/api/auth/login', { email, password: secret });
        assert.equal(result.status, 200, `${name} can sign in`);
        sessions[name] = result.body.data.token;
        return result.body.data.user;
    };
    let lecturerId, studentId, activityId, qr, registrationId;
    const activity = {
        category_id: 1, zone_id: 1, title: 'Shared workflow workshop', location: 'E4',
        start_at: '2099-01-01T10:00:00Z', end_at: '2099-01-01T12:00:00Z',
        points: 75, max_participants: 10, status: 'draft',
    };
    try {
        await t.test('admin creates a lecturer who must change the temporary password', async () => {
            await login('admin', 'admin@workflow.invalid');
            const created = await request('admin', 'POST', '/api/admin/lecturers', {
                full_name: 'Activity Organizer', email: 'lecturer@workflow.invalid', password,
            });
            assert.equal(created.status, 201);
            lecturerId = created.body.data.user_id;
            assert.equal((await login('lecturer', 'lecturer@workflow.invalid')).must_change_password, true);
            assert.equal((await request('lecturer', 'GET', '/api/lecturer/dashboard')).status, 403);
            assert.equal((await request('lecturer', 'PATCH', '/api/auth/change-password', {
                current_password: password, new_password: changedPassword, confirm_password: changedPassword,
            })).status, 200);
            assert.equal((await login('lecturer', 'lecturer@workflow.invalid', changedPassword)).must_change_password, false);
            assert.equal((await request('lecturer', 'GET', '/api/lecturer/dashboard')).status, 200);
            await login('otherLecturer', 'other@workflow.invalid');
            for (const [name, code] of [['student', 'S-1'], ['otherStudent', 'S-2']]) {
                assert.equal((await request(null, 'POST', '/api/auth/register', {
                    student_code: code, full_name: name, email: `${name}@workflow.invalid`, password,
                })).status, 201);
                const user = await login(name, `${name}@workflow.invalid`);
                if (name === 'student') studentId = user.user_id;
            }
        });
        await t.test('only admins configure categories and campus network ranges used by the other roles', async () => {
            assert.equal((await request('admin', 'GET', '/api/admin/settings')).status, 200);
            for (const role of ['lecturer', 'otherLecturer', 'student', 'otherStudent']) {
                assert.equal((await request(role, 'GET', '/api/admin/settings')).status, 403);
                assert.equal((await request(role, 'POST', '/api/admin/settings/categories', { category_name: 'Forbidden' })).status, 403);
                assert.equal((await request(role, 'DELETE', '/api/admin/settings/ips/1')).status, 403);
            }
            const category = await request('admin', 'POST', '/api/admin/settings/categories', { category_name: 'ZZ Student Services' });
            assert.equal(category.status, 201);
            const categoryId = category.body.data.id;
            assert.equal((await request('admin', 'POST', '/api/admin/settings/categories', { category_name: 'zz student services' })).status, 409);
            assert.equal((await request('admin', 'PATCH', `/api/admin/settings/categories/${categoryId}`, { is_active: false })).status, 200);
            let options = (await request('lecturer', 'GET', '/api/activities/options')).body.data;
            assert.equal(options.categories.some(row => row.category_id === categoryId), false);
            assert.equal((await request('admin', 'PATCH', `/api/admin/settings/categories/${categoryId}`, { is_active: true })).status, 200);
            options = (await request('lecturer', 'GET', '/api/activities/options')).body.data;
            assert.equal(options.categories.some(row => row.category_id === categoryId), true);

            const zone = await request('admin', 'POST', '/api/admin/settings/zones', { zone_name: 'ZZ Additional Campus', is_active: true });
            assert.equal(zone.status, 201);
            const zoneId = zone.body.data.id;
            const createdIp = await request('admin', 'POST', '/api/admin/settings/ips', { zone_id: zoneId, ip_range: '198.51.100.45/24' });
            assert.equal(createdIp.status, 201);
            const ipId = createdIp.body.data.id;
            let saved = (await request('admin', 'GET', '/api/admin/settings')).body.data;
            assert.equal(saved.allowed_ips.find(row => row.ip_id === ipId).ip_range, '198.51.100.0/24');
            assert.equal((await request('admin', 'POST', '/api/admin/settings/ips', { zone_id: zoneId, ip_range: '198.51.100.22/24' })).status, 409);
            for (const invalid of ['256.0.0.1', '198.51.100.1/33', '0.0.0.0/0', 'not-an-ip']) {
                assert.equal((await request('admin', 'POST', '/api/admin/settings/ips', { zone_id: zoneId, ip_range: invalid })).status, 400);
            }
            assert.equal((await request('admin', 'POST', '/api/admin/settings/ips', { zone_id: 99999, ip_range: '198.51.100.1' })).status, 400);
            assert.equal((await request('admin', 'POST', '/api/admin/settings/ips', { zone_id: true, ip_range: '198.51.100.1' })).status, 400);
            assert.equal((await request('admin', 'PATCH', `/api/admin/settings/categories/${categoryId}`, { is_active: null })).status, 400);
            assert.equal((await request('admin', 'PATCH', '/api/admin/settings/zones/99999', { is_active: false })).status, 404);

            // Network settings remain editable; attendance now works on any network.
            assert.equal((await request('admin', 'PATCH', `/api/admin/settings/ips/${ipId}`, { ip_range: '127.0.0.1' })).status, 200);
            process.env.WIFI_MOCK_MODE = 'false';
            try {
                assert.equal((await request('student', 'POST', '/api/checkins', { activity_id: 99999, token: 'test' })).status, 404);
                assert.equal((await request('admin', 'PATCH', `/api/admin/settings/zones/${zoneId}`, { is_active: false })).status, 200);
                assert.equal((await request('student', 'POST', '/api/checkins', { activity_id: 99999, token: 'test' })).status, 404);
                options = (await request('lecturer', 'GET', '/api/activities/options')).body.data;
                assert.equal(options.zones.some(row => row.zone_id === zoneId), false);
                assert.equal((await request('admin', 'DELETE', `/api/admin/settings/ips/${ipId}`)).status, 200);
                saved = (await request('admin', 'GET', '/api/admin/settings')).body.data;
                assert.equal(saved.allowed_ips.some(row => row.ip_id === ipId), false);
            } finally { process.env.WIFI_MOCK_MODE = 'false'; }
        });
        await t.test('staff upload validated activity images, students cannot upload, and the cover persists across roles', async () => {
            const image = await sharp({ create: { width: 2000, height: 1200, channels: 3, background: '#1258b8' } }).png().toBuffer();
            assert.equal((await request('student', 'POST', '/api/activities/image', { image: image.toString('base64') })).status, 403);
            assert.equal((await request('lecturer', 'POST', '/api/activities/image', { image: 'invalid image' })).status, 400);
            assert.equal((await request('lecturer', 'POST', '/api/activities/image', { image: Buffer.from('<svg/>').toString('base64') })).status, 400);
            assert.equal((await request('lecturer', 'POST', '/api/activities/image', { image: 'a'.repeat(4 * 1024 * 1024 + 4) })).status, 413);
            const uploaded = await request('lecturer', 'POST', '/api/activities/image', { image: image.toString('base64') });
            assert.equal(uploaded.status, 201);
            assert.equal(uploads.length, 1);
            const metadata = await sharp(uploads[0].buffer).metadata();
            assert.equal(metadata.format, 'jpeg');
            assert.ok(metadata.width <= 1600);
            assert.ok(metadata.height <= 1000);
            assert.equal(uploads[0].options.contentType, 'image/jpeg');
            activity.cover_image = uploaded.body.data.url;
        });
        await t.test('lecturer publishes an activity using shared category and zone options', async () => {
            const options = await request('lecturer', 'GET', '/api/activities/options');
            assert.equal(options.status, 200);
            assert.equal(options.body.data.categories[0].category_name, 'Workshop');
            assert.equal(options.body.data.zones[0].zone_name, 'Campus');
            assert.equal((await request('student', 'GET', '/api/activities/options')).status, 403);
            const created = await request('lecturer', 'POST', '/api/activities', activity);
            assert.equal(created.status, 201);
            activityId = created.body.data.activity_id;
            assert.equal(created.body.data.organizer_id, lecturerId);
            assert.equal((await request('student', 'POST', `/api/registrations/${activityId}`)).status, 400);
            assert.equal((await request('lecturer', 'POST', `/api/qr/${activityId}`, {
                starts_at: '2000-01-01T00:00:00Z', expires_at: '2099-01-01T00:00:00Z',
            })).status, 400);
            assert.equal((await request('lecturer', 'PUT', `/api/activities/${activityId}`, { ...activity, status: 'published' })).status, 200);
            const visible = await request('student', 'GET', '/api/activities');
            assert.equal(visible.body.data.find(row => row.activity_id === activityId).status, 'published');
            assert.equal(visible.body.data.find(row => row.activity_id === activityId).cover_image, activity.cover_image);
            assert.equal((await request('admin', 'GET', `/api/activities/${activityId}`)).body.data.cover_image, activity.cover_image);
            assert.equal((await request('lecturer', 'GET', '/api/lecturer/dashboard')).body.data.activities[0].cover_image, activity.cover_image);
            assert.equal((await request('otherLecturer', 'PUT', `/api/activities/${activityId}`, activity)).status, 403);
            assert.equal((await request('otherLecturer', 'GET', `/api/lecturer/activities/${activityId}/participants`)).status, 404);
            assert.equal((await request('otherLecturer', 'POST', `/api/qr/${activityId}`, {})).status, 403);
        });
        await t.test('registration, cancellation and rejoining appear in the organizer attendance list', async () => {
            const registered = await request('student', 'POST', `/api/registrations/${activityId}`);
            assert.equal(registered.status, 201);
            registrationId = registered.body.data.registration_id;
            assert.equal((await request('student', 'POST', `/api/registrations/${activityId}`)).status, 409);
            assert.equal((await request('student', 'GET', '/api/registrations/my')).body.data[0].activity_id, activityId);
            assert.equal((await request('otherStudent', 'GET', '/api/registrations/my')).body.data.length, 0);
            let list = await request('lecturer', 'GET', `/api/lecturer/activities/${activityId}/participants`);
            assert.equal(list.body.data[0].user_id, studentId);
            assert.equal(list.body.data[0].registration_status, 'registered');
            assert.equal((await request('student', 'DELETE', `/api/registrations/${activityId}`)).status, 200);
            list = await request('lecturer', 'GET', `/api/lecturer/activities/${activityId}/participants`);
            assert.equal(list.body.data[0].registration_status, 'cancelled');
            const afterCancel = (await request('lecturer', 'GET', '/api/lecturer/dashboard')).body.data.activities[0];
            assert.equal(Number(afterCancel.total_registrations), 0);
            assert.equal(afterCancel.location, activity.location);
            const rejoined = await request('student', 'POST', `/api/registrations/${activityId}`);
            assert.equal(rejoined.status, 200);
            assert.equal(rejoined.body.data.registration_id, registrationId);
            assert.equal(Number((await request('lecturer', 'GET', '/api/lecturer/dashboard')).body.data.activities[0].total_registrations), 1);
        });
        await t.test('QR photos and registration allow attendance on any network and award points exactly once', async () => {
            assert.deepEqual((await request('student', 'GET', '/api/qr/alerts')).body.data, []);
            assert.equal((await request('lecturer', 'POST', `/api/qr/${activityId}`, {
                starts_at: 'bad date', expires_at: 'also bad',
            })).status, 400);
            const generated = await request('lecturer', 'POST', `/api/qr/${activityId}`, {
                starts_at: '2000-01-01T00:00:00Z', expires_at: '2099-01-01T00:00:00Z',
            });
            assert.equal(generated.status, 201);
            qr = { activity_id: activityId, token: generated.body.data.token };
            const checkInLink = `https://mfu333-app.vercel.app/#/check-in?activity_id=${activityId}&token=${qr.token}`;
            const qrImage = await QRCode.toBuffer(checkInLink, { width: 600, margin: 4 });
            const read = await request('student', 'POST', '/api/checkins/read-qr', { image: qrImage.toString('base64') });
            assert.equal(read.status, 200);
            assert.equal(read.body.data.payload, checkInLink);
            assert.equal((await request('student', 'GET', '/api/points/my')).body.data.total_points, 0, 'reading an image does not check in');
            assert.equal((await request('lecturer', 'POST', '/api/checkins/read-qr', { image: qrImage.toString('base64') })).status, 403);
            const blank = await sharp({ create: { width: 100, height: 100, channels: 3, background: '#ffffff' } }).png().toBuffer();
            assert.equal((await request('student', 'POST', '/api/checkins/read-qr', { image: blank.toString('base64') })).status, 400);
            const saved = await request('lecturer', 'GET', `/api/qr/${activityId}`);
            assert.equal(saved.status, 200);
            assert.equal(saved.body.data[0].token, qr.token, 'saved code can be redrawn after a new request');
            assert.equal(saved.body.data[0].qr_id, generated.body.data.qr_id);
            assert.ok(!('token_hash' in saved.body.data[0]));
            assert.equal((await request('admin', 'GET', `/api/qr/${activityId}`)).body.data[0].token, qr.token);
            assert.equal((await request('otherLecturer', 'GET', `/api/qr/${activityId}`)).status, 403);
            assert.equal((await request('student', 'GET', `/api/qr/${activityId}`)).status, 403);
            for (const student of ['student', 'otherStudent']) {
                const alerts = await request(student, 'GET', '/api/qr/alerts');
                assert.equal(alerts.status, 200);
                assert.equal(alerts.body.data[0].activity_id, activityId);
                assert.equal(alerts.body.data[0].activity_title, activity.title);
                assert.equal(alerts.body.data[0].qr_id, generated.body.data.qr_id);
                assert.ok(!('token' in alerts.body.data[0]));
                assert.ok(!('token_hash' in alerts.body.data[0]));
            }
            assert.equal((await request('lecturer', 'GET', '/api/qr/alerts')).status, 403);
            assert.equal((await request('otherStudent', 'POST', '/api/checkins', qr)).status, 403);
            process.env.WIFI_MOCK_MODE = 'false';
            assert.equal((await request('student', 'POST', '/api/checkins', { ...qr, token: 'invalid' })).status, 400);
            const checkedIn = await request('student', 'POST', '/api/checkins', qr);
            assert.equal(checkedIn.status, 201);
            assert.equal(checkedIn.body.data.points, 75);
            assert.equal((await engine.query('SELECT verified_ip FROM activity_checkins WHERE user_id = $1', [studentId])).rows[0].verified_ip, '127.0.0.1');
            assert.equal((await request('student', 'POST', '/api/checkins', qr)).status, 409);
        });
        await t.test('legacy QR codes remain visible and valid, while unavailable codes are excluded from student alerts', async () => {
            const crypto = require('node:crypto');
            const legacy = 'older-printed-qr';
            const inserted = await engine.query(
                `INSERT INTO qr_tokens (activity_id, token_hash, starts_at, expires_at)
                 VALUES ($1, $2, '2000-01-01', '2099-01-01') RETURNING qr_id`,
                [activityId, crypto.createHash('sha256').update(legacy).digest('hex')]
            );
            const id = inserted.rows[0].qr_id;
            const saved = (await request('lecturer', 'GET', `/api/qr/${activityId}`)).body.data;
            assert.equal(saved.find(row => row.qr_id === id).token, null);
            assert.ok(await require('../src/services/qrService').verifyActivityQr(legacy, activityId));
            assert.ok(await require('../src/services/qrService').verifyActivityQr(qr.token, activityId));
            const key = process.env.JWT_SECRET;
            try {
                process.env.JWT_SECRET = 'rotated-test-key';
                assert.equal((await require('../src/services/qrService').listActivityQr(activityId)).find(row => row.token !== null), undefined);
                assert.ok(await require('../src/services/qrService').verifyActivityQr(qr.token, activityId));
                delete process.env.JWT_SECRET;
                const before = (await engine.query('SELECT COUNT(*) AS count FROM qr_tokens')).rows[0].count;
                await assert.rejects(require('../src/services/qrService').createActivityQr(activityId, '2000-01-01', '2099-01-01'));
                assert.equal((await engine.query('SELECT COUNT(*) AS count FROM qr_tokens')).rows[0].count, before, 'failed creation rolls back both the QR and its alert');
            } finally { process.env.JWT_SECRET = key; }
            await engine.query('UPDATE qr_tokens SET is_active = 0 WHERE qr_id = $1', [id]);
            assert.ok(!(await request('student', 'GET', '/api/qr/alerts')).body.data.some(row => row.qr_id === id));
            await engine.query("UPDATE qr_tokens SET is_active = 1, expires_at = '2001-01-01' WHERE qr_id = $1", [id]);
            assert.ok(!(await request('student', 'GET', '/api/qr/alerts')).body.data.some(row => row.qr_id === id));
            await engine.query("UPDATE activities SET status = 'draft' WHERE activity_id = $1", [activityId]);
            assert.deepEqual((await request('student', 'GET', '/api/qr/alerts')).body.data, []);
            await engine.query("UPDATE activities SET status = 'published' WHERE activity_id = $1", [activityId]);
        });
        await t.test('student points, lecturer attendance and admin summaries agree on the same check-in', async () => {
            assert.equal((await request('student', 'GET', '/api/points/my')).body.data.total_points, 75);
            const history = await request('student', 'GET', '/api/points/history');
            assert.equal(history.body.data.length, 1);
            assert.equal(history.body.data[0].activity_title, activity.title);
            assert.equal((await request('otherStudent', 'GET', '/api/points/my')).body.data.total_points, 0);
            assert.equal((await request('otherStudent', 'GET', '/api/points/history')).body.data.length, 0);
            const participants = (await request('lecturer', 'GET', `/api/lecturer/activities/${activityId}/participants`)).body.data;
            assert.equal(participants[0].registration_status, 'attended');
            assert.ok(participants[0].checked_in_at);
            assert.equal(participants[0].full_name, 'student');
            assert.equal(participants[0].email, 'student@workflow.invalid');
            assert.equal(Number(participants[0].total_points), 75);
            const students = (await request('admin', 'GET', '/api/admin/users?role=student')).body.data;
            const student = students.find((row) => row.email === 'student@workflow.invalid');
            assert.equal(student.student_code, 'S-1');
            assert.equal(Number(student.total_points), 75);
            const lecturerStudents = (await request('lecturer', 'GET', '/api/lecturer/students')).body.data;
            const lecturerStudent = lecturerStudents.find((row) => row.email === 'student@workflow.invalid');
            assert.equal(lecturerStudent.student_code, 'S-1');
            assert.equal(Number(lecturerStudent.total_points), 75);
            const stats = (await request('lecturer', 'GET', '/api/lecturer/dashboard')).body.data;
            assert.equal(Number(stats.activities[0].total_attended), 1);
            const summary = (await request('admin', 'GET', '/api/admin/dashboard')).body.data;
            assert.equal(Number(summary.checkins.successful_checkins), 1);
            assert.equal(Number(summary.points.total_points_awarded), 75);
            assert.equal((await request('lecturer', 'PATCH', `/api/lecturer/activities/${activityId}/status`, { status: 'completed' })).status, 200);
            assert.deepEqual((await request('student', 'GET', '/api/qr/alerts')).body.data, []);
            assert.ok((await request('lecturer', 'GET', `/api/qr/${activityId}`)).body.data.length > 0);
            assert.equal((await request('otherStudent', 'POST', `/api/registrations/${activityId}`)).status, 400);
            assert.equal((await request('otherStudent', 'POST', '/api/checkins', qr)).status, 400);
        });
        await t.test('a second student can join an ongoing activity and check in from an unmatched network', async () => {
            assert.equal((await request('lecturer', 'PATCH', `/api/lecturer/activities/${activityId}/status`, { status: 'ongoing' })).status, 200);
            assert.equal((await request('otherStudent', 'POST', `/api/registrations/${activityId}`)).status, 201);
            assert.equal((await request('otherStudent', 'POST', '/api/checkins', qr)).status, 201);
            assert.equal((await request('otherStudent', 'GET', '/api/points/my')).body.data.total_points, 75);
            assert.equal(Number((await request('admin', 'GET', '/api/admin/dashboard')).body.data.points.total_points_awarded), 150);
            assert.equal((await request('lecturer', 'PATCH', `/api/lecturer/activities/${activityId}/status`, { status: 'completed' })).status, 200);
        });
        await t.test('admin deactivation applies to existing sessions without changing attendance history', async () => {
            assert.equal((await request('admin', 'PATCH', `/api/admin/users/${studentId}/status`, { is_active: false })).status, 200);
            assert.equal((await request('student', 'GET', '/api/points/my')).status, 401);
            assert.equal((await request('admin', 'PATCH', `/api/admin/users/${studentId}/status`, { is_active: true })).status, 200);
            await login('student', 'student@workflow.invalid');
            assert.equal((await request('student', 'GET', '/api/points/my')).body.data.total_points, 75);
            assert.equal((await request('student', 'GET', '/api/admin/users')).status, 403);
            assert.equal((await request('lecturer', 'GET', '/api/points/history')).status, 403);
            assert.equal((await request('admin', 'GET', '/api/registrations/my')).status, 403);
        });
    } finally {
        await new Promise(resolve => server.close(resolve));
        await engine.close();
    }
});
