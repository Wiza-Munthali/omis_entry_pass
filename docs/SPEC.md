# OMIS Entry — Build Spec & Screen Brief

Oct 17, 2026 · @Wiza

## Overview and scope

OMIS Entry replaces the paper gate sign-in book with QR gate passes, so people enter and exit with one scan instead of writing in a queue.

**How it works in one paragraph.** Staff get a long-term pass by verifying their org email in a web app. Visitors request a one-day or one-week pass in the same web app; a receptionist approves it and the visitor receives a QR pass. Visitors without email are registered at the gate by the guard, who sends the request for approval from the mobile app and can attach a photo of their ID. Guards scan passes at the gate to record entry and exit times. Admins manage everything from a web dashboard.

**Goals**

- No queue at the gate: a known person passes in under 5 seconds.
- Every entry and exit has an accurate timestamp, a person and, where relevant, a vehicle.
- A live answer to "who is on site right now".
- Runs on cheap Android phones and unreliable networks.

**Non-goals (for now):** turnstile or boom-gate hardware, number-plate recognition, native visitor apps, multi-organisation tenancy.

**MVP**

1. Staff pass via org email verification.
2. Visitor self-service request (one-day / one-week) with receptionist approval and emailed QR pass.
3. Guard-created visitor requests with optional ID photo.
4. Guard scanning with automatic entry/exit detection, working offline.
5. Receptionist approval queue with push notifications and escalation to admins.
6. Admin dashboard: passes, visits log, approvals, users, gates, settings, CSV export.
7. Scheduled jobs: auto-close open visits, expire passes, delete old ID photos.

**Later:** host (staff) pre-registration of visitors, SMS/WhatsApp pass delivery, overstay alerts, plate photos, reports and charts.

## Architecture and tech stack

Three clients talk to one Supabase project; all business rules (validity, entry/exit, approvals) live in the database as Postgres functions so no client can bypass them.

| Part | Who uses it | Tech |
| --- | --- | --- |
| Public web portal | Staff, visitors | Next.js 15 (App Router, TypeScript), Tailwind CSS, shadcn/ui, PWA manifest |
| Admin dashboard | Admins (receptionists read-only views optional) | Same Next.js app under `/admin` |
| Gate app | Guards, receptionists, admins | Flutter (Android first, iOS supported), one app with role-based screens |
| Backend | All | Supabase: Postgres, Auth, Storage, Edge Functions, Realtime, pg\_cron |
| Email | System | Resend (or SMTP) called from Edge Functions |
| Push | Gate app | Firebase Cloud Messaging, sent from an Edge Function |

**Repository layout (monorepo)**

```
omis-entry/
  apps/
    web/                 # Next.js: portal + /admin dashboard
      app/(portal)/      # staff + visitor flows
      app/admin/         # dashboard
      lib/supabase/      # server + browser clients
      components/
    gate/                # Flutter app
      lib/
        core/            # theme, router, supabase, env
        data/            # repositories, drift db, sync
        features/
          auth/
          scan/
          requests/
          approvals/
          onsite/
  supabase/
    migrations/          # SQL schema, RLS, functions, cron
    functions/           # Edge Functions (TypeScript/Deno)
    seed.sql
  docs/
    SPEC.md              # this document
```

**Key packages**

- Web: `@supabase/ssr`, `@supabase/supabase-js`, `qrcode`, `zod`, `react-hook-form`, `date-fns`.
- Flutter: `supabase_flutter`, `flutter_riverpod`, `go_router`, `mobile_scanner`, `drift` + `sqlite3_flutter_libs`, `connectivity_plus`, `image_picker`, `firebase_messaging`, `flutter_local_notifications`.

**Environment:** separate Supabase projects for `dev` and `prod`; all keys in `.env` files never committed; the service-role key is used only inside Edge Functions.

## Roles and permissions

Operator roles form a strict hierarchy, admin > receptionist > guard, and each role inherits everything below it; staff and visitors are pass holders, not operators.

