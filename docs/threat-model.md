# Threat Model — Quick Reference

The full normative threat model is [RFC-AITP-0009 Security](../rfcs/RFC-AITP-0009-security.md). This document is a non-normative summary.

## Threats addressed in v0.1

| Threat | Mechanism |
|---|---|
| Impersonation | AID + identity binding signature + Mutual-Handshake PoP. |
| Replay | `message_id` deduplication + timestamp window + nonce echoes. |
| Manifest tampering | Manifest signature + PoP over a publish-time challenge. |
| Manifest replay across agents | PoP signature is bound to the Manifest's own challenge. |
| Confused deputy | `audience` field on TCTs (peer AID) and delegation tokens (delegator AID); no wildcards. |
| Token theft | Proof-of-possession (`binding.cnf`). |
| Delegation scope escalation | `scope ⊆ grant_proof.capabilities` (stateless). |
| Peer-AID confusion | Peer keys are resolved from the peer's Manifest, not from `trust_anchors`. |
| PoP nonce binding failure | `pop_nonce_echo` MUST equal the value sent in the previous round. |
| Key compromise | JTI revocation + Manifest re-publication + short TTLs. |

## Known gaps in v0.1

| Gap | Mitigation |
|---|---|
| No real-time key-revocation push | Pull-based; bounded by `max_staleness_secs`. |
| No Sybil resistance | Delegated to identity providers. |
| No runtime integrity attestation | TEE extension reserved in [RFC-AITP-0012](../rfcs/RFC-AITP-0012-extensions.md). |
| No ZK compliance proofs | ZK extension reserved in RFC-AITP-0012. |
| No multi-hop delegation | Reserved in [RFC-AITP-0011](../rfcs/RFC-AITP-0011-multihop-delegation.md). |
| No multi-agent session scaling | Reserved in [RFC-AITP-0010](../rfcs/RFC-AITP-0010-session-trust-bundle.md). |
| No cross-domain trust federation | Future specification. |

## Attack scenarios

### 1. C presents B's delegation token to peer D
**Result.** D rejects — `delegation.audience = A's AID ≠ D's AID`.

### 2. B escalates scope when delegating to C
**Setup.** A peer-issued grants `["read_data"]` to B. B issues a delegation to C claiming `["read_data", "write_data"]`.
**Result.** A rejects — `scope ⊆ grant_proof.capabilities` fails. `write_data` is not in A's original signed grant.

### 3. Attacker replays a captured MUTUAL_HELLO
**Result.** Rejected — `message_id` already in the deny list.

### 4. Attacker uses a stolen TCT
**Result.** Attacker cannot prove possession of the private key matching `binding.cnf`. The Mutual Handshake's PoP is mandatory; downstream consumers enforcing PoP reject the request.

### 5. Attacker swaps a peer's Manifest
**Result.** The Manifest's PoP signature must validate under the public key in `manifest.aid`. Without the genuine private key, the attacker cannot forge a valid PoP. TLS at the well-known endpoint is the secondary defense.
