# RFC-AITP-0011
# Multi-hop Delegation

**Document:** RFC-AITP-0011
**Version:** 0.1.0-draft.1
**Status:** Draft
**Depends on:** [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md), [RFC-AITP-0006 Single-Hop Delegation](RFC-AITP-0006-delegation.md), [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)

---

> **Status: Draft.** Normative text below resolves the five open questions tracked in earlier "Reserved" revisions of this RFC. Multi-hop delegation is **not** part of v0.1 conformance — v0.1 implementations MUST reject multi-hop tokens with `DELEGATION_MULTIHOP_NOT_SUPPORTED` (RFC-AITP-0006 §4.4). This RFC specifies the format and verification rules so v0.2 implementations have a stable target.

---

## Abstract

[RFC-AITP-0006](RFC-AITP-0006-delegation.md) defines single-hop delegation: A peer-issues to B; B delegates a subset of grants to C; A verifies and peer-issues to C. Multi-hop extends the same model to chains longer than one hop (A → B → C → D → …) by carrying a `chain` of `DelegationStep` records inside the `DelegationToken`.

The design preserves single-hop's stateless verifiability: any peer in the chain can verify the full chain locally using only Manifest-resolved public keys for each hop.

---

## 1. Chain Encoding

The `DelegationToken` (RFC-AITP-0006 §2) gains two OPTIONAL fields, `chain` and `chain_hash`:

```json
{
  "delegation": {
    "delegator": "aid:pubkey:<A>",
    "delegatee": "aid:pubkey:<D>",
    "issued_by": "aid:pubkey:<C>",
    "audience": "aid:pubkey:<A>",
    "scope": ["read_data"],
    "expires_at": 1711903600,
    "cnf": "<D-public-key>",
    "grant_proof": {
      "issuer":          "aid:pubkey:<B>",
      "subject":         "aid:pubkey:<C>",
      "capabilities":    ["read_data"],
      "issued_at":       1711901000,
      "expires_at":      1711903600,
      "source_tct_jti":  "<JTI of the chain[0] step that authorized B→C>",
      "signature":       "<B's signature over the canonical step body>"
    },
    "chain": [
      {
        "issuer":          "aid:pubkey:<A>",
        "subject":         "aid:pubkey:<B>",
        "capabilities":    ["read_data", "write_data"],
        "issued_at":       1711900000,
        "expires_at":      1711903600,
        "source_tct_jti":  "<JTI of A's peer-issued TCT to B>",
        "signature":       "<A's signature on its peer-issued TCT to B (= the source TCT's signature)>"
      }
    ],
    "chain_hash": "<base64url sha256(canonical_json([chain[0].source_tct_jti, ..., chain[n-2].source_tct_jti]))>",
    "signature": "<C-signature>"
  }
}
```

### 1.1 DelegationStep — what each chain entry represents

