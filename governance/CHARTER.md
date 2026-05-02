# AITP Governance Charter

This document describes the governance structure for the Agent Identity & Trust Protocol (AITP). It is intentionally minimal — AITP is a small standards effort, and the goal is to ship interoperable specifications, not to build a federation.

---

## Mission

AITP defines an open, peer-to-peer trust protocol for autonomous agents. The standard is published under Apache License 2.0 and is intended to remain implementable by any team without commercial restriction.

---

## Core Team

The Core Team is responsible for:

- Shepherding RFCs through the lifecycle defined in [RFC-PROCESS.md](RFC-PROCESS.md).
- Resolving ambiguity and inconsistency across published RFCs.
- Maintaining the registries (identity types, capabilities, error codes, media types).
- Approving the conformance test suite.
- Cutting versioned releases.

The Core Team operates by **rough consensus**. When consensus cannot be reached, the Core Team votes; ties default to the status quo.

Until a Core Team is seated, the repository maintainer (the AITP project lead) acts in its place for editorial and registry matters; substantive (normative) RFCs SHOULD wait for a seated Core Team or a public review period of at least 30 days. Once seated, the Core Team roster will be tracked in a separate file under `governance/` so membership changes do not require a charter amendment.

---

## Joining the Core Team

A contributor may be invited to the Core Team after demonstrating sustained, high-quality contributions across at least two of: shepherding an RFC, building an interoperating implementation, maintaining the conformance suite, or producing reference documentation. Invitations require Core Team consensus.

A Core Team member who has been inactive for more than 12 consecutive months is moved to emeritus status and loses voting rights until reactivated.

---

## Decision-Making

| Decision | Mechanism |
|---|---|
| Editorial fixes (typos, clarifications, non-normative text) | Single Core Team approval, merged directly. |
| New normative content (new RFCs, schema changes, error codes) | Full RFC process per `RFC-PROCESS.md`. |
| Changes to this charter | Two-thirds majority of active Core Team members. |
| Versioned release | Core Team consensus, formal sign-off in CHANGELOG. |

---

## Disclosure of Conflicts

Core Team members who have a material interest in an RFC (employer-sponsored, financial, or otherwise) MUST disclose it in the RFC PR. The rest of the Core Team decides whether the conflict requires recusal.

---

## Code of Conduct

All participation in AITP repositories, mailing lists, and meetings is governed by [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md). Violations are handled by the Core Team.

---

## Amendments

This charter may be amended by a two-thirds majority of active Core Team members. Amendments are tracked via PRs to this file and announced in the next release's CHANGELOG.
