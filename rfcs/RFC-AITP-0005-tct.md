# RFC-AITP-0005
# Trust Context Token (TCT)

**Document:** RFC-AITP-0005
**Version:** 0.1.0-rc.3
**Status:** Release Candidate
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md), [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)

---

## Abstract

The Trust Context Token (TCT) is the canonical output of AITP. It is a signed, peer-issued capability grant produced by the Mutual Handshake (RFC-AITP-0004). Each side of a successful handshake holds one TCT issued by the other peer.

A TCT answers exactly one question: *what is this peer allowed to do here?*

---

## 1. Schema

```json
{
  "tct": {
    "version": "aitp/0.1",
    "jti": "<uuid-v4>",
    "issuer": "aid:pubkey:<issuing-peer-base64url>",
    "subject": "aid:pubkey:<subject-peer-base64url>",
    "audience": "aid:pubkey:<subject-peer-base64url>",
    "issued_at": 1711900000,
    "expires_at": 1711903600,
    "grants": [
      "macp.mode.task.v1",
      "read_data"
    ],
    "binding": {
      "cnf": "<subject-peer-public-key-base64url>"
    },
    "signature": "<base64url>"
  }
}
```

The canonical schema is [`schemas/json/aitp-tct.schema.json`](../schemas/json/aitp-tct.schema.json).

---

## 2. Required Fields

| Field | Type | Description |
|---|---|---|
| `version` | string | MUST be `"aitp/0.1"` for this RFC. |
| `jti` | string | UUID v4. Unique token ID for revocation. |
| `issuer` | string | AID of the issuing peer. |
| `subject` | string | AID of the agent this TCT was issued for (the subject peer). |
| `audience` | string | AID of the intended consuming peer. MUST equal the subject's AID. |
| `issued_at` | integer | Unix timestamp of issuance. |
| `expires_at` | integer | Unix timestamp of expiry. |
| `grants` | array of string | Capability strings the subject is granted. |
| `signature` | string | base64url signature by the issuing peer. |

## 3. Required PoP Binding (v0.1 peer-issued TCT profile)

| Field | Type | Description |
|---|---|---|
| `binding.cnf` | string | Subject's public key, encoded as the same 43-char unpadded base64url AID-identifier form defined in RFC-AITP-0001 §5.3. Used for proof-of-possession. |

Every v0.1 peer-issued TCT MUST include `binding.cnf`. There is no bearer-TCT profile in v0.1. `binding.cnf` is what distinguishes a peer-issued TCT from a credential that can be freely transferred — it binds the grant to the subject's live private key and enables downstream PoP verification by any consumer without replaying the handshake.

`binding.cnf` MUST equal the AID-identifier component of the TCT's `subject` field (i.e. the bytes after `aid:pubkey:`). Issuers MUST NOT issue TCTs where `cnf` and `subject` reference different keys, and consumers MUST reject such TCTs.

---

## 4. Grants

Grants are opaque strings from the issuer's perspective. The subject peer's domain decides what each string means.

### 4.1 Format

Grants SHOULD follow a dot-namespaced format: `<namespace>.<resource>.<action>`. Examples:

- `macp.mode.task.v1`
- `macp.session.start`
- `read_data`
- `write_data`

### 4.2 Semantics

- Grants are **additive** — the subject has every capability listed.
- Grants have **no implicit hierarchy** — `read_data` does not imply `write_data`.
- Grants are **flat** in v0.1 — no constraints or conditions inside a grant string.
- Grants MUST NOT contain whitespace.

### 4.2.1 Capability ownership

Grant strings are **opaque to AITP**. Their semantics are defined by the namespace owner identified by the grant prefix. For example, `com.example.calendar.read` is defined by the `com.example` namespace, not by the subject and not by AITP. The reserved AITP-managed namespaces (`aitp.*`, `macp.*`) are listed in [`registries/capabilities.md`](../registries/capabilities.md); everything else is owned by the namespace holder.

Issuing peers and consuming peers MUST agree on grant semantics out-of-band — through a published capability schema, a shared specification document, or bilateral agreement. AITP carries the strings without interpreting them; cross-domain interoperability requires that both sides bind the same string to the same operation. A grant string with no agreed meaning is a no-op: a consuming peer that does not recognize the namespace MUST NOT infer behavior from the string and MUST treat it as an unknown capability for enforcement purposes.

