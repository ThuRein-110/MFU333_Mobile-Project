# MFU333 API Test Report

| Item | Detail |
| --- | --- |
| Project | MFU333 Campus Activity System |
| Report date | 6 November 2026, Asia/Bangkok |
| Application | https://mfu333-app.vercel.app |
| API base URL | `https://mfu333-app.vercel.app/api` |
| Deployment referenced | `dpl_6Hb4jYzPDcdwZcpJKncmJEAYBQud` |
| Overall result | All executed checks passed within the scope described below; some routes and campus-network behavior remain unverified. |

## 1. Objective and scope

The tests check whether the API accepts valid requests, rejects selected invalid or unauthenticated requests, reads the hosted PostgreSQL database, and supports the main activity-registration workflow. They also check the database compatibility code used to migrate the supplied MySQL dump to PostgreSQL.

This report combines a fresh automated test run, fresh non-mutating checks of the deployed API, and authenticated live checks recorded earlier in the deployment session. These evidence types are identified separately. A database-model test is not presented as a successful test of the corresponding HTTP endpoint.

No application passwords, database credentials, JWT values, or password hashes are included in this report.

## 2. Test environment

| Component | Environment or tool |
| --- | --- |
| Backend | Node.js and Express 5.3.0 |
| Declared Node.js version | `24.x` in the backend package configuration |
| Local test runtime | Node.js `v26.8.1` |
| Hosting | Vercel Hobby |
| Hosted database | Aiven PostgreSQL 18, Free plan |
| PostgreSQL driver | `pg` 8.23.1 |
| Legacy MySQL driver | `mysql2` 3.24.6 |
| Automated test framework | Node.js built-in test runner and `node:assert/strict` |
| Isolated database tests | Embedded PostgreSQL through PGlite |
| Fresh live HTTP checks | Python HTTP client, with actual response status and JSON recorded |
| Recorded browser checks | Playwright with Chrome; an additional WebKit HTTP check was used during login diagnosis |
| Frontend checks | Flutter widget tests and a release web build |

The automated backend suite ran in an isolated temporary checkout containing the project changes. That checkout did not load the working project's private `.env` file. The supplied SQL dump was tested against an embedded database; the automated suite did not re-import it into the production database.

## 3. Result summary

| Test set | Result | Evidence boundary |
| --- | --- | --- |
| Fresh backend suite | **16 passed; 0 failed; 0 skipped** | Configuration, SQL parsing, local HTTP handlers, and embedded PostgreSQL integration |
| Fresh live HTTP checks | **5 passed; 0 failed** | Deployed API health and selected validation/authentication failures |
| Recorded authenticated live workflow | **Passed** | Browser login, activity retrieval, registration, registration retrieval, cancellation, and points access |
| Recorded admin dashboard check | **Passed** | Authenticated `GET /api/admin/dashboard` and desktop/mobile rendering |
| Supporting Flutter widget checks | **5 passed** | Admin response rendering at two widths, lecturer statistics, student activity list, and app startup |
| Real campus Wi-Fi and QR check-in | **Not verified end to end** | Requires real campus network configuration and dedicated HTTP/browser tests |

The fresh backend run completed in approximately **2.27 seconds**. This is the duration of the local suite, not an API response-time measurement or a load-test result.

The runner's total of 16 includes one parent workflow test and its three nested tests. The next section lists the **15 leaf test cases**, rather than counting the parent as an additional independent scenario.

## 4. Automated backend test cases

### 4.1 HTTP, connection configuration, and MySQL import compatibility

Source: [hosting.test.js](backend/mfu-reg-backend/test/hosting.test.js).

