# Integration Guide

How a peer agent consumes a peer-issued Trust Context Token (TCT) — the
common case in AITP v0.1.

---

## What you need

- The peer's signed Manifest (RFC-AITP-0003), fetched from
  `https://<peer-host>/.well-known/aitp-manifest` and verified.
- Your own AID (the peer-issued TCT will name you as `subject` and `audience`).

That's it. There is no third-party verifier, no separate token-introspection
call, no shared secret.

---

## Step 1: Receive the TCT

In a typical flow you already hold the TCT from the Mutual Handshake (RFC-
AITP-0004 §3.4): the peer delivered it inline, verbatim, as the `tct` field
of `MUTUAL_COMMIT_ACK` — a compact JWS string, never decoded-and-re-encoded
by the envelope layer. If you need to forward a TCT to a downstream
consumer, pass the compact JWS itself in a request header or metadata
field; it is already transport-safe verbatim (RFC-AITP-0001 §5.4.5) — no
extra encoding layer is needed:

```
x-aitp-tct: <compact JWS>
```

---

## Step 2: Verify locally

```python
# Pseudocode. Notes below the snippet matter.
import time
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

# A TCT is a compact JWS (RFC-AITP-0005 §1): three base64url segments
# joined by `.`. There is NO canonicalization step and nothing to strip —
# the signature covers the exact transmitted `header.payload` bytes
# (RFC-AITP-0005 §7.1). Do not reach for a JCS library here: that profile
# governs the Manifest and the revocation snapshot (RFC-AITP-0001 §5.4.1),
# never the TCT.

# AITP base64url is unpadded (RFC 4648 §5); a JWS segment carrying `=`
# padding or any character outside `[A-Za-z0-9_-]` MUST be rejected, not
# normalized. For the header and payload segments the base64url TEXT
# itself is part of the signing input, so silently normalizing it would
# verify a different byte sequence than what was actually signed
# (RFC-AITP-0001 §5.4.5 "Strict parsing").
def b64url_decode_strict(s: str) -> bytes:
    if "=" in s:
        raise ValueError("base64url padding is forbidden in AITP")
    pad = (-len(s)) % 4
    return base64.urlsafe_b64decode(s + ("=" * pad))  # padding only for the decoder, never accepted on input

# The sole acceptable `alg` is derived from the issuer AID's method, never
# read from the token itself — this is what forecloses `alg: none` and
# algorithm-confusion attacks (RFC-AITP-0001 §5.4.5 "Algorithm pinning").
def expected_alg_for_aid(aid: str) -> str:
    if not aid.startswith("aid:pubkey:"):
        raise ValueError(f"unsupported AID method: {aid}")
    rest = aid[len("aid:pubkey:"):]
    if rest.startswith("p256:"):
        return "ES256"
    if rest.startswith("ed25519:") or len(rest) == 43:  # legacy untagged form == Ed25519 (RFC-AITP-0001 §5.3)
        return "EdDSA"
    raise ValueError(f"unsupported AID method: {aid}")

def verify_tct(tct_jws: str, issuer_aid: str, issuer_pubkey: Ed25519PublicKey, my_aid: str) -> list[str]:
    # 1. Strict-parse: exactly three non-empty, dot-separated base64url
    #    segments (RFC-AITP-0005 §7.2 step 1) — no unsecured JWS, no
    #    detached payload, no JSON serialization.
    parts = tct_jws.split(".")
    if len(parts) != 3 or not all(parts):
        raise ValueError("malformed compact JWS")
    header_b64, payload_b64, sig_b64 = parts

    header = json.loads(b64url_decode_strict(header_b64))

    # 2. Enforce `typ` (RFC-AITP-0005 §7.2 step 2).
    if header.get("typ") != "aitp-tct+jwt":
        raise ValueError("TOKEN_TYP_MISMATCH")

    # 3. Pin `alg` from the issuer AID and reject everything else,
    #    including "none" (RFC-AITP-0005 §7.2 step 3).
    if header.get("alg") != expected_alg_for_aid(issuer_aid):
        raise ValueError("TOKEN_ALG_MISMATCH")
    if set(header) != {"alg", "typ"}:
        raise ValueError("protected header must contain exactly alg and typ")

    # 4. Verify the signature over the exact transmitted bytes — NOT a
    #    re-canonicalized or re-serialized form. There is no
    #    canonicalization step for a compact JWS (RFC-AITP-0005 §7.1).
    signing_input = f"{header_b64}.{payload_b64}".encode("ascii")
    sig = b64url_decode_strict(sig_b64)
    issuer_pubkey.verify(sig, signing_input)  # raises on failure

    # 5. Only now decode and validate claims (RFC-AITP-0005 §7.2 step 5) —
    #    nothing above this line is trusted before the signature checks out.
    claims = json.loads(b64url_decode_strict(payload_b64))

    assert claims["ver"] == "aitp/0.2", "Unknown version"
    assert claims["exp"] > time.time(), "TCT expired"
    assert claims["aud"] == my_aid, "Audience mismatch"  # no wildcards (RFC-AITP-0005 §5.1)

    # `cnf.jkt` MUST match the thumbprint of the key encoded in `sub` — the
    # verifier derives the EXPECTED thumbprint from `sub` itself and never
    # trusts `cnf.jkt` as freestanding (RFC-AITP-0001 §5.4.4). Pinned
    # thumbprint vectors are at schemas/conformance/known-answer/jwk-thumbprints.json.
    if claims["cnf"]["jkt"] != jwk_thumbprint_from_aid(claims["sub"]):
        raise ValueError("cnf.jkt does not match sub")

    # 6. Reject any unknown top-level claim outside the `ext` slot
    #    (RFC-AITP-0001 §5.4.5 "Strict parsing"). Silently ignoring unknown
    #    claims would create signature-scope ambiguity across implementations.
    KNOWN = {"ver", "jti", "iss", "sub", "aud", "iat", "exp", "grants", "cnf", "ext"}
    unknown = set(claims) - KNOWN
    assert not unknown, f"Unknown TCT claims: {unknown}"

    return claims["grants"]
```

