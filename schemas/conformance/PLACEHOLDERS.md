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
| `__NOW__` | The runner's reference clock at execution time. | Unix seconds (integer). |
| `__NOW_MINUS_3600__` | One hour before `__NOW__`. | `__NOW__ - 3600` (integer). |
| `__NOW_PLUS_3600__` | One hour after `__NOW__`. | `__NOW__ + 3600` (integer). |

Additional `__NOW_MINUS_<seconds>__` and `__NOW_PLUS_<seconds>__`
tokens MAY be introduced as new fixtures need them; minting tools MUST
parse the trailing integer literally and substitute `__NOW__ ±
<seconds>`.

### Reference clock for byte-stable minting

Minting tools MUST anchor `__NOW__` to **`1711900000`** (the same
clock used by the rc.2 known-answer test vectors in
[`known-answer/jcs-sha256.json`](known-answer/jcs-sha256.json)).
Using the wall clock would produce different canonical bytes on every
mint; pinning `__NOW__` lets a re-mint be byte-stable across runs and
across implementations. Runners that consume already-minted fixtures
MUST treat the integer in the fixture as authoritative; they do not
compare it to wall time.

## AID role mapping

Most fixtures use placeholder AIDs of the form
`aid:pubkey:agent<X>_pubkey_AID_v01_placeholder_<X>...`. The minting
tool MUST replace these with the real AIDs derived from the pinned
known-answer keypairs. The mapping is normative for v0.1:

| Fixture role | KAT keypair | AID |
|---|---|---|
| `agentA` (initiator / TCT issuer in most fixtures) | [`kat-keypair-001`](known-answer/keypairs.json) | `aid:pubkey:O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik` |
| `agentB` (target / TCT subject) | [`kat-keypair-002`](known-answer/keypairs.json) | `aid:pubkey:A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg` |
| `agentC` (delegatee in single-hop, intermediate in multi-hop) | [`kat-keypair-003`](known-answer/keypairs.json) | `aid:pubkey:dqFZIESm5PURJlvKc6YE2QsFKdHfYCvjChmpJXZg0fU` |
| `agentD` (final delegatee in multi-hop chains) | [`kat-keypair-004`](known-answer/keypairs.json) | `aid:pubkey:iojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w` |
| `issuingPeer` (alias of `agentA` in delegation fixtures) | `kat-keypair-001` | same as `agentA` |
| `worker_pubkey_AID_v01_placeholder_wwwwwwwww` (Manifest example) | `kat-keypair-002` | same as `agentB` |
| `verifier_pubkey_AID_v01_placeholder_vvvvvvv` / `victim_pubkey_AID_v01_placeholder_vvvvvvvvv` (verifier in `id-*`) | `kat-keypair-001` | same as `agentA` |
| `attacker_pubkey_AID_v01_placeholder_XXXXXXX` (`mh-002`) | A separate one-shot keypair NOT in `keypairs.json`. Generated deterministically from a fixture-only seed (e.g. `0xff` × 32) and inlined where needed. Tests trust-anchor + signature checks against an unknown peer. | n/a |

Identity-issuer keys (the OIDC issuers used by `__VALID_JWT__` and
`__VALID_JWT_FROM_UNKNOWN_ISSUER__`) are NOT drawn from
`keypairs.json` — they are minted at runtime by the tool and the
public key is inlined into the fixture's `accepted_trust_anchors` /
local `trust_anchors` so the verifier accepts (or rejects) the JWT
based on issuer-list membership alone.

## Operation key

Every fixture carries a top-level `input.operation` string telling
the conformance runner which conformance op to invoke against the
implementation under test. The operation registry for v0.1:

