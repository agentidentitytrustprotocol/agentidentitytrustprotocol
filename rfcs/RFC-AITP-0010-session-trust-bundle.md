# RFC-AITP-0010
# Session Trust Bundle

**Document:** RFC-AITP-0010
**Version:** 0.1.0-draft.1
**Status:** Draft
**Depends on:** [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md), [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md), [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)

---

> **Status: Draft.** Normative text below resolves the four open questions tracked in earlier "Reserved" revisions of this RFC. The bundle wire format and conformance surface are still being implemented; consumers MUST treat the schema as Draft until this RFC is promoted to Release Candidate.

---

## Abstract

In a multi-agent session of N participants, requiring O(N²) bilateral Mutual Handshakes is unscalable. The **Session Trust Bundle** is a signed artifact a coordinator constructs from N Mutual Handshakes (coordinator ↔ each participant) and distributes to all participants, so that every agent-to-agent pair within the session has a verifiable trust artifact without a full mesh of handshakes.

The bundle does not replace bilateral handshakes — it redistributes them. Pairs that need direct peer-to-peer identity binding (rather than coordinator-attested membership) MUST run a separate bilateral Mutual Handshake.

---

## 1. Motivation

- Coordinator-mediated trust scales linearly in N rather than quadratically.
- The bundle composes naturally with [Multi-Agent Coordination Protocol (MACP)](https://github.com/multiagentcoordinationprotocol/multiagentcoordinationprotocol) `SessionStart` participant lists; each `SessionStart` participant gets one TCT from the coordinator and one bundle.
- Bilateral Mutual Handshakes (RFC-AITP-0004) remain the source of truth; the bundle is a packaging mechanism, not a new trust primitive.

---

## 2. Trust Model

A `SessionBundle` provides **coordinator-attested membership**, not peer-to-peer identity binding. If A and B both appear in the same bundle, they know:

a. The coordinator authenticated each of them directly via a Mutual Handshake (the coordinator holds a peer-issued TCT for each participant).
b. The coordinator signed both of those TCTs into the same bundle.

A and B do NOT hold a direct peer-issued TCT from each other. A peer that requires direct binding (e.g. for a high-value capability that demands evidence of mutual liveness) MUST run a bilateral Mutual Handshake in addition to the bundle distribution. Coordinator-attested membership is sufficient for capability-routing and presence within a session; it is not sufficient for a binding A↔B grant exchange.

**Coordinator authority.** The coordinator's signing key is the bundle's root of trust. A compromised coordinator can fabricate participant lists or omit revocations. Bundle consumers MUST treat the coordinator's AID with the same scrutiny they apply to any peer — its Manifest is verified per [RFC-AITP-0003 §5](RFC-AITP-0003-manifest.md#5-manifest-verification), and its signature on the bundle is verified before any participant TCT is consumed.

---

## 3. Schema

```json
{
  "session_bundle": {
    "version": "aitp/0.1",
    "session_id": "<uuid-v4>",
    "coordinator": "aid:pubkey:<coordinator-base64url>",
    "issued_at": 1711900000,
    "expires_at": 1711903600,
    "participants": [
      {
        "aid": "aid:pubkey:<participant-base64url>",
        "tct": { "...": "embedded peer-issued TCT — coordinator → participant" }
      }
    ],
    "signature": "<base64url sig over canonical session_bundle JSON excluding signature>"
  }
}
```

| Field | Required | Description |
|---|---|---|
| `version` | REQUIRED | MUST be `"aitp/0.1"` for this RFC. |
| `session_id` | REQUIRED | UUID v4 unique to this session. Used as a replay-binding scope. |
| `coordinator` | REQUIRED | The coordinator's AID. MUST match the `issuer` of every embedded `tct`. |
| `issued_at` | REQUIRED | Unix timestamp when this bundle was signed. |
| `expires_at` | REQUIRED | Unix timestamp after which the bundle MUST NOT be used. MUST equal `min(participants[*].tct.expires_at)` (see §6). |
| `participants` | REQUIRED | Array of participant entries. Each entry pairs a participant AID with the peer-issued TCT the coordinator issued to that participant during the bilateral handshake that fed into this bundle. |
| `signature` | REQUIRED | Coordinator's signature over the canonical `session_bundle` JSON (excluding `signature`). Same JCS rules as RFC-AITP-0001 §5.4.1. |

The participant `tct` field is a verbatim peer-issued TCT (RFC-AITP-0005 §1) — coordinator-issued, with `audience` set to the participant's AID. The bundle distributes the participant's *own* TCT back to that participant alongside everyone else's, so a single fetch reveals the full session roster.

---

## 4. Bundle Issuance

### 4.1 Pre-conditions

The coordinator MUST have completed a Mutual Handshake (RFC-AITP-0004) with every participant before assembling a bundle. The bundle is a function of those handshakes; it does NOT itself perform identity binding.

### 4.2 Construction

1. For each participant `P_i`, take the peer-issued TCT the coordinator issued during the handshake (`coordinator → P_i`).
2. Compute `expires_at = min(TCT_i.expires_at)` across all participants.
3. Assemble the `session_bundle` body with `version`, fresh `session_id`, `coordinator`, `issued_at`, this `expires_at`, and the `participants` array.
4. Sign the canonical JCS bytes of the body (excluding `signature`) with the coordinator's private key.

### 4.3 Distribution

The coordinator MAY distribute the bundle by any transport that preserves the canonical JSON (HTTPS POST, signed message bus, etc.). Each participant SHOULD verify the bundle on receipt.

---

## 5. Verification

A participant receiving a bundle MUST, in order:

1. **Version check** — `session_bundle.version` MUST be `"aitp/0.1"` or a later supported version.
2. **Expiry check** — `session_bundle.expires_at` MUST be in the future.
3. **Coordinator key resolution** — fetch and verify the coordinator's Manifest per RFC-AITP-0003 §5; resolve the coordinator's public key from `manifest.aid`.
4. **Bundle signature** — verify `session_bundle.signature` against the coordinator's key over the canonical body.
5. **Per-participant TCT verification** — for each `participants[i].tct`, run the standard TCT verification (RFC-AITP-0005 §9). Every embedded TCT MUST have `issuer == session_bundle.coordinator`. The participant SHOULD verify its own TCT first.
6. **Self-membership check** — the receiving participant MUST find its own AID in `participants[*].aid` and confirm the embedded TCT's `audience` equals its own AID. A bundle that does not contain the receiver is rejected.

A failure at any step MUST result in `SESSION_BUNDLE_INVALID`. Implementations MUST NOT consume a bundle whose signature does not validate, regardless of whether individual TCTs are otherwise well-formed.

---

## 6. Expiry

`session_bundle.expires_at` MUST equal `min(participants[*].tct.expires_at)`. This ensures the bundle is never valid past the lifetime of its shortest-lived participant TCT. A bundle whose `expires_at` exceeds any embedded TCT's `expires_at` is non-conformant and MUST be rejected at issuance and at verification time.

When the bundle expires, the coordinator SHOULD re-run the bilateral handshakes for any expiring participants, mint fresh TCTs, and publish a new bundle with a fresh `session_id`. Bundle reuse across sessions is forbidden — a bundle from session X MUST NOT be presented in session Y.

---

## 7. Revocation

Bundle revocation is **per-pair degradation**, not whole-bundle invalidation:

- Revoking a single participant's TCT (via the coordinator's deny list, RFC-AITP-0008 §1) removes that participant from the active session.
- The remaining participants' TCTs in the same bundle are unaffected and remain valid until their own `expires_at`.
- Consuming peers MUST re-check each embedded TCT against the coordinator's `ListRevoked` feed at the cadence configured by `revocation_policy.max_staleness_secs` (RFC-AITP-0008 §3.2).

