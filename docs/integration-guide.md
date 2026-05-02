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
AITP-0004 §3.4): the peer delivered it inline in `MUTUAL_COMMIT_ACK`. If you
need to forward a TCT to a downstream consumer, pass it in a request header
or metadata field:

```
x-aitp-tct: <base64url-encoded TCT JSON>
```

---

## Step 2: Verify locally

```python
# Pseudocode. Notes below the snippet matter.
import time
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

# AITP signatures are over RFC 8785 (JCS) canonical JSON. Use a JCS library
# (e.g. `pyjcs`); `json.dumps(sort_keys=True, separators=(',', ':'))` is
# NOT JCS-compliant for nested objects, Unicode, or numbers.
from jcs import canonicalize as jcs_canonicalize  # pip install pyjcs

# AITP base64url is unpadded (RFC 4648 §5). Reject padding rather than
# normalizing it — padded inputs are non-conformant per RFC-AITP-0001 §5.4.
def b64url_decode_strict(s: str) -> bytes:
    if "=" in s:
        raise ValueError("base64url padding is forbidden in AITP")
    pad = (-len(s)) % 4
    return base64.urlsafe_b64decode(s + ("=" * pad))  # padding only for the decoder, never accepted on input

def verify_tct(tct_b64: str, issuer_pubkey: Ed25519PublicKey, my_aid: str) -> list[str]:
    tct = json.loads(b64url_decode_strict(tct_b64))["tct"]

    # 1. Check version
    assert tct["version"] == "aitp/0.1", "Unknown version"

    # 2. Check expiry
    assert tct["expires_at"] > time.time(), "TCT expired"

    # 3. Check audience (must equal my AID; no wildcards in v0.1)
    assert tct["audience"] == my_aid, "Audience mismatch"

    # 4. Reject any unknown top-level field outside the `extensions` slot
    #    (RFC-AITP-0001 §7). Silently ignoring unknown fields would create
    #    signature ambiguity across implementations.
    KNOWN = {"version","jti","issuer","subject","audience","issued_at",
             "expires_at","grants","binding","signature","extensions"}
    unknown = set(tct) - KNOWN
    assert not unknown, f"Unknown TCT fields: {unknown}"

    # 5. Verify signature against the issuing peer's public key
    #    (resolved from the issuing peer's Manifest).
    tct_without_sig = {k: v for k, v in tct.items() if k != "signature"}
    canonical = jcs_canonicalize(tct_without_sig)  # bytes, JCS-canonical
    sig = b64url_decode_strict(tct["signature"])
    issuer_pubkey.verify(sig, canonical)  # raises on failure

    return tct["grants"]
```

The `issuer_pubkey` is extracted from the issuing peer's `manifest.aid`
(`aid:pubkey:<43-char-base64url>` → decode → 32-byte raw Ed25519 public key,
loaded via `Ed25519PublicKey.from_public_bytes()`). v0.1 AIDs are exactly
43 base64url characters; reject any AID of a different length.

---

## Step 3: Enforce grants

```python
def check_grant(grants: list[str], required: str) -> None:
    if required not in grants:
        raise PermissionError(f"Grant '{required}' not present in TCT")
```

---

## Proof-of-possession

`binding.cnf` is required on every v0.1 peer-issued TCT. Whether to verify
PoP at consumption time is governed by the issuing peer's per-grant policy
(RFC-AITP-0005 §6): consumers MUST verify PoP for any grant the issuing peer
marks as requiring it, and SHOULD verify PoP for all grants unless the
deployment provides equivalent channel binding (mTLS with bound client
certs, an authenticated message bus, etc.).

To verify PoP, send a fresh challenge nonce (via `pop_challenge` envelope),
ask the peer to sign `sha256(nonce)`, and verify the response signature
against `binding.cnf` using the same strict base64url + JCS rules as the
TCT signature itself. The Mutual Handshake's round-2 PoP exchange already
binds the TCT to a live key — downstream PoP is the same proof, repeated
when a TCT is presented after the handshake.

---

## Delegating verification to the issuing peer

If you prefer to delegate verification to the issuing peer instead of
verifying locally, POST a `tct_verify` envelope to the issuing peer's
verify endpoint (advertised in its Manifest):

```json
{
  "tct_token": "<base64url TCT>",
  "expected_audience": "aid:pubkey:11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo",
  "required_grants": ["macp.mode.task.v1"]
}
```

On success, the response carries the verified grants list. The issuing
peer is authoritative for revocation, so this also serves as a freshness
check.

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
