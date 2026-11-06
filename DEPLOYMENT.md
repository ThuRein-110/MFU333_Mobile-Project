# MFU333 deployment

Updated: 6 November 2026 (Asia/Bangkok).

- App URL: https://mfu333-app.vercel.app
- Hosting: Vercel Hobby, project `mfu333-app`, team `thurein-oos-projects`.
- Project ID: `prj_8P1PJdfvA7q82mIDODktJGI9lFdm`.
- Deployment ID: `dpl_6Hb4jYzPDcdwZcpJKncmJEAYBQud`.
- Interface and Express API are deployed together; browser API calls use the same origin.
- The release bundles the Noto Sans Thai font and its OFL license.
- Database: Aiven PostgreSQL 18, Free plan, service `pg-352a72b3`.

The private local connection file is `backend/mfu-reg-backend/.env`.
`DATABASE_URL` contains the supplied Aiven PostgreSQL Service URI. Its CA
certificate is saved as `backend/mfu-reg-backend/ca.pem`; production uses the
certificate through `DB_SSL_CA` with TLS verification enabled.
The original SQL dump remains at `/Users/thurein/Downloads/mfu_reg333 (2).sql`.
The SQL dump was converted and imported into PostgreSQL successfully:
5 users, 6 categories, 1 network zone, 1 allowed IP range, 2 activities,
2 registrations, 2 QR tokens, 1 check-in, and 1 points transaction.
The migrated schema has 9 primary keys and 14 foreign keys. Existing account
password hashes and record IDs were preserved.

Production database variables are configured and the PostgreSQL backend is
deployed. `WIFI_MOCK_MODE` remains `false`. The supplied allowed-IP range is a
development private range; real campus Wi-Fi check-in requires a suitable
public campus range when the API is hosted outside the university network.

Verification completed: 16 backend checks, including an embedded PostgreSQL
import of the actual SQL dump with every inserted value checked, import
rollback, authentication, registration, check-in transactions, points and
dashboard queries. Flutter build and widget checks also passed. Live browser
verification against the production URL passed: login, imported activity
rendering on desktop and mobile, registration, registration cancellation, and
points access. The live health endpoint returns HTTP 200 with
`database: connected`. The browser had no JavaScript errors or failed network
requests. Temporary verification accounts and their registrations were removed.

The admin dashboard now displays numeric totals and labeled breakdowns from
the nested summary response, instead of printing maps. Its layout adapts to
desktop and mobile widths. Five Flutter widget checks passed, covering the
admin response shape, mobile layout, lecturer statistics, and student activity
list. The release build and browser preview against live admin data passed.
The production admin dashboard also passed desktop/mobile browser checks with
HTTP 200 from `/api/admin/dashboard`, no raw object output, no JavaScript
errors, and no failed network requests.

Local macOS dataless files blocked builds in Documents. The deployment used a
fresh temporary checkout at `/private/tmp/mfu333-deploy-u2yumxjc`, with the same
application changes and generated web assets. Local source edits remain in the
user's repository. No paid resources were created.
