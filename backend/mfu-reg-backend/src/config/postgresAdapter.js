const idColumns = Object.freeze({
    users: "user_id",
    activities: "activity_id",
    activity_categories: "category_id",
    activity_checkins: "checkin_id",
    activity_registrations: "registration_id",
    allowed_ips: "ip_id",
    network_zones: "zone_id",
    point_transactions: "transaction_id",
    qr_tokens: "qr_id"
});

const postgresOptions = (options) => ({
    host: options.host, port: options.port, user: options.user,
    password: options.password, database: options.database, ssl: options.ssl,
    max: options.connectionLimit, connectionTimeoutMillis: options.connectTimeout,
    idleTimeoutMillis: 10000, allowExitOnIdle: true,
    options: "-c timezone=UTC"
});

const prepareQuery = (sql) => {
    let index = 0;
    // Translate placeholders only outside SQL strings, quoted names and comments.
    let text = sql.replace(
        /'(?:''|\\.|[^'\\])*'|"(?:""|[^"\\])*"|`(?:``|[^`])*`|--[^\n]*|\/\*[\s\S]*?\*\/|\?/g,
        (token) => token === "?" ? `$${++index}` : token
    ).trim().replace(/;$/, "");
    const insert = text.match(/^INSERT\s+INTO\s+([a-z_]+)\b/i);
    let idColumn;
    if (insert) {
        idColumn = idColumns[insert[1].toLowerCase()];
        if (!idColumn) throw new Error("Insert target is not an MFU333 table");
        if (!/\bRETURNING\b/i.test(text)) text += ` RETURNING ${idColumn}`;
    }
    return { text, idColumn };
};

const createPostgresAdapter = (pool) => {
    const wrapQuery = (client) => async (sql, values = []) => {
        const { text, idColumn } = prepareQuery(sql);
        try {
            const result = await client.query(text, values.map((value) =>
                typeof value === "boolean" ? Number(value) : value));
            if (result.command === "SELECT") return [result.rows, result.fields];
            return [{
                insertId: idColumn ? result.rows[0]?.[idColumn] : undefined,
                affectedRows: result.rowCount
            }, result.fields];
        } catch (error) {
            if (error.code === "23505") {
                error.postgresCode = error.code;
                error.code = "ER_DUP_ENTRY";
            }
            throw error;
        }
    };

    return {
        query: wrapQuery(pool),
        end: () => pool.end(),
        getConnection: async () => {
            const client = await pool.connect();
            return {
                query: wrapQuery(client),
                beginTransaction: () => client.query("BEGIN"),
                commit: () => client.query("COMMIT"),
                rollback: () => client.query("ROLLBACK"),
                release: () => client.release()
            };
        }
    };
};

module.exports = { idColumns, postgresOptions, prepareQuery, createPostgresAdapter };
