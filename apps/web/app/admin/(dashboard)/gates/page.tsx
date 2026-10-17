import { DoorOpen } from "lucide-react";
import { requireAdmin } from "@/lib/admin/auth";
import { ActionButton } from "@/components/admin/action-button";
import { ActionForm, TextField } from "@/components/admin/form-state";
import { PageHeader, Panel, Pill } from "@/components/admin/ui";
import { addGate, setGateActive } from "../../actions";

// A8 Gates: one card per gate with active toggle and today's entries; Add gate.
export default async function Gates() {
  const { supabase } = await requireAdmin();
  const startOfToday = new Date(
    new Intl.DateTimeFormat("en-CA", { timeZone: "Africa/Blantyre" }).format(
      new Date(),
    ) + "T00:00:00+02:00",
  ).toISOString();
  const [{ data: gates }, { data: today }] = await Promise.all([
    supabase.from("gates").select("id, name, is_active").order("name"),
    supabase.from("visits").select("gate_id").gte("entry_at", startOfToday),
  ]);
  const entries = new Map<string, number>();
  today?.forEach((v) =>
    entries.set(v.gate_id, (entries.get(v.gate_id) ?? 0) + 1),
  );

  return (
    <div className="grid gap-6">
      <PageHeader
        title="Gates"
        subtitle="Where guards scan. Phones remember the gate they are posted at."
      />
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {gates?.map((g) => (
          <Panel key={g.id} className={g.is_active ? "" : "opacity-70"}>
            <div className="flex items-start justify-between gap-3">
              <span className="flex size-12 items-center justify-center rounded-full bg-brand-soft text-brand-strong">
                <DoorOpen className="size-6" />
              </span>
              {g.is_active ? (
                <Pill tone="success">Open</Pill>
              ) : (
                <Pill tone="neutral">Closed</Pill>
              )}
            </div>
            <h2 className="mt-4 text-title font-semibold text-ink">{g.name}</h2>
            <p className="text-label text-text-muted">
              {entries.get(g.id) ?? 0} entries today
            </p>
            <div className="mt-4">
              <ActionButton
                label={g.is_active ? "Close gate" : "Open gate"}
                variant={g.is_active ? "danger" : "outline"}
                confirm={
                  g.is_active
                    ? {
                        title: `Close ${g.name}?`,
                        body: "Scans there stop until it is opened again. Guards posted there will be asked to choose another gate.",
                        action: "Close gate",
                      }
                    : undefined
                }
                run={setGateActive.bind(null, g.id, !g.is_active)}
              />
            </div>
          </Panel>
        ))}
        <Panel title="Add gate">
          <ActionForm action={addGate} submit="Add gate">
            <TextField
              label="Name"
              name="name"
              placeholder="e.g. North gate"
              required
            />
          </ActionForm>
        </Panel>
      </div>
    </div>
  );
}
