#!/usr/bin/env bash
# Logical backup of the database (Phase 9): roles, schema and data, plus row counts.
#
#   scripts/backup/backup.sh                    local database
#   scripts/backup/backup.sh --db-url "$URL"    a hosted project (session pooler URL;
#                                               needs psql for the row counts)
#
# Writes backups/<UTC time>/ (git-ignored). Not included, by design:
# - Vault secrets (functions_url, internal_hook_secret): set them again after a restore;
# - ID photo files in Storage (kept 30 days at most); their rows are in data.sql;
# - cron job definitions and pg_net queues: the migrations recreate the jobs.
set -euo pipefail
cd "$(dirname "$0")/../.."
export PATH="$HOME/.docker/bin:$PATH"

target=(--local)
if [[ "${1:-}" == "--db-url" ]]; then target=(--db-url "$2"); fi

dir="backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$dir"

npx supabase db dump "${target[@]}" --role-only -f "$dir/roles.sql" </dev/null
npx supabase db dump "${target[@]}" -f "$dir/schema.sql" </dev/null
npx supabase db dump "${target[@]}" --data-only --use-copy \
  -x cron.job,cron.job_run_details,net._http_response,net.http_request_queue \
  -f "$dir/data.sql" </dev/null

if [[ "${target[0]}" == "--local" ]]; then
  docker exec -i supabase_db_omis-entry psql -U postgres -qAt -F ' ' < scripts/backup/counts.sql > "$dir/counts.txt"
else
  psql "${target[1]}" -qAt -F ' ' < scripts/backup/counts.sql > "$dir/counts.txt"
fi

echo "Backup written to $dir"
du -sh "$dir"/*
