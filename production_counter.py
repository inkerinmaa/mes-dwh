#!/usr/bin/env python3
"""
Simulate a production counter message for a specific line.

The backend NatsOpcCounterService reads Counter from the message and computes
the delta against the previous value. If delta > 0 and a order is running on
that line, produced_volume is incremented by the delta.

Usage:
    python3 production_counter.py <line_id> <counter_value>

    line_id        : production line ID (1, 2, 3, ...)
    counter_value  : absolute counter value (integer ≥ 0)

Examples:
    python3 production_counter.py 1 100   # line 1 counter = 100
    python3 production_counter.py 2 43    # line 2 counter = 43

Counter is absolute — send increasing values to increment produced volume:
    python3 production_counter.py 1 0    # first message, sets baseline
    python3 production_counter.py 1 10   # +10 packages produced on line 1
    python3 production_counter.py 1 25   # +15 more packages produced on line 1
"""

import sys
import json
import subprocess

NATS_URL = "nats://localhost:4222"

# Must match Nats:OrderData[].ProductionCounter in appsettings.json
COUNTER_TOPICS = {
    1: "opcua.line1.PartCounter",
    2: "opcua.line2.PartCounter",
    3: "opcua.line3.PartCounter",
    4: "opcua.line4.PartCounter",
}


def usage():
    lines = ", ".join(f"{lid} → {topic}" for lid, topic in COUNTER_TOPICS.items())
    print(f"Usage: {sys.argv[0]} <line_id> <counter_value>", file=sys.stderr)
    print(f"Lines: {lines}", file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) != 3:
        usage()

    try:
        line_id = int(sys.argv[1])
        counter = int(sys.argv[2])
    except ValueError:
        print("Error: both arguments must be integers", file=sys.stderr)
        usage()

    if counter < 0:
        print("Error: counter_value must be >= 0", file=sys.stderr)
        sys.exit(1)

    if line_id not in COUNTER_TOPICS:
        print(f"Error: unknown line_id {line_id}", file=sys.stderr)
        print(f"Known lines: {list(COUNTER_TOPICS.keys())}", file=sys.stderr)
        sys.exit(1)

    topic = COUNTER_TOPICS[line_id]
    payload = json.dumps({"Counter": counter})

    print(f"Line {line_id}  |  {topic}  |  {payload}")

    result = subprocess.run(
        [
            "docker", "run", "--rm", "--network", "host",
            "natsio/nats-box:latest",
            "nats", "pub", topic, payload,
            "--server", NATS_URL,
        ],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(f"Error publishing: {result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)

    print("Published.")


if __name__ == "__main__":
    main()
