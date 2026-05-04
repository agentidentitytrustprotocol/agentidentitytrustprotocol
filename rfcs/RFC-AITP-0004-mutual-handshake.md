# RFC-AITP-0004
# Mutual Handshake

**Document:** RFC-AITP-0004
**Version:** 0.1.0-rc.3
**Status:** Release Candidate
**Depends on:**
  [RFC-AITP-0001 Core](RFC-AITP-0001-core.md),
  [RFC-AITP-0002 Identity](RFC-AITP-0002-identity.md),
  [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
**Referenced by:** [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)

---

## Abstract

The **Mutual Handshake** is the core agent-to-agent primitive in AITP. Two agents simultaneously verify each other's identity and establish bidirectional trust without requiring a third-party verifier.

At the end of a successful Mutual Handshake, each agent holds a Trust Context Token (TCT) issued by its peer. Each TCT is signed by the issuing peer, audience-bound to the recipient, capability-scoped to what the issuer is willing to grant, and proof-of-possession bound to the recipient's key.

This RFC defines a four-message protocol over two round trips. There is no central verifier and no shared-verifier "fast path"; AITP v0.1 is strictly peer-to-peer.

---

## 1. Design Principles

The Mutual Handshake is governed by four normative principles. Architectural rationale — including why this protocol uses four messages rather than two — lives in [`docs/architecture.md`](../docs/architecture.md).

1. **Simultaneous presentation.** Both agents present identity in the same round trip. Either agent MAY initiate.
2. **Symmetric trust output.** Both agents issue TCTs for each other. Neither agent is privileged by the protocol structure.
3. **Peer-issued TCTs.** Each agent acts as its own verifier for the peer it is authenticating. The TCT `issuer` field is the authenticating agent's AID. Consumers of peer-issued TCTs validate them against the peer's AID public key (resolved from the peer's Manifest).
4. **Graceful failure on incompatibility.** If trust-anchor overlap cannot be established, the handshake MUST fail with `INCOMPATIBLE_TRUST_ANCHORS`. Agents that cannot establish trust MUST NOT proceed with coordination.

---

## 2. Protocol Overview

```
Agent A                              Agent B
   |                                    |
   | (A fetches B's manifest,           |
   |  verifies it, screens for          |
   |  trust anchor compatibility)       |
   |                                    |
   |------ MUTUAL_HELLO --------------->|
   |       A's identity                 |
   |       A's manifest (inline)        |
   |       A's requested grants         |
   |       A's PoP nonce                |
   |                                    |
   | (B verifies A's manifest,          |
   |  screens trust anchors,            |
   |  verifies A's identity,            |
   |  evaluates grant policy)           |
   |                                    |
   |<------ MUTUAL_HELLO_ACK -----------|
   |        B's identity                |
   |        B's manifest (inline)       |
   |        B's requested grants        |
   |        B's PoP nonce               |
   |        A's PoP nonce echo          |
   |                                    |
   | (A verifies B's manifest,          |
   |  verifies B's identity,            |
   |  evaluates grant policy,           |
   |  signs PoP over B's nonce)         |
   |                                    |
   |------ MUTUAL_COMMIT --------------->|
   |       TCT_B  (A → B, signed by A)  |
   |       PoP_A  (A proves key to B)   |
   |                                    |
   | (B verifies TCT_B, verifies PoP_A, |
   |  signs PoP over A's nonce)         |
   |                                    |
   |<------ MUTUAL_COMMIT_ACK ----------|
   |        TCT_A  (B → A, signed by B) |
   |        PoP_B  (B proves key to A)  |
   |                                    |
   | (A verifies TCT_A, verifies PoP_B) |
   |                                    |
   |====== bidirectional trust =========|
   |   A holds TCT_A  (from B)          |
   |   B holds TCT_B  (from A)          |
```

The handshake is **four messages over two round trips**. The first round trip exchanges credentials and nonces. The second round trip exchanges the signed TCTs and proof-of-possession signatures.

---

## 3. Message Definitions

All messages use the standard AITP envelope from RFC-AITP-0001 §5. New `message_type` values: `mutual_hello`, `mutual_hello_ack`, `mutual_commit`, `mutual_commit_ack`.

> **PoP signing input (§§3.3, 3.4, 5.3, 5.4).** Throughout this RFC, `sha256(<nonce>)` denotes the SHA-256 hash of the **raw bytes obtained by base64url-decoding the nonce string** — never the ASCII bytes of the base64url form. This matches the convention used by the pinned-key proof input (RFC-AITP-0002 §3.1) and downstream PoP (RFC-AITP-0005 §6.2). Implementations that hash the base64url string itself are non-conformant.

### 3.1 MUTUAL_HELLO

Sent by the initiating agent (A) to the target agent (B).

#### Envelope

```json
{
  "version": "aitp/0.1",
  "message_type": "mutual_hello",
  "message_id": "<uuid-v4>",
  "timestamp": 1711900000,
  "sender": { "agent_id": "aid:pubkey:<A-pubkey>" },
  "payload": { ... },
  "signature": "<A-sig>"
}
```

#### Payload schema

```json
{
  "identity": {
    "type": "oidc",
    "issuer": "https://auth.openai.com",
    "subject": "agent-A",
    "proof": "<jwt>"
  },
  "manifest": { ... },
  "requested_grants": [
    "macp.mode.task.v1",
    "read_data"
  ],
  "pop_nonce": "<random 128-bit base64url>"
}
```

#### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `identity` | object | REQUIRED | A fresh, handshake-bound identity proof for this exchange. MUST be the same `type` and `subject` as `manifest.identity`. For `oidc`, the JWT MUST include the `pop_nonce` value from this message as the JWT `nonce` claim, binding the proof to this specific handshake and preventing replay of the same JWT in a different session. |
| `manifest` | object | REQUIRED | A's Agent Manifest (RFC-AITP-0003), inline. |
| `requested_grants` | array of string | REQUIRED | Capabilities A is requesting from B. |
| `pop_nonce` | string | REQUIRED | Random 128-bit base64url. B MUST sign over this in MUTUAL_COMMIT_ACK to prove key possession. |

### 3.2 MUTUAL_HELLO_ACK

Sent by the target agent (B) in response to MUTUAL_HELLO.

#### Payload schema

```json
{
  "identity": {
    "type": "oidc",
    "issuer": "https://auth.anthropic.com",
    "subject": "agent-B",
    "proof": "<jwt>"
  },
  "manifest": { ... },
  "requested_grants": [
    "macp.mode.task.v1"
  ],
  "pop_nonce": "<B's nonce>",
  "pop_nonce_echo": "<A's pop_nonce from MUTUAL_HELLO>"
}
```

#### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `identity` | object | REQUIRED | A fresh, handshake-bound identity proof for this exchange. MUST be the same `type` and `subject` as `manifest.identity`. For `oidc`, the JWT MUST include the `pop_nonce` value from this message as the JWT `nonce` claim, binding the proof to this specific handshake and preventing replay of the same JWT in a different session. |
| `manifest` | object | REQUIRED | B's Agent Manifest, inline. |
| `requested_grants` | array of string | REQUIRED | Capabilities B is requesting from A. |
| `pop_nonce` | string | REQUIRED | B's nonce. A MUST sign over this in MUTUAL_COMMIT. |
| `pop_nonce_echo` | string | REQUIRED | MUST equal A's `pop_nonce` from MUTUAL_HELLO. Binds round 2 to round 1. |

### 3.3 MUTUAL_COMMIT

Sent by the initiating agent (A) after verifying B's MUTUAL_HELLO_ACK.

#### Payload schema

```json
{
  "tct_for_peer": {
    "tct": {
      "version": "aitp/0.1",
      "jti": "<uuid-v4>",
      "issuer": "aid:pubkey:<A-pubkey>",
      "subject": "aid:pubkey:<B-pubkey>",
      "audience": "aid:pubkey:<B-pubkey>",
      "issued_at": 1711900200,
      "expires_at": 1711903800,
      "grants": ["macp.mode.task.v1"],
      "binding": { "cnf": "<B-pubkey>" },
      "signature": "<A-sig>"
    }
  },
  "pop_signature": "<base64url — A's sig over sha256(B's pop_nonce)>",
  "pop_nonce_echo": "<B's pop_nonce from MUTUAL_HELLO_ACK>"
}
```

#### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `tct_for_peer` | object | REQUIRED | The TCT A is issuing for B. See §4 for issuance rules. |
| `pop_signature` | string | REQUIRED | `base64url(sign(A_private_key, sha256(B_pop_nonce)))`. Proves A holds the key for its AID. |
| `pop_nonce_echo` | string | REQUIRED | MUST equal B's `pop_nonce` from MUTUAL_HELLO_ACK. |

### 3.4 MUTUAL_COMMIT_ACK

Sent by the target agent (B) to complete the handshake.

#### Payload schema

```json
{
  "tct_for_peer": {
    "tct": {
      "version": "aitp/0.1",
      "jti": "<uuid-v4>",
      "issuer": "aid:pubkey:<B-pubkey>",
      "subject": "aid:pubkey:<A-pubkey>",
      "audience": "aid:pubkey:<A-pubkey>",
      "issued_at": 1711900400,
      "expires_at": 1711904000,
      "grants": ["macp.mode.task.v1"],
      "binding": { "cnf": "<A-pubkey>" },
      "signature": "<B-sig>"
    }
  },
  "pop_signature": "<base64url — B's sig over sha256(A's pop_nonce)>",
  "pop_nonce_echo": "<A's pop_nonce from MUTUAL_HELLO>"
}
```

#### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `tct_for_peer` | object | REQUIRED | The TCT B is issuing for A. |
| `pop_signature` | string | REQUIRED | `base64url(sign(B_private_key, sha256(A_pop_nonce)))`. |
| `pop_nonce_echo` | string | REQUIRED | MUST equal A's `pop_nonce` from MUTUAL_HELLO. |

---

## 4. TCT Issuance Rules

Each agent issues a TCT for its peer. Peer-issued TCTs are the canonical TCT form: `issuer` is a peer agent AID, not a third-party verifier AID.

Consumers of peer-issued TCTs MUST:

- Resolve the issuer's public key from the **peer's Agent Manifest** (RFC-AITP-0003).
- Cache the peer Manifest for the duration of `manifest.expires_at` to avoid re-fetching on every request.

### 4.1 Grant intersection

The issuing agent MUST issue grants that are the intersection of:

1. what the peer's identity allows (based on the issuing agent's local policy for the peer's issuer and subject), AND
2. what the peer requested (`requested_grants` in the handshake messages), AND
3. what the issuing agent's `offered_capabilities` includes (from its own Manifest, RFC-AITP-0003 §3.1).

```
issued_grants = peer_requested_grants
              ∩ identity_policy(peer_identity)
              ∩ self_offered_capabilities
```

The issuing agent MUST NOT grant capabilities it did not offer in its Manifest. The issuing agent MUST NOT grant capabilities the peer did not request.

If the resulting `issued_grants` set is **empty**, the issuing agent MUST NOT issue a TCT and MUST instead respond with `POLICY_VIOLATION`. An empty-grants TCT is forbidden in v0.1: a TCT with no grants is operationally indistinguishable from a proof-of-identity, and AITP separates identity (the Manifest's identity binding + handshake PoP) from authority (the TCT's `grants`). Peers that need an identity-only proof MUST use the Manifest, not a stripped TCT.

### 4.2 Audience binding

Peer-issued TCTs MUST set `audience` to the peer's AID:

```json
"audience": "aid:pubkey:<peer-pubkey>"
```

The peer MUST verify that `audience` matches its own AID when consuming the TCT.

### 4.3 Expiry

Peer-issued TCT `expires_at` MUST NOT exceed the issuing agent's Manifest `expires_at`. The RECOMMENDED default TTL for peer-issued TCTs is **1 hour**.

### 4.4 Proof-of-possession binding

Peer-issued TCTs MUST include `binding.cnf` set to the peer's public key. The `MUTUAL_COMMIT` / `MUTUAL_COMMIT_ACK` PoP signatures ARE the proof-of-possession verification for the handshake itself. Downstream consumers of peer-issued TCTs MAY require additional PoP per RFC-AITP-0005 §6.

---

## 5. Verification Steps

### 5.1 On receiving MUTUAL_HELLO (B verifies A)

The bootstrap order matters. A peer receiving a MUTUAL_HELLO has no
pre-shared key for the sender — the sender's claimed key is *inside* the
inline Manifest, and the Manifest itself must be authenticated before any
other cryptographic operation that depends on it. The numbered steps below
make the order explicit.

**Steps 1–3 are the only unauthenticated operations the peer ever performs
on inbound traffic.** Step 4 is the trust bootstrap — once the Manifest
proof-of-possession verifies, every subsequent step has a trusted public
key to work with.

B MUST:

1. **Parse the envelope unauthenticated.** Validate replay controls
   (`message_id` deduplication, `timestamp` tolerance) per RFC-AITP-0001
   §5.5. These do not require the sender's key.
2. **Parse the payload** as a `MutualHelloPayload`.
3. **Confirm `payload.manifest.aid` equals `envelope.sender.agent_id`.**
   If they differ, reject with `INVALID_ENVELOPE`. This anchors all
   subsequent verification on a single AID.
4. **Verify the Manifest's `proof_of_possession.signature`** using the
   public key encoded in `payload.manifest.aid`. **This is the first
   cryptographic check.** It bootstraps trust in the sender's claimed
   key. If it fails, reject with `MANIFEST_POP_FAILED`.
5. **Verify the Manifest's `signature`** using the same public key. Failure
   ⇒ `MANIFEST_SIGNATURE_INVALID`. Together, steps 4 and 5 prove the
   sender controls the private key matching `manifest.aid`.
6. **Verify the fresh identity proof** in `payload.identity` per
   [RFC-AITP-0002](RFC-AITP-0002-identity.md) — including the `aud`,
   `cnf.jkt`, and (for OIDC) `nonce` requirements (RFC-AITP-0002 §2.2/§2.3).
   The Manifest itself carries only `identity_hint` (no JWT); the verifiable
   proof always lives in `payload.identity` so it can be bound to this
   handshake's `pop_nonce`. Implementations MUST verify that
   `payload.identity.subject` equals `payload.manifest.identity_hint.subject`
   and `payload.identity.type` equals `payload.manifest.identity_hint.type`.
   For OIDC, `payload.identity.issuer` MUST equal
   `payload.manifest.identity_hint.issuer`. Any mismatch ⇒ `IDENTITY_FAILED`.
7. **Verify the envelope signature** using the now-trusted public key
   from `manifest.aid`. Failure ⇒ `INVALID_SIGNATURE`. From this point
   forward, the envelope's contents are authenticated.
8. **Apply policy.** Check that A's identity issuer appears in B's own
   `trust_anchors` (`INCOMPATIBLE_TRUST_ANCHORS` otherwise). Evaluate A's
   `requested_grants` against B's policy and `offered_capabilities` to
   determine what B will grant. Record A's `pop_nonce` for use in
   MUTUAL_COMMIT_ACK. Construct and send MUTUAL_HELLO_ACK.

### 5.2 On receiving MUTUAL_HELLO_ACK (A verifies B)

A applies the same 8-step bootstrap to B's inline Manifest, with one
additional check before step 8:

A MUST:

1. Parse the envelope unauthenticated; validate replay controls.
2. Parse the payload as a `MutualHelloAckPayload`.
3. Confirm `payload.manifest.aid` equals `envelope.sender.agent_id`.
   Failure ⇒ `INVALID_ENVELOPE`.
4. Verify B's Manifest `proof_of_possession.signature`.
5. Verify B's Manifest `signature`.
6. Verify B's identity binding per RFC-AITP-0002 (including `aud` and
   `cnf.jkt`).
7. Verify the envelope signature.
8. **Verify `pop_nonce_echo`** equals A's original `pop_nonce` from
   MUTUAL_HELLO. Failure ⇒ `NONCE_MISMATCH`.
9. Apply policy: check B's identity issuer is in A's `trust_anchors`,
   evaluate B's `requested_grants`, construct `tct_for_peer` (the TCT A
   will issue for B) per §4, compute `pop_signature` over B's `pop_nonce`,
   and send MUTUAL_COMMIT.