A coordinator that wishes to terminate a session entirely MUST add every embedded TCT JTI to its deny list. There is no "revoke the bundle" surface; the bundle is a redistribution of TCTs, and the TCT JTI deny list is the only revocation primitive.

---

## 8. Error Codes

| Code | Meaning | Retryable |
|---|---|---|
| `SESSION_BUNDLE_INVALID` | Bundle signature, expiry, or per-participant TCT verification failed | false |
| `SESSION_BUNDLE_NOT_MEMBER` | Receiver's AID is not in `participants[*].aid` | false |
| `SESSION_BUNDLE_EXPIRED` | `expires_at` is in the past | false |

---

## 9. Conformance Surface

| Adapter operation | Description |
|---|---|
| `issue_session_bundle` | Coordinator op: take N coordinator-issued TCTs and produce a signed bundle. |
| `verify_session_bundle` | Participant op: run §5 verification on a received bundle. |

A conformant v0.1 implementation that opts into RFC-AITP-0010 MUST expose both operations in its conformance harness. Implementations that do not expose them MUST report SKIP for any `bundle-*` fixture rather than FAIL.

KAT vectors live in [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json) (`kat-session-bundle-001`, to be added) and pin (coordinator key + N participant TCTs → canonical bundle body → signature). The vector follows the same convention as `kat-tct-001`.

> **Draft-stage deferral.** This RFC is Draft. The KAT vector is deferred to RC promotion per the Draft-stage carve-out in [`governance/RFC-PROCESS.md`](../governance/RFC-PROCESS.md). It is a blocker for moving this RFC out of Review.

---

## 10. Security Considerations

- **Coordinator compromise.** A malicious or compromised coordinator can fabricate participant lists, omit revocation entries, or reissue stale bundles. Bundle consumers MUST treat the coordinator's AID with normal peer-trust scrutiny — there is no implicit privilege.
- **Bundle replay.** A bundle issued in session X MUST NOT be reusable in session Y. The `session_id` field and the `min(tct.expires_at)` expiry are the primary defenses; consumers MUST reject bundles whose `session_id` they have already accepted with a different signature.
- **Transitive trust inflation.** Participants that never directly handshake with each other inherit only coordinator-attested membership, not peer-to-peer binding. The trust model (§2) makes this limit explicit; it does not provide proof of peer-to-peer identity binding.
- **Mid-session revocation.** Resolved per §7 (per-pair degradation). The coordinator's deny list is the single source of truth.
- **Selective omission.** A coordinator that withholds bundle distribution from a participant cannot be detected by the protocol alone. Out-of-band session announcements (e.g. via the upper-layer coordination protocol) are required to detect omission.

---

## 11. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)
- [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
