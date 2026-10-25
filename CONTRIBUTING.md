# Contributing to AITP

Thank you for contributing to the Agent Identity & Trust Protocol (AITP).

AITP is an agent-to-agent trust standard. All changes MUST preserve the core invariants:

- TCTs are signed, peer-issued, audience-bound (peer AID), capability-scoped, and self-contained.
- Verification is stateless on the consuming peer's side.
- Every agent publishes a signed Manifest at `/.well-known/aitp-manifest` (RFC-AITP-0003).
- Delegation is single-hop in v0.3 core; chains are RFC-AITP-0011, an opt-in draft outside core conformance.
- Replay protection is dual-controlled (`message_id` deduplication + `timestamp` window) and the Mutual Handshake binds rounds via PoP nonce echoes.
- Identity binding is pluggable; peers MUST NOT accept issuers outside `trust_anchors`.

## Types of contributions

- Specification clarifications (non-normative)
- New RFCs or amendments to existing RFCs
- JSON Schema updates (canonical for v0.3)
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

### Review windows

Until a Core Team is seated, the maintainer acts in its place
([`governance/CHARTER.md` § Core Team](governance/CHARTER.md#core-team)) and
shepherds every RFC. A normative RFC leaves Review, Release Candidate or Final
Comment Period only after a public review of at least 30 days at that stage
([RFC-PROCESS.md § Stages](governance/RFC-PROCESS.md#stages)). Each window is
announced in a pinned
[Discussions](https://github.com/agentidentitytrustprotocol/agentidentitytrustprotocol/discussions)
thread with its open and close dates; comment there or on the RFC's pull
request. The first window, the review of the `aitp/0.3` core RFCs
(RFC-AITP-0001 to RFC-AITP-0009), opened on 2026-10-24 and closes no earlier
than 2027-01-10. Its thread is
[Public review: aitp/0.3](https://github.com/agentidentitytrustprotocol/agentidentitytrustprotocol/discussions/117).

## Registry additions

There are seven registries, indexed in [`registries/README.md`](registries/README.md): [`identity-types.md`](registries/identity-types.md), [`capabilities.md`](registries/capabilities.md), [`error-codes.md`](registries/error-codes.md), [`extension-keys.md`](registries/extension-keys.md), [`jti-domain-tags.md`](registries/jti-domain-tags.md), [`media-types.md`](registries/media-types.md) and [`message-types.md`](registries/message-types.md). To add an entry, submit a PR adding a row to the relevant table, following any "Adding …" section in that file. New identifiers MUST NOT conflict with existing entries.

Status columns differ by registry:

- identity types, capabilities, extension keys and jti domain tags use the shared [status values](registries/README.md#status-values) — `Reserved`, `Proposed`, `Provisional`, `Stable`, `Deprecated`. `Reserved` sets an identifier aside for a named future mechanism with no normative spec yet; implementations MUST NOT use it;
- error codes carry a `spec_status` of `core` or `draft` instead (see the note at the top of [`error-codes.md`](registries/error-codes.md)); new codes need no new RFC *document*, but the RFCs whose normative text gains the code take a version bump ([VERSIONING.md](VERSIONING.md#change-classes));
- media types list registered types, with superseded ones in a separate table;
- message types use the shared status values too, and a new value also changes the envelope schema's `enum` (see the "Adding a message type" section of [`message-types.md`](registries/message-types.md)).

## Conformance fixtures

Adding a fixture is a checklist: pick the id, write the fixture, map its
embedded artifacts in `scripts/fixture-validation-map.json` (an unmapped
fixture fails the build), update the index and counts, and record it in the
CHANGELOG. The steps are in
[`docs/how-to-add-a-fixture.md`](docs/how-to-add-a-fixture.md); the fixture
format itself is in [`schemas/conformance/README.md`](schemas/conformance/README.md).

## Prerequisites

- **`python3`** — a hard prerequisite. `scripts/validate-json.sh` calls it
  unconditionally, both for JSON syntax checking and for the fixture-input
  cross-check described above; there is no fallback path for that stage.
- **Node.js 20+** for local development, matching what CI pins
  (`.github/workflows/ci.yml` sets `node-version: '20'`). The hard technical
  floor is lower — `scripts/verify-known-answer.mjs` relies on `Buffer`'s
  `base64url` encoding, added in Node.js 15.7.0 (backported to 14.18.0) — but
  those lines are long past end-of-life, so match CI's Node 20 rather than
  the historical minimum.
- **`ajv-cli`** and **`ajv-formats`** — install with `make install-tools`
  (requires `npm`).

## Technical requirements

- JSON Schemas MUST themselves be valid (`make json-schema-validate`).
- JSON examples and conformance fixture inputs MUST validate against the
  relevant JSON Schema (`make json-validate`; see "Conformance fixtures"
  above for the fixture-input map requirement).
- Documentation MUST stay coherent with itself (`make doc-coherence`). The
  check covers RFC version claims (and the README version against the newest
  CHANGELOG release), intra-repo anchor links, RFC section citations, fixture
  error codes, mirrored schema definitions, the RFC status ladder, stale
  superseded-revision vocabulary in `docs/` and the README, sibling-repo link
  form (`blob/main` URLs; with sibling checkouts next to this one, linked
  paths and anchors are verified too), the threat-model index and the
  retired schema namespace host; the header
  of `scripts/check-doc-coherence.sh` is the authoritative description of
  what each stage enforces.
- Run `make validate` before opening a PR; it runs every check above plus
  `make kat-verify` and `make kat-independent` (pinned known-answer values,
  recomputed by two implementations that share no code), exactly as CI does.
  `make kat-independent` needs python-ecdsa:
  `python3 -m pip install --require-hashes -r scripts/requirements-kat.txt`.
- Backward compatibility MUST be addressed explicitly in the PR description.

## Consuming the spec

This rule binds every repository in the project that tests against the spec
(implementations, verifiers, the docs knowledge base). It is a project rule,
not part of the protocol.

- A consumer MUST pin the spec by full commit SHA in one committed file, and
  its blocking CI MUST check out the spec at that SHA. A branch name or tag is
  not a pin.
- The pin MUST be bumped by the `aitp-ci` reusable workflow `bump-spec-ref`,
  run from the consumer's `bump-spec.yml` on the `spec-released` dispatch that
  [`notify-spec-consumers.yml`](.github/workflows/notify-spec-consumers.yml)
  sends on every conformance-relevant push to `main`. The bump opens a held
  PR: adopting a spec revision is a reviewed change, and that PR's CI runs the
  new fixtures.
- A job that checks out the spec's floating `main` is allowed only as a
  non-blocking canary (for example a scheduled run, or a job that is not a
  required check). It warns early that a spec change will break the
  consumer, and it never turns the consumer's own PRs red.
- A new consumer is added to `notify-spec-consumers.yml` and to the
  consumer table in [`docs/ecosystem.md`](docs/ecosystem.md#spec-consumers-and-their-pins).
  The `aitp-deps-bot` GitHub App must be installed on it, or the dispatch
  fails.

## Style

- Use RFC 2119 keywords (MUST, SHOULD, MAY) consistently in normative text.
- Use present tense ("Verifiers MUST verify…", not "Verifiers should verify…").
- JSON examples MUST be valid against the corresponding schema.

## Normative RFCs (v0.3 core, Review)

- **[RFC-AITP-0001 Core](rfcs/RFC-AITP-0001-core.md)**
- **[RFC-AITP-0002 Identity](rfcs/RFC-AITP-0002-identity.md)**
- **[RFC-AITP-0003 Agent Manifest](rfcs/RFC-AITP-0003-manifest.md)**
- **[RFC-AITP-0004 Mutual Handshake](rfcs/RFC-AITP-0004-mutual-handshake.md)**
- **[RFC-AITP-0005 TCT](rfcs/RFC-AITP-0005-tct.md)**
- **[RFC-AITP-0006 Delegation](rfcs/RFC-AITP-0006-delegation.md)**
- **[RFC-AITP-0007 Key Resolution](rfcs/RFC-AITP-0007-key-resolution.md)**
- **[RFC-AITP-0008 Revocation](rfcs/RFC-AITP-0008-revocation.md)**
- **[RFC-AITP-0009 Security](rfcs/RFC-AITP-0009-security.md)**

## Opt-in, Reserved and Planned RFCs

Statuses are from the single RFC lifecycle in
[`governance/RFC-PROCESS.md`](governance/RFC-PROCESS.md#rfc-lifecycle); the
per-RFC table is [`rfcs/README.md`](rfcs/README.md).

- **[RFC-AITP-0010 Session Trust Bundle](rfcs/RFC-AITP-0010-session-trust-bundle.md)** *(Draft, opt-in — not part of v0.3 core conformance)*
- **[RFC-AITP-0011 Multi-hop Delegation](rfcs/RFC-AITP-0011-multihop-delegation.md)** *(Draft, opt-in — not part of v0.3 core conformance)*
- **[RFC-AITP-0012 Extensions](rfcs/RFC-AITP-0012-extensions.md)** *(Reserved — non-normative for `aitp/0.3`)*
- **[RFC-AITP-0013 TCT Renewal Extension](rfcs/RFC-AITP-0013-tct-renewal-extension.md)** *(Planned — stub reserving the number)*
- **[RFC-AITP-0014 A2A Agent Card Security Scheme](rfcs/RFC-AITP-0014-a2a-agent-card.md)** *(Draft, opt-in — not part of v0.3 core conformance)*

## Releases

Releases are cut by maintainers; see [RELEASING.md](RELEASING.md). Every PR
adds an entry under `## Unreleased` in [CHANGELOG.md](CHANGELOG.md).

## Community

- Questions, ideas and implementation help go to
  [Discussions](https://github.com/agentidentitytrustprotocol/agentidentitytrustprotocol/discussions).
- Issues labelled `good first issue` are scoped for a first PR; `help wanted`
  marks work the maintainer would welcome help with.
- Review routing is in [`.github/CODEOWNERS`](.github/CODEOWNERS).
- Repository settings across the organization (descriptions, topics,
  Discussions, private vulnerability reporting, labels) are managed by
  `scripts/handoff/org-settings.sh`, not by hand: it is a dry-run by default,
  snapshots before `--apply`, and restores with `--rollback`.

All contributors must follow the [Code of Conduct](CODE_OF_CONDUCT.md).
