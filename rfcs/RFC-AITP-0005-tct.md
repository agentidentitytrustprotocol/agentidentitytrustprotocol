# RFC-AITP-0005
# Trust Context Token (TCT)

**Document:** RFC-AITP-0005
**Version:** 0.3.0-draft
**Status:** Community Standards Track (Draft)
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md), [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)

---

## Abstract

The Trust Context Token (TCT) is the canonical output of AITP. It is a signed, peer-issued capability grant produced by the Mutual Handshake (RFC-AITP-0004). Each side of a successful handshake holds one TCT issued by the other peer.

A TCT answers exactly one question: *what is this peer allowed to do here?*

In `aitp/0.3` the TCT is a **compact JWS** ([RFC 7515](https://datatracker.ietf.org/doc/html/rfc7515)) under the Compact JWS profile of [RFC-AITP-0001 §5.4.5](RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts). Its claims map onto registered JWT claims, so any mature JOSE library can verify a TCT given only the issuer's public key — no AITP stack, no canonicalization, no byte reconstruction. This RFC also defines the **grant voucher** (§8), a companion JWS minted alongside the TCT that makes delegation (RFC-AITP-0006) verifiable without reconstructing TCT bytes.

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
  "ver": "aitp/0.3",
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
| `ver` | string | MUST be `"aitp/0.3"` for this RFC. Private claim; see RFC-AITP-0001 §5.4.5. |
| `jti` | string | Lowercase UUID v4 in the §2.2 layout, random or derived. Unique token ID; the revocation handle (RFC-AITP-0008). |
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

| v0.1 field | Current claim |
|---|---|
| `version: "aitp/0.1"` | `ver: "aitp/0.3"` |
| `jti` | `jti` (unchanged; still the revocation handle) |
| `issuer` | `iss` |
| `subject` | `sub` |
| `audience` | `aud` (the `audience == subject` invariant carries over) |
| `issued_at` / `expires_at` | `iat` / `exp` |
| `grants` | `grants` |
| `binding.cnf` (raw public key) | `cnf: {"jkt": …}` (§3) |
| `signature` (embedded, over JCS bytes) | the JWS signature segment (over transmitted bytes) |
| `extensions` | `ext` |

### 2.2 Identifier layout (`jti`)

`jti` MUST be a lowercase hyphenated string in the [RFC 9562](https://datatracker.ietf.org/doc/html/rfc9562) UUID v4 layout: version nibble `4`, variant bits `10`. A verifier MUST reject any other form before signature verification (§7.2 step 1), with `TCT_SIGNATURE_INVALID`, the TCT's structural-rejection code ([`registries/error-codes.md`](../registries/error-codes.md#structural-rejection)). No dedicated code exists: that table already decides that a compact-JWS artifact collapses structural failure onto its signature-family code, so an unauthenticated token leaks no parse detail.

The remaining 122 bits MUST be either:

- **random**: drawn from a CSPRNG (RFC-AITP-0001 §11), or
- **derived**: taken from `h = SHA-256(domain_tag_bytes || 0x00 || input_bytes)`, where `domain_tag_bytes` is the ASCII encoding of an issuer-chosen label unique to that use (printable ASCII `0x21`–`0x7E`, so it never contains `0x00`), `0x00` is a single null byte separator (the RFC-AITP-0002 §3.1 `proof_input` convention), and `input_bytes` is unique per token for that issuer. The issuer MUST guarantee that distinct tokens never share an `input_bytes`. The identifier is `h[0..16]` with `h[6] = (h[6] & 0x0f) | 0x40` and `h[8] = (h[8] & 0x3f) | 0x80`, rendered as lowercase hyphenated 8-4-4-4-12 hex. The separator stops two registered tags where one is a prefix of the other (`a` and `ab`) from yielding the same preimage.

A verifier cannot tell the two apart, and MUST NOT try.

Derived identifiers serve idempotent re-issuance and archival attestations: a host that re-mints the commitment for the same record after a restart must produce the same `jti`, which CSPRNG bits would forbid. Requiring the v4 layout keeps the schema pattern valid and lets generic UUID parsers that check version or variant accept the value. Domain tags in use are listed in [`registries/jti-domain-tags.md`](../registries/jti-domain-tags.md); the known-answer vector `kat-derived-uuid-001` ([`jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json)) pins the construction byte for byte. The same layout governs the envelope `message_id` (RFC-AITP-0001 §5.2), the grant voucher's `src_jti` (§8.1), and the per-hop `jti` of RFC-AITP-0011.

---

## 3. Confirmation Claim (`cnf`)

| Claim | Type | Description |
|---|---|---|
| `cnf.jkt` | string | RFC 7638 JWK thumbprint of the subject's public key, base64url-unpadded (43 chars). Used for proof-of-possession. |

Every v0.3 peer-issued TCT MUST include `cnf`. There is no bearer-TCT profile. `cnf` is what distinguishes a peer-issued TCT from a credential that can be freely transferred — it binds the grant to the subject's live private key and enables downstream PoP verification by any consumer without replaying the handshake.

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

The reserved marker grant `aitp.attestation` (§5.3) is a deliberate two-segment exception. It names no capability, and appears only in a self-attestation.

### 4.2 Semantics

- Grants are **additive** — the subject has every capability listed.
- Grants have **no implicit hierarchy** — `read_data` does not imply `write_data`.
- Grants are **flat** in v0.3 — no constraints or conditions inside a grant string.
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

### 5.3 Self-issued attestation TCTs

A TCT with `iss == sub == aud` is a **self-attestation**: a signed statement by the issuer about itself, for example the commitment to a decision record kept as archival evidence. It confers no capability. It is not issued by the Mutual Handshake, whose TCTs always have `iss ≠ sub`.

- **Grant contexts.** A *grant context* is any context that evaluates a TCT as a capability grant: the Mutual Handshake ([RFC-AITP-0004 §4](RFC-AITP-0004-mutual-handshake.md#4-tct-issuance-rules)), the consumer rules of §10, the verification API of §11, and a delegation's source TCT ([RFC-AITP-0006](RFC-AITP-0006-delegation.md)). A verifier in a grant context MUST reject a TCT with `iss == sub`, with `TCT_SIGNATURE_INVALID`. This follows the self-delegation rule of RFC-AITP-0006 §4 step 8 and RFC-AITP-0011 §3. The check runs after the signature has verified (§7.2 step 5), so it is not a structural rejection in the sense of [`registries/error-codes.md`](../registries/error-codes.md#structural-rejection), but it reuses the TCT's signature-family code, the code that table assigns to TCT structural defects. It is not `AUDIENCE_MISMATCH`, because `aud` does equal the verifier's AID there.
- **Marker grant.** `grants` stays non-empty (§2). An attestation carries exactly one grant, the reserved marker `aitp.attestation` ([`registries/capabilities.md`](../registries/capabilities.md)), which names no capability. An issuer MUST NOT mint a TCT containing `aitp.attestation` with `iss ≠ sub`, and MUST NOT put it beside any other grant. A verifier in a grant context MUST reject any TCT whose `grants` contains `aitp.attestation`, with `TCT_SIGNATURE_INVALID`, whatever its `iss`.
- **Statement.** The attested content goes in `ext`, under a namespaced key per [RFC-AITP-0012](RFC-AITP-0012-extensions.md) (an AITP-registered key, or a reverse-domain vendor key). `ext` is inside the JWS payload, so it is signed. The §2 rule that unknown keys inside `ext` MUST be ignored still applies to keys the relying party does not consume. A relying party MUST reject an attestation whose `ext` lacks the key it expects, with `TCT_SIGNATURE_INVALID` (`tct-019`). This check runs after the signature has verified, so it is not a structural rejection in the sense of [`registries/error-codes.md`](../registries/error-codes.md#structural-rejection); it reuses the TCT's signature-family code so that every attestation rejection reads the same.
- **`typ`, `cnf` and `jti`.** An attestation is an ordinary TCT on the wire: header `typ` `aitp-tct+jwt`, the claims of §2 and no others. A distinct attestation `typ` is not defined, and a verifier MUST reject any other `typ` with `TOKEN_TYP_MISMATCH` (§7.2 step 2). An attestation MUST carry `cnf` (§3), which binds the issuer's own key, since `sub` is the issuer. `jti` follows §2.2 and MAY be derived, so that re-minting the same statement yields the same token.
- **Lifetime.** An attestation MAY be long-lived. When the issuer publishes no Manifest, the §9.1 and §10.4 Manifest bounds have nothing to bind to. A relying party MUST then decide explicitly to waive the Manifest cap, and MUST establish from its own records (an enrollment or key-history record, for example) that the issuer key was trusted at `iat`. When its records do not establish that, it MUST reject the attestation with `TCT_SIGNATURE_INVALID` (`tct-021`). It MUST NOT treat a far-future `exp` alone as evidence of validity. When the issuer does publish a Manifest, §10.4 applies unchanged.
- **Verification.** Verifying an attestation is not a grant context. A relying party runs §7.2 steps 1–4 and 6 unchanged. For step 5 it checks `ver`, `exp` (subject to the lifetime rule above) and `cnf.jkt` as written, and checks that `iss == sub == aud` and that `grants` is exactly `["aitp.attestation"]`. Any of these attestation-shape defects ⇒ `TCT_SIGNATURE_INVALID`. These checks run after the signature has verified, so they are not structural rejections in the sense of [`registries/error-codes.md`](../registries/error-codes.md#structural-rejection); they reuse the code the TCT uses for its structural and signature failures. The §5.2 audience rule, and the §10 consumer rules, govern grant contexts: a third party that checks archival evidence is not the attestation's audience, and it does not consume the attestation as a grant. Issuer key resolution follows the §7.3 exception.
- **Revocation.** [RFC-AITP-0008](RFC-AITP-0008-revocation.md) `jti` revocation applies unchanged.
- **Conformance claim.** Verifying attestations is an OPTIONAL relying-party role. An implementation that verifies attestations MAY claim "AITP v0.3 self-attestation" conformance; if it does, it MUST pass the fixtures gated on `feature: aitp-self-attestation`. Issuing attestations needs no separate claim.

The attestation profile does not change [RFC-AITP-0004 §4.1](RFC-AITP-0004-mutual-handshake.md#41-grant-intersection)'s ban on empty-grants TCTs or its rule that an identity-only proof uses the Manifest: an attestation is not issued in a handshake, its `grants` is not empty, and it is a statement by the issuer about itself, not a proof of a peer's identity.

> **Known answers.** `kat-tct-002-self-attestation` (EdDSA, `kat-keypair-001`) and `kat-tct-003-p256-self-attestation` (ES256, `kat-keypair-005-p256`) under [`signed-examples/tct/`](../schemas/conformance/known-answer/signed-examples/tct/) pin two attestations with a 100-year `exp`, a `jti` derived with the `aitp-kat-attestation-v1` tag over the vector id, and an `ext` statement. `tct-015` (self-issued grant), `tct-016` (marker grant with a distinct `iss`) and `tct-018` (marker beside an ordinary grant) are the grant-context rejections. The "Verification" bullet above is pinned twice. Both stacks of `make kat-verify` check each known answer as an attestation: `iss == sub == aud`, `grants` exactly `["aitp.attestation"]`, `cnf.jkt` the issuer's own thumbprint, and the `ext` statement present. `tct-020` presents `kat-tct-002` itself to a third-party relying party through the `verify_attestation` operation and expects success, although `aud` is not that party's AID. `tct-019` is an otherwise valid attestation whose `ext` lacks the key the relying party expects, rejected with `TCT_SIGNATURE_INVALID`. `tct-021` presents `kat-tct-002` to a relying party whose records do not show the issuer key as trusted at `iat`, rejected with `TCT_SIGNATURE_INVALID`. `tct-019`, `tct-020` and `tct-021` are `status: extension` under `feature: aitp-self-attestation`, because consuming attestations is a relying-party role that RFC-AITP-0001 §10 does not require.

---

## 6. Binding (Proof of Possession)

`cnf` is REQUIRED on every v0.3 peer-issued TCT (RFC-AITP-0004 §4.4). It binds the token to the subject's key so any peer can challenge the holder for proof-of-possession.

Within the Mutual Handshake itself, PoP is **mandatory** and is exchanged via the `pop_signature` / `pop_nonce` fields of `MUTUAL_COMMIT` and `MUTUAL_COMMIT_ACK`.

**Downstream PoP** — when a peer presents a TCT to consume a capability after the handshake — is governed by the issuing peer's policy:

- Consumers **MUST** verify PoP for any grant that the issuing peer's policy marks as requiring it.
- Consumers **SHOULD** verify PoP for all grants by default, unless the deployment environment provides equivalent channel binding (e.g. mTLS with bound client certificates, an authenticated message bus where the underlying channel already proves possession of the AID's key).

The mechanism by which an issuing peer marks per-grant PoP requirements is **deployment-defined in v0.3**: it MAY be encoded in the issuing peer's `offered_capabilities` namespace (e.g. by suffix convention), kept in a side channel (a policy document at a well-known URL), or distributed out-of-band. A normative marking mechanism is reserved for a future RFC.

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
  "version": "aitp/0.3",
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
  "version": "aitp/0.3",
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

> **Conformance note.** An AITP v0.3 implementation MUST implement the PoP exchange mechanics — it MUST be capable of issuing `pop_challenge` envelopes, producing `pop_response` envelopes, and verifying both ends. Whether PoP is *enforced* for any specific grant depends on the issuing peer's policy annotation for that grant (the deployment-defined marking mechanism described in §6). Implementations MUST expose a configuration surface to enable PoP enforcement **per grant**, so that the issuing peer's policy annotations can be honored without code changes. **An implementation that silently skips PoP regardless of the issuing peer's policy — including for grants the issuer has marked as requiring PoP — is non-conformant.** This is true even if the deployment claims equivalent channel binding: equivalent channel binding may justify omitting PoP for non-marked grants (the SHOULD in §6 above), but a marked-by-issuer requirement is a MUST per §6 and cannot be silently dropped at the consumer side.
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

A TCT verifier MUST, in order. Step numbers below are load-bearing (cited by
RFC-AITP-0001 §7, RFC-AITP-0008 §3.3, RFC-AITP-0009 §1, and the `tct-002` /
`tct-003` / `tct-004` / `tct-008` / `tct-009` / `tct-010` / `tct-013` /
`tct-014` conformance fixtures) and are not renumbered here; instead, step 1's *sub-steps* are
ordered explicitly, since they previously read as a single unordered clause:

1. **Parse strictly** — exactly three non-empty base64url segments (RFC-AITP-0001 §5.4.5 strict-parsing rules); this segment check alone precedes everything below, including step 2. Once decoded, this step also requires the claims set to contain only the claims registered in §2 — the TCT is a compact JWS, so RFC-AITP-0001 §7's unknown-field rule lands on the decoded *claims*, and the extension namespace is the `ext` claim, spelled `ext`, not `extensions`; any unrecognized claim outside `ext` ⇒ `UNKNOWN_FIELD`, unknown keys *inside* `ext` MUST be ignored. The same clause checks `jti` against the §2.2 layout; a `jti` in any other form (another UUID version, wrong variant bits, uppercase) ⇒ `TCT_SIGNATURE_INVALID`, before step 4 (`tct-013`, `tct-014`). (The protected header needs no separate unknown-member check here: §5.4.5 already pins it to exactly `alg` and `typ`.) **This claims-membership check executes after step 2's `typ` enforcement, not before it** (see step 2's note) — it is kept under step 1's number, rather than given its own, only to avoid renumbering the load-bearing steps that follow. Full execution order: this step's segment-parsing, then step 2, then this step's claims-membership clause, then steps 3–4.
2. **Enforce `typ`** — header `typ` MUST be exactly `aitp-tct+jwt`; otherwise reject with `TOKEN_TYP_MISMATCH`. This runs before step 1's claims-membership clause (see the note there): a `typ` mismatch is rejected as type confusion regardless of what the decoded claims contain, so that a grant voucher or delegation token — signed by the same issuer key as its companion TCT, and structurally a valid JWS carrying its own, different, registered claim set — is never evaluated as a TCT at all. `tct-010` pins exactly this ordering: a schema-valid, validly-signed grant voucher presented as a TCT MUST be rejected with `TOKEN_TYP_MISMATCH`, even though its claims (e.g. `src_jti`) are not TCT claims and would otherwise trigger `UNKNOWN_FIELD`.
3. **Pin `alg`** — derive the sole acceptable `alg` from the issuer's AID (`iss` claim) and reject any other header value, including `none`, with `TOKEN_ALG_MISMATCH`.
4. **Verify the signature** against the issuer's public key.
5. **Check claims** — `ver` known; `aud` == own AID; `exp` in the future; `cnf.jkt` matches `sub` (§3); grants non-empty. In a grant context, also `iss` ≠ `sub` and no `aitp.attestation` in `grants` (§5.3); either defect ⇒ `TCT_SIGNATURE_INVALID` (`tct-015`, `tct-016`, `tct-018`).
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

**Exception: self-attestations without a Manifest (§5.3).** A self-attestation whose issuer publishes no Manifest has no Manifest-resolved key, and the chain above does not apply to it. Its key is the one encoded in its `iss` AID, and the signature proves only that the holder of that key signed it. A relying party MUST NOT make a trust decision on such an attestation unless it has established from its own records (an enrollment or key-history record) that the issuer key was trusted at `iat`; otherwise it rejects the attestation with `TCT_SIGNATURE_INVALID` (§5.3, `tct-021`). It MUST NOT accept such a TCT in a grant context at all (§5.3).

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
  "ver": "aitp/0.3",
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
| `ver` | string | MUST be `"aitp/0.3"`. |
| `iss` | string | The TCT issuer's AID. The voucher is signed by this key. |
| `sub` | string | The TCT subject's AID — the peer entitled to delegate against this voucher. |
| `grants` | array of string | MUST equal the companion TCT's `grants`. Non-empty. |
| `iat` / `exp` | integer | MUST equal the companion TCT's `iat` / `exp`. |
| `src_jti` | string | The companion TCT's `jti`, so it has the §2.2 layout; a voucher whose `src_jti` breaks it is rejected structurally with `DELEGATION_INVALID_VOUCHER`. Revocation rides on this: revoking the TCT kills every voucher and delegation derived from it (RFC-AITP-0008). |
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

A self-attestation (§5.3) is not peer-issued, and these TTLs do not apply to it. It MAY be long-lived. When its issuer publishes a Manifest, the bound above still applies. When the issuer publishes none, the relying party waives the bound explicitly, as §5.3 requires.

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
- Check revocation status by querying the issuer's `ListRevoked` endpoint, located through the `rfc-aitp-0008.revocation_list_uri` key in the issuer's Manifest (§11).

### 10.4 Manifest expiry bound (conditional)

If the issuing peer's Manifest is available — from the handshake payload or a local cache — the consumer MUST verify:

```
tct.exp ≤ issuer_manifest.expires_at
```

A TCT that violates this bound MUST be rejected with `TCT_EXPIRES_AFTER_MANIFEST`. A peer-issued TCT cannot outlive the Manifest credential that authenticates its issuer's key; RFC-AITP-0004 §4.3 constrains the issuer not to mint such a TCT, and this rule is the verifier-side mirror of that constraint.

This check MAY be skipped when the issuer Manifest is unavailable — verifiers are NOT required to fetch the Manifest solely to perform it. The §10.1 expiry check (`exp` in the future) still applies unconditionally.

A self-attestation (§5.3) whose issuer publishes no Manifest has no bound to check. Skipping it there is not the passive skip above: the relying party MUST decide explicitly to waive the cap and MUST establish that the issuer key was trusted at `iat`, rejecting the attestation with `TCT_SIGNATURE_INVALID` when it cannot (§5.3). A far-future `exp` is not evidence of validity.

---

## 11. Peer-Issued TCT Verification API

Each agent that issues TCTs exposes the following HTTPS operations for peers to verify and manage revocation of its TCTs. Only `ListRevoked` is REQUIRED:

| Operation | Method | Requirement | Description |
|---|---|---|---|
| `ListRevoked` | GET | MUST | Returns the issuing peer's signed revocation snapshot (RFC-AITP-0008 §1.5). |
| `Verify` | POST | MAY | Convenience verification — consuming peer can verify locally using only the issuing peer's Manifest key, but MAY call this for a freshness check. |
| `Revoke` | POST | MAY | Admin-only; adds a `jti` to the issuing peer's deny list. An administrative surface of the issuing deployment, not a peer-protocol operation. |

**Advertisement.** An issuing peer MUST advertise its `ListRevoked` URL in its Manifest's `extensions` under the registered key `rfc-aitp-0008.revocation_list_uri` ([`registries/extension-keys.md`](../registries/extension-keys.md); RFC-AITP-0012). The value is an HTTPS URL. This is how consuming peers locate the snapshot they poll (RFC-AITP-0008 §1.4). The obligation is on the issuer: a verifier MUST NOT reject a Manifest solely because the key is absent. It treats the issuer's revocation status as unavailable and applies its configured revocation policy (RFC-AITP-0008 §3).

A peer that exposes `Verify` MAY advertise it under `rfc-aitp-0005.verify_uri`. Concrete URL paths for all three operations are deployment-defined; request and response bodies for `Verify` and `Revoke` are not pinned by this RFC.

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
