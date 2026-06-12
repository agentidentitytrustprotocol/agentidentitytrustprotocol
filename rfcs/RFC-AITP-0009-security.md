# RFC-AITP-0009
# Security & Threat Model

**Document:** RFC-AITP-0009
**Version:** 0.2.0-draft
**Status:** Community Standards Track (v0.2 Draft)
**Depends on:** All preceding RFCs.

---

## Abstract

This RFC enumerates the threats AITP defends against in the agent-to-agent setting, the defenses, the v0.2 limitations, and the implementation requirements that conformant deployments MUST follow.

---

## 1. Threats Addressed in v0.2

### 1.1 Impersonation

**Threat:** An attacker claims to be a trusted agent without holding the corresponding private key.

**Defense:**
- All envelopes are signed with the sender's private key (AID).
- Identity binding requires proof-of-possession or a verifiable credential from a trusted issuer.
- The Mutual Handshake includes a PoP exchange in round 2 that binds the TCT to a live private key.
- Peer-issued TCTs are bound to the subject's public key via the `cnf` claim (`cnf.jkt`, RFC-AITP-0001 §5.4.4).

### 1.2 Replay

**Threat:** An attacker captures a valid AITP message and replays it.

**Defense:**
- `message_id` deduplication: peers maintain a deny list of seen IDs.
- `timestamp` tolerance window (default ±300 s): stale messages are rejected.
- Mutual-Handshake nonces (`pop_nonce`, `pop_nonce_echo`) bind round 2 to round 1.
- TCT `exp`: tokens are time-bounded.
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
- Delegation tokens carry an `aud` claim set to the AID of the issuing peer they may be presented to (A — RFC-AITP-0006 §2).
- Peers MUST reject delegation tokens where `aud ≠ self` (`DELEGATION_AUDIENCE_MISMATCH`).
- TCTs carry an `aud` claim that MUST be the subject peer's AID; consuming peers reject mismatched audiences (`AUDIENCE_MISMATCH`).
- Wildcard audiences are forbidden (RFC-AITP-0005 §5).

### 1.6 Token Theft and Misuse

**Threat:** An attacker obtains a TCT and uses it without being the intended subject.

**Defense:**
- The `cnf` claim binds the TCT to the subject's public key.
- Consumers MUST verify proof-of-possession for grants marked as requiring it by the issuing peer's policy, and SHOULD verify PoP for all grants unless equivalent channel binding is explicitly configured.
- Short TTLs (RFC-AITP-0005 §9.1) limit the window of misuse.
- JTI revocation allows immediate invalidation.

### 1.7 Delegation Scope Escalation

**Threat:** Agent B issues a delegation token to C claiming more capabilities than B was originally granted.

**Defense:**
- Delegation tokens embed — verbatim, as an opaque string — the grant voucher A minted alongside B's TCT (RFC-AITP-0005 §8): A's original signed grant to B.
- Peers check `scope ⊆ voucher.grants` (`DELEGATION_SCOPE_EXCEEDED` on failure).
- The voucher is signed by A; B cannot forge it, and B cannot substitute a voucher issued to another agent (`voucher.sub` must equal the outer `iss` — RFC-AITP-0006 §4 step 4, `DELEGATION_INVALID_VOUCHER`).
- The scope-constraint check is **stateless** — no session lookup required.

> **Reconstruction surface removed in v0.2.** The v0.1 `grant_proof` was a projection of B's TCT whose signature could only be checked by canonical-JSON *reconstruction* of the source TCT's bytes — a verifier-side re-serialization surface of exactly the kind the JWS migration exists to eliminate. That surface is removed entirely in v0.2: `verify_source_tct_projection`-style logic is deleted from the protocol, and every signature in delegation verification — the outer delegation JWS and the embedded voucher JWS — is checked over the transmitted bytes only (RFC-AITP-0006 §3–§4). No verification step reconstructs any byte sequence.

### 1.8 Peer-AID Confusion

**Threat:** A consuming peer treats a peer-issued TCT as if it were issued by some other authority, or fails to resolve the issuer's key from the right Manifest.

**Defense:**
- The TCT `iss` claim is unambiguously a peer AID.
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

**Partial defense (v0.2):**
- The compromised peer SHOULD revoke all TCTs it issued (add JTIs to its deny list).
- The compromised peer SHOULD re-publish its Manifest under a new `aid`.
- Identity-issuer key revocation propagates through the cache TTL or `max_staleness_secs`.
- Short TTLs limit exposure window.

**Known limitation:** AITP v0.2 does not provide real-time key-compromise detection. Operators MUST establish out-of-band key-rotation procedures.

### 1.11 Manifest PoP Bypass

