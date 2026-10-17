import { requireAdmin } from "@/lib/admin/auth";
import { ActionForm, TextField } from "@/components/admin/form-state";
import { PageHeader, Panel } from "@/components/admin/ui";
import { saveSettings } from "../../actions";

// A9 Settings: grouped form cards. One form so a change is saved together.
export default async function Settings() {
  const { supabase } = await requireAdmin();
  const { data: s } = await supabase.from("settings").select("*").single();
  if (!s) return <p className="text-danger">Settings could not be loaded.</p>;

  return (
    <div className="grid gap-6">
      <PageHeader
        title="Settings"
        subtitle="How passes, approvals and records work"
      />
      <ActionForm
        action={saveSettings}
        submit="Save settings"
        className="max-w-4xl"
      >
        <div className="grid gap-6 md:grid-cols-2">
          <Panel title="Organisation">
            <TextField
              label="Name"
              name="org_name"
              defaultValue={s.org_name}
              required
            />
          </Panel>
          <Panel
            title="Access"
            subtitle="Staff can get a pass with an email on these domains."
          >
            <TextField
              label="Allowed email domains"
              name="allowed_email_domains"
              defaultValue={(s.allowed_email_domains as string[]).join(", ")}
              hint="Separate with commas, e.g. ghii.org, ghii.mw"
            />
          </Panel>
          <Panel title="Passes">
            <div className="grid grid-cols-2 gap-4">
              <TextField
                label="Staff pass (days)"
                name="staff_pass_days"
                type="number"
                min={1}
                max={730}
                defaultValue={s.staff_pass_days}
              />
              <TextField
                label="Week pass (days)"
                name="week_pass_days"
                type="number"
                min={1}
                max={31}
                defaultValue={s.week_pass_days}
              />
            </div>
          </Panel>
          <Panel title="Approvals">
            <TextField
              label="Escalate to admins after (minutes)"
              name="approval_timeout_minutes"
              type="number"
              min={1}
              max={240}
              defaultValue={s.approval_timeout_minutes}
            />
          </Panel>
          <Panel title="Visits">
            <TextField
              label="Auto-close open visits at (Blantyre time)"
              name="auto_close_time"
              type="time"
              defaultValue={String(s.auto_close_time).slice(0, 5)}
            />
          </Panel>
          <Panel title="Privacy">
            <TextField
              label="Keep ID photos for (days)"
              name="id_photo_retention_days"
              type="number"
              min={1}
              max={365}
              defaultValue={s.id_photo_retention_days}
            />
          </Panel>
        </div>
      </ActionForm>
    </div>
  );
}
