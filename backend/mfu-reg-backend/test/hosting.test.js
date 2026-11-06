const { test, after } = require("node:test");
const assert = require("node:assert/strict");
const { databaseOptions } = require("../src/config/databaseOptions");
const { prepareDump, importDatabase } = require("../scripts/import-database");

test("hosted URI preserves encoded credentials and verifies the provider certificate", () => {
    const options = databaseOptions({
        DATABASE_URL: "mysql://test%40user:p%23%2F%25@example.invalid:25060/defaultdb?ssl-mode=REQUIRED",
        DB_SSL_CA: "first\\nsecond"
    });
    assert.equal(options.user, "test@user");
    assert.equal(options.password, "p#/%");
    assert.equal(options.database, "defaultdb");
    assert.equal(options.port, 25060);
    assert.deepEqual(options.ssl, { rejectUnauthorized: true, ca: "first\nsecond" });
    assert.notEqual(options.multipleStatements, true);
});

test("existing local DB settings remain supported without requiring TLS", () => {
    const options = databaseOptions({ DB_HOST: "127.0.0.1", DB_NAME: "mfu_reg333", DB_USER: "root" });
    assert.equal(options.host, "127.0.0.1");
    assert.equal(options.database, "mfu_reg333");
    assert.equal(options.ssl, undefined);
});

test("SQL import refuses a populated database before executing the dump", async () => {
    let queries = 0;
    const connection = { query: async () => { queries++; return [[{ table: "existing" }]]; } };
    await assert.rejects(importDatabase(connection, "CREATE TABLE `users` (id INT);"), /must be empty/);
    assert.equal(queries, 1);
});

test("phpMyAdmin primary keys move before inserts while preserving unique keys and foreign keys", () => {
    const dump = [
        "CREATE TABLE `users` (`id` int NOT NULL, `email` varchar(100)) ENGINE=InnoDB;",
        "INSERT INTO `users` VALUES (1, 'fixture@example.invalid');",
        "ALTER TABLE `users` ADD PRIMARY KEY (`id`), ADD UNIQUE KEY `email` (`email`);",
        "ALTER TABLE `users` MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;",
        "ALTER TABLE `activities` ADD CONSTRAINT `owner` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`);"
    ].join("\n");
    const prepared = prepareDump(dump);
    assert.ok(prepared.indexOf("PRIMARY KEY (`id`)") < prepared.indexOf("INSERT INTO"));
    assert.equal((prepared.match(/PRIMARY KEY/g) || []).length, 1);
    assert.match(prepared, /ALTER TABLE `users` ADD UNIQUE KEY `email`/);
    assert.match(prepared, /AUTO_INCREMENT=2/);
    assert.match(prepared, /FOREIGN KEY/);
});

const app = require("../server");
const db = require("../src/config/db");
const server = app.listen(0, "127.0.0.1");
const ready = new Promise((resolve) => server.once("listening", resolve));
const get = async (path) => {
    await ready;
    return fetch(`http://127.0.0.1:${server.address().port}${path}`);
};

after(async () => {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    await db.end();
});

test("hosting health explicitly reports missing database setup", async () => {
    if (process.env.DATABASE_URL || process.env.DB_HOST) return;
    const response = await get("/api/health");
    assert.equal(response.status, 503);
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.deepEqual(await response.json(), { success: false, database: "not_configured" });
});

test("hosted API keeps authentication on activity routes", async () => {
    const response = await get("/api/activities");
    assert.equal(response.status, 401);
    assert.equal((await response.json()).message, "Access token is required");
});

test("login validates required inputs without a database connection", async () => {
    await ready;
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/auth/login`, {
        method: "POST", headers: { "Content-Type": "application/json" }, body: "{}"
    });
    assert.equal(response.status, 400);
    assert.equal((await response.json()).message, "Email and password are required");
});
