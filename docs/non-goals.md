# AITP Non-Goals and Design Boundaries

This document is non-normative. It explains what AITP intentionally does not address. Each non-goal has a rationale; together they keep the spec narrow and shippable.

## 1. Service-consumer trust model

**Non-goal.** AITP v0.1 does not define a service-consumer flow (`Agent → Verifier → TCT → Service`).

**Rationale.** Embedding a third-party verifier role would create a privileged middle position and force every consumer to know about it. AITP keeps the trust model symmetric: every participant is a peer, and every TCT is peer-issued. Service-consumer flows can be built on top of AITP by reframing the service as a peer with its own Manifest.

**What AITP does instead.** Defines the Mutual Handshake as the only path to a TCT. Either side can be the "consuming side" depending on direction.

## 2. Global reputation standardization

**Non-goal.** AITP does not define a universal reputation system or score.

**Rationale.** Reputation is highly domain-specific. A reputation model for financial agents differs fundamentally from one for coding agents or research agents. Reputation systems also evolve faster than protocol layers; standardizing them would create maintenance burden and bias the protocol toward current assumptions.

**What AITP does instead.** Reputation is a grant-level decision in each issuing peer's policy. A pluggable trust-vector interface MAY be added in a future version.

## 3. Sybil resistance

**Non-goal.** AITP does not define a Sybil-resistance mechanism.

**Rationale.** Sybil resistance depends on identity-issuance economics — rate limits, proof-of-work, stake, KYC, hardware binding. These belong in identity providers, not in a trust evaluation protocol.

**What AITP does instead.** Defines the requirements identity providers MUST meet to be usable in AITP: stable subject IDs, rate-limited issuance, auditable public keys. Each peer selects providers that meet its Sybil tolerance.

## 4. Identity issuance

**Non-goal.** AITP does not issue agent identities.

**Rationale.** AITP is a trust evaluation/expression protocol. Creating a new identity system would compete with OIDC, DID, and enterprise IAM — systems with far more deployment infrastructure. The goal is interoperability, not replacement.

**What AITP does instead.** Accepts identity from any conformant identity provider via the pluggable `identity_type` interface (RFC-AITP-0002).

## 5. Real-time key-revocation propagation

**Non-goal.** AITP v0.1 does not guarantee real-time propagation of key-revocation events.

**Rationale.** Real-time revocation requires a distributed coordination mechanism (OCSP stapling, gossip, push) that adds significant complexity and network dependencies. For v0.1, latency is bounded by `max_staleness_secs`.

**What AITP does instead.** Three revocation modes (`fail_closed`, `fail_open`, `soft_fail`) and per-issuing-peer JTI deny lists for individual tokens.

## 6. Multi-hop delegation (v0.1)

**Non-goal.** AITP v0.1 does not support delegation chains longer than one hop.

**Rationale.** Multi-hop requires chain verification, hop limits, trust-penalty formulas, and defenses against chain insertion. These add significant complexity. Most real agent interactions are single-hop. Shipping v0.1 without multi-hop reduces adoption friction while preserving the extension path.

**What AITP does instead.** Specifies single-hop with full security properties (audience binding, PoP, stateless grant verification). Multi-hop is reserved in [RFC-AITP-0011](../rfcs/RFC-AITP-0011-multihop-delegation.md).

## 7. Multi-agent session scaling (v0.1)

**Non-goal.** AITP v0.1 does not define an O(N) trust mechanism for sessions of N agents.

**Rationale.** Bilateral handshakes are O(N²) in a full mesh. A coordinator-distributed Session Trust Bundle would solve this but introduces its own design questions (revocation in flight, membership changes mid-session, etc.).

**What AITP does instead.** Defines bilateral Mutual Handshakes as the building block. The Session Trust Bundle is reserved in [RFC-AITP-0010](../rfcs/RFC-AITP-0010-session-trust-bundle.md).

## 8. ZK proof verification (v0.1 core)

**Non-goal.** ZK proof generation and verification is not part of the v0.1 core.

**Rationale.** ZK tooling (circuit compilers, proof systems, verifiers) is still maturing. Requiring ZK in v0.1 would prevent adoption by teams that don't need it.

**What AITP does instead.** Reserves the `extensions.zk` field. See [RFC-AITP-0012](../rfcs/RFC-AITP-0012-extensions.md).

## 9. TEE attestation (v0.1 core)

**Non-goal.** TEE attestation is not part of the v0.1 core.

**Rationale.** TEE attestation requires platform-specific tooling (SGX, SEV, TrustZone) and introduces hardware dependencies. It is valuable for attesting that an agent runs specific code, but that is a higher-order requirement than basic identity and capability verification.

**What AITP does instead.** Reserves the `extensions.tee` field. See [RFC-AITP-0012](../rfcs/RFC-AITP-0012-extensions.md).

## 10. Cross-domain trust federation

**Non-goal.** AITP v0.1 does not define how peers in different trust domains recognize each other when their `accepted_trust_anchors` lists do not overlap.

**Rationale.** Cross-domain federation requires policy negotiation, issuer discovery, and trust-graph resolution — ecosystem-wide problems, not protocol-level. SAML and OIDC federation took years to standardize after their base protocols.

**What AITP does instead.** The `audience`, `issuer`, and `accepted_trust_anchors` fields are the building blocks for future federation. Federation semantics are deferred.

## 11. Authorization semantics

**Non-goal.** AITP does not define what `grants` mean in any specific peer.

**Rationale.** AITP is the trust contraction. Authorization semantics are domain-specific and live in the consuming peer.

**What AITP does instead.** Defines `grants` as opaque, additive, flat strings. Peers are responsible for grant interpretation.

## 12. Data references and operational context

**Non-goal.** AITP does not define how agents reference external data sources, attest to data provenance, or carry operational metadata in trust tokens.

**Rationale.** AITP is a trust kernel — it answers "who is this agent and what is it allowed to do here?" Embedding `postgres://` URIs, content hashes, or data-type tags inside TCTs would couple the trust layer to domain-specific concerns and destroy TCT portability across agent domains.

**What to use instead.** Data references belong in the coordination layer (e.g. MACP task messages). Cryptographic attestations over data — proving an agent operated on specific data without revealing it — belong in the ZK/TEE extension layer (RFC-AITP-0012).
