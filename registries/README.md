# AITP Registries

This directory tracks the well-known identifiers used in AITP. Each registry is a Markdown table; entries are added via PR.

| Registry | File | Authority RFC |
|---|---|---|
| Identity types | [identity-types.md](identity-types.md) | [RFC-AITP-0002](../rfcs/RFC-AITP-0002-identity.md) |
| Capabilities | [capabilities.md](capabilities.md) | [RFC-AITP-0001](../rfcs/RFC-AITP-0001-core.md), [RFC-AITP-0005](../rfcs/RFC-AITP-0005-tct.md) |
| Error codes | [error-codes.md](error-codes.md) | [RFC-AITP-0001](../rfcs/RFC-AITP-0001-core.md) |
| Extension keys | [extension-keys.md](extension-keys.md) | [RFC-AITP-0001 §7](../rfcs/RFC-AITP-0001-core.md#7-compatibility-model), [RFC-AITP-0003](../rfcs/RFC-AITP-0003-manifest.md) |
| Media types | [media-types.md](media-types.md) | [RFC-AITP-0001](../rfcs/RFC-AITP-0001-core.md) |

## Status values

| Status | Meaning |
|---|---|
| `Proposed` | Suggested in an open RFC or PR. Not yet merged. |
| `Provisional` | Merged but not yet shipped in two interoperating implementations. |
| `Stable` | Two interoperating implementations confirmed. Backwards-compatible additions only. |
| `Deprecated` | Retained for archaeology. New implementations MUST NOT depend on it. |

## Naming conventions

- Capability strings use dot-namespaced reverse-domain notation (`<namespace>.<resource>.<action>`).
- Error codes use `SCREAMING_SNAKE_CASE`.
- Identity types use lowercase snake_case.
- Experimental identifiers SHOULD use a vendor-prefixed reverse-domain name (e.g. `com.example.feature`).
