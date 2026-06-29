#!/usr/bin/env bash
# Publish a random new state for a production line to NATS.
# The backend NatsLineStateService picks it up and writes to machine_states in Postgres.
#
# Usage:
#   ./send-line-state.sh             # defaults to LINE_ID=1
#   LINE_ID=2 ./send-line-state.sh

set -euo pipefail

LINE_ID=${LINE_ID:-1}
STATES=("running" "warning" "stopped")

# Query Postgres for the most recent state of this line
CURRENT=$(docker exec postgres-db psql -U mesrwl -d mes -t -A -c \
  "SELECT state FROM machine_states WHERE production_line_id = ${LINE_ID} ORDER BY ts DESC LIMIT 1;")

echo "Line ${LINE_ID} current state: ${CURRENT:-'(none)'}"

# Pick a random state that differs from current
NEXT_STATE=""
while [ -z "$NEXT_STATE" ]; do
  CANDIDATE="${STATES[$((RANDOM % 3))]}"
  if [ "$CANDIDATE" != "$CURRENT" ]; then
    NEXT_STATE="$CANDIDATE"
  fi
done

PAYLOAD="{\"lineId\":${LINE_ID},\"state\":\"${NEXT_STATE}\"}"
SUBJECT="lines.${LINE_ID}.state"

echo "Publishing ${SUBJECT}: ${PAYLOAD}"
docker run --rm --network host natsio/nats-box:latest \
  nats pub "$SUBJECT" "$PAYLOAD" --server nats://localhost:4222

echo "Done. Verify with:"
echo "  docker exec postgres-db psql -U mesrwl -d mes -c \"SELECT id, production_line_id, state, ts FROM machine_states WHERE production_line_id = ${LINE_ID} ORDER BY ts DESC LIMIT 3;\""
