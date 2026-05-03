# Revocation snapshot examples

Schema-valid Agent revocation snapshots (RFC-AITP-0008 §1.5). Both
files use **placeholder signature strings** — they are illustrative,
not cryptographically valid.

## Files

| File | Use |
|---|---|
| [`empty-list.json`](empty-list.json) | The most common runtime case: a signed snapshot with `entries: []`, asserting that no TCT issued by the peer has been revoked since the last snapshot. |
| [`with-entry.json`](with-entry.json) | Snapshot listing one revoked TCT with a `reason` string. The `reason` field is informational; consumers MUST NOT use it for trust decisions (RFC-AITP-0008 §1.6). |

## When you need real signatures

For cross-implementation interop testing — i.e. an artifact that
actually verifies — see
[`schemas/conformance/known-answer/signed-examples/revocation/`](../../schemas/conformance/known-answer/signed-examples/)
once minted, and the canonical-bytes vector
`kat-revocation-001` in
[`schemas/conformance/known-answer/jcs-sha256.json`](../../schemas/conformance/known-answer/jcs-sha256.json).
