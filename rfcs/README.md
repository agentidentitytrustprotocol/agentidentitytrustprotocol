# AITP RFC Index

This directory contains the normative RFCs that define the Agent Identity & Trust Protocol (AITP). AITP is an **agent-to-agent (A2A)** trust protocol; the current revision is **`aitp/0.2`** (v0.1 was the first published version — v0.2 is a breaking revision that re-serializes the portable trust artifacts as compact JWS and adds cryptographic agility; see [RFC-AITP-0001 §1](RFC-AITP-0001-core.md#1-status-of-this-memo)).

Status values below are drawn from the single lifecycle ladder in
[`governance/RFC-PROCESS.md`](../governance/RFC-PROCESS.md) — see that
document for what each stage means; `(opt-in)` is not a lifecycle stage,
it flags that the RFC is outside v0.2 core conformance (see below).

| RFC | Title | Status |
|---|---|---|
| [RFC-AITP-0001](RFC-AITP-0001-core.md) | Core — envelope, signatures, replay, error codes | Draft |
| [RFC-AITP-0002](RFC-AITP-0002-identity.md) | Identity Binding | Draft |
| [RFC-AITP-0003](RFC-AITP-0003-manifest.md) | Agent Manifest | Draft |
| [RFC-AITP-0004](RFC-AITP-0004-mutual-handshake.md) | Mutual Handshake | Draft |
| [RFC-AITP-0005](RFC-AITP-0005-tct.md) | Trust Context Token | Draft |
| [RFC-AITP-0006](RFC-AITP-0006-delegation.md) | Single-Hop Delegation | Draft |
| [RFC-AITP-0007](RFC-AITP-0007-key-resolution.md) | Key Resolution | Draft |
| [RFC-AITP-0008](RFC-AITP-0008-revocation.md) | Revocation | Draft |
| [RFC-AITP-0009](RFC-AITP-0009-security.md) | Security & Threat Model | Draft |
| [RFC-AITP-0010](RFC-AITP-0010-session-trust-bundle.md) | Session Trust Bundle | Draft (opt-in) |
| [RFC-AITP-0011](RFC-AITP-0011-multihop-delegation.md) | Multi-hop Delegation | Draft (opt-in) |
| [RFC-AITP-0012](RFC-AITP-0012-extensions.md) | Extensions (ZK, TEE) — reserved | Reserved |
| [RFC-AITP-0013](RFC-AITP-0013-tct-renewal-extension.md) | TCT Renewal Extension | Planned |

## Reading order

The numbering matches dependency order. Read top-to-bottom:

1. **[RFC-AITP-0001 Core](RFC-AITP-0001-core.md)** — envelope, replay protection, signatures, error codes.
2. **[RFC-AITP-0002 Identity](RFC-AITP-0002-identity.md)** — identity binding model and trust anchors.
3. **[RFC-AITP-0003 Manifest](RFC-AITP-0003-manifest.md)** — signed agent self-description.
4. **[RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)** — the four-message A2A handshake.
5. **[RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)** — the canonical peer-issued Trust Context Token.
6. **[RFC-AITP-0006 Delegation](RFC-AITP-0006-delegation.md)** — single-hop delegation between peers.
7. **[RFC-AITP-0007 Key Resolution](RFC-AITP-0007-key-resolution.md)** — Manifest-first peer-key resolution and identity-issuer key resolution.
8. **[RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)** — JTI deny lists per issuing peer, key revocation.
9. **[RFC-AITP-0009 Security](RFC-AITP-0009-security.md)** — threat model and required defenses.

Opt-in (Draft normative text published, NOT part of v0.2 core conformance):

- **[RFC-AITP-0010 Session Trust Bundle](RFC-AITP-0010-session-trust-bundle.md)** — multi-agent session scaling.
- **[RFC-AITP-0011 Multi-hop Delegation](RFC-AITP-0011-multihop-delegation.md)** — chains beyond a single hop.

Reserved (a real, detailed document exists, but its contents are non-normative for `aitp/0.2` — see `governance/RFC-PROCESS.md`'s lifecycle for the Reserved/Planned distinction):

- **[RFC-AITP-0012 Extensions](RFC-AITP-0012-extensions.md)** — ZK and TEE namespaces.

Planned (a materially thinner stub exists, reserving the number and giving other documents a stable link):

- **[RFC-AITP-0013 TCT Renewal Extension](RFC-AITP-0013-tct-renewal-extension.md)** —
  standardization of the shortened renewal endpoint described
  non-normatively in
  [RFC-AITP-0004 §8.1](RFC-AITP-0004-mutual-handshake.md#81-non-normative-shortened-renewal-extension).

## RFC lifecycle

`Reserved → Planned → Idea → Draft → Review → Release Candidate → Final Comment Period → Accepted` (or `Rejected`) — see [governance/RFC-PROCESS.md](../governance/RFC-PROCESS.md) for what a numbered RFC's `**Status:**` header reads at each stage; `scripts/check-doc-coherence.sh` asserts every one of the 13 RFC files (plus the repo `README.md`) draws from this ladder.

The `aitp/0.2` revision is a breaking change (compact-JWS trust artifacts, cryptographic agility), so RFCs 0001–0009 returned to **Draft** (shown simply as "Draft" above — the RFC's own `Version:` header, not its `Status:`, is what records which protocol revision a Draft belongs to) and re-progress through the lifecycle; the v0.1 line completed Release Candidate at `0.1.0-rc.3`.

Document versions within a protocol revision **may diverge**: the `Version:` header tracks each RFC's own editorial history, not the protocol literal, which stays `aitp/0.2` for all of them, and not the minor position, which is reserved for the protocol revision itself (see [`VERSIONING.md`](../VERSIONING.md)). RFC-AITP-0008 is at `0.2.7-draft`; RFC-AITP-0001 is at `0.2.6-draft`; RFC-AITP-0003 and RFC-AITP-0010 are at `0.2.5-draft`; RFC-AITP-0002 and RFC-AITP-0004 are at `0.2.4-draft`; RFC-AITP-0005 is at `0.2.2-draft`, after the JCS signing-input, session-bundle placement, extensions field-table, RFC-AITP-0011 wrapper-citation, §3.1 pinned-key timestamp, `UNKNOWN_FIELD`, structural-rejection code, identity-descriptor mirror, and status-ladder corrections (see [`CHANGELOG.md`](../CHANGELOG.md)); and RFC-AITP-0006, RFC-AITP-0007, RFC-AITP-0009 and RFC-AITP-0011 are at `0.2.1-draft` (the status-ladder normalization, their only editorial history to date). RFC-AITP-0012 and RFC-AITP-0013 keep their own `-reserved` / `-planned` version suffixes, unmoved by this normalization since their `Status:` values did not change. Check the header of the document you are reading rather than assuming a shared version.

**Release Candidate** is the editorial stage after Review and before FCP: the RFC text is substantively complete, the version carries an `rc.N` suffix (e.g. `0.2.0-rc.1`; the v0.1 line reached `0.1.0-rc.3`), and further changes are limited to clarifications, KAT vectors, and conformance fixtures. RC can iterate (rc.1, rc.2, …) as implementer feedback surfaces issues. Promotion to FCP requires all required KAT vectors present, the conformance fixture set complete for the RFC's normative surfaces, and at least one implementation passing the core conformance tier. See [governance/RFC-PROCESS.md](../governance/RFC-PROCESS.md) for the full stage definitions.
