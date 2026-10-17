# OMIS Entry: the complete guide

This guide is for anyone who needs to run, set up or use OMIS Entry. You do not need to
be a programmer. If you have never used Docker, Next.js or Flutter, follow the steps in
order and copy the commands exactly.

**Contents**

1. [What OMIS Entry is](#1-what-omis-entry-is)
2. [How the pieces fit together](#2-how-the-pieces-fit-together)
3. [Words you will see](#3-words-you-will-see)
4. [Part A: try it on your own computer](#part-a-try-it-on-your-own-computer)
5. [Part B: put it online for real use](#part-b-put-it-online-for-real-use)
6. [Part C: using OMIS Entry every day](#part-c-using-omis-entry-every-day)
7. [Part D: looking after it](#part-d-looking-after-it)
8. [Troubleshooting](#troubleshooting)
9. [Where to find more](#where-to-find-more)

---

## 1. What OMIS Entry is

OMIS Entry replaces the paper logbook and manual checks at the gate with QR-code passes.

- **Staff** get a permanent pass on their phone by signing in with their work email.
- **Visitors** request a pass online before they arrive. Reception approves it, and the
  visitor gets a QR code by email.
- **Guards** scan the QR code with a phone. Entry and exit times are recorded
  automatically, so nobody writes in a book and the queue moves faster.
- **Visitors who arrive without a request** are registered by the guard on the phone.
  Reception approves them from their own phone within minutes.
- **Admins** see who is on site right now, search the full log, export it to Excel, and
  manage passes, staff accounts and gates.

The gate phone keeps working when the internet drops. Scans are saved on the phone and
sent as soon as the connection returns.

## 2. How the pieces fit together

There are three things people use and one engine behind them.

| Piece | Who uses it | What it is |
| --- | --- | --- |
| **Web portal** | Staff and visitors, on any phone browser | A website: the welcome page, the staff pass and the visitor request form |
| **Admin dashboard** | Admins, on a computer | The same website, under `/admin` |
| **Gate app** | Guards and receptionists | An Android app installed on the gate phones |
| **Supabase** (the engine) | Nobody directly | Stores all the data, handles sign-in codes, and runs the rules and timed jobs |

All the rules live in the engine: who may enter, when a pass expires, and who can approve.
That means the website and the app can't be tricked into breaking them.

Emails (sign-in codes, passes, approvals) are sent by an email service. **Resend** is
built in. Phone notifications for reception go through **Firebase**, which is optional.

## 3. Words you will see

| Word | Meaning |
| --- | --- |
| **Terminal** | A window where you type commands. On a Mac: open *Terminal* from Applications → Utilities. On Windows: open *PowerShell* from the Start menu. |
| **Command** | A line you type (or paste) into the terminal, then press Enter. In this guide, commands are in grey boxes. |
| **Repository / repo** | The folder with all of OMIS Entry's code, kept on GitHub. |
| **Docker** | A program that runs the Supabase engine on your own computer, inside a sealed box. You only install it and leave it running. |
| **Node.js / npm** | The tool that runs the website. `npm` commands start things. |
| **Flutter** | The tool that builds the gate app for Android. |
| **Supabase** | The engine (database, sign-in, email codes and timed jobs). Local copy for testing, hosted copy for real use. |
| **Edge Functions** | Small programs inside Supabase that send emails and notifications. |
| **Migrations** | The step-by-step recipe that builds the database. Never edit old ones; they are applied in order. |
| **Environment file (`.env`)** | A small text file holding addresses and secret keys. Never share or upload these. |
| **Mailpit** | A fake inbox used when testing on your computer. Every email the system sends lands there instead of in real inboxes. |

---

# Part A: try it on your own computer

This gives you a full working copy with test data. Nothing you do here affects real
people. Allow about an hour the first time, mostly waiting for downloads.

**You need:**
- A Mac or Windows computer with **at least 15 GB of free disk space** (Docker and the
  Android tools are large). Check before you start, because running out of space makes
  Docker freeze.
- At least 8 GB of memory.
- An internet connection for the downloads.
- For the gate app, an Android phone and its USB cable.

## A1. Install the tools (once)

Install these in order and accept the default options:

1. **Git**, which downloads the code. Mac: open Terminal, type `git --version` and press
   Enter; if it offers to install the "command line developer tools", accept. Windows:
   install from https://git-scm.com/download/win.
2. **Node.js 22 (LTS)**, which runs the website: https://nodejs.org. Choose the "LTS"
   version.
3. **Docker Desktop**, which runs the engine: https://www.docker.com/products/docker-desktop.
   Open it after installing and wait until it says **Engine running**. Docker must be open
   whenever you use OMIS Entry locally.
4. **Only if you want the gate app on a phone:** **Android Studio**
   (https://developer.android.com/studio), then **Flutter** (https://docs.flutter.dev/get-started/install).
   Follow Flutter's page for your system. When you're done, `flutter doctor` in the
   terminal should show green ticks for Flutter and Android.

Check the tools by typing these one at a time. Each should print a version number.

```bash
git --version
```
```bash
node --version
```
```bash
docker --version
```

## A2. Download OMIS Entry

Pick a place for the code, for example your Documents folder:

```bash
cd ~/Documents
```
```bash
git clone <repository address from GitHub>
```
```bash
cd omis_entry_pass
```

From now on, **every command is typed inside this `omis_entry_pass` folder**. If you open a
new terminal window, run `cd ~/Documents/omis_entry_pass` first.

## A3. Install the website's building blocks (once)

```bash
npm install
```

This downloads everything the website needs (a few minutes). Yellow "warn" lines are normal.

## A4. Start the engine

Make sure Docker Desktop is open, then:

```bash
npm run db:start
```

The first time, this downloads Supabase (10–20 minutes). When it finishes, it prints a list
of addresses and keys. You can show that list again at any time:

```bash
npx supabase status
```

Keep two values from it: the **API URL** (`http://127.0.0.1:54321`) and the
**Publishable key** (a long text starting with `sb_publishable_`).

## A5. Create the settings files (once)

Make copies of three example files. You can do this in Finder or File Explorer (copy, paste,
rename), or with these commands on a Mac:

```bash
cp apps/web/.env.example apps/web/.env.local
```
```bash
cp supabase/functions/.env.example supabase/functions/.env
```
```bash
cp apps/gate/env/dev.example.json apps/gate/env/dev.json
```

Then open `apps/web/.env.local` in a text editor (TextEdit, Notepad or VS Code) and fill in:

```
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<the publishable key from step A4>
```

Leave everything else as it is. `supabase/functions/.env` works exactly as copied.

## A6. Load the test data

```bash
npm run db:reset
```

This rebuilds the database and fills it with test people, passes and gates. Run it again
whenever you want a clean start; it erases your local test data.

## A7. Start everything

You need **two terminal windows**, both in the `omis_entry_pass` folder, both left open.

Window 1, the email and notification programs:

```bash
npm run functions
```

Window 2, the website:

```bash
npm run dev
```

When window 2 says **Ready**, open these in your browser:

| What | Address |
| --- | --- |
| Welcome page (staff and visitors) | http://localhost:3000 |
| Admin dashboard | http://localhost:3000/admin |
| Test inbox (all emails, including sign-in codes) | http://127.0.0.1:54324 |
| Database viewer (Supabase Studio) | http://127.0.0.1:54323 |

## A8. Sign in with a test account

Nobody has a password; everyone signs in with a 6-digit code sent by email. Locally, those
emails land in the **test inbox** (http://127.0.0.1:54324).

| Email | Role |
| --- | --- |
| admin@ghii.test | Admin: dashboard and gate app |
| reception@ghii.test | Receptionist: approves visitors in the gate app |
| guard@ghii.test | Guard: scans passes in the gate app |
| chikondi@ghii.test | Staff member with a valid pass |
| grace@ghii.test | Staff member whose pass was revoked |

Try it: go to http://localhost:3000/admin, enter `admin@ghii.test`, open the test inbox,
copy the code and enter it.

## A9. Run the gate app on an Android phone (optional)

1. **Connect the phone and the computer to the same Wi-Fi.**
2. **Find the computer's address on that Wi-Fi.** Mac: System Settings → Wi-Fi → Details
   → IP address. Windows: run `ipconfig` and read the "IPv4 Address". It looks like
   `192.168.1.25`.
3. **Edit `apps/gate/env/dev.json`.** Set
   `"SUPABASE_URL": "http://192.168.1.25:54321"` (your address) and
   `"SUPABASE_PUBLISHABLE_KEY"` (from step A4). Leave the `FIREBASE_` and `SENTRY_`
   values empty.
4. **Turn on developer mode.** On the phone, go to Settings → About phone and tap
   **Build number** seven times. Then Settings → Developer options → turn on
   **USB debugging**.
5. **Connect the phone.** Plug it in by USB and accept the "Allow USB debugging?" prompt.
6. **Install and start the app:**
   ```bash
   cd apps/gate
   ```
   ```bash
   flutter run --dart-define-from-file=env/dev.json
   ```
   The first build takes several minutes. The app then opens on the phone.
7. **Sign in as `guard@ghii.test`** (code from the test inbox) and choose a gate.

To get a QR code to scan, open http://localhost:3000 on the computer and sign in as
`chikondi@ghii.test` (staff with a pass). Then scan the code on screen with the phone.

## A10. Stopping and starting again

- **To stop:** press `Ctrl + C` in both terminal windows, then run `npm run db:stop`. Your
  test data is kept.
- **To start again later:** open Docker Desktop, then run `npm run db:start`, then
  `npm run functions` (window 1) and `npm run dev` (window 2).

---

# Part B: put it online for real use

This is a one-off job, best done by someone comfortable following technical
instructions carefully. Work through it once on a **staging** (test) setup, then repeat it
for **production** (real use).

You will create accounts with these services:

| Service | What for | Plan |
| --- | --- | --- |
| **Supabase** (supabase.com) | The engine | **Pro**: the free plan has no daily backups |
| **Vercel** (vercel.com) | Hosts the website | Pro for an organisation (the free plan is for personal use) |
| **Resend** (resend.com) | Sends emails | Free tier to start; needs access to your email domain's DNS |
| **Sentry** (sentry.io) | Reports errors to you | Free tier is enough |
| **Firebase** (firebase.google.com) | Optional: phone notifications for reception | Free |
| **GitHub** (github.com) | Holds the code; Vercel builds from it | Free |

Write every key and password into a password manager as you go, never into email or chat.

## B1. Create the Supabase project

1. **Create the project.** At supabase.com, click **New project**. Pick a region close to
   Malawi (for example a European or South African region, if available), and save the
   database password.
2. **Link the code to it.** On your computer, in the `omis_entry_pass` folder:
   ```bash
   npx supabase login
   ```
   ```bash
   npx supabase link --project-ref <project ref from the project's URL>
   ```
3. **Build the database:**
   ```bash
   npx supabase db push
   ```
   This applies every migration: tables, security rules, timed jobs and the storage
   bucket. It does **not** add test data.
4. **Set up the email programs.** Open `supabase/functions/.env` and fill it in for real
   use:
   - `PORTAL_URL`: the website address (step B3), for example `https://entry.yourorg.org`.
   - `EMAIL_FROM`: the sender, for example `OMIS Entry <no-reply@yourorg.org>`.
   - `RESEND_API_KEY`: from step B2.
   - `MAILPIT_URL`: leave it empty.
   - `INTERNAL_HOOK_SECRET`: a long random password (at least 40 characters) that you
     make up.
   - `FCM_SERVICE_ACCOUNT_JSON`: from step B5, or leave it empty.
   - `SENTRY_DSN` and `SENTRY_ENVIRONMENT=production`: from Sentry.

   Then send the settings and the programs to Supabase:
   ```bash
   npx supabase secrets set --env-file supabase/functions/.env
   ```
   ```bash
   npx supabase functions deploy
   ```
5. **Connect the database to the email programs.** In the Supabase dashboard, open
   **SQL Editor** and run this, putting in your project ref and the same
   `INTERNAL_HOOK_SECRET`:
   ```sql
   select vault.create_secret('https://<project-ref>.supabase.co/functions/v1', 'functions_url');
   select vault.create_secret('<INTERNAL_HOOK_SECRET>', 'internal_hook_secret');
   ```
6. **Configure sign-in** in the dashboard, under **Authentication**:
   - **URL Configuration:** set **Site URL** to your website address.
   - **Emails → SMTP Settings:** turn on custom SMTP with Resend's SMTP details. Supabase's
     built-in sender only allows a few emails an hour, which is not enough for sign-in codes.
   - **Emails → Templates:** for both **Magic Link** and **Confirm signup**, set the
     subject to `Your OMIS Entry code` and paste the contents of
     `supabase/templates/sign_in_code.html` as the body.
   - **Sign In / Providers → Email:** set the email OTP (code) length to **6**, because the
     sign-in screens expect 6 digits.
   - **Hooks:** add a **Before User Created** hook of type **Postgres**, choosing the
     function `private.before_user_created`. This is what stops people with the wrong
     email domain from getting staff passes.
7. **Set your organisation's details.** In **SQL Editor**, with your real staff email
   domain:
   ```sql
   update public.settings set org_name = 'GHII', allowed_email_domains = '{yourorg.org}';
   ```

## B2. Set up email (Resend)

1. Create a Resend account and add your domain (for example `yourorg.org`).
2. Resend shows a few DNS records. Ask whoever manages your domain to add them, then wait
   for Resend to show the domain as **Verified**.
3. Create an **API key** (for `RESEND_API_KEY`). Note the **SMTP** details for step B1.6.

## B3. Put the website online (Vercel)

1. Put the code on GitHub (a private repository) if it is not there already.
2. At vercel.com, click **Add New → Project**, choose the repository, and set:
   - **Root Directory:** `apps/web`.
   - **Environment Variables:**
     - `NEXT_PUBLIC_SUPABASE_URL`: `https://<project-ref>.supabase.co`.
     - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`: from Supabase, under **Project Settings →
       API Keys**.
     - `NEXT_PUBLIC_SENTRY_DSN` and `NEXT_PUBLIC_SENTRY_ENVIRONMENT=production`: from
       Sentry.
3. Click **Deploy**. When it's done, add your own address (for example
   `entry.yourorg.org`) under **Settings → Domains**.
4. Go back to Supabase step B1.6 and check that **Site URL** matches this address.

## B4. Create the first admin

Every other account is created from the dashboard, but the very first admin is set up by
hand:

1. **Sign in once as staff.** Go to your website, choose **I work here**, and sign in with
   your work email. Fill in your details. You now have a staff pass.
2. **Make that account an admin.** In Supabase **SQL Editor**:
   ```sql
   update public.profiles set role = 'admin' where email = 'you@yourorg.org';
   ```
3. **Open the dashboard.** Go to `https://<your website>/admin`. From there, add
   receptionists, guards and other admins under **Users → Invite user**.

## B5. Build the gate app for the gate phones

1. **Turn on notifications (optional).** For phone notifications to reception, create a
   Firebase project with an **Android app** named `mw.ghii.omis_gate`. Copy its
   project ID, app ID, API key and sender ID. Then create a service account key for
   `FCM_SERVICE_ACCOUNT_JSON` (README → "Approvals, escalation and push").
2. **Create the settings file.** In `apps/gate/env`, copy `dev.example.json` to
   `prod.json` and fill in:
   - `SUPABASE_URL`: `https://<project-ref>.supabase.co`.
   - `SUPABASE_PUBLISHABLE_KEY`: the publishable key.
   - The `FIREBASE_` values, or leave them empty.
   - `SENTRY_DSN` and `SENTRY_ENVIRONMENT`.
3. **Build the app:**
   ```bash
   cd apps/gate
   ```
   ```bash
   flutter build apk --release --split-per-abi --dart-define-from-file=env/prod.json
   ```
   The install files appear in `apps/gate/build/app/outputs/flutter-apk/`. Most phones use
   `app-arm64-v8a-release.apk`; very cheap or old phones may need
   `app-armeabi-v7a-release.apk`. The app needs Android 7.0 or newer.
4. **Install it on each gate phone.** Copy the file to the phone (USB or a shared drive),
   tap it, and allow "install unknown apps" when asked.
5. **Sign the app for long-term use.** Before handing it out widely, create a signing key
   and `apps/gate/android/key.properties`. See
   [docs/GO-LIVE.md](GO-LIVE.md#5-field-test-at-the-real-gate). Keep that key safe:
   without it, phones can't receive updates.

## B6. Before the first real day

Work through [docs/GO-LIVE.md](GO-LIVE.md):
- Backups confirmed.
- Error reports arriving in Sentry.
- A load test against staging.
- The privacy contact set.
- A field test at the real gate on the cheapest phone you plan to use.

Also put up a poster where visitors queue, with a large QR code linking to your website
(any free QR code generator will make one) and the line "No smartphone? Ask the guard".

---

# Part C: using OMIS Entry every day

## C1. Visitors

1. **Request a pass.** Open the website (from the QR code on the gate poster, or a link), tap
   **I'm visiting** and fill in three short steps:
   - About you: name, phone, email and ID number.
   - Your visit: who you are visiting, why, one day or one week, the start date and your
     car plate (optional).
   - Check and send: read the privacy notice and tick the box.
2. **Wait for a decision.** The status page updates by itself when reception decides. Keep
   it open or bookmarked; the approval also arrives by email.
3. **Get your pass.** When approved, the page and the email show your QR code. If the
   request is turned down, they show the reason instead.
4. **At the gate,** show the QR code (on your phone or printed) when you arrive and again
   when you leave. Bring the ID you used on the request.

No smartphone? Tell the guard. They will register you on their phone.

## C2. Staff

1. **Get your pass (once).** Open the website, tap **I work here**, enter your work email,
   and type the 6-digit code from your inbox. Fill in your name, ID number and plate if you
   drive.
2. **Keep it handy.** Your pass is on screen. Tap **Add to home screen** to open it like an
   app, or **Email me my pass** to keep a copy.
3. **At the gate,** show the QR code on the way in and on the way out.

Staff passes last a year; admins can extend them.

## C3. Guards (gate app)

**Starting a shift.** Open the app, sign in with your work email and the code, and choose
your gate. Shared phone? Each guard signs in to their own account. Sign out from the
account button at the top of **Home** when your shift ends.

The tabs along the bottom are **Home**, **Scan**, **On site** and **New visitor**.

**Scanning.** Tap **Scan** (or **Scan pass** on Home) and point the camera at the QR code.

| You see | What to do |
| --- | --- |
| **Entry recorded** (green) | Let them in. |
| **Exit recorded** | Let them out; the time on site is shown. |
| **Pass revoked** / **Pass expired** / **Not valid yet** | Don't let them in. Ask them to contact reception. Admins are told automatically. |
| **Needs approval** / **Not approved yet** | Reception hasn't decided yet. Ask them to wait. |
| **Unknown code** | It isn't an OMIS Entry pass. |
| **Saved offline — will sync** | No internet right now; the scan is saved and sent later. Carry on. |

**A visitor without a pass.** Tap **New visitor**, enter their details, and add a photo of
their ID if your site requires it. Tap **Send for approval**. The waiting screen updates by
itself when reception decides. Been here before? Use **Returning visitor? Find their pass**.

**Who is inside.** **On site** lists everyone currently in, with entry times. Use
**Check out** for someone who left without scanning.

**No internet.** A bar at the top says **Offline**, with the number of scans waiting. Keep
scanning. Everything is sent when the signal returns. Passes the phone has never seen
before can't be checked offline.

## C4. Receptionists (gate app)

Your tabs are **Home**, **Scan**, **Approvals**, **On site** and **More**.

- **New requests** appear in **Approvals**, with a notification if Firebase is set up.
- **Deciding a request.** Open it to see the details (and ID photo, if any), then tap
  **Approve**. Or tap **Reject** and give a reason; the visitor sees that reason.
- **Requests left waiting** longer than the approval timeout (5 minutes by default) are
  escalated to admins.
- **A visitor showing a pending request at the desk:** scan it to open the request
  straight away.

## C5. Admins (dashboard on a computer)

Open `https://<your website>/admin` and sign in with your email code.

| Page | Use it to |
| --- | --- |
| **Overview** | See who is on site now, today's entries by hour and anything needing attention. Check out a person here. |
| **Visits** | Search the full log by name, ID number or plate; filter by gate, pass type and dates. **Export CSV** opens in Excel. |
| **Requests** | Approve or reject visitor requests (pending, escalated and past ones). |
| **Passes** | Show someone's QR code, email it again, **Extend** it, or **Revoke** it with a reason (the holder is emailed). |
| **Users** | **Invite user** to add a guard, receptionist or admin (they get an email). Change roles, or **Deactivate** someone who has left. |
| **Gates** | Add a gate, or close one (scans there are refused until it is reopened). |
| **Flags** | Review problems: blocked passes that were scanned, visits closed automatically at night, and conflicts from offline scans. Click **Resolve** when each is dealt with. |
| **Settings** | Organisation name, allowed staff email domains, pass lengths, approval timeout, nightly auto-close time, how long ID photos are kept, and the privacy contact. |

**Automatic jobs** run without anyone doing anything:
- **Every minute:** requests left waiting past the approval timeout are escalated to admins.
- **Every 5 minutes:** anyone still marked inside after the auto-close time (23:59 by
  default) is checked out and flagged.
- **Every 15 minutes:** passes past their end date become expired.
- **Every hour:** form-protection records older than a day are deleted.
- **Every night:** ID photos past their retention period are deleted.
- **Every Sunday:** details of visitor requests that were never approved are removed after
  90 days.

---

# Part D: looking after it

| How often | Task |
| --- | --- |
| Daily | Glance at **Overview** and **Flags**; resolve flags. |
| Weekly | Export the visits log if your site keeps paper records. Check Sentry for new errors. Take an off-site backup (`npm run db:backup -- --db-url ...`, see GO-LIVE.md) and store it encrypted. |
| When someone leaves | **Users → Deactivate** (operators). **Passes → Revoke** (staff pass). |
| Monthly | Check that the Supabase dashboard shows recent backups. Make sure each gate phone has the latest app. |
| Every few months | Do a restore drill (`npm run db:restore-drill`, see GO-LIVE.md). |

**Updating the system** (for whoever maintains the code):
- **Website:** changes pushed to GitHub redeploy automatically on Vercel.
- **Database:** run `npx supabase db push` after new migrations.
- **Email programs:** run `npx supabase functions deploy` after changes.
- **Gate app:** build a new APK (step B5) and install it over the old one. Use the same
  signing key, or the update fails.

**Personal data.** The system holds names, ID numbers, phone numbers and plates. Only give
admin access to people who need it. Never send exports or backups by email or WhatsApp,
and delete old exports. The public privacy notice is at `/privacy`.

---

## Troubleshooting

| Problem | What to try |
| --- | --- |
| `npm run db:start` says Docker isn't running | Open Docker Desktop and wait for **Engine running**, then try again. |
| Docker freezes or nothing responds | Usually the disk is full. Free at least 10 GB, quit and reopen Docker Desktop, then run `npm run db:start`. |
| `command not found: npm` / `node` / `flutter` | That tool isn't installed, or the terminal was open before you installed it. Close the terminal, open a new one and try again. |
| No sign-in code arrives (locally) | Look in the test inbox, http://127.0.0.1:54324, not your real email. Is `npm run functions` running in a terminal? |
| No sign-in code arrives (online) | Check the Supabase SMTP settings (B1.6) and that the domain is verified in Resend. Check spam. |
| "Use your work email address" when a staff member signs in | Their email domain isn't in **Settings → Allowed email domains**. |
| A staff member's domain is right but they still can't sign up | Check that the **Before User Created** hook is on (B1.6). |
| Website shows "Something went wrong" | Check Sentry; for a local copy, read the terminal running `npm run dev`. |
| Gate app shows "Supabase not configured" | The app was built without the settings file. Rebuild with `--dart-define-from-file=env/...json`. |
| Gate app can't connect (local testing) | The phone and computer must be on the same Wi-Fi, and `SUPABASE_URL` must use the computer's Wi-Fi address, not `127.0.0.1`. |
| Approved visitor didn't get an email | Check the Vault secrets (B1.5), the Resend key, and that the request has an email address. |
| "Too many requests" on the visitor form | It allows 5 requests per phone number and 30 per network each hour. Wait an hour, or have the guard register the visitor. |
| Scan says **Saved offline** but the phone has internet | Wait a minute; it syncs automatically. If the bar stays, sign out and back in. |
| A person shows as on site but they left | Use **Check out** in the app (**On site**) or on the dashboard **Overview**. |

---

## Where to find more

| Document | For |
| --- | --- |
| [README.md](../README.md) | Developer quick reference: commands, test accounts, features |
| [docs/SPEC.md](SPEC.md) | The full design: rules, data, screens and colours |
| [docs/GO-LIVE.md](GO-LIVE.md) | Go-live checklist: error tracking, backups, load test, privacy, field test |
| `supabase/migrations/` | Every database rule, in the order applied |
