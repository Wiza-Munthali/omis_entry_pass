# OMIS Entry

QR gate passes for staff and visitors. The full build spec is in [docs/SPEC.md](docs/SPEC.md).

**New here, or not technical?** Start with [docs/GUIDE.md](docs/GUIDE.md): running it, putting it
online, and using it day to day, step by step.

```
apps/web/     Next.js 15: public portal + /admin dashboard
apps/gate/    Flutter gate app (Android first, iOS supported)
supabase/     migrations, Edge Functions, pgTAP tests, seed
```

## Prerequisites

- Node 22+ (`.nvmrc`)
- Flutter 3.44 (stable) with Android SDK
- A Docker runtime (Docker Desktop or OrbStack) for the local Supabase stack

The Supabase CLI is a root dev dependency; call it with `npx supabase`.

## First run

```bash
npm install
npm run db:start                         # local Supabase on :54321, Studio on :54323
npx supabase status                      # copy the API URL and publishable key
cp apps/web/.env.example apps/web/.env.local
cp apps/gate/env/dev.example.json apps/gate/env/dev.json
cp supabase/functions/.env.example supabase/functions/.env
```

Fill the URL and publishable key into `apps/web/.env.local` and `apps/gate/env/dev.json`.
The functions `.env` works as copied: locally, emails go to Mailpit.
The Android emulator reaches the host as `10.0.2.2`; on a real phone use your Mac's LAN IP.

## Local accounts (seed)

`npm run db:reset` loads [supabase/seed.sql](supabase/seed.sql). Sign in with an email code; codes arrive in Mailpit at http://127.0.0.1:54324.

| Email | Role |
| --- | --- |
| admin@ghii.test | admin |
| reception@ghii.test | receptionist |
| guard@ghii.test | guard |
| chikondi@ghii.test | staff (approved pass) |
| grace@ghii.test | staff (revoked pass) |

The seed also has two gates and visitor passes that are pending, approved (on site), rejected and expired.

Staff sign-up is limited to `settings.allowed_email_domains` (`ghii.test` locally), enforced by the
`before_user_created` auth hook. In a hosted project, enable the hook under Authentication → Hooks
(Postgres function `private.before_user_created`) and set the sign-in email templates from
[supabase/templates](supabase/templates).

### Visitor requests

Visitors request a pass at `/visit` and follow it at `/r/{status_token}`. When reception approves
or rejects a web request, the database calls the `notify-visitor` Edge Function (via `pg_net`) to
email the visitor. That needs two Vault entries, which the seed creates locally. In a hosted project,
create them once in the SQL editor, using the same secret as the function's `INTERNAL_HOOK_SECRET`:

```sql
select vault.create_secret('https://<project-ref>.supabase.co/functions/v1', 'functions_url');
select vault.create_secret('<long random value>', 'internal_hook_secret');
```

Without them, decisions still work; only the email is skipped (with a warning in the database log).

Requests are limited to 5 per hour per phone and 30 per hour per IP (mobile networks and guest
Wi-Fi put many visitors behind one IP). Locally every request shares one IP, so clear the counter
when testing a lot:

```bash
docker exec supabase_db_omis-entry psql -U postgres -c "truncate private.request_attempts"
```

### Approvals, escalation and push

Every new visitor request (web or gate) calls `notify-approvers`, which emails and pushes to active
receptionists. A `pg_cron` job runs every minute: requests still pending after
`settings.approval_timeout_minutes` (default 5) are escalated once, with a flag, to all admins.
To try escalation quickly, lower the timeout in Studio (`settings` table) to 1.

Push is off until Firebase is configured; everything else, including the emails, works without it.
To turn it on (Android; iPhone push additionally needs a paid Apple developer account and an APNs key
uploaded to Firebase):

1. Create a Firebase project and add an **Android app** with package name `mw.ghii.omis_gate`.
2. From **Project settings → General**, copy the project ID, the Android app ID, the API key and the
   sender ID (Cloud Messaging tab) into `apps/gate/env/dev.json` (`FIREBASE_*`; see `dev.example.json`).
3. From **Project settings → Service accounts → Generate new private key**, put the whole JSON on one
   line in `supabase/functions/.env` as `FCM_SERVICE_ACCOUNT_JSON='{...}'`, then restart
   `npm run functions`.
