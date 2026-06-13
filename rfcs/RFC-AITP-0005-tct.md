# RFC-AITP-0005
# Trust Context Token (TCT)

**Document:** RFC-AITP-0005
**Version:** 0.2.0-draft
**Status:** Community Standards Track (v0.2 Draft)
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md), [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)

---

## Abstract

The Trust Context Token (TCT) is the canonical output of AITP. It is a signed, peer-issued capability grant produced by the Mutual Handshake (RFC-AITP-0004). Each side of a successful handshake holds one TCT issued by the other peer.

A TCT answers exactly one question: *what is this peer allowed to do here?*

In `aitp/0.2` the TCT is a **compact JWS** ([RFC 7515](https://datatracker.ietf.org/doc/html/rfc7515)) under the Compact JWS profile of [RFC-AITP-0001 §5.4.5](RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts). Its claims map onto registered JWT claims, so any mature JOSE library can verify a TCT given only the issuer's public key — no AITP stack, no canonicalization, no byte reconstruction. This RFC also defines the **grant voucher** (§8), a companion JWS minted alongside the TCT that makes delegation (RFC-AITP-0006) verifiable without reconstructing TCT bytes.

---

## 1. Serialization

A TCT is a compact JWS string:

```
<base64url(header)>.<base64url(claims)>.<base64url(signature)>
```

with protected header (exactly these two parameters — RFC-AITP-0001 §5.4.5):

```json
{ "alg": "EdDSA", "typ": "aitp-tct+jwt" }
```

`alg` is the sole value derived from the issuer's AID (`EdDSA` for Ed25519 AIDs, `ES256` for P-256 AIDs — RFC-AITP-0001 §5.4.5), and decoded claims:

```json
{
  "ver": "aitp/0.2",
  "jti": "<uuid-v4>",
  "iss": "aid:pubkey:ed25519:<issuing-peer-key>",
  "sub": "aid:pubkey:ed25519:<subject-peer-key>",
  "aud": "aid:pubkey:ed25519:<subject-peer-key>",
  "iat": 1711900000,
  "exp": 1711903600,
  "grants": [
    "macp.mode.task.v1",
    "read_data"
  ],
  "cnf": { "jkt": "<RFC 7638 thumbprint of subject key>" }
}
```

The signature covers the exact transmitted bytes. Verifiers MUST NOT re-serialize or canonicalize any part of the token.

The canonical schema for the decoded claims object is [`schemas/json/aitp-tct.schema.json`](../schemas/json/aitp-tct.schema.json). On the wire — in handshake payloads, session bundles, HTTP headers — the TCT is always the opaque compact string.

---

## 2. Claims

| Claim | Type | Description |
|---|---|---|
| `ver` | string | MUST be `"aitp/0.2"` for this RFC. Private claim; see RFC-AITP-0001 §5.4.5. |
| `jti` | string | UUID v4. Unique token ID; the revocation handle (RFC-AITP-0008). |
| `iss` | string | AID of the issuing peer. |
| `sub` | string | AID of the agent this TCT was issued for (the subject peer). |
| `aud` | string | AID of the intended consuming peer. MUST equal `sub`. |
| `iat` | integer | Unix timestamp of issuance (seconds). |
| `exp` | integer | Unix timestamp of expiry (seconds). |
| `grants` | array of string | Capability strings the subject is granted. MUST be non-empty. Private claim. |
| `cnf` | object | RFC 7800 confirmation claim, `{"jkt": …}` form only (§3). |
| `ext` | object | OPTIONAL extensions slot (RFC-AITP-0012). Unknown keys inside `ext` MUST be ignored; unknown claims outside it MUST be rejected. |

`jti`, `iss`, `sub`, `aud`, `iat`, `exp`, and `cnf` carry their registered [RFC 7519](https://datatracker.ietf.org/doc/html/rfc7519) / [RFC 7800](https://datatracker.ietf.org/doc/html/rfc7800) semantics. `ver`, `grants`, and `ext` are AITP private claims.

### 2.1 Mapping from the v0.1 TCT

For implementers migrating from `aitp/0.1`:

| v0.1 field | v0.2 claim |
|---|---|
| `version: "aitp/0.1"` | `ver: "aitp/0.2"` |
| `jti` | `jti` (unchanged; still the revocation handle) |
| `issuer` | `iss` |
| `subject` | `sub` |
| `audience` | `aud` (the `audience == subject` invariant carries over) |
| `issued_at` / `expires_at` | `iat` / `exp` |
| `grants` | `grants` |
| `binding.cnf` (raw public key) | `cnf: {"jkt": …}` (§3) |
| `signature` (embedded, over JCS bytes) | the JWS signature segment (over transmitted bytes) |
| `extensions` | `ext` |

---

## 3. Confirmation Claim (`cnf`)

| Claim | Type | Description |
|---|---|---|
| `cnf.jkt` | string | RFC 7638 JWK thumbprint of the subject's public key, base64url-unpadded (43 chars). Used for proof-of-possession. |

Every v0.2 peer-issued TCT MUST include `cnf`. There is no bearer-TCT profile. `cnf` is what distinguishes a peer-issued TCT from a credential that can be freely transferred — it binds the grant to the subject's live private key and enables downstream PoP verification by any consumer without replaying the handshake.

`cnf.jkt` MUST equal the RFC 7638 thumbprint of the public key encoded in the TCT's `sub` AID (RFC-AITP-0001 §5.4.4). Issuers MUST NOT issue TCTs where `cnf.jkt` and `sub` reference different keys, and consumers MUST reject such TCTs. Because the subject AID itself encodes the key, the verifier derives the *expected* thumbprint from `sub` alone — `cnf.jkt` is deliberately redundant so that JOSE-generic verifiers (which understand `cnf` but not AIDs) can still perform PoP.

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
- Grants are **flat** in v0.2 — no constraints or conditions inside a grant string.
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

The `aud` claim identifies which peer this TCT is valid for.

### 5.1 Format

`aud` MUST be the subject peer's AID:

```
aid:<method>:<identifier>
```

Wildcard audiences (`"*"`) are NOT permitted. Every TCT is bound to exactly one peer. `aud` is a single string, never an array.

### 5.2 Audience validation

A peer consuming a TCT MUST verify that `aud` matches its own AID. TCTs with a mismatched audience MUST be rejected with `AUDIENCE_MISMATCH`.

---

## 6. Binding (Proof of Possession)

`cnf` is REQUIRED on every v0.2 peer-issued TCT (RFC-AITP-0004 §4.4). It binds the token to the subject's key so any peer can challenge the holder for proof-of-possession.

Within the Mutual Handshake itself, PoP is **mandatory** and is exchanged via the `pop_signature` / `pop_nonce` fields of `MUTUAL_COMMIT` and `MUTUAL_COMMIT_ACK`.

**Downstream PoP** — when a peer presents a TCT to consume a capability after the handshake — is governed by the issuing peer's policy:

- Consumers **MUST** verify PoP for any grant that the issuing peer's policy marks as requiring it.
- Consumers **SHOULD** verify PoP for all grants by default, unless the deployment environment provides equivalent channel binding (e.g. mTLS with bound client certificates, an authenticated message bus where the underlying channel already proves possession of the AID's key).

The mechanism by which an issuing peer marks per-grant PoP requirements is **deployment-defined in v0.2**: it MAY be encoded in the issuing peer's `offered_capabilities` namespace (e.g. by suffix convention), kept in a side channel (a policy document at a well-known URL), or distributed out-of-band. A normative marking mechanism is reserved for a future RFC.

**RECOMMENDED convention.** Until a normative mechanism is standardized, implementations SHOULD use the `#pop_required` suffix to signal a PoP requirement on a grant: `<capability_identifier>#pop_required`. A consumer that recognizes this suffix MUST:

1. Issue a `pop_challenge` before authorizing invocation of the marked grant.
2. Reject the invocation if no valid `pop_response` is received within the challenge's freshness window.

The `tct-007` conformance fixture uses `macp.mode.task.v1#pop_required` to exercise this convention. Deployments using a different marking scheme (`.pop_required`, `.requires_pop`, an out-of-band policy document, etc.) remain conformant, provided both peers agree on the scheme out-of-band; the suffix above is RECOMMENDED specifically so that implementations with no prior agreement still interoperate on PoP-marked grants.

Implementations that omit downstream PoP for non-marked grants MUST document that posture and MUST NOT claim conformance for environments that lack equivalent channel binding.

### 6.1 Downstream PoP exchange

The downstream exchange is two messages, both wrapped in the standard envelope (RFC-AITP-0001 §5).

**Step 1 — Challenge.** The consuming peer sends:

```json
{
  "version": "aitp/0.2",
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
  "version": "aitp/0.2",
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
3. Verify `pop_signature` against the subject's public key — the key encoded in the TCT's `sub` AID:
   `verify(sub_public_key, sha256(base64url_decode(nonce)), pop_signature)`.
   The hash input MUST be the raw decoded bytes of the challenge nonce, not the base64url string.
4. Confirm `cnf.jkt` equals the RFC 7638 thumbprint of that same key (§3).

A failure at any step MUST return `POP_RESPONSE_INVALID`. A malformed or stale challenge MUST return `POP_CHALLENGE_INVALID`. Replay protection on `pop_challenge` follows RFC-AITP-0001 §5.5; nonces from an expired challenge MUST NOT be accepted.

> **Conformance note.** An AITP v0.2 implementation MUST implement the PoP exchange mechanics — it MUST be capable of issuing `pop_challenge` envelopes, producing `pop_response` envelopes, and verifying both ends. Whether PoP is *enforced* for any specific grant depends on the issuing peer's policy annotation for that grant (the deployment-defined marking mechanism described in §6). Implementations MUST expose a configuration surface to enable PoP enforcement **per grant**, so that the issuing peer's policy annotations can be honored without code changes. **An implementation that silently skips PoP regardless of the issuing peer's policy — including for grants the issuer has marked as requiring PoP — is non-conformant.** This is true even if the deployment claims equivalent channel binding: equivalent channel binding may justify omitting PoP for non-marked grants (the SHOULD in §6 above), but a marked-by-issuer requirement is a MUST per §6 and cannot be silently dropped at the consumer side.
>
> Implementations MUST also document their default PoP enforcement posture (enforce-for-marked-only, enforce-for-all, mTLS-equivalent-channel-binding, etc.) so operators can audit the configuration against their threat model.
>
> The conformance fixture [`tct-006-pop-challenge-response.json`](../schemas/conformance/tct-006-pop-challenge-response.json) verifies the implementation can produce and verify a PoP exchange end-to-end. The fixture [`tct-007-pop-enforcement-required.json`](../schemas/conformance/tct-007-pop-enforcement-required.json) verifies that a grant marked as requiring PoP cannot be consumed without a valid `pop_response` — implementations that allow capability invocation against a PoP-required grant in the absence of a valid response MUST fail this fixture.

### 6.3 Where this exchange happens

Downstream PoP is **transport-flexible**. It can be carried in:

- HTTP request/response bodies (JSON envelopes);
- HTTP headers carrying base64url-encoded JSON envelopes (`x-aitp-pop-challenge` / `x-aitp-pop-response`);
- any other transport that preserves the envelope's integrity, provided the AITP envelope round-trips through the transport unchanged and signature verification uses the canonical JSON form (RFC-AITP-0001 §5.4.1).

This RFC defines the message types and their payloads; transport binding is deployment-defined.

---

## 7. TCT Signature and Verification

### 7.1 What is signed

The JWS signing input is the transmitted bytes, per RFC 7515:

```
signing_input = ASCII(base64url(header) || "." || base64url(claims))
signature     = base64url(sign(issuer_private_key, signing_input))
```

(For `EdDSA` the signature is Ed25519 over the signing input; for `ES256` it is ECDSA P-256/SHA-256 with the JOSE raw `R || S` encoding — RFC-AITP-0001 §5.4.5.)

There is no canonicalization step. The bytes the issuer transmitted are the bytes the verifier checks. Pinned (fixed seed → exact compact JWS string) vectors live under [`schemas/conformance/known-answer/signed-examples/`](../schemas/conformance/known-answer/signed-examples/); implementations MUST reproduce them byte-for-byte, and any off-the-shelf JOSE tool given the issuer public key MUST verify them.

### 7.2 Verification order

A TCT verifier MUST, in order:

1. **Parse strictly** — exactly three non-empty base64url segments (RFC-AITP-0001 §5.4.5 strict-parsing rules).
2. **Enforce `typ`** — header `typ` MUST be exactly `aitp-tct+jwt`; otherwise reject with `TOKEN_TYP_MISMATCH`.
3. **Pin `alg`** — derive the sole acceptable `alg` from the issuer's AID (`iss` claim) and reject any other header value, including `none`, with `TOKEN_ALG_MISMATCH`.
4. **Verify the signature** against the issuer's public key.
5. **Check claims** — `ver` known; `aud` == own AID; `exp` in the future; `cnf.jkt` matches `sub` (§3); grants non-empty.
6. **Check revocation** — look up `jti` against the issuer's deny list (RFC-AITP-0008), only after all signature checks (RFC-AITP-0008 §3.3).

### 7.3 Issuer key resolution

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

## 8. Grant Voucher

The grant voucher is a compact JWS minted by the TCT issuer **at TCT issuance time**, alongside the TCT, and delivered in the same `MUTUAL_COMMIT` / `MUTUAL_COMMIT_ACK` payload (RFC-AITP-0004 §4). It exists for exactly one purpose: to let the subject later delegate (RFC-AITP-0006) without anyone reconstructing TCT bytes. It replaces the v0.1 `grant_proof` mechanism entirely.

### 8.1 Serialization

Protected header (exactly two parameters):

```json
{ "alg": "<derived from issuer AID>", "typ": "aitp-grant+jwt" }
```

Decoded claims:

```json
{
  "ver": "aitp/0.2",
  "iss": "aid:pubkey:ed25519:<TCT-issuer-key>",
  "sub": "aid:pubkey:ed25519:<TCT-subject-key>",
  "grants": ["macp.mode.task.v1", "read_data"],
  "iat": 1711900000,
  "exp": 1711903600,
  "src_jti": "<jti of the companion TCT>"
}
```

| Claim | Type | Description |
|---|---|---|
| `ver` | string | MUST be `"aitp/0.2"`. |
| `iss` | string | The TCT issuer's AID. The voucher is signed by this key. |
| `sub` | string | The TCT subject's AID — the peer entitled to delegate against this voucher. |
| `grants` | array of string | MUST equal the companion TCT's `grants`. Non-empty. |
| `iat` / `exp` | integer | MUST equal the companion TCT's `iat` / `exp`. |
| `src_jti` | string | The companion TCT's `jti`. Revocation rides on this: revoking the TCT kills every voucher and delegation derived from it (RFC-AITP-0008). |
| `ext` | object | OPTIONAL, same semantics as the TCT `ext` claim. |

The voucher has no `jti` and no independent revocation handle — its lifecycle is strictly derived from the companion TCT via `src_jti`. It has no `cnf`: it is not presented under PoP by itself, but embedded verbatim inside a delegation token whose outer signature binds it (RFC-AITP-0006).

The canonical schema for the decoded claims is [`schemas/json/aitp-grant-voucher.schema.json`](../schemas/json/aitp-grant-voucher.schema.json).

### 8.2 Issuance rules

- The issuer MUST mint the voucher with the same `iss`, `sub`, `grants`, `iat`, and `exp` as the companion TCT, and `src_jti` equal to the TCT's `jti`.
- The voucher MUST be delivered alongside the TCT in the handshake commit payload (RFC-AITP-0004 §4). An issuer MAY decline to mint a voucher when its policy forbids the subject from delegating; the handshake then carries only the TCT, and the subject cannot delegate.
- Voucher verification (by the issuer itself, during delegation verification) is defined in RFC-AITP-0006 §4.

### 8.3 Privacy note

The voucher carries the companion TCT's complete `grants` list. When the subject delegates, the delegatee (and any verifier of the delegation token) therefore sees the subject's full capability profile from that issuer, not just the delegated subset. This is an *honest* restatement of a property v0.1 already had — the v0.1 `grant_proof` claimed minimization but reconstruction forced `grant_proof.capabilities` to equal the full grant list. A future extension may introduce selective disclosure (SD-JWT-style) vouchers; the extension point is reserved in RFC-AITP-0012.

---

## 9. Lifecycle

```
Issued → Active → Expired
                         ↑
         Revoked ────────┘ (via JTI deny list)
```

- TCTs MUST NOT be used after `exp`.
- TCTs MAY be revoked before `exp` via the issuing peer's JTI deny list (see [RFC-AITP-0008](RFC-AITP-0008-revocation.md)). Revoking a TCT also invalidates its companion voucher and every delegation derived from it (`src_jti` linkage, §8.1).

### 9.1 Recommended TTLs

| Use case | Recommended TTL |
|---|---|
| Short interaction | 1 hour |
| Standard task | 8 hours |
| Long-running collaboration | 24 hours |

Peer-issued TCT `exp` MUST NOT exceed the issuing peer's Manifest `expires_at`. (See RFC-AITP-0004 §4.3.)

---

## 10. Consumer Rules

### 10.1 MUST

1. Run the full verification order of §7.2 (strict parse, `typ`, AID-pinned `alg`, signature against the issuing peer's Manifest-resolved key).
2. Confirm `aud` matches own AID.
3. Confirm `exp` is in the future.
4. Enforce `grants` — deny any operation not in the grant list.

### 10.2 MUST NOT

- Recompute trust from the underlying identity proof.
- Accept TCTs with an unknown `ver`.
- Accept the `alg` or any key material from the token itself — the AID and Manifest decide (RFC-AITP-0001 §5.4.5, RFC-AITP-0007).
- Modify or re-sign TCTs.
- Accept TCTs whose `aud` is not own AID.

### 10.3 SHOULD

- Verify proof-of-possession per the issuing peer's per-grant policy (§6). Consumers that omit downstream PoP MUST NOT claim conformance for environments lacking equivalent channel binding.
- Check revocation status by querying the issuer's `ListRevoked` endpoint.

### 10.4 Manifest expiry bound (conditional)

If the issuing peer's Manifest is available — from the handshake payload or a local cache — the consumer MUST verify:

```
tct.exp ≤ issuer_manifest.expires_at
```

A TCT that violates this bound MUST be rejected with `TCT_EXPIRES_AFTER_MANIFEST`. A peer-issued TCT cannot outlive the Manifest credential that authenticates its issuer's key; RFC-AITP-0004 §4.3 constrains the issuer not to mint such a TCT, and this rule is the verifier-side mirror of that constraint.

This check MAY be skipped when the issuer Manifest is unavailable — verifiers are NOT required to fetch the Manifest solely to perform it. The §10.1 expiry check (`exp` in the future) still applies unconditionally.

---

## 11. Peer-Issued TCT Verification API

Each agent that issues TCTs MUST expose three HTTPS endpoints for peers to verify and manage revocation of its TCTs:

| Operation | Method | Description |
|---|---|---|
| `Verify` | POST | Convenience verification — consuming peer can verify locally using only the issuing peer's Manifest key, but MAY call this for a freshness check. |
| `Revoke` | POST | Admin-only; adds a `jti` to the issuing peer's deny list. |
| `ListRevoked` | GET | Returns the issuing peer's signed revocation snapshot (RFC-AITP-0008 §1.5). |

Concrete URL paths are deployment-defined. The Manifest MAY advertise the verify and revocation endpoints in `extensions` (RFC-AITP-0012); v0.2 does not normatively pin those advertisement fields.

---

## 12. Design Notes: Alternatives Considered (non-normative)

The v0.2 move from JCS-signed JSON to compact JWS for the TCT was made for four reasons:

1. **Kill the re-serialization bug class on the hot path.** A JWS signature covers the exact transmitted bytes; verifiers never re-canonicalize. JCS re-serialization mismatches are the XML-DSig/JOSE-era signature-bypass class, and TCTs are the artifact most likely to be verified by non-AITP code in other languages.
2. **Off-the-shelf verification.** TCT claims map 1:1 onto registered JWT claims (`jti`/`iss`/`sub`/`aud`/`iat`/`exp`/`cnf`); every language has a mature JOSE library. Only `grants` (and `ver`/`ext`) are private claims.
3. **Cross-protocol confusion immunity by convention.** RFC 8725 explicit typing (`typ`) replaces immunity-by-obscurity.
4. **Standards legibility.** A "JWT profile with mandatory `cnf`" is legible to IETF/WIMSE/OpenID reviewers, with registerable media types.

Alternatives rejected:

- **Dual serialization** (JSON+JCS *and* JWS): doubles the conformance matrix and creates a downgrade surface — a verifier that accepts both forms can be steered to the weaker path.
- **Byte-deterministic JWS** (JCS-canonicalized payload inside the JWS): keeps the canonicalization requirement alive and forfeits gain #1; the payload bytes would once again be reconstructible state.
- **Full JOSE migration** (envelopes and manifests too): a much larger rewrite with no consumer for off-the-shelf verification of protocol-internal messages — both ends of those exchanges are full AITP stacks by definition. Hence the boundary rule of RFC-AITP-0001 §5.4.5.

---

## 13. Security Considerations

- A TCT is portable — anyone holding it can present it. PoP via `cnf` is the primary defense against TCT theft.
- Consuming peers MUST treat the TCT signature as the sole authority. The TCT is self-contained; there is no out-of-band lookup that "augments" trust.
- The `alg` header is attacker-controlled input until pinned: deriving the sole acceptable algorithm from the AID **before** verification (§7.2 step 3) is what forecloses `none` and cross-algorithm confusion. See RFC-AITP-0009 §1.
- `typ` enforcement (§7.2 step 2) prevents a grant voucher or delegation token — signed by the same keys — from being replayed as a TCT. See RFC-AITP-0009 §1.
- Recommended TTLs balance availability against compromise blast radius. See [RFC-AITP-0009](RFC-AITP-0009-security.md).
- Wildcard audiences are forbidden to prevent cross-peer confusion attacks.

---

## 14. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0006 Single-Hop Delegation](RFC-AITP-0006-delegation.md)
- [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
- [RFC 7515 — JSON Web Signature](https://datatracker.ietf.org/doc/html/rfc7515)
- [RFC 7519 — JSON Web Token](https://datatracker.ietf.org/doc/html/rfc7519)
- [RFC 7638 — JWK Thumbprint](https://datatracker.ietf.org/doc/html/rfc7638)
- [RFC 7800 — Proof-of-Possession Key Semantics for JWTs](https://datatracker.ietf.org/doc/html/rfc7800)
- [RFC 8725 — JWT Best Current Practices](https://datatracker.ietf.org/doc/html/rfc8725)
