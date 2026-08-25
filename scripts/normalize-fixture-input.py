#!/usr/bin/env python3
"""Extract one artifact from a conformance fixture and normalize it for schema validation.

Conformance fixtures carry placeholder tokens (`__VALID_A_SIG__`, `__JWS_TCT__`,
`__NOW_PLUS_3600__`, …) rather than minted values, because minting needs key
material this repository deliberately does not use at validation time. Those
tokens do not satisfy the schemas' own `pattern` constraints, so a fixture's
`input` cannot be handed to ajv as-is.

This script substitutes a **shape-conformant dummy per placeholder family** —
never by consulting the target schema. That distinction is the whole design:
substitution is directed by what the placeholder *is*, so `pattern`, `format`
and `const` keywords still do real work on every value that is not a
placeholder. The alternative — stripping `pattern`/`format` from the schemas so
the raw tokens pass — was rejected: it would disable the checks on real values
too, which is most of them.

An `__UPPER_SNAKE__` token with no family entry is a hard error. A minting tool
that meets a placeholder it does not recognize must fail fast rather than guess
(`schemas/conformance/PLACEHOLDERS.md`); the same rule applies here, and it is
what guarantees a newly-introduced token gets classified instead of silently
sailing through as an ordinary string.

Some schemas describe the **wrapped** transport form of an artifact rather than
its body — `aitp-manifest.schema.json` requires a top-level `manifest` member,
while fixtures store the manifest body itself. `--wrap KEY` re-wraps the
extracted artifact as `{"KEY": <artifact>}` so it is validated in the shape the
schema actually describes. The map declares this per artifact; it is never
inferred, so a schema that changes which form it describes surfaces as a
validation failure rather than being silently accommodated.

Usage:
    normalize-fixture-input.py <fixture.json> <json-pointer> <output.json> [--wrap KEY]

Exits non-zero with a diagnostic on: unreadable fixture, a pointer that does not
resolve, a pointer that resolves to a non-object, or an unknown placeholder.
"""

from __future__ import annotations

import copy
import json
import re
import sys

# The pinned reference clock. Every fixture's relative time placeholder is
# resolved against this instant, matching `PLACEHOLDERS.md`.
NOW = 1711900000

# Shape-conformant dummies, chosen to satisfy the schemas' patterns:
#   signature   ^((ed25519|p256)\.)?[A-Za-z0-9_-]{86}$   (64-byte sig, unpadded)
#   compact JWS ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$
#   thumbprint  ^[A-Za-z0-9_-]{43}$                      (32-byte digest)
#   pop nonce   ^[A-Za-z0-9_-]{22}$                      (128-bit nonce)
DUMMY_SIGNATURE = "A" * 86
DUMMY_JWS = "eyJhbGciOiJFZERTQSJ9.eyJzdWIiOiJkdW1teSJ9." + "A" * 86
DUMMY_HASH = "A" * 43
DUMMY_NONCE = "A" * 22

# Every placeholder token appearing anywhere in schemas/conformance/*.json,
# classified by family. Regenerate the census with:
#   grep -rho '__[A-Z][A-Z0-9_]*__' schemas/conformance/*.json | sort -u
# Adding a fixture that introduces a new token makes this script fail until the
# token is classified here — deliberately.
PLACEHOLDER_FAMILIES: dict[str, object] = {
    # ── Signature family ────────────────────────────────────────────────────
    "__VALID_A_SIG__": DUMMY_SIGNATURE,
    "__VALID_B_SIG__": DUMMY_SIGNATURE,
    "__VALID_ENVELOPE_SIG__": DUMMY_SIGNATURE,
    "__VALID_MANIFEST_SIG__": DUMMY_SIGNATURE,
    "__VALID_POP_SIG__": DUMMY_SIGNATURE,
    "__VALID_DOWNSTREAM_POP_SIG__": DUMMY_SIGNATURE,
    "__VALID_GRANT_PROOF_SIG__": DUMMY_SIGNATURE,
    "__INVALID_POP_SIG__": DUMMY_SIGNATURE,
    "__INVALID_POP_SIG_OVER_WRONG_NONCE__": DUMMY_SIGNATURE,
    "__TAMPERED_SIGNATURE__": DUMMY_SIGNATURE,
    "__ANY_DELEGATION_SIG__": DUMMY_SIGNATURE,
    "__ANY_CHAIN_STEP_SIG__": DUMMY_SIGNATURE,
    "__LEGACY_PINNED_PROOF__": DUMMY_SIGNATURE,
    "__CAPTURED_PROOF_FROM_ORIGINAL_HANDSHAKE__": DUMMY_SIGNATURE,
    # ── Compact-JWS family ──────────────────────────────────────────────────
    # The alg-none / wrong-alg / tampered variants normalize to the same shape:
    # their defect lives in the JWS header or signature segment, which schema
    # validation of the *decoded claims* does not and should not see.
    "__JWS_TCT__": DUMMY_JWS,
    "__JWS_TCT_TAMPERED_SIG__": DUMMY_JWS,
    "__JWS_TCT_WRONG_ALG__": DUMMY_JWS,
    "__JWS_TCT_ALG_NONE__": DUMMY_JWS,
    "__JWS_GRANT_VOUCHER__": DUMMY_JWS,
    "__JWS_DELEGATION__": DUMMY_JWS,
    "__ANY_JWS__": DUMMY_JWS,
    "__VALID_JWT__": DUMMY_JWS,
    "__VALID_JWT_FROM_UNKNOWN_ISSUER__": DUMMY_JWS,
    "__JWT_MISSING_AUD_CLAIM__": DUMMY_JWS,
    "__JWT_MISSING_CNF_JKT_CLAIM__": DUMMY_JWS,
    "__JWT_AUD_TARGETS_DIFFERENT_PEER__": DUMMY_JWS,
    # ── Digest family ───────────────────────────────────────────────────────
    "__COMPUTED_CHAIN_HASH__": DUMMY_HASH,
    "__ANY_CHAIN_HASH__": DUMMY_HASH,
    # ── Nonce family ────────────────────────────────────────────────────────
    "__VALID_NONCE__": DUMMY_NONCE,
    "__VALID_NONCE_ECHO__": DUMMY_NONCE,
    # ── Clock family ────────────────────────────────────────────────────────
    # Integers, not strings: these sit in `exp` / `expires_at` positions whose
    # schema type is integer, so substituting a string would fail validation for
    # a reason that has nothing to do with the artifact under test.
    "__NOW__": NOW,
}

