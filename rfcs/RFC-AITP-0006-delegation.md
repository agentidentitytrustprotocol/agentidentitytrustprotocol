# RFC-AITP-0006
# Single-Hop Delegation

**Document:** RFC-AITP-0006
**Version:** 0.2.0-draft
**Status:** Community Standards Track (v0.2 Draft)
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md), [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)

---

## Abstract

Delegation lets an agent (B) that holds a TCT from an issuing peer (A) grant a subset of its capabilities to a third agent (C). This RFC supports **single-hop delegation only**. Multi-hop chains are reserved for [RFC-AITP-0011](RFC-AITP-0011-multihop-delegation.md).

In `aitp/0.2` the delegation token is a **compact JWS** (RFC-AITP-0001 §5.4.5) signed by the delegating agent, which embeds — verbatim, as an opaque string — the **grant voucher** the issuing peer minted alongside B's TCT (RFC-AITP-0005 §8). No step of issuance or verification reconstructs any byte sequence: every signature is checked over the exact transmitted bytes.

---

## 1. Trust Propagation Model

```
A (issuing peer)
│
│ peer-issues TCT + grant voucher to B   grants: ["read_data", "write_data"]
▼
B (delegator)
│
│ issues Delegation JWS to C             scope: ["read_data"]
│ (embeds A's voucher verbatim)
▼
C (delegatee)
│
│ presents the Delegation JWS to A
▼
A verifies → peer-issues TCT for C with grants: ["read_data"]
```

**Key invariant:** C can never receive more than B was originally granted.

---

## 2. Delegation Token

A delegation token is a compact JWS with protected header (exactly two parameters — RFC-AITP-0001 §5.4.5):

```json
{ "alg": "<derived from B's AID>", "typ": "aitp-delegation+jwt" }
```

and decoded claims:

```json
{
  "ver": "aitp/0.2",
  "iss": "aid:pubkey:ed25519:<B-key>",
  "sub": "aid:pubkey:ed25519:<C-key>",
  "aud": "aid:pubkey:ed25519:<A-key>",
  "scope": ["read_data"],
  "exp": 1711903600,
  "cnf": { "jkt": "<RFC 7638 thumbprint of C's key>" },
  "voucher": "<compact JWS string — A's grant voucher, verbatim>"
}
```

| Claim | Type | Required | Description |
|---|---|---|---|
| `ver` | string | REQUIRED | MUST be `"aitp/0.2"`. |
| `iss` | string | REQUIRED | AID of the agent issuing this delegation (B, the delegator-of-record). The token is signed by this key. |
| `sub` | string | REQUIRED | AID of the agent receiving delegation (C). |
| `aud` | string | REQUIRED | MUST equal A's AID — the only peer this token may be presented to. |
| `scope` | array of string | REQUIRED | Capabilities delegated to C. Non-empty. |
| `exp` | integer | REQUIRED | Unix seconds. MUST be ≤ the embedded voucher's `exp`. |
| `cnf` | object | REQUIRED | RFC 7800 confirmation claim for C's key, `{"jkt": …}` form (RFC-AITP-0001 §5.4.4). MUST match the key encoded in `sub`. |
| `voucher` | string | REQUIRED | The grant voucher compact JWS (RFC-AITP-0005 §8), embedded **verbatim**. B MUST NOT decode-and-re-encode it. |
| `ext` | object | OPTIONAL | Extensions slot (RFC-AITP-0012); unknown claims outside `ext` MUST be rejected. |

The v0.1 `delegator` and `audience` fields (which v0.1 required to be equal) are collapsed into the single `aud` claim. The v0.1 `grant_proof` object is replaced by the `voucher` string. The canonical schema for the decoded claims is [`schemas/json/aitp-delegation.schema.json`](../schemas/json/aitp-delegation.schema.json).

---

## 3. Issuance Flow

When B completes a handshake with A, the `MUTUAL_COMMIT` / `MUTUAL_COMMIT_ACK` payload carries both B's TCT and the companion grant voucher (RFC-AITP-0004 §4, RFC-AITP-0005 §8). To delegate to C, B:

