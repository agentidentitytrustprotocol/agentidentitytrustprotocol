# Agent Identity & Trust Protocol (AITP)

**Version:** 0.2.0-draft
**Status:** Community Standards Track (Draft)
**Canonical wire format:** JSON
**Normative transport:** HTTPS
**Canonical signing input:** RFC 8785 (JCS) canonical JSON (protocol-internal artifacts); RFC 7515 compact JWS (portable trust artifacts, §5.4.5)

AITP is an **agent-to-agent (A2A) trust protocol**. It lets two autonomous agents — running in different organizations, behind different identity providers, with no shared verifier — establish bidirectional trust before they exchange any binding work.

AITP introduces one strict invariant:

> **Trust between two agents MUST be expressed as a pair of signed, audience-bound, capability-scoped Trust Context Tokens (TCTs) produced by a Mutual Handshake.**

There is no central verifier. Each agent is its own verifier for the peer it is authenticating. The output of the handshake is a TCT each peer holds about the other. A TCT is verified locally — its signature is checked against the issuing peer's public key, resolved from the peer's signed Agent Manifest.

AITP has been **A2A-native since its first published version** (`aitp/0.1`, the v0.1 line); there is no earlier service-consumer version to migrate from. The service-consumer trust pattern (agent → verifier → service) is intentionally out of scope.

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
  README.md  CHANGELOG.md  VERSIONING.md  RELEASING.md
  CONTRIBUTING.md  CODE_OF_CONDUCT.md  LICENSE  Makefile

  manifesto/
    manifesto.md

  rfcs/
    README.md                               # RFC index + per-RFC status
    RFC-AITP-0001-core.md
    RFC-AITP-0002-identity.md
    RFC-AITP-0003-manifest.md
    RFC-AITP-0004-mutual-handshake.md
    RFC-AITP-0005-tct.md
    RFC-AITP-0006-delegation.md
    RFC-AITP-0007-key-resolution.md
    RFC-AITP-0008-revocation.md
    RFC-AITP-0009-security.md
    RFC-AITP-0010-session-trust-bundle.md   # Draft, opt-in (not part of v0.2 core conformance)
    RFC-AITP-0011-multihop-delegation.md    # Draft, opt-in (not part of v0.2 core conformance)
    RFC-AITP-0012-extensions.md             # Reserved
    RFC-AITP-0013-tct-renewal-extension.md  # Planned

  docs/                                     # Non-normative guides
    architecture.md
    discovery.md
    ecosystem.md                            # Which sibling repo owns what; canonical links
    GLOSSARY.md
    implementer-quickstart.md
    integration-guide.md
    non-goals.md
    operational-guidance.md
    threat-model.md

  registries/
    README.md
    identity-types.md
    capabilities.md
    error-codes.md
    extension-keys.md
    media-types.md

  schemas/
    json/
      aitp-envelope.schema.json
      aitp-identity.schema.json
      aitp-manifest.schema.json
      aitp-mutual-handshake.schema.json
      aitp-tct.schema.json
      aitp-grant-voucher.schema.json
      aitp-delegation.schema.json
      aitp-revocation-list.schema.json
      aitp-session-bundle.schema.json
      aitp-trust-anchors.schema.json
      aitp-conformance-fixture.schema.json  # metadata block every fixture carries
    conformance/
      README.md                             # fixture format, runner rules, counts
      PLACEHOLDERS.md                       # placeholder tokens runners substitute
      env-*.json  man-*.json  id-*.json  mh-*.json
      tct-*.json  vch-*.json  del-*.json  rev-*.json   # v0.2 core
      del-mh-*.json  bundle-*.json                     # opt-in drafts (RFC-AITP-0011 / 0010)
      known-answer/                         # pinned canonical bytes, keys, signatures
        signed-examples/

  examples/
    manifest/        agent-b-manifest.json
    tct/             tct-peer-issued.json
    grant-voucher/   voucher.json
    delegation/      single-hop.json
    revocation/      empty-list.json, with-entry.json
    non-normative/   peer-signed-full-flow.json   (transcript, not schema-valid)

  governance/
    CHARTER.md
    GOVERNANCE.md
    RFC-PROCESS.md                          # the RFC status ladder
    DECISIONS.md                            # decision log (issue #48)
    spec-errata-from-independent-verifier-2026-07.md

  scripts/         # Validation scripts (make validate)
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
15. **[docs/implementer-quickstart.md](docs/implementer-quickstart.md)** — one-page reading order for someone building an AITP peer.
16. **[docs/operational-guidance.md](docs/operational-guidance.md)** — renewal patterns, Manifest rotation, cache TTL tuning, failure modes (non-normative).
17. **[docs/threat-model.md](docs/threat-model.md)** and **[docs/non-goals.md](docs/non-goals.md)** — what AITP defends against, and what it deliberately does not do.
18. **[docs/ecosystem.md](docs/ecosystem.md)** — where the implementations, tools and services live (see [Ecosystem](#ecosystem) below).

---

## Conformance

v0.2 defines one conformance target: what a conformant implementation MUST do is listed in [RFC-AITP-0001 §10](rfcs/RFC-AITP-0001-core.md#10-conformance) (RFCs 0001–0009, the mandatory known-answer vectors, and the core conformance fixtures). There are no named conformance profiles.

The opt-in drafts are selected per fixture, not per profile: every fixture under [`schemas/conformance/`](schemas/conformance/README.md) carries a metadata block (`status`, `required_for_v0_2`, `feature`), and a `draft` fixture runs only when the runner has explicitly opted into its named `feature` flag — `experimental-session-bundle` (RFC-AITP-0010) or `experimental-multihop-delegation` (RFC-AITP-0011). See the [runner enforcement rules](schemas/conformance/README.md#conformance-runner-enforcement-rules) and RFC-AITP-0001 §10 for how a core-only implementation treats those fixtures.

There is no service-consumer conformance target. AITP is peer-to-peer.

---

## Standards posture

- **RFC-AITP-0001 Core** — envelope, replay, signatures, error codes, capability negotiation, registry hooks.
- **RFC-AITP-0002 Identity** — pluggable identity-binding (OIDC and pinned key in v0.2).
- **RFC-AITP-0003 Manifest** — signed self-description with `/.well-known/aitp-manifest`.
- **RFC-AITP-0004 Mutual Handshake** — four-message peer auth + bilateral TCT issuance.
- **RFC-AITP-0005 TCT** — canonical peer-issued capability grant, plus the grant voucher consumed by delegation; both compact JWS.
- **RFC-AITP-0006 Delegation** — stateless single-hop delegation as a compact JWS embedding the issuing peer's grant voucher.
- **RFC-AITP-0007 Key Resolution** — peer key from Manifest; issuer key cache → pinned → well-known.
- **RFC-AITP-0008 Revocation** — JTI deny lists, key revocation, fail modes.
- **RFC-AITP-0009 Security** — A2A threat model and required defenses.
- **RFC-AITP-0010 Session Trust Bundle** *(Draft, opt-in — not part of v0.2 core conformance)* — multi-agent session scaling.
- **RFC-AITP-0011 Multi-hop Delegation** *(Draft, opt-in — not part of v0.2 core conformance)* — chains beyond a single hop.
- **RFC-AITP-0012 Extensions** *(reserved)* — `extensions.zk` and `extensions.tee` namespaces.
- **RFC-AITP-0013 TCT Renewal Extension** *(Planned)* — standardization of the non-normative shortened renewal endpoint described in RFC-AITP-0004 §8.1.

---

## Maintenance posture

- **Status:** maintained, single maintainer, best-effort. Until a Core Team is seated, the repository maintainer acts in its place for editorial and registry matters (see [governance/CHARTER.md § Core Team](governance/CHARTER.md#core-team)); substantive RFC changes still go through the [RFC process](governance/RFC-PROCESS.md), not one person's judgment alone.
- **What's stable vs. not:** the `aitp/0.2` revision is tagged (`v0.2.0-draft`, `schema-v0.2.0`). On the [RFC status ladder](governance/RFC-PROCESS.md#rfc-lifecycle), RFCs 0001–0011 are `Draft` (0010 and 0011 opt-in, outside v0.2 core conformance), RFC-AITP-0012 is `Reserved`, and RFC-AITP-0013 is `Planned` — the [RFC index](rfcs/README.md) is the authoritative per-RFC table. Nothing in the v0.2 line has reached Release Candidate (the earlier v0.1 line did, at `0.1.0-rc.3`).
- **Cadence:** best-effort, driven by need. Changes land when a consumer needs them, not on a fixed schedule.

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

- **Protocol version** governs the envelope (`version: aitp/0.2`).
- **JSON Schema namespace** governs canonical schema compatibility (`https://aitp.dev/schema/v0.2/`).
- **TCT version** governs the canonical token contract.
- **Manifest version** governs the agent self-description format.

Major mismatches are not compatible. Minor versions are expected to be backward compatible. Unknown JSON fields outside explicit `extensions` namespaces MUST be rejected. Unknown keys *inside* `extensions` MUST be ignored. See RFC-AITP-0001 §7. See [VERSIONING.md](VERSIONING.md).

---

## Using AITP

The canonical v0.2 surface is JSON. Implementations consume the JSON Schemas directly using whatever tooling fits the target language — this covers the JCS-profile artifacts (envelope, Manifest, revocation snapshot, session bundle, handshake payloads) in full, and the decoded-claims shape of the compact-JWS portable trust artifacts (TCT, grant voucher, delegation token); producing and verifying the JWS itself still needs an RFC 7515 JOSE library, not schema codegen alone:

- `quicktype` — https://quicktype.io
- `json-schema-to-typescript` (TypeScript)
- `datamodel-code-generator` (Python)
- `go-jsonschema` (Go)
- any JSON Schema codegen tool

Schemas live under `schemas/json/` and are versioned by `$id` URI.

See [RELEASING.md](RELEASING.md) for the release workflow.

---

## Repository highlights

- **Canonical JSON Schemas** under `schemas/json/`.
- **Conformance fixtures** under `schemas/conformance/`, validated in CI —
  both the fixture's own metadata block and every artifact embedded in its
  `input` (session bundle, TCT claims, manifest, …) are validated against
  the matching JSON Schema.
- **Registries** under `registries/` evolve without destabilizing the core.
- **Examples** under `examples/` are validated against the canonical schemas.
- **GitHub Actions CI** validates JSON Schemas, examples, conformance
  fixtures (including their embedded artifacts), pinned known-answer
  vectors, and the eight-stage doc-coherence check (the stages are listed in
  the header of `scripts/check-doc-coherence.sh`) on every PR.

---

## Development

```bash
make install-tools    # ajv-cli, ajv-formats (one-time); also requires python3 and Node.js 20+
make validate         # v0.2 conformance: JSON Schemas + examples + fixtures
                       # (incl. fixture-input cross-check) + known-answer
                       # vectors + doc coherence
make release          # Build the sanctioned release archive
make help             # Show all targets
```

---

## Ecosystem

This repository is the specification only. Implementations, tools and services live in sibling repositories in the [`agentidentitytrustprotocol`](https://github.com/agentidentitytrustprotocol) organization, each owning its own docs; [docs/ecosystem.md](docs/ecosystem.md) is the single map of which repo owns what. Common entry points:

- **Reference implementation (Rust, with Python and Node SDKs):** [aitp-rs](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/README.md) — [Python SDK](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/sdk-python.md), [Node SDK](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/sdk-node.md)
- **Independent verifier (Python, written from the RFCs alone):** [aitp-verifier-py](https://github.com/agentidentitytrustprotocol/aitp-verifier-py/blob/main/README.md)
- **End-to-end demo:** [aitp-playground getting started](https://github.com/agentidentitytrustprotocol/aitp-playground/blob/main/docs/getting-started.md)
- **Spec access for AI agents (MCP server):** [aitp-docs client setup](https://github.com/agentidentitytrustprotocol/aitp-docs/blob/main/docs/clients.md)

The published documentation site is [agentidentitytrustprotocol.io](https://agentidentitytrustprotocol.io); it renders the RFCs, registries and `docs/` from this repository. If a sibling doc and an RFC disagree, the RFC wins.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), the [RFC process](governance/RFC-PROCESS.md), and [RELEASING.md](RELEASING.md). The changelog is [CHANGELOG.md](CHANGELOG.md); the versioning policy is [VERSIONING.md](VERSIONING.md).

---

## License

Apache License 2.0. See [LICENSE](LICENSE).
