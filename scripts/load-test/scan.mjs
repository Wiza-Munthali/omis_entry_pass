#!/usr/bin/env node
// Load test for record_scan (Phase 9): target p95 under 300 ms, end to end through the API
// (client → API gateway → PostgREST → Postgres), the same path the gate app uses.
//
//   npm run load:scan -- --seed                 add test data, then run
//   npm run load:scan -- --concurrency 16 --duration 60
//   npm run load:scan -- --cleanup              remove the test data
//
// Local by default (keys from `supabase status`, SQL through the database container).
// For a staging project set SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY and
// DATABASE_URL (psql must be installed). Never point it at production: it writes visits.
//
// Each worker is a guard scanning back to back with no pause, so 8 workers is far more
// traffic than a real gate (a guard scans every few seconds at most).
import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");

const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const option = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? Number(args[i + 1]) : fallback;
};
const concurrency = option("concurrency", 8);
const durationS = option("duration", 30);
const targetMs = option("target", 300);
const guardEmail = process.env.LOAD_GUARD_EMAIL ?? "guard@ghii.test";

const dockerPath = `${process.env.HOME}/.docker/bin:${process.env.PATH}`;

function sql(text) {
  const opts = { encoding: "utf8", input: text, env: { ...process.env, PATH: dockerPath } };
  const out = process.env.DATABASE_URL
    ? execFileSync("psql", [process.env.DATABASE_URL, "-v", "ON_ERROR_STOP=1", "-qAt"], opts)
    : execFileSync(
        "docker",
        ["exec", "-i", "supabase_db_omis-entry", "psql", "-U", "postgres", "-v", "ON_ERROR_STOP=1", "-qAt"],
        opts,
      );
  return out.trim().split("\n").filter(Boolean);
}

function config() {
  if (process.env.SUPABASE_URL) {
    return {
      url: process.env.SUPABASE_URL.replace(/\/$/, ""),
      anonKey: process.env.SUPABASE_ANON_KEY,
      serviceKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
    };
  }
  const status = JSON.parse(
    execFileSync("npx", ["supabase", "status", "-o", "json"], {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      env: { ...process.env, PATH: dockerPath },
    }),
  );
  return { url: status.API_URL, anonKey: status.ANON_KEY, serviceKey: status.SERVICE_ROLE_KEY };
}

async function signInAsGuard({ url, anonKey, serviceKey }) {
  // An admin-generated sign-in link, used directly: no email is sent.
  const link = await fetch(`${url}/auth/v1/admin/generate_link`, {
    method: "POST",
    headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ type: "magiclink", email: guardEmail }),
  }).then((r) => r.json());
  if (!link.hashed_token) throw new Error(`Could not create a sign-in link for ${guardEmail}: ${JSON.stringify(link)}`);
  const session = await fetch(`${url}/auth/v1/verify`, {
    method: "POST",
    headers: { apikey: anonKey, "Content-Type": "application/json" },
    body: JSON.stringify({ type: "magiclink", token_hash: link.hashed_token }),
  }).then((r) => r.json());
  if (!session.access_token) throw new Error(`Sign-in failed: ${JSON.stringify(session)}`);
  return session.access_token;
}

const percentile = (sorted, p) => sorted[Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)];
const ms = (n) => `${n.toFixed(0)} ms`;

async function main() {
  if (flag("cleanup")) {
    console.log(sql(readFileSync(join(here, "cleanup.sql"), "utf8")).join("\n"));
    return;
  }
  if (flag("seed")) {
    console.log("Seeding load-test data…");
    console.log(sql(readFileSync(join(here, "seed.sql"), "utf8")).at(-1));
  }

  const tokens = sql(
    "select pa.qr_token from public.passes pa join public.people pe on pe.id = pa.person_id where pe.id_number like 'LOADTEST-%';",
  );
  if (tokens.length === 0) throw new Error("No load-test passes. Run with --seed first.");
  const gates = sql("select id from public.gates where is_active order by name;");
  const [visits] = sql("select count(*) from public.visits;");

  const cfg = config();
  const jwt = await signInAsGuard(cfg);
  const headers = {
    apikey: cfg.anonKey,
    Authorization: `Bearer ${jwt}`,
    "Content-Type": "application/json",
  };

  const scan = async () => {
    const started = performance.now();
    const res = await fetch(`${cfg.url}/rest/v1/rpc/record_scan`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        p_qr_token: tokens[Math.floor(Math.random() * tokens.length)],
        p_gate_id: gates[Math.floor(Math.random() * gates.length)],
        p_client_event_id: randomUUID(),
      }),
    });
    const body = await res.json().catch(() => ({}));
    return { elapsed: performance.now() - started, ok: res.ok, result: res.ok ? body.result : `HTTP ${res.status}` };
  };

  // Warm up connections and plans; not measured.
  await Promise.all(Array.from({ length: 20 }, scan));
  try {
    sql("select pg_stat_statements_reset();");
  } catch {
    // Not allowed on every project; the database-side figures are then cumulative.
  }

  console.log(
    `Scanning for ${durationS}s with ${concurrency} workers: ${tokens.length} passes, ${visits} visits in the table, ${gates.length} gates.`,
  );
  const timings = [];
  const results = {};
  const deadline = performance.now() + durationS * 1000;
  await Promise.all(
    Array.from({ length: concurrency }, async () => {
      while (performance.now() < deadline) {
        const r = await scan();
        timings.push(r.elapsed);
        results[r.result] = (results[r.result] ?? 0) + 1;
      }
    }),
  );

  timings.sort((a, b) => a - b);
  const p95 = percentile(timings, 95);
  const failures = Object.entries(results)
    .filter(([result]) => !["entry_recorded", "exit_recorded"].includes(result))
    .reduce((n, [, count]) => n + count, 0);

  console.log(`\n${timings.length} scans, ${(timings.length / durationS).toFixed(1)} per second`);
  console.log(
    `p50 ${ms(percentile(timings, 50))} · p90 ${ms(percentile(timings, 90))} · p95 ${ms(p95)} · p99 ${ms(percentile(timings, 99))} · max ${ms(timings.at(-1))}`,
  );
  console.log("Results:", results);
  try {
    const [row] = sql(
      "select calls || ' calls, mean ' || round(mean_exec_time::numeric, 1) || ' ms, max ' || round(max_exec_time::numeric, 1) || ' ms' from pg_stat_statements where query like '%record_scan%' and query not like '%pg_stat_statements%' order by calls desc limit 1;",
    );
    if (row) console.log(`Inside Postgres: ${row}`);
  } catch {
    // pg_stat_statements unavailable.
  }

  const passed = p95 < targetMs && failures === 0;
  console.log(
    passed
      ? `\nPASS: p95 ${ms(p95)} is under ${targetMs} ms, every scan recorded.`
      : `\nFAIL: p95 ${ms(p95)} (target ${targetMs} ms), ${failures} scans not recorded.`,
  );
  console.log("Remove the test data with: npm run load:scan -- --cleanup");
  process.exitCode = passed ? 0 : 1;
}

main().catch((e) => {
  console.error(e.message);
  process.exitCode = 1;
});