| Action | Guard | Receptionist | Admin |
| --- | --- | --- | --- |
| Scan pass, record entry/exit | Yes | Yes | Yes |
| Create visitor request at gate (+ ID photo) | Yes | Yes | Yes |
| See on-site list, check someone out manually | Yes | Yes | Yes |
| Approve / reject visitor requests | No | Yes | Yes |
| Scan a pending request QR and approve on the spot | No | Yes | Yes |
| View ID photos | No | Requests they handle | All |
| Receive escalated requests | No | No | Yes |
| Manage staff passes (revoke, extend) | No | No | Yes |
| Manage operator accounts | No | No | Yes |
| Gates, settings, exports, audit log | No | No | Yes |

**Pass holders**

- **Staff:** anyone who verifies an email on an allowed org domain. Can view and re-send their own pass and update their name, ID number and vehicle. Cannot see anyone else.
- **Visitors:** do not create accounts. A request returns a private status link (`/r/{status_token}`) where they see pending, approved (with QR) or rejected.

**Implementation rules**

- Store the role in `profiles.role` (enum `admin | receptionist | guard | staff`). Operator accounts are created only by admins (invite by email; first admin via seed).
- A helper SQL function `has_role(min_role)` compares by rank (guard = 1, receptionist = 2, admin = 3) and is used in every RLS policy and RPC.
- Never trust a role sent from a client; always read it from `profiles` using `auth.uid()`.

## Data model

Ten tables cover the system; a pass is the central record, and a visit is one entry/exit pair against a pass.

**Enums**

- `user_role`: `admin`, `receptionist`, `guard`, `staff`
- `pass_type`: `staff`, `day`, `week`
- `pass_status`: `pending`, `approved`, `rejected`, `revoked`, `expired`
- `request_source`: `web`, `gate`
- `flag_type`: `exit_without_entry`, `double_entry`, `auto_closed`, `scan_invalid_pass`, `approval_escalated`, `offline_conflict`

**Tables**

| Table | Key columns | Notes |
| --- | --- | --- |
| `profiles` | `id` (= `auth.users.id`), `role`, `full_name`, `email`, `phone`, `fcm_token`, `is_active`, `created_at` | Operators and staff. |
| `people` | `id`, `profile_id` (nullable), `full_name`, `id_number`, `phone`, `email`, `created_at` | Anyone who holds a pass. Visitors have no profile. Match returning visitors on `id_number`. |
| `vehicles` | `id`, `person_id`, `plate` (uppercase, no spaces), `description` | A person can have several. |
| `passes` | `id`, `person_id`, `vehicle_id`, `type`, `status`, `qr_token` (unique, random 32 bytes, base64url), `status_token` (unique, for visitor status link), `valid_from`, `valid_until`, `host_name`, `purpose`, `source`, `requested_by`, `decided_by`, `decided_at`, `reject_reason`, `escalated_at`, `created_at` | Staff passes: `valid_until` = 1 year, renewable. Day = end of that day; week = 7 days from `valid_from`. |
| `visits` | `id`, `pass_id`, `person_id`, `gate_id`, `vehicle_plate`, `entry_at`, `entry_by`, `exit_at`, `exit_by`, `auto_closed`, `client_entry_id`, `client_exit_id`, `recorded_offline` | One row per stay. Open visit = `exit_at is null`. `client_*_id` (UUID from the device) makes offline sync idempotent. |
| `gates` | `id`, `name`, `is_active` | One row per physical gate; operators pick their gate on login. |
| `id_photos` | `id`, `pass_id`, `storage_path`, `uploaded_by`, `delete_after`, `created_at` | File in private bucket `id-photos`. |
| `flags` | `id`, `type`, `pass_id`, `visit_id`, `details` (jsonb), `resolved_by`, `resolved_at`, `created_at` | Review queue for admins. |
| `settings` | single row: `allowed_email_domains` (text\[\]), `approval_timeout_minutes` (default 5), `auto_close_time` (default 23:59), `id_photo_retention_days` (default 30), `staff_pass_days` (default 365), `week_pass_days` (default 7), `org_name` | Admin-editable. |
| `audit_log` | `id`, `actor_id`, `action`, `target_table`, `target_id`, `details`, `created_at` | Written by triggers and RPCs. |

**Indexes:** `passes(qr_token)`, `passes(status_token)`, `passes(status, valid_until)`, `visits(pass_id) where exit_at is null`, `people(id_number)`, `vehicles(plate)`.

