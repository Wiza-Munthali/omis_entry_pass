// cleanup-id-photos — removes ID photos past their delete_after date: the files from
// the private bucket (storage only allows this through its API), then the rows
// (docs/SPEC.md → Scheduled jobs: daily 02:00).
//
// Called only by the database (cleanup-id-photos cron job via pg_net) with x-internal-secret.
import { serviceClient } from "../_shared/admin.ts";
import { json, safeEqual } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const expected = Deno.env.get("INTERNAL_HOOK_SECRET");
  if (!expected || !safeEqual(req.headers.get("x-internal-secret") ?? "", expected)) {
    return json(401, { error: "unauthorized" });
  }

  const supabase = serviceClient();
  const { data: due, error } = await supabase
    .from("id_photos")
    .select("id, storage_path")
    .lt("delete_after", new Date().toISOString())
    .limit(500);
  if (error) return json(500, { error: "lookup_failed" });
  if (!due?.length) return json(200, { deleted: 0 });

  const { error: removeError } = await supabase.storage.from("id-photos").remove(due.map((p) => p.storage_path));
  if (removeError) {
    console.error("cleanup-id-photos: storage remove failed", removeError);
    return json(502, { error: "storage_failed" });
  }
  const { error: deleteError } = await supabase.from("id_photos").delete().in("id", due.map((p) => p.id));
  if (deleteError) return json(500, { error: "rows_not_deleted" });

  return json(200, { deleted: due.length });
});
