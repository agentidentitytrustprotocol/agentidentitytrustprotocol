# AITP RFC Index

This directory contains the normative RFCs that define the Agent Identity & Trust Protocol (AITP). AITP is an **agent-to-agent (A2A)** trust protocol; v0.1 is the first published version.

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
| [RFC-AITP-0010](RFC-AITP-0010-session-trust-bundle.md) | Session Trust Bundle | Draft (post-v0.1) |
| [RFC-AITP-0011](RFC-AITP-0011-multihop-delegation.md) | Multi-hop Delegation | Draft (post-v0.1) |
| [RFC-AITP-0012](RFC-AITP-0012-extensions.md) | Extensions (ZK, TEE) — reserved | Reserved |
| RFC-AITP-0013 | TCT Renewal Extension | Planned |

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

Post-v0.1 (Draft normative text published, NOT part of v0.1 conformance):

- **[RFC-AITP-0010 Session Trust Bundle](RFC-AITP-0010-session-trust-bundle.md)** — multi-agent session scaling.
- **[RFC-AITP-0011 Multi-hop Delegation](RFC-AITP-0011-multihop-delegation.md)** — chains beyond a single hop.

Reserved (no normative text, numbering pinned for future work):

- **[RFC-AITP-0012 Extensions](RFC-AITP-0012-extensions.md)** — ZK and TEE namespaces.

Planned (RFC number reserved, no document yet):

- **RFC-AITP-0013 TCT Renewal Extension** — standardization of the
  shortened renewal endpoint described non-normatively in
  [RFC-AITP-0004 §8.1](RFC-AITP-0004-mutual-handshake.md#81-non-normative-shortened-renewal-extension).

## RFC lifecycle

`Draft → Review → Final Comment Period → Accepted` (or `Rejected`). See [governance/RFC-PROCESS.md](../governance/RFC-PROCESS.md).
