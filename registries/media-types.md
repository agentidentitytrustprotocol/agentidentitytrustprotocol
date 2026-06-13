# Media Types Registry

Media types used by AITP v0.2. AITP ships JSON-only (see [RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#54-signature)); no Protobuf or binary framing is part of conformance. The portable trust artifacts are compact JWS strings ([RFC-AITP-0001 §5.4.5](../rfcs/RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts)).

## Registered media types

| Media type | Description |
|---|---|
| `application/aitp+json; version=0.2` | Canonical JSON envelope. The signing input is the inner payload in RFC 8785 (JCS) canonical JSON form. |
| `application/aitp-tct+jwt` | A Trust Context Token as a compact JWS (RFC-AITP-0005). The JWS `typ` header is `aitp-tct+jwt`. Versioned by the `ver` claim, not the media type. |
| `application/aitp-grant+jwt` | A grant voucher as a compact JWS (RFC-AITP-0005 §8). The JWS `typ` header is `aitp-grant+jwt`. |
| `application/aitp-delegation+jwt` | A delegation token as a compact JWS (RFC-AITP-0006). The JWS `typ` header is `aitp-delegation+jwt`. |

## Superseded media types

| Media type | Status |
|---|---|
| `application/aitp+json; version=0.1` | Superseded by `version=0.2`. |
| `application/aitp-tct+json; version=0.1` | **Superseded** — the v0.1 JCS-signed JSON TCT form is retired; v0.2 TCTs are compact JWS (`application/aitp-tct+jwt`). |

## Carriage guidance (non-normative)

The following patterns are operational guidance, not conformance requirements.

A compact JWS is header-safe and URL-safe verbatim — no additional encoding is needed. When carrying a TCT in an HTTP request, implementations SHOULD use:

```
x-aitp-tct: <compact JWS string>
```

(The v0.1 convention of base64url-encoding a TCT JSON object into this header is retired with the JSON form itself.)

When negotiating content types over HTTP, clients SHOULD send `Accept: application/aitp+json` and servers SHOULD honor the preference where supported.
