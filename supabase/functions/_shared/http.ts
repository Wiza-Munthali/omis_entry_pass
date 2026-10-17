// Small HTTP helpers shared by the Edge Functions.

/** CORS headers for the public portal (PORTAL_URL); other origins get none. */
export function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin");
  const allowed = (Deno.env.get("PORTAL_URL") ?? "http://localhost:3000").replace(/\/$/, "");
  if (!origin || origin !== allowed) return {};
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
    Vary: "Origin",
  };
}

export function json(status: number, body: unknown, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

/** Constant-time string comparison for shared secrets. */
export function safeEqual(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}