**Row Level Security (enable on every table)**

- `profiles`: users read their own row; admins read and write all.
- `people`, `vehicles`, `passes`: staff read their own (via `profile_id`); guards read only through the scan RPC and the on-site view; receptionists read all; only admins update staff passes.
- `visits`: guards read open visits at any gate (on-site list); receptionists and admins read all; **no direct inserts or updates from any client** — only through RPCs.
- `id_photos` and the storage bucket: guards may insert only; receptionists read rows for passes they are deciding; admins read all.
- `settings`, `gates`, `flags`, `audit_log`: admins write; operators read `gates` and the settings they need.
- Visitor portal writes go through an Edge Function using the service role, never through anon table access.

## Core flows and server logic

Every state change goes through one named Postgres function (RPC) or Edge Function, listed under each flow.

### 1. Staff pass

1. Staff opens the portal, chooses **I work here**, enters their email.
2. Supabase Auth sends a 6-digit email OTP. A `before_user_created` auth hook (or check in the RPC) rejects domains not in `settings.allowed_email_domains`.
3. After verification, staff completes name, ID number and optional vehicle plate.
4. RPC `register_staff_pass()` creates `people`, `vehicles`, and an `approved` `staff` pass (no approval needed) and returns the QR token.
5. Edge Function `send-pass-email` emails the QR as an image plus a link to `/pass` (which shows the QR, works as an installable PWA).
6. Re-opening the portal later shows the same pass; "Resend pass" re-sends the email.

### 2. Visitor self-service request

1. Visitor opens the portal (link or gate poster), chooses **I'm visiting**.
2. Form: full name, phone, email, ID number, vehicle plate (optional), person/department visiting, purpose, pass type (one-day or one-week), start date (today by default, up to 14 days ahead).
3. Edge Function `submit-visitor-request` validates with zod, rate-limits by IP and phone (max 5 per hour), upserts `people` by `id_number`, creates a `pending` pass with `source = web`, and returns the `status_token`.
4. Visitor is redirected to `/r/{status_token}` (bookmark-able, shows "Waiting for approval", updates via Realtime or 15-second polling).
5. Edge Function `notify-approvers` emails all active receptionists and sends FCM push to their devices.
6. On approval the status page shows the QR immediately and `send-pass-email` emails it. On rejection it shows the reason.

### 3. Guard-created request (visitor without email)

1. Guard taps **New visitor**, fills name, ID number, phone (optional), plate, visiting, purpose, pass type.
2. Optional: take a photo of the ID. Upload to `id-photos/{pass_id}/{uuid}.jpg` (compressed to max 1600 px, under 400 KB).
3. RPC `create_gate_request()` creates the pending pass with `source = gate`, `requested_by = guard`. Approvers are notified as above.
4. The guard's screen shows a waiting state and listens on Realtime for the decision.
5. On approval, the app asks "Check in now?" and calls `record_scan` with the new pass. No QR is needed; the person appears in the on-site list. Returning within a week pass: guard searches by name or ID number and checks them in.

### 4. Approval and escalation

- RPC `decide_request(pass_id, decision, reason)` requires receptionist or above; sets status, `decided_by`, `decided_at`; writes `audit_log`. It refuses if the pass is no longer `pending` (first decision wins).
- pg\_cron job every minute: pending passes older than `approval_timeout_minutes` with `escalated_at is null` → set `escalated_at`, create an `approval_escalated` flag, notify all admins.
- **Scan and approve:** a receptionist scans the QR on a visitor's status page (pending passes display a QR too); the app opens the request detail with Approve / Reject.

### 5. Scanning at the gate

RPC `record_scan(qr_token, gate_id, scanned_at, client_event_id)` is the single entry point:

1. Look up pass by `qr_token`. Not found → `invalid`.
2. Status not `approved`, or now outside `valid_from`–`valid_until` → return `pending`, `rejected`, `revoked` or `expired` with the person's name; create `scan_invalid_pass` flag.
3. Open visit exists for this pass → set `exit_at`, `exit_by` → return `exit_recorded`.
4. No open visit → insert visit with `entry_at`, `entry_by`, plate from the pass → return `entry_recorded`.
5. Return payload: result, full name, pass type, plate, valid until, entry time (for exits: duration on site).
6. `client_event_id` already seen → return the original result without writing (idempotent for offline retries).

