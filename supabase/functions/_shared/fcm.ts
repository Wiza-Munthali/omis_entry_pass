// Firebase Cloud Messaging (HTTP v1) without extra packages: the service account's
// private key signs a short-lived JWT (Web Crypto, RS256), exchanged for an access token.
// Configure with FCM_SERVICE_ACCOUNT_JSON (the downloaded key file's JSON, one line).

type ServiceAccount = { project_id: string; client_email: string; private_key: string; token_uri: string };

export type PushMessage = { title: string; body: string; data?: Record<string, string> };

let cached: { token: string; expiresAt: number } | null = null;

function serviceAccount(): ServiceAccount | null {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!raw) return null;
  try {
    const sa = JSON.parse(raw);
    return sa.project_id && sa.client_email && sa.private_key ? { token_uri: "https://oauth2.googleapis.com/token", ...sa } : null;
  } catch {
    console.error("FCM_SERVICE_ACCOUNT_JSON is not valid JSON");
    return null;
  }
}

export function pushConfigured(): boolean {
  return serviceAccount() !== null;
}

const b64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
const b64urlJson = (value: unknown) => b64url(new TextEncoder().encode(JSON.stringify(value)));

async function accessToken(sa: ServiceAccount): Promise<string> {
  if (cached && cached.expiresAt > Date.now() + 60_000) return cached.token;

  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${b64urlJson({ alg: "RS256", typ: "JWT" })}.${b64urlJson({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  })}`;

  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, [
    "sign",
  ]);
  const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)));

  const res = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${b64url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`FCM auth failed: ${res.status} ${await res.text()}`);
  const json = await res.json();
  cached = { token: json.access_token, expiresAt: Date.now() + json.expires_in * 1000 };
  return cached.token;
}

/**
 * Sends one notification to each device token. Returns the tokens FCM says are no
 * longer valid (app uninstalled, token rotated) so the caller can forget them.
 */
export async function sendPush(tokens: string[], message: PushMessage): Promise<{ sent: number; invalid: string[] }> {
  const sa = serviceAccount();
  if (!sa || tokens.length === 0) return { sent: 0, invalid: [] };
  const auth = await accessToken(sa);

  const results = await Promise.all(
    tokens.map(async (token) => {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: "POST",
        headers: { Authorization: `Bearer ${auth}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: message.title, body: message.body },
            data: message.data ?? {},
            android: { priority: "high", notification: { channel_id: "approvals" } },
            apns: { payload: { aps: { sound: "default" } } },
          },
        }),
      });
      if (res.ok) return { token, ok: true, invalid: false };
      const text = await res.text();
      const invalid = res.status === 404 || text.includes("UNREGISTERED") || text.includes("INVALID_ARGUMENT");
      if (!invalid) console.error("FCM send failed", res.status, text);
      return { token, ok: false, invalid };
    }),
  );
  return { sent: results.filter((r) => r.ok).length, invalid: results.filter((r) => r.invalid).map((r) => r.token) };
}
