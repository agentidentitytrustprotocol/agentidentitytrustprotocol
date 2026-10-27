# Security policy

This policy covers the AITP specification: the RFCs, JSON Schemas, registries, conformance fixtures and known-answer vectors in this repository. It overrides the organization default.

## Scope

| You found | Report it to |
|---|---|
| A **spec defect**: a rule in an RFC, schema, registry or fixture that, implemented as written, lets a conformant peer accept what it should reject (or the reverse) | This repository |
| An **implementation bug**: a library or service departs from the spec | That implementation's repository. aitp-rs, aitp-verifier-py, aitp-verifier-ts, aitp-verifier-go, aitp-control-plane, aitp-playground and aitp-ui-console each accept private reports the same way. |

If you are not sure which it is, report it here. We move it if needed.

## Reporting

Use GitHub private vulnerability reporting: **[Report a vulnerability](https://github.com/agentidentitytrustprotocol/agentidentitytrustprotocol/security/advisories/new)**. It is the only intake channel. Do not open a public issue, pull request or discussion.

Include the RFC section or file affected, the conformance outcome you expect and the one you get. A proposed fixture is welcome.

## What happens next

- **Acknowledgement** within 3 business days.
- **Assessment.** We confirm or decline the report and agree a timeline with you.
- **Embargo.** Details stay in the private advisory until a fix is published, or 90 days after acknowledgement, whichever comes first. We can agree to extend it when implementations need more time. Implementations affected by the defect are told privately, before publication.
- **CVE.** We request a CVE through the GitHub advisory when the defect affects deployed implementations.
- **Credit** in the advisory and the CHANGELOG, unless you ask not to be named.

## Security fixes that change the wire

A security fix may change wire behaviour (a signing input, a verification rule, an error outcome). Such a fix ships as a new `aitp/0.3.x` release tag with a published advisory and a **strict cutover**: no dual-accept window, as for any revision change ([VERSIONING.md](VERSIONING.md#migrating-from-aitp02-to-aitp03)). A dual-accept window is reconsidered only once there are real deployments to protect. Fixes that do not change the wire ship as normal clarifications or fixtures.

## Supported revisions

Only the current revision, `aitp/0.3`, receives security fixes. The `aitp/0.2` line is frozen and is not fixed.

## External review

The surfaces in scope for an external security review are listed in [docs/security-review-scope.md](docs/security-review-scope.md).
