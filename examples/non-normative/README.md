# Non-normative examples

This directory contains illustrative wrappers showing complete flows.
Files here do **NOT** individually validate against the JSON schemas in
[`schemas/json/`](../../schemas/json/) — they are multi-message
narratives, not single payloads.

For schema-valid examples of single payloads, see the sibling
directories under [`examples/`](../):

- [`examples/manifest/`](../manifest/) — Agent Manifests (RFC-AITP-0003).
- [`examples/tct/`](../tct/) — Peer-issued Trust Context Tokens (RFC-AITP-0005).
- [`examples/delegation/`](../delegation/) — Single-hop delegation tokens (RFC-AITP-0006).

## Files

| File | Describes |
|---|---|
| [`peer-signed-full-flow.json`](peer-signed-full-flow.json) | Full Mutual Handshake transcript (RFC-AITP-0004): four messages over two round trips, plus the precondition state both peers carry into the exchange. |