**Threat:** An attacker forges a Manifest proof-of-possession signature for an AID they do not control — for example, by exploiting an implementation that hashes the wrong input (the base64url ASCII string instead of the decoded raw bytes) or that fails to verify the PoP at all. A forged Manifest can redirect every subsequent handshake to a man-in-the-middle.

**Defense:**
- The PoP is `sign(sha256(base64url_decode(challenge)))` — the unified signing-input convention defined in [RFC-AITP-0001 §5.4.2](RFC-AITP-0001-core.md#542-pop-signing-input-convention).
- The `challenge` is chosen randomly at Manifest publication time by the legitimate publisher; an attacker cannot choose `challenge` to produce a weaker signing input without controlling the Manifest publication itself.
- Implementations MUST hash the 16 raw decoded bytes (NOT the ASCII string) and MUST verify the PoP against the public key encoded in `manifest.aid` *before* trusting any other Manifest field — including the handshake endpoint, accepted trust anchors, and offered capabilities.
- Implementations MUST cross-check their PoP code path against the pinned KAT vector `kat-manifest-pop-001` ([`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json)) so a "wrong-input" bug is detected at test time rather than at first cross-implementation contact.
- Conformance fixtures `man-001`/`mh-003` exercise the rejection path; `kat-manifest-pop-001` exercises the construction path. Both MUST pass.

### 1.12 Algorithm Confusion

**Threat:** An attacker presents a compact-JWS artifact (TCT, grant voucher, delegation token) whose `alg` header does not correspond to the signer's key — for example, an ES256-signed token presented against an Ed25519 AID, or a header naming any algorithm the attacker hopes a permissive JOSE library will honor. This is the classic JOSE algorithm-confusion class: a verifier that trusts the header to select the verification algorithm can be steered onto the wrong (or a weaker) code path.

**Defense:**
- There is **no algorithm negotiation**. Before signature verification, the verifier derives the **sole acceptable** `alg` value from the signer's AID (`EdDSA` for Ed25519 AIDs, `ES256` for P-256 AIDs) and rejects any other header value with `TOKEN_ALG_MISMATCH` ([RFC-AITP-0001 §5.4.5](RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts)). The AID, not the token, decides.
- The `alg` header is treated as attacker-controlled input until pinned; pinning happens before any cryptographic operation (RFC-AITP-0005 §7.2 step 3, RFC-AITP-0006 §4 step 1).
- Key material is never taken from the token: the header MUST contain exactly `alg` and `typ`, and headers carrying `jwk`, `jku`, `x5c`, `kid`, or any other parameter are rejected outright (RFC-AITP-0001 §5.4.5).
- JCS-profile signatures have the parallel rule: the algorithm tag MUST match the signing AID's algorithm (RFC-AITP-0001 §5.4.3).

### 1.13 Token-Type Confusion

**Threat:** One AITP JWS artifact is replayed in another artifact's verification context — a grant voucher or delegation token presented as a TCT, or vice versa. The three portable artifacts are signed by the same agent keys and share claim names, so a verifier that dispatches on payload shape alone can be confused into honoring the wrong artifact.

**Defense:**
- Every AITP JWS carries an explicit `typ` per [RFC 8725 §3.11](https://datatracker.ietf.org/doc/html/rfc8725#section-3.11) (`aitp-tct+jwt`, `aitp-grant+jwt`, `aitp-delegation+jwt`), and verifiers MUST reject a token whose `typ` does not exactly match the single value expected for the verification context, with `TOKEN_TYP_MISMATCH` (RFC-AITP-0001 §5.4.5).
- `typ` enforcement runs early in every verification order: TCT verification step 2 (RFC-AITP-0005 §7.2), and both layers of delegation verification — the outer token and the embedded voucher (RFC-AITP-0006 §4 steps 1 and 3).
- Defense in depth: strict claim validation (unknown claims outside `ext` are rejected, RFC-AITP-0001 §5.4.5) means the artifacts' differing claim sets also fail cross-context validation even before semantic checks.

### 1.14 Unsecured JWS (`alg: none`)

**Threat:** An attacker strips or fabricates the signature of a compact-JWS artifact and presents it with `alg: none` (in any capitalization), or as a structurally degenerate token (missing or empty signature segment, JSON serialization, detached payload), hoping the verifier's JOSE library accepts unsecured input.

**Defense:**
- Algorithm pinning (§1.12) forecloses `none` by construction: `none` can never equal the AID-derived `alg` value, so the token is rejected with `TOKEN_ALG_MISMATCH` before any signature processing (RFC-AITP-0001 §5.4.5).
- Strict three-segment parsing: verifiers MUST reject any token that does not consist of exactly three non-empty `.`-separated base64url segments — no unsecured JWS, no detached payload, no JSON serialization (RFC-AITP-0001 §5.4.5). A signature-less token never reaches the `alg` check, let alone verification.

---

## 2. Known Limitations (v0.2)

| Threat | Status |
|---|---|
| Sybil attacks | Delegated to identity providers (see [non-goals](#5-non-goals)). |
| Runtime integrity (is the agent running expected code?) | Requires TEE — reserved in [RFC-AITP-0012](RFC-AITP-0012-extensions.md). |
| Zero-knowledge compliance proofs | Requires ZK extension — reserved in [RFC-AITP-0012](RFC-AITP-0012-extensions.md). |
| Real-time key-revocation propagation | Out-of-band in v0.2 (pull-based). |
| Cross-domain trust federation | Future specification. |
| Multi-hop delegation chains | Specified in [RFC-AITP-0011](RFC-AITP-0011-multihop-delegation.md) (Draft; opt-in). |
| Multi-agent session scaling (O(N²) handshakes) | Specified in [RFC-AITP-0010](RFC-AITP-0010-session-trust-bundle.md) (Draft; opt-in). |

---

## 3. Implementation Security Requirements

Implementations **MUST**:

- Use a cryptographically secure RNG for `message_id`, PoP nonces, and Manifest challenges.
- Store private keys in secure storage (HSM, OS keychain, or equivalent).
- Validate all inputs against the JSON Schema before processing.
- Enforce expiry (`exp` on compact-JWS artifacts, `expires_at` on JCS-profile objects) with server-side time (not client-provided time).
- Validate the TLS certificate of any peer host before fetching its Manifest.
- Log all authentication failures with sufficient context for forensic analysis.
- Never log private keys, raw compact-JWS tokens (TCT, grant voucher, delegation token), PoP nonces, or other proof material.

Implementations **SHOULD**:

- Rotate signing keys on a schedule (recommended: 90 days).
- Pin TLS certificates of frequently-contacted peers in production.
- Implement rate limiting on the handshake endpoint per §3.1 below.
- Re-verify long-lived peer TCTs every 5 minutes by checking the issuer's `ListRevoked` feed.

### 3.1 Rate limiting (RECOMMENDED)

A malicious agent can flood the handshake endpoint with syntactically valid envelopes, each forcing a JWK fetch and signature verification. Rate limiting is a defense-in-depth measure for resource exhaustion; protocol-level replay is handled by the deny list (RFC-AITP-0001 §5.5), which runs before the rate-limit check.

Implementations SHOULD enforce per-source-IP and per-AID limits at the handshake endpoint. Recommended defaults:

| Limit | Default |
|---|---|
| Handshake requests per source IP, per 60 s | 30 |
| Handshake requests per initiator AID, per 60 s | 10 |
| Maximum concurrent in-flight handshake sessions | 1000 |
| Maximum `MUTUAL_HELLO` payload size | 64 KB |

Rate limiting is a deployment concern; these defaults are RECOMMENDED, not REQUIRED. Deployments handling high-volume agent swarms SHOULD tune limits to match expected traffic. Responses to rate-limited requests SHOULD use HTTP 429 with no AITP `error` envelope payload (the request never reached the protocol layer).

The check order at the handshake endpoint **MUST** be:

1. **Message-ID deny list** (replay; [RFC-AITP-0001 §5.5](RFC-AITP-0001-core.md#55-replay-protection)) — runs before rate limiting so a replay attempt does not consume the sender's rate-limit slot. A captured envelope that re-arrives MUST be rejected with `REPLAY_DETECTED` without incrementing the rate-limit counter for the AID it carries.
2. **Rate limiting** (this section) — runs before timestamp validation so a flood of distinct fresh envelopes is shed efficiently before any clock comparison or schema parsing.
3. **Timestamp tolerance** ([RFC-AITP-0001 §5.5](RFC-AITP-0001-core.md#55-replay-protection)) — `TIMESTAMP_EXPIRED` for envelopes outside the configured window.
4. **Content-Type and body-size validation** — reject oversized or wrong-Content-Type bodies before parsing.
5. **Envelope signature verification** ([RFC-AITP-0001 §5.4](RFC-AITP-0001-core.md#54-signature)) — `INVALID_SIGNATURE` on failure.
6. **Payload cryptographic checks** — Manifest signature/PoP, peer-issued TCT signature, downstream PoP, and any other payload-level cryptography per the message type (`MUTUAL_HELLO`, `MUTUAL_HELLO_ACK`, `MUTUAL_COMMIT`, `MUTUAL_COMMIT_ACK`).

This ordering is normative: replay-before-rate-limit prevents an attacker from burning a victim's rate-limit budget with captured envelopes; rate-limit-before-timestamp sheds floods before any per-envelope work; signature-verification-before-payload-checks ensures payload bytes are authenticated before any expensive cryptographic operation runs against them. Implementations that reverse any of these orderings MUST document the deviation and the threat that justifies it; the conformance default is the order above.

---

## 4. Cryptographic Agility

AITP v0.2 mandates two signature algorithms: **Ed25519** (RFC 8032; JOSE `EdDSA`) and **ECDSA on P-256 with SHA-256** (JOSE `ES256`). A v0.2 peer MUST be able to verify both, even if it only signs with one (RFC-AITP-0001 §5.4.3); Manifests MAY advertise acceptance via `accepted_signature_algorithms` (v0.2 default `["ed25519", "p256"]`, RFC-AITP-0003 §3.2). The algorithm is determined by the AID key type, not by a negotiated parameter, to prevent algorithm-downgrade attacks.

`version: "aitp/0.2"` artifacts carry their algorithm in one of two ways, depending on the signing profile (RFC-AITP-0001 §5.4):

- **JCS embedded-signature profile** (envelopes, Manifests, revocation snapshots, handshake payloads): the algorithm-tagged signature grammar `<alg>.<base64url-sig>` of [RFC-AITP-0001 §5.4.3](RFC-AITP-0001-core.md#543-algorithm-tagged-signature-wire-format-jcs-profile-only). The tag MUST match the signing AID's algorithm; the legacy untagged 86-char form remains valid and means Ed25519.
- **Compact JWS profile** (TCT, grant voucher, delegation token — v0.2 re-serializes these portable trust artifacts as compact JWS, [RFC-AITP-0001 §5.4.5](RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts)): the JOSE protected-header `alg` parameter carries the algorithm, pinned by the same AID-derived rule — the verifier derives the sole acceptable value from the signer's AID before verification and rejects anything else with `TOKEN_ALG_MISMATCH` (§1.12, §1.14).

The two mechanisms are the same rule stated per profile: the AID decides the algorithm, and the algorithm marker is bound to the signed bytes (the §5.4.3 tag is part of the canonical hash input; the JWS `alg` header is inside the signed segments). The v0.1 baseline was Ed25519-only, with the TCT and delegation token still JCS-signed; both the algorithm-tagged grammar and the JWS re-serialization arrive together in `aitp/0.2`.

A future major version MAY add algorithms via the RFC process. Removing algorithms requires a major version increment.

---

## 5. Non-Goals

The following are explicitly out of scope for AITP v0.2:

| Non-goal | Rationale |
|---|---|
| Service-consumer trust model | AITP is peer-to-peer; there is no third-party verifier. |
| Global reputation standardization | Domain-specific; reserved as a future extension. |
| Sybil resistance | Belongs in identity providers, not a trust evaluation protocol. |
| Identity issuance | AITP is a trust evaluation/expression layer, not an identity system. |
| Real-time key-revocation push | Adds significant complexity; bounded by `max_staleness_secs` in v0.2. |
| Multi-hop delegation chains | Specified in [RFC-AITP-0011](RFC-AITP-0011-multihop-delegation.md) (Draft; opt-in). |
| ZK proof verification (core) | Tooling still maturing; reserved as an extension. |
| TEE attestation (core) | Hardware dependency; reserved as an extension. |
| Cross-domain trust federation | Ecosystem problem, analogous to SAML/OIDC federation. |
| Authorization semantics | What `grants` mean is the consuming peer's domain, not AITP's. |

See [`docs/non-goals.md`](../docs/non-goals.md) for the full rationale on each item.

---

## 6. Attack Walkthroughs

### 6.1 C presents B's delegation token to peer D

**Setup.** A peer-issued a TCT to B. B delegates to C. C tries to use the delegation at D (not A).

**Result.** D rejects — the delegation's `aud` claim = A's AID ≠ D's AID (`DELEGATION_AUDIENCE_MISMATCH`).

### 6.2 B escalates scope when delegating to C

**Setup.** A peer-issued grants `["read_data"]` to B. B issues a delegation to C claiming `["read_data", "write_data"]`.

**Result.** A rejects — `scope ⊆ voucher.grants` fails (`DELEGATION_SCOPE_EXCEEDED`). `write_data` is not in the grant voucher A signed.

### 6.3 Attacker replays a captured MUTUAL_HELLO

**Setup.** Attacker captures A's MUTUAL_HELLO and resends it to B.

**Result.** Rejected — `message_id` already in B's deny list.

### 6.4 Attacker uses a stolen TCT

**Setup.** Attacker obtains a peer-issued TCT from network capture.

**Result.** Attacker cannot prove possession of the private key matching the TCT's `cnf.jkt`. Consuming peers enforcing PoP reject the request.

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
- [RFC-AITP-0010 Session Trust Bundle](RFC-AITP-0010-session-trust-bundle.md) *(Draft, opt-in)*
- [RFC-AITP-0011 Multi-hop Delegation](RFC-AITP-0011-multihop-delegation.md) *(Draft, opt-in)*
- [RFC-AITP-0012 Extensions](RFC-AITP-0012-extensions.md)
