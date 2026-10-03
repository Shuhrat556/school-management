#!/usr/bin/env bash
# Runs the whole stack natively, without Docker: a throwaway PostgreSQL, auth-service, school-service,
# the gateway and the built admin-web server. Data, logs and pids live in .local-stack/ (git-ignored).
#
#   scripts/local-stack.sh start     # fresh databases (migrated + seeded), then http://127.0.0.1:3000
#   scripts/local-stack.sh status
#   scripts/local-stack.sh stop
#
# Needs: PostgreSQL 16 client/server tools on PATH (initdb, pg_ctl, psql), the .NET SDK, Node 24.
# Ports: PostgreSQL 55432, auth 5102, school 5103, gateway 5001, admin-web 3000.
# Then: python3 scripts/smoke_test.py --write
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
DIR=${STACK_DIR:-$REPO/.local-stack}
PG_PORT=55432
PG="host=127.0.0.1 port=$PG_PORT user=postgres"

wait_for() { # url
  for _ in $(seq 1 90); do
    curl -fs -o /dev/null "$1" && return 0
    sleep 1
  done
  echo "timed out waiting for $1" >&2
  return 1
}

start_service() { # name, then env assignments, then project path
  local name=$1; shift
  nohup env "$@" > "$DIR/$name.log" 2>&1 &
  echo $! > "$DIR/$name.pid"
}

start() {
  mkdir -p "$DIR"
  [ -d "$DIR/pgdata" ] || initdb -D "$DIR/pgdata" -U postgres --auth=trust > /dev/null
  pg_ctl -D "$DIR/pgdata" -l "$DIR/postgres.log" -o "-p $PG_PORT -c unix_socket_directories='' -c listen_addresses=127.0.0.1" start > /dev/null
  for db in auth_db school_db; do
    psql "$PG" -q -c "drop database if exists $db" -c "create database $db"
  done

  echo "building..."
  (cd "$REPO/admin-web" && API_URL=http://127.0.0.1:5001 npm run build > "$DIR/admin-web-build.log")
  for p in auth-service/AuthService/AuthService.API school-service/SchoolService/SchoolService.API api-gateway/ApiGateway; do
    dotnet build "$REPO/backend/services/$p" > "$DIR/build.log"
  done

  local secret
  secret=$(openssl rand -hex 32)
  local common=(ASPNETCORE_ENVIRONMENT=Development "Jwt__Secret=$secret" Consul__Enabled=false)
  start_service auth "${common[@]}" ASPNETCORE_URLS=http://127.0.0.1:5102 \
    "ConnectionStrings__AuthDb=Host=127.0.0.1;Port=$PG_PORT;Database=auth_db;Username=postgres" \
    dotnet run --no-build --no-launch-profile --project "$REPO/backend/services/auth-service/AuthService/AuthService.API"
  start_service school "${common[@]}" ASPNETCORE_URLS=http://127.0.0.1:5103 \
    "ConnectionStrings__SchoolDb=Host=127.0.0.1;Port=$PG_PORT;Database=school_db;Username=postgres" \
    dotnet run --no-build --no-launch-profile --project "$REPO/backend/services/school-service/SchoolService/SchoolService.API"
  start_service gateway ASPNETCORE_ENVIRONMENT=Development ASPNETCORE_URLS=http://127.0.0.1:5001 \
    "ReverseProxy__Clusters__auth-cluster__Destinations__auth-service__Address=http://127.0.0.1:5102/" \
    "ReverseProxy__Clusters__school-cluster__Destinations__school-service__Address=http://127.0.0.1:5103/" \
    dotnet run --no-build --no-launch-profile --project "$REPO/backend/services/api-gateway/ApiGateway"

  # The standalone server needs its static files next to it (as in the Dockerfile).
  rm -rf "$DIR/admin-web" && mkdir -p "$DIR/admin-web"
  cp -R "$REPO/admin-web/.next/standalone/." "$DIR/admin-web/"
  cp -R "$REPO/admin-web/.next/static" "$DIR/admin-web/.next/static"
  (cd "$DIR/admin-web" && start_service admin-web PORT=3000 HOSTNAME=127.0.0.1 node server.js)

  wait_for http://127.0.0.1:5102/health
  wait_for http://127.0.0.1:5103/health
  wait_for http://127.0.0.1:5001/health
  wait_for http://127.0.0.1:3000/login
  echo "ready: http://127.0.0.1:3000 (logs in $DIR)"
}

stop() {
  for name in admin-web gateway school auth; do
    if [ -f "$DIR/$name.pid" ]; then
      pkill -P "$(cat "$DIR/$name.pid")" 2> /dev/null || true # dotnet run's child process
      kill "$(cat "$DIR/$name.pid")" 2> /dev/null || true
      rm -f "$DIR/$name.pid"
    fi
  done
  [ -d "$DIR/pgdata" ] && pg_ctl -D "$DIR/pgdata" stop > /dev/null 2>&1 || true
  echo "stopped"
}

status() {
  for url in http://127.0.0.1:5102/health http://127.0.0.1:5103/health http://127.0.0.1:5001/health http://127.0.0.1:3000/login; do
    printf '%-36s %s\n' "$url" "$(curl -s -o /dev/null -w '%{http_code}' "$url" || true)"
  done
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  *) echo "usage: $0 start|stop|status" >&2; exit 2 ;;
esac
