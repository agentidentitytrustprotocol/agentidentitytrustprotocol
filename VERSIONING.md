# AITP Versioning Policy

AITP uses a layered versioning model so that the wire format, the canonical schemas, and the published RFCs can evolve at different rates without surprising implementers.

`aitp/0.1` was the **first published version** (reached `v0.1.0-rc.3`). It is agent-to-agent from the
start; there is no earlier service-consumer version to migrate from.
`aitp/0.2` was a **breaking revision**: cryptographic agility (Ed25519 + P-256) and
re-serialization of the portable trust artifacts (TCT, grant voucher, delegation
token) as compact JWS (see [RFC-AITP-0001 §1](rfcs/RFC-AITP-0001-core.md#1-status-of-this-memo)
and the CHANGELOG for the migration record).
`aitp/0.3`, the current revision, is a **breaking revision** with one change of
substance: the envelope signature covers the whole envelope (issue #87). See
[Migrating from `aitp/0.2` to `aitp/0.3`](#migrating-from-aitp02-to-aitp03).

## Layers

| Layer | Identifier | Example | Compat rules |
|---|---|---|---|
| Protocol version | `version` field on JCS-profile objects (envelope, Manifest, revocation snapshot, session bundle); `ver` claim on JWS-profile artifacts (TCT, grant voucher, delegation token) | `aitp/0.3` | Major mismatch ⇒ rejected. Pre-1.0, the minor position is the revision, so **any** revision mismatch is rejected with the artifact's unknown-version code (see [Forward / backward compatibility](#forward--backward-compatibility)): an `aitp/0.3` verifier rejects `aitp/0.2` and `aitp/0.1`. |
| JSON Schema namespace | `$id` URI on each canonical schema | `https://agentidentitytrustprotocol.io/schema/v0.3/...` | Breaking changes bump the path segment (`v0.1/` → `v0.2/` → `v0.3/`). A change to the namespace host or to a schema's `$id` name that changes no validation outcome is schema metadata, not a breaking change, and does not bump the segment. The repo keeps a single flat `schemas/json/` directory tracking the current namespace; frozen earlier namespaces are available via the `schema-vX.Y.Z` git tags below, not via parallel directories. |
| TCT version | `ver` claim inside the TCT JWS payload | `aitp/0.3` | Mirrors the protocol version. Consumers MUST reject unknown versions. |
| Manifest version | `version` inside the Manifest | `aitp/0.3` | Mirrors the protocol version. |
| RFC version | RFC document `Version:` header | `0.3.0-draft` | Tracks the RFC's lifecycle stage (`-draft`, `-rc.N`; the Reserved and Planned placeholders carry `-reserved` / `-planned`) **and each document's own editorial history**. Versions may diverge between documents within one protocol revision — a patch bump on one RFC does not move the others. The protocol literal is a separate layer and does not follow it. |

## Change classes

- **Editorial / clarification** — patch-level RFC bump. No schema or wire change.
  This class also covers **reconciling normative text with a pinned artifact when
  the two contradict each other**, in either direction:
    - *Artifact wrong, prose right* — a known-answer vector or signed example
      contradicts the normative text, and the artifact is brought into line. The
      requirement did not change; the artifact was wrong.
    - *Prose wrong, artifact right* — the normative text misdescribes what the
      pinned artifact has always encoded, and the text is brought into line. The
      pinned bytes do not change, so no consumer's stored copy moves. **But this
      direction is not a no-op for implementers:** anyone who implemented from the
      incorrect prose produces different bytes and MUST change to interoperate. A
      correction in this direction therefore additionally requires an **erratum note
      in the affected section**, recording what the text used to say and that
      implementations following it must switch. RFC-AITP-0002 §3.1's timestamp
      encoding is the worked example.
  Either direction is a patch bump on the RFCs whose citations move, not a breaking
  change. Such a bump is what
  [`schemas/conformance/known-answer/README.md`](schemas/conformance/known-answer/README.md)'s
  Stability rule ("an existing vector's output MUST NOT change without an RFC bump")
  requires, and the CHANGELOG MUST publish the old and new values so a consumer
  pinning them can identify their copy.
- **Backward-compatible addition** — minor RFC bump. New optional fields, new error codes, new identity types. Unknown JSON fields outside explicit `extensions` namespaces MUST be rejected with `UNKNOWN_FIELD`. Unknown keys *inside* `extensions` MUST be ignored. See RFC-AITP-0001 §7.
  For error codes, this class composes with [`registries/error-codes.md`](registries/error-codes.md)'s stability note ("new codes can be added without an RFC") rather than contradicting it: the registry note waives the need for a new RFC *document*, while this class governs how the `Version:` header moves on the existing RFCs whose normative text gains the code. One addition, two policies, different questions — no new document, minor bump.
- **Breaking change** — major RFC bump and a new schema namespace. Migration notes required.
  On the `aitp/0.3` line a breaking change is taken only as a security fix; see
  [What is frozen](#what-is-frozen-aitp03-line).

> **Pre-1.0 position mapping.** While the protocol literal is `aitp/0.M`, RFC document
> versions stay in the `0.M.x` line. The **minor position is reserved for the protocol
> revision** — it moved `0.1.x` → `0.2.x` only because `aitp/0.2` was itself a breaking
> revision, and `0.2.x` → `0.3.0` only because `aitp/0.3` was. A protocol revision
> resets **every** document to `0.M.0` (with its `-draft`, `-reserved` or `-planned`
> suffix), however far the documents had diverged inside the previous revision. A change
> whose *class* is a backward-compatible addition, made **inside** an existing protocol
> revision, therefore takes a **patch-position** bump and records its class in the
> CHANGELOG; it does not move the minor position. Doing otherwise would put a `0.4.0-draft`
> document inside protocol `aitp/0.3` — readable as a protocol break, and leaving document
> versions permanently offset once `aitp/0.4` arrives. The `UNKNOWN_FIELD` addition is the
> worked example: minor class, patch position.

## What is frozen (aitp/0.3 line)

From the first release that carries this section until 1.0, the `aitp/0.3` line makes
**no wire-breaking change** to the surfaces RFC-AITP-0001 to RFC-AITP-0009 define. The only
exception is a disclosed security fix handled under [SECURITY.md](SECURITY.md). This is a
promise to implementers: an artifact that verifies (or fails, with a given code) today
does the same under every later `aitp/0.3` release.

The freeze covers the wire, not the prose. The RFCs keep moving through their lifecycle
stages and can still be clarified. The "backward-incompatible changes remain possible"
sentence in RFC-AITP-0001 §1 is narrowed by this section to the security exception. The
change classes above still apply, within the limits below. In particular, a "new optional
field" outside `extensions` is not a backward-compatible addition on this line, because a
peer that does not know the field rejects it with `UNKNOWN_FIELD` (RFC-AITP-0001 §7).

### Frozen

| Surface | What does not change | Defined in |
|---|---|---|
| Signing inputs | The bytes every signature and proof covers: the envelope `sig_input_v2`, the JCS profile and its wrapper rule, the PoP signing input, the algorithm-tagged signature format, the compact-JWS input and header rules, and the signing primitive for each algorithm. | RFC-AITP-0001 §5.4, §5.4.1, §5.4.2, §5.4.3, §5.4.5, §5.4.6; RFC-AITP-0002 §3.1; RFC-AITP-0003 §6.1; RFC-AITP-0005 §7.1; RFC-AITP-0006 §6; RFC-AITP-0008 §1.5 |
| Message and field sets outside `extensions` | The `message_type` values, and the members of every envelope, payload, Manifest, identity descriptor, revocation snapshot and JWS claims set. No member outside `extensions` / `ext` is added, removed, renamed, retyped or made REQUIRED. The reject-unknown-member rule and the ignore-inside-`extensions` rule stay as they are. | RFC-AITP-0001 §5.2, §7; RFC-AITP-0002 §1; RFC-AITP-0003 §3; RFC-AITP-0004 §3; RFC-AITP-0005 §2, §8.1; RFC-AITP-0006 §2; RFC-AITP-0008 §1.5 |
| Error codes and their meanings | Every code in [`registries/error-codes.md`](registries/error-codes.md), its meaning, and which code a given failure returns, including each artifact's check order. | RFC-AITP-0001 §5.4, §5.7; RFC-AITP-0003 §10; RFC-AITP-0004 §6; RFC-AITP-0006 §4 |
| The `aitp/0.3` literal | Its spelling, the fields that carry it (`version`, `ver`), and the rule that any other value is rejected with the artifact's unknown-version code before anything else is checked. | RFC-AITP-0001 §5.2, §7; RFC-AITP-0005 §2 |
| The known-answer set | Additions only. No existing vector's output and no known-answer keypair changes. | RFC-AITP-0001 §10 (item 8); [`known-answer/README.md`](schemas/conformance/known-answer/README.md) Stability |
| Schema validation outcomes | Every existing fixture and every committed artifact passes or fails the canonical JSON Schemas exactly as it does now. | RFC-AITP-0001 §10 (item 9), §11; [Fixture-input validation](schemas/conformance/README.md#fixture-input-validation) |

A contradiction between the prose and a pinned artifact is settled **toward the pinned
bytes**: the prose is corrected with an erratum note (the "prose wrong, artifact right"
class above). The "artifact wrong, prose right" direction changes a pinned output, so on
this line it is a wire change and is taken only as a security fix.

### Allowed

| Change | Condition | Defined in |
|---|---|---|
| Additive identity types | A new `IdentityDescriptor.type`, registered at `Proposed`. A peer that does not implement it already rejects it with `IDENTITY_FAILED`, so no existing outcome moves. | RFC-AITP-0002 §5; [`registries/identity-types.md`](registries/identity-types.md) |
| Opt-in extension RFCs | New behaviour carried inside `extensions` / `ext` under registered keys, or a new draft RFC whose fixtures are gated on a named `feature`. Additive registry rows (extension keys, message types, capabilities, error codes) enter at `Proposed`, and are used only by the opt-in surface. None of them changes the outcome of an existing core fixture. | RFC-AITP-0012 §1, §1.1; RFC-AITP-0001 §7, §9, §10 (item 9) |
| Clarifications | Editorial and clarification changes, including a "prose wrong, artifact right" erratum. | RFC-AITP-0002 §3.1 (the worked erratum); [Change classes](#change-classes) |
| New fixtures and known-answer vectors | They pin behaviour the RFCs already require. | RFC-AITP-0001 §10 (items 8 and 9) |
| Schema refactors | A canonical schema may be restructured, for example `aitp-identity.schema.json` taking a new identity type, when **every existing fixture's validation outcome is unchanged**. `$id` metadata follows the [Layers](#layers) rule. | RFC-AITP-0001 §10 (item 9); RFC-AITP-0002 §1 |
| Security fixes | A disclosed fix for a defect against the threat model ships as a new `aitp/0.3.x` release tag with a published advisory and a strict cutover ([SECURITY.md](SECURITY.md#security-fixes-that-change-the-wire)). A dual-accept window is reconsidered only once real deployments exist. | RFC-AITP-0009 §1, §2 |

Any other wire change waits for 1.0.

### Conformance fixtures and reports

- **Frozen:** each existing fixture's `id` and its `expected` outcome (that is the wire
  freeze seen through the fixtures); the meaning of every fixture metadata key in
  [`aitp-conformance-fixture.schema.json`](schemas/json/aitp-conformance-fixture.schema.json)
  (`id`, `rfc`, `status`, `required_for_v0_1`, `required_for_core`, `feature`, `dynamic`,
  `dynamic_fields`); each existing fixture's `status` and core-tier flags (new fixtures may join a tier, but none leaves it or changes tier); and the three claim
  strings of RFC-AITP-0001 §10.
- **Metadata key names are frozen.** `required_for_core` marks the `aitp/0.3` core tier. It
  was renamed once from `required_for_v0_2` (2026-10-24), together with the runners that
  read it by name (aitp-rs, aitp-verifier-py) and the conformance report schema, which copies
  it. Its meaning and the fixtures it marks did not change. No other metadata key is renamed
  on this line.
- **Not frozen:** the [conformance report](docs/conformance-badge.md) format. It is not a
  wire artifact, and it changes only by moving to a new `report_version`.

### Who classifies a change

Whether a change is a clarification or a wire change, and whether a wire change is a
security fix, is decided by the maintainer acting as shepherd under the `CHARTER.md`
§ Core Team substitute, or by the Core Team once one is seated. Each classification of
a review comment or erratum is recorded with the change. The decision and its reversal
trigger are in [`governance/DECISIONS.md`](governance/DECISIONS.md).

## Forward / backward compatibility

- Unknown JSON fields outside explicit `extensions` namespaces MUST be rejected (RFC-AITP-0001 §7). Forward compatibility is provided through `extensions`, not through silent unknown-field tolerance.
- Verifiers receiving an unknown `version` MUST reject it with the artifact's unknown-version code and MUST NOT attempt to process it further. That code is `UNKNOWN_VERSION` for envelopes and JWS-profile artifacts (`ver`), `MANIFEST_VERSION_UNKNOWN` for Manifests, `REVOCATION_SNAPSHOT_INVALID` for revocation snapshots and `BUNDLE_VERSION_MISMATCH` for session trust bundles (see [`registries/error-codes.md`](registries/error-codes.md)).
- New identity types are registered in [`registries/identity-types.md`](registries/identity-types.md) and start at status `Proposed`. They graduate to `Stable` once two independent implementations interoperate.

## Migrating from `aitp/0.2` to `aitp/0.3`

**What breaks.** Two things, both wire-visible:

1. **The envelope signing input.** The envelope signature is computed over
   `sig_input_v2 = "aitp-envelope-v2" || 0x00 || JCS(envelope without "signature")`,
   hashed with SHA-256 and signed per the sender's algorithm
   ([RFC-AITP-0001 §5.4](rfcs/RFC-AITP-0001-core.md#54-signature)). It covers every
   member, so `version`, `message_type` and `extensions` are now sender-authenticated.
   The `aitp/0.2` input as tagged (`v0.2.0-draft`) was the pipe-composed string
   `message_id|timestamp|sender.agent_id|hex(sha256(JCS(payload)))`, which covered none
   of them. Envelopes are checked in a fixed order: `version`, then the member set, then
   the signature (fixtures env-008 to env-010).
2. **The literal.** Every `version` field (envelope, Manifest, revocation snapshot,
   session bundle) and every `ver` claim (TCT, grant voucher, delegation token) is
   `aitp/0.3`, and the schema `$id` namespace is `https://agentidentitytrustprotocol.io/schema/v0.3/`. Because
   the literal is inside every signed artifact, every signature changes: the known-answer
   vectors and signed examples are re-minted, and the CHANGELOG lists each old and new
   output.

**Strict cutover.** There is no dual-accept window. An `aitp/0.3` implementation does
not implement `aitp/0.2`: it rejects an `aitp/0.2` artifact with that artifact's unknown-version code
(`UNKNOWN_VERSION` for an envelope or a JWS-profile artifact; see Forward / backward
compatibility above for the others),
before the member set or the signature is examined, even when its signature is valid
(fixture env-011). Peers upgrade together; an `aitp/0.2` peer and an `aitp/0.3` peer
do not interoperate. Under the [freeze](#what-is-frozen-aitp03-line) no further
revision boundary is planned before 1.0, so this strict cutover applies next either to a
security fix on the `aitp/0.3` line or to the 1.0 revision.

**What is unchanged.** Everything else: the compact-JWS profile and its header rules,
the JCS embedded-signature profile for Manifests, revocation snapshots and session
bundles (only the literal inside them changes), the AID forms and identity binding, the
handshake, TCT, delegation, multi-hop and revocation semantics, the error-code
registry, canonical byte lengths (the literal keeps its length), and every key in the
known-answer keypair set. The conformance fixture schema's core-tier key is `required_for_core`;
for `aitp/0.3` it marks the core fixtures.

## Release tags

Schema artifacts are tagged independently of the spec:

- `vX.Y.Z[-draft]` — tag on the specification as a whole (e.g. `v0.2.0-draft`); see [RELEASING.md](RELEASING.md).
- `schema-vX.Y.Z` — tag on the canonical JSON Schemas in `schemas/json/`.
- `rfc-aitp-NNNN-vX.Y.Z` — tag on individual RFC documents when they reach `Accepted` on the RFC status ladder. No RFC has reached `Accepted` yet, so no such tag exists.

Downstream consumers pin to a specific tag and upgrade on their own schedule.

**The v0.2 line is frozen** at commit `f9ee7ea`, the last commit whose literal is
`aitp/0.2` (it already carries the new envelope signing input, landed one step ahead of
the literal). The existing `v0.2.0-draft` and `schema-v0.2.0` tags point at an earlier
v0.2 line commit (`ea22c71`); `f9ee7ea` itself is tagged `v0.2.1-draft` and
`schema-v0.2.1`. The first `aitp/0.3` tags are `v0.3.0-draft` and `schema-v0.3.0`; the latest are `v0.3.2-draft` and `schema-v0.3.2`.

## Status ladder

RFC lifecycle stages are defined in exactly one place: the
[RFC lifecycle](governance/RFC-PROCESS.md#rfc-lifecycle) in
`governance/RFC-PROCESS.md`
(`Reserved → Planned → Idea → Draft → Review → Release Candidate → Final Comment Period → Accepted | Rejected`).
The per-RFC status table is in [`rfcs/README.md`](rfcs/README.md), and
`scripts/check-doc-coherence.sh` checks every RFC's `**Status:**` header
against that ladder. This document does not define a status vocabulary of
its own.
