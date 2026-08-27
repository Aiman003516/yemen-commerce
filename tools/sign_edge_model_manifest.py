#!/usr/bin/env python3
"""Sign a Yemen Commerce EdgeModelManifest without storing key material.

The private key is read from an operator-supplied file and is never printed or
written by this script. The input JSON must contain the unsigned manifest
fields used by EdgeModelManifest.canonicalPayload. The output signature is
URL-safe base64 without padding, matching the Dart verifier.
"""

from __future__ import annotations

import argparse
import base64
import json
from pathlib import Path
from typing import Any

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

CANONICAL_FIELDS = (
    "manifest_id",
    "model_id",
    "model_version",
    "platform",
    "artifact_uri",
    "artifact_sha256",
    "min_os_version",
    "min_memory_mb",
    "required_locales",
    "requires_hardware_acceleration",
    "requires_network_download",
    "disallow_low_power_mode",
    "enabled",
    "read_only_only",
)


def urlsafe(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def canonical_payload(manifest: dict[str, Any]) -> dict[str, Any]:
    missing = [key for key in CANONICAL_FIELDS if key not in manifest]
    if missing:
        raise ValueError(f"manifest is missing fields: {', '.join(missing)}")
    return {key: manifest[key] for key in CANONICAL_FIELDS}


def canonical_bytes(payload: dict[str, Any]) -> bytes:
    return json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def load_private_key(path: Path) -> Ed25519PrivateKey:
    data = path.read_bytes()
    try:
        key = serialization.load_pem_private_key(data, password=None)
    except ValueError:
        raw = base64.urlsafe_b64decode(data.strip() + b"=" * (-len(data.strip()) % 4))
        key = Ed25519PrivateKey.from_private_bytes(raw)
    if not isinstance(key, Ed25519PrivateKey):
        raise ValueError("key file is not an Ed25519 private key")
    return key


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--private-key-file", required=True, type=Path)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--public-key-output", type=Path)
    args = parser.parse_args()

    manifest = json.loads(args.input.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        raise ValueError("manifest JSON must be an object")
    payload = canonical_payload(manifest)
    key = load_private_key(args.private_key_file)
    signature = key.sign(canonical_bytes(payload))
    signed = dict(payload)
    signed["signer_key_id"] = args.key_id
    signed["signature_base64"] = urlsafe(signature)
    args.output.write_text(
        json.dumps(signed, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if args.public_key_output:
        args.public_key_output.write_text(
            urlsafe(key.public_key().public_bytes(
                serialization.Encoding.Raw,
                serialization.PublicFormat.Raw,
            ))
            + "\n",
            encoding="utf-8",
        )
    print(f"signed_manifest={args.output}")
    print(f"manifest_id={payload['manifest_id']}")
    print(f"signer_key_id={args.key_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
