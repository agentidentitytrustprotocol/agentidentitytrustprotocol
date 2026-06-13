# Capability Registry

Capability strings appear in `requested_grants` (`MUTUAL_HELLO` / `MUTUAL_HELLO_ACK`, RFC-AITP-0004 §3), `offered_capabilities` and `required_peer_capabilities` (Manifest, RFC-AITP-0003 §3), `grants` (TCT, RFC-AITP-0005 §4), and `scope` (Delegation, RFC-AITP-0006 §2). They are opaque to AITP — consumers define their meaning. This registry tracks well-known prefixes so identifiers do not collide.

> **Stability:** The reserved namespaces in this registry are stable for v0.2. New entries can be added without an RFC; renaming or removing an existing entry is a breaking change and requires the RFC process. Vendor capabilities under reverse-domain prefixes evolve independently of this registry.

## Naming

`<namespace>.<resource>.<action>` — lowercase, dot-separated, no whitespace. Reverse-domain notation for vendor-specific capabilities.

## Reserved namespaces

| Namespace | Owner | Description | Status |
|---|---|---|---|
| `aitp.handshake.v1` | AITP core | Base handshake support. | Stable |
| `aitp.delegation.v1` | AITP core | Single-hop delegation. | Stable |
| `aitp.tct.verify.v1` | AITP core | TCT verification API. | Stable |
| `aitp.tct.revoke.v1` | AITP core | TCT revocation API. | Stable |
| `macp.*` | Multi-Agent Coordination Protocol | Coordination kernel grants (e.g. `macp.session.start`, `macp.mode.task.v1`). | Stable |

## Adding a capability

Open a PR adding a row above. Include:

- The exact capability string.
- Owner (project or vendor).
- A one-line description.
- A status (`Proposed`, `Provisional`, `Stable`, `Deprecated`).

Vendor-specific capabilities SHOULD live under a reverse-domain prefix (`com.example.read.v1`) and need not be registered here, but registration is encouraged for ecosystem visibility.
