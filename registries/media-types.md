# Media Types Registry

Media types used by AITP v0.1. v0.1 ships JSON-only (see [RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#54-signature)); no Protobuf or binary framing is part of conformance.

## Registered media types

| Media type | Description |
|---|---|
| `application/aitp+json; version=0.1` | Canonical JSON envelope. The signing input is the inner payload in RFC 8785 (JCS) canonical JSON form. |
| `application/aitp-tct+json; version=0.1` | A bare TCT, JSON-encoded. Used when a TCT is carried outside an envelope (e.g. an `Authorization` header or out-of-band reference). |

## Carriage guidance (non-normative)

The following patterns are operational guidance, not v0.1 conformance requirements. Deployments are free to choose their own carriage so long as the JCS signing input is preserved.

When carrying a TCT in an HTTP request, implementations SHOULD use:

```
x-aitp-tct: <base64url-encoded TCT JSON>
```

When negotiating content types over HTTP, clients SHOULD send `Accept: application/aitp+json` and servers SHOULD honor the preference where supported.