1. Chooses `scope` ⊆ the voucher's `grants` and `exp` ≤ the voucher's `exp`.
2. Builds the claims object above, embedding A's voucher string verbatim.
3. Signs it as a compact JWS with its own key (`alg` derived from B's AID).

No issuance step requires A's involvement, and no step re-serializes the voucher. If A declined to mint a voucher at handshake time (issuer policy — RFC-AITP-0005 §8.2), B cannot delegate.

> **What changed from v0.1.** The v0.1 `grant_proof` was a seven-field projection of B's TCT whose signature could only be checked by byte-exact *reconstruction* of the source TCT's canonical JSON. That reconstruction logic (`verify_source_tct_projection`-style code) is deleted from the protocol: the voucher is an independently signed artifact, verified like any other JWS over its transmitted bytes.

---

## 4. Verification Rules

When C presents a delegation token to A, A MUST verify all of the following, in order. Steps 1–6 are pure JWS/claims checks; the revocation lookup (step 7) comes after all signature checks per RFC-AITP-0008 §3.3.

1. **Outer token.** Parse the compact JWS strictly (RFC-AITP-0001 §5.4.5). Enforce header `typ` == `aitp-delegation+jwt` ⇒ else `TOKEN_TYP_MISMATCH`. Derive the sole acceptable `alg` from the `iss` AID and reject any other ⇒ `TOKEN_ALG_MISMATCH`. Verify the signature against B's public key (resolved from the `iss` AID via B's Manifest, RFC-AITP-0003). Failure ⇒ `DELEGATION_INVALID_SIGNATURE`.
2. **Addressing and freshness.** `aud` MUST equal A's own AID ⇒ else `DELEGATION_AUDIENCE_MISMATCH`. `exp` MUST be in the future ⇒ else `DELEGATION_EXPIRED`.
3. **Embedded voucher.** Parse the `voucher` claim as a compact JWS. Enforce header `typ` == `aitp-grant+jwt` ⇒ else `TOKEN_TYP_MISMATCH`. `voucher.iss` MUST equal A's own AID, and the signature MUST verify under A's **own** key ⇒ else `DELEGATION_INVALID_VOUCHER`. (A is verifying its own past signature; no key resolution is needed.)
4. **Delegator held the grant.** `voucher.sub` MUST equal the outer token's `iss` — the delegator-of-record is the peer A actually granted ⇒ else `DELEGATION_INVALID_VOUCHER`. Without this check, B could embed a voucher issued to some other agent.
5. **Expiry monotonicity.** `voucher.exp` MUST be in the future, AND the outer `exp` MUST be ≤ `voucher.exp` (a delegated grant cannot outlive the source grant) ⇒ else `DELEGATION_EXPIRED`.
6. **Scope constraint.** Every capability in `scope` MUST appear in `voucher.grants`:

   ```
   scope ⊆ voucher.grants
   ```

   ⇒ else `DELEGATION_SCOPE_EXCEEDED`.
