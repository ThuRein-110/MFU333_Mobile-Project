// Parse phpMyAdmin INSERT data into values. MySQL SQL is never executed on PostgreSQL.
const splitStatements = (source) => {
    const statements = [];
    let text = "", quoted = false, lineComment = false, blockComment = false;
    for (let i = 0; i < source.length; i++) {
        const c = source[i], next = source[i + 1];
        if (lineComment) { if (c === "\n") { lineComment = false; text += "\n"; } continue; }
        if (blockComment) { if (c === "*" && next === "/") { blockComment = false; i++; text += " "; } continue; }
        if (!quoted && c === "-" && next === "-") { lineComment = true; i++; continue; }
        if (!quoted && c === "/" && next === "*") { blockComment = true; i++; continue; }
        if (quoted && c === "\\") { text += c + (next || ""); i++; continue; }
        if (c === "'") {
            if (quoted && next === "'") { text += "''"; i++; continue; }
            quoted = !quoted;
        }
        if (c === ";" && !quoted) { statements.push(text.trim()); text = ""; }
        else text += c;
    }
    if (quoted || blockComment) throw new Error("Unterminated SQL string or comment");
    if (text.trim()) statements.push(text.trim());
    return statements;
};

const decodeValue = (token) => {
    const text = token.trim();
    if (/^NULL$/i.test(text)) return null;
    if (/^-?\d+(?:\.\d+)?$/.test(text)) {
        const number = Number(text);
        if (!Number.isSafeInteger(number)) throw new Error("Dump contains an unsupported numeric value");
        return number;
    }
    if (!text.startsWith("'") || !text.endsWith("'")) throw new Error("Unsupported SQL value in INSERT data");
    const escapes = { "0": "\0", b: "\b", n: "\n", r: "\r", t: "\t", Z: "\x1a" };
    return text.slice(1, -1).replace(/\\([\s\S])|''/g, (match, escaped) =>
        escaped === undefined ? "'" : (escapes[escaped] ?? escaped));
};

const parseRows = (source, columns) => {
    const rows = [];
    let row = null, token = "", quoted = false;
    for (let i = 0; i < source.length; i++) {
        const c = source[i], next = source[i + 1];
        if (quoted && c === "\\") { token += c + (next || ""); i++; continue; }
        if (c === "'") {
            if (quoted && next === "'") { token += "''"; i++; continue; }
            quoted = !quoted; token += c; continue;
        }
        if (!quoted && c === "(") {
            if (row) throw new Error("Nested INSERT expressions are not supported");
            row = []; token = ""; continue;
        }
        if (!quoted && row && (c === "," || c === ")")) {
            row.push(decodeValue(token)); token = "";
            if (c === ")") {
                if (row.length !== columns.length) throw new Error("INSERT row does not match its columns");
                rows.push(row); row = null;
            }
            continue;
        }
        if (row) token += c;
        else if (!/[\s,]/.test(c)) throw new Error("Unexpected text outside an INSERT row");
    }
    if (quoted || row) throw new Error("Incomplete INSERT row");
    return rows;
};

const parseMysqlDump = (source) => {
    const inserts = [], nextIds = {};
    for (const statement of splitStatements(source)) {
        if (/^INSERT\s/i.test(statement)) {
            const match = statement.match(/^INSERT INTO `([a-z_]+)`\s*\(([^)]+)\)\s*VALUES\s*([\s\S]+)$/i);
            if (!match) throw new Error("Unsupported INSERT statement in SQL dump");
            const columns = match[2].split(",").map((column) => {
                const name = column.trim().match(/^`([a-z_]+)`$/i);
                if (!name) throw new Error("Invalid INSERT column name");
                return name[1];
            });
            inserts.push({ table: match[1], columns, rows: parseRows(match[3], columns) });
        }
        const sequence = statement.match(/^ALTER TABLE `([a-z_]+)`\s+MODIFY `[a-z_]+`[\s\S]*?AUTO_INCREMENT\s*,\s*AUTO_INCREMENT=(\d+)/i);
        if (sequence) nextIds[sequence[1]] = Number(sequence[2]);
    }
    if (!inserts.length) throw new Error("No INSERT data found in SQL dump");
    return { inserts, nextIds };
};

module.exports = { parseMysqlDump };