# `__NOW_PLUS_<n>__` / `__NOW_MINUS_<n>__` are computed rather than enumerated,
# per the arithmetic rule in PLACEHOLDERS.md.
RELATIVE_CLOCK = re.compile(r"^__NOW_(PLUS|MINUS)_([0-9]+)__$")

# Any remaining token of this shape is unclassified and must stop the build.
PLACEHOLDER_SHAPE = re.compile(r"^__[A-Z][A-Z0-9_]*__$")


class NormalizeError(Exception):
    """A fixture could not be normalized. Always fatal — never a skip."""


def resolve_pointer(doc: object, pointer: str) -> object:
    """Resolve an RFC 6901 JSON pointer, or raise NormalizeError."""
    if pointer in ("", "/"):
        return doc
    if not pointer.startswith("/"):
        raise NormalizeError(f"pointer must start with '/': {pointer!r}")
    current = doc
    for raw in pointer.split("/")[1:]:
        token = raw.replace("~1", "/").replace("~0", "~")
        if isinstance(current, list):
            if not token.isdigit():
                raise NormalizeError(
                    f"pointer {pointer!r}: {token!r} is not an array index")
            index = int(token)
            if index >= len(current):
                raise NormalizeError(
                    f"pointer {pointer!r}: index {index} out of range "
                    f"(array has {len(current)} entries)")
            current = current[index]
        elif isinstance(current, dict):
            if token not in current:
                raise NormalizeError(
                    f"pointer {pointer!r}: no member {token!r} "
                    f"(available: {', '.join(sorted(current)) or 'none'})")
            current = current[token]
        else:
            raise NormalizeError(
                f"pointer {pointer!r}: cannot descend into {type(current).__name__} at {token!r}")
    return current


def substitute(value: str, where: str) -> object:
    """Map one placeholder token to its family dummy, or fail loudly."""
    if value in PLACEHOLDER_FAMILIES:
        return PLACEHOLDER_FAMILIES[value]
    relative = RELATIVE_CLOCK.match(value)
    if relative:
        offset = int(relative.group(2))
        return NOW + offset if relative.group(1) == "PLUS" else NOW - offset
    raise NormalizeError(
        f"unclassified placeholder {value!r} at {where}.\n"
        f"       Add it to PLACEHOLDER_FAMILIES in scripts/normalize-fixture-input.py\n"
        f"       with the dummy shape its family requires. Refusing to guess: an\n"
        f"       unrecognized placeholder validated as a literal string would pass\n"
        f"       or fail for the wrong reason.")


def normalize(node: object, where: str = "") -> object:
    """Recursively substitute placeholders and drop documentation companions.

    Two classes of member are removed:

    * keys beginning with `_` — the documentation-companion convention already
      used by `validate-json.sh` for example files (`_decoded_claims`, `_wire_note`).
    * a `<x>_claims` member sitting beside an `<x>` member — the claims-sibling
      minting convention documented in the bundle fixtures' `$comment`
      (`tct`/`tct_claims`, `voucher`/`voucher_claims`). The companion carries the
      decoded claims of the opaque compact JWS next to it, so it is documentation
      relative to the artifact being validated. It is not exempted from checking:
      the map points at each companion separately so it is validated against its
      own claims schema in its own right.
    """
    if isinstance(node, dict):
        drop = {
            key for key in node
            if key.endswith("_claims") and key[: -len("_claims")] in node
        }
        return {
            key: normalize(value, f"{where}/{key}")
            for key, value in node.items()
            if not key.startswith("_") and key not in drop
        }
    if isinstance(node, list):
        return [normalize(item, f"{where}/{index}") for index, item in enumerate(node)]
    if isinstance(node, str) and PLACEHOLDER_SHAPE.match(node):
        return substitute(node, where or "/")
    return node


def main(argv: list[str]) -> int:
    if len(argv) not in (4, 6) or (len(argv) == 6 and argv[4] != "--wrap"):
        sys.stderr.write(__doc__ or "")
        return 2
    fixture_path, pointer, output_path = argv[1], argv[2], argv[3]
    wrap_key = argv[5] if len(argv) == 6 else None

    try:
        with open(fixture_path, encoding="utf-8") as handle:
            fixture = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"error: cannot read {fixture_path}: {exc}\n")
        return 1

    try:
        artifact = resolve_pointer(fixture, pointer)
        if not isinstance(artifact, (dict, list)):
            raise NormalizeError(
                f"pointer {pointer!r} resolves to {type(artifact).__name__}, "
                f"not an object or array — a schema cannot validate a scalar here")
        normalized = normalize(copy.deepcopy(artifact), pointer)
        if wrap_key is not None:
            normalized = {wrap_key: normalized}
    except NormalizeError as exc:
        sys.stderr.write(f"error: {fixture_path}: {exc}\n")
        return 1

    try:
        with open(output_path, "w", encoding="utf-8") as handle:
            json.dump(normalized, handle)
    except OSError as exc:
        sys.stderr.write(f"error: cannot write {output_path}: {exc}\n")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
