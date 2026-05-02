# RFC-AITP-0011
# Multi-hop Delegation

**Document:** RFC-AITP-0011
**Version:** 0.1.0-reserved
**Status:** Reserved
**Depends on:** [RFC-AITP-0006 Single-Hop Delegation](RFC-AITP-0006-delegation.md)

---

> **This RFC is reserved.** The numbering is pinned for Multi-hop Delegation so future work can be cited consistently. **No normative text is published yet.** Implementations MUST NOT depend on the contents of this document.

---

## Abstract (placeholder)

[RFC-AITP-0006](RFC-AITP-0006-delegation.md) defines single-hop delegation: A peer-issues to B, B delegates a subset to C, A verifies and peer-issues to C. Multi-hop extends the same model to chains longer than one hop (A → B → C → D → …).

## Motivation (placeholder)

- Real agent ecosystems form chains: orchestrator → planner → executor → tool agent.
- Single-hop forces every consumer to be the original issuer, which collapses many useful patterns into bilateral handshakes.
- Chain verification must remain stateless and stop scope inflation at every hop.

## Design directions (placeholder)

- Self-contained `grant_proof` chain inside the delegation token.
- Per-hop signature verification and bounded hop limit (proposed default: max 3).
- Trust-decay or TTL-decay formulas as hops accumulate.
- Defense against chain-insertion and chain-truncation attacks.
- Stateless verification: any peer in the chain can verify the full chain without contacting other peers.

## Open questions (placeholder)

- Chain encoding format.
- Hop-limit policy (configurable, fixed, per-namespace?).
- Failure modes for partial chain verification.
- Interaction with revocation (what if an intermediate peer is revoked mid-chain?).

## Security Considerations (placeholder)

A full threat analysis MUST be completed before this RFC leaves Reserved status. Known threats already in scope:

- **Chain insertion.** An intermediate peer SHOULD NOT be able to inject a fabricated hop into a valid chain. Each hop MUST be authenticated by the previous delegator's key and bound to the originating TCT's `jti`.
- **Chain truncation.** Removing a hop in the middle of a chain MUST NOT produce a chain that verifies. The chain encoding MUST commit to the full sequence, not to individual links.
- **Scope inflation across hops.** Every hop's `scope` MUST be a strict subset of the prior hop's `scope`. Multi-hop verification MUST enforce this transitively, not just adjacent-hop-locally.
- **Hop limits and DoS.** Without a bounded hop count, a malicious chain could force unbounded verification work. v0.2 SHOULD specify a default upper bound (proposed: 3) and require receivers to reject chains exceeding it.
- **Mid-chain revocation.** If an intermediate peer is revoked, downstream hops issued before the revocation MUST be treated as revoked. The encoding MUST make every intermediate `jti` available so the receiver can check each one against the appropriate issuer's deny list.

## References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)
- [RFC-AITP-0006 Single-Hop Delegation](RFC-AITP-0006-delegation.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
