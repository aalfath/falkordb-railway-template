#!/bin/sh
# Railway wrapper around the official FalkorDB entrypoint (run.sh).
# - refuses to start without a password (the server is reachable over the network)
# - turns on AOF persistence so a redeploy loses at most ~1 s of writes
# - keeps the Browser's API-token store on the same volume as the graph data
set -eu

DATA="${FALKORDB_DATA_PATH:-/var/lib/falkordb/data}"

if [ -z "${FALKORDB_PASSWORD:-}" ]; then
  echo "ERROR: FALKORDB_PASSWORD is empty. Set it (the template generates one) so the database is not open to anyone." >&2
  exit 1
fi
case "$FALKORDB_PASSWORD" in
  *[!A-Za-z0-9._~-]*)
    echo "ERROR: FALKORDB_PASSWORD may only use letters, digits and . _ ~ - (it is passed on the command line and used in URLs)." >&2
    exit 1 ;;
esac

# Browser secrets: empty values are dropped so the Browser generates its own.
[ -n "${AUTH_SECRET:-}" ] || unset AUTH_SECRET
[ -n "${ENCRYPTION_KEY:-}" ] || unset ENCRYPTION_KEY

mkdir -p "$DATA/browser"
export API_TOKEN_STORAGE_PATH="${API_TOKEN_STORAGE_PATH:-$DATA/browser/api_tokens.json}"

# Hand the volume to the unprivileged users ourselves (a fresh Railway volume is
# root-owned and holds lost+found, which makes run.sh keep redis as root).
if [ "$(id -u)" = "0" ]; then
  chown falkordb:falkordb "$DATA"
  find "$DATA" -mindepth 1 -maxdepth 1 \( -name '*.rdb' -o -name 'nodes*.conf' -o -name appendonlydir \) \
    -exec chown -R falkordb:falkordb {} +
  chown -R nextjs:nodejs "$DATA/browser"
  export SKIP_FIX_PERMS=1
fi

# Server options: password, AOF (fsync every second) on top of the default RDB
# snapshots, plus anything the deployer adds in REDIS_ARGS.
export REDIS_ARGS="--requirepass ${FALKORDB_PASSWORD} --appendonly yes --appendfsync everysec ${REDIS_ARGS:-}"

exec /var/lib/falkordb/bin/run.sh "$@"