### 5.3 On receiving MUTUAL_COMMIT (B finalizes)

Round 2 messages do **not** repeat the full bootstrap. The peer's Manifest
was verified and cached in round 1; its public key is already trusted.

B MUST:

1. Validate the envelope signature (using A's trusted public key from the
   cached Manifest) and replay controls.
2. Verify `pop_nonce_echo` equals B's `pop_nonce` from MUTUAL_HELLO_ACK.
   Failure ⇒ `NONCE_MISMATCH`.
3. Verify `pop_signature`: `verify(A_pubkey, sha256(B_pop_nonce), pop_signature)`.
   Failure ⇒ `POP_VERIFICATION_FAILED`.
4. Verify `tct_for_peer` (the TCT A issued for B):
   - Signature valid under A's AID public key.
   - `subject` equals B's AID.
   - `audience` equals B's AID.
   - `expires_at` is in the future.
   - `grants` are a subset of B's `offered_capabilities`.
   - Every capability in B's own `required_peer_capabilities` (from B's
     Manifest, RFC-AITP-0003 §3.2) is present in `tct_for_peer.grants`.
     Missing required capability ⇒ `INSUFFICIENT_GRANTS`.
5. Construct `tct_for_peer` (the TCT B issues for A) per §4.
6. Compute `pop_signature` over A's `pop_nonce`.
7. Send MUTUAL_COMMIT_ACK.

