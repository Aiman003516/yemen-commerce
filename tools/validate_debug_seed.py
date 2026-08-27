from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / "supabase/debug/seed_synthetic_debug.sql"
CLEANUP = ROOT / "supabase/debug/cleanup_synthetic_debug.sql"


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


seed = SEED.read_text(encoding="utf-8")
cleanup = CLEANUP.read_text(encoding="utf-8")

for label, text in (("seed", seed), ("cleanup", cleanup)):
    if not re.search(r"\bbegin\s*;", text, flags=re.I):
        fail(f"{label} is missing BEGIN")
    if not re.search(r"\bcommit\s*;", text, flags=re.I):
        fail(f"{label} is missing COMMIT")
    if re.search(r"\brollback\s*;", text, flags=re.I):
        fail(f"{label} contains an unexpected ROLLBACK")
    if re.search(r"service[_-]?role|SUPABASE_SERVICE_ROLE|private[_-]?key|BEGIN (RSA|OPENSSH|EC|PRIVATE) KEY", text, flags=re.I):
        fail(f"{label} contains a forbidden credential/private-key marker")
    if "mtaujfgkqvzwauqiegkl" in text:
        fail(f"{label} references the shared Supabase project")

if seed.count("@example.invalid") < 6:
    fail("seed does not contain all synthetic email identities")
if "example.invalid" not in cleanup:
    fail("cleanup lacks the synthetic email guard")
if "DEBUG-" not in seed:
    fail("seed lacks debug record markers")

ids = set(re.findall(r"'([0-9a-f]{8}-[0-9a-f-]{27,})'", seed, flags=re.I))
if len(ids) < 35:
    fail(f"seed contains unexpectedly few fixed UUIDs: {len(ids)}")

seed_id_block = seed.split("insert into debug_seed_ids", 1)[1].split(";", 1)[0]
seed_ids = set(re.findall(r"'([0-9a-f]{8}-[0-9a-f-]{27,})'", seed_id_block, flags=re.I))
referenced_debug_ids = set(re.findall(r"debug_seed_ids where key = '[^']+'\)\s*\)?", seed))
if len(seed_ids) < 35:
    fail(f"debug_seed_ids contains unexpectedly few records: {len(seed_ids)}")

# Ensure every explicit fixed UUID in cleanup is present in the seed, except
# no extra data may be targeted by cleanup.
cleanup_ids = set(re.findall(r"'([0-9a-f]{8}-[0-9a-f-]{27,})'", cleanup, flags=re.I))
if not cleanup_ids.issubset(ids):
    fail("cleanup targets a UUID that is not part of the seed fixture graph")

print(f"debug seed validation passed: {len(seed_ids)} declared IDs, {len(cleanup_ids)} cleanup IDs")
