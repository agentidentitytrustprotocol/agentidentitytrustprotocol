# RFC-AITP-0011
# Multi-hop Delegation

**Document:** RFC-AITP-0011
**Version:** 0.2.0-draft
**Status:** Draft
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md), [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md), [RFC-AITP-0006 Single-Hop Delegation](RFC-AITP-0006-delegation.md), [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)

---

> **Status: Draft.** Multi-hop delegation is **not** part of AITP core
> conformance (v0.1 or v0.2) — implementations that do not opt into this
> RFC MUST reject multi-hop tokens with
> `DELEGATION_MULTIHOP_NOT_SUPPORTED` (RFC-AITP-0006 §4, multi-hop
> guard). This revision rewrites the chain mechanics for the `aitp/0.2`
> compact-JWS profile: the v0.1 `DelegationStep` record, its
> reconstruction recipe, and the hop-0 "peer-issued TCT projection"
> dispatch are deleted. This RFC specifies the format and verification
> rules so v0.2 implementations have a stable opt-in target.

---

## Abstract

[RFC-AITP-0006](RFC-AITP-0006-delegation.md) defines single-hop delegation: A peer-issues a TCT and grant voucher to B; B delegates a subset of grants to C; A verifies and peer-issues to C. Multi-hop extends the same model to chains longer than one delegation (A → B → C → D → …) by carrying a `chain` claim inside the final delegation token: an array of **delegation compact JWS strings** (RFC-AITP-0006 §2), one per prior hop, embedded **verbatim**.

There are no `DelegationStep` objects and no byte reconstruction anywhere in the chain. Every hop is an ordinary delegation JWS verified over its transmitted bytes; the first hop's authority comes from the grant voucher (RFC-AITP-0005 §8) embedded in the first delegation JWS, exactly as in single-hop. The design preserves single-hop's stateless verifiability: any peer can verify the full chain locally using only Manifest-resolved public keys for each hop's issuer (plus its own key for the root voucher).

---

## 1. Chain Encoding