### 5.4 On receiving MUTUAL_COMMIT_ACK (A finalizes)

Like §5.3, A relies on the cached, already-verified Manifest from round 1.

A MUST:

1. Validate the envelope signature (using B's trusted public key from the
   cached Manifest) and replay controls.
2. Verify `pop_nonce_echo` equals A's `pop_nonce` from MUTUAL_HELLO.
   Failure ⇒ `NONCE_MISMATCH`.
3. Verify `pop_signature`: `verify(B_pubkey, sha256(A_pop_nonce), pop_signature)`.
   Failure ⇒ `POP_VERIFICATION_FAILED`.
4. Verify `tct_for_peer` (the TCT B issued for A):
   - Signature valid under B's AID public key.
   - `subject` equals A's AID.
   - `audience` equals A's AID.
   - `expires_at` is in the future.
   - `grants` are a subset of A's `offered_capabilities`.
5. **Verify peer-capability requirements.** A's own Manifest declares
   `required_peer_capabilities` (RFC-AITP-0003 §3.2). Every capability in
   that list MUST appear in `tct_for_peer.grants` — i.e. B has granted A
   everything A required of its peer for this exchange. Any required
   capability missing ⇒ `INSUFFICIENT_GRANTS`. The converse check happens
   on B's side in §5.3 step 4.
