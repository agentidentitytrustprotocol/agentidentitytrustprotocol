# RFC-AITP-0013
# TCT Renewal Extension

**Document:** RFC-AITP-0013
**Version:** 0.2.0-planned
**Status:** Planned
**Depends on:** [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md), [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)

---

## Abstract

This RFC will standardize the shortened TCT renewal flow described
non-normatively in
[RFC-AITP-0004 §8.1](RFC-AITP-0004-mutual-handshake.md#81-non-normative-shortened-renewal-extension).
The wire format of the shortened renewal exchange is stable across
implementations, but conformance testing and required behavior are
reserved for this RFC.

The contents of this RFC are **non-normative** for v0.2. They become
normative in a future version.

## Status

No normative text. Reserved for post-v0.2 standardization. This stub
exists so that RFC-AITP-0004 §8.1, `rfcs/README.md`, and
`registries/extension-keys.md` have a stable reference to point at
before the document is written.

v0.2 implementations:

- MUST NOT require shortened renewal support (RFC-AITP-0004 §8.1).
- MAY offer the shortened renewal extension, advertising it via
  `extensions["rfc-aitp-0005.renew_uri"]` (see
  [`registries/extension-keys.md`](../registries/extension-keys.md)).
- MUST fall back to the full Mutual Handshake (RFC-AITP-0004) for
  renewal when the extension is absent.

## Sketch under `aitp/0.2` (non-normative)

Under the v0.2 Compact JWS profile (RFC-AITP-0001 §5.4.5), the
shortened renewal exchange carries TCTs as opaque compact JWS strings:

- The renewal **request** carries the holder's current TCT as a compact
  JWS string (not a JSON object), alongside the `pop_nonce` /
  `pop_signature` fields sketched in RFC-AITP-0004 §8.1.
- The renewal **response** carries the replacement TCT as a compact JWS
  string, with a new `jti` and `exp ≤ issuer.manifest.expires_at`.
- When the issuer's policy permits the subject to delegate, the
  companion grant voucher is **re-minted on renewal** and returned
  alongside the new TCT (RFC-AITP-0005 §8.2): the voucher's lifecycle
  rides on its `src_jti`, so vouchers bound to the old TCT's `jti` do
  not transfer to the renewed token.

No other semantic change relative to the RFC-AITP-0004 §8.1 sketch: the
issuer still verifies the current TCT is unexpired before issuing a
replacement, and still re-evaluates grant policy, revocation, manifest
rotation, and trust-anchor state.

## References

- [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0005 Trust Context Token](RFC-AITP-0005-tct.md)
- [registries/extension-keys.md](../registries/extension-keys.md)
