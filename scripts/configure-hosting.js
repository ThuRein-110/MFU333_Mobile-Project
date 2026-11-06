// Run after filling the private backend .env file and downloading ca.pem.
// Values go to the Vercel CLI through stdin, never command arguments or logs.
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const backend = path.resolve(__dirname, "../backend/mfu-reg-backend");
const dotenv = require(path.join(backend, "node_modules/dotenv"));
const linked = JSON.parse(fs.readFileSync(path.join(backend, ".vercel/project.json"), "utf8"));
if (linked.projectName !== "mfu333-app") {
    throw new Error("Link the backend directory to the mfu333-app Vercel project first.");
}
const settings = dotenv.parse(fs.readFileSync(path.join(backend, ".env")));
if (!settings.DATABASE_URL || !settings.JWT_SECRET) {
    throw new Error("Fill DATABASE_URL and JWT_SECRET in the private backend .env first.");
}

let certificate = settings.DB_SSL_CA?.replace(/\\n/g, "\n");
if (!certificate) {
    const filename = path.resolve(backend, settings.DB_SSL_CA_FILE || "ca.pem");
    certificate = fs.readFileSync(filename, "utf8");
}

const variables = {
    DATABASE_URL: settings.DATABASE_URL,
    DB_SSL: "true",
    DB_SSL_CA: certificate,
    JWT_SECRET: settings.JWT_SECRET,
    WIFI_MOCK_MODE: settings.WIFI_MOCK_MODE || "false"
};

const run = (args, input) => {
    const result = spawnSync("npx", ["--yes", "vercel@65.12.0", ...args], {
        cwd: backend,
        input,
        encoding: "utf8"
    });
    if (result.status !== 0) {
        throw new Error("Vercel configuration failed. Check authentication and the linked project; secret values were not printed.");
    }
};

run(["project", "inspect", "--non-interactive"]);
for (const [key, value] of Object.entries(variables)) {
    run([
        "env", "add", key, "--environment", "production", "--force",
        "--type", ["DB_SSL", "WIFI_MOCK_MODE"].includes(key) ? "config" : "secret",
        "--yes"
    ], value);
    console.log(`Saved production setting: ${key}`);
}
console.log("Production settings saved. Deploy again to apply them.");
