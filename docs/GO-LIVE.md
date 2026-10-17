# OMIS Entry — go-live checklist (Phase 9)

Work through this on the **production** Supabase project and the phones that will be used
at the gate. Tick each box only when its check has passed.

| | Item | Done when |
| --- | --- | --- |
| [ ] | Error tracking | A test error from the web app, an Edge Function and the gate app shows in Sentry, with no names, emails, phone numbers or pass codes in it |
| [ ] | Backups | The dashboard shows a backup from the last 24 hours, and a restore drill passed |
| [ ] | Load test | `record_scan` p95 under 300 ms against staging, measured from the gate's network |
| [ ] | Privacy notice | Contact set in Settings, wording reviewed by the organisation |
| [ ] | Field test | Every row of the field-test table below passes on the cheapest phone |

---

## 1. Error tracking (Sentry)

Two Sentry projects: **omis-web** (Next.js; the Edge Functions report here too) and
**omis-gate** (Flutter). Nothing is sent while a DSN is empty, so development stays local.

| Where | Setting |
| --- | --- |
| Web host env | `NEXT_PUBLIC_SENTRY_DSN`, `NEXT_PUBLIC_SENTRY_ENVIRONMENT=production` |
| Web CI build (optional, readable stack traces) | `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN` |
| Edge Functions | `SENTRY_DSN`, `SENTRY_ENVIRONMENT=production` in `supabase/functions/.env`, then `npx supabase secrets set --env-file supabase/functions/.env` |
| Gate app build | `SENTRY_DSN`, `SENTRY_ENVIRONMENT` in the `--dart-define-from-file` JSON |

What is sent: errors only. No performance traces, session pings, screenshots or replays.
Before anything leaves the app, it is scrubbed:
- Request bodies, cookies, headers and query strings are removed.
- Only the user's ID is kept.
- Emails, phone numbers and pass tokens are masked.

The rules are in `apps/web/lib/observability/scrub.ts`, with a copy for the Edge Functions
in `supabase/functions/_shared/scrub.ts` and one for the gate app in
`apps/gate/lib/core/observability.dart`. Tests run against each copy.

**Check each one:**
- **Web:** open the site, open the browser's developer console and run
  `setTimeout(() => { throw new Error("Sentry check grace@example.com") })`. The event
  appears in omis-web as `Sentry check [email]`.
- **Edge Functions:** run
  `curl -X POST "$SUPABASE_URL/functions/v1/notify-approvers" -H "x-internal-secret: $INTERNAL_HOOK_SECRET" -d '{"pass_id":"not-a-uuid","kind":"new"}'`.
  It answers 500, and omis-web shows `notify-approvers returned 500 lookup_failed`.
- **Gate app:** the first real error appears in omis-gate. Its user field holds only an ID.

## 2. Backups

**Hosted backups.** Supabase takes daily backups on the Pro plan and above; the Free plan
has none, so production must be on Pro. Point-in-time recovery is an optional add-on.

Check: Dashboard → Database → Backups lists a backup from the last 24 hours.

**Our own copy (weekly, off-site).**

```bash
npm run db:backup -- --db-url "postgresql://postgres.<ref>:<password>@<pooler-host>:5432/postgres"
```

This writes the following to `backups/<UTC time>/` (git-ignored):
- `roles.sql`, `schema.sql` and `data.sql`;
- `counts.txt`, the row count of each key table.

The backup contains personal data. Store it encrypted, keep only as many as you need, and
delete the local copy after uploading it.

Not in the dump:
- **Vault secrets.** Set them again after a restore (below).
- **ID photo files.** They are kept for 30 days at most; their database rows are in the dump.
- **Cron jobs.** The migrations recreate them.

**Restore drill.** Do this on a development machine and delete the data afterwards:

```bash
npm run db:restore-drill -- backups/<UTC time>
```

The drill rebuilds the **local** database from the migrations, loads `data.sql` with
triggers off, recreates the Vault secrets, and compares every row count with `counts.txt`.
It prints PASS when they all match.

**Restoring production** into a new project:
1. Link the project, then run `npx supabase db push` to apply the migrations.
2. Load the data:
   `psql "$NEW_DB_URL" --single-transaction -c "set session_replication_role = replica" -c "truncate public.settings, storage.buckets cascade" -f data.sql`
