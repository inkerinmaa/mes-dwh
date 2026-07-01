#!/usr/bin/env bash
# check-nats.sh — inspect NATS broker state and optionally watch live messages
#
# Usage:
#   ./check-nats.sh            # show connections + subscriptions
#   ./check-nats.sh watch      # subscribe to opcua.floor1.PartCounter for 15 s
#   ./check-nats.sh watch all  # subscribe to > (all subjects) for 15 s

set -euo pipefail

NATS_MONITOR="http://localhost:8222"
TIMEOUT=15

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

ok()   { printf "${GREEN}[OK]${NC}  %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
fail() { printf "${RED}[FAIL]${NC} %s\n" "$*"; }

TMPDIR_NATS=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR_NATS"; }
trap cleanup EXIT

VARZ_FILE="$TMPDIR_NATS/varz.json"
CONNZ_FILE="$TMPDIR_NATS/connz.json"

# ── 1. Server health ────────────────────────────────────────────────────────

echo "=== NATS server ($NATS_MONITOR) ==="
if ! curl -sf --max-time 3 "$NATS_MONITOR/varz" -o "$VARZ_FILE"; then
    fail "NATS not reachable at $NATS_MONITOR"
    exit 1
fi

python3 - "$VARZ_FILE" <<'PY'
import sys, json
d = json.load(open(sys.argv[1]))
js = "enabled" if d.get("jetstream") else "disabled"
print(f"  version={d['version']}  uptime={d['uptime']}  JetStream={js}")
PY
ok "NATS is up"

# ── 2. Connections + subscriptions ─────────────────────────────────────────

echo ""
echo "=== Connections ==="
curl -sf --max-time 3 "${NATS_MONITOR}/connz?subs=1" -o "$CONNZ_FILE" \
  || curl -sf --max-time 3 "${NATS_MONITOR}/connz" -G --data-urlencode "subs=1" -o "$CONNZ_FILE"

python3 - "$CONNZ_FILE" <<'PY'
import sys, json

d = json.load(open(sys.argv[1]))
conns = d.get("connections", [])
print(f"  {d['num_connections']} connection(s)")
for c in conns:
    lang = c.get("lang", "?")
    name = c.get("name", "?")
    ip   = c.get("ip", "?")
    idle = c.get("idle", "?")
    subs = c.get("subscriptions_list") or []
    print(f"\n  [{lang}] {name}")
    print(f"    ip={ip}  idle={idle}  msgs_in={c.get('in_msgs',0)}  msgs_out={c.get('out_msgs',0)}")
    for s in subs:
        print(f"    subscribed: {s}")
PY

# ── 3. Expected subscription check ─────────────────────────────────────────

echo ""
echo "=== Subscription check ==="

python3 - "$CONNZ_FILE" <<'PY'
import sys, json

GREEN = "\033[0;32m"; RED = "\033[0;31m"; NC = "\033[0m"
ok   = lambda msg: print(f"{GREEN}[OK]{NC}  {msg}")
fail = lambda msg: print(f"{RED}[FAIL]{NC} {msg}")

d = json.load(open(sys.argv[1]))
all_subs = [s for c in d.get("connections", []) for s in (c.get("subscriptions_list") or [])]

checks = [
    ("opcua.floor1.PartCounter", "MES NatsOpcCounterService (OPC UA counter)"),
    ("lines.*.state",            "MES NatsLineStateService  (line state events)"),
]

for subject, label in checks:
    matched = any(s == subject for s in all_subs)
    if matched:
        ok(f"{label}\n    listening on: {subject}")
    else:
        fail(f"{label} — NOT subscribed ({subject})\n    → is mes-backend running?")

# Also warn if OPC UA client isn't connected
has_java = any(c.get("lang") in ("Java", "java") for c in d.get("connections", []))
has_go   = any(c.get("lang") in ("go", "Go") for c in d.get("connections", []))
if not has_java and not has_go:
    YELLOW = "\033[1;33m"
    print(f"\n{YELLOW}[WARN]{NC} No Java/Go client connected → eclipse-milo opc-client is probably not running")
    print("    Start it with:  cd ~/projects/eclipse-milo && docker compose up --build")
PY

# ── 4. Live message watch ───────────────────────────────────────────────────

if [ "${1:-}" = "watch" ]; then
    SUBJECT="${2:-opcua.floor1.PartCounter}"
    [ "$SUBJECT" = "all" ] && SUBJECT=">"

    echo ""
    echo "=== Watching '$SUBJECT' for ${TIMEOUT}s (Ctrl-C to stop early) ==="
    echo "    Uses natsio/nats-box (docker pull on first run)"
    echo ""

    docker run --rm \
        --network host \
        --name nats-watch-$$ \
        natsio/nats-box:latest \
        nats sub "$SUBJECT" --server nats://localhost:4222 &
    SUB_PID=$!

    (sleep "$TIMEOUT" && docker rm -f "nats-watch-$$" 2>/dev/null) &
    KILL_PID=$!

    wait "$SUB_PID" 2>/dev/null || true
    kill "$KILL_PID" 2>/dev/null || true
    echo ""
    echo "(watch ended after ${TIMEOUT}s)"
fi
