# AITP Examples

These are illustrative JSON artifacts for the AITP `aitp/0.2` wire format.
They are **not** real cryptographic material — signatures and proofs use
placeholder strings. For the v0.2 portable trust artifacts (TCT, grant
voucher, delegation token), which travel on the wire as compact JWS
strings (RFC-AITP-0001 §5.4.5), each example shows the wire form as a
clearly-fake three-segment placeholder string alongside a `_decoded_claims`
companion object showing what the payload segment would decode to.

## Layout

```
examples/
├── manifest/        Agent Manifest examples (RFC-AITP-0003)
├── tct/             Peer-issued Trust Context Tokens as compact JWS (RFC-AITP-0005)
├── grant-voucher/   Grant vouchers — the TCT's delegation companion (RFC-AITP-0005 §8)
├── delegation/      Single-hop delegation tokens as compact JWS (RFC-AITP-0006)
├── revocation/      Signed revocation snapshots (RFC-AITP-0008)
└── non-normative/   Multi-message flow transcripts (NOT individually schema-valid)
```

## Validation

These examples are validated by `scripts/validate-json.sh` against:

- `schemas/json/aitp-manifest.schema.json` — manifest examples
- `schemas/json/aitp-tct.schema.json` — TCT decoded claims
- `schemas/json/aitp-grant-voucher.schema.json` — grant voucher decoded claims
- `schemas/json/aitp-delegation.schema.json` — delegation token decoded claims
- `schemas/json/aitp-revocation-list.schema.json` — revocation snapshots

For the compact-JWS artifacts the schemas validate the *decoded claims*
objects; the placeholder wire strings only match the structural
three-segment `CompactJws` pattern, never a real signature.

`non-normative/` contains multi-message narratives (e.g. a full
Mutual Handshake transcript, including the `MUTUAL_COMMIT` /
`MUTUAL_COMMIT_ACK` payloads that carry the TCT and grant voucher).
These are validated for JSON syntax only — their individual inner
messages are covered by the schema-valid examples in the sibling
directories.

Run `make json-validate` to validate the full set.

## Conformance fixtures

For pass/fail behavioral fixtures (replay rejection, expired TCT, scope-
exceeded delegation, …) see [`schemas/conformance/`](../schemas/conformance/).
For **real**, cryptographically verifiable compact JWS artifacts minted
from the pinned KAT keypairs, see
[`schemas/conformance/known-answer/signed-examples/`](../schemas/conformance/known-answer/signed-examples/).
