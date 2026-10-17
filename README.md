# OMIS Entry

QR gate passes for staff and visitors. The full build spec is in [docs/SPEC.md](docs/SPEC.md).

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
The Android emulator reaches the host as `10.0.2.2`; on a real phone use your Mac's LAN IP.

## Day to day

| Task | Command |
| --- | --- |
| Web dev server (http://localhost:3000) | `npm run dev` |
| Gate app | `cd apps/gate && flutter run --dart-define-from-file=env/dev.json` |
| Reset DB (migrations + seed) | `npm run db:reset` |
| DB tests (pgTAP) | `npm run db:test` |
| Web lint / typecheck / tests | `npm run lint`, `npm run typecheck`, `npm test` |
| Web formatting | `npm run format` |
| Gate lint / tests | `cd apps/gate && flutter analyze && flutter test` |

## Rules

- Business logic lives in Postgres functions or Edge Functions; clients never write to `visits` or `passes` directly.
- Every table has RLS enabled, with a test per policy.
- Colours come only from the design tokens in `apps/web/app/globals.css` and `apps/gate/lib/core/theme/app_colors.dart`. Tests in both apps fail if they drift from the spec or if a colour literal appears elsewhere.
- `.env` files are never committed; the service-role key is used only inside Edge Functions.
