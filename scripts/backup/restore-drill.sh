#!/usr/bin/env bash
# Restore drill (Phase 9): proves a backup can be restored, on the LOCAL database only.
#
#   scripts/backup/restore-drill.sh backups/<UTC time>
#
# Rebuilds the local database from the migrations (no seed), loads the backup's data,
# recreates the local Vault secrets, and checks every row count in counts.txt matches.
# This replaces whatever is in the local database with the backup's contents.
set -euo pipefail
cd "$(dirname "$0")/../.."
export PATH="$HOME/.docker/bin:$PATH"

dir="${1:?usage: restore-drill.sh backups/<UTC time>}"
for f in data.sql counts.txt; do
  [[ -s "$dir/$f" ]] || { echo "Missing $dir/$f"; exit 1; }
done

psql_local() { docker exec -i supabase_db_omis-entry psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -qAt "$@"; }

echo "1/4 Rebuilding the local database from migrations…"
npx supabase db reset --local --no-seed </dev/null >/dev/null

echo "2/4 Loading $dir/data.sql…"
# The migrations already created the settings row and a few auth/storage rows; the
# backup is the source of truth, so clear them first. Triggers stay off while loading:
# restored rows must not send emails, pushes or new audit entries.
{
  echo "set session_replication_role = replica;"
  echo "truncate public.settings, storage.buckets cascade;"
  cat "$dir/data.sql"
} | psql_local --single-transaction >/dev/null

echo "3/4 Recreating local Vault secrets…"
psql_local <<'SQL' >/dev/null
select vault.create_secret('http://supabase_kong_omis-entry:8000/functions/v1', 'functions_url');
select vault.create_secret('local-dev-only-internal-secret', 'internal_hook_secret');
SQL

echo "4/4 Comparing row counts…"
psql_local -F ' ' < scripts/backup/counts.sql > "$dir/counts.restored.txt"
if diff -u "$dir/counts.txt" "$dir/counts.restored.txt"; then
  jobs=$(psql_local -c "select count(*) from cron.job")
  echo "PASS: every table matches the backup ($(wc -l < "$dir/counts.txt" | tr -d ' ') tables); $jobs scheduled jobs."
else
  echo "FAIL: row counts differ (above)."
  exit 1
fi
