const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const { PGlite } = require("@electric-sql/pglite");
const { importPostgres } = require("../scripts/import-postgres");
const { parseMysqlDump } = require("../scripts/parse-mysql-dump");
const { createPostgresAdapter, prepareQuery } = require("../src/config/postgresAdapter");
const { databaseOptions, databaseDialect } = require("../src/config/databaseOptions");

const value = (item) => item === null ? "NULL" : typeof item === "number" ? String(item)
    : `'${item.replace(/\\/g, "\\\\").replace(/'/g, "\\'")}'`;
const insert = (table, columns, rows) => `INSERT INTO \`${table}\` (${columns.map((name) => `\`${name}\``).join(", ")}) VALUES ${rows.map((row) => `(${row.map(value).join(", ")})`).join(",\n")};`;
const fixture = (organizer = 2) => [
    insert("users", ["user_id", "student_code", "full_name", "email", "password_hash", "role"], [
        [1, null, "Admin", "admin@example.invalid", "fixture-hash", "admin"],
        [2, null, "Lecturer", "lecturer@example.invalid", "fixture-hash", "lecturer"],
        [3, "S-3", "Student", "student@example.invalid", "fixture-hash", "student"]
    ]),
    insert("activity_categories", ["category_id", "category_name"], [[1, "Workshop"]]),
    insert("network_zones", ["zone_id", "zone_name"], [[1, "Campus"]]),
    insert("allowed_ips", ["ip_id", "zone_id", "ip_range"], [[1, 1, "10.20.0.0/16"]]),
    insert("activities", ["activity_id", "organizer_id", "category_id", "title", "location", "start_at", "end_at", "status", "points"],
        [[1, organizer, 1, "กิจกรรม; O'Brien? \\ campus", "E4", "2099-01-01 10:00:00", "2099-01-01 12:00:00", "published", 100]]),
    insert("qr_tokens", ["qr_id", "activity_id", "token_hash", "starts_at", "expires_at"],
        [[1, 1, "fixture-token-hash", "2000-01-01 00:00:00", "2099-01-02 00:00:00"]]),
    "ALTER TABLE `users` MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;"
].join("\n");

// Run the production SQL against an embedded PostgreSQL engine, without a
// separately installed database server. Only the network transport is replaced.
const openDatabase = async () => {
    const engine = new PGlite();
    const client = {
        async query(sql, params) {
            if (sql.startsWith("CREATE TABLE users")) {
                await engine.exec(sql);
                return { rows: [], rowCount: 0, command: "CREATE" };
            }
            const result = await engine.query(sql, params);
            return { ...result, rowCount: result.affectedRows || 0, command: sql.trim().split(/\s+/)[0].toUpperCase() };
        },
        release() {}
    };
    return { engine, client, pool: { ...client, connect: async () => client, end: () => engine.close() } };
};

test("PostgreSQL URIs use the right port and retain verified TLS despite sslmode in the URL", () => {
    const env = { DATABASE_URL: "postgres://avnadmin:p%23%2F@example.invalid/defaultdb?sslmode=require", DB_SSL_CA: "certificate" };
    assert.equal(databaseDialect(env), "postgres");
    const config = databaseOptions(env);
    assert.equal(config.port, 5432);
    assert.equal(config.password, "p#/");
    assert.deepEqual(config.ssl, { rejectUnauthorized: true, ca: "certificate" });
});

test("query parameters remain bound when strings or comments contain question marks", () => {
    const { text } = prepareQuery("SELECT '?' AS literal, user_id FROM users WHERE email = ? -- ?\n AND user_id = ?");
    assert.equal(text, "SELECT '?' AS literal, user_id FROM users WHERE email = $1 -- ?\n AND user_id = $2");
});

test("dump parser preserves Thai, SQL punctuation and MySQL string escapes as data", () => {
    const parsed = parseMysqlDump(fixture());
    assert.equal(parsed.inserts.find((item) => item.table === "activities").rows[0][3], "กิจกรรม; O'Brien? \\ campus");
    assert.equal(parsed.nextIds.users, 10);
});

test("PostgreSQL import rolls back schema and data together on invalid foreign keys", async () => {
    const { engine, client } = await openDatabase();
    try {
        await assert.rejects(importPostgres(client, fixture(999)), (error) => error.code === "23503");
        const tables = await client.query("SELECT tablename FROM pg_tables WHERE schemaname = current_schema()");
        assert.equal(tables.rows.length, 0);
    } finally { await engine.close(); }
});

test("supplied SQL dump preserves every inserted value and all nine tables", { skip: !process.env.MFU_SQL_DUMP }, async () => {
    const source = await fs.readFile(process.env.MFU_SQL_DUMP, "utf8");
    const parsed = parseMysqlDump(source);
    const { engine, client } = await openDatabase();
    try {
        const counts = await importPostgres(client, source);
        assert.equal(Object.keys(counts).length, 9);
        for (const item of parsed.inserts) {
            // Compare stored wall-clock timestamps as SQL text. The embedded
            // client's local Date parser differs from the production UTC parser.
            const selected = item.columns.map((column) =>
                /(?:_at$|registration_deadline$)/.test(column)
                    ? `"${column}"::text AS "${column}"` : `"${column}"`).join(", ");
            const rows = (await client.query(`SELECT ${selected} FROM "${item.table}"`)).rows;
            assert.equal(rows.length, item.rows.length);
            const id = item.columns[0];
            for (const expected of item.rows) {
                const actual = rows.find((row) => row[id] === expected[0]);
                assert.ok(Boolean(actual), "Imported primary key is present");
                item.columns.forEach((column, index) => {
                    const found = actual[column];
                    const wanted = found instanceof Date ? new Date(`${expected[index].replace(" ", "T")}Z`).toISOString() : expected[index];
                    // Boolean comparison avoids printing personal data or password hashes on failure.
                    assert.ok((found instanceof Date ? found.toISOString() : found) === wanted, `Preserved value in ${item.table}.${column}`);
                });
            }
        }
        await assert.rejects(importPostgres(client, source), /must be empty/);
        assert.equal(Number((await client.query("SELECT COUNT(*) AS total FROM users")).rows[0].total), counts.users);
    } finally { await engine.close(); }
});

test("PostgreSQL supports authentication, registration, atomic check-in, points and dashboards", async (t) => {
    const { engine, client, pool } = await openDatabase();
    await importPostgres(client, fixture());
    const db = createPostgresAdapter(pool);
    const dbPath = require.resolve("../src/config/db");
    require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };
    process.env.JWT_SECRET = "postgres-integration-test-secret";
    const app = require("../server");
    const server = app.listen(0, "127.0.0.1");
    await new Promise((resolve) => server.once("listening", resolve));
    const base = `http://127.0.0.1:${server.address().port}`;
    let studentId, token, registrationId;
    const request = async (path, method = "GET", body, authorization = token) => {
        const response = await fetch(base + path, {
            method,
            headers: { "Content-Type": "application/json", ...(authorization ? { Authorization: `Bearer ${authorization}` } : {}) },
            body: body ? JSON.stringify(body) : undefined
        });
        return { status: response.status, data: await response.json() };
    };
    try {
        await t.test("new users receive preserved sequence IDs and can log in without email case sensitivity", async () => {
            const result = await request("/api/auth/register", "POST", { student_code: "S-10", full_name: "Browser Test", email: "Browser@example.invalid", password: "Test-only-Password-27" });
            assert.equal(result.status, 201);
            studentId = result.data.data.user_id;
            assert.equal(studentId, 10);
            const login = await request("/api/auth/login", "POST", { email: "browser@example.invalid", password: "Test-only-Password-27" });
            assert.equal(login.status, 200);
            token = login.data.data.token;
            assert.equal(login.data.data.user.role, "student");
            assert.equal((await request("/api/activities")).status, 200);
        });
        const registrationModel = require("../src/models/registrationModel");
        const checkinModel = require("../src/models/checkinModel");
        await t.test("registration IDs, duplicate checks and rollback preserve attendance and points", async () => {
            registrationId = await registrationModel.createRegistration(1, studentId);
            assert.ok(Number.isInteger(registrationId));
            await assert.rejects(registrationModel.createRegistration(1, studentId), (error) => error.code === "ER_DUP_ENTRY");
            assert.equal(Number(await registrationModel.countRegistrations(1)), 1);
            await assert.rejects(checkinModel.createCheckin({ activityId: 1, userId: studentId, registrationId, qrId: 1, verifiedIp: "10.20.5.25", points: "invalid" }));
            assert.equal((await registrationModel.findRegistration(1, studentId)).status, "registered");
            assert.equal((await client.query("SELECT COUNT(*) AS total FROM activity_checkins")).rows[0].total, 0);
            const checkin = await checkinModel.createCheckin({ activityId: 1, userId: studentId, registrationId, qrId: 1, verifiedIp: "10.20.5.25", points: 100 });
            assert.ok(Number.isInteger(checkin.checkin_id));
            assert.equal((await registrationModel.findRegistration(1, studentId)).status, "attended");
            assert.equal(Number(await require("../src/models/pointModel").getMyPoints(studentId)), 100);
        });
        await t.test("lecturer first-login flags, search and aggregate dashboards work", async () => {
            const users = require("../src/models/userModel");
            const lecturerId = await users.createLecturer("Another Lecturer", "another@example.invalid", "fixture-hash");
            assert.equal((await users.findUserById(lecturerId)).must_change_password, 1);
            await users.changePassword(lecturerId, "new-fixture-hash");
            assert.equal((await users.findUserById(lecturerId)).must_change_password, 0);
            const admin = require("../src/models/adminModel");
            assert.equal((await admin.getAllUsers("BROWSER", "student")).length, 1);
            const summary = await admin.getDashboardSummary();
            assert.equal(Number(summary.checkins.total_checkins), 1);
            assert.equal(Number(summary.points.total_points_awarded), 100);
            const lecturer = require("../src/models/lecturerModel");
            assert.equal((await lecturer.getMyActivityStats(2)).published_activities, 1);
            assert.equal((await lecturer.getMyActivities(2)).length, 1);
        });
    } finally {
        await new Promise((resolve) => server.close(resolve));
        await engine.close();
    }
});
