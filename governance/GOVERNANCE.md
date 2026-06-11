# AITP Governance

AITP is maintained as an open protocol specification.

## Maintainers

Maintainers are responsible for:

- Reviewing and merging pull requests.
- Protecting protocol invariants (see [CONTRIBUTING.md](../CONTRIBUTING.md#contributing-to-aitp)).
- Managing releases (RFC final transitions, schema/proto tags).
- Maintaining registry consistency (`registries/`).

## Decision Process

| Class | Decision rule |
|---|---|
| Clarifications | Maintainer approval. |
| Backward-compatible additions | Maintainer consensus. |
| Breaking changes | Formal [RFC process](RFC-PROCESS.md) + version bump on the affected RFC. |
| Registry additions | Maintainer approval; identifiers MUST NOT collide. |

## RFC Lifecycle

`Idea → Draft → Review → Release Candidate → Final Comment Period → Accepted` (or `Rejected`).

Status MUST be reflected in the RFC document header. See [RFC-PROCESS.md](RFC-PROCESS.md) for the authoritative definition of each stage.

## Registry Authority

The project maintains four registries under [`registries/`](../registries/):

- Identity types (`registries/identity-types.md`)
- Capabilities (`registries/capabilities.md`)
- Error codes (`registries/error-codes.md`)
- Media types (`registries/media-types.md`)

Experimental identifiers SHOULD use reverse-domain notation (e.g. `com.example.feature`).

## Code of Conduct

All contributors are expected to follow the [Code of Conduct](../CODE_OF_CONDUCT.md).
