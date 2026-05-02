# RFC-AITP-0009
# Security & Threat Model

**Document:** RFC-AITP-0009
**Version:** 0.1.0-draft
**Status:** Draft
**Depends on:** All preceding RFCs.

---

## Abstract

This RFC enumerates the threats AITP defends against in the agent-to-agent setting, the defenses, the v0.1 limitations, and the implementation requirements that conformant deployments MUST follow.

---

## 1. Threats Addressed in v0.1

### 1.1 Impersonation

**Threat:** An attacker claims to be a trusted agent without holding the corresponding private key.

**Defense:**
- All envelopes are signed with the sender's private key (AID).
- Identity binding requires proof-of-possession or a verifiable credential from a trusted issuer.
- The Mutual Handshake includes a PoP exchange in round 2 that binds the TCT to a live private key.
- Peer-issued TCTs are bound to the subject's public key via `binding.cnf`.

### 1.2 Replay

**Threat:** An attacker captures a valid AITP message and replays it.

**Defense:**
- `message_id` deduplication: peers maintain a deny list of seen IDs.
- `timestamp` tolerance window (default ±300 s): stale messages are rejected.
- Mutual-Handshake nonces (`pop_nonce`, `pop_nonce_echo`) bind round 2 to round 1.
- TCT `expires_at`: tokens are time-bounded.
- TCT `jti` revocation: tokens can be invalidated before expiry.

### 1.3 Manifest Tampering

**Threat:** An attacker presents a modified Manifest pointing at the wrong public key, the wrong handshake endpoint, or claiming different `accepted_trust_anchors`.

**Defense:**
- Manifests are signed by the agent's own private key (key from `aid`).
- The Manifest carries a proof-of-possession over a publish-time challenge.
- Both signatures are verified before any handshake initiation (RFC-AITP-0003 §5).

### 1.4 Manifest Replay Across Agents

**Threat:** An attacker presents agent B's Manifest as if it were agent C's.

**Defense:**
- The `proof_of_possession.challenge` is randomly chosen at publish time and signed.
- The PoP signature is verified using the public key in `manifest.aid`.
- The Manifest's `signature` field covers the entire document, including `aid`.

### 1.5 Confused Deputy

**Threat:** Agent C presents B's delegation token to a different peer D, claiming B's authority there.

**Defense:**
- Delegation tokens carry an `audience` field set to the delegator's AID.
- Peers MUST reject delegation tokens where `audience ≠ self`.
- TCTs carry an `audience` field that MUST be the subject peer's AID; consuming peers reject mismatched audiences.
- Wildcard audiences are forbidden (RFC-AITP-0005 §5).

### 1.6 Token Theft and Misuse

**Threat:** An attacker obtains a TCT and uses it without being the intended subject.

**Defense:**
- `binding.cnf` binds the TCT to the subject's public key.
- Consumers MUST verify proof-of-possession for grants marked as requiring it by the issuing peer's policy, and SHOULD verify PoP for all grants unless equivalent channel binding is explicitly configured.
- Short TTLs (RFC-AITP-0005 §8.1) limit the window of misuse.
- JTI revocation allows immediate invalidation.

### 1.7 Delegation Scope Escalation

**Threat:** Agent B issues a delegation token to C claiming more capabilities than B was originally granted.

**Defense:**
- Delegation tokens carry a `grant_proof`: A's original signed grant to B.
- Peers check `scope ⊆ grant_proof.capabilities`.
- `grant_proof` is signed by A; B cannot forge it.
- The scope-constraint check is **stateless** — no session lookup required.

### 1.8 Peer-AID Confusion

**Threat:** A consuming peer treats a peer-issued TCT as if it were issued by some other authority, or fails to resolve the issuer's key from the right Manifest.

**Defense:**
- The TCT `issuer` field is unambiguously a peer AID.
- Peer-issued TCT keys MUST be resolved from the issuing peer's Manifest, not from `trust_anchors`.
- The Manifest's `aid` field encodes the public key directly (`aid:pubkey:<base64url>`), so resolution is local once the Manifest is verified.

### 1.9 PoP Nonce Binding Failure

**Threat:** An attacker injects a fabricated MUTUAL_HELLO_ACK referencing different nonces, causing A to sign a PoP for an agent it did not intend to authenticate.

**Defense:**
- `pop_nonce_echo` MUST equal the value sent in the previous round.
- Nonces are 128-bit cryptographically random values.
- Implementations MUST verify nonce echoes before constructing a TCT or PoP signature.

### 1.10 Key Compromise

**Threat:** An agent's private key is compromised.

**Partial defense (v0.1):**
- The compromised peer SHOULD revoke all TCTs it issued (add JTIs to its deny list).
- The compromised peer SHOULD re-publish its Manifest under a new `aid`.
- Identity-issuer key revocation propagates through the cache TTL or `max_staleness_secs`.
- Short TTLs limit exposure window.

**Known limitation:** AITP v0.1 does not provide real-time key-compromise detection. Operators MUST establish out-of-band key-rotation procedures.

---

## 2. Known Limitations (v0.1)

