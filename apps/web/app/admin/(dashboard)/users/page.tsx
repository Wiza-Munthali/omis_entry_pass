import { requireAdmin } from "@/lib/admin/auth";
import { timeAgo } from "@/lib/format";
import { ActionButton } from "@/components/admin/action-button";
import { ActionForm, TextField } from "@/components/admin/form-state";
import {
  Empty,
  Initials,
  PageHeader,
  Panel,
  Pill,
  Table,
} from "@/components/admin/ui";
import { inviteOperator, setUserActive, setUserRole } from "../../actions";

type User = {
  id: string;
  full_name?: string;
  email: string;
  role: "admin" | "receptionist" | "guard";
  is_active: boolean;
  last_sign_in_at?: string;
};
const ROLE_TONE = {
  admin: "brand",
  receptionist: "info",
  guard: "neutral",
} as const;
const ROLES = [
  { value: "guard", label: "Guard" },
  { value: "receptionist", label: "Receptionist" },
  { value: "admin", label: "Admin" },
];

// A7 Users: operators, role chip, last active, status; Invite user.
export default async function Users() {
  const { supabase, admin } = await requireAdmin();
  const { data, error } = await supabase.rpc("admin_users");
  const users = (data ?? []) as User[];

  return (
    <div className="grid gap-6">
      <PageHeader
        title="Users"
        subtitle="Guards, receptionists and admins who run the gates"
      />
      <div className="grid gap-6 xl:grid-cols-[1fr_360px]">
        <Panel>
          {error ? (
            <p className="text-danger">{error.message}</p>
          ) : !users.length ? (
            <Empty text="No operators yet." />
          ) : (
            <Table
              head={["Name", "Role", "Last active", "Status", "Actions"]}
              caption="Operators"
            >
              {users.map((u) => {
                const self = u.id === admin.id;
                return (
                  <tr key={u.id} className={u.is_active ? "" : "opacity-60"}>
                    <td>
                      <span className="flex items-center gap-2">
                        <Initials name={u.full_name ?? u.email} />
                        <span>
                          <span className="block font-medium text-ink">
                            {u.full_name ?? "—"}
                            {self && " (you)"}
                          </span>
                          <span className="block text-caption text-text-muted">
                            {u.email}
                          </span>
                        </span>
                      </span>
                    </td>
                    <td>
                      <Pill tone={ROLE_TONE[u.role]} dot={false}>
                        {u.role[0].toUpperCase() + u.role.slice(1)}
                      </Pill>
                    </td>
                    <td>
                      {u.last_sign_in_at ? timeAgo(u.last_sign_in_at) : "Never"}
                    </td>
                    <td>
                      {u.is_active ? (
                        <Pill tone="success">Active</Pill>
                      ) : (
                        <Pill tone="neutral">Deactivated</Pill>
                      )}
                    </td>
                    <td>
                      {self ? (
                        <span className="text-caption text-text-muted">—</span>
                      ) : (
                        <div className="flex flex-wrap items-start gap-2">
                          <ActionButton
                            label="Change role"
                            confirm={{
                              title: `Change ${u.full_name ?? u.email}'s role`,
                              action: "Save",
                            }}
                            field={{
                              name: "role",
                              label: "Role",
                              options: [
                                ROLES.find((r) => r.value === u.role)!,
                                ...ROLES.filter((r) => r.value !== u.role),
                              ],
                            }}
                            run={async (role) => {
                              "use server";
                              return setUserRole(u.id, role as User["role"]);
                            }}
                          />
                          <ActionButton
                            label={u.is_active ? "Deactivate" : "Reactivate"}
                            variant={u.is_active ? "danger" : "outline"}
                            confirm={
                              u.is_active
                                ? {
                                    title: `Deactivate ${u.full_name ?? u.email}?`,
                                    body: "They can no longer sign in to the gate app or dashboard. Their history stays.",
                                    action: "Deactivate",
                                  }
                                : undefined
                            }
                            run={setUserActive.bind(null, u.id, !u.is_active)}
                          />
                        </div>
                      )}
                    </td>
                  </tr>
                );
              })}
            </Table>
          )}
        </Panel>
        <Panel
          title="Invite user"
          subtitle="They sign in with an email code; no password."
        >
          <ActionForm action={inviteOperator} submit="Invite">
            <TextField label="Email" name="email" type="email" required />
            <TextField label="Full name" name="full_name" />
            <label className="grid gap-1.5 text-label font-medium">
              Role
              <select
                name="role"
                defaultValue="guard"
                className="h-11 rounded-full border border-border bg-surface px-4 font-normal"
              >
                {ROLES.map((r) => (
                  <option key={r.value} value={r.value}>
                    {r.label}
                  </option>
                ))}
              </select>
            </label>
          </ActionForm>
        </Panel>
      </div>
    </div>
  );
}