7. **Source TCT revocation.** Look up `voucher.src_jti` in A's own deny list. If the source TCT has been revoked, the delegation token MUST be rejected ⇒ `DELEGATION_SOURCE_TCT_REVOKED`. This is the only stateful check; it runs only after every signature check has passed (RFC-AITP-0008 §3.3).
8. **No self-delegation.** The outer `iss` MUST NOT equal `sub` ⇒ else `DELEGATION_INVALID_SIGNATURE`.
9. **Proof of possession.** Verify that the presenting agent holds the private key matching `cnf` by running the downstream PoP exchange of [RFC-AITP-0005 §6.1](RFC-AITP-0005-tct.md#61-downstream-pop-exchange) against C, with the bound key taken from the delegation's `sub` AID and checked against `cnf.jkt` (RFC-AITP-0005 §6.2). The verifier MUST issue a fresh `pop_challenge` with a per-verification 128-bit nonce. PoP failure ⇒ `DELEGATION_POP_FAILED`. Implementations MAY skip the exchange only when an equivalent channel binding to C's key is already in place (e.g. mTLS with a client certificate matching `cnf`); they MUST document that posture.

**Multi-hop guard.** Until an implementation explicitly opts into RFC-AITP-0011, it MUST reject any delegation token carrying a `chain` claim (RFC-AITP-0011's opt-in marker) with `DELEGATION_MULTIHOP_NOT_SUPPORTED` — a structural rejection before any per-hop processing.

No step of this algorithm reconstructs any byte sequence. Every signature is verified over bytes exactly as transmitted.

---

## 5. Security Invariants

### 5.1 Audience binding

The `aud` claim MUST equal the verifying issuer's AID (A). A delegation token presented to any other peer MUST be rejected. This prevents C from using B's delegation token at a different peer (D).

### 5.2 Non-transferability

A delegation token is bound to a specific `aud`, a specific `sub`, and a specific `cnf`. None of these bindings can be changed without invalidating B's signature.

### 5.3 Scope cannot exceed original grant

Scope is verified against the voucher, which is signed by A. B cannot forge a voucher claiming more capabilities than A originally granted, and B cannot substitute another agent's voucher (step 4).

### 5.4 Privacy: the voucher discloses B's full grant profile

The voucher carries the complete `grants` list of B's TCT, so C — and anyone C shows the token to — learns B's full capability profile from A, not just the delegated subset.

> **Erratum against v0.1.** RFC-AITP-0006 v0.1 claimed the minimized `grant_proof` hid the delegator's full capability profile. It did not: signature reconstruction forced `grant_proof.capabilities` to equal the complete TCT grant list, so the disclosure was identical. v0.2 states the property honestly. A selective-disclosure voucher (SD-JWT-style) is a natural future fix; the extension point is reserved in RFC-AITP-0012.

---

## 6. Delegation Token Signature

B signs the delegation token as a compact JWS over the transmitted bytes (RFC-AITP-0001 §5.4.5):

```
signing_input = ASCII(base64url(header) || "." || base64url(claims))
signature     = base64url(sign(B_private_key, signing_input))
```

There is no canonicalization step, for the outer token or the embedded voucher. The voucher string inside the claims object is covered verbatim by B's signature, so it cannot be swapped without invalidating the outer JWS.

Pinned (fixed seed → exact compact JWS) vectors for a single-hop delegation live under [`schemas/conformance/known-answer/signed-examples/delegation/`](../schemas/conformance/known-answer/signed-examples/delegation/); implementations MUST reproduce them byte-for-byte.

---

## 7. TCT Issuance for Delegated Peers

After verifying the delegation token, A issues a TCT for C with:

- `sub = C's AID`
- `aud = C's AID`
- `grants = scope ∩ A's policy for delegated peers`
- `exp ≤ delegation.exp`

A MAY reduce the grants or TTL based on local policy. A MUST NOT expand them. A MAY also mint a companion grant voucher for C per RFC-AITP-0005 §8.2 — but only if its policy permits C to delegate onward (which, absent RFC-AITP-0011 opt-in, it should not).

---

## 8. Verification API

Each issuing peer exposes a delegation-verification endpoint over HTTPS. The endpoint accepts a JSON envelope containing the delegation token (compact JWS string) and the calling agent's AID; it returns either a fresh peer-issued TCT for the delegatee or a `DelegationError`.

Defined error codes (see [`registries/error-codes.md`](../registries/error-codes.md)):

| Code | Meaning |
|---|---|
| `TOKEN_TYP_MISMATCH` | Outer or embedded JWS `typ` is not the expected value (§4 steps 1, 3) |
| `TOKEN_ALG_MISMATCH` | JWS `alg` is not the sole AID-derived value, including `none` (§4 step 1) |
| `DELEGATION_AUDIENCE_MISMATCH` | `aud` ≠ verifier's AID |
| `DELEGATION_SCOPE_EXCEEDED` | `scope ⊄ voucher.grants` |
| `DELEGATION_INVALID_VOUCHER` | Embedded voucher signature invalid, `voucher.iss` ≠ verifier's AID, or `voucher.sub` ≠ outer `iss` |
| `DELEGATION_SOURCE_TCT_REVOKED` | `voucher.src_jti` is in the issuing peer's deny list |
| `DELEGATION_INVALID_SIGNATURE` | Outer delegation signature invalid, or self-delegation (`iss` == `sub`) |
| `DELEGATION_EXPIRED` | Token or voucher expired, or `exp` > `voucher.exp` |
| `DELEGATION_POP_FAILED` | Proof-of-possession failed |
| `DELEGATION_MULTIHOP_NOT_SUPPORTED` | `chain` claim present without RFC-AITP-0011 opt-in |

(`DELEGATION_INVALID_VOUCHER` replaces the v0.1 `DELEGATION_INVALID_GRANT_PROOF`; the other codes keep their names with definitions restated in voucher terms.)

---

## 9. Multi-hop (Future)

Multi-hop delegation (A → B → C → D) is specified in [RFC-AITP-0011](RFC-AITP-0011-multihop-delegation.md) (Draft; opt-in). RFC-AITP-0011 covers:

- the `chain` claim — an array of delegation compact JWS strings, one per hop, carried verbatim;
- per-hop verification — standard JWS verification plus scope-subsetting, expiry monotonicity, and revocation at every hop;
- hop limits (default `max_delegation_hops = 3`);
- defense against chain insertion (audience continuity), truncation (`chain_hash`), and scope inflation (transitive subsetting).

**Core conformance.** Until an implementation explicitly opts into RFC-AITP-0011, it MUST reject any delegation token carrying a `chain` claim with `DELEGATION_MULTIHOP_NOT_SUPPORTED`.

---

## 10. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)
- [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
- [RFC-AITP-0011 Multi-hop Delegation](RFC-AITP-0011-multihop-delegation.md) *(Draft, opt-in)*
- [RFC 7515 — JSON Web Signature](https://datatracker.ietf.org/doc/html/rfc7515)
- [RFC 7800 — Proof-of-Possession Key Semantics for JWTs](https://datatracker.ietf.org/doc/html/rfc7800)
