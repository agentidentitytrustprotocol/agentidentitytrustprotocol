# RFC-AITP-0006
# Single-Hop Delegation

**Document:** RFC-AITP-0006
**Version:** 0.1.0-rc.3
**Status:** Release Candidate
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md), [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)

---

## Abstract

Delegation lets an agent (B) that holds a TCT from an issuing peer (A) grant a subset of its capabilities to a third agent (C). v0.1 supports **single-hop delegation only**. Multi-hop chains are reserved for [RFC-AITP-0011](RFC-AITP-0011-multihop-delegation.md).

---

## 1. Trust Propagation Model

```
A (issuing peer)
│
│ peer-issues TCT to B with grants: ["read_data", "write_data"]
▼
B (delegator)
│
│ issues Delegation Token to C with scope: ["read_data"]
▼
C (delegatee)
│
│ presents Delegation Token + B's original grant proof to A
▼
A verifies → peer-issues TCT for C with grants: ["read_data"]
```

**Key invariant:** C can never receive more than B was originally granted.

---

## 2. Delegation Token Schema

```json
{
  "delegation": {
    "delegator": "aid:pubkey:<A-pubkey>",
    "delegatee": "aid:pubkey:<C-pubkey>",
    "issued_by": "aid:pubkey:<B-pubkey>",
    "audience": "aid:pubkey:<A-pubkey>",
    "scope": ["read_data"],
    "expires_at": 1711903600,
    "cnf": "<C-public-key-base64url>",
    "grant_proof": {
      "issuer": "aid:pubkey:<A-pubkey>",
      "subject": "aid:pubkey:<B-pubkey>",
      "capabilities": ["read_data", "write_data"],
      "issued_at": 1711900000,
      "expires_at": 1711907200,
      "source_tct_jti": "<jti of A's TCT to B>",
      "signature": "<A-signature>"
    },
    "signature": "<B-signature>"
  }
}
```

The canonical schema is [`schemas/json/aitp-delegation.schema.json`](../schemas/json/aitp-delegation.schema.json).

**Why `grant_proof` is not the full TCT.** A TCT contains all grants the issuer gave to B, which may be a superset of what B is delegating. Embedding the full TCT would expose B's complete capability profile to C and to any peer that inspects the delegation token. The minimized `grant_proof` contains only the fields needed for scope-subset verification and to reconstruct A's signing input (`issuer`, `subject`, `capabilities`, `issued_at`, `expires_at`, `source_tct_jti`, `signature`), which limits information disclosure while preserving stateless verifiability.

---

## 3. Fields

### 3.1 Issuance flow

When B receives a TCT from A in `MUTUAL_COMMIT_ACK`, B MAY use that TCT directly to issue delegation tokens to other agents. The `grant_proof` B embeds in the delegation token is constructed from B's held TCT:

| `grant_proof` field | Source from B's TCT |
|---|---|
| `issuer` | `tct.issuer` |
| `subject` | `tct.subject` |
| `capabilities` | `tct.grants` |
| `issued_at` | `tct.issued_at` |
| `expires_at` | `tct.expires_at` |
| `source_tct_jti` | `tct.jti` |
| `signature` | `tct.signature` |

No separate issuance flow is required — every TCT is a valid `grant_proof` source. Because `grant_proof.signature` is reused verbatim from the source TCT's signature, A's original signature continues to authenticate the grant without re-signing. B's outer `delegation.signature` covers the entire delegation token (excluding the outer `signature` field itself), so the per-delegation fields B chose (`scope`, `delegatee`, `cnf`, `expires_at`, `audience`, `delegator`, `issued_by`) are bound to the embedded `grant_proof` and cannot be substituted independently.

> **Why `issued_at` is carried explicitly.** Earlier drafts allowed verifiers to reconstruct `issued_at` as `expires_at − default_TTL` (e.g. 3600 s). That works only when A used the default TTL; tokens minted with non-default TTL fail cross-implementation verification because A's signature covers `tct.issued_at` byte-exactly. v0.1 carries `issued_at` directly so the `grant_proof` byte sequence A signed can be reconstructed without guessing the TTL.



| Field | Type | Required | Description |
|---|---|---|---|
| `delegator` | string | REQUIRED | AID of the original issuing peer (A). |
| `delegatee` | string | REQUIRED | AID of the agent receiving delegation (C). |
| `issued_by` | string | REQUIRED | AID of the agent issuing this delegation (B). |
| `audience` | string | REQUIRED | MUST equal A's AID — audience binding. |
| `scope` | array of string | REQUIRED | Capabilities delegated to C. |
| `expires_at` | integer | REQUIRED | MUST be ≤ `grant_proof.expires_at`. |
| `cnf` | string | REQUIRED | C's public key for proof-of-possession. |
| `grant_proof` | object | REQUIRED | A's original signed grant to B (constructed from B's source TCT — see §3.1). |
| `grant_proof.issued_at` | integer | REQUIRED | Unix seconds; copied verbatim from the source TCT's `issued_at`. Required so the source TCT's signing input can be reconstructed byte-for-byte without guessing the issuer's chosen TTL. |
| `grant_proof.source_tct_jti` | string | REQUIRED | The `jti` of A's original TCT to B. Used for revocation lookup against A's deny list. If the source TCT has been revoked, all derived delegation tokens MUST be rejected. |
| `grant_proof.signature` | string | REQUIRED | A's signature over the source TCT (reused verbatim). |
| `signature` | string | REQUIRED | B's signature over the delegation token. |

