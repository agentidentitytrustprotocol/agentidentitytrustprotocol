# Error Code Registry

AITP error codes returned in error envelopes (`AitpError.code`). AITP is JSON-only; codes are string constants in the canonical JSON wire format (see [RFC-AITP-0001 §5.6](../rfcs/RFC-AITP-0001-core.md#56-error-envelope)).

> **Stability:** The codes listed below are stable for v0.2. Implementations MUST treat unknown codes as opaque failures and MUST NOT key behavior off codes that are not in this registry. New codes can be added without an RFC; renaming or removing an existing code is a breaking change and requires the RFC process. (v0.2 renamed `DELEGATION_INVALID_GRANT_PROOF` → `DELEGATION_INVALID_VOUCHER` via that process, as part of the JWS migration — see the delegation table below.)

> **`spec_status` column.** Each code below carries a `spec_status` of either `core` or `draft`. `core` codes are part of v0.2 conformance and MAY be emitted by any conformant implementation. `draft` codes are reserved for the opt-in draft RFCs (currently RFC-AITP-0010 Session Trust Bundle and RFC-AITP-0011 Multi-hop Delegation) and MUST NOT be used except when implementing the cited draft RFC. Conformance runners MUST treat receipt of a `draft` code from an implementation that does not opt into the corresponding draft as a non-conformance.

## Code naming convention

Object-level failures use the `<OBJECT>_<FAILURE>` form (e.g.
`MANIFEST_SIGNATURE_INVALID`, `TCT_EXPIRED`,
`DELEGATION_SCOPE_EXCEEDED`). Envelope-level failures use bare codes
(e.g. `INVALID_SIGNATURE`, `REPLAY_DETECTED`). This granularity is
deliberate: a consumer needs to know *which* object failed, not only
that something failed. New codes proposed via the RFC process MUST
follow this convention.

## Envelope-level codes

| Code | Meaning | Retryable | spec_status | Spec |
|---|---|---|---|---|
| `INVALID_ENVELOPE` | Envelope failed schema validation. | false | core | [RFC-AITP-0001 §5.6](../rfcs/RFC-AITP-0001-core.md#56-error-envelope) |
| `INVALID_SIGNATURE` | Signature verification failed. | false | core | [RFC-AITP-0001 §5.4](../rfcs/RFC-AITP-0001-core.md#54-signature) |
| `REPLAY_DETECTED` | Duplicate `message_id`. | false | core | [RFC-AITP-0001 §5.5](../rfcs/RFC-AITP-0001-core.md#55-replay-protection) |
| `TIMESTAMP_EXPIRED` | Timestamp outside tolerance. | true | core | [RFC-AITP-0001 §5.5](../rfcs/RFC-AITP-0001-core.md#55-replay-protection) |
| `UNKNOWN_VERSION` | Unsupported `version` field. | false | core | [RFC-AITP-0001 §7](../rfcs/RFC-AITP-0001-core.md#7-compatibility-model) |
| `IDENTITY_FAILED` | Identity binding could not be verified. | false | core | [RFC-AITP-0002](../rfcs/RFC-AITP-0002-identity.md) |
| `POLICY_VIOLATION` | Requested capability not granted. | false | core | [RFC-AITP-0004 §4](../rfcs/RFC-AITP-0004-mutual-handshake.md#4-tct-issuance-rules) |
| `GRANT_OVERFLOW` | Peer-issued TCT grants exceed `offered_capabilities`. | false | core | [RFC-AITP-0004](../rfcs/RFC-AITP-0004-mutual-handshake.md) |
| `INSUFFICIENT_GRANTS` | Received peer-issued TCT lacks a capability listed in the receiver's own `required_peer_capabilities`. | false | core | [RFC-AITP-0004 §5.3/§5.4](../rfcs/RFC-AITP-0004-mutual-handshake.md) |
| `KEY_RESOLUTION_FAILED` | Could not resolve issuer or peer keys. | true | core | [RFC-AITP-0007](../rfcs/RFC-AITP-0007-key-resolution.md) |

## Token-format codes (RFC-AITP-0001 §5.4.5)

Returned when a compact-JWS artifact (TCT, grant voucher, delegation token) fails the JOSE-header enforcement rules. The two codes are deliberately distinct so conformance fixtures can assert the rejection reason.

| Code | Meaning | Retryable | spec_status |
|---|---|---|---|
| `TOKEN_ALG_MISMATCH` | JWS header `alg` is not the sole value derived from the signer's AID — including `none` (any capitalization) and unknown algorithms. | false | core |
| `TOKEN_TYP_MISMATCH` | JWS header `typ` does not exactly match the value expected for the verification context (`aitp-tct+jwt`, `aitp-grant+jwt`, or `aitp-delegation+jwt`). | false | core |

## TCT-verification codes (RFC-AITP-0005)

Returned when a peer evaluates a TCT outside the handshake context — e.g. via a TCT verification API or local verification of a presented TCT.

| Code | Meaning | Retryable | spec_status |
|---|---|---|---|
| `TCT_EXPIRED` | TCT `exp` is in the past. | false | core |
| `TCT_REVOKED` | TCT `jti` is in the issuing peer's deny list. | false | core |
| `TCT_SIGNATURE_INVALID` | TCT JWS signature does not validate under the issuing peer's key. | false | core |
| `TCT_EXPIRES_AFTER_MANIFEST` | TCT `exp` exceeds the issuing peer's Manifest `expires_at` (RFC-AITP-0004 §4.3). The peer-issued TCT cannot outlive the credential that authenticates its issuer's key. | false | core |

## Downstream PoP codes (RFC-AITP-0005 §6)

| Code | Meaning | Retryable | spec_status |
|---|---|---|---|
| `POP_CHALLENGE_INVALID` | Challenge envelope was malformed or stale. | false | core |
| `POP_RESPONSE_INVALID` | Response signature failed verification against the subject key bound via `cnf.jkt`. | false | core |

## Manifest codes (RFC-AITP-0003)

| Code | Meaning | Retryable | spec_status |
|---|---|---|---|
| `MANIFEST_EXPIRED` | `expires_at` is in the past. | false | core |
| `MANIFEST_SIGNATURE_INVALID` | Signature verification failed. | false | core |
| `MANIFEST_POP_FAILED` | Proof-of-possession verification failed. | false | core |
| `INCOMPATIBLE_TRUST_ANCHORS` | No overlap in accepted trust anchors. | false | core |
| `INCOMPATIBLE_IDENTITY_TYPE` | Peer's `identity.type` is not present in the receiver's `accepted_identity_types`. More specific than `INCOMPATIBLE_TRUST_ANCHORS`: signals identity-type incompatibility (e.g. `pinned_key` vs. `oidc`) rather than trust-anchor incompatibility. | false | core |
| `MANIFEST_VERSION_UNKNOWN` | `version` not supported by this implementation. | false | core |

## Mutual Handshake codes (RFC-AITP-0004)

Returned in error envelopes during the four-message handshake.

| Code | Meaning | spec_status |
|---|---|---|
| `INCOMPATIBLE_TRUST_ANCHORS` | No trust-anchor overlap. | core |
| `INCOMPATIBLE_IDENTITY_TYPE` | Peer's identity type not in `accepted_identity_types`. | core |
| `MANIFEST_SIGNATURE_INVALID` | Peer's Manifest signature invalid. | core |
| `MANIFEST_POP_FAILED` | Peer's Manifest PoP failed. | core |
| `POP_VERIFICATION_FAILED` | Round-2 PoP signature failed. | core |
| `NONCE_MISMATCH` | `pop_nonce_echo` mismatch. | core |
| `AUDIENCE_MISMATCH` | TCT `aud` ≠ self AID. | core |
| `GRANT_OVERFLOW` | TCT grants exceed peer's `offered_capabilities`. | core |
| `TCT_EXPIRED` | TCT already expired. | core |
| `TCT_EXPIRES_AFTER_MANIFEST` | TCT `exp` exceeds issuer's Manifest `expires_at`. | core |
| `TOKEN_ALG_MISMATCH` | Received TCT/voucher JWS `alg` not the AID-derived value. | core |
| `TOKEN_TYP_MISMATCH` | Received TCT/voucher JWS `typ` not the expected value. | core |
| `IDENTITY_FAILED` | Peer identity verification failed. | core |
| `REPLAY_DETECTED` | Duplicate `message_id`. | core |
| `TIMESTAMP_EXPIRED` | Envelope timestamp outside tolerance. | core |

## Manifest-service codes

Returned by an HTTP endpoint serving `/.well-known/aitp-manifest` or by an out-of-band manifest lookup.

| Code | Meaning | spec_status |
|---|---|---|
| `MANIFEST_EXPIRED` | `expires_at` in the past. | core |
| `MANIFEST_SIGNATURE_INVALID` | Signature verification failed. | core |
| `MANIFEST_POP_FAILED` | Proof-of-possession failed. | core |
| `MANIFEST_VERSION_UNKNOWN` | Version not supported. | core |
| `MANIFEST_NOT_FOUND` | No manifest for the requested AID. | core |

## Delegation codes (RFC-AITP-0006)

Delegation-layer codes carry the `DELEGATION_` prefix so they cannot be confused with the envelope-level or manifest-level codes that share the same root.

| Code | Meaning | spec_status |
|---|---|---|
| `DELEGATION_AUDIENCE_MISMATCH` | `aud` ≠ verifier's AID. | core |
| `DELEGATION_SCOPE_EXCEEDED` | `scope ⊄ voucher.grants`. | core |
| `DELEGATION_INVALID_VOUCHER` | Embedded voucher JWS signature invalid, `voucher.iss` ≠ verifier's AID, or `voucher.sub` ≠ outer `iss`. **Renamed in v0.2** from `DELEGATION_INVALID_GRANT_PROOF` (the `grant_proof` reconstruction mechanism was removed by the JWS migration). | core |
| `DELEGATION_SOURCE_TCT_REVOKED` | `voucher.src_jti` is in the issuing peer's deny list. | core |
| `DELEGATION_INVALID_SIGNATURE` | Outer delegation JWS signature invalid, or self-delegation (`iss` == `sub`). | core |
| `DELEGATION_EXPIRED` | Token or voucher expired, or `exp` > `voucher.exp`. | core |
| `DELEGATION_POP_FAILED` | Proof-of-possession failed. | core |
| `DELEGATION_MULTIHOP_NOT_SUPPORTED` | Multi-hop attempt detected (`chain` claim present without RFC-AITP-0011 opt-in). | core |

> **`DELEGATION_MULTIHOP_NOT_SUPPORTED` is a core code, not a draft code.** Implementations with default `max_hops = 0` MUST emit this code for any delegation token carrying a `chain` claim — rejecting multi-hop is the **required core behavior**, not an optional one. The code is distinct from the `draft` codes in the "Multi-hop delegation codes (RFC-AITP-0011, opt-in)" table below: those codes (`DELEGATION_HOP_LIMIT_EXCEEDED`, `DELEGATION_CHAIN_HASH_MISMATCH`) are emitted by implementations that have opted into multi-hop and are validating chain semantics. `DELEGATION_MULTIHOP_NOT_SUPPORTED` is the core *refusal* to even process the chain — a structural rejection before any per-hop verification. See [conformance fixture `del-004`](../schemas/conformance/del-004-multihop-rejected-v01.json) for the pinned v0.1-era behavior and its v0.2 sibling for the claim-shaped equivalent.

## Multi-hop delegation codes (RFC-AITP-0011, opt-in)

These codes are reserved for multi-hop delegation (RFC-AITP-0011 is Draft and not part of core conformance). Implementations that do not opt in will not emit them.

| Code | Meaning | spec_status |
|---|---|---|
| `DELEGATION_HOP_LIMIT_EXCEEDED` | Chain length exceeds `max_delegation_hops` (default 3). | draft |
| `DELEGATION_CHAIN_HASH_MISMATCH` | `chain_hash` does not match the `chain` array contents (truncation or tampering detected). | draft |

## Session Trust Bundle codes (RFC-AITP-0010, opt-in)

These codes are reserved for Session Trust Bundles (RFC-AITP-0010 is Draft and not part of core conformance). The granular code set was pinned to align with the `aitp-rs` adapter that emits them ahead of bundle conformance.

| Code | Meaning | spec_status |
|---|---|---|
| `BUNDLE_INVALID_SIGNATURE` | Coordinator's outer bundle signature failed verification under the coordinator's Manifest key. | draft |
| `BUNDLE_VERSION_MISMATCH` | `version` is not `"aitp/0.2"` (or a later version this implementation supports). | draft |
| `BUNDLE_EXPIRED` | `expires_at` is in the past at verification time. | draft |
| `BUNDLE_EXPIRY_WINDOW_INVARIANT` | `expires_at` is greater than `min(participants[*].tct.exp)` (violates RFC-AITP-0010 §6). | draft |
| `BUNDLE_COORDINATOR_ISSUER_MISMATCH` | One or more participant TCT `iss` claims do not equal `coordinator`. | draft |
| `BUNDLE_AUDIENCE_MISMATCH` | A participant TCT `aud` claim does not equal that participant's `aid`. | draft |
| `BUNDLE_EMPTY_PARTICIPANTS` | `participants` array is empty. | draft |
| `BUNDLE_PARTICIPANT_TCT_INVALID` | At least one embedded participant TCT failed standard TCT verification. | draft |
| `BUNDLE_NOT_MEMBER` | Receiver's AID is not in `participants[*].aid`. | draft |
| `SESSION_BUNDLE_INVALID` | Aggregate fallback — implementations MAY return this when a deployment policy requires a single-error surface for bundles, in lieu of the specific codes above. | draft |

## Adding a code

Open a PR adding a row to one of the tables above. Verifiers MUST NOT reveal which specific policy check failed beyond the registered code; `reason` strings are informational only.