6. Store TCT_A (the TCT from B). Handshake is complete.

---

## 6. Failure Paths

| Scenario | Who fails | Error code |
|---|---|---|
| A's identity from issuer not in B's trust anchors | B | `INCOMPATIBLE_TRUST_ANCHORS` |
| B's identity from issuer not in A's trust anchors | A | `INCOMPATIBLE_TRUST_ANCHORS` |
| A's Manifest signature invalid | B | `MANIFEST_SIGNATURE_INVALID` |
| B's Manifest signature invalid | A | `MANIFEST_SIGNATURE_INVALID` |
| PoP signature verification failed | Either | `POP_VERIFICATION_FAILED` |
| `pop_nonce_echo` mismatch | Either | `NONCE_MISMATCH` |
| Peer TCT `audience` does not match self AID | Either | `AUDIENCE_MISMATCH` |
| Peer TCT grants exceed peer's `offered_capabilities` | Either | `GRANT_OVERFLOW` |
| Grant intersection is empty | Issuing peer | `POLICY_VIOLATION` |
| Received TCT lacks a capability listed in own `required_peer_capabilities` | Either | `INSUFFICIENT_GRANTS` |
| Peer TCT already expired | Either | `TCT_EXPIRED` |
| Envelope replay detected | Either | `REPLAY_DETECTED` |
| Envelope timestamp expired | Either | `TIMESTAMP_EXPIRED` |

