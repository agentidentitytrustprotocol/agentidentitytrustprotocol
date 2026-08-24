#!/usr/bin/env python3
"""Regenerate the JCS-profile known-answer vectors and signed examples.

Maintainer tool, not part of `make validate`. It needs a checkout of
`aitp-verifier-py` and that package's crypto dependency, neither of which CI
has; `scripts/verify-known-answer.mjs` is what CI runs, and it depends on
nothing beyond Node's standard library.

The split is deliberate. This script *generates* using the Python reference
implementation; the Node checker *verifies* using an independent one. Bytes
produced by one implementation and checked by another is the only interop
property a single repository can actually demonstrate.

Vectors are never hand-transcribed. Hand-transcription is what produced the
divergence this script exists to correct: three vectors pinned the transport
envelope while three RFCs specified the inner artifact body.

Usage:
    python3 scripts/regen-known-answer.py [--verifier-py PATH] [--check]

    --verifier-py  Path to the aitp-verifier-py checkout. Defaults to the
                   AITP_VERIFIER_PY environment variable, then to
                   ../aitp-verifier-py relative to this repository.
    --check        Compute and report, but write nothing. Exits non-zero if
                   anything would change — usable as an idempotency test.

This repository is never written outside its own root, and the verifier-py
checkout is only ever read.
"""

from __future__ import annotations

import argparse
import collections
import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KAT = REPO / "schemas/conformance/known-answer"
JCS_VECTORS = KAT / "jcs-sha256.json"
REVOCATION_EXAMPLE = KAT / "signed-examples/revocation/kat-keypair-001-snapshot.json"
KEYPAIRS = KAT / "keypairs.json"

# The artifact-name wrapper is transport routing metadata and is never signed
# (RFC-AITP-0001 §5.4.1). Each vector's `object` must therefore be the inner
# artifact body.
WRAPPED_VECTORS = {
    "kat-manifest-001": "manifest",
    "kat-revocation-001": "revocation_list",
    "kat-session-bundle-001": "session_bundle",
}

def load_kat_seeds() -> dict[str, bytes]:
    """AID -> Ed25519 seed, read from the committed keypairs.json.

    Seeds are deliberately weak, published test values living in the repository;
    nothing secret is read from the environment or from outside this repo.
    Reading them here rather than hard-coding keeps this tool honest: if a vector
    is re-keyed, the signer follows the vector file instead of a stale constant.
    """
    doc = json.loads(KEYPAIRS.read_text(encoding="utf-8"))
    seeds: dict[str, bytes] = {}
    for vector in doc["vectors"]:
        if "seed_hex" not in vector:
            continue  # P-256 entries carry a scalar, not a seed; none is signed here
        seeds[vector["aid"]] = bytes.fromhex(vector["seed_hex"])
    return seeds


def load_reference_implementation(path: Path):
    """Import aitp-verifier-py as a library. Read-only; never written to."""
    if not (path / "aitp_verifier" / "jcs.py").exists():
        sys.exit(
            f"error: no aitp-verifier-py checkout at {path}\n"
            f"       Pass --verifier-py PATH or set AITP_VERIFIER_PY.\n"
            f"       This tool generates vectors by executing a reference\n"
            f"       implementation; it will not hand-compute them."
        )
    sys.path.insert(0, str(path))
    try:
        from aitp_verifier.b64 import b64url_encode
        from aitp_verifier.crypto import PrivateKey, sha256
        from aitp_verifier.jcs import canonicalize
    except ImportError as exc:  # pragma: no cover - environment problem, not logic
        sys.exit(
            f"error: found {path} but could not import it: {exc}\n"
            f"       Install its dependencies (pip install -e {path}) and retry."
        )
    return canonicalize, sha256, PrivateKey, b64url_encode


def signing_key(aid: str, PrivateKey, seeds: dict[str, bytes]):
    seed = seeds.get(aid)
    if seed is None:
        detail = (
            "that keypair is not Ed25519 — this tool signs the JCS profile with "
            "Ed25519 only; add ECDSA-P256 signing deliberately"
            if ":p256:" in aid else
            "no such keypair is published there"
        )
        raise SystemExit(
            f"error: cannot sign for {aid}: {detail}.\n"
            f"       A vector may only be signed by a keypair published in "
            f"{KEYPAIRS.relative_to(REPO)}.")
    return PrivateKey.ed25519_from_seed(seed)


def serialize(doc) -> str:
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


def assert_roundtrip_stable(path: Path, raw: str, doc) -> None:
    """Refuse to rewrite a file whose formatting this serializer would change.

    Values are rewritten with a full `json.dumps`, which is only safe while the
    file already round-trips through it byte-exactly. If it does not, writing
    would bury the semantic change under cosmetic churn — the diff would stop
    being reviewable, which for a file of pinned cryptographic values is the
    whole point. Fail loudly instead.
    """
    if serialize(doc) != raw:
        raise SystemExit(
            f"error: {path.relative_to(REPO)} does not round-trip through this\n"
            f"       serializer unchanged, so rewriting it would churn formatting\n"
            f"       as well as values. Reformat the file to match (indent=2,\n"
            f"       non-ASCII literal, trailing newline) or teach this script a\n"
            f"       targeted key-level rewrite before regenerating."
        )