Both `issuer_aid` and `issuer_pubkey` come from the issuing peer's
`manifest.aid` (`aid:pubkey:ed25519:<43-char-base64url>`, or the legacy
untagged `aid:pubkey:<43-char-base64url>` form → decode → 32-byte raw
Ed25519 public key, loaded via `Ed25519PublicKey.from_public_bytes()`).
`issuer_aid` is what `expected_alg_for_aid()` pins the header `alg`
against — the algorithm is never read from the token itself. A P-256
issuer AID (`aid:pubkey:p256:<44-char-base64url>`) carries the same shape
with `ES256` / SEC1-compressed key material instead; this walkthrough
sticks to the Ed25519 case for brevity (RFC-AITP-0001 §5.3).

> **Also check the Manifest-expiry bound when you can.** If you hold the
> issuing peer's Manifest — you do immediately after a Mutual Handshake,
> where it is exchanged inline — additionally verify
> `claims["exp"] <= issuer_manifest["expires_at"]` and reject with
> `TCT_EXPIRES_AFTER_MANIFEST` on violation
> ([RFC-AITP-0005 §10.4](../rfcs/RFC-AITP-0005-tct.md#104-manifest-expiry-bound-conditional)).
> A peer-issued TCT must not outlive the Manifest credential that
> authenticates its issuer's key. This check is conditional — skip it if
> the issuer Manifest is not on hand; do not fetch it solely for this
> purpose. The Step 2 expiry check (`exp` in the future) always
> applies regardless.

---

## Step 3: Enforce grants

```python
def check_grant(grants: list[str], required: str) -> None:
    if required not in grants:
        raise PermissionError(f"Grant '{required}' not present in TCT")
```

---

## Proof-of-possession

`cnf` — specifically `cnf.jkt`, the RFC 7638 thumbprint of the subject's
public key — is required on every v0.2 peer-issued TCT (RFC-AITP-0005 §3).
There is no bearer-TCT profile. The v0.1 raw-public-key `binding.cnf` form
does **not** appear in v0.2 tokens (RFC-AITP-0001 §5.4.4) — if you are
looking for it on a v0.2 TCT's claims, it is not there; use `cnf.jkt`.
Whether to verify PoP at consumption time is governed by the issuing
peer's per-grant policy (RFC-AITP-0005 §6): consumers MUST verify PoP for
any grant the issuing peer marks as requiring it, and SHOULD verify PoP for
all grants unless the deployment provides equivalent channel binding (mTLS
with bound client certs, an authenticated message bus, etc.).

The RECOMMENDED marking convention is a `#pop_required` suffix on the
grant string (`<capability>#pop_required`): a consumer that recognizes the
suffix MUST run the challenge/response below before authorizing that grant,
and MUST reject the invocation if no valid `pop_response` arrives within the
challenge's freshness window (RFC-AITP-0005 §6).

To verify PoP, send a fresh challenge nonce (via `pop_challenge` envelope),
ask the peer to sign `sha256(base64url_decode(nonce))` — the holder MUST
hash the **decoded raw bytes** of the nonce, never the base64url ASCII
string (the unified PoP signing-input convention is in
[RFC-AITP-0001 §5.4.2](../rfcs/RFC-AITP-0001-core.md#542-pop-signing-input-convention))
— then verify `pop_signature` against the subject's public key, i.e. the
key encoded in the TCT's `sub` AID, and confirm `cnf.jkt` equals that same
key's RFC 7638 thumbprint (RFC-AITP-0005 §6.2). `pop_signature` is a raw
Ed25519/ECDSA signature over a hash, not a JCS-canonicalized object — it
was never JCS-signed JSON, in v0.1 or v0.2, so there is nothing here to
canonicalize; do not reuse the TCT's (JWS) verification code path for it,
and do not reach for JCS either. The Mutual Handshake's round-2 PoP
exchange already binds the TCT to a live key — downstream PoP is the same
proof, repeated when a TCT is presented after the handshake.

---

## Delegating verification to the issuing peer

If you prefer to delegate verification to the issuing peer instead of
verifying locally, you can POST to the issuing peer's `Verify` endpoint
(RFC-AITP-0005 §10). The endpoint's URL path and request/response shape
are **deployment-defined in v0.1** — the RFC names the operation but does
not pin a wire format. The example below is non-normative; consult the
issuing peer's published API contract:

```json
{
  "tct_token": "<base64url TCT>",
  "expected_audience": "aid:pubkey:11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo",
  "required_grants": ["macp.mode.task.v1"]
}
```

On success, the response typically carries the verified grants list. The
issuing peer is authoritative for revocation, so this also serves as a
freshness check.

---

## Pairing with MACP

A common pairing is using AITP to authorize calls into a MACP runtime
(see the [Multi-Agent Coordination Protocol](https://github.com/multiagentcoordinationprotocol/multiagentcoordinationprotocol)).

The short version:
- TCT arrives via `x-aitp-tct` HTTP header or as part of a Mutual Handshake.
- The MACP runtime maps `grants` to `allowed_modes` for session participation.
- AITP is the trust layer; MACP is the coordination layer; they compose.

---

## See also

- [Architecture overview](architecture.md)
- [RFC-AITP-0005 Trust Context Token](../rfcs/RFC-AITP-0005-tct.md)
- [Examples](../examples/)
