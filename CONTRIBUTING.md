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

## Conformance fixtures

Every fixture under `schemas/conformance/*.json` MUST have a matching entry
in `scripts/fixture-validation-map.json`, keyed by the fixture's `id` field
(not its filename). `make json-validate` (`scripts/validate-json.sh`) treats
an unmapped fixture as a build failure, never a silent skip — a validator
that quietly skips what it does not recognize is worse than no validator at
all.

When you add a fixture:

1. Add the fixture JSON under `schemas/conformance/`.
2. Add a matching entry to `scripts/fixture-validation-map.json`. For each
   artifact embedded in the fixture's `input` (a session bundle, TCT claims,
   a manifest, …), name:
   - `pointer` — the RFC 6901 JSON pointer to the artifact inside the fixture.
   - `schema` — the schema filename under `schemas/json/` it must satisfy.
   - `expect` — `valid`, `invalid`, or `invalid_known_defect`.
   - `reason` — required whenever `expect` is not `valid`; explains why the
     artifact is expected to fail validation.
   - `wrap` — optional; re-wraps the artifact as `{KEY: artifact}` for a
     schema that describes the wrapped transport form rather than the body.

   A fixture with no embedded artifacts to validate MUST say so explicitly
   with a `no_artifacts` entry naming a reason, instead of being omitted.

`expect` is checked in **both directions**: an artifact declared `invalid`
that starts validating fails the build exactly as loudly as one declared
`valid` that stops validating. If you fix a fixture's underlying defect,
update its map entry in the same commit — otherwise the build fails there
instead.

Example entry:

```json
"bundle-002": {
  "artifacts": [
    {
      "pointer": "/input/session_bundle",
      "schema": "aitp-session-bundle.schema.json",
      "expect": "valid"
    }
  ]
}
```

See [`schemas/conformance/README.md`](schemas/conformance/README.md) for the
fixture format itself, and `scripts/normalize-fixture-input.py` for how
placeholder tokens (`__VALID_A_SIG__`, `__NOW_PLUS_3600__`, …) are substituted
before an artifact is checked against its schema.

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
- Documentation MUST stay coherent with itself — RFC version claims in
  `rfcs/README.md` MUST match each RFC's own `Version:` header, and every
  intra-repo `path.md#anchor` link MUST resolve (`make doc-coherence`).
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
