import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { ScreenHeader } from "@/components/portal/screen-header";
import { DetailsForm } from "./details-form";

// P4 Staff details (also "edit details" from the pass page)
export default async function StaffDetailsPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/staff");

  // RLS returns only the signed-in staff member's own rows.
  const [{ data: person }, { data: pass }] = await Promise.all([
    supabase.from("people").select("full_name, id_number").maybeSingle(),
    supabase
      .from("passes")
      .select("id, vehicles(plate)")
      .eq("type", "staff")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);
  const plate =
    (pass?.vehicles as unknown as { plate: string } | null)?.plate ?? "";
  const isEdit = Boolean(pass);

  return (
    <>
      <ScreenHeader backHref={isEdit ? "/pass" : undefined} />
      <h1 className="mt-8 text-display font-semibold text-ink">
        {isEdit ? "Your details" : "About you"}
      </h1>
      <p className="mt-2 text-body text-text-muted">
        {isEdit
          ? "Changes apply to your pass straight away."
          : "This goes on your staff pass."}
      </p>
      <DetailsForm
        isEdit={isEdit}
        defaults={{
          fullName:
            person?.full_name ??
            (user.user_metadata?.full_name as string | undefined) ??
            "",
          idNumber: person?.id_number ?? "",
          drives: Boolean(plate),
          plate,
        }}
      />
    </>
  );
}