### 4.3 Grant intersection

The issuing peer MUST issue grants that are the intersection of:

1. what the subject's identity allows (issuer policy), AND
2. what the subject requested (`requested_grants` in the handshake), AND
3. what the issuing peer's `offered_capabilities` includes (its own Manifest).

The issuing peer MUST NOT grant capabilities the subject did not request, MUST NOT grant capabilities that exceed the subject's identity-based allowance, and MUST NOT grant capabilities outside its own `offered_capabilities`.

---

## 5. Audience

The `audience` field identifies which peer this TCT is valid for.

### 5.1 Format

`audience` MUST be the subject peer's AID:

```
aid:<method>:<identifier>
```

Wildcard audiences (`"*"`) are NOT permitted in v0.1. Every TCT is bound to exactly one peer.

### 5.2 Audience validation

A peer consuming a TCT MUST verify that `audience` matches its own AID. TCTs with a mismatched audience MUST be rejected with `AUDIENCE_MISMATCH`.

---

## 6. Binding (Proof of Possession)

`binding.cnf` is REQUIRED on every v0.1 peer-issued TCT (RFC-AITP-0004 §4.4). It carries the subject's public key so any peer can challenge the holder for proof-of-possession.

Within the Mutual Handshake itself, PoP is **mandatory** and is exchanged via the `pop_signature` / `pop_nonce` fields of `MUTUAL_COMMIT` and `MUTUAL_COMMIT_ACK`.

**Downstream PoP** — when a peer presents a TCT to consume a capability after the handshake — is governed by the issuing peer's policy:

