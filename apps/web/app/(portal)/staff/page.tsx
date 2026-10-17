import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { ScreenHeader } from "@/components/portal/screen-header";
import { EmailForm } from "./email-form";

// P2 Staff email
export default async function StaffEmailPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (user) {
    const { data: pass } = await supabase
      .from("passes")
      .select("id")
      .eq("type", "staff")
      .limit(1)
      .maybeSingle();
    redirect(pass ? "/pass" : "/staff/details");
  }

  const { data: config } = await supabase.rpc("portal_config");
  const domains: string[] = config?.allowed_email_domains ?? [];

  return (
    <>
      <ScreenHeader backHref="/" />
      <h1 className="mt-8 text-display font-semibold text-ink">
        Sign in with your work email
      </h1>
      <p className="mt-2 text-body text-text-muted">
        We&apos;ll email you a 6-digit code. No password needed.
      </p>
      <EmailForm domains={domains} />
    </>
  );
}