def regenerate_vectors(deps, seeds, *, write: bool) -> list[str]:
    canonicalize, sha256, PrivateKey, b64url_encode = deps
    changes: list[str] = []

    raw = JCS_VECTORS.read_text(encoding="utf-8")
    doc = json.loads(raw, object_pairs_hook=collections.OrderedDict)
    assert_roundtrip_stable(JCS_VECTORS, raw, doc)

    for vector in doc["vectors"]:
        wrapper = WRAPPED_VECTORS.get(vector["id"])
        if wrapper is None:
            continue

        obj = vector["object"]
        if wrapper in obj:
            # Still wrapped: unwrap to the inner artifact body.
            body = obj[wrapper]
        else:
            # Already unwrapped; recompute anyway so this script is idempotent
            # and so a re-run re-derives rather than trusts what is on disk.
            body = obj

        if "signature" in body:
            raise SystemExit(
                f"{vector['id']}: the inner body carries a `signature` member. The signing\n"
                f"       input excludes it (RFC-AITP-0003 §6.1 for the manifest and session\n"
                f"       bundle; for the revocation snapshot the signature is a sibling of\n"
                f"       the wrapper and never appears in the body at all). Canonicalizing it\n"
                f"       into the pinned bytes would pin the wrong input.")

        canonical = canonicalize(body)
        digest = sha256(canonical)

        updates = {
            "object": body,
            "signing_input": "body",
            "jcs_canonical_hex": canonical.hex(),
            "jcs_canonical_len_bytes": len(canonical),
            "sha256_hex": digest.hex(),
            "sha256_b64url": b64url_encode(digest),
        }

        # Re-mint any signature this vector pins, over the new signing input.
        if "coordinator_signature_b64url" in vector:
            coordinator = body["coordinator"]
            key = signing_key(coordinator, PrivateKey, seeds)
            updates["coordinator_signature_b64url"] = b64url_encode(key.sign_digest(digest))

        for member, value in updates.items():
            if vector.get(member) != value:
                old = vector.get(member)
                if member == "object":
                    changes.append(f"{vector['id']}.object: unwrapped from {{'{wrapper}': ...}}")
                else:
                    changes.append(f"{vector['id']}.{member}: {old!r} -> {value!r}")
                vector[member] = value

        # Member order is left exactly as found. Reordering would churn the diff
        # and hide the semantic change behind cosmetic movement.

    if write and changes:
        JCS_VECTORS.write_text(serialize(doc), encoding="utf-8")
    return changes


def regenerate_revocation_example(deps, seeds, *, write: bool) -> list[str]:
    canonicalize, sha256, PrivateKey, b64url_encode = deps
    raw = REVOCATION_EXAMPLE.read_text(encoding="utf-8")
    doc = json.loads(raw, object_pairs_hook=collections.OrderedDict)
    assert_roundtrip_stable(REVOCATION_EXAMPLE, raw, doc)

    body = doc["revocation_list"]
    if "signature" in body:
        raise SystemExit(
            "the revocation body must not carry a signature member; "
            "the signature is a sibling of the wrapper (RFC-AITP-0008 §1.5)")

    key = signing_key(body["issuer"], PrivateKey, seeds)
    signature = b64url_encode(key.sign_digest(sha256(canonicalize(body))))

    if doc["signature"] == signature:
        return []
    change = f"signed-examples/revocation: signature {doc['signature']!r} -> {signature!r}"
    doc["signature"] = signature
    if write:
        REVOCATION_EXAMPLE.write_text(serialize(doc), encoding="utf-8")
    return [change]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--verifier-py", type=Path,
                        default=Path(os.environ.get("AITP_VERIFIER_PY", REPO.parent / "aitp-verifier-py")))
    parser.add_argument("--check", action="store_true",
                        help="report what would change and exit non-zero if anything would")
    args = parser.parse_args()

    deps = load_reference_implementation(args.verifier_py.resolve())
    print(f"reference implementation: {args.verifier_py.resolve()}")

    seeds = load_kat_seeds()
    print(f"signing keypairs: {len(seeds)} Ed25519 seeds from {KEYPAIRS.relative_to(REPO)}")

    # Check every file's formatting before writing any of them, so a failure on
    # the second file cannot leave the first already rewritten.
    for path in (JCS_VECTORS, REVOCATION_EXAMPLE):
        raw = path.read_text(encoding="utf-8")
        assert_roundtrip_stable(path, raw, json.loads(raw, object_pairs_hook=collections.OrderedDict))

    changes = regenerate_vectors(deps, seeds, write=not args.check)
    changes += regenerate_revocation_example(deps, seeds, write=not args.check)

    if not changes:
        print("no changes — vectors and signed examples already match the reference output")
        return 0

    verb = "would change" if args.check else "changed"
    print(f"\n{len(changes)} value(s) {verb}:")
    for line in changes:
        print(f"  {line}")
    if args.check:
        print("\n--check: nothing written; exiting non-zero because output differs")
        return 1
    print("\nNow run: node scripts/verify-known-answer.mjs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
