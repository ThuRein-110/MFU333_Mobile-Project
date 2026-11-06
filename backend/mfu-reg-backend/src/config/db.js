require("dotenv").config({ quiet: true });

const { databaseOptions, databaseDialect } = require("./databaseOptions");

let db;
if (databaseDialect() === "postgres") {
    const { Pool, types } = require("pg");
    const { createPostgresAdapter, postgresOptions } = require("./postgresAdapter");
    // The app's counts and point totals are small integers, as in the MySQL API.
    types.setTypeParser(20, (value) => Number.isSafeInteger(Number(value)) ? Number(value) : value);
    types.setTypeParser(1114, (value) => new Date(`${value.replace(" ", "T")}Z`));
    const pool = new Pool(postgresOptions(databaseOptions()));
    pool.on("error", (error) => console.error("Database pool error:", error.code || "unknown"));
    db = createPostgresAdapter(pool);
} else {
    db = require("mysql2/promise").createPool(databaseOptions());
}

module.exports = db;