| ID | Scenario | Expected result | Actual result |
| --- | --- | --- | --- |
| AT-01 | Parse a hosted MySQL URI containing encoded credentials and a CA certificate | Credentials decode correctly; TLS certificate verification remains enabled; ordinary application queries do not enable multiple statements | PASS |
| AT-02 | Use existing local MySQL environment settings | Host, database, and user remain supported without requiring TLS for the local configuration | PASS |
| AT-03 | Attempt a MySQL import into a populated target | Import stops before executing the dump | PASS — tested with a stubbed connection, not a live MySQL server |
| AT-04 | Prepare phpMyAdmin SQL for hosted MySQL | Primary keys move before inserts; unique-key and foreign-key declarations remain in the SQL | PASS — SQL transformation check |
| AT-05 | Request `GET /api/health` without database configuration | HTTP `503`; `database: not_configured`; response is not cached | PASS |
| AT-06 | Request `GET /api/activities` without a JWT | HTTP `401`; message is `Access token is required` | PASS |
| AT-07 | Submit `POST /api/auth/login` with an empty JSON object | HTTP `400`; message is `Email and password are required` | PASS |

AT-01 checks generated TLS options; it does not itself perform a TLS handshake. Hosted connectivity is covered separately by the live health check. AT-05 requires an environment without `DATABASE_URL` or `DB_HOST`; that condition was met in the isolated run.

### 4.2 PostgreSQL migration and application integration

Source: [postgres.test.js](backend/mfu-reg-backend/test/postgres.test.js).

| ID | Scenario | Expected result | Actual result |
| --- | --- | --- | --- |
| AT-08 | Parse a PostgreSQL URI with encoded credentials and `sslmode=require` | Select PostgreSQL, use its default port when omitted, and retain the supplied CA with certificate verification enabled | PASS |
| AT-09 | Translate query placeholders while SQL strings/comments contain `?` | Only real placeholders become PostgreSQL parameters; quoted/comment text is preserved | PASS |
| AT-10 | Parse MySQL inserts containing Thai text, quotes, semicolons, backslashes, and identity metadata | Values remain data and retain their original content; next identity value is recognized | PASS |
| AT-11 | Import records containing an invalid foreign key | Import fails and rolls back both the schema and inserted data | PASS — embedded PostgreSQL |
| AT-12 | Import the actual supplied SQL dump into an empty embedded database | All nine tables and every supplied column value are preserved; a second import into the populated target is rejected | PASS |
| AT-13 | Register a student, log in using a different email-letter case, and retrieve activities | Registration returns `201`; preserved identity sequence is used; login and authenticated activity retrieval return `200` | PASS — local HTTP API backed by embedded PostgreSQL |
| AT-14 | Exercise registration and check-in models, including an intentional points-insert failure | Duplicate registration is rejected; failed check-in rolls back attendance changes; successful check-in marks attendance and awards 100 points | PASS — model/database integration, not the campus check-in HTTP endpoint |
| AT-15 | Exercise lecturer first-login flags, user search, and dashboard queries | First-login flag can be set and cleared; case-insensitive search and aggregate admin/lecturer statistics return the expected data | PASS — model/database integration |

The embedded tests execute the production schema and model queries, with a test wrapper replacing the network connection. They do not establish production concurrency behavior or validate every aspect of the `pg` network driver.

## 5. Fresh live API checks

These checks were executed against the deployed application while preparing this report. They did not create users, change passwords, register participants, or change application records.

| ID | Method | Endpoint | Input or condition | Expected HTTP | Actual HTTP | Result |
| --- | --- | --- | --- | --- | --- | --- |
| LT-01 | GET | `/api/health` | No authentication required | 200 | 200 | PASS — database connected |
| LT-02 | GET | `/api/activities` | Authorization header omitted | 401 | 401 | PASS — access token required |
| LT-03 | GET | `/api/admin/dashboard` | Authorization header omitted | 401 | 401 | PASS — access token required |
| LT-04 | POST | `/api/auth/login` | Body: `{}` | 400 | 400 | PASS — required fields rejected |
| LT-05 | POST | `/api/auth/login` | Deliberately invalid, non-existent test credentials | 401 | 401 | PASS — invalid credentials rejected |

An expected `400` or `401` is a passing negative test. It does not indicate that the API is offline.

### 5.1 Database health response

Request:

```http
GET /api/health
Accept: application/json
```

Observed response — HTTP `200`:

```json
{
  "success": true,
  "database": "connected"
}
```