Each `chain[i]` is a **DelegationStep**: a signed record proving that `chain[i].issuer` granted `chain[i].capabilities` to `chain[i].subject` by `chain[i].expires_at`. The fields are the same as the `grant_proof` shape defined in [RFC-AITP-0006 §3.1](RFC-AITP-0006-delegation.md#3-fields):

| Field | Type | Description |
|---|---|---|
| `issuer` | AID | The delegator at this hop. |
| `subject` | AID | The delegatee at this hop. |
| `capabilities` | array | Capabilities granted at this hop. MUST be a subset of the prior hop's `capabilities`. |
| `issued_at` | integer | Unix timestamp when this step was signed. |
| `expires_at` | integer | Unix timestamp of step expiry. MUST be ≤ the prior hop's `expires_at`. |
| `source_tct_jti` | UUIDv4 | At hop 0: the JTI of the original peer-issued TCT. At hop i>0: a fresh UUIDv4 the issuer assigned when minting this step. Used by `chain_hash` (§5) and per-hop revocation (§6). |
| `signature` | base64url | Signature by `chain[i].issuer`'s key over the canonical JSON of the step body, excluding `signature`. JCS rules per RFC-AITP-0001 §5.4.1. |

A DelegationStep is signed by the issuer's AID-derived key — there is no requirement that the issuer also peer-issue a TCT to themselves before signing. The `signature` field is interpreted as follows:

- **Hop 0 (i.e. `chain[0]`).** The step IS a projection of A's peer-issued TCT to B (the same shape as the `grant_proof` in single-hop, RFC-AITP-0006 §3.1). The `signature` is reused verbatim from that source TCT's signature. The reconstruction recipe in [RFC-AITP-0006 §4.2](RFC-AITP-0006-delegation.md#42-grant-proof-validity-stateless) (table) applies.
- **Hop i > 0.** The step is signed by the prior intermediate's AID-derived key over the canonical JSON of the step body excluding `signature`. There is no separate "source TCT" to reconstruct; the body itself is what was signed.

### 1.2 Worked example — three hops (A → B → C → D)

Concretely, for D presenting a delegation it received from C (which C is allowed to issue because of B's prior delegation to C, which B was allowed to issue because of A's original peer-issued TCT to B):

| Position | Issuer → Subject | Capabilities | Signature key | `signature` body |
|---|---|---|---|---|
| `chain[0]` | A → B | `["read_data", "write_data"]` | A | A's peer-issued TCT body (reused verbatim per RFC-AITP-0006 §3.1) |
| `chain[1]` | B → C | `["read_data"]` | B | Canonical JSON of the step body excluding `signature` |
| `delegation.grant_proof` | C → D's effective scope source (= the most-recent step before D) | `["read_data"]` | C | Canonical JSON of the step body excluding `signature` |
| `delegation.signature` | C signs the outer delegation (selecting D, scope, audience, cnf, expires_at) | n/a | C | Canonical JSON of the delegation body excluding outer `signature` |

D presents this delegation to A. A verifies every step, the chain hash, and C's outer signature, and (if all pass) peer-issues a fresh TCT to D for the requested scope.

| Field | Required | Description |
|---|---|---|
| `chain` | OPTIONAL | Array of DelegationStep records, ordered from oldest hop (chain[0]) to most recent (chain[n-2]). Absent (or empty) for single-hop tokens — this is the v0.1 case. For an n-hop delegation the chain contains the first n-1 steps; the n-th (most recent) step remains in the top-level `grant_proof` field. |
| `chain_hash` | REQUIRED if `chain` is non-empty | `base64url(sha256(canonical_json([chain[0].source_tct_jti, ..., chain[n-2].source_tct_jti])))`. Bound into the outer signature so a hop cannot be removed without invalidating the signature. See §5. |

A delegation token without `chain` (or with `chain == []`) is a single-hop delegation and follows RFC-AITP-0006 verification verbatim. The fields below apply only when `chain` is non-empty.

### 1.3 Relationship to RFC-AITP-0006 §9

[RFC-AITP-0006 §9](RFC-AITP-0006-delegation.md#9-multi-hop-future) requires v0.1 implementations to reject any token whose `grant_proof` is itself a delegation — because in single-hop a `grant_proof` is always a peer-issued TCT projection. Multi-hop relaxes this: when a token also carries a non-empty `chain` per this RFC, `grant_proof` is the most-recent DelegationStep (not necessarily a peer-issued TCT projection) and is verified per §3 below. v0.2 implementations that opt into RFC-AITP-0011 MUST allow the relaxation; v0.1 implementations and v0.2 implementations that opt out MUST reject any token with a non-empty `chain` using `DELEGATION_MULTIHOP_NOT_SUPPORTED` (RFC-AITP-0006 §8).

---

## 2. Hop Limits

Verifiers MUST reject delegation tokens whose total chain length exceeds a configurable `max_delegation_hops`:

```
total_hops = (chain.length) + 1   // +1 for the top-level grant_proof
```

| Setting | Default | Notes |
|---|---|---|
| `max_delegation_hops` | **3** | RECOMMENDED upper bound. Configurable per deployment. |

If `total_hops > max_delegation_hops`, the verifier MUST reject with `DELEGATION_HOP_LIMIT_EXCEEDED`. The default of 3 covers most realistic agent ecosystems (orchestrator → planner → executor) without amplifying verification cost. Deployments that need longer chains MUST opt in explicitly.

---

## 3. Per-Hop Verification

For an n-hop delegation, a verifier MUST verify every hop. Indexing convention for an n-hop token (where `n = chain.length + 1`):

- `chain[0]` is the oldest hop (A → B in the worked example).
- `chain[n-2]` is the second-most-recent (e.g. B → C in a 3-hop chain).
- The top-level `grant_proof` is the most recent hop (e.g. C → ... in a 3-hop chain — i.e., the step that authorized `delegation.issued_by` to issue the outer delegation).

For each hop `i ∈ [0, n-1]` (where `chain[n-1]` is shorthand for the top-level `grant_proof`):

1. **Reconstruct the signed body and verify the signature**, dispatching on hop position:
   - **At hop 0** — the body is a projection of the original peer-issued TCT. Apply the reconstruction recipe in [RFC-AITP-0006 §4.2](RFC-AITP-0006-delegation.md#42-grant-proof-validity-stateless) (table) to produce the reconstructed source TCT body and verify `chain[0].signature` against `chain[0].issuer`'s public key (resolved from `chain[0].issuer`'s Manifest, RFC-AITP-0003).
   - **At hops i > 0 (including the top-level `grant_proof`)** — the body is the DelegationStep itself (§1.1). The verifier produces canonical JSON over the step body excluding `signature` (per RFC 8785 / JCS), hashes with SHA-256, and verifies `signature` against the step's `issuer` public key. There is NO separate source TCT to reconstruct.
2. **Audience continuity** — `chain[i].subject` MUST equal `chain[i+1].issuer` for `i < n-2`. The last chain entry's `chain[n-2].subject` MUST equal `grant_proof.issuer`. The top-level `grant_proof.subject` MUST equal `delegation.issued_by` (same rule as RFC-AITP-0006).
3. **Issuer-of-first-hop matches `delegator`** — `chain[0].issuer` MUST equal `delegation.delegator`. This is what roots the entire chain in A.
4. **Per-hop expiry** — every hop's `expires_at` MUST be in the future, and successor `expires_at` MUST be ≤ predecessor `expires_at`. Expiry is monotonically non-increasing along the chain.
5. **JTI continuity for `chain_hash` (§5)** — `chain[i].source_tct_jti` (for `i ∈ [0, n-2]`) MUST be unique within the chain so the hash collision space cannot be probed by an attacker minting overlapping JTIs.

Failure at any hop MUST result in `DELEGATION_INVALID_GRANT_PROOF`.

---

## 4. Scope Enforcement (Transitive)

For a single-hop delegation, RFC-AITP-0006 §4.3 requires `scope ⊆ grant_proof.capabilities`. For multi-hop, scope subsetting MUST be enforced **transitively** at every hop, not only between adjacent hops:

```
scope ⊆ grant_proof.capabilities
     ⊆ chain[n-2].capabilities
     ⊆ chain[n-3].capabilities
     …
     ⊆ chain[0].capabilities      (= what A originally granted B)
```

Equivalently: every hop's `capabilities` MUST be a subset of the previous hop's `capabilities`, and the outermost `scope` MUST be a subset of the most-recent (top-level) `grant_proof.capabilities`.

A single adjacent-hop check is **not sufficient** — a chain where each adjacent pair satisfies subsetting can still allow scope inflation if intermediate hops re-add capabilities that an earlier hop removed. The verifier MUST check the full transitive chain.

Failure ⇒ `DELEGATION_SCOPE_EXCEEDED`.

---

## 5. Truncation Defense

The outer `delegation.signature` is computed over the canonical JSON of the delegation token excluding `signature`. To bind the chain into the signature so a hop cannot be silently removed, the token includes a `chain_hash` field:

```
chain_hash = base64url(
  sha256(
    canonical_json([
      chain[0].source_tct_jti,
      chain[1].source_tct_jti,
      ...,
      chain[n-2].source_tct_jti
    ])
  )
)
```

The hash is computed over the canonical JSON of an array of strings (the JTIs in chain order). A verifier MUST:

1. Recompute `chain_hash` from the received `chain` array.
2. Verify the recomputed value equals the value in `delegation.chain_hash`.
3. Verify the outer `delegation.signature` (which covers `chain_hash` along with every other delegation field).

Removing a hop changes the JTI list, which changes the hash, which invalidates the outer signature. Truncation is therefore detected by step 2 (mismatch) and step 3 (signature failure) together.

`chain_hash` is REQUIRED whenever `chain` is non-empty. Tokens with `chain` but no `chain_hash`, or with a `chain_hash` that does not match the `chain` contents, MUST be rejected with `DELEGATION_INVALID_SIGNATURE`.

---

## 6. Per-Hop Revocation

For multi-hop, the source-TCT revocation check (RFC-AITP-0006 §4.2.1) MUST be applied at **every** hop. The verifier MUST:

- For each `chain[i]`, look up `chain[i].source_tct_jti` against the deny list of `chain[i].issuer` (resolved via that peer's `ListRevoked` endpoint, RFC-AITP-0008 §1.4).
- Look up `grant_proof.source_tct_jti` against the deny list of `grant_proof.issuer`.

If any of these lookups returns "revoked," the entire delegation MUST be rejected with `DELEGATION_SOURCE_TCT_REVOKED`. A revoked intermediate TCT invalidates every hop downstream of it — there is no partial-validity model.

This is the only stateful verification step in multi-hop. It requires up to n network calls (one per hop) in the worst case; implementations SHOULD cache deny lists per RFC-AITP-0008 §3.2.

---

## 7. Error Codes (additions over RFC-AITP-0006)

| Code | Meaning | Retryable |
|---|---|---|
| `DELEGATION_HOP_LIMIT_EXCEEDED` | `total_hops > max_delegation_hops` | false |
| `DELEGATION_CHAIN_HASH_MISMATCH` | `chain_hash` does not match the `chain` contents | false |

`DELEGATION_INVALID_GRANT_PROOF`, `DELEGATION_SCOPE_EXCEEDED`, `DELEGATION_SOURCE_TCT_REVOKED`, and `DELEGATION_INVALID_SIGNATURE` are reused from RFC-AITP-0006 with semantics extended per-hop.

---

## 8. Conformance Surface

Multi-hop is **opt-in** for v0.2. A v0.1 implementation that opts out MUST reject any delegation token with a non-empty `chain` using `DELEGATION_MULTIHOP_NOT_SUPPORTED`. A v0.2 implementation that opts in MUST:

1. Implement §3 verification for chains up to its configured `max_delegation_hops`.
2. Implement §4 transitive scope checking.
3. Implement §5 chain-hash recomputation and verification.
4. Implement §6 per-hop revocation lookup.

Conformance fixtures for multi-hop live under `schemas/conformance/del-mh-*.json`:

- [`del-mh-001-success.json`](../schemas/conformance/del-mh-001-success.json) — 3-hop happy path (reuses kat-multihop-chain-001 verbatim).
- [`del-mh-002-scope-inflation.json`](../schemas/conformance/del-mh-002-scope-inflation.json) — transitive scope check (every signature valid; chain[1] introduces a capability not in chain[0]).
- [`del-mh-003-chain-hash-mismatch.json`](../schemas/conformance/del-mh-003-chain-hash-mismatch.json) — truncation defense (chain_hash tampered).
- [`del-mh-004-revoked-hop.json`](../schemas/conformance/del-mh-004-revoked-hop.json) — per-hop revocation (chain[1].source_tct_jti is in chain[1].issuer's deny list).

KAT vectors `kat-multihop-chain-001` (per-hop signature reconstruction) and `kat-multihop-truncation-001` (chain_hash reference) live at [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json).

---

## 9. Security Considerations

- **Chain insertion.** Defended by §3 step 3 (audience continuity) and §3 step 2 (per-hop signature). An intermediate peer cannot inject a fabricated hop without the previous hop's private key.
- **Chain truncation.** Defended by §5 (`chain_hash` bound into the outer signature). Removing a hop changes the hash and invalidates the signature.
- **Scope inflation across hops.** Defended by §4 (transitive subsetting). Adjacent-only checks are insufficient and explicitly forbidden.
- **Hop-limit DoS.** Defended by §2 (`max_delegation_hops`, default 3). Without a bound, a malicious chain could force unbounded verification work.
- **Mid-chain revocation.** Defended by §6 (per-hop deny-list check). A revoked intermediate TCT invalidates every downstream hop; the verifier MUST check every hop, not only the most recent.
- **TTL/trust decay.** Required by §3 step 5 (monotonic non-increasing expiry). Each hop's lifetime is bounded by the previous hop's; future RFCs MAY add an explicit trust-decay formula on top of the lifetime constraint.

---

## 10. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)
- [RFC-AITP-0006 Single-Hop Delegation](RFC-AITP-0006-delegation.md)
- [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