3. Recreate the Vault secrets:
   `select vault.create_secret('https://<ref>.supabase.co/functions/v1', 'functions_url');`
   `select vault.create_secret('<INTERNAL_HOOK_SECRET>', 'internal_hook_secret');`
4. Deploy the functions and set their secrets.

## 3. Load test (`record_scan`, target p95 under 300 ms)

```bash
npm run load:scan -- --seed
npm run load:scan -- --concurrency 16 --duration 60
npm run load:scan -- --cleanup
```

The seed adds 3,000 pass holders and 60,000 past visits (about a month at a busy site),
all tagged `LOADTEST-`. Each worker is a guard scanning back to back without pausing. The
script reports latency percentiles, the result of every scan, and the time spent inside
Postgres. It fails if p95 reaches 300 ms or any scan isn't recorded.

**Local results** (17–18 Oct 2026, laptop):

| Workers | Scans per second | p50 | p95 | p99 | In Postgres (mean) |
| --- | --- | --- | --- | --- | --- |
| 8 | 1,280 | 5 ms | 10 ms | 16 ms | 1.4 ms |
| 32 | 773 | 34 ms | 91 ms | 149 ms | 1.8 ms |

The database is nowhere near the limit. What decides the real figure is the network
between the gate and the Supabase region. So run it against **staging**, from a laptop
tethered to a gate phone's mobile data:

```bash
SUPABASE_URL=https://<staging-ref>.supabase.co \
SUPABASE_ANON_KEY=… SUPABASE_SERVICE_ROLE_KEY=… \
DATABASE_URL="postgresql://…" LOAD_GUARD_EMAIL=<a staging guard> \
npm run load:scan -- --seed --concurrency 4
```

Never point it at production: it writes visits.

## 4. Privacy notice

The notice is at `/privacy`. It is linked from the welcome page, the staff sign-in page,
the visitor consent checkbox, and pass and rejection emails. The retention periods it
quotes come from the live settings.

- [ ] In Admin → Settings → Privacy, set **Privacy contact** (an email address or an
  office). Until it is set, the page tells people to ask at reception.
- [ ] Have the organisation review the wording against Malawi's data protection law.
- [ ] Decide how long approved passes and entry/exit records are kept. Today they are kept
  with no limit, and the notice says so. This is an open item in the spec.

## 5. Field test at the real gate

**Build for the cheapest phone you intend to use.** Use a staging or production project
over HTTPS: on Android 9 and newer, release builds refuse plain `http://`.

```bash
cd apps/gate
cp env/dev.example.json env/prod.json
flutter build apk --release --split-per-abi --dart-define-from-file=env/prod.json
```

Fill in `env/prod.json` before building: the HTTPS `SUPABASE_URL`, the publishable key and
the Sentry DSN.

The build writes `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Very cheap
phones may need `app-armeabi-v7a-release.apk` instead; check with
`adb shell getprop ro.product.cpu.abi`. The app needs Android 7.0 (API 24) or newer.

Release builds are signed with `android/key.properties` (`storeFile`, `storePassword`,
`keyAlias`, `keyPassword`; never committed). Without that file they use the debug key,
which is fine for this test but not for distribution.

Record results here:

| # | Check | Pass when | Result |
| --- | --- | --- | --- |
| 1 | Install and sign in as a guard; pick the gate | Under 1 minute, code email arrives | |
| 2 | Scan a staff QR from a phone screen, full brightness | Result screen in under 1 s | |
| 3 | Same QR from a phone at low brightness | Reads within 3 s | |
| 4 | Printed visitor pass, daylight and at night under the gate light | Reads within 3 s | |
| 5 | Scan the same pass again on the way out | Exit recorded with time on site | |
| 6 | Revoked or expired pass | Clear "do not admit" screen; flag appears in admin | |
| 7 | Guard creates a visitor with an ID photo | Photo uploads on mobile data in under 15 s | |
| 8 | Reception approves on another phone | Guard screen updates by itself | |
| 9 | Airplane mode: 10 scans, then back online | Offline banner shown; all 10 sync, no duplicates | |
| 10 | Weak signal (back of the gatehouse) | Scans still record, or queue and sync | |
| 11 | Leave the app open for a full shift | Battery left; phone not too hot to hold | |
| 12 | Kill and reopen the app; restart the phone | Still signed in at the same gate | |
| 13 | Another guard signs in on the same phone | Sees only their own session | |
| 14 | Sentry | No errors, or each one understood | |

Phone model and Android version tested: ______________________  Date: __________
