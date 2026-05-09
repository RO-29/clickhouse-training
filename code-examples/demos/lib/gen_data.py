#!/usr/bin/env python3
"""Synthetic event generator for ClickHouse training demos.

Writes TSV to stdout. Schema:
    event_time (DateTime)  user_id (UInt32)  country (String)
    device (String)  event_type (String)  revenue (Float64)
    session_id (UUID)  url (String)

Pure stdlib so it runs anywhere with python3.
"""
from __future__ import annotations

import argparse
import datetime as dt
import random
import sys
import uuid

COUNTRIES = ["US", "IN", "DE", "BR", "JP", "GB", "FR", "CA", "AU", "MX"]
DEVICES = ["ios", "android", "web", "tv"]
EVENTS = ["view", "click", "purchase", "signup", "logout", "search"]
PATHS = ["/home", "/cart", "/checkout", "/product/{n}", "/category/{c}", "/search?q={q}"]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--rows", type=int, default=1_000_000, help="rows to emit")
    p.add_argument("--start", default="2026-01-01", help="start date YYYY-MM-DD")
    p.add_argument("--days", type=int, default=90, help="time window length")
    p.add_argument("--users", type=int, default=100_000, help="distinct user_id pool")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument(
        "--shard-key",
        choices=["user_id", "none"],
        default="user_id",
        help="If set, biases distribution to mimic a real workload.",
    )
    return p.parse_args()


def main() -> int:
    args = parse_args()
    rng = random.Random(args.seed)
    start = dt.datetime.fromisoformat(args.start)
    span = dt.timedelta(days=args.days)
    window_seconds = int(span.total_seconds())

    out = sys.stdout
    write = out.write

    for _ in range(args.rows):
        ts = start + dt.timedelta(seconds=rng.randint(0, window_seconds))
        user = rng.randint(1, args.users)
        country = rng.choice(COUNTRIES)
        device = rng.choices(DEVICES, weights=[3, 4, 6, 1])[0]
        event = rng.choices(EVENTS, weights=[60, 25, 5, 4, 4, 2])[0]
        # Revenue only on purchase, otherwise 0.
        revenue = round(rng.uniform(5, 250), 2) if event == "purchase" else 0.0
        sess = uuid.UUID(int=rng.getrandbits(128))
        path = rng.choice(PATHS).replace("{n}", str(rng.randint(1, 9999))) \
                                .replace("{c}", rng.choice(["a", "b", "c", "d"])) \
                                .replace("{q}", f"q{rng.randint(1,99)}")

        write(
            f"{ts:%Y-%m-%d %H:%M:%S}\t{user}\t{country}\t{device}\t"
            f"{event}\t{revenue}\t{sess}\t{path}\n"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
