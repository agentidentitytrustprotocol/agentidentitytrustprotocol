# AITP RFC Index

This directory contains the normative RFCs that define the Agent Identity & Trust Protocol (AITP). AITP is an **agent-to-agent** trust protocol; the current revision is **`aitp/0.3`** (v0.1 was the first published version; the v0.2 line re-serialized the portable trust artifacts as compact JWS and added cryptographic agility; `aitp/0.3` makes the envelope signature cover the whole envelope — see [RFC-AITP-0001 §1](RFC-AITP-0001-core.md#1-status-of-this-memo)).

Status values below are drawn from the single lifecycle ladder in
[`governance/RFC-PROCESS.md`](../governance/RFC-PROCESS.md) — see that
document for what each stage means; `(opt-in)` is not a lifecycle stage,
it flags that the RFC is outside v0.3 core conformance (see below).

| RFC | Title | Status |
|---|---|---|
| [RFC-AITP-0001](RFC-AITP-0001-core.md) | Core — envelope, signatures, replay, error codes | Review |
| [RFC-AITP-0002](RFC-AITP-0002-identity.md) | Identity Binding | Review |
| [RFC-AITP-0003](RFC-AITP-0003-manifest.md) | Agent Manifest | Review |
| [RFC-AITP-0004](RFC-AITP-0004-mutual-handshake.md) | Mutual Handshake | Review |
| [RFC-AITP-0005](RFC-AITP-0005-tct.md) | Trust Context Token | Review |
| [RFC-AITP-0006](RFC-AITP-0006-delegation.md) | Single-Hop Delegation | Review |
| [RFC-AITP-0007](RFC-AITP-0007-key-resolution.md) | Key Resolution | Review |
| [RFC-AITP-0008](RFC-AITP-0008-revocation.md) | Revocation | Review |
| [RFC-AITP-0009](RFC-AITP-0009-security.md) | Security & Threat Model | Review |
| [RFC-AITP-0010](RFC-AITP-0010-session-trust-bundle.md) | Session Trust Bundle | Draft (opt-in) |
| [RFC-AITP-0011](RFC-AITP-0011-multihop-delegation.md) | Multi-hop Delegation | Draft (opt-in) |
| [RFC-AITP-0012](RFC-AITP-0012-extensions.md) | Extensions (ZK, TEE) — reserved | Reserved |
| [RFC-AITP-0013](RFC-AITP-0013-tct-renewal-extension.md) | TCT Renewal Extension | Planned |
| [RFC-AITP-0014](RFC-AITP-0014-a2a-agent-card.md) | A2A Agent Card Security Scheme | Draft (opt-in) |

## Reading order

The numbering matches dependency order. Read top-to-bottom:

1. **[RFC-AITP-0001 Core](RFC-AITP-0001-core.md)** — envelope, replay protection, signatures, error codes.
2. **[RFC-AITP-0002 Identity](RFC-AITP-0002-identity.md)** — identity binding model and trust anchors.
3. **[RFC-AITP-0003 Manifest](RFC-AITP-0003-manifest.md)** — signed agent self-description.
4. **[RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)** — the four-message agent-to-agent handshake.
5. **[RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)** — the canonical peer-issued Trust Context Token.
6. **[RFC-AITP-0006 Delegation](RFC-AITP-0006-delegation.md)** — single-hop delegation between peers.
7. **[RFC-AITP-0007 Key Resolution](RFC-AITP-0007-key-resolution.md)** — Manifest-first peer-key resolution and identity-issuer key resolution.
8. **[RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)** — JTI deny lists per issuing peer, key revocation.
9. **[RFC-AITP-0009 Security](RFC-AITP-0009-security.md)** — threat model and required defenses.

Opt-in (Draft normative text published, NOT part of v0.3 core conformance):

- **[RFC-AITP-0010 Session Trust Bundle](RFC-AITP-0010-session-trust-bundle.md)** — multi-agent session scaling.
- **[RFC-AITP-0011 Multi-hop Delegation](RFC-AITP-0011-multihop-delegation.md)** — chains beyond a single hop.
- **[RFC-AITP-0014 A2A Agent Card Security Scheme](RFC-AITP-0014-a2a-agent-card.md)** — advertising AITP in an A2A (Agent2Agent protocol) Agent Card, bound to the agent's Manifest.

Reserved (a real, detailed document exists, but its contents are non-normative for `aitp/0.3` — see `governance/RFC-PROCESS.md`'s lifecycle for the Reserved/Planned distinction):

- **[RFC-AITP-0012 Extensions](RFC-AITP-0012-extensions.md)** — ZK and TEE namespaces.

Planned (a materially thinner stub exists, reserving the number and giving other documents a stable link):

- **[RFC-AITP-0013 TCT Renewal Extension](RFC-AITP-0013-tct-renewal-extension.md)** —
  standardization of the shortened renewal endpoint described
  non-normatively in
  [RFC-AITP-0004 §8.1](RFC-AITP-0004-mutual-handshake.md#81-non-normative-shortened-renewal-extension).

## RFC lifecycle

`Reserved → Planned → Idea → Draft → Review → Release Candidate → Final Comment Period → Accepted` (or `Rejected`) — see [governance/RFC-PROCESS.md](../governance/RFC-PROCESS.md) for what a numbered RFC's `**Status:**` header reads at each stage; `scripts/check-doc-coherence.sh` asserts every one of the 14 RFC files (plus the repo `README.md`) draws from this ladder.

The `aitp/0.2` revision was a breaking change (compact-JWS trust artifacts, cryptographic agility), so RFCs 0001–0009 returned to **Draft** (shown simply as "Draft" above — the RFC's own `Version:` header, not its `Status:`, is what records which protocol revision a Draft belongs to) and re-progressed through the lifecycle; the v0.1 line completed Release Candidate at `0.1.0-rc.3`. The `aitp/0.3` revision (envelope signing input, issue #87) is breaking again, so every RFC stayed at its `Status:` when it landed. RFCs 0001–0009 entered **Review** on 2026-10-24, after the `aitp/0.3` wire froze ([`VERSIONING.md` § What is frozen](../VERSIONING.md#what-is-frozen-aitp03-line)); their public review runs until at least 2027-01-10 in the [review thread](https://github.com/agentidentitytrustprotocol/agentidentitytrustprotocol/discussions/117). A Review RFC keeps its `-draft` version suffix; the suffix changes to `-rc.N` at Release Candidate.

The `aitp/0.3` revision reset every document's `Version:` header to `0.3.0` (`0.3.0-draft`, or `-reserved` / `-planned` for the placeholders). RFC-AITP-0010 is still at `0.3.0-draft`, RFC-AITP-0014 entered at `0.3.0-draft`, RFC-AITP-0012 is at `0.3.0-reserved` and RFC-AITP-0013 is at `0.3.0-planned`. RFC-AITP-0009 then moved to `0.3.1-draft` (signature-string malleability documented), RFC-AITP-0001 to `0.3.3-draft` (the same, then its status memo names the ladder's `Accepted` stage, then its schema namespace moves to the project domain), RFC-AITP-0006 and RFC-AITP-0011 to `0.3.1-draft` (a discarded revocation snapshot falls back to `revocation_policy.mode`), and RFC-AITP-0008 to `0.3.2-draft` (the same fallback, then an informative note that no third-party revocation authority exists). Entering Review bumped each of RFCs 0001–0009 by a patch, and landing RFC-AITP-0014 bumped four of them again (RFC-AITP-0009 for the Agent Card threats §1.15–§1.17, the other three for wording only: "agent-to-agent" in place of "A2A"). Landing the `spiffe` identity type (RFC-AITP-0002 §6) bumped RFC-AITP-0002 and RFC-AITP-0003 again. RFC-AITP-0005 and RFC-AITP-0007 are at `0.3.1-draft`, RFC-AITP-0002, RFC-AITP-0004 and RFC-AITP-0006 are at `0.3.2-draft`, RFC-AITP-0003, RFC-AITP-0008 and RFC-AITP-0009 are at `0.3.3-draft`, and RFC-AITP-0001 is at `0.3.5-draft`. Within a revision, document versions may diverge again as each RFC takes its own editorial bumps; the minor position stays reserved for the protocol revision (see [`VERSIONING.md`](../VERSIONING.md)). The per-document history of the v0.2 line (where versions had diverged up to `0.2.14-draft`) is recorded in [`CHANGELOG.md`](../CHANGELOG.md) and in the frozen v0.2 line at commit `f9ee7ea` (tag `v0.2.1-draft`). Check the header of the document you are reading rather than assuming a shared version.

**Release Candidate** is the editorial stage after Review and before FCP: the RFC text is substantively complete, the version carries an `rc.N` suffix (e.g. `0.3.0-rc.1`; the v0.1 line reached `0.1.0-rc.3`), and further changes are limited to clarifications, KAT vectors, and conformance fixtures. RC can iterate (rc.1, rc.2, …) as implementer feedback surfaces issues. Promotion to FCP requires all required KAT vectors present, the conformance fixture set complete for the RFC's normative surfaces, and at least one implementation passing the core conformance tier. See [governance/RFC-PROCESS.md](../governance/RFC-PROCESS.md) for the full stage definitions.