4. Rebuild the gate app and sign in as a receptionist; allow notifications when asked.

### Offline scanning

The gate app keeps an offline copy of approved passes: SHA-256 fingerprints of the QR tokens, never
the tokens, plus who is on site. The copy refreshes at start, every 5 minutes and after each sync.
Without a network, scans are decided from that copy and queued; so are visitors registered at the
gate, photos included. A banner shows **Offline — N scans waiting to sync**. When the connection
returns, the queue is sent in order. Every item carries its event id, so retries never duplicate.
If a pass changed while the phone was offline (for example it was revoked), the visit is still
recorded and an `offline_conflict` flag is raised for admins. Codes that are not in the offline copy
cannot be checked until the connection is back.

## Admin dashboard

Open http://localhost:3000/admin and sign in as `admin@ghii.test` with the code from Mailpit.
Only admins get in; everyone else is sent back to sign-in.

| Page | What it is for |
| --- | --- |
| Overview | Who is on site now (with check-out), today's entries per hour, what needs attention |
| Visits | Search the log by name, ID or plate; filter by gate, pass type and dates; **Export CSV** |
| Requests | Pending, escalated and decided requests; approve, or reject with a reason |
| Passes | Show the QR, resend the email, extend, or revoke with a reason (the holder is emailed) |
| Users | Invite guards, receptionists and admins; change roles; deactivate |
| Gates | Today's entries per gate; add, close or reopen a gate |
| Flags | Revoked or expired passes scanned, offline conflicts, auto-closed visits; resolve |
| Settings | Organisation, staff email domains, pass lengths, approval timeout, auto-close time, photo retention |

The CSV export takes the current filters, holds up to 50,000 rows, and guards against
spreadsheet formulas in names and plates.

### Scheduled jobs (pg_cron)

| Job | When | What it does |
| --- | --- | --- |
| `escalate-approvals` | every minute | Escalates requests left waiting past the approval timeout |
| `auto-close-visits` | every 5 minutes | Closes visits still open at the auto-close time and flags them |
| `expire-passes` | every 15 minutes | Marks approved passes past their end as expired |
| `cleanup-id-photos` | daily 02:00 CAT | Deletes ID photos past retention (calls the `cleanup-id-photos` function, so `npm run functions` must be running) |
| `purge-old-requests` | Sundays 03:00 CAT | Removes contact and visit details from requests older than 90 days |

To see them: `select jobname, schedule from cron.job;` and recent runs in `cron.job_run_details`.

## Going live

[docs/GO-LIVE.md](docs/GO-LIVE.md) is the checklist for production. It covers:
- **Sentry error tracking.** Errors only, scrubbed of personal data; nothing is sent
  until a DSN is set.
- **Backups and a restore drill.**
- **The `record_scan` load test.**
- **The privacy notice** at `/privacy`.
- **The field test** on the cheapest gate phone.

## Day to day

| Task | Command |
| --- | --- |
| Web dev server (http://localhost:3000) | `npm run dev` |
| Edge Functions (emails, visitor requests, approvals, push) | `npm run functions` |
| Read emails (codes, passes) | http://127.0.0.1:54324 |
| Gate app | `cd apps/gate && flutter run --dart-define-from-file=env/dev.json` |
| Reset DB (migrations + seed) | `npm run db:reset` |
| DB tests (pgTAP) | `npm run db:test` |
| Web lint / typecheck / tests | `npm run lint`, `npm run typecheck`, `npm test` |
| Web formatting | `npm run format` |
| Gate lint / tests | `cd apps/gate && flutter analyze && flutter test` |
| Load test `record_scan` (p95 under 300 ms) | `npm run load:scan -- --seed`, then `-- --cleanup` |
| Back up the database / restore drill | `npm run db:backup`, `npm run db:restore-drill -- backups/<time>` |

## Rules

- Business logic lives in Postgres functions or Edge Functions; clients never write to `visits` or `passes` directly.
- Every table has RLS enabled, with a test per policy.
- Colours come only from the design tokens in `apps/web/app/globals.css` and `apps/gate/lib/core/theme/app_colors.dart`. Tests in both apps fail if they drift from the spec or if a colour literal appears elsewhere.
- `.env` files are never committed; the service-role key is used only inside Edge Functions.
- Import `cn` from `@/lib/utils` (it knows the spec's type and radius scales), never from `cn` directly.
