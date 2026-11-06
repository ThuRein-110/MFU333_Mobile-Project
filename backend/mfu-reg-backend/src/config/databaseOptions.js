const fs = require("node:fs");

const databaseDialect = (env = process.env) => {
    const protocol = env.DATABASE_URL ? new URL(env.DATABASE_URL).protocol : "mysql:";
    if (["postgres:", "postgresql:"].includes(protocol)) return "postgres";
    if (protocol === "mysql:") return "mysql";
    throw new Error("DATABASE_URL must use mysql://, postgres:// or postgresql://");
};

const databaseOptions = (env = process.env) => {
    const dialect = databaseDialect(env);
    let connection = {
        host: env.DB_HOST || "127.0.0.1",
        port: Number(env.DB_PORT || 3306),
        user: env.DB_USER,
        password: env.DB_PASSWORD,
        database: env.DB_NAME
    };

    if (env.DATABASE_URL) {
        const url = new URL(env.DATABASE_URL);
        connection = {
            host: url.hostname,
            port: Number(url.port || (dialect === "postgres" ? 5432 : 3306)),
            user: decodeURIComponent(url.username),
            password: decodeURIComponent(url.password),
            database: decodeURIComponent(url.pathname.slice(1))
        };
    }

    // Hosted connections use TLS with certificate verification enabled.
    // A provider's CA certificate can be supplied as a multiline environment value.
    const sslEnabled = env.DB_SSL === "true" ||
        (Boolean(env.DATABASE_URL) && env.DB_SSL !== "false");
    if (sslEnabled) {
        connection.ssl = { rejectUnauthorized: true };
        if (env.DB_SSL_CA) {
            connection.ssl.ca = env.DB_SSL_CA.replace(/\\n/g, "\n");
        } else if (env.DB_SSL_CA_FILE) {
            connection.ssl.ca = fs.readFileSync(env.DB_SSL_CA_FILE, "utf8");
        }
    }

    return {
        ...connection,
        waitForConnections: true,
        connectionLimit: 5,
        queueLimit: 0,
        connectTimeout: 10000,
        enableKeepAlive: true
    };
};

module.exports = { databaseOptions, databaseDialect };