Manual check-out from the on-site list uses RPC `check_out(visit_id, client_event_id)`.

### 6. Visit and pass lifecycle

- Visit: *open* (entry recorded) → *closed* (exit scanned, manual check-out, or auto-closed by cron).
- Pass: *pending* → *approved* or *rejected*; *approved* → *expired* (cron, after `valid_until`) or *revoked* (admin).

## Offline sync, notifications and scheduled jobs

The gate app must keep scanning with no network; everything else can wait for a connection.

**Offline scanning (gate app)**

- A local Drift database holds a cache of approved, unexpired passes (`qr_token` hash, name, type, plate, valid window) and open visits. Refresh on app start, every 5 minutes when online, and via Realtime changes on `passes`.
- Store `sha256(qr_token)`, not raw tokens, in the cache.
- When offline, a scan is validated against the cache, entry/exit is decided from the local open-visit table, and the event is written to an `outbox` table with a device-generated `client_event_id` and the scan time.
- A sync worker drains the outbox in order when connectivity returns, calling `record_scan` with the original `scanned_at`. Conflicts (for example a pass revoked while offline) create an `offline_conflict` flag; the guard is not blocked.
- A persistent banner shows **Offline — N scans waiting to sync**.
- Creating a visitor request offline is allowed: it queues in the outbox (ID photo kept locally) and the guard sees "Will send when online". Approvals themselves need a connection.

**Notifications**

| Event | Who | Channel |
| --- | --- | --- |
| New visitor request | Active receptionists | Push + email |
| Request escalated | All admins | Push + email |
| Request approved / rejected | Visitor; requesting guard | Email + status page; Realtime on guard's screen |
| Staff pass issued or re-sent | Staff member | Email |
| Pass revoked | Staff member | Email |

Push is sent by Edge Function `send-push` using FCM; device tokens are saved to `profiles.fcm_token` on login and cleared on logout. Emails use one branded HTML template with the QR embedded as an inline PNG and a plain-text fallback.

**Scheduled jobs (pg\_cron)**

| Job | Schedule | Action |
| --- | --- | --- |
| Escalate approvals | Every minute | Pending past timeout → escalate, notify admins |
| Expire passes | Every 15 minutes | Approved past `valid_until` → `expired` |
| Auto-close visits | Daily at `auto_close_time` | Open visits → set `exit_at`, `auto_closed = true`, create flag |
| Delete ID photos | Daily 02:00 | Rows past `delete_after` → delete storage object and row |
| Purge old requests | Weekly | Rejected or never-decided requests older than 90 days → delete personal fields |

All times are stored in UTC and displayed in Africa/Blantyre (CAT, UTC+2).

## Build phases for Claude Code

Build in nine phases, backend first; give Claude Code one phase at a time and do not start the next until the acceptance checks pass.

**Standing instructions to paste at the top of every Claude Code session**

```
You are building OMIS Entry. The full spec is in docs/SPEC.md — read it before
changing anything. Work only on the phase I name. Rules:
- All business logic lives in Postgres functions or Edge Functions; clients
  never write to visits or passes directly.
- Every table has RLS enabled; write a test for each policy.
- Use the design tokens in docs/SPEC.md (Design system section) — no ad-hoc colors.
- Small commits with clear messages. At the end of the phase, list what was
  built, how to run it, and how to verify each acceptance check.
- Ask before adding a dependency not listed in the spec.
```

1. **Phase 0 — Setup.** Monorepo, Next.js app, Flutter app, Supabase CLI project, env files, lint and format configs, CI running tests.
   - Done when: `supabase start`, `npm run dev` and `flutter run` all work locally.
2. **Phase 1 — Schema and security.** Enums, tables, indexes, `has_role`, RLS policies, `audit_log` triggers, `settings` row, seed (1 admin, 1 receptionist, 1 guard, 2 gates, sample passes).
   - Done when: pgTAP (or SQL) tests prove each role can and cannot do what the permissions table says.
