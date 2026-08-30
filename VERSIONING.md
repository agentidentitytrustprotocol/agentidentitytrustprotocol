# AITP Versioning Policy

AITP uses a layered versioning model so that the wire format, the canonical schemas, and the published RFCs can evolve at different rates without surprising implementers.

`aitp/0.1` was the **first published version** (reached `v0.1.0-rc.3`). It is agent-to-agent from the
start; there is no earlier service-consumer version to migrate from.
`aitp/0.2` is a **breaking revision**: cryptographic agility (Ed25519 + P-256) and
re-serialization of the portable trust artifacts (TCT, grant voucher, delegation
token) as compact JWS (see [RFC-AITP-0001 §1](rfcs/RFC-AITP-0001-core.md#1-status-of-this-memo)
and the CHANGELOG for the migration record).

## Layers

| Layer | Identifier | Example | Compat rules |
|---|---|---|---|
| Protocol version | `version` field on JCS-profile objects (envelope, Manifest, revocation snapshot, session bundle); `ver` claim on JWS-profile artifacts (TCT, grant voucher, delegation token) | `aitp/0.2` | Major mismatch ⇒ `UNKNOWN_VERSION`. Minor bumps are backward compatible. |
| JSON Schema namespace | `$id` URI on each canonical schema | `https://aitp.dev/schema/v0.2/...` | Breaking changes bump the path segment (`v0.1/` → `v0.2/`). The repo keeps a single flat `schemas/json/` directory tracking the current namespace; frozen earlier namespaces are available via the `schema-vX.Y.Z` git tags below, not via parallel directories. |
| TCT version | `ver` claim inside the TCT JWS payload | `aitp/0.2` | Mirrors the protocol version. Consumers MUST reject unknown versions. |
| Manifest version | `version` inside the Manifest | `aitp/0.2` | Mirrors the protocol version. |
| RFC version | RFC document `Version:` header | `0.2.3-draft` | Tracks status (`-draft`, `-rc.N`, `-final`) **and each document's own editorial history**. Versions may diverge between documents within one protocol revision — a patch bump on one RFC does not move the others. The protocol literal is a separate layer and does not follow it. |

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

> **Pre-1.0 position mapping.** While the protocol literal is `aitp/0.M`, RFC document
> versions stay in the `0.M.x` line. The **minor position is reserved for the protocol
> revision** — it moved `0.1.x` → `0.2.x` only because `aitp/0.2` was itself a breaking
> revision. A change whose *class* is a backward-compatible addition, made **inside** an
> existing protocol revision, therefore takes a **patch-position** bump and records its
> class in the CHANGELOG; it does not move the minor position. Doing otherwise would put
> a `0.3.0-draft` document inside protocol `aitp/0.2` — readable as a protocol break, and
> leaving document versions permanently offset once `aitp/0.3` arrives. The
> `UNKNOWN_FIELD` addition is the worked example: minor class, patch position.

## Forward / backward compatibility

- Unknown JSON fields outside explicit `extensions` namespaces MUST be rejected (RFC-AITP-0001 §7). Forward compatibility is provided through `extensions`, not through silent unknown-field tolerance.
- Verifiers receiving an unknown `version` MUST reply with `UNKNOWN_VERSION` and MUST NOT attempt to process the message.
- New identity types are registered in [`registries/identity-types.md`](registries/identity-types.md) and start at status `Proposed`. They graduate to `Stable` once two independent implementations interoperate.

## Release tags

Schema artifacts are tagged independently of the spec:

- `schema-vX.Y.Z` — tag on the canonical JSON Schemas in `schemas/json/`.
- `rfc-aitp-NNNN-vX.Y.Z` — tag on individual RFC documents when they hit Final status.

Downstream consumers pin to a specific tag and upgrade on their own schedule.

## Status ladder

| Status | Meaning |
|---|---|
| `Draft` | Open for substantive change. |
| `Review` | Under shepherded review. No structural changes during the FCP window. |
| `Final Comment Period` | Last call. Editorial fixes only. |
| `Final` | Stable. Breaking changes require a new RFC. |
| `Deprecated` | Superseded by another RFC; retained for archaeology. |
