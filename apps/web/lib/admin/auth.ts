import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type AdminProfile = {
  id: string;
  full_name: string | null;
  email: string;
};

/**
 * Every admin page and action starts here: a signed-in, active admin, with the role
 * read from profiles (never from the client). Otherwise → the admin sign-in page.
 */
export async function requireAdmin() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/admin/sign-in");
  const { data: profile } = await supabase
    .from("profiles")
    .select("id, full_name, email, role, is_active")
    .eq("id", user.id)
    .maybeSingle();
  if (!profile || profile.role !== "admin" || !profile.is_active)
    redirect("/admin/sign-in?denied=1");
  return { supabase, admin: profile as AdminProfile };
}