3. **Phase 2 — Core RPCs.** `register_staff_pass`, `create_gate_request`, `decide_request`, `record_scan`, `check_out`, with idempotency on `client_event_id`.
   - Done when: tests cover every `record_scan` outcome (entry, exit, pending, rejected, revoked, expired, invalid, duplicate event).
4. **Phase 3 — Staff portal.** Email OTP with domain check, profile form, pass page with QR, PWA manifest, `send-pass-email`.
   - Done when: a seeded-domain email gets a working QR pass by email; another domain is refused.
5. **Phase 4 — Visitor portal.** Request form, `submit-visitor-request` with rate limiting, status page with live updates, approval and rejection emails.
   - Done when: a request appears as pending, and approving it in SQL shows the QR on the status page within 15 seconds.
6. **Phase 5 — Gate app: auth and scanning.** Login, gate selection, role-based home, scanner, result screens, on-site list, manual check-out.
   - Done when: scanning seeded passes on a real Android phone records entry then exit, and invalid passes show the right message.
7. **Phase 6 — Approvals and gate requests.** Receptionist queue, request detail, approve/reject, scan-and-approve, guard new-visitor flow with ID photo, FCM push, escalation cron.
   - Done when: a guard request triggers a push on the receptionist phone, approval updates the guard screen live, and an ignored request reaches admins after the timeout.
8. **Phase 7 — Offline.** Drift cache, outbox, sync worker, offline banner, conflict flags.
   - Done when: with airplane mode on, 10 scans are recorded, and all 10 sync correctly once online, with no duplicates after a forced retry.
9. **Phase 8 — Admin dashboard and jobs.** Overview, visits log with filters and CSV export, requests, staff passes, users, gates, flags, settings; remaining cron jobs.
   - Done when: an admin can run a full day's operations and export the log without touching SQL.

**Phase 9 — Hardening (before go-live):** error tracking (Sentry), backups confirmed, load test of `record_scan` (target under 300 ms), privacy notice page, field test at the real gate on the cheapest phone you intend to use.

## Design system

The look is soft, rounded and high-contrast: near-black primary buttons with GHII teal accents on warm off-white surfaces, taken from the inspiration's style but not its content.

**Colors** (brand teal sampled from the GHII logo)

| Token | Hex | Use |
| --- | --- | --- |
| `brand` | #34C5A0 | Accent: highlight cards, active icons, text on black buttons, links |
| `brand-strong` | #1F9E7E | Teal text on light backgrounds (passes contrast), hover |
| `brand-soft` | #DDF5EF | Tinted chips, selected rows, soft backgrounds |
| `ink` | #111111 | Primary buttons, active tab and nav pills, headings |
| `ink-2` | #1C1C1E | Dark sections and dark cards |
| `text` | #1A1A1A | Body text |
| `text-muted` | #6B6B6B | Secondary text, labels |
| `bg` | #EEEEEA | App background (warm light grey) |
| `surface` | #FFFFFF | Cards, sheets, inputs |
| `surface-2` | #F5F5F2 | Search fields, inactive pills, icon circles |
| `border` | #E4E4E0 | Hairlines, table dividers |
| `success` | #1F9E7E on #DDF5EF | Approved, entry recorded, valid |
| `warning` | #B7791F on #FDF1DC | Pending, expiring soon |
| `danger` | #C0392B on #FBE3E0 | Rejected, revoked, invalid |
| `info` | #2F6FB0 on #E1ECF8 | Checked out, informational |

**Type:** Inter (web) and Inter via `google_fonts` (Flutter). Display 28/34 semibold; title 20/28 semibold; body 16/24 regular; label 14/20 medium; caption 12/16. Numbers in stat cards 28–32 semibold.

**Shape and spacing**

- Radii: buttons and inputs fully rounded (pill); cards 24 px; sheets 28 px top corners; status chips pill.
- Spacing on an 8-point grid; screen padding 20 px mobile, 32 px desktop content.
- No drop shadows on mobile; separation comes from the off-white background behind white cards. Desktop uses 1 px borders.

**Components (mobile)**

