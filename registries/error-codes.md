# Error Code Registry

AITP error codes returned in error envelopes (`AitpError.code`). v0.1 is JSON-only; codes are string constants in the canonical JSON wire format (see [RFC-AITP-0001 §5.6](../rfcs/RFC-AITP-0001-core.md#56-error-envelope)).

> **Stability:** The codes listed below are stable for v0.1. Implementations MUST treat unknown codes as opaque failures and MUST NOT key behavior off codes that are not in this registry. New codes can be added without an RFC; renaming or removing an existing code is a breaking change and requires the RFC process.

## Code naming convention

Object-level failures use the `<OBJECT>_<FAILURE>` form (e.g.
`MANIFEST_SIGNATURE_INVALID`, `TCT_EXPIRED`,
`DELEGATION_SCOPE_EXCEEDED`). Envelope-level failures use bare codes
(e.g. `INVALID_SIGNATURE`, `REPLAY_DETECTED`). This granularity is
deliberate: a consumer needs to know *which* object failed, not only
that something failed. New codes proposed via the RFC process MUST
follow this convention.

## Envelope-level codes

| Code | Meaning | Retryable | Spec |
|---|---|---|---|
| `INVALID_ENVELOPE` | Envelope failed schema validation. | false | [RFC-AITP-0001 §5.6](../rfcs/RFC-AITP-0001-core.md#56-error-envelope) |
| `INVALID_SIGNATURE` | Signature verification failed. | false | [RFC-AITP-0001 §5.4](../rfcs/RFC-AITP-0001-core.md#54-signature) |
| `REPLAY_DETECTED` | Duplicate `message_id`. | false | [RFC-AITP-0001 §5.5](../rfcs/RFC-AITP-0001-core.md#55-replay-protection) |
| `TIMESTAMP_EXPIRED` | Timestamp outside tolerance. | true | [RFC-AITP-0001 §5.5](../rfcs/RFC-AITP-0001-core.md#55-replay-protection) |
| `UNKNOWN_VERSION` | Unsupported `version` field. | false | [RFC-AITP-0001 §7](../rfcs/RFC-AITP-0001-core.md#7-compatibility-model) |
| `IDENTITY_FAILED` | Identity binding could not be verified. | false | [RFC-AITP-0002](../rfcs/RFC-AITP-0002-identity.md) |
| `POLICY_VIOLATION` | Requested capability not granted. | false | [RFC-AITP-0004 §4](../rfcs/RFC-AITP-0004-mutual-handshake.md#4-tct-issuance-rules) |
| `GRANT_OVERFLOW` | Peer-issued TCT grants exceed `offered_capabilities`. | false | [RFC-AITP-0004](../rfcs/RFC-AITP-0004-mutual-handshake.md) |
| `INSUFFICIENT_GRANTS` | Received peer-issued TCT lacks a capability listed in the receiver's own `required_peer_capabilities`. | false | [RFC-AITP-0004 §5.3/§5.4](../rfcs/RFC-AITP-0004-mutual-handshake.md) |
| `KEY_RESOLUTION_FAILED` | Could not resolve issuer or peer keys. | true | [RFC-AITP-0007](../rfcs/RFC-AITP-0007-key-resolution.md) |

## TCT-verification codes (RFC-AITP-0005)

Returned when a peer evaluates a TCT outside the handshake context — e.g. via a TCT verification API or local verification of a presented TCT.

| Code | Meaning | Retryable |
|---|---|---|
| `TCT_EXPIRED` | TCT `expires_at` is in the past. | false |
| `TCT_REVOKED` | TCT `jti` is in the issuing peer's deny list. | false |
| `TCT_SIGNATURE_INVALID` | TCT signature does not validate under the issuing peer's key. | false |

## Downstream PoP codes (RFC-AITP-0005 §6)

| Code | Meaning | Retryable |
|---|---|---|
| `POP_CHALLENGE_INVALID` | Challenge envelope was malformed or stale. | false |
| `POP_RESPONSE_INVALID` | Response signature failed verification against `binding.cnf`. | false |

## Manifest codes (RFC-AITP-0003)

| Code | Meaning | Retryable |
|---|---|---|
| `MANIFEST_EXPIRED` | `expires_at` is in the past. | false |
| `MANIFEST_SIGNATURE_INVALID` | Signature verification failed. | false |
| `MANIFEST_POP_FAILED` | Proof-of-possession verification failed. | false |
| `INCOMPATIBLE_TRUST_ANCHORS` | No overlap in accepted trust anchors. | false |
| `MANIFEST_VERSION_UNKNOWN` | `version` not supported by this implementation. | false |

## Mutual Handshake codes (RFC-AITP-0004)

Returned in error envelopes during the four-message handshake.

| Code | Meaning |
|---|---|
| `INCOMPATIBLE_TRUST_ANCHORS` | No trust-anchor overlap. |
| `MANIFEST_SIGNATURE_INVALID` | Peer's Manifest signature invalid. |
| `MANIFEST_POP_FAILED` | Peer's Manifest PoP failed. |
| `POP_VERIFICATION_FAILED` | Round-2 PoP signature failed. |
| `NONCE_MISMATCH` | `pop_nonce_echo` mismatch. |
| `AUDIENCE_MISMATCH` | TCT audience ≠ self AID. |
| `GRANT_OVERFLOW` | TCT grants exceed peer's `offered_capabilities`. |
| `TCT_EXPIRED` | TCT already expired. |
| `IDENTITY_FAILED` | Peer identity verification failed. |
| `REPLAY_DETECTED` | Duplicate `message_id`. |
| `TIMESTAMP_EXPIRED` | Envelope timestamp outside tolerance. |

## Manifest-service codes

Returned by an HTTP endpoint serving `/.well-known/aitp-manifest` or by an out-of-band manifest lookup.

| Code | Meaning |
|---|---|
| `MANIFEST_EXPIRED` | `expires_at` in the past. |
| `MANIFEST_SIGNATURE_INVALID` | Signature verification failed. |
| `MANIFEST_POP_FAILED` | Proof-of-possession failed. |
| `MANIFEST_VERSION_UNKNOWN` | Version not supported. |
| `MANIFEST_NOT_FOUND` | No manifest for the requested AID. |

## Delegation codes (RFC-AITP-0006)

Delegation-layer codes carry the `DELEGATION_` prefix so they cannot be confused with the envelope-level or manifest-level codes that share the same root.

| Code | Meaning |
|---|---|
| `DELEGATION_AUDIENCE_MISMATCH` | `audience ≠ issuer_aid`. |
| `DELEGATION_SCOPE_EXCEEDED` | `scope ⊄ grant_proof.capabilities`. |
| `DELEGATION_INVALID_GRANT_PROOF` | `grant_proof.signature` invalid, or `grant_proof.subject ≠ issued_by`. |
| `DELEGATION_SOURCE_TCT_REVOKED` | `grant_proof.source_tct_jti` is in the issuing peer's deny list. |
| `DELEGATION_INVALID_SIGNATURE` | `delegation.signature` invalid. |
| `DELEGATION_EXPIRED` | Token or grant proof expired. |
| `DELEGATION_POP_FAILED` | Proof-of-possession failed. |
| `DELEGATION_MULTIHOP_NOT_SUPPORTED` | Multi-hop attempt detected (v0.1 implementations reject multi-hop tokens). |

## Multi-hop delegation codes (RFC-AITP-0011, post-v0.1)

These codes are reserved for v0.2 multi-hop delegation (RFC-AITP-0011 is currently Draft and not part of v0.1 conformance). Implementations targeting only v0.1 will not emit them.

| Code | Meaning |
|---|---|
| `DELEGATION_HOP_LIMIT_EXCEEDED` | Chain length exceeds `max_delegation_hops` (default 3). |
| `DELEGATION_CHAIN_HASH_MISMATCH` | `chain_hash` does not match the `chain` array contents (truncation or tampering detected). |

## Session Trust Bundle codes (RFC-AITP-0010, post-v0.1)

These codes are reserved for v0.2 Session Trust Bundles (RFC-AITP-0010 is currently Draft and not part of v0.1 conformance).

| Code | Meaning |
|---|---|
| `SESSION_BUNDLE_INVALID` | Bundle signature, expiry, or per-participant TCT verification failed. |
| `SESSION_BUNDLE_NOT_MEMBER` | Receiver's AID is not in `participants[*].aid`. |
| `SESSION_BUNDLE_EXPIRED` | Bundle `expires_at` is in the past. |

## Adding a code

Open a PR adding a row to one of the tables above. Verifiers MUST NOT reveal which specific policy check failed beyond the registered code; `reason` strings are informational only.
