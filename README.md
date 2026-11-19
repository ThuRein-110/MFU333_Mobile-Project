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

## Navigation and roles

Desktop, the mobile drawer, and bottom navigation use the same role-specific menu:

| Role | Main menu | Tabs inside Activities |
| --- | --- | --- |
| Administrator | Overview, Activities, User accounts, System settings | Activity list, Details, QR codes |
| Lecturer | Overview, Activities | Activity list, Details, Registrations, QR codes |
| Student | Overview, Activities, QR check-in, Points | Activity list, Details, My registrations |

Activity creation and editing are actions in the activity list. QR creation is an
action in the QR codes tab. Lecturers can edit only their own activities. Password
changes and sign-out are in the account menu for every role.

`frontend/lib/navigation/app_navigation.dart` defines the visible pages and page
access checks to match existing API permissions. Check-in and personal points are
student-only; account management is admin-only; participant management uses the
lecturer's own activities. The API enforces these restrictions independently.
Activity categories, network zones, and allowed IP ranges are combined in the
admin-only **System settings** section. Create and edit actions stay inside their
lists rather than adding separate navigation entries.

## Connected activity workflow

1. Admins maintain activity categories and campus network zones in **System
   settings**, and create lecturer accounts in **User accounts**. Lecturers must change
   their temporary password before using the app, including after a page reload.
2. Lecturers create and publish their activities using category and network-zone
   choices loaded from the database. Activity rows open details, participants,
   and QR tools with that activity already selected. The selection carries across
   the activity tabs. Overview activity cards also open the selected activity.
3. Students join from Activities. **My registrations** links each eligible
   registration directly to its check-in screen. QR codes include both the
   activity ID and token; existing token-only codes still work with the activity
   selector. Camera scanning and pasting a QR payload are supported.
4. A successful check-in updates the registration to attended and writes a single
   points transaction atomically. Students can open their point balance and
   history immediately. The lecturer's participant list and the admin summary
   read those same records on refresh.
5. Deactivating an account blocks its existing sessions on the next API request.
   The interface clears invalid sessions and returns to sign-in. Students see
   only their own registrations and points; lecturers manage their own attendees.

The full shared workflow is covered by `backend/mfu-reg-backend/test/workflow.test.js`
using an isolated PostgreSQL database with two lecturers and two students.
Frontend workflow tests cover activity navigation, QR payloads, check-in-to-points,
lecturer creation, forced password changes, and expired sessions.

**Manage QR codes** loads the selected activity's saved codes, including validity
times and expired codes. Newly created codes can be displayed again after a
refresh. Version 2 tokens are derived with a domain-separated HMAC using the
server signing key; the database retains only a versioned token hash. Existing
hash-only codes still validate, but their original images cannot be recovered.
Rotating the signing key also prevents redrawing earlier codes; already printed
codes continue to validate against their saved hashes.

Creating a QR code also makes a **New Activity alert** available to students.
While the app is open, students check the shared feed every 15 seconds and on
returning to the app. The popup links to activity details for registration, and
the bell reopens available alerts. Dismissal is saved per account on that device.
Multiple QR codes for one activity are grouped in the popup. Inactive or expired
codes and unpublished/completed activities are excluded; this feed never exposes
attendance tokens. API and widget tests cover persistence, role access, legacy
codes, cross-user alerts, dismissal, reloads, and activity navigation.

Check-in is allowed from **any network**, as requested. Students must still be
signed in, registered, and present an active QR for the matching activity.
Attendance and points remain atomic and duplicate check-ins are rejected.
Client IP addresses are retained for attendance records; campus IP ranges no
longer gate check-in. Existing network settings remain optional activity metadata.
Students can register for published and ongoing activities, subject to the
registration deadline and participant limit.

QR images have a white background and encode an HTTPS check-in link. A phone's
normal camera can open the student site; signing in preserves the activity and
token, and unregistered students can open the activity to register first.
The token is in the URL fragment so it is not sent in the initial page request.
Students can also use the in-app camera, upload a QR photo, or paste a link/token.
The camera's pinned ZXing library is served from `web/vendor`, with its license.
QR photo decoding alone does not record attendance; students explicitly confirm.

Activity creation/editing includes an optional image picker and preview. JPEG,
PNG and WebP uploads up to 3 MB are validated, resized, converted to JPEG and
stored in the linked public Vercel Blob store. Only staff can upload images.
The stored URL is retained on edits and appears in activity details and overview
cards for students and staff. Failed saves preserve the form and selected image.
The linked store provides `BLOB_READ_WRITE_TOKEN`; pull `.env.local` for local
development. Never save uploads to the Vercel function's temporary filesystem.

Activity and QR time fields provide localized calendar/time pickers and save UTC
timestamps. An end time must be after its start time. Dashboards include a refresh
button for loading changes made by other users. Lecturer registration totals count
registered and attended students, excluding cancelled registrations.

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
| `BLOB_READ_WRITE_TOKEN` | Added by the linked Vercel Blob store |

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

Running `flutter build web` alone updates only `frontend/build/web`; the Express
server continues serving its previous `public/` files. Use the build script above
to update a local backend. To update `https://mfu333-app.vercel.app`, publish with
the deployment script below as well. Restarting a backend does not publish the
frontend to Vercel.

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

Browser camera scanning requires HTTPS and camera permission. QR photo upload
and check-in links work as alternatives. Existing SQL accounts retain their
passwords. Student check-in is allowed from any network with a valid QR and
registration; no campus IP range or Wi-Fi mock setting is needed.

Free hosting and database services have usage limits; no paid plan is required
by this configuration.

The frontend includes the team's 23 regression tests from
[`RAWEEROT666/unit-test` at `46a7a26`](https://github.com/RAWEEROT666/unit-test/commit/46a7a26896c72393c10a33440e017ff1c903319e).
They cover sessions, login, navigation, role-specific dashboards, management
screens, and password changes alongside the existing dashboard and language
tests. API responses and connection failures are mocked, so `flutter test`
does not need a running backend. The tests have been adapted to the current
dashboard text and separate language and account menus.
