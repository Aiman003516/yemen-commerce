#!/usr/bin/env python3
"""Evaluate measured Edge model benchmark records.

Input is a JSON object with a `records` array collected on real devices. This
script does not generate or infer measurements. It reports pass/fail against
explicit release gates so the model remains disabled until evidence exists.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import mean
from typing import Any

THRESHOLDS = {
    "max_p95_first_token_ms": 4000,
    "max_p95_total_ms": 20000,
    "max_peak_memory_mb": 1024,
    "max_battery_pct_per_10_requests": 8.0,
    "max_crash_rate": 0.01,
    "min_completed_requests": 20,
}


def percentile(values: list[float], fraction: float) -> float:
    if not values:
        return float("inf")
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, round((len(ordered) - 1) * fraction)))
    return ordered[index]


def evaluate(records: list[dict[str, Any]]) -> dict[str, Any]:
    completed = [row for row in records if row.get("completed") is True]
    first_token = [float(row["first_token_ms"]) for row in completed if "first_token_ms" in row]
    total = [float(row["total_ms"]) for row in completed if "total_ms" in row]
    memory = [float(row["peak_memory_mb"]) for row in records if "peak_memory_mb" in row]
    battery = [float(row["battery_pct_per_10_requests"]) for row in records if "battery_pct_per_10_requests" in row]
    crashes = sum(1 for row in records if row.get("crashed") is True)
    crash_rate = crashes / len(records) if records else 1.0
    metrics = {
        "record_count": len(records),
        "completed_count": len(completed),
        "p95_first_token_ms": percentile(first_token, 0.95),
        "p95_total_ms": percentile(total, 0.95),
        "max_peak_memory_mb": max(memory, default=float("inf")),
        "mean_battery_pct_per_10_requests": mean(battery) if battery else float("inf"),
        "crash_rate": crash_rate,
    }
    checks = {
        "minimum_completed_requests": metrics["completed_count"] >= THRESHOLDS["min_completed_requests"],
        "first_token_latency": metrics["p95_first_token_ms"] <= THRESHOLDS["max_p95_first_token_ms"],
        "total_latency": metrics["p95_total_ms"] <= THRESHOLDS["max_p95_total_ms"],
        "peak_memory": metrics["max_peak_memory_mb"] <= THRESHOLDS["max_peak_memory_mb"],
        "battery": metrics["mean_battery_pct_per_10_requests"] <= THRESHOLDS["max_battery_pct_per_10_requests"],
        "crash_rate": metrics["crash_rate"] <= THRESHOLDS["max_crash_rate"],
    }
    return {
        "gate": "edge5_real_device_benchmark",
        "passed": all(checks.values()),
        "thresholds": THRESHOLDS,
        "metrics": metrics,
        "checks": checks,
        "note": "A missing measurement fails its gate; no result is imputed.",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    payload = json.loads(args.input.read_text(encoding="utf-8"))
    records = payload.get("records") if isinstance(payload, dict) else None
    if not isinstance(records, list) or not all(isinstance(row, dict) for row in records):
        raise ValueError("input must be an object with a records array of objects")
    report = evaluate(records)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"passed={report['passed']}")
    print(f"completed_count={report['metrics']['completed_count']}")
    print(f"report={args.output}")
    return 0 if report["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
