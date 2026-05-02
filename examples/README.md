# AITP Examples

These are illustrative JSON artifacts for the AITP wire format. They are
**not** real cryptographic material — signatures and proofs use placeholder
strings.

## Layout

```
examples/
├── manifest/        Agent Manifest examples (RFC-AITP-0003)
├── tct/             Peer-issued Trust Context Tokens (RFC-AITP-0005)
├── delegation/      Single-hop delegation tokens (RFC-AITP-0006)
└── non-normative/   Multi-message flow transcripts (NOT individually schema-valid)
```

## Validation

These examples are validated by `scripts/validate-json.sh` against:

- `schemas/json/aitp-manifest.schema.json` — manifest examples
- `schemas/json/aitp-tct.schema.json` — TCT examples
- `schemas/json/aitp-delegation.schema.json` — delegation tokens

`non-normative/` contains multi-message narratives (e.g. a full
Mutual Handshake transcript). These are validated for JSON syntax
only — their individual inner messages are covered by the
schema-valid examples in the sibling directories.

Run `make json-validate` to validate the full set.

## Conformance fixtures

For pass/fail behavioral fixtures (replay rejection, expired TCT, scope-
exceeded delegation, …) see [`schemas/conformance/`](../schemas/conformance/).