- **Primary button:** full-width black pill, 56 px tall, teal label and icon.
- **Secondary button:** white pill with ink text; destructive variant uses danger text.
- **Circular icon buttons:** 48 px, `surface-2` fill, for back, notifications, more.
- **Segmented tabs:** pill track in `surface`, active segment black with teal text.
- **Highlight stat cards:** teal fill, ink number and label, small black circle with a chevron.
- **List cards:** white, 24 px radius, avatar or initials circle, name, secondary line, outlined status chip with check icon, small tag chips (pass type) in `surface-2`.
- **Bottom navigation:** floating pill bar in mid-grey, 5 circular icon slots, active slot black with teal icon.
- **Dark hero section:** optional black lower half on home screens for announcements or quick actions, with white text.

**Components (web dashboard)**

- Left sidebar on white with GHII logo and "OMIS Entry", search with keyboard hint, grouped menu with small section labels, signed-in user at the bottom.
- Breadcrumb, page title with one-line subtitle, primary teal button top right plus an outlined "More actions" button.
- KPI row: 4 stats separated by thin vertical dividers, each with a small colored dash and a muted caption.
- Tables: filter bar (search, status dropdown, date range, more filters), soft-colored status pills with a dot, "Details" outlined button and kebab menu per row, pagination with Previous/Next.

**Logo use:** the GHII mark sits top-left in the dashboard sidebar and centered above the portal forms; the product name "OMIS Entry" is set in Inter semibold beside or below it.

## Screen brief: public web portal

Ten mobile-first screens (design at 390 × 844), used by staff and visitors in a phone browser.

| # | Screen | Content and layout | States |
| --- | --- | --- | --- |
| P1 | Welcome | GHII logo and "OMIS Entry" centered; one-line purpose ("Get your gate pass"); two large white cards: **I work here** (badge icon) and **I'm visiting** (person-plus icon); small "Already have a pass? View it" link | — |
| P2 | Staff email | Back button; title "Sign in with your work email"; pill email field; helper text naming the allowed domain; black **Send code** button | Domain not allowed error |
| P3 | Verify code | Title "Enter the 6-digit code"; six rounded digit boxes; "Sent to name@org…"; resend timer link | Wrong or expired code |
| P4 | Staff details | Full name, ID number, "I drive to work" toggle revealing plate field; black **Get my pass** button | Validation errors |
| P5 | Staff pass | White card with name, "Staff" chip, large QR (280 px) on white, plate, "Valid until" date; teal highlight strip at top of card; buttons: **Email me my pass**, **Add to home screen**; small edit-details link | Revoked (danger banner), expired |
| P6 | Visitor request, step 1: about you | Step indicator (1 of 3); full name, phone, email, ID number | Validation |
| P7 | Visitor request, step 2: your visit | Who you're visiting, purpose (select: meeting, delivery, contractor, interview, other), pass type as two selectable cards (**One day**, **One week**), start date picker, vehicle plate (optional) | — |
| P8 | Visitor request, step 3: review | Summary card of all fields with edit links; consent checkbox for data use; black **Send request** button | Submitting spinner |
| P9 | Request status | Status hero: pending = warning chip, animated clock icon, "Waiting for reception to approve", note to keep page or check email; approved = success chip, QR card as in P5 with valid dates; rejected = danger chip and reason | Pending, approved, rejected, expired |
| P10 | Gate poster (print, A4) | GHII logo, "OMIS Entry", large QR to the portal, three short steps with icons (Scan, Fill in, Show your pass), "No smartphone? Ask the guard" | — |

**Emails (same visual style, 600 px wide):** staff pass issued; visitor pass approved (QR inline, valid dates, gate instructions); request rejected; new request for reception (name, visiting, pass type, **Review in app** button).

## Screen brief: admin dashboard

Ten desktop screens (design at 1440 × 960) sharing the sidebar layout described in the design system.

**Sidebar menu:** Overview · Visits · Requests (with pending count badge) · Passes · People · Flags (count badge); section "Manage": Users · Gates · Settings · Help.