A multi-hop delegation token is a delegation compact JWS per [RFC-AITP-0006 §2](RFC-AITP-0006-delegation.md#2-delegation-token) whose claims additionally include `chain` and `chain_hash`:

```json
{
  "ver": "aitp/0.2",
  "iss": "aid:pubkey:ed25519:<C-key>",
  "sub": "aid:pubkey:ed25519:<D-key>",
  "aud": "aid:pubkey:ed25519:<A-key>",
  "scope": ["read_data"],
  "exp": 1711903600,
  "cnf": { "jkt": "<RFC 7638 thumbprint of D's key>" },
  "jti": "<uuid-v4 — this hop's revocation handle, §6>",
  "chain": [
    "<compact JWS string — B's delegation to C, verbatim (carries the voucher)>"
  ],
  "chain_hash": "<base64url(sha256(JCS(array of per-entry SHA-256 digests))) — §5>"
}
```

| Claim | Required | Description |
|---|---|---|
| `chain` | OPTIONAL | Array of delegation compact JWS strings (`typ: aitp-delegation+jwt`), ordered from the oldest hop (`chain[0]`) to the most recent prior hop. Each entry is carried **verbatim** — issuers MUST NOT decode-and-re-encode an entry, and verifiers MUST NOT reconstruct any byte sequence. Absent (or empty) for single-hop tokens — that is the RFC-AITP-0006 case. |
| `chain_hash` | REQUIRED if `chain` is non-empty | Digest-array commitment over the chain (§5). Bound under the outer JWS signature like every other claim. |
| `jti` | REQUIRED on every hop of a chain | Fresh UUID v4 minted by the hop's issuer; the hop's revocation handle (§6). |

A delegation token without `chain` (or with `chain == []`) is a single-hop delegation and follows RFC-AITP-0006 verification verbatim. The rules below apply only when `chain` is non-empty.

### 1.1 What each chain entry is

Each `chain[i]` is a complete delegation compact JWS exactly as its issuer minted and signed it: protected header `{ "alg": <derived from the hop issuer's AID>, "typ": "aitp-delegation+jwt" }` and the claims shape of RFC-AITP-0006 §2 (`ver`, `iss`, `sub`, `aud`, `scope`, `exp`, `cnf`), plus the multi-hop claims this RFC defines. There is no separate per-hop record format. The hop's signature is the JWS signature segment, verified over the transmitted bytes — never over a reconstructed body.

**Exactly one root of authority.** The chain's authority is rooted in the grant voucher A minted alongside B's TCT (RFC-AITP-0005 §8):

- `chain[0]` (the first delegation, B → C) MUST carry the `voucher` claim — A's grant voucher, embedded verbatim per RFC-AITP-0006 §2. This is where the chain's authority bottoms out; there is no "peer-issued TCT projection" hop and no reconstruction of A's TCT.
- Every subsequent hop — `chain[i]` for `i > 0`, and the outer token — MUST NOT carry a `voucher` claim. Its authority is the preceding hop, established by the continuity, scope, and expiry rules of §3–§4. This relaxes, for chain-bearing tokens only, RFC-AITP-0006 §2's rule that `voucher` is REQUIRED.

**Per-hop `jti`.** Every hop of a chain — each `chain[i]` and the outer token — MUST carry a `jti` claim: a fresh UUID v4 the issuer assigned when minting that hop. It is the handle by which that issuer can later revoke the hop (§6), carrying over the v0.1 per-step revocation model. `jti` is not part of the single-hop claims set (RFC-AITP-0006 §2); implementations that opt into this RFC MUST accept an OPTIONAL `jti` on any delegation token, while non-opted-in verifiers will reject `jti`-bearing tokens under the strict-claims rule of RFC-AITP-0001 §5.4.5 — an issuer SHOULD therefore mint `jti` only on delegations intended to be extensible into a chain.

**Nested chain claims (prefix consistency).** A hop token that was itself minted as a multi-hop token (because its issuer extended an existing chain) carries its own `chain` and `chain_hash` claims. Such a token is still embedded verbatim when delegated onward. When a verifier encounters a `chain` claim inside `chain[i]`, that inner array MUST equal `chain[0..i-1]` of the outer token, element-wise by exact string comparison, and the entry's own `chain_hash` MUST recompute (§5) over that prefix. Any inconsistency ⇒ `DELEGATION_INVALID_VOUCHER`. (With the default hop limit of §2, chains never grow long enough for nesting to occur; the rule exists so longer, explicitly configured chains remain well-defined.)

### 1.2 Worked example — three hops (A → B → C → D)

| Hop | Artifact | Signer | Key claims |
|---|---|---|---|
| Root (A → B) | TCT + **grant voucher** (RFC-AITP-0005 §8), minted at handshake time | A | voucher: `iss = A`, `sub = B`, `grants = ["read_data", "write_data"]`, `src_jti` = B's TCT `jti` |
| First delegation (B → C) | Delegation JWS `h1` — becomes `chain[0]` | B | `iss = B`, `sub = C`, `aud = A`, `scope = ["read_data"]`, `exp` ≤ voucher `exp`, `cnf` = C's `jkt`, fresh `jti`, `voucher` = A's voucher verbatim |
| Final delegation (C → D) | Delegation JWS `h2` — the **outer token** D presents | C | `iss = C`, `sub = D`, `aud = A`, `scope ⊆ h1.scope`, `exp ≤ h1.exp`, `cnf` = D's `jkt`, fresh `jti`, `chain = [h1]`, `chain_hash`, **no `voucher`** |

D presents `h2` to A. A verifies every hop's JWS, the voucher inside `chain[0]`, the continuity/scope/expiry rules, and the chain hash, then (if all pass and revocation is clear) peer-issues a fresh TCT to D for the requested scope. Note that the root hop (A → B) appears in the chain only through the voucher embedded in `chain[0]` — it is not a chain entry.

### 1.3 Relationship to RFC-AITP-0006

The `chain` claim is the multi-hop opt-in marker. [RFC-AITP-0006 §4](RFC-AITP-0006-delegation.md#4-verification-rules) (multi-hop guard) requires implementations that have not opted into this RFC to reject any delegation token carrying a `chain` claim with `DELEGATION_MULTIHOP_NOT_SUPPORTED` — a structural rejection before any per-hop processing. Implementations that opt in MUST instead process the token per §2–§6 below, including the §1.1 relaxation under which a chain-bearing token's authority is the chain (terminating in `chain[0]`'s voucher) rather than a directly embedded voucher.

---

## 2. Hop Limits

Verifiers MUST reject delegation tokens whose total chain length exceeds a configurable `max_delegation_hops`:

```
total_hops = chain.length + 2
           // +1 for the root peer-issuance (attested by the voucher in chain[0])
           // +1 for the outer token (the most recent delegation)
```

This counts the same trust steps as v0.1, where the root issuance occupied `chain[0]`: the worked example A → B → C → D is 3 hops.

| Setting | Default | Notes |
|---|---|---|
| `max_delegation_hops` | **3** | RECOMMENDED upper bound. Configurable per deployment. |

If `total_hops > max_delegation_hops`, the verifier MUST reject with `DELEGATION_HOP_LIMIT_EXCEEDED` — before any signature verification, so an attacker cannot force unbounded verification work. The default of 3 covers most realistic agent ecosystems (orchestrator → planner → executor) without amplifying verification cost. Deployments that need longer chains MUST opt in explicitly.

---

## 3. Per-Hop Verification

Let the hops, oldest first, be `H = [chain[0], …, chain[k-1], outer]` (where `k = chain.length`). After the §2 hop-limit check and the §5 chain-hash check, the verifier (A) MUST verify **every** hop. For each hop token `h` in `H`, in order:

1. **Standard JWS verification.** Parse the compact JWS strictly (RFC-AITP-0001 §5.4.5). Enforce header `typ` == `aitp-delegation+jwt` ⇒ else `TOKEN_TYP_MISMATCH`. Derive the sole acceptable `alg` from `h.iss`'s AID and reject any other value, including `none` ⇒ `TOKEN_ALG_MISMATCH`. Verify the signature against `h.iss`'s public key, resolved from that issuer's Manifest (RFC-AITP-0003). Failure ⇒ `DELEGATION_INVALID_SIGNATURE`. No byte sequence is ever reconstructed: the signature is checked over the entry string exactly as carried in the `chain` claim (or, for the outer token, as presented).
2. **Common claims.** `ver` MUST be known. `aud` MUST equal A's own AID — at **every** hop, since the chain is only ever presentable to A ⇒ else `DELEGATION_AUDIENCE_MISMATCH`. `h.iss` MUST NOT equal `h.sub` (no self-delegation at any hop) ⇒ else `DELEGATION_INVALID_SIGNATURE`. `h.cnf.jkt` MUST match the key encoded in `h.sub` (RFC-AITP-0001 §5.4.4). `h.jti` MUST be present and unique among all hops of the chain ⇒ else `DELEGATION_INVALID_VOUCHER`.
3. **Root authority (first hop only).** `chain[0]` MUST carry the `voucher` claim; verify it per RFC-AITP-0006 §4 steps 3–5: header `typ` == `aitp-grant+jwt` (⇒ else `TOKEN_TYP_MISMATCH`), `voucher.iss` == A's own AID and signature valid under A's **own** key, `voucher.sub` == `chain[0].iss` (⇒ else `DELEGATION_INVALID_VOUCHER`), `voucher.exp` in the future and `chain[0].exp ≤ voucher.exp` (⇒ else `DELEGATION_EXPIRED`).
4. **Continuity (every hop after the first).** `voucher` MUST be absent (⇒ else `DELEGATION_INVALID_VOUCHER` — exactly one root of authority, §1.1), and `h.iss` MUST equal the preceding hop's `sub` ⇒ else `DELEGATION_INVALID_VOUCHER`. The delegator-of-record at each hop is exactly the agent the previous hop delegated to; an intermediate cannot splice in a hop it was never granted.
5. **Expiry monotonicity (every hop).** `h.exp` MUST be in the future, and for every hop after the first, `h.exp` MUST be ≤ the preceding hop's `exp` (for the first hop: ≤ `voucher.exp`, step 3). Expiry is monotonically non-increasing along the chain ⇒ else `DELEGATION_EXPIRED`.
6. **Scope subsetting (every hop).** Per §4 ⇒ else `DELEGATION_SCOPE_EXCEEDED`.
7. **Nested chain prefix consistency.** Per §1.1 ⇒ else `DELEGATION_INVALID_VOUCHER`.

After all hops pass, A runs the **proof-of-possession** exchange of RFC-AITP-0006 §4 step 9 against the presenting agent, with the bound key taken from the **outer** token's `sub` AID and checked against the outer `cnf.jkt`. Intermediate hops' `cnf` claims are not PoP-challenged — they bound the key at mint time and are consumed by the continuity checks.

Revocation lookups (§6) run only after every signature check above has passed (RFC-AITP-0008 §3.3 ordering).

Failure of a per-hop structural check not covered by a more specific code above ⇒ `DELEGATION_INVALID_VOUCHER` (the renamed v0.1 `DELEGATION_INVALID_GRANT_PROOF` — that code no longer exists).

---

## 4. Scope Enforcement (Transitive)

For a single-hop delegation, RFC-AITP-0006 §4 step 6 requires `scope ⊆ voucher.grants`. For multi-hop, scope subsetting MUST be enforced at **every adjacent pair** of hops:

```
chain[0].scope ⊆ chain[0].voucher.grants   (= what A originally granted B)
chain[i].scope ⊆ chain[i-1].scope          for every i ∈ [1, k-1]
outer.scope    ⊆ chain[k-1].scope
```

Because `⊆` is transitive, checking every adjacent pair yields the chain-wide invariant `outer.scope ⊆ voucher.grants`: the final delegatee can never hold more than A originally granted B.

Checking only the most recent pair (`outer.scope ⊆ chain[k-1].scope`) is **not sufficient** — an intermediate hop could re-add a capability that an earlier hop removed, and the inflation would go undetected. The verifier MUST evaluate the subset relation at every hop boundary, including the voucher boundary at `chain[0]`.

Failure ⇒ `DELEGATION_SCOPE_EXCEEDED`.

---

## 5. Truncation Defense (`chain_hash`)

The `chain_hash` claim is a commitment to the entire chain, computed over per-entry digests:

```
d_i        = base64url( sha256( ASCII(chain[i]) ) )      // digest of the verbatim compact JWS string
chain_hash = base64url( sha256( JCS( [d_0, d_1, …, d_{k-1}] ) ) )
```

Precisely:

1. For each chain entry, compute SHA-256 over the ASCII bytes of the compact JWS string exactly as carried, and base64url-encode the 32-byte digest (43 characters, unpadded).
2. Form the JSON array of those digest strings, in chain order.
3. Canonicalize the array per [RFC 8785 (JCS)](https://datatracker.ietf.org/doc/html/rfc8785) and compute SHA-256 over the canonical bytes.
4. base64url-encode the result.

The digests are over the chain *strings*, so the commitment covers every hop's full content — header, claims, and signature — not merely an identifier. `chain_hash` is a claim in the outer token's payload and is therefore bound under the final delegator's signature.

A verifier MUST:

1. Recompute `chain_hash` from the received `chain` array.
2. Reject with `DELEGATION_CHAIN_HASH_MISMATCH` if the recomputed value differs from the `chain_hash` claim, or if `chain` is non-empty and `chain_hash` is absent.

Removing, reordering, or substituting any entry changes its digest position in the array, which changes the hash. Truncating the chain (dropping a restrictive hop so a verifier roots the remaining entries differently) is likewise detected. The outer signature already covers the `chain` claim verbatim; `chain_hash` is deliberate defense-in-depth — a single order-sensitive commitment that survives implementations which compare chain arrays carelessly, and a stable identifier for audit logging of a specific chain.

---

## 6. Per-Hop Revocation

For multi-hop, revocation MUST be checked at **every** hop, after all signature checks (RFC-AITP-0008 §3.3). The verifier MUST:

- **Root:** look up `chain[0].voucher.src_jti` in A's **own** deny list — revoking B's source TCT kills the voucher and every chain rooted in it (RFC-AITP-0005 §8, RFC-AITP-0008).
- **Each delegation hop:** for each hop token `h` in `H` (every chain entry and the outer token), look up `h.jti` against the deny list of `h.iss` (resolved via that peer's `ListRevoked` endpoint, RFC-AITP-0008 §1.4). This preserves the v0.1 per-hop revocation model: each delegator can unilaterally kill the hop it issued — and with it everything downstream — by adding that hop's `jti` to its own deny list.

If any lookup returns "revoked," the entire delegation MUST be rejected with `DELEGATION_SOURCE_TCT_REVOKED`. A revoked hop invalidates every hop downstream of it — there is no partial-validity model.

This is the only stateful verification step in multi-hop. It requires up to `total_hops` network calls in the worst case; implementations SHOULD cache deny lists per RFC-AITP-0008 §3.2.

---

## 7. Error Codes (additions over RFC-AITP-0006)

| Code | Meaning | Retryable |
|---|---|---|
| `DELEGATION_HOP_LIMIT_EXCEEDED` | `total_hops > max_delegation_hops` (§2) | false |
| `DELEGATION_CHAIN_HASH_MISMATCH` | `chain_hash` absent or does not match the recomputed digest-array commitment (§5) | false |

Both are Draft codes scoped to this RFC. `TOKEN_TYP_MISMATCH`, `TOKEN_ALG_MISMATCH`, `DELEGATION_INVALID_SIGNATURE`, `DELEGATION_AUDIENCE_MISMATCH`, `DELEGATION_EXPIRED`, `DELEGATION_SCOPE_EXCEEDED`, `DELEGATION_INVALID_VOUCHER`, `DELEGATION_SOURCE_TCT_REVOKED`, and `DELEGATION_POP_FAILED` are reused from RFC-AITP-0006 with semantics extended per-hop (§3). `DELEGATION_INVALID_VOUCHER` is the renamed v0.1 `DELEGATION_INVALID_GRANT_PROOF` and additionally covers chain-structure failures (continuity, voucher placement, `jti` uniqueness, nested-chain consistency).

---

## 8. Conformance Surface

Multi-hop is **opt-in** for v0.2; it is not part of core conformance. An implementation that does not opt in MUST reject any delegation token with a non-empty `chain` using `DELEGATION_MULTIHOP_NOT_SUPPORTED` (RFC-AITP-0006 §4). A v0.2 implementation that opts in MUST:

1. Implement §2 hop limiting and §3 per-hop verification for chains up to its configured `max_delegation_hops`.
2. Implement §4 adjacent-pair scope checking at every hop boundary, including the voucher boundary.
3. Implement §5 chain-hash recomputation and verification.
4. Implement §6 per-hop revocation lookup.

Conformance fixtures for multi-hop live under `schemas/conformance/del-mh-*.json` (Draft, opt-in — runners not opted into RFC-AITP-0011 MUST report SKIP, not FAIL):

- [`del-mh-001-success.json`](../schemas/conformance/del-mh-001-success.json) — 3-hop happy path (reuses kat-multihop-chain-001 verbatim).
- [`del-mh-002-scope-inflation.json`](../schemas/conformance/del-mh-002-scope-inflation.json) — adjacent-pair scope check (every signature valid; the outer token's scope re-adds a capability `chain[0]` did not delegate).
- [`del-mh-003-chain-hash-mismatch.json`](../schemas/conformance/del-mh-003-chain-hash-mismatch.json) — truncation defense (`chain_hash` claim tampered relative to the carried chain).
- [`del-mh-004-revoked-hop.json`](../schemas/conformance/del-mh-004-revoked-hop.json) — per-hop revocation (`chain[0].jti` is in `chain[0]`'s issuer's deny list).

KAT vectors `kat-multihop-chain-001` (fixed-seed chain: pinned compact JWS strings for each hop, plus the expected `chain_hash`) and `kat-multihop-truncation-001` (`chain_hash` reference recomputation) live at [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json). Both vectors are **re-specified for `aitp/0.2`** against the digest-array `chain_hash` form of §5 (the JCS+SHA-256 step now operates on the array of per-entry digests, not on `source_tct_jti` lists); the v0.1 reconstruction-based vectors do not survive.

---

## 9. Security Considerations

- **Chain insertion.** Defended by §3 step 1 (per-hop JWS signature) and §3 step 4 (continuity: each hop's `iss` equals the previous hop's `sub`). An intermediate peer cannot inject a fabricated hop without the previous hop's private key.
- **Chain truncation / reordering.** Defended by §5 (`chain_hash` digest-array commitment, bound under the outer signature) on top of the outer signature's verbatim coverage of the `chain` claim. Removing, reordering, or substituting a hop changes the recomputed hash.
- **Scope inflation across hops.** Defended by §4 (subset check at every adjacent hop boundary, transitively rooting in `voucher.grants`). Checking only the most recent boundary is insufficient and explicitly forbidden.
- **Algorithm and type confusion.** Each hop is independently subject to the Compact JWS profile defenses (RFC-AITP-0001 §5.4.5): AID-pinned `alg` (no `none`, no negotiation) and exact `typ` matching, so a TCT, voucher, or foreign JWT cannot be smuggled in as a chain entry.
- **Hop-limit DoS.** Defended by §2 (`max_delegation_hops`, default 3, enforced before signature verification). Without a bound, a malicious chain could force unbounded verification work.
- **Mid-chain revocation.** Defended by §6 (root `src_jti` plus per-hop `jti` deny-list checks). A revoked hop invalidates every downstream hop; the verifier MUST check every hop, not only the most recent.
- **TTL/trust decay.** Required by §3 step 5 (monotonic non-increasing expiry, rooted in `voucher.exp`). Each hop's lifetime is bounded by the previous hop's; future RFCs MAY add an explicit trust-decay formula on top of the lifetime constraint.
- **Privacy.** As in single-hop (RFC-AITP-0006 §5.4), the voucher inside `chain[0]` discloses B's full grant profile from A to every later participant in the chain and to anyone shown the token.

---

## 10. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)
- [RFC-AITP-0006 Single-Hop Delegation](RFC-AITP-0006-delegation.md)
- [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
- [RFC 7515 — JSON Web Signature](https://datatracker.ietf.org/doc/html/rfc7515)
- [RFC 8785 — JSON Canonicalization Scheme (JCS)](https://datatracker.ietf.org/doc/html/rfc8785)
