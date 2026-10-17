// Local dev only: renders the QR codes of the seeded passes into seed-qr.html so the
// gate app can be tested by scanning them off a screen.
//   node scripts/seed-qr.mjs && open seed-qr.html
// Reads the local API URL and secret key from `supabase status`; never use in production.
import { execSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import QRCode from "qrcode";

const env = Object.fromEntries(
  execSync("npx supabase status -o env", {
    stdio: ["ignore", "pipe", "ignore"],
  })
    .toString()
    .split("\n")
    .map((line) => line.match(/^(\w+)="(.*)"$/))
    .filter(Boolean)
    .map((m) => [m[1], m[2]]),
);
const key = env.SECRET_KEY ?? env.SERVICE_ROLE_KEY;
if (!env.API_URL || !key)
  throw new Error("Local Supabase is not running (npm run db:start)");

const res = await fetch(
  `${env.API_URL}/rest/v1/passes?select=type,status,qr_token,valid_until,people(full_name),visits(exit_at)&order=created_at`,
  { headers: { apikey: key, Authorization: `Bearer ${key}` } },
);
if (!res.ok) throw new Error(`Could not read passes: ${res.status}`);
const passes = await res.json();

const expect = (p) => {
  const onSite = p.visits.some((v) => v.exit_at === null);
  if (onSite) return "Exit recorded (already on site), then Entry recorded";
  if (p.status === "approved" && new Date(p.valid_until) > new Date())
    return "Entry recorded (scan again: Exit recorded)";
  return (
    {
      pending: "Not approved yet",
      rejected: "Request rejected",
      revoked: "Pass revoked",
      expired: "Pass expired",
    }[p.status] ?? "Pass expired"
  );
};

const cards = await Promise.all(
  [
    ...passes.map((p) => ({
      title: p.people.full_name,
      sub: `${p.type} · ${p.status}`,
      expect: expect(p),
      token: p.qr_token,
    })),
    {
      title: "Not an OMIS pass",
      sub: "random code",
      expect: "Unknown code",
      token: "not-an-omis-entry-pass",
    },
  ].map(async (c) => ({
    ...c,
    svg: await QRCode.toString(c.token, { type: "svg", margin: 2 }),
  })),
);

const esc = (s) =>
  String(s).replace(
    /[&<>"]/g,
    (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[ch],
  );
writeFileSync(
  "seed-qr.html",
  `<!doctype html><meta charset="utf-8"><title>Seeded pass QR codes (local)</title>
<style>body{font-family:system-ui,sans-serif;margin:24px}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:24px}
article{border:1px solid #ccc;border-radius:16px;padding:16px}svg{width:220px;height:220px;display:block;margin:8px auto}
h2{margin:0;font-size:18px}p{margin:4px 0;color:#555}.exp{color:#000;font-weight:600}</style>
<h1>Seeded pass QR codes</h1><p>Local development data. Scan with the gate app; results depend on current state (an entry flips to exit).</p>
<main>${cards
    .map(
      (c) =>
        `<article><h2>${esc(c.title)}</h2><p>${esc(c.sub)}</p>${c.svg}<p class="exp">Expect: ${esc(c.expect)}</p></article>`,
    )
    .join("")}</main>`,
);
console.log(`Wrote seed-qr.html with ${cards.length} codes`);
