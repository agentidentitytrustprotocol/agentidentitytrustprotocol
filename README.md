# Agent Identity & Trust Protocol (AITP)

**Version:** 0.1.0-draft
**Status:** Community Standards Track (Draft)
**Canonical wire format:** JSON
**Normative transport:** HTTPS
**Canonical signing input:** RFC 8785 (JCS) canonical JSON

AITP is an **agent-to-agent (A2A) trust protocol**. It lets two autonomous agents — running in different organizations, behind different identity providers, with no shared verifier — establish bidirectional trust before they exchange any binding work.

AITP introduces one strict invariant:

> **Trust between two agents MUST be expressed as a pair of signed, audience-bound, capability-scoped Trust Context Tokens (TCTs) produced by a Mutual Handshake.**

There is no central verifier. Each agent is its own verifier for the peer it is authenticating. The output of the handshake is a TCT each peer holds about the other. A TCT is verified locally — its signature is checked against the issuing peer's public key, resolved from the peer's signed Agent Manifest.

This is the **first published version** of AITP and it is A2A-native. The service-consumer trust pattern (agent → verifier → service) is intentionally out of scope.

---

## What AITP looks like

```
Agent A (Manifest, identity)             Agent B (Manifest, identity)
   |                                                |
   |  GET /.well-known/aitp-manifest                |
   |----------------------------------------------->|
   |<-- Manifest -----------------------------------|
   |                                                |
   |  Mutual Handshake (four messages)              |
   |================================================|
   |   round 1:  identity + manifest + nonces       |
   |   round 2:  TCTs + PoP signatures              |
   |================================================|
   |                                                |
   |  Each peer holds a TCT signed by the other.    |
   |  TCTs are audience-bound, capability-scoped.   |
   |  No third-party verifier in the loop.          |
```

---

## What this repository contains

This repository is structured like a publishable protocol standard — the normative core is small and stable; implementers get enough architectural and operational guidance to build real peer agents.

```text
agentidentitytrustprotocol/
  manifesto/
    manifesto.md

  rfcs/
    RFC-AITP-0001-core.md
    RFC-AITP-0002-identity.md
    RFC-AITP-0003-manifest.md
    RFC-AITP-0004-mutual-handshake.md
    RFC-AITP-0005-tct.md
    RFC-AITP-0006-delegation.md
    RFC-AITP-0007-key-resolution.md
    RFC-AITP-0008-revocation.md
    RFC-AITP-0009-security.md
    RFC-AITP-0010-session-trust-bundle.md   # Reserved
    RFC-AITP-0011-multihop-delegation.md    # Reserved
    RFC-AITP-0012-extensions.md             # Reserved

  docs/
    architecture.md
    discovery.md
    GLOSSARY.md
    integration-guide.md
    non-goals.md
    threat-model.md

  registries/
    README.md
    identity-types.md
    capabilities.md
    error-codes.md
    media-types.md

  schemas/
    json/
      aitp-envelope.schema.json
      aitp-identity.schema.json
      aitp-manifest.schema.json
      aitp-mutual-handshake.schema.json
      aitp-tct.schema.json
      aitp-delegation.schema.json
      aitp-revocation-list.schema.json
      aitp-trust-anchors.schema.json
    conformance/
      README.md
      mh-001-replay-rejected.json   # …and the rest of the mh-, id-, tct-, del- fixtures
      tct-002-expired.json
      del-003-scope-exceeded.json

  examples/
    manifest/        agent-b-manifest.json
    tct/             tct-peer-issued.json
    delegation/      single-hop.json
    revocation/      empty-list.json, with-entry.json
    non-normative/   peer-signed-full-flow.json   (transcript, not schema-valid)

  governance/
    GOVERNANCE.md
    RFC-PROCESS.md

  scripts/         # Validation scripts
  .github/         # CI, issue templates, PR template
```

---

## Reading order

If you are new to AITP, read in this order:

1. **[manifesto/manifesto.md](manifesto/manifesto.md)** — why a trust kernel is needed.
2. **[docs/architecture.md](docs/architecture.md)** — the problem, the shape, the flows, the reading order.
3. **[docs/GLOSSARY.md](docs/GLOSSARY.md)** — quick reference for the terms used across the spec.
4. **[RFC-AITP-0001 Core](rfcs/RFC-AITP-0001-core.md)** — the envelope, signatures, replay protection, error codes.
5. **[RFC-AITP-0002 Identity](rfcs/RFC-AITP-0002-identity.md)** — identity binding model.
6. **[RFC-AITP-0003 Manifest](rfcs/RFC-AITP-0003-manifest.md)** — signed agent self-description.
7. **[RFC-AITP-0004 Mutual Handshake](rfcs/RFC-AITP-0004-mutual-handshake.md)** — the A2A handshake.
8. **[RFC-AITP-0005 TCT](rfcs/RFC-AITP-0005-tct.md)** — the canonical Trust Context Token.
9. **[RFC-AITP-0006 Delegation](rfcs/RFC-AITP-0006-delegation.md)** — single-hop delegation.
10. **[RFC-AITP-0007 Key Resolution](rfcs/RFC-AITP-0007-key-resolution.md)** — Manifest-first peer keys + issuer keys.
11. **[RFC-AITP-0008 Revocation](rfcs/RFC-AITP-0008-revocation.md)** — JTI deny lists per issuing peer.
12. **[RFC-AITP-0009 Security](rfcs/RFC-AITP-0009-security.md)** — threat model.
13. **[docs/discovery.md](docs/discovery.md)** — initial peer discovery patterns (non-normative).
14. **[docs/integration-guide.md](docs/integration-guide.md)** — consuming a peer-issued TCT in code.

