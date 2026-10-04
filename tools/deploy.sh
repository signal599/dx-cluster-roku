#!/usr/bin/env bash
# Build the channel zip and sideload it onto the dev Roku.
#
#   tools/deploy.sh                  build and install
#   tools/deploy.sh --package-only   build out/dx-cluster.zip only
#
# Settings come from .env at the repo root (see .env.example). Variables
# already set in the environment take precedence over .env.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$ROOT/build/stage"
ZIP="$ROOT/out/dx-cluster.zip"

die() { echo "deploy: $*" >&2; exit 1; }

package_only=false
for arg in "$@"; do
    case "$arg" in
        --package-only) package_only=true ;;
        -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $arg" ;;
    esac
done

# --- Load .env without overriding variables that are already set -----------

load_env() {
    local file="$1" line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"            # trim leading space
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" == *=* ]] || die "$file: bad line: $line"
        key="${line%%=*}"
        value="${line#*=}"
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "$file: bad key: $key"
        if [[ "$value" =~ ^\"(.*)\"$ || "$value" =~ ^\'(.*)\'$ ]]; then
            value="${BASH_REMATCH[1]}"
        else
            value="${value%%[[:space:]]#*}"                  # strip " # comment"
            value="${value%"${value##*[![:space:]]}"}"       # trim trailing space
        fi
        if [[ -z "${!key+set}" ]]; then
            export "$key=$value"
        fi
    done < "$file"
}

[[ -f "$ROOT/.env" ]] || die "no .env found - copy .env.example to .env and fill it in"
load_env "$ROOT/.env"

# --- Validate cluster settings ----------------------------------------------

CLUSTER_MODE="${CLUSTER_MODE:-telnet-login}"
CLUSTER_CALLSIGN="${CLUSTER_CALLSIGN:-}"
[[ -n "${CLUSTER_HOST:-}" ]] || die "CLUSTER_HOST is not set"
[[ "$CLUSTER_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || die "CLUSTER_HOST has invalid characters: $CLUSTER_HOST"
[[ "${CLUSTER_PORT:-}" =~ ^[0-9]+$ ]] && (( CLUSTER_PORT >= 1 && CLUSTER_PORT <= 65535 )) \
    || die "CLUSTER_PORT must be a number from 1 to 65535"
case "$CLUSTER_MODE" in
    telnet-login) [[ -n "$CLUSTER_CALLSIGN" ]] || die "CLUSTER_CALLSIGN is required in telnet-login mode" ;;
    raw) ;;
    *) die "CLUSTER_MODE must be telnet-login or raw" ;;
esac
[[ "$CLUSTER_CALLSIGN" =~ ^[A-Za-z0-9/-]*$ ]] || die "CLUSTER_CALLSIGN has invalid characters: $CLUSTER_CALLSIGN"

# --- Stage app/ plus config.json, then zip ----------------------------------

rm -rf "$STAGE"
mkdir -p "$STAGE" "$(dirname "$ZIP")"
cp -R "$ROOT/app/." "$STAGE/"

# Values are validated above, so they need no JSON escaping.
cat > "$STAGE/config.json" <<EOF
{
  "host": "$CLUSTER_HOST",
  "port": $((10#$CLUSTER_PORT)),
  "callsign": "$CLUSTER_CALLSIGN",
  "mode": "$CLUSTER_MODE"
}
EOF

rm -f "$ZIP"
(cd "$STAGE" && zip -qr "$ZIP" . -x '.*' -x '*/.*')
echo "deploy: built ${ZIP#"$ROOT/"} ($CLUSTER_HOST:$CLUSTER_PORT, $CLUSTER_MODE${CLUSTER_CALLSIGN:+, $CLUSTER_CALLSIGN})"

$package_only && exit 0

# --- Sideload ----------------------------------------------------------------

[[ -n "${ROKU_IP:-}" ]] || die "ROKU_IP is not set"
[[ -n "${ROKU_PASSWORD:-}" ]] || die "ROKU_PASSWORD is not set"

echo "deploy: installing on $ROKU_IP ..."
response="$(mktemp)"
trap 'rm -f "$response"' EXIT

# Pass the credentials through a curl config on stdin so they don't show up in `ps`.
escaped_password="$(printf '%s' "$ROKU_PASSWORD" | sed 's/[\\"]/\\&/g')"
status="$(printf 'user = "rokudev:%s"\n' "$escaped_password" | curl --silent --show-error \
    --config - --digest --connect-timeout 10 --max-time 120 \
    --output "$response" --write-out '%{http_code}' \
    --form mysubmit=Install --form "archive=@$ZIP" \
    "http://$ROKU_IP/plugin_install")" || die "could not reach the Roku at $ROKU_IP"

case "$status" in
    200) ;;
    401) die "the Roku rejected the password (HTTP 401) - check ROKU_PASSWORD" ;;
    *) die "install failed with HTTP $status" ;;
esac

# The installer replies with an HTML page; pull out its status messages.
messages="$(grep -oE "'(Install Success|Identical to previous version|Install Failure|Failed)[^']*'" "$response" \
    | tr -d "'" | sort -u || true)"
[[ -n "$messages" ]] && echo "$messages" | sed 's/^/deploy: roku says: /'
if grep -qE 'Install Failure|Failed' <<<"$messages"; then
    exit 1
fi

echo "deploy: done. Debug console: telnet $ROKU_IP 8085"
