from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / "supabase/debug/seed_synthetic_debug.sql"
CLEANUP = ROOT / "supabase/debug/cleanup_synthetic_debug.sql"

SUPPORTED_EMAILS = {
    "creator.auth.debug@mock.yemencommerce.dev",
    "merchant.auth.debug@mock.yemencommerce.dev",
    "customer.auth.debug@mock.yemencommerce.dev",
    "customer2.auth.debug@mock.yemencommerce.dev",
    "reviewer.auth.debug@mock.yemencommerce.dev",
    "support.auth.debug@mock.yemencommerce.dev",
}
LEGACY_AUTH_IDS = {
    "10000000-0000-0000-0000-000000000001",
    "10000000-0000-0000-0000-000000000002",
    "10000000-0000-0000-0000-000000000003",
    "10000000-0000-0000-0000-000000000004",
    "10000000-0000-0000-0000-000000000005",
    "10000000-0000-0000-0000-000000000006",
}
DYNAMIC_WORKFLOW_IDS = {
    "b4000000-0000-0000-0000-000000000001",  # B2B checkout session
    "b5000000-0000-0000-0000-000000000001",  # B2B order
    "b6000000-0000-0000-0000-000000000001",  # B2B order item
    "b7000000-0000-0000-0000-000000000001",  # COD checkout session
    "b8000000-0000-0000-0000-000000000001",  # COD order
    "b9000000-0000-0000-0000-000000000001",  # COD order item
}


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

if re.search(r"\b(insert|update|delete)\s+(into\s+)?auth\.users\b|encrypted_password\s*=|\bcrypt\s*\(", seed, flags=re.I):
    fail("seed attempts unsupported direct Auth-table/password writes")
if not all(email in seed for email in SUPPORTED_EMAILS):
    fail("seed does not guard all six supported synthetic Auth identities")
if not all(email in cleanup for email in SUPPORTED_EMAILS):
    fail("cleanup does not target all six supported synthetic Auth identities")
if "example.invalid" not in cleanup:
    fail("cleanup lacks the legacy synthetic email guard")
if "DEBUG-" not in seed:
    fail("seed lacks debug record markers")

ids = set(re.findall(r"'([0-9a-f]{8}-[0-9a-f-]{27,})'", seed, flags=re.I))
if len(ids) < 35:
    fail(f"seed contains unexpectedly few fixed UUIDs: {len(ids)}")

seed_id_block = seed.split("insert into debug_seed_ids", 1)[1].split(";", 1)[0]
seed_ids = set(re.findall(r"'([0-9a-f]{8}-[0-9a-f-]{27,})'", seed_id_block, flags=re.I))
if len(seed_ids) < 35:
    fail(f"debug_seed_ids contains unexpectedly few records: {len(seed_ids)}")

cleanup_ids = set(re.findall(r"'([0-9a-f]{8}-[0-9a-f-]{27,})'", cleanup, flags=re.I))
allowed_cleanup_ids = ids | LEGACY_AUTH_IDS | DYNAMIC_WORKFLOW_IDS
if not cleanup_ids.issubset(allowed_cleanup_ids):
    fail("cleanup targets a UUID outside the declared or explicitly disposable fixture graph")

print(f"debug seed validation passed: {len(seed_ids)} declared IDs, {len(cleanup_ids)} cleanup IDs")
