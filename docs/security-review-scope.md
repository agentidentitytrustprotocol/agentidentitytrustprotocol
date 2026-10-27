# Security review scope

This page scopes an external security review of the `aitp/0.3` core (RFC-AITP-0001 to RFC-AITP-0009). It lists the surfaces to review, the issues already known, and the gaps in runtime fuzzing. Findings are reported through [SECURITY.md](../SECURITY.md).

Also in scope, at lower priority: the Manifest ([RFC-AITP-0003](../rfcs/RFC-AITP-0003-manifest.md)), single-hop delegation ([RFC-AITP-0006](../rfcs/RFC-AITP-0006-delegation.md)) and key resolution ([RFC-AITP-0007](../rfcs/RFC-AITP-0007-key-resolution.md)).

Out of scope: the opt-in drafts (RFC-AITP-0010 to RFC-AITP-0014, including the `spiffe` identity type and the A2A binding), deployment and hosting.

## Surfaces in scope

| Surface | Sections | Review question |
|---|---|---|
| Signing inputs | [RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#541-signing-input-jcs-profile), [§5.4.2](../rfcs/RFC-AITP-0001-core.md#542-pop-signing-input-convention), [§5.4.3](../rfcs/RFC-AITP-0001-core.md#543-algorithm-tagged-signature-wire-format-jcs-profile-only), [§5.4.5](../rfcs/RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts), [§5.4.7](../rfcs/RFC-AITP-0001-core.md#547-verification-strictness) | Is every signed byte string unambiguous, and can no signature be valid for two different meanings? |
| Key thumbprint | [RFC-AITP-0001 §5.4.4](../rfcs/RFC-AITP-0001-core.md#544-jwk-thumbprint-for-cnf), [RFC-AITP-0002 §2.2.1](../rfcs/RFC-AITP-0002-identity.md#221-canonical-jwk-form-for-cnfjkt) | Does one key map to exactly one thumbprint? |
| Identity binding | [RFC-AITP-0002 §2.3](../rfcs/RFC-AITP-0002-identity.md#23-verification-steps), [§3.2](../rfcs/RFC-AITP-0002-identity.md#32-verification-steps), [§3.4](../rfcs/RFC-AITP-0002-identity.md#34-one-way-pinned-key-admission-optional-profile-pinned-admission), [§4](../rfcs/RFC-AITP-0002-identity.md#4-trust-anchors) | Is an AID bound to its key and to a trust anchor in every identity type? |
| Mutual handshake | [RFC-AITP-0004 §3](../rfcs/RFC-AITP-0004-mutual-handshake.md#3-message-definitions), [§4.2](../rfcs/RFC-AITP-0004-mutual-handshake.md#42-audience-binding), [§4.4](../rfcs/RFC-AITP-0004-mutual-handshake.md#44-proof-of-possession-binding), [§5](../rfcs/RFC-AITP-0004-mutual-handshake.md#5-verification-steps) | Do the four messages give mutual authentication, round binding and freshness? |
| TCT and `cnf` | [RFC-AITP-0005 §3](../rfcs/RFC-AITP-0005-tct.md#3-confirmation-claim-cnf), [§5.2](../rfcs/RFC-AITP-0005-tct.md#52-audience-validation), [§6](../rfcs/RFC-AITP-0005-tct.md#6-binding-proof-of-possession), [§7.2](../rfcs/RFC-AITP-0005-tct.md#72-verification-order) | Is a TCT usable only by its holder, at its audience, within its grants? |
| Revocation policy | [RFC-AITP-0008 §1.5](../rfcs/RFC-AITP-0008-revocation.md#15-signed-revocation-response), [§3.1](../rfcs/RFC-AITP-0008-revocation.md#31-modes), [§3.2](../rfcs/RFC-AITP-0008-revocation.md#32-staleness), [§3.3](../rfcs/RFC-AITP-0008-revocation.md#33-revocation-lookup-ordering) | Does every policy mode fail safe when revocation data is missing, stale or from the wrong signer? |

The threat model the review checks against is [RFC-AITP-0009](../rfcs/RFC-AITP-0009-security.md).

**Formal model.** A Tamarin model of the handshake, TCT use and renewal, and single-hop delegation is in [`formal/`](../formal/README.md). [formal/REPORT.md](../formal/REPORT.md) states what it proves and its limits; per-lemma results are in [formal/results/summary.md](../formal/results/summary.md). A review can start from the modelling limits listed there.

## Known items

These are already tracked. A review need not rediscover them.

| Item | Where | Status |
|---|---|---|
| Handshake routes do not enforce the replay and timestamp checks of [RFC-AITP-0009 §1.2](../rfcs/RFC-AITP-0009-security.md#12-replay) | [aitp-playground `PENDING.md`](https://github.com/agentidentitytrustprotocol/aitp-playground/blob/main/PENDING.md), item P17 | Open |
| A capability route takes the expected TCT audience from the token instead of from its own AID ([RFC-AITP-0005 §5.2](../rfcs/RFC-AITP-0005-tct.md#52-audience-validation)) | [aitp-playground `agents/base/aitp_server.py`](https://github.com/agentidentitytrustprotocol/aitp-playground/blob/main/agents/base/aitp_server.py) | Open |
| Revocation entries signed by a party other than the token's issuer ([RFC-AITP-0008 §1.5](../rfcs/RFC-AITP-0008-revocation.md#15-signed-revocation-response)) | [aitp-control-plane#153](https://github.com/agentidentitytrustprotocol/aitp-control-plane/issues/153) | Resolved in the spec by fixture `rev-011` and the [2026-10-24 decision](../governance/DECISIONS.md) |

## Runtime fuzz gaps

aitp-rs has fourteen fuzz targets, run in CI: envelope, Manifest and delegation parsing, JCS canonicalization, JWS, TCT, delegation and revocation verification, handshake payload decoding (RFC-AITP-0004 §3), OIDC identity proofs (RFC-AITP-0002 §2.3), pinned-key admission (RFC-AITP-0002 §3.4), SPIFFE SVID verification, session bundles (RFC-AITP-0010, opt-in) and interop enrolment.

aitp-verifier-go fuzzes its JCS canonicalizer and strict JSON parser with Go native fuzzing. aitp-verifier-py and aitp-verifier-ts have no fuzz targets.