### 5.2 Protected resource without authentication

Request:

```http
GET /api/activities
Accept: application/json
```

Observed response — HTTP `401`:

```json
{
  "success": false,
  "message": "Access token is required"
}
```

### 5.3 Login with missing fields

Request:

```http
POST /api/auth/login
Content-Type: application/json

{}
```

Observed response — HTTP `400`:

```json
{
  "success": false,
  "message": "Email and password are required"
}
```

### 5.4 Login with invalid credentials

The test used a deliberately non-existent account. No real user's password was guessed or reset.

Observed response — HTTP `401`:

```json
{
  "success": false,
  "message": "Invalid email or password"
}
```

## 6. Recorded authenticated live checks

The following results were recorded earlier in this deployment session on 6 November 2026. They were not all re-executed during report generation.

| ID | Method | Endpoint | Verified behavior | Observed HTTP |
| --- | --- | --- | --- | --- |
| WF-01 | POST | `/api/auth/register` | Temporary verification account was created | 201 |
| WF-02 | POST | `/api/auth/login` | Browser login returned a JWT and opened the student dashboard | 200 |
| WF-03 | GET | `/api/activities` | Authenticated browser displayed the two imported activities | 200 |
| WF-04 | POST | `/api/registrations/:activityId` | Verification account registered for an available activity | 201 |
| WF-05 | GET | `/api/registrations/my` | The new registration appeared in the student's registration list | 200 |
| WF-06 | DELETE | `/api/registrations/:activityId` | The verification registration was cancelled | 200 |
| WF-07 | GET | `/api/points/my` | The authenticated student could retrieve its points response | 200 |
| WF-08 | GET | `/api/admin/dashboard` | Authenticated admin summary loaded and rendered numeric totals and breakdowns | 200 |

The temporary verification accounts and their registrations were removed after testing. The admin dashboard rendering check used a short-lived read-only development session; it did not reset the administrator's password. The existing administrator password was preserved.

Protected application requests use an authorization header in this format:

```http
Authorization: Bearer <JWT_RETURNED_BY_LOGIN>
```

The latest admin dashboard browser check reported no JavaScript errors or failed network requests. This validates that particular dashboard flow, rather than every page in the application.

## 7. Database migration verification

The production import and the isolated migration test used the supplied `mfu_reg333 (2).sql` dump. The following is the import snapshot, not a guarantee that live counts will remain unchanged as users work in the application.

| Table | Imported rows |
| --- | --- |
| `users` | 5 |
| `activity_categories` | 6 |
| `network_zones` | 1 |
| `allowed_ips` | 1 |
| `activities` | 2 |
| `activity_registrations` | 2 |
| `qr_tokens` | 2 |
| `activity_checkins` | 1 |
| `point_transactions` | 1 |
| **Total** | **21** |

The migration preserved record IDs, password hashes, stored timestamps, and next identity values. The hosted schema was checked after import and contained nine primary keys and fourteen foreign keys. The automated import test also compared every supplied inserted value and checked that re-import into a populated database is rejected.

## 8. Coverage limits and follow-up tests

Route existence and access rules below were inspected in the source. That inspection does not count as an executed endpoint test.

| Area | Coverage established | Still to verify through HTTP/browser requests |
| --- | --- | --- |
| Authentication | Registration, successful login, missing fields, invalid credentials, and selected missing-token requests | `/api/auth/me`, password-change endpoint, expired/malformed JWTs, and first-login access restrictions |
| Activities | Authenticated list retrieval | Individual activity retrieval, create, update, cancellation, ownership rules, and invalid activity data |
| Registrations | Valid registration, retrieval and cancellation live; duplicate rejection at the model layer | HTTP duplicate-registration responses, full activities, passed deadlines, attended activities, and concurrent requests |
| Points | Live total-points access and model-level point awarding/aggregation | `/api/points/history` and additional transaction types |
| Admin | Authenticated dashboard HTTP response; model-level search and aggregates | User list/detail HTTP routes, account activation/deactivation, lecturer creation, and full role-denial cases |
| Lecturer | Embedded model statistics and owned-activity queries | `/api/lecturer/dashboard`, participants, owned activity details/status updates, and cross-owner denial |
| QR tokens | Fixture tokens support the check-in model tests | `POST /api/qr/:activityId`, token creation, hashing/verification, expiry, and invalid-token responses |
| Check-in | Embedded transaction rollback and successful attendance/points model updates | Full `POST /api/checkins` flow, Wi-Fi middleware, camera scanning, duplicate check-ins, and production concurrency |
| Diagnostic and role-probe routes | Source inspection | `/test-db` and `/api/test/student`, `/api/test/lecturer`, `/api/test/admin` |

