#!/usr/bin/env bash
# Dumps auth_db and school_db from the running Docker Compose stack and keeps
# the newest $KEEP dumps of each. Run on the server from anywhere:
#   ~/apps/school-management/scripts/backup-db.sh
# Restore (after a failed release, with the owner's approval):
#   docker compose exec -T school-db pg_restore -U school_user -d school_db --clean --if-exists < school_db-<ts>.dump
set -euo pipefail

COMPOSE_DIR=${COMPOSE_DIR:-"$(cd "$(dirname "$0")/../backend" && pwd)"}
BACKUP_DIR=${BACKUP_DIR:-"$HOME/backups/school-management"}
KEEP=${KEEP:-14}

ts=$(date +%F-%H%M%S)
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

dump() {
  local service=$1 user=$2 db=$3
  local file="$BACKUP_DIR/$db-$ts.dump"
  docker compose --project-directory "$COMPOSE_DIR" exec -T "$service" pg_dump -U "$user" -Fc "$db" > "$file.partial"
  # A custom-format dump always starts with "PGDMP"; anything else means pg_dump failed
  if [ "$(head -c 5 "$file.partial")" != "PGDMP" ]; then
    echo "backup of $db looks broken, keeping $file.partial for inspection" >&2
    return 1
  fi
  mv "$file.partial" "$file"
  chmod 600 "$file"
  echo "$file ($(du -h "$file" | cut -f1))"
  # Rotate: names sort by timestamp, so the glob lists the oldest first
  local dumps=("$BACKUP_DIR/$db-"*.dump)
  local excess=$(( ${#dumps[@]} - KEEP ))
  if [ "$excess" -gt 0 ]; then
    rm -- "${dumps[@]:0:excess}"
  fi
}

dump auth-db auth_user auth_db
dump school-db school_user school_db
