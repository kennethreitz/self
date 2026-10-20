#!/usr/bin/env bash
# Prune old Dokploy/MinIO backup objects to a retention count.
#
# Dokploy stores each scheduled backup as a MinIO multipart OBJECT, which on the
# single-node fs backend is a *directory* of `part.NN` chunks + `xl.meta` named
# like `webserver-backup-YYYY-MM-DDT00-00-00-000Z.zip`. Their ISO-8601 names sort
# chronologically, so "keep newest N" = keep the last N after a lexical sort.
#
# Runs on the server, e.g. from /etc/cron.d (see docs/server-setup.md).
#
# Usage:
#   scripts/prune-backups.sh                 # keep 7 (default), really delete
#   KEEP=14 scripts/prune-backups.sh         # keep 14
#   DRY_RUN=1 scripts/prune-backups.sh       # show what would be deleted, delete nothing
#
# Env:
#   KEEP     number of most-recent backups to keep per job dir (default 7)
#   BASE     backups root (default /var/lib/minio-infra/dokploy-backups)
#   DRY_RUN  set to 1 to only print
set -euo pipefail

KEEP="${KEEP:-7}"
BASE="${BASE:-/var/lib/minio-infra/dokploy-backups}"
DRY_RUN="${DRY_RUN:-0}"

[[ "$KEEP" =~ ^[0-9]+$ && "$KEEP" -ge 1 ]] || { echo "KEEP must be a positive integer" >&2; exit 2; }
[[ -d "$BASE" ]] || { echo "backups root not found: $BASE" >&2; exit 1; }

ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
deleted_total=0

# Each immediate subdir of BASE is one backup JOB; its child dirs are the backup objects.
for job in "$BASE"/*/; do
  [[ -d "$job" ]] || continue
  jobname="$(basename "$job")"

  # Object dirs, oldest first; drop the newest KEEP, prune the rest by full path.
  mapfile -t victims < <(find "$job" -mindepth 1 -maxdepth 1 -type d | sort | head -n "-$KEEP")
  (( ${#victims[@]} )) || { echo "$(ts) [$jobname] nothing to prune (<= $KEEP backups)"; continue; }

  for obj in "${victims[@]}"; do
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "$(ts) [$jobname] WOULD delete $(basename "$obj") ($(du -sh "$obj" 2>/dev/null | cut -f1))"
    else
      sz="$(du -sh "$obj" 2>/dev/null | cut -f1)"
      rm -rf "$obj"
      echo "$(ts) [$jobname] deleted $(basename "$obj") ($sz)"
      ((deleted_total++))
    fi
  done
done

echo "$(ts) done — keep=$KEEP, deleted=$deleted_total, dry_run=$DRY_RUN, df=$(df -h "$BASE" | awk 'NR==2{print $5" used, "$4" free"}')"