---

## Conformance profiles

| Profile | Required RFCs | Description |
|---|---|---|
| `aitp-a2a-peer` *(default)* | 0001–0009 | Every AITP agent. Implements Manifest, Mutual Handshake, peer-issued TCTs, delegation. |
| `aitp-session-participant` | 0001–0010 | *Forthcoming. No implementations possible until RFC-AITP-0010 reaches Draft status. Currently reserved.* |
| `aitp-full` | 0001–0011 | Adds multi-hop delegation (when 0011 is finalized). |

There is no service-consumer profile. AITP is peer-to-peer.

---

## Standards posture

- **RFC-AITP-0001 Core** — envelope, replay, signatures, error codes, capability negotiation, registry hooks.
- **RFC-AITP-0002 Identity** — pluggable identity-binding (OIDC and pinned key in v0.1).
- **RFC-AITP-0003 Manifest** — signed self-description with `/.well-known/aitp-manifest`.
- **RFC-AITP-0004 Mutual Handshake** — four-message peer auth + bilateral TCT issuance.
- **RFC-AITP-0005 TCT** — canonical peer-issued capability grant.
- **RFC-AITP-0006 Delegation** — stateless single-hop delegation.
- **RFC-AITP-0007 Key Resolution** — peer key from Manifest; issuer key cache → pinned → well-known.
- **RFC-AITP-0008 Revocation** — JTI deny lists, key revocation, fail modes.
- **RFC-AITP-0009 Security** — A2A threat model and required defenses.
- **RFC-AITP-0010 Session Trust Bundle** *(reserved)* — multi-agent session scaling.
- **RFC-AITP-0011 Multi-hop Delegation** *(reserved)* — chains beyond a single hop.
- **RFC-AITP-0012 Extensions** *(reserved)* — `extensions.zk` and `extensions.tee` namespaces.

---

## Capability negotiation

Capabilities are negotiated in two layers:

1. **At discovery time** — each agent's Manifest declares `offered_capabilities` and `required_peer_capabilities`. Peers screen for compatibility before initiating a handshake.
2. **At handshake time** — `requested_grants` in `mutual_hello` / `mutual_hello_ack` requests specific capabilities. The peer-issued grant is the intersection of `requested_grants`, the issuing peer's `offered_capabilities`, and its identity-policy for the peer.

Reserved namespaces (see [registries/capabilities.md](registries/capabilities.md)):

- `aitp.handshake.v1` — base mutual handshake
- `aitp.delegation.v1` — single-hop delegation
- `aitp.tct.verify.v1` — TCT verification API
- `aitp.tct.revoke.v1` — TCT revocation API
- `macp.*` — Multi-Agent Coordination Protocol grants

---

## Compatibility model

- **Protocol version** governs the envelope (`version: aitp/0.1`).
- **JSON Schema namespace** governs canonical schema compatibility (`https://aitp.dev/schema/v0.1/`).
- **TCT version** governs the canonical token contract.
- **Manifest version** governs the agent self-description format.

Major mismatches are not compatible. Minor versions are expected to be backward compatible. Unknown JSON fields outside explicit `extensions` namespaces MUST be rejected. Unknown keys *inside* `extensions` MUST be ignored. See RFC-AITP-0001 §7. See [VERSIONING.md](VERSIONING.md).

---

## Using AITP

The canonical v0.1 surface is JSON. Implementations consume the JSON Schemas directly using whatever tooling fits the target language:

- `quicktype` — https://quicktype.io
- `json-schema-to-typescript` (TypeScript)
- `datamodel-code-generator` (Python)
- `go-jsonschema` (Go)
- any JSON Schema codegen tool

Schemas live under `schemas/json/` and are versioned by `$id` URI.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the release workflow.

---

## Repository highlights

- **Canonical JSON Schemas** under `schemas/json/`.
- **Conformance fixtures** under `schemas/conformance/`, validated in CI.
- **Registries** under `registries/` evolve without destabilizing the core.
- **Examples** under `examples/` are validated against the canonical schemas.
- **GitHub Actions CI** validates JSON Schemas, examples, and conformance fixtures on every PR.

---

## Development

```bash
make install-tools    # ajv-cli (one-time)
make validate         # v0.1 conformance: JSON Schemas + examples + fixtures
make release          # Build the sanctioned release archive
make help             # Show all targets
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and the [RFC process](governance/RFC-PROCESS.md).

---

## License

Apache License 2.0. See [LICENSE](LICENSE).
