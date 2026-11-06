const fs = require("node:fs/promises");
const path = require("node:path");
const { parseMysqlDump } = require("./parse-mysql-dump");
const { idColumns, postgresOptions } = require("../src/config/postgresAdapter");

const tableOrder = ["users", "activity_categories", "network_zones", "allowed_ips", "activities",
    "activity_registrations", "qr_tokens", "activity_checkins", "point_transactions"];
const quote = (name) => `"${name.replace(/"/g, '""')}"`;

// Use one PostgreSQL client for the entire transaction, including schema creation.
const importPostgres = async (client, source) => {
    const parsed = parseMysqlDump(source);
    if (parsed.inserts.some(({ table }) => !Object.hasOwn(idColumns, table))) {
        throw new Error("The dump contains a table outside the MFU333 schema");
    }
    await client.query("BEGIN");
    try {
        const existing = await client.query("SELECT tablename FROM pg_tables WHERE schemaname = current_schema()");
        if (existing.rows.length) throw new Error("Import stopped: the target database must be empty. Existing data was not changed.");
        const schema = await fs.readFile(path.join(__dirname, "schema-postgres.sql"), "utf8");
        await client.query(schema);
        const counts = {};
        for (const table of tableOrder) {
            for (const insert of parsed.inserts.filter((item) => item.table === table)) {
                const names = insert.columns.map(quote).join(", ");
                const placeholders = insert.columns.map((_, i) => `$${i + 1}`).join(", ");
                for (const row of insert.rows) {
                    await client.query(`INSERT INTO ${quote(table)} (${names}) VALUES (${placeholders})`, row);
                }
            }
            const id = idColumns[table];
            const result = await client.query(`SELECT COUNT(*) AS total, COALESCE(MAX(${quote(id)}),0) AS max_id FROM ${quote(table)}`);
            counts[table] = Number(result.rows[0].total);
            const next = Math.max(Number(result.rows[0].max_id) + 1, parsed.nextIds[table] || 1);
            await client.query("SELECT setval(pg_get_serial_sequence($1, $2), $3, false)", [table, id, next]);
        }
        await client.query("COMMIT");
        return counts;
    } catch (error) {
        await client.query("ROLLBACK");
        throw error;
    }
};

const main = async () => {
    require("dotenv").config({ quiet: true });
    const { databaseOptions, databaseDialect } = require("../src/config/databaseOptions");
    if (databaseDialect() !== "postgres") throw new Error("Set DATABASE_URL to your PostgreSQL Service URI first");
    const filename = process.argv[2];
    if (!filename) throw new Error('Usage: npm run db:import:postgres -- "/path/to/database.sql"');
    const source = await fs.readFile(filename, "utf8");
    const { Client } = require("pg");
    const client = new Client(postgresOptions(databaseOptions()));
    await client.connect();
    try {
        console.log("PostgreSQL import complete. Row counts:", JSON.stringify(await importPostgres(client, source)));
    } finally {
        await client.end();
    }
};

if (require.main === module) {
    main().catch((error) => {
        console.error("PostgreSQL import failed:", error.code || error.message);
        process.exitCode = 1;
    });
}

module.exports = { importPostgres };
