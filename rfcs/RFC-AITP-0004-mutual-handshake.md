# RFC-AITP-0004
# Mutual Handshake

**Document:** RFC-AITP-0004
**Version:** 0.2.0-draft
**Status:** Community Standards Track (v0.2 Draft)
**Depends on:**
  [RFC-AITP-0001 Core](RFC-AITP-0001-core.md),
  [RFC-AITP-0002 Identity](RFC-AITP-0002-identity.md),
  [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
**Referenced by:** [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)

---

## Abstract

The **Mutual Handshake** is the core agent-to-agent primitive in AITP. Two agents simultaneously verify each other's identity and establish bidirectional trust without requiring a third-party verifier.

At the end of a successful Mutual Handshake, each agent holds a Trust Context Token (TCT) issued by its peer. Each TCT is a compact JWS (RFC-AITP-0005 §1) signed by the issuing peer, audience-bound to the recipient, capability-scoped to what the issuer is willing to grant, and proof-of-possession bound to the recipient's key. The commit messages also carry an OPTIONAL companion **grant voucher** (RFC-AITP-0005 §8), minted by the TCT issuer at TCT issuance time, which is what later makes delegation (RFC-AITP-0006) verifiable.

This RFC defines a four-message protocol over two round trips. There is no central verifier and no shared-verifier "fast path"; AITP v0.2 is strictly peer-to-peer.

---

## 1. Design Principles

The Mutual Handshake is governed by four normative principles. Architectural rationale — including why this protocol uses four messages rather than two — lives in [`docs/architecture.md`](../docs/architecture.md).

1. **Simultaneous presentation.** Both agents present identity in the same round trip. Either agent MAY initiate.
2. **Symmetric trust output.** Both agents issue TCTs for each other. Neither agent is privileged by the protocol structure.
3. **Peer-issued TCTs.** Each agent acts as its own verifier for the peer it is authenticating. The TCT `iss` claim is the authenticating agent's AID. Consumers of peer-issued TCTs validate them against the peer's AID public key (resolved from the peer's Manifest).
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
   |       Voucher_B (optional, by A)   |
   |       PoP_A  (A proves key to B)   |
   |                                    |
   | (B verifies TCT_B, verifies PoP_A, |
   |  signs PoP over A's nonce)         |
   |                                    |
   |<------ MUTUAL_COMMIT_ACK ----------|
   |        TCT_A  (B → A, signed by B) |
   |        Voucher_A (optional, by B)  |
   |        PoP_B  (B proves key to A)  |
   |                                    |
   | (A verifies TCT_A, verifies PoP_B) |
   |                                    |
   |====== bidirectional trust =========|
   |   A holds TCT_A  (from B)          |
   |   B holds TCT_B  (from A)          |
```

The handshake is **four messages over two round trips**. The first round trip exchanges credentials and nonces. The second round trip exchanges the signed TCTs (each with its OPTIONAL companion grant voucher) and proof-of-possession signatures.

---

## 3. Message Definitions

All messages use the standard AITP envelope from RFC-AITP-0001 §5. New `message_type` values: `mutual_hello`, `mutual_hello_ack`, `mutual_commit`, `mutual_commit_ack`.

Handshake envelopes and payloads remain JCS-profile signed (RFC-AITP-0001 §5.4.1). The TCT and grant voucher carried in the commit payloads are compact JWS strings (RFC-AITP-0001 §5.4.5): they are embedded as **opaque JSON strings**, verbatim — the envelope layer never decodes-and-re-encodes them, and the outer JCS signature covers the strings verbatim.

> **PoP signing input (§§3.3, 3.4, 5.3, 5.4).** Throughout this RFC, `sha256(<nonce>)` denotes the SHA-256 hash of the **raw bytes obtained by base64url-decoding the nonce string** — never the ASCII bytes of the base64url form. This matches the convention used by the pinned-key proof input (RFC-AITP-0002 §3.1) and downstream PoP (RFC-AITP-0005 §6.1). The unified rule covering all four PoP sites lives in [RFC-AITP-0001 §5.4.2](RFC-AITP-0001-core.md#542-pop-signing-input-convention). Implementations that hash the base64url string itself are non-conformant.

### 3.1 MUTUAL_HELLO

Sent by the initiating agent (A) to the target agent (B).

#### Envelope

```json
{
  "version": "aitp/0.2",
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
| `identity` | object | REQUIRED | A fresh, handshake-bound identity proof for this exchange. MUST be the same `type` and `subject` as `manifest.identity_hint`. For `oidc`, the JWT MUST include the `pop_nonce` value from this message as the JWT `nonce` claim, binding the proof to this specific handshake and preventing replay of the same JWT in a different session. For `pinned_key`, `identity.public_key` MUST equal `manifest.identity_hint.public_key`. |
| `manifest` | object | REQUIRED | A's Agent Manifest (RFC-AITP-0003), inline. |
| `requested_grants` | array of string | REQUIRED | Capabilities A is requesting from B. |
| `pop_nonce` | string | REQUIRED | Random 128-bit value, encoded as exactly 22 chars of unpadded base64url (RFC-AITP-0001 §5.4). B MUST sign over this in MUTUAL_COMMIT_ACK to prove key possession. |

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
| `identity` | object | REQUIRED | A fresh, handshake-bound identity proof for this exchange. MUST be the same `type` and `subject` as `manifest.identity_hint`. For `oidc`, the JWT MUST include the `pop_nonce` value from this message as the JWT `nonce` claim, binding the proof to this specific handshake and preventing replay of the same JWT in a different session. For `pinned_key`, `identity.public_key` MUST equal `manifest.identity_hint.public_key`. |
| `manifest` | object | REQUIRED | B's Agent Manifest, inline. |
| `requested_grants` | array of string | REQUIRED | Capabilities B is requesting from A. |
| `pop_nonce` | string | REQUIRED | B's nonce. A MUST sign over this in MUTUAL_COMMIT. |
| `pop_nonce_echo` | string | REQUIRED | MUST equal A's `pop_nonce` from MUTUAL_HELLO. Binds round 2 to round 1. |

### 3.3 MUTUAL_COMMIT

Sent by the initiating agent (A) after verifying B's MUTUAL_HELLO_ACK.

#### Payload schema

```json
{
  "tct": "<compact JWS string: aitp-tct+jwt>",
  "grant_voucher": "<compact JWS string: aitp-grant+jwt>",
  "pop_signature": "<base64url — A's sig over sha256(B's pop_nonce)>",
  "pop_nonce_echo": "<B's pop_nonce from MUTUAL_HELLO_ACK>"
}
```

#### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `tct` | string | REQUIRED | The TCT A is issuing for B (RFC-AITP-0005), as an opaque compact JWS string with header `typ` `aitp-tct+jwt`. Embedded verbatim — never decoded-and-re-encoded by the envelope layer. See §4 for issuance rules. |
| `grant_voucher` | string | OPTIONAL | The companion grant voucher (RFC-AITP-0005 §8), minted by A at TCT issuance time, as an opaque compact JWS string with header `typ` `aitp-grant+jwt`. A MAY omit it when its policy forbids B from delegating; without it B cannot delegate (RFC-AITP-0006). Embedded verbatim. |
| `pop_signature` | string | REQUIRED | `base64url(sign(A_private_key, sha256(B_pop_nonce)))`. Proves A holds the key for its AID. |
| `pop_nonce_echo` | string | REQUIRED | MUST equal B's `pop_nonce` from MUTUAL_HELLO_ACK. |

### 3.4 MUTUAL_COMMIT_ACK

Sent by the target agent (B) to complete the handshake.

#### Payload schema

```json
{
  "tct": "<compact JWS string: aitp-tct+jwt>",
  "grant_voucher": "<compact JWS string: aitp-grant+jwt>",
  "pop_signature": "<base64url — B's sig over sha256(A's pop_nonce)>",
  "pop_nonce_echo": "<A's pop_nonce from MUTUAL_HELLO>"
}
```

#### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `tct` | string | REQUIRED | The TCT B is issuing for A (RFC-AITP-0005), as an opaque compact JWS string with header `typ` `aitp-tct+jwt`. Embedded verbatim. |
| `grant_voucher` | string | OPTIONAL | The companion grant voucher (RFC-AITP-0005 §8), minted by B at TCT issuance time, as an opaque compact JWS string with header `typ` `aitp-grant+jwt`. B MAY omit it when its policy forbids A from delegating. Embedded verbatim. |
| `pop_signature` | string | REQUIRED | `base64url(sign(B_private_key, sha256(A_pop_nonce)))`. |
| `pop_nonce_echo` | string | REQUIRED | MUST equal A's `pop_nonce` from MUTUAL_HELLO. |

---

## 4. TCT Issuance Rules

Each agent issues a TCT for its peer. Peer-issued TCTs are the canonical TCT form: `iss` is a peer agent AID, not a third-party verifier AID.

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

If the resulting `issued_grants` set is **empty**, the issuing agent MUST NOT issue a TCT and MUST instead respond with `POLICY_VIOLATION`. An empty-grants TCT is forbidden in v0.2: a TCT with no grants is operationally indistinguishable from a proof-of-identity, and AITP separates identity (the Manifest's identity binding + handshake PoP) from authority (the TCT's `grants`). Peers that need an identity-only proof MUST use the Manifest, not a stripped TCT.

### 4.2 Audience binding

Peer-issued TCTs MUST set `aud` to the peer's AID:

```json
"aud": "aid:pubkey:<peer-pubkey>"
```

The peer MUST verify that `aud` matches its own AID when consuming the TCT.

### 4.3 Expiry

Peer-issued TCT `exp` MUST NOT exceed the issuing agent's Manifest `expires_at`. The RECOMMENDED default TTL for peer-issued TCTs is **1 hour**.

### 4.4 Proof-of-possession binding

Peer-issued TCTs MUST include `cnf` with `jkt` set to the RFC 7638 thumbprint of the peer's public key — the key encoded in the TCT's `sub` AID (RFC-AITP-0005 §3). The `MUTUAL_COMMIT` / `MUTUAL_COMMIT_ACK` PoP signatures ARE the proof-of-possession verification for the handshake itself. Downstream consumers of peer-issued TCTs MAY require additional PoP per RFC-AITP-0005 §6.

### 4.5 Grant voucher issuance

The issuing agent mints the companion grant voucher (RFC-AITP-0005 §8) at TCT issuance time, with the same `iss`, `sub`, `grants`, `iat`, and `exp` as the TCT and `src_jti` equal to the TCT's `jti` (RFC-AITP-0005 §8.2). The voucher is delivered alongside the TCT, in the `grant_voucher` field of the same `MUTUAL_COMMIT` / `MUTUAL_COMMIT_ACK` payload (§§3.3–3.4). An issuing agent MAY omit the voucher when its policy forbids the peer from delegating; the handshake then carries only the TCT, and the peer cannot delegate (RFC-AITP-0006 §3).

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
   `nonce`, and `cnf.jkt` requirements (RFC-AITP-0002 §2.2/§2.3).
   The Manifest itself carries only `identity_hint` (no JWT); the verifiable
   proof always lives in `payload.identity` so it can be bound to this
   handshake's `pop_nonce`. Implementations MUST verify that
   `payload.identity.subject` equals `payload.manifest.identity_hint.subject`
   and `payload.identity.type` equals `payload.manifest.identity_hint.type`.
   For OIDC, `payload.identity.issuer` MUST equal
   `payload.manifest.identity_hint.issuer`. For `pinned_key`,
   `payload.identity.public_key` MUST equal
   `payload.manifest.identity_hint.public_key` AND MUST equal the
   AID-identifier component of `payload.manifest.aid` (the same key
   already authenticated in steps 4–5; this check forecloses substitution
   of an unrelated pinned key into the descriptor). Any mismatch ⇒
   `IDENTITY_FAILED`.
7. **Verify the envelope signature** using the now-trusted public key
   from `manifest.aid`. Failure ⇒ `INVALID_SIGNATURE`. From this point
   forward, the envelope's contents are authenticated.
8. **Apply policy.** Two distinct compatibility checks, each with its
   own error code (cf. RFC-AITP-0003 §5):
   - **Identity type accepted.** A's `identity.type` MUST appear in B's
     own `accepted_identity_types` (default `["oidc"]` when absent).
     Failure ⇒ `INCOMPATIBLE_IDENTITY_TYPE` — not
     `INCOMPATIBLE_TRUST_ANCHORS`. This is the case where, for example,
     A presents `pinned_key` but B accepts only `oidc`.
   - **Trust-anchor overlap** (OIDC only). When `A.identity.type ==
     "oidc"`, A's identity `issuer` MUST appear in B's
     `trust_anchors`. Failure ⇒ `INCOMPATIBLE_TRUST_ANCHORS`. For
     `pinned_key` this check is replaced by the
     `pinned_keys` lookup already performed in step 6.

   After compatibility passes, evaluate A's `requested_grants` against
   B's policy and `offered_capabilities` to determine what B will
   grant. Record A's `pop_nonce` for use in MUTUAL_COMMIT_ACK. Construct
   and send MUTUAL_HELLO_ACK.

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
   evaluate B's `requested_grants`, construct the `tct` A will issue for
   B (and, if A's policy permits B to delegate, the companion
   `grant_voucher`) per §4, compute `pop_signature` over B's `pop_nonce`,
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
4. Verify `tct` (the TCT A issued for B) per the verification order of
   [RFC-AITP-0005 §7.2](RFC-AITP-0005-tct.md#72-verification-order):
   - Parse the compact JWS strictly — exactly three non-empty
     base64url segments (RFC-AITP-0001 §5.4.5).
   - Header `typ` is exactly `aitp-tct+jwt`. Violation ⇒
     `TOKEN_TYP_MISMATCH`.
   - Header `alg` is the sole value derived from A's AID; any other
     value, including `none`, ⇒ `TOKEN_ALG_MISMATCH`.
   - JWS signature valid under A's AID public key.
   - `ver` is `"aitp/0.2"`.
   - `sub` equals B's AID.
   - `aud` equals B's AID.
   - `exp` is in the future.
   - `cnf.jkt` equals the RFC 7638 thumbprint of the key encoded in
     `sub` (RFC-AITP-0005 §3).
   - `tct.exp` ≤ A's Manifest `expires_at` — the
     verifier-side Manifest-expiry bound from
     [RFC-AITP-0005 §10.4](RFC-AITP-0005-tct.md#104-manifest-expiry-bound-conditional).
     B has A's Manifest from round 1 (cached), so this conditional
     check is required at handshake time. Violation ⇒
     `TCT_EXPIRES_AFTER_MANIFEST`.
   - `grants` are a subset of B's `offered_capabilities`.
   - Every capability in B's own `required_peer_capabilities` (from B's
     Manifest, RFC-AITP-0003 §3.2) is present in the TCT's `grants`.
     Missing required capability ⇒ `INSUFFICIENT_GRANTS`.

   If the payload carries `grant_voucher`, B stores the string verbatim
   alongside the TCT for later delegation use (RFC-AITP-0006). B is not
   required to verify the voucher at handshake time — the issuer
   verifies its own voucher during delegation verification
   (RFC-AITP-0005 §8.2, RFC-AITP-0006 §4) — but B MAY check the
   RFC-AITP-0005 §8.2 consistency rules (`iss`, `sub`, `grants`, `iat`,
   `exp` matching the TCT; `src_jti` equal to the TCT's `jti`) before
   relying on it.
5. Construct the `tct` B issues for A (and, per B's policy, the
   companion `grant_voucher`) per §4.
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
4. Verify `tct` (the TCT B issued for A) per the verification order of
   [RFC-AITP-0005 §7.2](RFC-AITP-0005-tct.md#72-verification-order):
   - Parse the compact JWS strictly — exactly three non-empty
     base64url segments (RFC-AITP-0001 §5.4.5).
   - Header `typ` is exactly `aitp-tct+jwt`. Violation ⇒
     `TOKEN_TYP_MISMATCH`.
   - Header `alg` is the sole value derived from B's AID; any other
     value, including `none`, ⇒ `TOKEN_ALG_MISMATCH`.
   - JWS signature valid under B's AID public key.
   - `ver` is `"aitp/0.2"`.
   - `sub` equals A's AID.
   - `aud` equals A's AID.
   - `exp` is in the future.
   - `cnf.jkt` equals the RFC 7638 thumbprint of the key encoded in
     `sub` (RFC-AITP-0005 §3).
   - `tct.exp` ≤ B's Manifest `expires_at` — the
     verifier-side Manifest-expiry bound from
     [RFC-AITP-0005 §10.4](RFC-AITP-0005-tct.md#104-manifest-expiry-bound-conditional).
     A has B's Manifest from round 1 (cached), so this conditional
     check is required at handshake time. Violation ⇒
     `TCT_EXPIRES_AFTER_MANIFEST`.
   - `grants` are a subset of A's `offered_capabilities`.
5. **Verify peer-capability requirements.** A's own Manifest declares
   `required_peer_capabilities` (RFC-AITP-0003 §3.2). Every capability in
   that list MUST appear in the TCT's `grants` — i.e. B has granted A
   everything A required of its peer for this exchange. Any required
   capability missing ⇒ `INSUFFICIENT_GRANTS`. The converse check happens
   on B's side in §5.3 step 4.
6. Store TCT_A (the TCT from B) and, if present, its `grant_voucher`
   string verbatim (same handling as §5.3 step 4). Handshake is
   complete.

---

## 6. Failure Paths

| Scenario | Who fails | Error code |
|---|---|---|
| `payload.manifest.aid ≠ envelope.sender.agent_id` (step §5.1 #3) | Either | `INVALID_ENVELOPE` |
| Manifest PoP signature invalid (step §5.1 #4) | Either | `MANIFEST_POP_FAILED` |
| A's Manifest signature invalid (step §5.1 #5) | B | `MANIFEST_SIGNATURE_INVALID` |
| B's Manifest signature invalid (step §5.2 #5) | A | `MANIFEST_SIGNATURE_INVALID` |
| Identity proof failed or `identity.type` ≠ `manifest.identity_hint.type` (step §5.1 #6) | Either | `IDENTITY_FAILED` |
| Peer's identity `type` not in own `accepted_identity_types` (step §5.1 #8) | Either | `INCOMPATIBLE_IDENTITY_TYPE` |
| Peer's OIDC `issuer` not in own `trust_anchors` (step §5.1 #8, OIDC only) | Either | `INCOMPATIBLE_TRUST_ANCHORS` |
| Envelope signature invalid after trust bootstrap (step §5.1 #7, §5.3 #1, §5.4 #1) | Either | `INVALID_SIGNATURE` |
| PoP signature verification failed (step §5.3 #3, §5.4 #3) | Either | `POP_VERIFICATION_FAILED` |
| `pop_nonce_echo` mismatch (step §5.2 #8, §5.3 #2, §5.4 #2) | Either | `NONCE_MISMATCH` |
| Peer TCT header `typ` is not exactly `aitp-tct+jwt` (step §5.3 #4, §5.4 #4; RFC-AITP-0005 §7.2) | Either | `TOKEN_TYP_MISMATCH` |
| Peer TCT header `alg` is not the sole AID-derived value, including `none` (step §5.3 #4, §5.4 #4; RFC-AITP-0001 §5.4.5) | Either | `TOKEN_ALG_MISMATCH` |
| Peer TCT `aud` does not match self AID | Either | `AUDIENCE_MISMATCH` |
| Peer TCT grants exceed peer's `offered_capabilities` | Either | `GRANT_OVERFLOW` |
| Grant intersection is empty | Issuing peer | `POLICY_VIOLATION` |
| Received TCT lacks a capability listed in own `required_peer_capabilities` | Either | `INSUFFICIENT_GRANTS` |
| Peer TCT already expired | Either | `TCT_EXPIRED` |
| Peer TCT `exp` exceeds issuer's Manifest `expires_at` (step §5.3 #4, §5.4 #4; RFC-AITP-0005 §10.4) | Either | `TCT_EXPIRES_AFTER_MANIFEST` |
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
| Own issued TCT and grant voucher (constructed, not yet confirmed) | Both | COMMIT_ACK verified |

After the handshake is complete:

| State | Owner | Retained until |
|---|---|---|
| Peer's TCT and grant voucher (received) | Both | TCT `exp` or revocation |
| Peer's Manifest (cached) | Both | Manifest `expires_at` |

Agents MUST NOT persist `pop_nonce` values across restarts. Restarting agents MUST re-initiate any interrupted handshake from scratch.

---

## 8. Handshake Renewal

TCTs expire per `exp`. Peers MAY initiate a fresh Mutual Handshake before expiry to renew trust. There is no in-band renewal message in v0.2. Agents MUST NOT use an expired peer TCT. See [`docs/operational-guidance.md`](../docs/operational-guidance.md) for non-normative renewal patterns.

### 8.1 Non-normative: shortened renewal extension

Implementations MAY offer a shortened renewal endpoint as a non-normative
extension. Shortened renewal is NOT part of v0.2 conformance and MUST be
gated behind an explicit feature or configuration opt-in. Peers MUST
advertise support via the `extensions["rfc-aitp-0005.renew_uri"]`
Manifest field (see [`registries/extension-keys.md`](../registries/extension-keys.md))
so other implementations can discover it without assuming its presence.

The path `/aitp/handshake/renew` is used in examples only. It is **NOT
a reserved path** in core v0.2 — implementations MAY mount the
shortened-renewal endpoint at any path, host, or port that is reachable
over HTTPS. Implementations offering shortened renewal MUST advertise
the **actual concrete endpoint** they expose in
`extensions["rfc-aitp-0005.renew_uri"]`; peers that do not find this
extension key in the issuer's Manifest MUST fall back to a fresh Mutual
Handshake (this RFC, §1 onward) for renewal. Peers MUST NOT probe
`/aitp/handshake/renew` directly when the extension is absent — the
absence of the extension key is the discovery signal, not the HTTP
response from a guessed path.

Wire format for the experimental shortened renewal:

- `POST /aitp/handshake/renew` (illustrative path; the actual endpoint
  is whatever the issuer advertises in `extensions["rfc-aitp-0005.renew_uri"]`).
- Request body:
  ```json
  {
    "current_tct": "<compact JWS string: aitp-tct+jwt>",
    "pop_nonce": "<22-char unpadded base64url>",
    "pop_signature": "<86-char unpadded base64url, sign(holder_key, sha256(base64url_decode(pop_nonce)))>"
  }
  ```
- Response: a fresh TCT (compact JWS string, `typ` `aitp-tct+jwt`) with
  a new `jti` and `exp ≤ issuer.manifest.expires_at` — accompanied, per
  issuer policy, by a fresh companion grant voucher
  (RFC-AITP-0005 §8.2).

An expired TCT MUST NOT be used to bootstrap a shortened renewal — the
issuer MUST verify `current_tct.exp > now` before issuing a
replacement. The issuer MUST also re-evaluate its grant policy for the
holder; shortened renewal is not a bypass for revocation, manifest
rotation, or trust-anchor changes.

v0.2 conformance testers MUST NOT require shortened renewal support and
MUST NOT fail implementations that only support full Mutual Handshake
renewal. The eventual standardization of this extension is reserved as
[RFC-AITP-0013 TCT Renewal Extension](RFC-AITP-0013-tct-renewal-extension.md) (Planned).

---

## 9. Integration with Multi-Agent Sessions

AITP v0.2 defines bilateral A2A trust only. Multi-agent systems MAY use the bilateral handshake between a coordinator and each participant, but v0.2 does NOT define participant-to-participant trust propagation, session-wide bundles, membership changes, or session-wide revocation. Session Trust Bundle is reserved for [RFC-AITP-0010](RFC-AITP-0010-session-trust-bundle.md).

---

## 10. Transport in v0.2

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

- **Multi-agent session bundles.** v0.2 is bilateral only. Participant-to-participant trust propagation, session-wide bundles, membership changes, and session-wide revocation are reserved for [RFC-AITP-0010](RFC-AITP-0010-session-trust-bundle.md).
- **Full mesh trust without a coordinator.** v0.2 does not define a gossip or decentralized trust-propagation mechanism.
- **Continuous identity assurance.** Once a TCT is issued, AITP does not monitor whether the peer's identity remains valid. Renewal (§8) is the mechanism for re-verifying identity at TCT expiry.
- **Revocation push.** JTI revocation is pull-based (RFC-AITP-0008). There is no push notification to a peer when a TCT is revoked mid-session.

---

## 13. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0002 Identity](RFC-AITP-0002-identity.md)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)
- [RFC-AITP-0006 Single-Hop Delegation](RFC-AITP-0006-delegation.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
- [RFC-AITP-0010 Session Trust Bundle](RFC-AITP-0010-session-trust-bundle.md) *(Draft, post-v0.2)*
- [RFC 2119 — Key words for use in RFCs](https://datatracker.ietf.org/doc/html/rfc2119)
- [RFC 7515 — JSON Web Signature](https://datatracker.ietf.org/doc/html/rfc7515)
