# AITP Non-Goals and Design Boundaries

This document is non-normative. It explains what AITP intentionally does not address. Each non-goal has a rationale; together they keep the spec narrow and shippable. The normative summary is the table in [RFC-AITP-0009 §5](../rfcs/RFC-AITP-0009-security.md#5-non-goals); RFC status (Draft, Draft opt-in, Reserved, Planned) is listed in [`rfcs/README.md`](../rfcs/README.md).

## 1. Service-consumer trust model

**Non-goal.** AITP does not define a service-consumer flow (`Agent → Verifier → TCT → Service`).

**Rationale.** Embedding a third-party verifier role would create a privileged middle position and force every consumer to know about it. AITP keeps the trust model symmetric: every participant is a peer, and every TCT is peer-issued. Service-consumer flows can be built on top of AITP by reframing the service as a peer with its own Manifest.

**What AITP does instead.** Defines the Mutual Handshake as the only path to a TCT. Either side can be the "consuming side" depending on direction.

## 2. Global reputation standardization

**Non-goal.** AITP does not define a universal reputation system or score.

**Rationale.** Reputation is highly domain-specific. A reputation model for financial agents differs fundamentally from one for coding agents or research agents. Reputation systems also evolve faster than protocol layers; standardizing them would create maintenance burden and bias the protocol toward current assumptions.

**What AITP does instead.** Reputation is a grant-level decision in each issuing peer's policy. Reputation is reserved as a possible future extension ([RFC-AITP-0009 §5](../rfcs/RFC-AITP-0009-security.md#5-non-goals)); no interface for it is specified.

## 3. Sybil resistance

**Non-goal.** AITP does not define a Sybil-resistance mechanism.

**Rationale.** Sybil resistance depends on identity-issuance economics — rate limits, proof-of-work, stake, KYC, hardware binding. These belong in identity providers, not in a trust evaluation protocol.

**What AITP does instead.** Nothing at the protocol layer: Sybil resistance is delegated to identity providers ([RFC-AITP-0009 §2](../rfcs/RFC-AITP-0009-security.md#2-known-limitations-v02)). Each peer chooses which identity issuers it accepts (its `trust_anchors`, published as the Manifest's `accepted_trust_anchors`) according to its own Sybil tolerance.

## 4. Identity issuance

**Non-goal.** AITP does not issue agent identities.

**Rationale.** AITP is a trust evaluation/expression protocol. Creating a new identity system would compete with OIDC, DID, and enterprise IAM — systems with far more deployment infrastructure. The goal is interoperability, not replacement.

**What AITP does instead.** Binds agents to identities issued elsewhere through the identity descriptor's `type` — `oidc` or `pinned_key` in v0.2, registered in [`registries/identity-types.md`](../registries/identity-types.md) ([RFC-AITP-0002](../rfcs/RFC-AITP-0002-identity.md)).

## 5. Real-time key-revocation propagation

**Non-goal.** AITP v0.2 does not guarantee real-time propagation of key-revocation events.

**Rationale.** Real-time revocation requires a distributed coordination mechanism (OCSP stapling, gossip, push) that adds significant complexity and network dependencies. In v0.2, revocation is pull-based and staleness is bounded by `max_staleness_secs` ([RFC-AITP-0008 §3.2](../rfcs/RFC-AITP-0008-revocation.md#32-staleness)).

**What AITP does instead.** Per-issuing-peer JTI deny lists for individual tokens, and three revocation-policy modes (`fail_closed`, the default; `soft_fail`; `fail_open`) for when no fresh snapshot is available ([RFC-AITP-0008 §3.1](../rfcs/RFC-AITP-0008-revocation.md#31-modes)). None of the fail modes is a way around cryptography: in key resolution, `fail_open` never bypasses the signature check ([RFC-AITP-0007 §3.3](../rfcs/RFC-AITP-0007-key-resolution.md#33-fail_open-and-identity-verification)), and network revocation lookups run only after signatures verify ([RFC-AITP-0008 §3.3](../rfcs/RFC-AITP-0008-revocation.md#33-revocation-lookup-ordering)).

## 6. Multi-hop delegation (core)

**Non-goal.** AITP v0.2 core conformance does not include delegation chains longer than one hop.

**Rationale.** Multi-hop requires chain verification, hop limits, and defenses against chain insertion. These add significant complexity. Most real agent interactions are single-hop. Keeping multi-hop out of core reduces adoption friction while preserving the extension path.

**What AITP does instead.** Core specifies single-hop delegation ([RFC-AITP-0006](../rfcs/RFC-AITP-0006-delegation.md)) with full security properties (audience binding, PoP, stateless grant verification against the embedded grant voucher). Multi-hop is specified in [RFC-AITP-0011](../rfcs/RFC-AITP-0011-multihop-delegation.md) (Draft, opt-in) and is not part of v0.2 core conformance; a core-only verifier rejects a delegation token carrying a `chain` claim ([RFC-AITP-0006 §4](../rfcs/RFC-AITP-0006-delegation.md#4-verification-rules)).

## 7. Multi-agent session scaling (core)

**Non-goal.** AITP v0.2 core does not define an O(N) trust mechanism for sessions of N agents.

**Rationale.** Bilateral handshakes are O(N²) in a full mesh. A coordinator-distributed Session Trust Bundle would solve this but introduces its own design questions (revocation in flight, membership changes mid-session, etc.).

**What AITP does instead.** Core defines bilateral Mutual Handshakes as the building block ([RFC-AITP-0004 §9](../rfcs/RFC-AITP-0004-mutual-handshake.md#9-integration-with-multi-agent-sessions)). The Session Trust Bundle is specified in [RFC-AITP-0010](../rfcs/RFC-AITP-0010-session-trust-bundle.md) (Draft, opt-in) and is not part of v0.2 core conformance.

## 8. ZK proof verification (core)

**Non-goal.** ZK proof generation and verification is not part of the v0.2 core.

**Rationale.** ZK tooling (circuit compilers, proof systems, verifiers) is still maturing. Requiring ZK in core would prevent adoption by teams that don't need it.

**What AITP does instead.** Reserves the `extensions.zk` namespace; its contents are non-normative in v0.2 and a peer MUST NOT make a trust decision based on them. See [RFC-AITP-0012](../rfcs/RFC-AITP-0012-extensions.md) (Reserved).

## 9. TEE attestation (core)

**Non-goal.** TEE attestation is not part of the v0.2 core.

**Rationale.** TEE attestation requires platform-specific tooling (SGX, SEV, TrustZone) and introduces hardware dependencies. It is valuable for attesting that an agent runs specific code, but that is a higher-order requirement than basic identity and capability verification.

**What AITP does instead.** Reserves the `extensions.tee` namespace, under the same non-normative, no-trust-decision rule. See [RFC-AITP-0012](../rfcs/RFC-AITP-0012-extensions.md) (Reserved).

## 10. Cross-domain trust federation

**Non-goal.** AITP v0.2 does not define how peers in different trust domains recognize each other when their `accepted_trust_anchors` lists do not overlap.

**Rationale.** Cross-domain federation requires policy negotiation, issuer discovery, and trust-graph resolution — ecosystem-wide problems, not protocol-level. SAML and OIDC federation took years to standardize after their base protocols.

**What AITP does instead.** The `aud` and `iss` claims and the Manifest's `accepted_trust_anchors` field are the building blocks for future federation. Federation semantics are deferred.

## 11. Authorization semantics

**Non-goal.** AITP does not define what `grants` mean in any specific peer.

**Rationale.** AITP is the trust contraction. Authorization semantics are domain-specific and live in the consuming peer.

**What AITP does instead.** Defines `grants` as opaque, additive, flat strings. Peers are responsible for grant interpretation.

## 12. Data references and operational context

**Non-goal.** AITP does not define how agents reference external data sources, attest to data provenance, or carry operational metadata in trust tokens.

**Rationale.** AITP is a trust kernel — it answers "who is this agent and what is it allowed to do here?" Embedding `postgres://` URIs, content hashes, or data-type tags inside TCTs would couple the trust layer to domain-specific concerns and destroy TCT portability across agent domains.

**What to use instead.** Data references belong in the coordination layer (e.g. MACP task messages). Cryptographic attestations over data — proving an agent operated on specific data without revealing it — belong in the ZK/TEE extension layer (RFC-AITP-0012).

## 13. DPoP and OAuth 2.0 Token Exchange

**Non-goal.** AITP v0.2 does not specify DPoP ([RFC 9449](https://datatracker.ietf.org/doc/html/rfc9449)) or OAuth 2.0 Token Exchange ([RFC 8693](https://datatracker.ietf.org/doc/html/rfc8693)). No RFC, conformance fixture, or threat-model entry covers either.

**Rationale.** Both sit in the authentication path, so specifying them means normative text, fixtures and a threat-model entry for their interaction with AITP — a maintenance surface with no current consumer. A "descriptive" RFC documenting one implementation's behaviour was explicitly rejected. The decision, its reasoning and its reversal trigger (a real consumer) are recorded in [`governance/DECISIONS.md`](../governance/DECISIONS.md#2026-09-19--do-not-spec-aitp-rss-dpop--oauth-token-exchange-surface-yet-issue-49).

**What AITP does instead.** TCTs are bound to the subject key by the static `cnf.jkt` claim ([RFC-AITP-0005 §3](../rfcs/RFC-AITP-0005-tct.md#3-confirmation-claim-cnf)), with possession proven by the downstream PoP exchange ([RFC-AITP-0005 §6.1](../rfcs/RFC-AITP-0005-tct.md#61-downstream-pop-exchange)). An implementation may ship DPoP or token-exchange support of its own (aitp-rs ships both), but that surface is unspecified by AITP and not part of conformance.
