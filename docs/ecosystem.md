# The AITP ecosystem — where to go for what

This repository is the **specification**: the RFCs, JSON schemas, registries and conformance suite. It deliberately does not document how to *use* an implementation, how to deploy one, or how to run the surrounding services. Those live in sibling repositories, each of which owns its own docs. This page is the single map; other pages in `docs/` link to specific sibling files where relevant and never restate them.

## Ownership rule

| Concern | Owner |
|---|---|
| What is normative (wire formats, verification algorithms, error codes, conformance vectors) | This repo — [`rfcs/`](../rfcs/README.md), [`schemas/`](../schemas/conformance/README.md), [`registries/`](../registries/README.md) |
| How to use or deploy an implementation | The implementation's repo (below) |

If a sibling doc and an RFC ever disagree, **the RFC wins**; please open an issue in the sibling.

## The repositories

All repositories live in the [`agentidentitytrustprotocol`](https://github.com/agentidentitytrustprotocol) GitHub organization; the published site is [agentidentitytrustprotocol.io](https://agentidentitytrustprotocol.io).

| Repository | What it is | Start here |
|---|---|---|
| `aitp-rs` | Reference implementation (Rust) with Python and Node bindings and a CLI | [README](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/README.md) · [docs index](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/README.md) |
| `aitp-verifier-py` | Independent Python implementation of the verification core, written from the RFCs and schemas only | [README](https://github.com/agentidentitytrustprotocol/aitp-verifier-py/blob/main/README.md) |
| `aitp-control-plane` | API-only registry, audit log, revocation list and webhook backend; not in the trust path | [README](https://github.com/agentidentitytrustprotocol/aitp-control-plane/blob/main/README.md) · [docs](https://github.com/agentidentitytrustprotocol/aitp-control-plane/blob/main/docs/README.md) |
| `aitp-playground` | Scenario harness that runs AITP end to end with real LLM agents (a demo, not production) | [README](https://github.com/agentidentitytrustprotocol/aitp-playground/blob/main/README.md) · [getting started](https://github.com/agentidentitytrustprotocol/aitp-playground/blob/main/docs/getting-started.md) |
| `aitp-ui-console` | Monitoring and control console over the playground and control plane | [README](https://github.com/agentidentitytrustprotocol/aitp-ui-console/blob/main/README.md) · [features](https://github.com/agentidentitytrustprotocol/aitp-ui-console/blob/main/docs/FEATURES.md) |
| `aitp-docs` | Cross-repo knowledge base and a read-only MCP server for agents | [README](https://github.com/agentidentitytrustprotocol/aitp-docs/blob/main/README.md) · [client setup](https://github.com/agentidentitytrustprotocol/aitp-docs/blob/main/docs/clients.md) |
| `aitp-website` | The public documentation site; it syncs content from this repo and several of the repos above | — |

> A local checkout directory named `aitp-cp` may exist as a symlink to `aitp-control-plane`. Always use `aitp-control-plane` in links.

## "I want to…"

| I want to… | Read |
|---|---|
| Understand the protocol's shape | [architecture.md](architecture.md), then the [RFC index](../rfcs/README.md) |
| Implement AITP from scratch | [implementer-quickstart.md](implementer-quickstart.md), the RFCs, and the [conformance suite](../schemas/conformance/README.md) |
| Verify a TCT in code | [aitp-rs Python SDK](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/sdk-python.md) · [Node SDK](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/sdk-node.md) · independent reference: [`aitp_verifier/tct.py`](https://github.com/agentidentitytrustprotocol/aitp-verifier-py/blob/main/aitp_verifier/tct.py) and [`jws.py`](https://github.com/agentidentitytrustprotocol/aitp-verifier-py/blob/main/aitp_verifier/jws.py) |
| See exact handshake bytes | [handshake-transcripts](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/handshake-transcripts.md) · [JCS notes](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/jcs.md) |
| Run the conformance suite against an implementation | [aitp-rs conformance](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/conformance.md) · [verifier conformance coverage](https://github.com/agentidentitytrustprotocol/aitp-verifier-py/blob/main/README.md#conformance-coverage) |
| Deploy: replay cache, state, rate limits, hardening | [deployment](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/deployment.md) · [transport hardening](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/transport-hardening.md) · spec-level defaults in [operational-guidance.md](operational-guidance.md) |
| Store and rotate keys | [key management](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/key-management.md#rotation) |
| Use shortened TCT renewal | [tct-renewal](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/tct-renewal.md) · normative: RFC-AITP-0004 §8.1 and [RFC-AITP-0013](../rfcs/RFC-AITP-0013-tct-renewal-extension.md) |
| Use multi-hop delegation or session bundles (opt-in) | [multihop-delegation](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/multihop-delegation.md) · [session-bundle](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/session-bundle.md) |
| Run a registry / audit / revocation service | [control-plane API](https://github.com/agentidentitytrustprotocol/aitp-control-plane/blob/main/docs/api.md) · [events](https://github.com/agentidentitytrustprotocol/aitp-control-plane/blob/main/docs/events.md) |
| Try the protocol end to end | [playground getting started](https://github.com/agentidentitytrustprotocol/aitp-playground/blob/main/docs/getting-started.md) · [scenarios](https://github.com/agentidentitytrustprotocol/aitp-playground/blob/main/docs/scenarios.md) |
| Give an AI agent access to the spec | [aitp-docs client setup](https://github.com/agentidentitytrustprotocol/aitp-docs/blob/main/docs/clients.md) |
| Use AITP alongside MCP's OAuth authorization | [mcp-mapping.md](mcp-mapping.md) (non-normative). Not to be confused with the `aitp-docs` MCP server above, which serves the spec to agents. |

## Spec consumers and their pins

Every repository that tests against the spec pins it by commit SHA and adopts a new revision through a held bump PR; the rule is in [CONTRIBUTING.md](../CONTRIBUTING.md#consuming-the-spec). [`notify-spec-consumers.yml`](../.github/workflows/notify-spec-consumers.yml) dispatches `spec-released` to the consumers marked "dispatched".

| Consumer | SHA-pin file | Bumped by | Dispatched |
|---|---|---|---|
| `aitp-rs` | `tests/schemas/SPEC_VERSION` | `bump-spec.yml` → `aitp-ci` `bump-spec-ref` (file mode) | yes |
| `aitp-verifier-py` | `SPEC_VERSION` (planned, VP1.1; until then CI tracks floating `main`) | `bump-spec.yml` → `bump-spec-ref` (planned, VP1.1) | yes |
| `aitp-docs` | `sources.lock.json` (`sources.spec.sha`) | planned, DOC1.1 | not yet |
| TypeScript verifier (repository not yet created) | `SPEC_VERSION` (planned) | `bump-spec-ref` (planned) | not yet |

A floating-`main` job, such as `aitp-verifier-py`'s daily scheduled run, is a non-blocking canary only. `aitp-website` is not a pinning consumer: it republishes on the `docs-updated` dispatch.

## Schema namespace

Every canonical JSON Schema's `$id` lives under `https://agentidentitytrustprotocol.io/schema/v0.3/`. The host is the project domain `agentidentitytrustprotocol.io`, which the project owns; `aitp-website` serves it. The `$id` is an identifier: no part of the spec dereferences it, and a validator never needs to fetch it. The site serves each schema at its `$id` URL as a convenience; the canonical copy is `schemas/json/` at a `schema-vX.Y.Z` tag. No other host is an AITP schema namespace.

## Link convention for this repository

- Links **within** this repository are relative.
- Links to a sibling repository are full `https://github.com/agentidentitytrustprotocol/<repo>/blob/main/<path>` URLs to a specific file — never `/tree/` URLs, and never the local directory alias `aitp-cp`. The website sync rewrites those to the rendered site page when the file is published there, and they work on GitHub otherwise.
- Do not hard-code sibling release versions or conformance counts in prose here; link the sibling's README or [`schemas/conformance/README.md`](../schemas/conformance/README.md), which owns the counts.
