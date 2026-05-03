# Manifest examples

This directory contains illustrative Agent Manifests (RFC-AITP-0003).

## Files

| File | Use |
|---|---|
| [`agent-b-manifest.json`](agent-b-manifest.json) | Documentation example with **placeholder signature strings**. Schema-valid, but the signatures are not real and will fail cryptographic verification. Useful for showing the Manifest shape to readers and for syntactic tests. |

## Why placeholders?

The signature, `proof_of_possession.signature`, and AID identifier are
left as readable placeholder tokens (`sig_..._placeholder_AAAA...`,
`worker_pubkey_AID_v01_placeholder_wwwwwwwww`) so that:

- Anyone reading the file can immediately see what each field is for
  without confusion about whether the value is "real".
- The example never accidentally ends up in a real trust path because
  no real key is published here.

## When you need real signatures

For cross-implementation interop testing — i.e. an artifact that
actually verifies — see
[`schemas/conformance/known-answer/signed-examples/`](../../schemas/conformance/known-answer/signed-examples/).
That directory is reserved for artifacts minted from the pinned
[KAT keypairs](../../schemas/conformance/known-answer/keypairs.json)
and is the canonical location for byte-stable signed examples.

## Adding new placeholder examples

Schema-valid placeholder Manifests showing additional configurations
(pinned-key identity, multi-anchor `accepted_trust_anchors`, etc.) are
welcome. They should:

1. Validate against
   [`schemas/json/aitp-manifest.schema.json`](../../schemas/json/aitp-manifest.schema.json).
2. Use placeholder strings that match the conventions in
   [`schemas/conformance/PLACEHOLDERS.md`](../../schemas/conformance/PLACEHOLDERS.md)
   so a future minting script can swap them out.
3. Be added to the table above.