- Consumers **MUST** verify PoP for any grant that the issuing peer's policy marks as requiring it.
- Consumers **SHOULD** verify PoP for all grants by default, unless the deployment environment provides equivalent channel binding (e.g. mTLS with bound client certificates, an authenticated message bus where the underlying channel already proves possession of the AID's key).

The mechanism by which an issuing peer marks per-grant PoP requirements is **deployment-defined in v0.1**: it MAY be encoded in the issuing peer's `offered_capabilities` namespace (e.g. by suffix convention), kept in a side channel (a policy document at a well-known URL), or distributed out-of-band. A normative marking mechanism is reserved for a future RFC.

**RECOMMENDED convention for v0.1.** Until a normative mechanism is standardized, implementations SHOULD use the `#pop_required` suffix to signal a PoP requirement on a grant: `<capability_identifier>#pop_required`. A consumer that recognizes this suffix MUST:

1. Issue a `pop_challenge` before authorizing invocation of the marked grant.
2. Reject the invocation if no valid `pop_response` is received within the challenge's freshness window.

The `tct-007` conformance fixture uses `macp.mode.task.v1#pop_required` to exercise this convention. Deployments using a different marking scheme (`.pop_required`, `.requires_pop`, an out-of-band policy document, etc.) remain conformant for v0.1, provided both peers agree on the scheme out-of-band; the suffix above is RECOMMENDED specifically so that implementations with no prior agreement still interoperate on PoP-marked grants.

Implementations that omit downstream PoP for non-marked grants MUST document that posture and MUST NOT claim conformance for environments that lack equivalent channel binding.

### 6.1 Downstream PoP exchange

The downstream exchange is two messages, both wrapped in the standard envelope (RFC-AITP-0001 §5).

**Step 1 — Challenge.** The consuming peer sends:

```json
{
  "version": "aitp/0.1",
  "message_type": "pop_challenge",
  "message_id": "<uuid-v4>",
  "timestamp": <unix-seconds>,
  "sender": { "agent_id": "<consuming-peer-AID>" },
  "payload": {
    "tct_jti": "<jti of the TCT being challenged>",
    "nonce":   "<random 128-bit base64url>"
  },
  "signature": "<consuming-peer envelope signature>"
}
```

The `tct_jti` field disambiguates which TCT the challenge refers to (a holder may have multiple from the same issuer).

**Step 2 — Response.** The TCT holder replies:

```json
{
  "version": "aitp/0.1",
  "message_type": "pop_response",
  "message_id": "<uuid-v4>",
  "timestamp": <unix-seconds>,
  "sender": { "agent_id": "<holder AID>" },
  "payload": {
    "tct_jti":       "<same jti>",
    "nonce_echo":    "<challenge nonce>",
    "pop_signature": "<base64url(sign(holder_private_key, sha256(nonce_decoded_bytes)))>"
  },
  "signature": "<holder envelope signature>"
}
```

> **Signing input.** `nonce_decoded_bytes` is the raw bytes obtained by base64url-decoding the challenge `nonce` (NOT the base64url ASCII string). This is the same convention used by the pinned-key proof input (RFC-AITP-0002 §3.1). Implementations MUST hash the decoded bytes; hashing the ASCII form of the base64url string is non-conformant.

### 6.2 Verification

The consuming peer MUST:

1. Verify the response envelope signature.
2. Verify `nonce_echo` matches the nonce sent in the challenge.
3. Verify `pop_signature` against `binding.cnf` from the TCT identified by `tct_jti`:
   `verify(binding.cnf, sha256(base64url_decode(nonce)), pop_signature)`.
   The hash input MUST be the raw decoded bytes of the challenge nonce, not the base64url string.
4. Confirm `binding.cnf` corresponds to the public key encoded in the TCT's `subject` AID.

A failure at any step MUST return `POP_RESPONSE_INVALID`. A malformed or stale challenge MUST return `POP_CHALLENGE_INVALID`. Replay protection on `pop_challenge` follows RFC-AITP-0001 §5.5; nonces from an expired challenge MUST NOT be accepted.

> **Conformance note.** An AITP v0.1 implementation MUST implement the PoP exchange mechanics — it MUST be capable of issuing `pop_challenge` envelopes, producing `pop_response` envelopes, and verifying both ends. Whether PoP is *enforced* for any specific grant depends on the issuing peer's policy annotation for that grant (the deployment-defined marking mechanism described in §6). Implementations MUST expose a configuration surface to enable PoP enforcement **per grant**, so that the issuing peer's policy annotations can be honored without code changes. **An implementation that silently skips PoP regardless of the issuing peer's policy — including for grants the issuer has marked as requiring PoP — is non-conformant.** This is true even if the deployment claims equivalent channel binding: equivalent channel binding may justify omitting PoP for non-marked grants (the SHOULD in §6 above), but a marked-by-issuer requirement is a MUST per §6 and cannot be silently dropped at the consumer side.
>
> Implementations MUST also document their default PoP enforcement posture (enforce-for-marked-only, enforce-for-all, mTLS-equivalent-channel-binding, etc.) so operators can audit the configuration against their threat model. Claiming AITP v0.1 conformance while silently skipping PoP for grants the issuing peer has marked as requiring it is non-conformant — the implementation has the capability but is operating outside the MUST baseline of §6.
>
> The conformance fixture [`tct-006-pop-challenge-response.json`](../schemas/conformance/tct-006-pop-challenge-response.json) verifies the implementation can produce and verify a PoP exchange end-to-end. The fixture [`tct-007-pop-enforcement-required.json`](../schemas/conformance/tct-007-pop-enforcement-required.json) verifies that a grant marked as requiring PoP cannot be consumed without a valid `pop_response` — implementations that allow capability invocation against a PoP-required grant in the absence of a valid response MUST fail this fixture.

### 6.3 Where this exchange happens

Downstream PoP is **transport-flexible**. It can be carried in:

- HTTP request/response bodies (JSON envelopes);
- HTTP headers carrying base64url-encoded JSON envelopes (`x-aitp-pop-challenge` / `x-aitp-pop-response`);
- any other transport that preserves the envelope's integrity, provided the AITP envelope round-trips through the transport unchanged and signature verification uses the canonical JSON form (RFC-AITP-0001 §5.4.1).

This RFC defines the message types and their payloads; transport binding is deployment-defined.

---

## 7. TCT Signature

### 7.1 What is signed

```
sig_input = sha256(canonical_json(tct_without_signature))
signature = base64url(sign(issuer_private_key, sig_input))
```

Canonical JSON MUST be produced per [RFC 8785 (JCS)](https://datatracker.ietf.org/doc/html/rfc8785). See [RFC-AITP-0001 §5.4](RFC-AITP-0001-core.md#54-signature) for the unified canonicalization and base64url encoding rules. A worked example (`kat-tct-001`) showing the canonical bytes and SHA-256 digest of a fixed TCT body lives at [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json); implementations MUST reproduce it byte-for-byte.

### 7.2 Issuer key resolution

The issuer's public key is resolved from the issuer's Agent Manifest (RFC-AITP-0003). A peer that has cached the issuer's Manifest does not need additional configuration to verify peer-issued TCTs.

There is no separate `trust_anchors` lookup for peer-issued TCTs. The chain of trust is:

```
Identity issuer (e.g. OIDC provider, trusted by the consuming peer)
       │
       │ vouches for
       ▼
Issuing peer's identity binding (in the issuing peer's Manifest)
       │
       │ proven by
       ▼
Issuing peer's signature on its Manifest
       │
       │ which exposes
       ▼
Issuing peer's public key (in `manifest.aid`)
       │
       │ which signs
       ▼
The peer-issued TCT
```

If a peer-issued TCT cannot be traced to an issuer whose identity sits behind a trusted anchor, it MUST be rejected.

---

## 8. Lifecycle

```
Issued → Active → Expired
                         ↑
         Revoked ────────┘ (via JTI deny list)
```

- TCTs MUST NOT be used after `expires_at`.
- TCTs MAY be revoked before `expires_at` via the issuing peer's JTI deny list (see [RFC-AITP-0008](RFC-AITP-0008-revocation.md)).

### 8.1 Recommended TTLs

| Use case | Recommended TTL |
|---|---|
| Short interaction | 1 hour |
| Standard task | 8 hours |
| Long-running collaboration | 24 hours |

Peer-issued TCT `expires_at` MUST NOT exceed the issuing peer's Manifest `expires_at`. (See RFC-AITP-0004 §4.3.)

---

## 9. Consumer Rules

### 9.1 MUST

1. Verify the TCT signature against the issuing peer's public key (resolved from the issuing peer's Manifest).
2. Confirm `audience` matches own AID.
3. Confirm `expires_at` is in the future.
4. Enforce `grants` — deny any operation not in the grant list.

### 9.2 MUST NOT

- Recompute trust from the underlying identity proof.
- Accept TCTs with an unknown `version`.
- Modify or re-sign TCTs.
- Accept TCTs whose `audience` is not own AID.

### 9.3 SHOULD

- Verify proof-of-possession per the issuing peer's per-grant policy (§6). Consumers that omit downstream PoP MUST NOT claim conformance for environments lacking equivalent channel binding.
- Check revocation status by querying the issuer's `ListRevoked` endpoint.

### 9.4 Manifest expiry bound (conditional)

If the issuing peer's Manifest is available — from the handshake payload or a local cache — the consumer MUST verify:

```
tct.expires_at ≤ issuer_manifest.expires_at
```

A TCT that violates this bound MUST be rejected with `TCT_EXPIRES_AFTER_MANIFEST`. A peer-issued TCT cannot outlive the Manifest credential that authenticates its issuer's key; RFC-AITP-0004 §4.3 constrains the issuer not to mint such a TCT, and this rule is the verifier-side mirror of that constraint.

This check MAY be skipped when the issuer Manifest is unavailable — verifiers are NOT required to fetch the Manifest solely to perform it. The §9.1 expiry check (`expires_at` in the future) still applies unconditionally.

---

## 10. Peer-Issued TCT Verification API

Each agent that issues TCTs MUST expose three HTTPS endpoints for peers to verify and manage revocation of its TCTs:

| Operation | Method | Description |
|---|---|---|
| `Verify` | POST | Convenience verification — consuming peer can verify locally using only the issuing peer's Manifest key, but MAY call this for a freshness check. |
| `Revoke` | POST | Admin-only; adds a `jti` to the issuing peer's deny list. |
| `ListRevoked` | GET | Returns the issuing peer's signed revocation snapshot (RFC-AITP-0008 §1.5). |

Concrete URL paths are deployment-defined. The Manifest MAY advertise the verify and revocation endpoints in `extensions` (RFC-AITP-0012); v0.1 does not normatively pin those advertisement fields.

---

## 11. Security Considerations

- A TCT is portable — anyone holding it can present it. PoP via `binding.cnf` is the primary defense against TCT theft.
- Consuming peers MUST treat the TCT signature as the sole authority. The TCT is self-contained; there is no out-of-band lookup that "augments" trust.
- Recommended TTLs balance availability against compromise blast radius. See [RFC-AITP-0009](RFC-AITP-0009-security.md).
- Wildcard audiences are forbidden in v0.1 to prevent cross-peer confusion attacks.

---

## 12. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