| # | Screen | Content and layout |
| --- | --- | --- |
| A1 | Sign in | Split layout: left white panel with logo, email field, **Send code**; right panel in teal with a simple gate illustration and the line "Every entry, on record" |
| A2 | Overview | KPI row: On site now · Entries today · Pending requests · Open flags. Below: two-column — "Live on site" table (name, type chip, plate, gate, time in) and "Needs attention" list (escalated requests, flags) with action buttons; small entries-by-hour bar chart for today |
| A3 | Visits log | Filter bar (search name/ID/plate, gate, pass type, date range); table: person, pass type chip, plate, gate, time in, time out, duration, status pill (On site / Checked out / Auto-closed); **Export CSV** primary button |
| A4 | Requests | Tabs: Pending · Escalated · Approved · Rejected; table: visitor, visiting, pass type, source chip (Web / Gate), requested, age (turns warning colour past timeout); row click opens A5 |
| A5 | Request detail (right drawer, 480 px) | Visitor details, visit details, ID photo thumbnail (click to enlarge, admin only), timeline (requested by, notified, escalated), **Approve** (teal) and **Reject** (outlined, asks for reason) |
| A6 | Passes | Tabs: Staff · Visitors; table: holder, type, plate, valid from–until, status pill; row actions: View QR, Resend, Extend, Revoke (confirm dialog) |
| A7 | Users | Operators table: name, email, role chip (Admin / Receptionist / Guard), last active, status; **Invite user** button opens modal with email and role |
| A8 | Gates | Simple card grid, one card per gate with name, active toggle, today's entries; **Add gate** |
| A9 | Settings | Grouped form cards: Organisation (name, logo), Access (allowed email domains as removable chips), Passes (staff pass days, week pass days), Approvals (timeout minutes), Visits (auto-close time), Privacy (ID photo retention days) |
| A10 | Flags | Table: type pill, person, details, time, **Resolve** button; filter by type |

Empty states use a small line illustration, one sentence and a single action (for example "No one is on site right now").

## Screen brief: gate app (Flutter)

One app, designed at 390 × 844, where the home screen and bottom navigation change by role; guards see four tabs, receptionists and admins see five.

**Bottom navigation**

- Guard: Home · Scan (centre, larger) · On site · New visitor
- Receptionist / admin: Home · Scan · Approvals (badge) · On site · More

| # | Screen | Content and layout | States |
| --- | --- | --- | --- |
| G1 | Sign in | Logo, "OMIS Entry", work email, code step (same as portal P2–P3) | Error |
| G2 | Choose gate | List of gate cards, tap to select; remembered for next login | — |
| G3 | Guard home | Header: avatar, "Hello, {name}", gate name, notification button. Two teal stat cards: **On site** count and **Entries today**. Huge black **Scan pass** button. Dark lower section: "Waiting for approval" list of the guard's open requests, and quick actions (New visitor, On site list) | Offline banner at top |
| G4 | Scanner | Full-screen camera, rounded square viewfinder with teal corners, torch and close buttons, hint "Point at the QR code" | Camera permission denied |
| G5 | Scan result: allowed | Bottom sheet over camera, success colour: big check, **Entry recorded** or **Exit recorded**, name, pass type chip, plate, time; for exits the time on site; auto-dismiss after 3 s back to scanner, **Done** button | — |
| G6 | Scan result: blocked | Danger or warning sheet: icon, reason (Expired / Revoked / Not approved yet / Rejected / Unknown code), name if known, **Scan again** | — |
| G7 | New visitor | Form: name, ID number, phone (optional), plate, visiting, purpose select, pass type cards (One day / One week); **Add ID photo** tile; black **Send for approval** | Validation, queued offline |
| G8 | ID photo capture | Camera with ID-card-shaped frame, capture, retake, use photo | — |
| G9 | Waiting for approval | Card with visitor name, animated pending indicator, "Sent to reception at 10:42", elapsed timer; on approval switches to success with **Check in now**; on rejection shows reason | Escalated note after timeout |
| G10 | On site | Search field; segmented tabs: All · Staff · Visitors; list cards with name, type chip, plate, time in, gate; swipe or tap for **Check out** with confirm | Empty |
| R1 | Receptionist home | Same header; teal stat cards: **Pending** and **On site**; "Needs approval" list (top 3) with inline Approve / Reject; dark section with today's activity feed | — |
| R2 | Approvals | Segmented tabs: Pending · Approved · Rejected (admins also see Escalated); request cards: name, phone, visiting, pass type chip, source chip (Web / Gate), age, outlined status chip | Empty |
| R3 | Request detail | Visitor info card, visit info card, ID photo (tap to enlarge), timeline; sticky bottom: **Reject** (white pill) and **Approve** (black pill, teal text); reject opens reason sheet with quick reasons | Already decided by someone else |
| R4 | Notifications | List of push history: new requests, escalations, flags | — |