| Fixture id prefix | `input.operation` | Notes |
|---|---|---|
| `env-*` | `verify_envelope` | Single envelope verification. |
| `man-*` | `verify_manifest` | Standalone Manifest verification (RFC-AITP-0003 §5). |
| `tct-*` | `verify_tct` | Standalone TCT verification (RFC-AITP-0005 §9). |
| `del-*` | `verify_delegation_token` | Single-hop delegation verification (RFC-AITP-0006 §4). |
| `rev-*` | `verify_revocation_snapshot` or `verify_tct` | Revocation-layer fixtures. `rev-001`/`002`/`003` use `verify_revocation_snapshot` (RFC-AITP-0008 §1.5) to exercise the snapshot freshness / signature / lookup path directly. `rev-004` uses `verify_tct` (the standard TCT op) with `input.revocation_instrumented: true` and `expected.side_effects.revocation_lookup_called: false` to pin the RFC-AITP-0008 §3.3 ordering requirement — TCT signature verification MUST precede any network revocation lookup. Runners that cannot instrument the revocation source MUST SKIP the side-effect assertion (and thus the fixture, since it is core/required). |
| `id-*` | `verify_handshake_payload` | Verify a single inline-handshake `payload` (i.e. the result of step 6 in RFC-AITP-0004 §5.1). |
| `mh-*` (single-message) | `verify_handshake_payload` | Same as above. |
| `mh-*` (multi-step `sequence`) | per-step in the sequence | Each `sequence[i]` carries its own `operation`; typical values are `start_handshake` and `process_handshake_message`. |
| `tct-*` (multi-step `sequence`) | per-step in the sequence | Used by `tct-006` (downstream PoP exchange) and `tct-007` (PoP enforcement). Operations for `tct-006`: `issue_pop_challenge` (verifier produces a `pop_challenge` envelope), `produce_pop_response` (holder signs `sha256(base64url_decode(nonce))` with `binding.cnf`'s private key and emits a `pop_response` envelope), `verify_pop_response` (verifier checks envelope signature, `nonce_echo`, and `pop_signature` per RFC-AITP-0005 §6.2). Operations for `tct-007`: `authorize_capability_invocation` (verifier receives a capability invocation against a grant the issuing peer marks as PoP-required; verifier SHOULD respond by issuing a `pop_challenge`), `expect_pop_challenge_issued` (no-op step that asserts the verifier instrumentation observed a `pop_challenge` envelope being emitted; uses the `side_effects.pop_challenge_issued` assertion), `withhold_pop_response` (test harness deliberately does NOT return a `pop_response`; verifier MUST reject the original invocation with `POP_RESPONSE_INVALID` and MUST NOT authorize the capability — asserted via `side_effects.capability_authorized: false`). |
| `del-mh-*` | `verify_delegation_token` | Multi-hop delegation verification (RFC-AITP-0011 §3-§6). Inputs may include a `revocation_snapshots` array of `{issuer_aid, snapshot}` records that the runner MUST populate per-hop deny lists from before checking source_tct_jti revocation. v0.1-only implementations MUST return `DELEGATION_MULTIHOP_NOT_SUPPORTED` for any token with a non-empty `chain` field. |
| `bundle-*` | `verify_session_bundle` | Session Trust Bundle verification (RFC-AITP-0010 §5). Inputs include `self_aid` (the receiving participant) and `now` (reference clock). v0.1-only implementations report `SKIP` rather than `FAIL` when this operation is encountered. |

A runner that encounters an unknown `operation` MUST return SKIP
rather than FAIL — that lets an implementation under test
self-document which conformance ops it does and does not support
without breaking the rest of the run.

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
| `__VALID_DOWNSTREAM_POP_SIG__` | TCT subject's signing key (the holder; AID encoded in `binding.cnf`) | `sha256(base64url_decode(nonce))` where `nonce` is the `__VALID_NONCE__` issued by the verifier in the matching `pop_challenge` (RFC-AITP-0005 §6.1). Same convention as `__VALID_POP_SIG__`; named separately to disambiguate the downstream PoP exchange from Manifest PoP in fixtures that include both. |

## Failure-injection placeholders

These represent values that look well-formed but trigger a specific
failure path. The minting tool produces them by manipulating a
known-good signed object — the surrounding fixture documents which
property should be broken.

| Token | What's broken | Expected error path |
|---|---|---|
| `__TAMPERED_SIGNATURE__` | Sign properly, then flip the **least-significant bit of the last raw signature byte** before base64url-encoding. | `MANIFEST_SIGNATURE_INVALID` (manifest), `INVALID_SIGNATURE` (envelope). |
| `__TAMPERED_SIG__` | Same recipe; shorter alias used by older fixtures. | `TCT_SIGNATURE_INVALID`. |

The tamper recipe is pinned so re-mints reproduce byte-for-byte. Any
implementation that mutates a different bit will produce a different
signature string and break cross-mint determinism.
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