---

## 4. Verification Rules

When C presents a delegation token to A, A MUST verify all of the following:

### 4.1 Structural validity

1. `audience` MUST equal A's own AID. Mismatch ⇒ `DELEGATION_AUDIENCE_MISMATCH`.
2. `delegator` MUST equal A's own AID. Mismatch ⇒ `DELEGATION_INVALID_GRANT_PROOF` (the token is not addressed to this issuer).
3. `expires_at` MUST be in the future AND `delegation.expires_at` MUST be ≤ `grant_proof.expires_at` (a delegated grant cannot outlive the source TCT). Failure ⇒ `DELEGATION_EXPIRED`.

### 4.2 Grant-proof validity (stateless)

4. `grant_proof.issuer` MUST equal A's own AID. Mismatch ⇒ `DELEGATION_INVALID_GRANT_PROOF`.
5. Verify `grant_proof.signature` against A's own public key. The signature input is the canonical JSON of the **reconstructed source TCT body**, with the following fields. Failure ⇒ `DELEGATION_INVALID_GRANT_PROOF`.

   | Reconstructed TCT field | Source |
   |---|---|
   | `version` | constant `"aitp/0.1"` (the only TCT version in v0.1; reject if the source TCT was minted under a future version this verifier does not support) |
   | `jti` | `grant_proof.source_tct_jti` |
   | `issuer` | `grant_proof.issuer` |
   | `subject` | `grant_proof.subject` |
   | `audience` | `grant_proof.subject` (peer-issued TCTs always set `audience = subject` per RFC-AITP-0005 §5.1) |
   | `issued_at` | `grant_proof.issued_at` (carried verbatim per §3.1; reconstructing as `expires_at − default_TTL` is not permitted in v0.1) |
   | `expires_at` | `grant_proof.expires_at` |
   | `grants` | `grant_proof.capabilities` |
   | `binding.cnf` | the 43-char AID-identifier component of `grant_proof.subject` (peer-issued TCTs always bind `cnf` to the subject's public key per RFC-AITP-0004 §4.4) |

   The verifier produces canonical JSON over this reconstructed object excluding the `signature` field per RFC 8785 (JCS), hashes with SHA-256, and verifies `grant_proof.signature` under A's public key. The reconstructed bytes MUST match the bytes A signed when issuing the original TCT; any divergence (extra fields, different encoding) MUST cause verification to fail.

6. `grant_proof.subject` MUST equal `delegation.issued_by`. Mismatch ⇒ `DELEGATION_INVALID_GRANT_PROOF` — without this check, B could attach C's grant proof and claim to be delegating C's authority.
7. `grant_proof.expires_at` MUST be in the future. Failure ⇒ `DELEGATION_EXPIRED`.

### 4.2.1 Source TCT revocation check

8. The verifier MUST look up `grant_proof.source_tct_jti` in its own (or a fresh fetched) deny list for the issuing peer. If the source TCT has been revoked, the delegation token MUST be rejected with `DELEGATION_SOURCE_TCT_REVOKED`. This is the only stateful check in delegation verification; it requires a revocation lookup, not a full session lookup.

### 4.3 Scope constraint

9. Every capability in `scope` MUST appear in `grant_proof.capabilities`:

   ```
   scope ⊆ grant_proof.capabilities
   ```

   Any delegation token where `scope` contains a capability not in `grant_proof.capabilities` MUST be rejected with `DELEGATION_SCOPE_EXCEEDED`.

### 4.4 Chain limits

10. `issued_by` MUST NOT equal `delegatee` (self-delegation is rejected). Failure ⇒ `DELEGATION_INVALID_SIGNATURE`.
11. No chain validation is required — only single-hop is supported. Implementations MUST reject delegation tokens where `issued_by` is itself a delegatee of another delegation (i.e. where the `grant_proof` is not a direct peer-issued TCT from A to B); only direct peer-issued grants from A to B are valid as `grant_proof`. Failure ⇒ `DELEGATION_MULTIHOP_NOT_SUPPORTED`.

### 4.5 Proof of possession

12. Verify that the presenting agent holds the private key matching `cnf` by running the downstream PoP exchange defined in [RFC-AITP-0005 §6.1](RFC-AITP-0005-tct.md#61-downstream-pop-exchange) against C, with `binding.cnf` taken from `delegation.cnf` (rather than from a TCT). The verifier MUST issue a fresh `pop_challenge` with a per-verification 128-bit nonce and verify C's `pop_response` per RFC-AITP-0005 §6.2. PoP failure ⇒ `DELEGATION_POP_FAILED`. Implementations MAY skip the exchange only when an equivalent channel binding to C's key is already in place (e.g. mTLS with a client certificate matching `cnf`); they MUST document that posture.

### 4.6 Issuer signature

13. Verify `signature` against B's public key (resolved from `issued_by` AID via B's Manifest, RFC-AITP-0003). Failure ⇒ `DELEGATION_INVALID_SIGNATURE`.

---

## 5. Security Invariants

### 5.1 Audience binding

The `audience` field MUST equal the delegator's AID (A). A delegation token presented to any other peer MUST be rejected. This prevents C from using B's delegation token at a different peer (D).

### 5.2 Non-transferability

A delegation token is bound to a specific `audience`, a specific `delegatee`, and a specific `cnf`. None of these bindings can be changed without invalidating B's signature.

### 5.3 Scope cannot exceed original grant

Scope is verified against the grant proof, which is signed by A. B cannot forge a grant proof claiming more capabilities than A originally peer-issued.

---

## 6. Delegation Token Signature

B signs the delegation token (excluding `signature`) using the same canonical serialization as the TCT:

```
sig_input  = sha256(canonical_json(delegation_without_signature))
signature  = base64url(sign(B_private_key, sig_input))
```

Canonical JSON MUST be produced per [RFC 8785 (JCS)](https://datatracker.ietf.org/doc/html/rfc8785). See [RFC-AITP-0001 §5.4](RFC-AITP-0001-core.md#54-signature) for the unified canonicalization and base64url encoding rules. A worked example (`kat-delegation-001`) showing the canonical bytes and SHA-256 digest of a fixed delegation token body lives at [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json); implementations MUST reproduce it byte-for-byte.

The same JCS rule applies to `grant_proof` when A originally signs it: A produces canonical JSON over the `grant_proof` object excluding its `signature` field, hashes with SHA-256, and signs with A's private key.

---

## 7. TCT Issuance for Delegated Peers

After verifying the delegation token, A issues a TCT for C with:

- `subject = C's AID`
- `audience = C's AID`
- `grants = scope ∩ A's policy for delegated peers`
- `expires_at ≤ delegation.expires_at`

A MAY reduce the grants or TTL based on local policy. A MUST NOT expand them.

---

## 8. Verification API

Each issuing peer exposes a delegation-verification endpoint over HTTPS. The endpoint accepts a JSON envelope containing the delegation token, the calling agent's AID, and the delegatee's public key (for PoP); it returns either a fresh peer-issued TCT for the delegatee or a `DelegationError`.

Defined error codes:

| Code | Meaning |
|---|---|
| `DELEGATION_AUDIENCE_MISMATCH` | `audience ≠ issuer_aid` |
| `DELEGATION_SCOPE_EXCEEDED` | `scope ⊄ grant_proof.capabilities` |
| `DELEGATION_INVALID_GRANT_PROOF` | `grant_proof.signature` invalid, or `grant_proof.subject ≠ issued_by` |
| `DELEGATION_SOURCE_TCT_REVOKED` | `grant_proof.source_tct_jti` is in the issuing peer's deny list |
| `DELEGATION_INVALID_SIGNATURE` | `delegation.signature` invalid |
| `DELEGATION_EXPIRED` | Token or grant proof expired |
| `DELEGATION_POP_FAILED` | Proof-of-possession failed |
| `DELEGATION_MULTIHOP_NOT_SUPPORTED` | Multi-hop attempt detected |

---

## 9. Multi-hop (Future)

Multi-hop delegation (A → B → C → D) is specified in [RFC-AITP-0011](RFC-AITP-0011-multihop-delegation.md) (Draft; not part of v0.1 conformance). RFC-AITP-0011 covers:

- chain format and `DelegationStep` per-entry shape
- per-hop signature verification (with dispatch between hop 0 — peer-issued TCT projection — and hops i > 0 — intermediate-signed steps)
- hop limits (default `max_delegation_hops = 3`)
- defense against chain insertion (audience continuity), truncation (`chain_hash`), and scope inflation (transitive subsetting)
- per-hop revocation (deny-list lookup at every hop's issuer)

**v0.1 conformance.** Until an implementation explicitly opts into RFC-AITP-0011, it MUST reject any token whose `grant_proof` is itself a delegation rather than a direct peer-issued grant, AND it MUST reject any token carrying a non-empty `chain` field with `DELEGATION_MULTIHOP_NOT_SUPPORTED` (the `chain` field is RFC-AITP-0011's opt-in marker).

**v0.2-and-up carve-out.** Implementations that opt into RFC-AITP-0011 follow that RFC's verification rules instead. In a multi-hop token (with non-empty `chain`), the top-level `grant_proof` is permitted to be a DelegationStep rather than a peer-issued TCT projection — see RFC-AITP-0011 §1.3.

---

## 10. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
- [RFC-AITP-0011 Multi-hop Delegation](RFC-AITP-0011-multihop-delegation.md) *(Draft, post-v0.1)*