On any failure, the failing agent MUST send an error envelope with the appropriate code and MUST discard all state from the failed handshake attempt (nonces, partial TCTs, cached Manifests from the failed session).

---

## 7. State Management

The Mutual Handshake requires the following transient state, retained for at most the timestamp tolerance window (default 300 s) or until the handshake completes or fails:

| State | Owner | Retained until |
|---|---|---|
| Peer's inline Manifest | Both | Handshake complete or failure |
| Own `pop_nonce` | Both | `pop_nonce_echo` verified in next message |
| Peer's `pop_nonce` | Both | PoP signature computed and sent |
| Own `tct_for_peer` (constructed, not yet confirmed) | Both | COMMIT_ACK verified |

After the handshake is complete:

| State | Owner | Retained until |
|---|---|---|
| Peer's TCT (received) | Both | TCT `expires_at` or revocation |
| Peer's Manifest (cached) | Both | Manifest `expires_at` |

Agents MUST NOT persist `pop_nonce` values across restarts. Restarting agents MUST re-initiate any interrupted handshake from scratch.

---

## 8. Handshake Renewal

TCTs expire per `expires_at`. Peers MAY initiate a fresh Mutual Handshake before expiry to renew trust. There is no in-band renewal message in v0.1. Agents MUST NOT use an expired peer TCT. See [`docs/operational-guidance.md`](../docs/operational-guidance.md) for non-normative renewal patterns.