| Threat | Status |
|---|---|
| Sybil attacks | Delegated to identity providers (see [non-goals](#5-non-goals)). |
| Runtime integrity (is the agent running expected code?) | Requires TEE — reserved in [RFC-AITP-0012](RFC-AITP-0012-extensions.md). |
| Zero-knowledge compliance proofs | Requires ZK extension — reserved in [RFC-AITP-0012](RFC-AITP-0012-extensions.md). |
| Real-time key-revocation propagation | Out-of-band in v0.1 (pull-based). |
| Cross-domain trust federation | Future specification. |
| Multi-hop delegation chains | Reserved in [RFC-AITP-0011](RFC-AITP-0011-multihop-delegation.md). |
| Multi-agent session scaling (O(N²) handshakes) | Reserved in [RFC-AITP-0010](RFC-AITP-0010-session-trust-bundle.md). |

---

## 3. Implementation Security Requirements

Implementations **MUST**:

- Use a cryptographically secure RNG for `message_id`, PoP nonces, and Manifest challenges.
- Store private keys in secure storage (HSM, OS keychain, or equivalent).
- Validate all inputs against the JSON Schema before processing.
- Enforce `expires_at` with server-side time (not client-provided time).
- Validate the TLS certificate of any peer host before fetching its Manifest.
- Log all authentication failures with sufficient context for forensic analysis.
- Never log private keys, raw JWT tokens, PoP nonces, or delegation proof material.

Implementations **SHOULD**:

- Rotate signing keys on a schedule (recommended: 90 days).
- Pin TLS certificates of frequently-contacted peers in production.
- Implement rate limiting on the handshake endpoint (recommended default: 10 initiations per minute per source AID).
- Re-verify long-lived peer TCTs every 5 minutes by checking the issuer's `ListRevoked` feed.

---

## 4. Cryptographic Agility

AITP v0.1 supports a single signature algorithm: **Ed25519**. The algorithm is determined by the AID key type, not by a negotiated parameter, to prevent algorithm-downgrade attacks.

A future major version MAY add algorithms via the RFC process. Removing algorithms requires a major version increment.

---

## 5. Non-Goals

The following are explicitly out of scope for AITP v0.1:

| Non-goal | Rationale |
|---|---|
| Service-consumer trust model | AITP is peer-to-peer; there is no third-party verifier. |
| Global reputation standardization | Domain-specific; reserved as a future extension. |
| Sybil resistance | Belongs in identity providers, not a trust evaluation protocol. |
| Identity issuance | AITP is a trust evaluation/expression layer, not an identity system. |
| Real-time key-revocation push | Adds significant complexity; bounded by `max_staleness_secs` in v0.1. |
| Multi-hop delegation chains | Reserved in RFC-AITP-0011. |
| ZK proof verification (core) | Tooling still maturing; reserved as an extension. |
| TEE attestation (core) | Hardware dependency; reserved as an extension. |
| Cross-domain trust federation | Ecosystem problem, analogous to SAML/OIDC federation. |
| Authorization semantics | What `grants` mean is the consuming peer's domain, not AITP's. |

See [`docs/non-goals.md`](../docs/non-goals.md) for the full rationale on each item.

---

## 6. Attack Walkthroughs

### 6.1 C presents B's delegation token to peer D

**Setup.** A peer-issued a TCT to B. B delegates to C. C tries to use the delegation at D (not A).

**Result.** D rejects — `delegation.audience = A's AID ≠ D's AID`.

### 6.2 B escalates scope when delegating to C

**Setup.** A peer-issued grants `["read_data"]` to B. B issues a delegation to C claiming `["read_data", "write_data"]`.

**Result.** A rejects — `scope ⊆ grant_proof.capabilities` fails. `write_data` is not in A's original signed grant.

### 6.3 Attacker replays a captured MUTUAL_HELLO

**Setup.** Attacker captures A's MUTUAL_HELLO and resends it to B.

**Result.** Rejected — `message_id` already in B's deny list.

### 6.4 Attacker uses a stolen TCT

**Setup.** Attacker obtains a peer-issued TCT from network capture.

**Result.** Attacker cannot prove possession of the private key matching `binding.cnf`. Consuming peers enforcing PoP reject the request.

> **Note:** PoP within the Mutual Handshake is mandatory. Downstream PoP is governed by the issuing peer's per-grant policy (RFC-AITP-0005 §6); consumers enforcing all grants SHOULD require PoP unless equivalent channel binding is present.

### 6.5 Attacker swaps a peer's Manifest

**Setup.** Attacker intercepts the well-known fetch and serves a Manifest with a different public key.

**Result.** The Manifest's PoP signature must be valid under the public key in `manifest.aid`. Without the genuine private key, the attacker cannot forge a valid PoP. The attacker would also need a valid TLS certificate for the peer host.

---

## 7. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)
- [RFC-AITP-0006 Single-Hop Delegation](RFC-AITP-0006-delegation.md)
- [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)
- [RFC-AITP-0010 Session Trust Bundle](RFC-AITP-0010-session-trust-bundle.md) *(reserved)*
- [RFC-AITP-0011 Multi-hop Delegation](RFC-AITP-0011-multihop-delegation.md) *(reserved)*
- [RFC-AITP-0012 Extensions](RFC-AITP-0012-extensions.md)