No throughput, load, endurance, or API latency benchmark was performed. No complete security assessment is claimed by this report.

### Campus Wi-Fi limitation

The supplied database contains the development range `10.20.0.0/16`. Production `WIFI_MOCK_MODE` remains `false`. A full hosted campus check-in test requires the university's actual public network ranges and verification of client-IP handling through the hosting proxy. The existing model tests do not prove that this network gate works from real campus Wi-Fi.

## 9. Issues and observations

| Observation | Status | Evidence or action |
| --- | --- | --- |
| Admin summary rendered nested objects as long text | Resolved | The frontend now extracts numeric totals and labeled breakdowns. Five Flutter checks and live desktop/mobile dashboard checks passed. |
| A failed login displayed a backend-connection warning in the user's browser | Historical UI observation; needs a dedicated browser regression check | Server logs showed HTTP `401`, and the health endpoint returned `200`. Chrome and a direct WebKit HTTP check could read the invalid-credentials response. The API rejected the login as expected; the browser-specific message classification was not established as fixed. |
| Real campus Wi-Fi/QR check-in has not been verified end to end | Pending configuration and testing | The database still uses the development IP range. |

## 10. Reproducing the checks

### Automated backend suite

Use an isolated checkout without the working project's private `.env` file and without inherited `DATABASE_URL` or `DB_HOST` settings. The tests use an embedded database and do not require XAMPP or a separately installed MySQL/PostgreSQL server.

```sh
cd backend/mfu-reg-backend
npm ci
MFU_SQL_DUMP="/absolute/path/to/mfu_reg333 (2).sql" npm test
```

Replace the example path with the actual SQL dump location. Providing `MFU_SQL_DUMP` enables the actual-dump preservation case. Without it, that case is skipped. The recorded full run used the dump and reported:

```text
tests 16
pass 16
fail 0
cancelled 0
skipped 0
```

### Non-mutating live checks

```sh
curl -i https://mfu333-app.vercel.app/api/health
curl -i https://mfu333-app.vercel.app/api/activities
curl -i https://mfu333-app.vercel.app/api/admin/dashboard
curl -i -X POST https://mfu333-app.vercel.app/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{}'
```

Expected statuses, in command order: `200`, `401`, `401`, and `400`.

## 11. Evidence references

- [HTTP/configuration tests](backend/mfu-reg-backend/test/hosting.test.js)
- [PostgreSQL integration tests](backend/mfu-reg-backend/test/postgres.test.js)
- [Server and route mounting](backend/mfu-reg-backend/server.js)
- [Route definitions](backend/mfu-reg-backend/src/routes)
- [PostgreSQL adapter](backend/mfu-reg-backend/src/config/postgresAdapter.js)
- [PostgreSQL importer](backend/mfu-reg-backend/scripts/import-postgres.js)
- [Dashboard widget tests](frontend/test/dashboard_test.dart)
- [Deployment and live verification record](DEPLOYMENT.md)

## 12. Conclusion

The executed checks support successful operation of the tested authentication, activity-list, registration, points-access, and admin-dashboard flows, together with the tested PostgreSQL migration and transaction behavior. The fresh live checks confirmed that the deployed API connects to its database and returns the expected validation and authentication errors.

The remaining HTTP route cases, full authorization matrix, real campus QR/Wi-Fi workflow, and performance testing should be completed before treating this as full-system acceptance testing.