---

## 9. Integration with Multi-Agent Sessions

AITP v0.1 defines bilateral A2A trust only. Multi-agent systems MAY use the bilateral handshake between a coordinator and each participant, but v0.1 does NOT define participant-to-participant trust propagation, session-wide bundles, membership changes, or session-wide revocation. Session Trust Bundle is reserved for [RFC-AITP-0010](RFC-AITP-0010-session-trust-bundle.md).

---

## 10. Transport in v0.1

The Mutual Handshake is delivered as JSON envelopes over HTTPS (RFC-AITP-0001 §8). Each peer's `handshake_endpoint` (advertised in its Manifest) accepts POST requests carrying a single AITP envelope; responses are AITP envelopes carrying either the next handshake message or an `error` envelope.

---

## 11. Security Considerations

### 11.1 Nonce binding across rounds

The `pop_nonce_echo` field in every response binds round 2 to round 1. Without it, an attacker could inject a fabricated MUTUAL_HELLO_ACK referencing different nonces, causing A to sign a PoP for an agent it did not intend to authenticate. Implementations MUST verify nonce echoes before proceeding.

### 11.2 Grant inflation by a malicious peer

A malicious peer could send a MUTUAL_HELLO_ACK claiming to offer capabilities it does not actually hold. The receiving agent issues a TCT based on the peer's claims. This does not harm the receiving agent — it only controls what grants it offers the peer, not what it trusts the peer to do. If the peer presents an over-claimed TCT to a third-party consumer, that consumer's grant enforcement is the defense.

### 11.3 Race condition on Manifest refresh

If Agent B rotates its key between A fetching the Manifest and A initiating the handshake, B's inline Manifest in MUTUAL_HELLO_ACK will carry a newer `published_at`. A MUST accept the newer Manifest (if it passes all verification checks) and discard the cached copy. A MUST NOT fail the handshake solely because the inline Manifest is newer than the cached one.

### 11.4 Denial-of-service on handshake endpoint

The `handshake_endpoint` in the Manifest is a public-facing surface. Implementations MUST apply rate limiting per source AID or IP. The RECOMMENDED default is 10 handshake initiations per minute per source AID.

---

## 12. Non-Goals

- **Multi-agent session bundles.** v0.1 is bilateral only. Participant-to-participant trust propagation, session-wide bundles, membership changes, and session-wide revocation are reserved for [RFC-AITP-0010](RFC-AITP-0010-session-trust-bundle.md).
- **Full mesh trust without a coordinator.** v0.1 does not define a gossip or decentralized trust-propagation mechanism.
- **Continuous identity assurance.** Once a TCT is issued, AITP does not monitor whether the peer's identity remains valid. Renewal (§8) is the mechanism for re-verifying identity at TCT expiry.
- **Revocation push.** JTI revocation is pull-based (RFC-AITP-0008). There is no push notification to a peer when a TCT is revoked mid-session.

---

## 13. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0002 Identity](RFC-AITP-0002-identity.md)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
- [RFC-AITP-0010 Session Trust Bundle](RFC-AITP-0010-session-trust-bundle.md) *(reserved)*
- [RFC 2119 — Key words for use in RFCs](https://datatracker.ietf.org/doc/html/rfc2119)
