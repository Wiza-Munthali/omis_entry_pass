import { createClient, type SupabaseClient } from "@supabase/supabase-js";

/** Service-role client for server-side reads and admin actions. */
export function serviceClient(): SupabaseClient {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
}

/** The caller's user id if their session belongs to an active admin, else null. */
export async function adminCaller(req: Request): Promise<string | null> {
  const authorization = req.headers.get("Authorization");
  if (!authorization) return null;
  const asUser = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data } = await asUser.auth.getUser();
  const id = data?.user?.id;
  if (!id) return null;
  // Role from the database, never from the request.
  const { data: profile } = await serviceClient().from("profiles").select("role, is_active").eq("id", id).maybeSingle();
  return profile?.role === "admin" && profile.is_active ? id : null;
}
