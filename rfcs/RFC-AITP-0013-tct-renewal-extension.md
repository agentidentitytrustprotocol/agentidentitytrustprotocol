# RFC-AITP-0013
# TCT Renewal Extension

**Document:** RFC-AITP-0013
**Version:** 0.3.0-draft
**Status:** Community Standards Track (Draft)
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md), [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md), [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md), [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md), [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)

---

> **Status: Draft.** This RFC replaces the non-normative sketch that RFC-AITP-0004 §8.1 carried through `0.3.4-draft`. It is opt-in and additive: it changes no message type, field, signing input or error code of RFC-AITP-0001 to RFC-AITP-0009, so it sits inside the `aitp/0.3` freeze ([`VERSIONING.md` § What is frozen](../VERSIONING.md#what-is-frozen-aitp03-line)). Its wire format, its known-answer vectors and its fixtures may still change while it is Draft.

> **Conformance scope.** RFC-AITP-0013 is **not part of AITP core
> conformance**. Implementations MUST NOT fail core conformance because
> they do not implement renewal. Conformance runners MUST treat the
> `ren-*` fixture set in [`schemas/conformance/`](../schemas/conformance/)
> as SKIP unless the runner is explicitly opted into this RFC (every
> renewal fixture carries `status: "draft"` and
> `feature: "experimental-renewal"`; see
> [`schemas/conformance/README.md`](../schemas/conformance/README.md)).
>
> The requirements below (MUST, SHALL, etc.) apply only to an
> implementation that offers or uses renewal. A core-only implementation
> renews by running a fresh Mutual Handshake (RFC-AITP-0004 §8) and is
> conformant.

---

## Abstract

A TCT expires at its `exp` (RFC-AITP-0005 §9). The core way to keep a trust relationship going is a fresh Mutual Handshake (RFC-AITP-0004 §8). This RFC defines a shorter exchange for the case where the holder already has a TCT from the issuer and wants a replacement: the holder sends its current TCT and a proof of possession of the subject key, and the issuer, after re-running its checks, answers with a new TCT in a signed envelope.

Renewal does not re-verify the holder's identity binding (RFC-AITP-0002). It re-uses the binding the issuer verified when it issued the current TCT, which is carried in the TCT's `sub` and `cnf`. A deployment that wants identity re-verified at every renewal runs a fresh handshake instead.

---

## 1. Conventions and roles

The key words MUST, MUST NOT, REQUIRED, SHALL, SHOULD, SHOULD NOT, RECOMMENDED, MAY and OPTIONAL are to be interpreted as described in BCP 14 (RFC 2119, RFC 8174) when, and only when, they appear in all capitals.

- **Issuer** — the agent that issued the current TCT (its `iss`), and that issues the renewed one.
- **Holder** — the agent the current TCT was issued to (its `sub`, which equals its `aud`, RFC-AITP-0005 §2).
- **Current TCT** — the TCT the holder presents for renewal.
- **Renewed TCT** — the TCT the issuer returns.

Byte strings are written as in RFC-AITP-0002 §3.1: `||` is concatenation, a quoted string is its ASCII bytes, and `\0` is one `0x00` byte.

---

## 2. Discovery

An issuer that offers renewal MUST advertise the HTTPS endpoint at which it accepts renewal requests in its Manifest, under the extension key `rfc-aitp-0005.renew_uri` ([`registries/extension-keys.md`](../registries/extension-keys.md)). The value is the actual endpoint; there is no reserved path. `/aitp/handshake/renew` is used in this document's examples only.

- Renewal MUST be gated behind an explicit feature or configuration opt-in on both sides.
- A holder MUST read `renew_uri` from the issuer's current, verified Manifest (RFC-AITP-0003 §5).
- A holder whose issuer's Manifest does not carry `rfc-aitp-0005.renew_uri` MUST renew with a fresh Mutual Handshake. It MUST NOT probe a guessed path: the absence of the key is the signal, not the HTTP response from a guess.
- The endpoint MUST be HTTPS, except in the localhost development mode of [`registries/extension-keys.md`](../registries/extension-keys.md#rules).

---

## 3. Renewal request

The holder sends the request as the body of an HTTPS `POST` to `renew_uri`, with media type `application/json`. The body is a JSON object with exactly these members. It is not an envelope.

```json
{
  "current_tct": "<compact JWS string: aitp-tct+jwt>",
  "pop_nonce": "<22-char unpadded base64url>",
  "pop_signature": "<renewal PoP signature, §3.1>"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `current_tct` | string | REQUIRED | The current TCT, verbatim, as the opaque compact JWS string the issuer sent (RFC-AITP-0001 §5.4.5). |
| `pop_nonce` | string | REQUIRED | A fresh nonce chosen by the holder: 16 bytes from a CSPRNG, as 22 unpadded base64url characters (RFC-AITP-0001 §5.4.2). A holder MUST use a new nonce for every request. |
| `pop_signature` | string | REQUIRED | The renewal PoP signature of §3.1, by the key encoded in the current TCT's `sub`. |

The schema is `$defs/RenewalRequest` in [`schemas/json/aitp-tct-renewal.schema.json`](../schemas/json/aitp-tct-renewal.schema.json).

### 3.1 Renewal PoP input

```
renewal_pop_input =
    "aitp-renewal-pop-v1\0"
    || issuer_aid_bytes        || "\0"
    || current_tct_jti_bytes   || "\0"
    || pop_nonce_decoded_bytes
pop_signature = base64url(sign(holder_private_key, sha256(renewal_pop_input)))
```

Where:

- `"aitp-renewal-pop-v1\0"` is the 19 ASCII bytes `aitp-renewal-pop-v1` followed by one `0x00` byte.
- `issuer_aid_bytes` is the UTF-8 encoding of the current TCT's `iss` claim exactly as written in the token. It is not rewritten to another form of the same key (RFC-AITP-0001 §5.3): an untagged and an `ed25519:`-tagged spelling of one key give different inputs.
- `current_tct_jti_bytes` is the UTF-8 encoding of the current TCT's `jti` claim: 36 ASCII bytes in the RFC-AITP-0005 §2.2 layout.
- `pop_nonce_decoded_bytes` is the 16 raw bytes obtained by base64url-decoding the request's `pop_nonce`, NOT the base64url string itself (RFC-AITP-0001 §5.4.2).
- `\0` is a single `0x00` byte. There is no separator after the last field.

With an untagged Ed25519 issuer AID the input is 20 + 54 + 1 + 36 + 1 + 16 = 128 bytes.

`pop_signature` uses the JCS-profile signature wire format of [RFC-AITP-0001 §5.4.3](RFC-AITP-0001-core.md#543-algorithm-tagged-signature-wire-format-jcs-profile-only), with the primitive of [§5.4.6](RFC-AITP-0001-core.md#546-signing-primitive-per-algorithm-jcs-profile-and-proofs), exactly as the pinned-key `proof` of RFC-AITP-0002 §3.1 does:

- `sha256(renewal_pop_input)` is the digest `d`, hashed exactly once. An Ed25519 key signs `d` as its message; a P-256 key uses `d` directly as the ECDSA hashed message (`e = d`) and MUST NOT hash it again.
- A holder whose `sub` AID is `p256` MUST emit the tagged form `p256.<86-char-b64url>`.
- A holder whose `sub` AID is `ed25519` MAY emit either the untagged form or `ed25519.<86-char-b64url>`.
- The tag MUST match the algorithm of the `sub` AID, per RFC-AITP-0001 §5.4.3 rule 3. An untagged signature is read as `ed25519`.

> **Known-answer test.** `kat-renewal-pop-001` in [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json) pins an `(iss, jti, pop_nonce)` triple taken from the committed TCT [`signed-examples/tct/kat-keypair-001-issues-002.json`](../schemas/conformance/known-answer/signed-examples/tct/kat-keypair-001-issues-002.json), the 128-byte `renewal_pop_input` in hex, its SHA-256 digest, and the Ed25519 signature by `kat-keypair-002`, the holder. `kat-renewal-pop-002-p256` pins the same input signed by `kat-keypair-005-p256` in the `p256.` form, with a double-hash signature that MUST NOT verify. Both vectors carry `"draft": true` and stay outside the frozen known-answer set until this RFC reaches Release Candidate.

---

## 4. Issuer processing

An issuer that receives a renewal request MUST run these steps in order and stop at the first failure.

1. **Parse the request.** It MUST be a JSON object with exactly the three members of §3, each a string. `pop_nonce` MUST be 22 unpadded base64url characters that decode to 16 bytes, under the strict decoding of RFC-AITP-0001 §5.4.5. Any other request ⇒ `POP_RESPONSE_INVALID`.
2. **Verify `current_tct` as its issuer**, by RFC-AITP-0005 §7.2 steps 1 to 5 in order, with that section's codes, and with these readings:
   - `iss` MUST equal the issuer's own AID, and the signature MUST verify under the issuer's own key (RFC-AITP-0005 §10.5 item 1). A TCT issued by any other peer ⇒ `TCT_SIGNATURE_INVALID`.
   - Step 5's audience check is read from the issuer's side, as in RFC-AITP-0005 §10.5 item 2: `aud` MUST equal `sub`; otherwise ⇒ `TCT_SIGNATURE_INVALID`. The grant-context checks of RFC-AITP-0005 §5.3 apply: a self-issued TCT, or one carrying the `aitp.attestation` marker grant, ⇒ `TCT_SIGNATURE_INVALID`.
   - `exp` MUST be in the future. An expired TCT MUST NOT be renewed ⇒ `TCT_EXPIRED`.
   - `exp` MUST NOT exceed the `expires_at` of the issuer's current Manifest (RFC-AITP-0005 §10.4, which is unconditional here: the issuer always has its own Manifest) ⇒ `TCT_EXPIRES_AFTER_MANIFEST`.
3. **Verify the renewal PoP.** Rebuild `renewal_pop_input` (§3.1) from the verified `iss` and `jti` of `current_tct` and the decoded `pop_nonce`, and verify `pop_signature` against the key encoded in the TCT's `sub`, per RFC-AITP-0001 §5.4.3 and §5.4.6. The issuer MUST NOT take the input's fields from anywhere else. Failure, including a valid signature by any key other than the one in `sub`, ⇒ `POP_RESPONSE_INVALID`.
4. **Check revocation.** Look up `jti` in the issuer's own deny list (RFC-AITP-0008), after every signature check above (RFC-AITP-0008 §3.3). A revoked TCT MUST NOT be renewed ⇒ `TCT_REVOKED`.
5. **Check and record the nonce.** If this issuer has already accepted a renewal request with this `pop_nonce`, the request is a replay ⇒ `REPLAY_DETECTED`. Otherwise the issuer records the nonce (§5) and continues.
6. **Re-evaluate grants.** The renewed grants are the current TCT's `grants` intersected with the `offered_capabilities` of the issuer's current Manifest (RFC-AITP-0004 §4.1), then narrowed by the issuer's grant policy for the holder. The renewed grants MUST be a subset of the current TCT's `grants`: renewal never widens them, whatever the Manifest now offers. An empty result, or an issuer policy that refuses renewal to this holder, ⇒ `POLICY_VIOLATION`.
7. **Mint the renewed TCT** per RFC-AITP-0004 §4 and RFC-AITP-0005:
   - `iss`, `sub`, `aud` and `cnf` equal the current TCT's;
   - `jti` is new (RFC-AITP-0005 §2.2) and MUST differ from the current TCT's;
   - `iat` is the issuer's current time;
   - `grants` are the result of step 6;
   - `exp` MUST NOT exceed the `expires_at` of the issuer's current Manifest (RFC-AITP-0004 §4.3). An issuer caps the lifetime it would otherwise grant at that value rather than refusing.
8. **Mint the companion grant voucher**, per issuer policy, under RFC-AITP-0005 §8.2: `src_jti` is the renewed TCT's `jti`. An issuer MAY omit it, as in the handshake (RFC-AITP-0004 §4.5).
9. **Respond** with the renewal response envelope of §6.

Renewal re-runs every check the issuer applies at issuance. It is not a bypass for revocation, Manifest rotation, trust-anchor changes or grant policy.

---

## 5. Nonce store

The issuer keeps a store of the `pop_nonce` values it has accepted for renewal.

- A nonce is recorded only by step 5 of §4, so only a request whose TCT and PoP have verified reaches the store.
- An entry is the decoded nonce; the issuer MAY record the holder's `sub` and the current TCT's `jti` beside it. It MUST be retained at least until the current TCT's `exp`. After that the current TCT can no longer be renewed (§4 step 2), so the entry may go.
- An issuer that runs several replicas MUST share one store across them, or the replay check holds per replica only.
- A store failure MUST fail the request closed. The issuer answers with a retryable error envelope and does not mint.

Nonces in this store are separate from the envelope `message_id` deny list of RFC-AITP-0001 §5.5 and from any other nonce store.

---

## 6. Renewal response

The issuer answers every request it processes with an RFC-AITP-0001 envelope, as the body of the HTTP response with media type `application/json`.

- A successful renewal is an envelope with `message_type` `tct` ([`registries/message-types.md`](../registries/message-types.md)), `sender.agent_id` equal to the current TCT's `iss`, signed by the issuer under RFC-AITP-0001 §5.4, with a fresh `message_id` and the issuer's current `timestamp`.
- A refused renewal is an error envelope (RFC-AITP-0001 §5.6) carrying the code of the failing step of §4.

The payload of a `tct` renewal response is a JSON object with exactly these members:

```json
{
  "tct": "<compact JWS string: aitp-tct+jwt>",
  "grant_voucher": "<compact JWS string: aitp-grant+jwt>",
  "pop_nonce_echo": "<the request's pop_nonce>"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `tct` | string | REQUIRED | The renewed TCT, as an opaque compact JWS string, embedded verbatim (RFC-AITP-0004 §2). |
| `grant_voucher` | string | OPTIONAL | The renewed TCT's companion grant voucher (§4 step 8), embedded verbatim. |
| `pop_nonce_echo` | string | REQUIRED | The request's `pop_nonce`, byte for byte. |

The schema is `$defs/RenewalResponsePayload` in [`schemas/json/aitp-tct-renewal.schema.json`](../schemas/json/aitp-tct-renewal.schema.json).

The HTTP status code is informative. An issuer SHOULD answer a `tct` envelope with `200` and an error envelope with a `4xx` status, or `503` for a retryable failure. A holder MUST decide from the envelope, not from the status.

### 6.1 Holder verification

A holder that receives a `tct` renewal response MUST run these steps in order and stop at the first failure. It MUST NOT use the renewed TCT until every step has passed.

1. **Verify the envelope** per RFC-AITP-0001 §5: schema, `version`, the timestamp window and `message_id` deduplication (§5.5), and the signature under the key of `sender.agent_id` (§5.4), with those sections' codes. `message_type` MUST be `tct` or `error` ⇒ otherwise `INVALID_ENVELOPE`.
2. **Check the sender.** `sender.agent_id` MUST equal the current TCT's `iss`, byte for byte ⇒ otherwise `PEER_MISMATCH`.
3. **Check the echo.** `pop_nonce_echo` MUST equal the `pop_nonce` the holder sent in this request ⇒ otherwise `NONCE_MISMATCH`.
4. **Verify the renewed TCT** by RFC-AITP-0005 §7.2 as its audience, with that section's codes: `aud` equals the holder's own AID. Its `iss` MUST equal the current TCT's `iss` ⇒ otherwise `TCT_SIGNATURE_INVALID`. When the issuer's Manifest is available, RFC-AITP-0005 §10.4 applies ⇒ `TCT_EXPIRES_AFTER_MANIFEST`.
5. **Check the subject.** `sub` MUST equal the holder's own AID and `cnf.jkt` MUST equal the current TCT's ⇒ otherwise `AUDIENCE_MISMATCH`.
6. **Check the grants.** Every grant in the renewed TCT MUST be in the current TCT's `grants` ⇒ otherwise `GRANT_OVERFLOW`. A renewed TCT with fewer grants is valid: the issuer narrowed them (§4 step 6).

If the payload carries `grant_voucher`, the holder stores it verbatim beside the renewed TCT, as in RFC-AITP-0004 §5.3. It MAY check the RFC-AITP-0005 §8.2 consistency rules before relying on it.

A holder that receives an error envelope verifies it under step 1 and step 2 before acting on its code. It then either keeps the current TCT until its `exp` or runs a fresh Mutual Handshake.

---

## 7. The current TCT after renewal

- Renewal does not revoke the current TCT. It stays valid until its own `exp` unless the issuer revokes it. The issuer MAY add its `jti` to its deny list (RFC-AITP-0008) once it has issued the replacement.
- The holder SHOULD use the renewed TCT from the moment it accepts it, and SHOULD discard the current one then.
- A grant voucher, and every delegation derived from it, rides on its `src_jti` (RFC-AITP-0005 §8.2, §9). A voucher bound to the current TCT's `jti` does not transfer to the renewed TCT; the holder delegates afresh under the renewed voucher.
- A holder MAY renew a renewed TCT. Each renewal is a separate request with its own nonce, against the TCT it then holds.

---

## 8. Error codes

Renewal registers no new error code. It uses these existing codes from [`registries/error-codes.md`](../registries/error-codes.md), with the renewal meaning given in its "TCT renewal codes" table:

| Code | Raised by | Step |
|---|---|---|
| `POP_RESPONSE_INVALID` | Issuer | §4 step 1 (malformed request), step 3 (PoP) |
| `TCT_SIGNATURE_INVALID`, `TOKEN_TYP_MISMATCH`, `TOKEN_ALG_MISMATCH`, `UNKNOWN_FIELD`, `TCT_EXPIRED`, `TCT_EXPIRES_AFTER_MANIFEST` | Issuer, holder | §4 step 2, §6.1 step 4 (RFC-AITP-0005 §7.2, §10.4) |
| `TCT_REVOKED` | Issuer | §4 step 4 |
| `REPLAY_DETECTED` | Issuer | §4 step 5 |
| `POLICY_VIOLATION` | Issuer | §4 step 6 |
| `INVALID_ENVELOPE`, `INVALID_SIGNATURE`, `TIMESTAMP_EXPIRED` | Holder | §6.1 step 1 (RFC-AITP-0001 §5) |
| `PEER_MISMATCH` | Holder | §6.1 step 2 |
| `NONCE_MISMATCH` | Holder | §6.1 step 3 |
| `AUDIENCE_MISMATCH` | Holder | §6.1 step 5 |
| `GRANT_OVERFLOW` | Holder | §6.1 step 6 |

`REPLAY_DETECTED` on the holder side keeps its RFC-AITP-0001 §5.5 meaning: a duplicate response `message_id`.

An issuer that does not offer renewal has no endpoint and answers nothing (§2). There is no "renewal not supported" code: an issuer that offers renewal but refuses it to a given holder by policy answers `POLICY_VIOLATION`.

---

## 9. Conformance

The `ren-*` fixtures in [`schemas/conformance/`](../schemas/conformance/) carry `status: "draft"`, `feature: "experimental-renewal"` and `required_for_core: false`. They use two operations ([`PLACEHOLDERS.md`](../schemas/conformance/PLACEHOLDERS.md#operation-key)):

- `renew_tct` runs §4 as the issuer, `kat-keypair-001`, against the committed TCT that it issued to `kat-keypair-002`. Every `pop_signature` is a real signature, committed in the fixture.
- `verify_renewal_response` runs §6.1 as the holder, `kat-keypair-002`.

| ID | Checks | Outcome |
|---|---|---|
| `ren-001` | Valid request; the renewed TCT keeps `iss`, `sub`, `aud`, `cnf` and `grants` and has a new `jti` | success |
| `ren-002` | The current TCT's `jti` is in the issuer's deny list (§4 step 4) | failure: TCT_REVOKED |
| `ren-003` | The issuer's Manifest expires before the requested lifetime ends; the renewed `exp` is capped at Manifest `expires_at` (§4 step 7) | success |
| `ren-004` | The same request sent twice (§4 step 5) | step 1 success, step 2 failure: REPLAY_DETECTED |
| `ren-005` | A valid `pop_signature` by a key other than the one in `sub` (§4 step 3) | failure: POP_RESPONSE_INVALID |
| `ren-006` | `pop_signature` over the input of §3.1 built with another `jti` (§4 step 3) | failure: POP_RESPONSE_INVALID |
| `ren-007` | `pop_signature` over the input of §3.1 built with another issuer AID (§4 step 3) | failure: POP_RESPONSE_INVALID |
| `ren-008` | The issuer's Manifest now offers more than the current TCT grants; the renewed grants stay the current ones (§4 step 6) | success |
| `ren-009` | The issuer's Manifest no longer offers the current TCT's grant (§4 step 6) | failure: POLICY_VIOLATION |
| `ren-010` | The holder accepts a valid renewal response (§6.1) | success |
| `ren-011` | The renewed TCT carries a grant the current TCT does not (§6.1 step 6) | failure: GRANT_OVERFLOW |
| `ren-012` | The current TCT has expired (§4 step 2) | failure: TCT_EXPIRED |

---

## 10. Security considerations

| Threat | Mitigation |
|---|---|
| A party without the subject key asks for a TCT in the holder's name. | The renewal PoP verifies only under the key in the current TCT's `sub` (§4 step 3), and the renewed TCT keeps the current `sub` and `cnf` (§4 step 7). |
| A captured renewal request is sent again. | The issuer accepts each `pop_nonce` once, for as long as the current TCT could be renewed (§4 step 5, §5). |
| Renewal is used to keep a TCT alive past revocation, Manifest rotation or a policy change. | The issuer re-runs revocation, the Manifest bound and grant policy on every request (§4 steps 2, 4 and 6). An expired TCT cannot be renewed. |
| Renewal widens the holder's grants. | The renewed grants are a subset of the current ones (§4 step 6), and the holder rejects a renewed TCT that carries more (§6.1 step 6). |
| A forged or replayed response gives the holder a TCT the issuer did not send for this request. | The response is an envelope signed by the issuer and replay-protected (RFC-AITP-0001 §5.4, §5.5), sent by the AID that issued the current TCT, and it echoes the request's nonce (§6.1 steps 1 to 3). |
| The renewal endpoint is flooded. | The endpoint is an issuance surface and falls under the rate limiting of RFC-AITP-0009 §3.1. The nonce store holds only nonces of requests whose TCT and PoP verified (§5), so a flood of invalid requests does not fill it. |
| Renewal extends trust without re-verifying identity. | By design: renewal carries forward the binding verified at issuance, bounded by the Manifest `expires_at` (§4 step 7). A deployment that needs fresh identity proof runs a full handshake (Abstract). |

The request is not an envelope. In transit it is protected by HTTPS, and `pop_signature` does not cover the HTTP request itself.

---

## 11. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0002 Identity](RFC-AITP-0002-identity.md) §3.1 (the pinned-key `proof_input`, whose conventions §3.1 follows)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0005 Trust Context Token](RFC-AITP-0005-tct.md)
- [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
- [registries/extension-keys.md](../registries/extension-keys.md)
- [schemas/json/aitp-tct-renewal.schema.json](../schemas/json/aitp-tct-renewal.schema.json)
