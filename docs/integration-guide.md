# Integration Guide

How a peer agent consumes a peer-issued Trust Context Token (TCT) — the
common case in AITP v0.2. This page sequences the normative rules and
points at maintained code; the rules themselves live in
[RFC-AITP-0005](../rfcs/RFC-AITP-0005-tct.md), and SDK usage lives in the
sibling repositories listed in [`docs/ecosystem.md`](ecosystem.md).

---

## What you need

- The issuing peer's signed Manifest (RFC-AITP-0003), fetched from
  `https://<peer-host>/.well-known/aitp-manifest` and verified. Its `aid`
  carries the issuer's public key (RFC-AITP-0007 §1).
- Your own AID. A peer-issued TCT names its subject in the `sub` claim and
  its intended consumer in the `aud` claim, and `aud` MUST equal `sub`
  (RFC-AITP-0005 §2); you check `aud` against your own AID (§5.2).

That's it. There is no third-party verifier, no separate token-introspection
call, no shared secret.

---

## Step 1: Receive the TCT

In a typical flow you already hold the TCT from the Mutual Handshake: the
peer delivered it inline, verbatim, as the `tct` field of its round-2
commit payload — `MUTUAL_COMMIT` (RFC-AITP-0004 §3.3) when the initiator
issues, `MUTUAL_COMMIT_ACK` (§3.4) when the target issues. Both payloads
may also carry an OPTIONAL companion `grant_voucher` (RFC-AITP-0005 §8):
store it verbatim alongside the TCT if you may later delegate; without it
you cannot (RFC-AITP-0006).

A TCT is a compact JWS string and is transport-safe verbatim
(RFC-AITP-0001 §5.4.5). To present it to a downstream consumer over HTTP,
the non-normative carriage convention in
[`registries/media-types.md`](../registries/media-types.md) is:

```
x-aitp-tct: <compact JWS>
```

No extra encoding layer is applied.

---

## Step 2: Verify locally

Run the RFC-AITP-0005 §7.2 verification order. The step numbers below are
the RFC's own (they are cited by other RFCs and fixtures), listed in
**execution order** — the RFC places step 1's claims-membership clause
after step 2:

1. **Step 1, segments** — exactly three non-empty, `.`-separated segments
   in the unpadded base64url alphabet; no `=` padding, no normalization
   (RFC-AITP-0001 §5.4.5 "Strict parsing").
2. **Step 2, `typ`** — the header `typ` MUST be exactly `aitp-tct+jwt`,
   otherwise `TOKEN_TYP_MISMATCH`.
3. **Step 1, claims membership** — the decoded claims may contain only the
   claims registered in RFC-AITP-0005 §2; any other claim outside `ext`
   ⇒ `UNKNOWN_FIELD`. Unknown keys *inside* `ext` are ignored. The
   payload must also be a JSON object with no duplicate keys
   (RFC-AITP-0001 §5.4.5 "Strict parsing").
4. **Step 3, `alg`** — derive the sole acceptable `alg` from the issuer
   AID in the `iss` claim (`EdDSA` for `aid:pubkey:ed25519:…` and the
   legacy untagged Ed25519 form, `ES256` for `aid:pubkey:p256:…`); any
   other value, including `none`, ⇒ `TOKEN_ALG_MISMATCH`.
5. **Step 4, signature** — verify against the issuer's public key, over
   the exact transmitted `header.payload` bytes. Never re-serialize or
   canonicalize (RFC-AITP-0005 §7.1).
6. **Step 5, claims** — exactly as the RFC lists them: "`ver` known;
   `aud` == own AID; `exp` in the future; `cnf.jkt` matches `sub` (§3);
   grants non-empty." An unknown `ver` ⇒ `UNKNOWN_VERSION`
   (RFC-AITP-0001 §5.4.5); a mismatched `aud` ⇒ `AUDIENCE_MISMATCH`
   (RFC-AITP-0005 §5.2); a past `exp` ⇒ `TCT_EXPIRED`. The expected
   `cnf.jkt` is derived from the key in `sub`, never trusted as
   freestanding (RFC-AITP-0001 §5.4.4).
7. **Step 6, revocation** — only after every check above, look up `jti`
   in the issuer's deny list (RFC-AITP-0008 §3.3); a listed `jti` ⇒
   `TCT_REVOKED` (RFC-AITP-0008 §1.1).

**Protected header.** It MUST contain exactly `alg` and `typ`
(RFC-AITP-0001 §5.4.5); RFC-AITP-0005 §7.2 adds no separate step for this.

