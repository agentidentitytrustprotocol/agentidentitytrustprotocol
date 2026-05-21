# RFC-AITP-0013
# TCT Renewal Extension

**Document:** RFC-AITP-0013
**Version:** 0.1.0-planned
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

The contents of this RFC are **non-normative** for v0.1. They become
normative in a future version.

## Status

No normative text. Reserved for v0.2 standardization. This stub exists
so that RFC-AITP-0004 §8.1, `rfcs/README.md`, and
`registries/extension-keys.md` have a stable reference to point at
before the document is written.

v0.1 implementations:

- MUST NOT require shortened renewal support (RFC-AITP-0004 §8.1).
- MAY offer the shortened renewal extension, advertising it via
  `extensions["rfc-aitp-0005.renew_uri"]` (see
  [`registries/extension-keys.md`](../registries/extension-keys.md)).
- MUST fall back to the full Mutual Handshake (RFC-AITP-0004) for
  renewal when the extension is absent.

## References

- [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0005 Trust Context Token](RFC-AITP-0005-tct.md)
- [registries/extension-keys.md](../registries/extension-keys.md)
