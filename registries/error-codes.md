# Error Code Registry

AITP error codes returned in error envelopes (`AitpError.code`). v0.1 is JSON-only; codes are string constants in the canonical JSON wire format (see [RFC-AITP-0001 §5.6](../rfcs/RFC-AITP-0001-core.md#56-error-envelope)).

> **Stability:** The codes listed below are stable for v0.1. Implementations MUST treat unknown codes as opaque failures and MUST NOT key behavior off codes that are not in this registry. New codes can be added without an RFC; renaming or removing an existing code is a breaking change and requires the RFC process.

> **`spec_status` column.** Each code below carries a `spec_status` of either `core` or `draft`. `core` codes are part of v0.1 conformance and MAY be emitted by any conformant implementation. `draft` codes are reserved for post-v0.1 RFCs (currently RFC-AITP-0010 Session Trust Bundle and RFC-AITP-0011 Multi-hop Delegation) and MUST NOT be used by v0.1 implementations except when implementing the cited draft RFC. v0.1 conformance runners MUST treat receipt of a `draft` code from an implementation that does not opt into the corresponding draft as a non-conformance.

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

## TCT-verification codes (RFC-AITP-0005)

Returned when a peer evaluates a TCT outside the handshake context — e.g. via a TCT verification API or local verification of a presented TCT.

| Code | Meaning | Retryable | spec_status |
|---|---|---|---|
| `TCT_EXPIRED` | TCT `expires_at` is in the past. | false | core |
| `TCT_REVOKED` | TCT `jti` is in the issuing peer's deny list. | false | core |
| `TCT_SIGNATURE_INVALID` | TCT signature does not validate under the issuing peer's key. | false | core |
| `TCT_EXPIRES_AFTER_MANIFEST` | TCT `expires_at` exceeds the issuing peer's Manifest `expires_at` (RFC-AITP-0004 §4.3). The peer-issued TCT cannot outlive the credential that authenticates its issuer's key. | false | core |

## Downstream PoP codes (RFC-AITP-0005 §6)

| Code | Meaning | Retryable | spec_status |
|---|---|---|---|
| `POP_CHALLENGE_INVALID` | Challenge envelope was malformed or stale. | false | core |
| `POP_RESPONSE_INVALID` | Response signature failed verification against `binding.cnf`. | false | core |

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
| `AUDIENCE_MISMATCH` | TCT audience ≠ self AID. | core |
| `GRANT_OVERFLOW` | TCT grants exceed peer's `offered_capabilities`. | core |
| `TCT_EXPIRED` | TCT already expired. | core |
| `TCT_EXPIRES_AFTER_MANIFEST` | TCT `expires_at` exceeds issuer's Manifest `expires_at`. | core |
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
| `DELEGATION_AUDIENCE_MISMATCH` | `audience ≠ issuer_aid`. | core |
| `DELEGATION_SCOPE_EXCEEDED` | `scope ⊄ grant_proof.capabilities`. | core |
| `DELEGATION_INVALID_GRANT_PROOF` | `grant_proof.signature` invalid, or `grant_proof.subject ≠ issued_by`. | core |
| `DELEGATION_SOURCE_TCT_REVOKED` | `grant_proof.source_tct_jti` is in the issuing peer's deny list. | core |
| `DELEGATION_INVALID_SIGNATURE` | `delegation.signature` invalid. | core |
| `DELEGATION_EXPIRED` | Token or grant proof expired. | core |
| `DELEGATION_POP_FAILED` | Proof-of-possession failed. | core |
| `DELEGATION_MULTIHOP_NOT_SUPPORTED` | Multi-hop attempt detected (v0.1 implementations reject multi-hop tokens). | core |

## Multi-hop delegation codes (RFC-AITP-0011, post-v0.1)

These codes are reserved for v0.2 multi-hop delegation (RFC-AITP-0011 is currently Draft and not part of v0.1 conformance). Implementations targeting only v0.1 will not emit them.

| Code | Meaning | spec_status |
|---|---|---|
| `DELEGATION_HOP_LIMIT_EXCEEDED` | Chain length exceeds `max_delegation_hops` (default 3). | draft |
| `DELEGATION_CHAIN_HASH_MISMATCH` | `chain_hash` does not match the `chain` array contents (truncation or tampering detected). | draft |

## Session Trust Bundle codes (RFC-AITP-0010, post-v0.1)

These codes are reserved for v0.2 Session Trust Bundles (RFC-AITP-0010 is currently Draft and not part of v0.1 conformance). The granular code set was pinned to align with the `aitp-rs` adapter that emits them ahead of v0.2 conformance.

| Code | Meaning | spec_status |
|---|---|---|
| `BUNDLE_INVALID_SIGNATURE` | Coordinator's outer bundle signature failed verification under the coordinator's Manifest key. | draft |
| `BUNDLE_VERSION_MISMATCH` | `version` is not `"aitp/0.1"` (or a later version this implementation supports). | draft |
| `BUNDLE_EXPIRED` | `expires_at` is in the past at verification time. | draft |
| `BUNDLE_EXPIRY_WINDOW_INVARIANT` | `expires_at` is greater than `min(participants[*].tct.expires_at)` (violates RFC-AITP-0010 §6). | draft |
| `BUNDLE_COORDINATOR_ISSUER_MISMATCH` | One or more `participants[*].tct.issuer` values do not equal `coordinator`. | draft |
| `BUNDLE_AUDIENCE_MISMATCH` | A `participants[i].tct.audience` does not equal `participants[i].aid`. | draft |
| `BUNDLE_EMPTY_PARTICIPANTS` | `participants` array is empty. | draft |
| `BUNDLE_PARTICIPANT_TCT_INVALID` | At least one embedded participant TCT failed standard TCT verification. | draft |
| `BUNDLE_NOT_MEMBER` | Receiver's AID is not in `participants[*].aid`. | draft |
| `SESSION_BUNDLE_INVALID` | Aggregate fallback — implementations MAY return this when a deployment policy requires a single-error surface for bundles, in lieu of the specific codes above. | draft |

## Adding a code

Open a PR adding a row to one of the tables above. Verifiers MUST NOT reveal which specific policy check failed beyond the registered code; `reason` strings are informational only.
