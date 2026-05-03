# Conformance Fixture Placeholder Convention

The fixtures under `schemas/conformance/*.json` use string placeholders
of the form `__UPPER_SNAKE__` for values that a runner or minting tool
must materialize at execution time. This file is the normative
specification for those placeholders.

A minting tool (e.g. `aitp-rs`'s `mint-conformance-fixtures` script)
walks each fixture, identifies placeholders by name, substitutes real
values per the rules below, and writes the result. A conformance
runner that consumes already-minted fixtures MUST NOT see any of these
tokens — if it does, the fixture is not yet migrated.

## Naming rule

Placeholders MUST match the regex `^__[A-Z][A-Z0-9_]+__$`. The
double-underscore boundaries make placeholders trivially greppable and
unambiguous against any base64url, hex, or UUID alphabet.

## Time placeholders

| Token | Meaning | Substitution |
|---|---|---|
| `__NOW__` | The runner's reference clock at execution time. | Current Unix seconds (integer). |
| `__NOW_MINUS_3600__` | One hour before `__NOW__`. | `__NOW__ - 3600` (integer). |

Additional `__NOW_MINUS_<seconds>__` tokens MAY be introduced as new
fixtures need them; minting tools MUST parse the trailing integer
literally. Negative offsets (`__NOW_PLUS_<seconds>__`) are reserved.

## Signature placeholders

The minting tool produces real Ed25519 signatures using the
[known-answer keypairs](known-answer/keypairs.json). Every signature
placeholder in this table is replaced with the unpadded base64url
encoding of the signature over the appropriate canonical input
(RFC-AITP-0001 §5.4.1).

| Token | Signing key | Signing input |
|---|---|---|
| `__VALID_ENVELOPE_SIG__` | Sender's pinned signing key | Envelope signing input per RFC-AITP-0001 §5.4 |
| `__VALID_MANIFEST_SIG__` | Manifest agent's signing key | JCS canonical Manifest body excluding `signature` (RFC-AITP-0003 §6.1) |
| `__VALID_POP_SIG__` | Manifest agent's signing key | `sha256(decoded_bytes(challenge))` (RFC-AITP-0003 §3.1) |
| `__VALID_TCT_SIG__` | TCT issuer's signing key | JCS canonical TCT body excluding `signature` (RFC-AITP-0005 §7.1) |
| `__VALID_A_SIG__` | Initiating peer (A)'s signing key | Context-dependent — typically envelope or TCT signing input; minting tool resolves from surrounding fixture shape. |
| `__VALID_B_SIG__` | Target peer (B)'s signing key | Same; context-dependent. |
| `__VALID_ISSUING_PEER_SIG__` | TCT issuer's signing key | Source-TCT signing input; reused verbatim in `grant_proof.signature` (RFC-AITP-0006 §3.1). |
| `__VALID_JWT__` | Identity issuer's key | Compact JWT serialization with claims pinned by the surrounding fixture context. |
| `__VALID_JWT_FROM_UNKNOWN_ISSUER__` | Untrusted issuer's key | Same shape as `__VALID_JWT__` but signed by an issuer NOT in the verifier's `trust_anchors`. The signature is cryptographically valid; the policy check is what fails. |
| `__VALID_NONCE__` | n/a | Random 128-bit base64url string (22 chars, unpadded). The minting tool MAY use a per-fixture deterministic seed for reproducibility. |
| `__VALID_NONCE_ECHO__` | n/a | The exact `__VALID_NONCE__` value from the corresponding earlier message in the same handshake. |

## Failure-injection placeholders

These represent values that look well-formed but trigger a specific
failure path. The minting tool produces them by manipulating a
known-good signed object — the surrounding fixture documents which
property should be broken.

| Token | What's broken | Expected error path |
|---|---|---|
| `__TAMPERED_SIGNATURE__` | Bytes flipped after signing. | `MANIFEST_SIGNATURE_INVALID` (manifest), `INVALID_SIGNATURE` (envelope). |
| `__TAMPERED_SIG__` | Same; shorter alias used by older fixtures. | `TCT_SIGNATURE_INVALID`. |
| `__INVALID_POP_SIG__` | PoP signature over the wrong input (e.g. the wrong challenge). | `MANIFEST_POP_FAILED`. |
| `__INVALID_POP_SIG_OVER_WRONG_NONCE__` | PoP signature whose input used a different `pop_nonce` than the receiving peer expects. | `POP_VERIFICATION_FAILED`. |
| `__JWT_MISSING_AUD_CLAIM__` | Otherwise-valid OIDC JWT with the `aud` claim removed. | `IDENTITY_FAILED`. |
| `__JWT_AUD_TARGETS_DIFFERENT_PEER__` | OIDC JWT whose `aud` is some other peer's AID. | `IDENTITY_FAILED`. |
| `__JWT_MISSING_CNF_JKT_CLAIM__` | OIDC JWT with `cnf.jkt` removed. | `IDENTITY_FAILED`. |
| `__CAPTURED_PROOF_FROM_ORIGINAL_HANDSHAKE__` | A pinned-key proof signed over a *different* (sender, receiver, message_id, timestamp, pop_nonce) tuple than the one in this fixture. Tests cross-peer replay (RFC-AITP-0002 §3.1). | `IDENTITY_FAILED`. |

## Adding new placeholders

A new placeholder requires:

1. A row in this file (table above + a one-line description of what it
   represents).
2. A minting-tool implementation that materializes it.
3. A test in the runner that asserts the substituted value still
   triggers the documented expected outcome.

Placeholders MUST NOT shadow real protocol values. Specifically, no
fixture field whose schema requires a fixed-length base64url or UUID
may be filled with an `__UPPER_SNAKE__` token at runtime — minting MUST
happen before validation.

## Stability

Placeholder names are stable for AITP v0.1. Renaming requires the RFC
process; new names can be added freely. A minting tool that does not
recognize a placeholder MUST fail fast rather than emit the literal
string, since unsubstituted placeholders would slip past schema
validation only to produce confusing runtime failures.
