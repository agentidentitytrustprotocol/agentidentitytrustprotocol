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
| Protocol version | `version` field on JCS-profile objects (envelope, Manifest, revocation snapshot); `ver` claim on JWS-profile artifacts (TCT, grant voucher, delegation token) | `aitp/0.2` | Major mismatch ⇒ `UNKNOWN_VERSION`. Minor bumps are backward compatible. |
| JSON Schema namespace | `$id` URI on each canonical schema | `https://aitp.dev/schema/v0.2/...` | Breaking changes bump the path segment (`v0.1/` → `v0.2/`). The repo keeps a single flat `schemas/json/` directory tracking the current namespace; frozen earlier namespaces are available via the `schema-vX.Y.Z` git tags below, not via parallel directories. |
| TCT version | `ver` claim inside the TCT JWS payload | `aitp/0.2` | Mirrors the protocol version. Consumers MUST reject unknown versions. |
| Manifest version | `version` inside the Manifest | `aitp/0.2` | Mirrors the protocol version. |
| RFC version | RFC document `Version:` header | `0.2.1-draft` | Tracks status (`-draft`, `-rc.N`, `-final`) **and each document's own editorial history**. Versions may diverge between documents within one protocol revision — a patch bump on one RFC does not move the others. The protocol literal is a separate layer and does not follow it. |

## Change classes

- **Editorial / clarification** — patch-level RFC bump. No schema or wire change.
  This class also covers **correcting a conformance artifact to match what the RFC
  already required**: if a known-answer vector or signed example contradicts the
  normative text, bringing the artifact into line is a patch bump on the RFCs whose
  citations move, not a breaking change — the requirement did not change, the
  artifact was wrong. Such a bump is what
  [`schemas/conformance/known-answer/README.md`](schemas/conformance/known-answer/README.md)'s
  Stability rule ("an existing vector's output MUST NOT change without an RFC bump")
  requires, and the CHANGELOG MUST publish the old and new values so a consumer
  pinning them can identify their copy.
- **Backward-compatible addition** — minor RFC bump. New optional fields, new error codes, new identity types. Unknown JSON fields outside explicit `extensions` namespaces MUST be rejected. Unknown keys *inside* `extensions` MUST be ignored. See RFC-AITP-0001 §7.
- **Breaking change** — major RFC bump and a new schema namespace. Migration notes required.

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
