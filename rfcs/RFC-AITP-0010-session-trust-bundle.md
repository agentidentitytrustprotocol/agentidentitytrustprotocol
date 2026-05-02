# RFC-AITP-0010
# Session Trust Bundle

**Document:** RFC-AITP-0010
**Version:** 0.1.0-reserved
**Status:** Reserved
**Depends on:** [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)

---

> **This RFC is reserved.** The numbering is pinned for the Session Trust Bundle so future work can be cited consistently. **No normative text is published yet.** Implementations MUST NOT depend on the contents of this document.

---

## Abstract (placeholder)

In a multi-agent session of N participants, requiring O(N²) bilateral Mutual Handshakes is unscalable. The Session Trust Bundle is a signed artifact that a coordinator constructs from N Mutual Handshakes (coordinator ↔ each participant) and distributes to all participants, so that every agent-to-agent pair within the session has a verifiable trust artifact without a full mesh of handshakes.

## Motivation (placeholder)

- Coordinator-mediated trust scales linearly in N.
- The bundle composes naturally with [Multi-Agent Coordination Protocol (MACP)](https://github.com/multiagentcoordinationprotocol/multiagentcoordinationprotocol) `SessionStart` participant lists.
- Bilateral Mutual Handshakes remain the source of truth; the bundle redistributes them.

## Open questions (placeholder)

- Bundle schema and signing semantics.
- Trust model for participants who do not directly handshake with each other.
- Revocation semantics within an active session.
- Bundle expiry vs participant TCT expiry.

## Security Considerations (placeholder)

A full threat analysis MUST be completed before this RFC leaves Reserved status. Known threats already in scope:

- **Coordinator compromise.** A malicious or compromised coordinator can fabricate participant lists, omit revocation entries, or reissue stale bundles. Bundle signing semantics MUST make coordinator authority explicit and bound.
- **Bundle replay.** A bundle distributed in one session MUST NOT be reusable in another. Mitigations under consideration: per-session nonce, expiry tied to the shortest participant TCT lifetime, and explicit session identifiers in the signing input.
- **Transitive trust inflation.** Participants who never directly handshake with each other inherit trust through the bundle. The trust model MUST document what guarantees this provides and what it does not (e.g. it does not prove peer-to-peer identity binding, only coordinator-attested membership).
- **Mid-session revocation.** Revocation semantics within an active session are listed as an open question above; the security analysis MUST converge on either (a) bundle invalidation on any participant revocation, or (b) per-pair degradation with documented behavior.

## References

- [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
