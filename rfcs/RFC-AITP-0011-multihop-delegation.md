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

[RFC-AITP-0006](RFC-AITP-0006-delegation.md) defines single-hop delegation: A peer-issues to B; B delegates a subset of grants to C; A verifies and peer-issues to C. Multi-hop extends the same model to chains longer than one hop (A → B → C → D → …) by carrying a `chain` of `GrantProof` records inside the `DelegationToken`.

The design preserves single-hop's stateless verifiability: any peer in the chain can verify the full chain locally using only Manifest-resolved public keys for each hop.

---

## 1. Chain Encoding

The `DelegationToken` (RFC-AITP-0006 §2) gains an OPTIONAL `chain` field:

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
      "...": "C's grant proof, derived from C's source TCT (the one C received as a delegated TCT from A via B)"
    },
    "chain": [
      {
        "...": "GrantProof: A → B (B's source TCT, in the standard grant_proof shape)"
      }
    ],
    "chain_hash": "<base64url sha256(canonical_json([chain[0].source_tct_jti, chain[1].source_tct_jti, ...]))>",
    "signature": "<C-signature>"
  }
}
```

| Field | Required | Description |
|---|---|---|
| `chain` | OPTIONAL | Array of `GrantProof` records, ordered from oldest hop to most recent. Absent (or empty) for single-hop delegations (this is the v0.1 case). For an n-hop delegation the chain contains the first n-1 grant proofs; the n-th (most recent) grant proof remains in the top-level `grant_proof` field. |
| `chain_hash` | REQUIRED if `chain` is present | `base64url(sha256(canonical_json([chain[0].source_tct_jti, ..., chain[n-2].source_tct_jti])))`. Bound into the outer signature so a hop cannot be removed without invalidating the signature. See §5. |

A delegation token without `chain` (or with `chain == []`) is a single-hop delegation and follows RFC-AITP-0006 verification verbatim. The fields below apply only when `chain` is present.

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

For an n-hop delegation, a verifier MUST verify every hop. Indexing convention: `chain[0]` is the oldest hop (A → B), `chain[n-2]` is the second-most-recent (e.g. A → … → C in a 3-hop chain), and the top-level `grant_proof` is the most recent hop (e.g. C's grant proof produced from C's delegated TCT received via B).

For each hop `i ∈ [0, n-1]`:

1. **Reconstruct the source TCT** — using the recipe in [RFC-AITP-0006 §4.2](RFC-AITP-0006-delegation.md#42-grant-proof-validity-stateless) (table). The reconstructed body MUST match what `chain[i].issuer` (or `grant_proof.issuer` for the top hop) signed byte-for-byte.
2. **Verify `chain[i].signature`** under `chain[i].issuer`'s public key (resolved from that peer's Manifest).
3. **Audience continuity** — `chain[i].subject` MUST equal `chain[i+1].issuer` (the subject of one hop is the issuer of the next). For the last `chain` entry, `chain[n-2].subject` MUST equal `grant_proof.issuer`. For the top-level grant_proof, `grant_proof.subject` MUST equal `delegation.issued_by` (same rule as RFC-AITP-0006).
4. **Issuer-of-first-hop matches `delegator`** — `chain[0].issuer` MUST equal `delegation.delegator`. (This is what makes the entire chain root in A.)
5. **Per-hop expiry** — every hop's `expires_at` MUST be in the future, and `chain[i+1].expires_at` MUST be ≤ `chain[i].expires_at`. Expiry is monotonically non-increasing along the chain.

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

Conformance fixtures for multi-hop will live under `schemas/conformance/del-mh-*.json` and follow the placeholder convention defined in [`schemas/conformance/PLACEHOLDERS.md`](../schemas/conformance/PLACEHOLDERS.md).

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
