# AITP Versioning Policy

AITP uses a layered versioning model so that the wire format, the canonical schemas, and the published RFCs can evolve at different rates without surprising implementers.

`aitp/0.1` is the **first published version**. It is agent-to-agent from the
start; there is no earlier service-consumer version to migrate from.

## Layers

| Layer | Identifier | Example | Compat rules |
|---|---|---|---|
| Protocol version | `version` field on the envelope, TCT, and Manifest | `aitp/0.1` | Major mismatch ⇒ `UNKNOWN_VERSION`. Minor bumps are backward compatible. |
| JSON Schema namespace | `$id` URI on each canonical schema | `https://aitp.dev/schema/v0.1/...` | Breaking changes bump the path segment to `v0.2/`. |
| TCT version | `version` inside the TCT | `aitp/0.1` | Mirrors the protocol version. Consumers MUST reject unknown versions. |
| Manifest version | `version` inside the Manifest | `aitp/0.1` | Mirrors the protocol version. |
| RFC version | RFC document `Version:` header | `0.1.0-draft` | Tracks status (`-draft`, `-rc`, `-final`). |

## Change classes

- **Editorial / clarification** — patch-level RFC bump. No schema or wire change.
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
