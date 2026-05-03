# Known-Answer Test Vectors

Pinned reference values that every conformant AITP v0.1 implementation
MUST reproduce byte-for-byte. These vectors close interop ambiguities
that schema validation alone cannot catch — JCS canonical-byte ordering,
JWK thumbprint serialization, and Ed25519 seed-to-AID derivation.

## Files

| File | Purpose | Spec reference |
|---|---|---|
| [`keypairs.json`](keypairs.json) | Ed25519 seed → raw public key → `aid:pubkey:` identifier | RFC-AITP-0001 §5.3 |
| [`jwk-thumbprints.json`](jwk-thumbprints.json) | RFC 7638 thumbprint of the canonical OKP/Ed25519 JWK form | RFC-AITP-0002 §2.2.1 |
| [`jcs-sha256.json`](jcs-sha256.json) | JCS canonical bytes (RFC 8785) and SHA-256 digest of the four signed AITP artifacts (TCT, Manifest, delegation token, revocation snapshot) | RFC-AITP-0001 §5.4.1 |
| [`signed-examples/`](signed-examples/) | Reserved location for real-signature artifacts minted from the pinned keypairs (currently empty — populated when an implementation mints them) | RFC-AITP-0003 §6 (Manifest), RFC-AITP-0005 §7 (TCT), RFC-AITP-0006 §6 (Delegation), RFC-AITP-0008 §1.5 (Revocation snapshot) |

## How to use

For each vector, an implementation MUST:

1. Compute the same canonical form (or thumbprint, or AID) from the
   pinned input.
2. Compare byte-for-byte against the pinned output.

Any mismatch is a conformance bug.

## Why pin canonical bytes, not just the hash?

A SHA-256 mismatch tells you something is wrong but not where. Pinning
the canonical bytes lets implementations diff their canonical output
against the reference and locate the divergence directly (sort order,
number formatting, Unicode escaping, whitespace, etc.).

## Stability

These vectors are stable for AITP v0.1. New vectors MAY be added; an
existing vector's output MUST NOT change without an RFC bump. If JCS
or JWK Thumbprint specifications change in a way that breaks these
vectors, AITP will issue a major version bump.
