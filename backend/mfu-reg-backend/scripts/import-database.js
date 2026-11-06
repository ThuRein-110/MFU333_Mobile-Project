const fs = require("node:fs/promises");

// phpMyAdmin adds primary keys after INSERTs. Hosted MySQL may require them
// on CREATE, so move only those declarations into their original tables.
const prepareDump = (source) => {
    const primaryKeys = new Map();
    const withoutLateKeys = source.replace(
        /ALTER TABLE `([^`]+)`\s+([\s\S]*?);/g,
        (statement, table, clauses) => {
            const key = clauses.match(/ADD PRIMARY KEY\s*(\([^)]*\))\s*(,\s*)?/i);
            if (!key) return statement;
            primaryKeys.set(table, key[1]);
            const remaining = clauses.replace(key[0], "").trim().replace(/,\s*$/, "");
            return remaining ? `ALTER TABLE \`${table}\` ${remaining};` : "";
        }
    );

    return withoutLateKeys.replace(
        /CREATE TABLE `([^`]+)`\s*\(([\s\S]*?)\)\s*(ENGINE=[^;]*);/g,
        (statement, table, columns, options) => {
            const key = primaryKeys.get(table);
            return key
                ? `CREATE TABLE \`${table}\` (${columns.trimEnd()},\n  PRIMARY KEY ${key}\n) ${options};`
                : statement;
        }
    );
};

const importDatabase = async (connection, source) => {
    const [existing] = await connection.query("SHOW TABLES");
    if (existing.length > 0) {
        throw new Error("Import stopped: the target database must be empty. Existing data was not changed.");
    }

    const tables = [...source.matchAll(/CREATE TABLE `([^`]+)`/g)].map((match) => match[1]);
    if (tables.length === 0) throw new Error("No CREATE TABLE statements found in the SQL file.");

    await connection.query(prepareDump(source));

    const counts = {};
    for (const table of tables) {
        const [rows] = await connection.query(`SELECT COUNT(*) AS total FROM ${connection.escapeId(table)}`);
        counts[table] = Number(rows[0].total);
    }
    return counts;
};

const main = async () => {
    require("dotenv").config({ quiet: true });
    const mysql = require("mysql2/promise");
    const { databaseOptions } = require("../src/config/databaseOptions");
    const filename = process.argv[2];
    if (!filename) throw new Error('Usage: npm run db:import -- "/path/to/database.sql"');
    if (!process.env.DATABASE_URL && !process.env.DB_HOST) {
        throw new Error("Set DATABASE_URL in the local .env file before importing.");
    }

    const source = await fs.readFile(filename, "utf8");
    const options = databaseOptions();
    // Multiple statements are enabled only in this one-time, local import tool.
    const connection = await mysql.createConnection({
        host: options.host,
        port: options.port,
        user: options.user,
        password: options.password,
        database: options.database,
        ssl: options.ssl,
        connectTimeout: options.connectTimeout,
        multipleStatements: true
    });

    try {
        const counts = await importDatabase(connection, source);
        console.log("SQL import complete. Row counts:", JSON.stringify(counts));
    } finally {
        await connection.end();
    }
};

if (require.main === module) {
    main().catch((error) => {
        console.error(`SQL import failed${error.code ? ` (${error.code})` : ""}: ${error.message}`);
        console.error("MySQL schema changes are not transactional; inspect the target before retrying a failed import.");
        process.exitCode = 1;
    });
}

module.exports = { prepareDump, importDatabase };
