# Contributing to AITP

Thank you for contributing to the Agent Identity & Trust Protocol (AITP).

AITP is an agent-to-agent trust standard. All changes MUST preserve the core invariants:

- TCTs are signed, peer-issued, audience-bound (peer AID), capability-scoped, and self-contained.
- Verification is stateless on the consuming peer's side.
- Every agent publishes a signed Manifest at `/.well-known/aitp-manifest` (RFC-AITP-0003).
- Delegation is single-hop in v0.1; chains are rejected.
- Replay protection is dual-controlled (`message_id` deduplication + `timestamp` window) and the Mutual Handshake binds rounds via PoP nonce echoes.
- Identity binding is pluggable; peers MUST NOT accept issuers outside `trust_anchors`.

## Types of contributions

- Specification clarifications (non-normative)
- New RFCs or amendments to existing RFCs
- JSON Schema updates (canonical for v0.1)
- Conformance fixtures
- Tooling and CI improvements
- Documentation

## Submitting changes

### Minor clarifications

Open a PR directly against the relevant document.

### Substantive (normative) changes

1. Open an issue using the [RFC proposal template](.github/ISSUE_TEMPLATE/rfc_proposal.yml).
2. Discuss motivation and compatibility.
3. Submit a PR updating the relevant RFC and any affected schemas or conformance fixtures.

Breaking changes require:
- A version bump on the affected RFC.
- Migration notes in the PR description.
- An explicit compatibility statement.

## Registry additions

To add an entry to a registry (`registries/identity-types.md`, `registries/capabilities.md`, `registries/error-codes.md`, `registries/media-types.md`), submit a PR adding a row to the relevant table. Each entry MUST include a `Status` (`Proposed`, `Provisional`, `Stable`, `Deprecated`). New identifiers MUST NOT conflict with existing entries.

## Technical requirements

- JSON Schemas MUST themselves be valid (`make json-schema-validate`).
- JSON examples MUST validate against the relevant JSON Schema (`make json-validate`).
- Backward compatibility MUST be addressed explicitly in the PR description.

## Style

- Use RFC 2119 keywords (MUST, SHOULD, MAY) consistently in normative text.
- Use present tense ("Verifiers MUST verify…", not "Verifiers should verify…").
- JSON examples MUST be valid against the corresponding schema.

## Normative RFCs

- **[RFC-AITP-0001 Core](rfcs/RFC-AITP-0001-core.md)**
- **[RFC-AITP-0002 Identity](rfcs/RFC-AITP-0002-identity.md)**
- **[RFC-AITP-0003 Agent Manifest](rfcs/RFC-AITP-0003-manifest.md)**
- **[RFC-AITP-0004 Mutual Handshake](rfcs/RFC-AITP-0004-mutual-handshake.md)**
- **[RFC-AITP-0005 TCT](rfcs/RFC-AITP-0005-tct.md)**
- **[RFC-AITP-0006 Delegation](rfcs/RFC-AITP-0006-delegation.md)**
- **[RFC-AITP-0007 Key Resolution](rfcs/RFC-AITP-0007-key-resolution.md)**
- **[RFC-AITP-0008 Revocation](rfcs/RFC-AITP-0008-revocation.md)**
- **[RFC-AITP-0009 Security](rfcs/RFC-AITP-0009-security.md)**

## Reserved RFCs

- **[RFC-AITP-0010 Session Trust Bundle](rfcs/RFC-AITP-0010-session-trust-bundle.md)** *(reserved)*
- **[RFC-AITP-0011 Multi-hop Delegation](rfcs/RFC-AITP-0011-multihop-delegation.md)** *(reserved)*
- **[RFC-AITP-0012 Extensions](rfcs/RFC-AITP-0012-extensions.md)** *(reserved)*

## Community

All contributors must follow the [Code of Conduct](CODE_OF_CONDUCT.md).