Touch targets are at least 48 px; text stays readable outdoors in bright sun, so keep body text at 16 px and avoid light grey text on the result sheets.

## ChatGPT prompt template for screens

Generate one screen per prompt: paste the style block once at the start of the chat, then send one screen line at a time and attach your two inspiration images and the logo to the first message.

**1. Style block (send first, with the inspiration images and logo attached)**

```
You are designing UI mockups for "OMIS Entry", a gate pass and visitor
entry system for the Global Health Informatics Institute (GHII). I've
attached two inspiration images and our logo.

Copy the DESIGN STYLE of the inspiration only — not its content, text,
photos, names or features. Style to copy: soft rounded shapes, pill buttons,
24px card radius, warm off-white background (#EEEEEA) behind white cards,
near-black primary buttons (#111111) with accent-colored labels, floating
pill bottom navigation with a black active circle, segmented pill tabs,
outlined status chips with check icons, generous whitespace, Inter font,
no drop shadows on mobile. Desktop: clean white sidebar layout, KPI row
with thin dividers, data tables with soft-colored status pills.

Replace the inspiration's lime accent with our brand teal #34C5A0 (from the
logo). Supporting colors: teal text #1F9E7E, teal tint #DDF5EF, muted text
#6B6B6B, warning #B7791F on #FDF1DC, danger #C0392B on #FBE3E0.

Use realistic Malawian names and context (e.g. Chikondi Banda, Thoko
Phiri, plates like "BT 4521", +265 phone numbers). Use simple initials
circles instead of photos. Render each screen as a single clean, flat,
high-fidelity mockup on a plain light-grey background, no device mockup
unless I ask. Confirm you understand, then wait for my first screen.
```

**2. Screen prompt (one per message)**

```
Screen [ID] — [Name] — [mobile 390x844 | desktop 1440x960]
Purpose: [one line]
Layout and content: [paste the row's "Content and layout" text from this doc]
State to show: [default | error | empty | pending | approved ...]
Keep the exact same style, colors and components as previous screens.
```

**Example**

```
Screen G5 — Scan result: allowed — mobile 390x844
Purpose: Guard sees instantly that a person may enter.
Layout and content: Bottom sheet over a dimmed camera view. Big teal check
icon, "Entry recorded", name "Chikondi Banda", "Staff" chip, plate "BT 4521",
time "08:42". Black "Done" pill button with teal text.
State to show: default.
Keep the exact same style, colors and components as previous screens.
```

**Tips:** generate the guard home (G3) and the admin overview (A2) first and approve them as the style references; then tell ChatGPT "match screen G3" or "match screen A2" in later prompts. Ask for a state variant in a follow-up ("same screen, rejected state") rather than a new screen.

## Assumptions and open items

These defaults are built into the spec; change any of them before Phase 1 starts.

**Assumptions**

- One organisation, one or more gates, single Supabase project per environment.
- "Week pass" = 7 consecutive days, including weekends.
- Staff passes are approved automatically once the org email is verified, and last 365 days.
- Visitors do not create accounts; their status link is the only way back to a pass besides email.
- The guard's phone is Android, shared between shifts, with each guard signing in to their own account.
- Approval timeout 5 minutes, auto-close at 23:59, ID photos kept 30 days.

**Open items**

- [ ] Confirm the allowed email domain(s).
- [ ] Confirm the site type and wording for "Who are you visiting" (person, department, unit).
- [ ] Decide whether the staff member being visited should also be notified.
- [ ] Choose email provider (Resend vs organisation SMTP) and sender address.
- [ ] Confirm data retention periods with the organisation and check obligations under Malawi's Data Protection Act.
- [ ] Decide what guards do if no one approves and the network is down (paper fallback vs phone call to reception).
