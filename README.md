# MFU333 browser app

The Flutter interface and Express API are deployed together on Vercel's Hobby
plan. Aiven's free PostgreSQL service stores the database. App users only need a
browser; XAMPP and local MySQL are not required.

## Interface language

Use the globe menu on the sign-in page or in the app header to choose **ไทย**
or **English**. The choice applies across screens and is saved in the browser
for future visits. Activity titles, descriptions, and names remain as entered.

Interface labels and API message translations are maintained in
`frontend/lib/l10n/app_strings.dart`. Flutter's built-in controls also follow
the selected locale.

## Database connection

The private local settings file is `backend/mfu-reg-backend/.env`.
It is ignored by Git and excluded from deployment uploads.

1. Create a **Free PostgreSQL** service in the [Aiven console](https://console.aiven.io/).
2. Copy its **Service URI** into `DATABASE_URL` in the private `.env` file.
   Keep the `/defaultdb` database name in the URI.
3. Download the service's CA certificate to
   `backend/mfu-reg-backend/ca.pem`, then set `DB_SSL_CA_FILE=./ca.pem` locally.
4. Import into an empty database:

   ```sh
   cd backend/mfu-reg-backend
   npm run db:import:postgres -- "/path/to/mfu_reg333.sql"
   ```

The PostgreSQL importer converts the supplied MySQL dump's INSERT data into
bound parameters and uses the equivalent nine-table PostgreSQL schema. It
preserves IDs, password hashes, timestamps, uniqueness constraints, foreign
keys, and next identity values. Schema creation and data import share one
transaction and roll back together if an import fails. Populated targets are
rejected without changing their existing data.

Existing MySQL connections remain supported with a `mysql://` Service URI
and the separate `npm run db:import` command.

The following command securely copies the local settings and certificate to the
linked Vercel project's **Production** environment:

```sh
node scripts/configure-hosting.js
```

It configures these variables:

| Variable | Value |
| --- | --- |
| `DATABASE_URL` | The Aiven Service URI |
| `DB_SSL` | `true` |
| `DB_SSL_CA` | The full contents of the downloaded CA certificate |
| `JWT_SECRET` | The private secret generated in the local `.env` |
| `WIFI_MOCK_MODE` | `false` for real network verification |

`DB_SSL_CA_FILE` is only for local import; hosted code uses `DB_SSL_CA`.
Redeploy after changing production environment variables. `/api/health` returns
HTTP 200 only when the API can connect to its database.

## Build and deploy

Flutter and Node.js are development tools; visitors do not install either.

```sh
bash scripts/build-web.sh
```

This builds the interface and copies it to the backend's ignored `public/`
directory. A release web build calls the API on the same origin. Local Flutter
development continues to use `http://localhost:3000`; a separate API can be
selected with `--dart-define=API_BASE_URL=https://your-api.example`.

The build also copies the root `login-data.txt` into `public/`, making the
listed account credentials available at `/login-data.txt` on the deployed app.
Edit the root file and rebuild/redeploy to update that page.

To publish the linked Vercel project after making changes:

```sh
bash scripts/deploy-web.sh
```

This verifies the linked project before deployment. Hosting source stays in
this repository; generated web assets, secrets, certificates, and SQL dumps
are excluded from Git.

## Verification

```sh
cd backend/mfu-reg-backend
npm test
cd ../../frontend
flutter test
```

Browser camera scanning requires HTTPS and camera permission. Existing SQL
accounts retain their existing passwords. Wi-Fi verification uses the allowed
network ranges in the database. The supplied dump contains a development-only
private IP range; real campus check-ins require the university's public network
range in the hosted database. `WIFI_MOCK_MODE=true` is available for a deliberate
demo setup.

Free hosting and database services have usage limits; no paid plan is required
by this configuration.

The frontend includes the team's 23 regression tests from
[`RAWEEROT666/unit-test` at `46a7a26`](https://github.com/RAWEEROT666/unit-test/commit/46a7a26896c72393c10a33440e017ff1c903319e).
They cover sessions, login, navigation, role-specific dashboards, management
screens, and password changes alongside the existing dashboard and language
tests. API responses and connection failures are mocked, so `flutter test`
does not need a running backend. The tests have been adapted to the current
dashboard text and separate language and account menus.
