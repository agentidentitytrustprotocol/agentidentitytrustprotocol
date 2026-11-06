# Capability Registry

Capability strings appear in `requested_grants` (`MUTUAL_HELLO` / `MUTUAL_HELLO_ACK`, RFC-AITP-0004 §3), `offered_capabilities` and `required_peer_capabilities` (Manifest, RFC-AITP-0003 §3), `grants` (TCT, RFC-AITP-0005 §4), and `scope` (Delegation, RFC-AITP-0006 §2). They are opaque to AITP — consumers define their meaning. This registry tracks well-known prefixes so identifiers do not collide.

> **Stability:** The reserved namespaces in this registry are stable for v0.3. New entries can be added without an RFC; renaming or removing an existing entry is a breaking change and requires the RFC process. Vendor capabilities under reverse-domain prefixes evolve independently of this registry.

## Naming

`<namespace>.<resource>.<action>` — lowercase, dot-separated, no whitespace. Reverse-domain notation for vendor-specific capabilities.

**What "no whitespace" means on the wire.** The schemas enforce one rule, not the naming convention above: a capability string is non-empty and contains none of these code points, the set ECMA-262 (the regular-expression dialect JSON Schema specifies) calls white space or line terminator:

U+0009, U+000A, U+000B, U+000C, U+000D, U+0020, U+00A0, U+1680, U+2000–U+200A, U+2028, U+2029, U+202F, U+205F, U+3000, U+FEFF.

Every other code point is accepted by the schema, including U+0085 and U+001C–U+001F, which some regex dialects count as white space. The schema patterns list the set explicitly, so every dialect reads them the same way. Each pattern holds the characters themselves, not regex escapes: the schema file writes them as JSON string escapes (`\t`, `\u00a0`, …), which a JSON parser decodes before the regex engine sees the pattern, because some engines, Go's RE2 among them, reject a `\u` escape inside a regex. A verifier MUST apply exactly this set: one that rejects U+0085, or accepts U+FEFF, refuses or admits artifacts that another verifier treats the other way. Fixtures `man-011` (U+0085, accepted) and `man-012` (U+FEFF, `MANIFEST_INVALID`) pin it.

**Exception: `aitp.attestation`.** This marker grant has two segments, not three, and confers no capability. It appears only as the sole grant of a self-attestation TCT (`iss == sub == aud`, [RFC-AITP-0005 §5.3](../rfcs/RFC-AITP-0005-tct.md#53-self-issued-attestation-tcts)). An issuer MUST NOT mint it with `iss ≠ sub`, and a verifier that evaluates a TCT as a capability grant MUST reject any TCT that contains it. No other entry may use the two-segment form.

## Reserved namespaces

| Namespace | Owner | Description | Status |
|---|---|---|---|
| `aitp.handshake.v1` | AITP core | Base handshake support. | Stable |
| `aitp.delegation.v1` | AITP core | Single-hop delegation. | Stable |
| `aitp.tct.verify.v1` | AITP core | TCT verification API: the OPTIONAL `Verify` operation ([RFC-AITP-0005 §11](../rfcs/RFC-AITP-0005-tct.md#11-peer-issued-tct-verification-api)). | Stable |
| `aitp.tct.revoke.v1` | AITP core | TCT revocation API ([RFC-AITP-0005 §11](../rfcs/RFC-AITP-0005-tct.md#11-peer-issued-tct-verification-api)). Advertising it signals the OPTIONAL `Revoke` operation; it is not needed to locate `ListRevoked`, which every TCT issuer serves at the URL advertised under the `rfc-aitp-0008.revocation_list_uri` extension key. | Stable |
| `aitp.attestation` | AITP core | Marker grant for a self-attestation TCT (RFC-AITP-0005 §5.3). Confers no capability; rejected in every grant context. The one exception to the three-segment naming form. | Provisional |
| `macp.*` | Multi-Agent Coordination Protocol | Coordination kernel grants (e.g. `macp.session.start`, `macp.mode.task.v1`). | Stable |

## Adding a capability

Open a PR adding a row above. Include:

- The exact capability string.
- Owner (project or vendor).
- A one-line description.
- A status (`Proposed`, `Provisional`, `Stable`, `Deprecated`).

Vendor-specific capabilities SHOULD live under a reverse-domain prefix (`com.example.read.v1`) and need not be registered here, but registration is encouraged for ecosystem visibility.