**Structural defects.** A payload that does not decode into the expected
claim set (missing or mistyped claim, value outside its grammar) is
rejected with `TCT_SIGNATURE_INVALID`: the compact-JWS artifacts
deliberately collapse structural rejection onto their signature-family
code, while `UNKNOWN_FIELD` wins when an unknown claim is the only defect.
See the structural-rejection table in
[`registries/error-codes.md`](../registries/error-codes.md#structural-rejection).

Do not hand-roll this. Use a maintained implementation:

- **aitp-rs** — [Python SDK](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/sdk-python.md)
  and [Node SDK](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/sdk-node.md)
  (TCT verification sections).
- **aitp-verifier-py** — an independent implementation written from the
  RFCs alone: [`aitp_verifier/tct.py`](https://github.com/agentidentitytrustprotocol/aitp-verifier-py/blob/main/aitp_verifier/tct.py)
  for the §7.2 order and [`aitp_verifier/jws.py`](https://github.com/agentidentitytrustprotocol/aitp-verifier-py/blob/main/aitp_verifier/jws.py)
  for strict compact-JWS parsing.

Pinned compact-JWS vectors to test against are under
[`schemas/conformance/known-answer/signed-examples/`](../schemas/conformance/known-answer/signed-examples/README.md);
thumbprint vectors for the `cnf.jkt` check are in
[`jwk-thumbprints.json`](../schemas/conformance/known-answer/jwk-thumbprints.json).

> **Also check the Manifest-expiry bound when you can.** If you hold the
> issuing peer's Manifest — you do immediately after a Mutual Handshake,
> where it is exchanged inline — additionally verify
> `exp <= issuer_manifest.expires_at` and reject with
> `TCT_EXPIRES_AFTER_MANIFEST` on violation
> ([RFC-AITP-0005 §10.4](../rfcs/RFC-AITP-0005-tct.md#104-manifest-expiry-bound-conditional)).
> This check is conditional — skip it if the issuer Manifest is not on
> hand; do not fetch it solely for this purpose. The step 5 expiry check
> always applies regardless.

---

## Step 3: Enforce grants

Deny any operation whose capability string is not in the TCT's `grants`
(RFC-AITP-0005 §10.1). Grants are flat, additive and opaque to AITP — no
implicit hierarchy (§4.2); their meaning is agreed out of band with the
namespace owner (§4.2.1).

---

## Proof-of-possession

`cnf.jkt` — the RFC 7638 thumbprint of the subject's public key, a
top-level claim — is required on every peer-issued TCT (RFC-AITP-0005 §3).
There is no bearer-TCT profile. Whether to verify PoP at consumption time
is governed by the issuing peer's per-grant policy (RFC-AITP-0005 §6):
consumers MUST verify PoP for any grant the issuing peer marks as
requiring it, and SHOULD verify PoP for all grants unless the deployment
provides equivalent channel binding (mTLS with bound client certs, an
authenticated message bus, etc.).

The RECOMMENDED marking convention is a `#pop_required` suffix on the
grant string (`<capability>#pop_required`): a consumer that recognizes the
suffix MUST run the challenge/response below before authorizing that grant,
and MUST reject the invocation if no valid `pop_response` arrives within the
challenge's freshness window (RFC-AITP-0005 §6).

To verify PoP, send a fresh challenge nonce in a `pop_challenge` envelope
(RFC-AITP-0005 §6.1); the holder signs `sha256(base64url_decode(nonce))` —
the **decoded raw bytes** of the nonce, never the base64url ASCII string
([RFC-AITP-0001 §5.4.2](../rfcs/RFC-AITP-0001-core.md#542-pop-signing-input-convention)).
Then verify `pop_signature` against the key encoded in the TCT's `sub` AID
and confirm `cnf.jkt` equals that key's RFC 7638 thumbprint
(RFC-AITP-0005 §6.2); failure ⇒ `POP_RESPONSE_INVALID`. `pop_signature` is
a raw signature over a hash — do not route it through your JWS or JCS
verification code. The Mutual Handshake's round-2 PoP exchange already
binds the TCT to a live key; downstream PoP is the same proof, repeated
when a TCT is presented after the handshake.

---

## Delegating verification to the issuing peer

Instead of verifying locally, you can ask the issuing peer: an issuer's
`Verify` operation offers convenience verification and a freshness check,
alongside `Revoke` and `ListRevoked`. What the RFCs require of these
issuer operations, and which parts are deployment-defined (concrete URL
paths among them), is stated in
[RFC-AITP-0005 §11](../rfcs/RFC-AITP-0005-tct.md#11-peer-issued-tct-verification-api)
— read it there. No request or response body is pinned by the spec. The
example below is non-normative; consult the issuing peer's published API
contract. Whatever the shape, the token is passed as the compact JWS
string itself:

```json
{
  "tct": "<compact JWS: header.payload.signature>",
  "expected_audience": "aid:pubkey:ed25519:11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo",
  "required_grants": ["macp.mode.task.v1"]
}
```

On success, the response typically carries the verified grants list. The
issuing peer is authoritative for revocation (RFC-AITP-0008 §1.1), so this
also serves as a freshness check.

---

## Pairing with MACP

A common pairing is using AITP to authorize calls into a MACP runtime
(see the [Multi-Agent Coordination Protocol](https://github.com/multiagentcoordinationprotocol/multiagentcoordinationprotocol)).
The `macp.*` capability namespace is reserved for it in
[`registries/capabilities.md`](../registries/capabilities.md).

The short version:
- The TCT arrives via the `x-aitp-tct` HTTP header or from a Mutual Handshake.
- The MACP side maps `macp.*` grants (e.g. `macp.mode.task.v1`) onto what
  the agent may do in a session; that mapping is MACP's, not AITP's.
- AITP is the trust layer; MACP is the coordination layer; they compose.

---

## See also

- [Architecture overview](architecture.md)
- [Ecosystem map](ecosystem.md)
- [RFC-AITP-0005 Trust Context Token](../rfcs/RFC-AITP-0005-tct.md)
- [Examples](../examples/)
