#!/usr/bin/env python3
"""JSONEachRow producer for the events topic. Pure stdlib (no kafka-python).

We talk Kafka's binary protocol via the kafka-console-producer that ships
with the broker container — we just need to *write* the JSON lines.
This script writes them to stdout; run.sh pipes them into the broker.

Usage:
    python3 produce.py --rows 200000 > events.jsonl
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import random
import sys


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--rows", type=int, default=100_000)
    p.add_argument("--seed", type=int, default=7)
    args = p.parse_args()

    rng = random.Random(args.seed)
    base = dt.datetime(2026, 5, 1)

    for i in range(args.rows):
        rec = {
            "event_time": (base + dt.timedelta(seconds=rng.randint(0, 86400))).strftime("%Y-%m-%d %H:%M:%S"),
            "user_id":    rng.randint(1, 100_000),
            "event_type": rng.choices(
                ["view", "click", "purchase", "signup", "logout"],
                weights=[60, 25, 5, 5, 5],
            )[0],
            "revenue":    round(rng.uniform(0, 250), 2),
            "payload":    f"u{rng.randint(1,9999)}-s{i}",
        }
        sys.stdout.write(json.dumps(rec) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
