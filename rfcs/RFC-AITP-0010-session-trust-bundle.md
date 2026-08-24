# RFC-AITP-0010
# Session Trust Bundle

**Document:** RFC-AITP-0010
**Version:** 0.2.0-draft
**Status:** Draft
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md), [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md), [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md), [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)

---

> **Status: Draft.** Normative text below resolves the four open questions tracked in earlier "Reserved" revisions of this RFC. The bundle wire format and conformance surface are still being implemented; consumers MUST treat the schema as Draft until this RFC is promoted to Release Candidate.

> **Conformance scope.** RFC-AITP-0010 is **not part of AITP core
> conformance** (v0.1 or v0.2). Implementations MUST NOT fail core
> conformance tests because they do not implement Session Trust Bundles.
> Conformance runners MUST treat the `bundle-*` fixture set in
> [`schemas/conformance/`](../schemas/conformance/) as SKIP unless the
> runner is explicitly opted into testing RFC-AITP-0010 draft conformance
> (the metadata block on every bundle fixture carries
> `status: "draft"` and `feature: "experimental-session-bundle"`; see
> [`schemas/conformance/README.md`](../schemas/conformance/README.md)).
>
> The normative requirements in this document (MUST, SHALL, etc.) apply
> only to implementations that explicitly opt into RFC-AITP-0010 draft
> conformance. A core-only implementation that ignores Session Trust
> Bundles entirely is conformant.

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

The bundle itself is a **JCS-signed JSON object** — a protocol-internal artifact under the embedded-signature profile of [RFC-AITP-0001 §5.4.1](RFC-AITP-0001-core.md#541-signing-input-jcs-profile). The TCTs it carries are **portable trust artifacts**: each participant `tct` is an opaque compact JWS string (RFC-AITP-0005 §1, RFC-AITP-0001 §5.4.5), embedded verbatim and covered as-is by the coordinator's outer JCS signature.

```json
{
  "session_bundle": {
    "version": "aitp/0.2",
    "session_id": "<uuid-v4>",
    "coordinator": "aid:pubkey:ed25519:<coordinator-base64url>",
    "issued_at": 1711900000,
    "expires_at": 1711903600,
    "participants": [
      {
        "aid": "aid:pubkey:ed25519:<participant-base64url>",
        "tct": "<compact JWS string — peer-issued TCT, coordinator → participant>"
      }
    ],
    "signature": "<base64url sig over the canonical INNER session_bundle body, excluding signature and excluding this wrapper>"
  }
}
```

| Field | Required | Description |
|---|---|---|
| `version` | REQUIRED | MUST be `"aitp/0.2"` for this RFC. |
| `session_id` | REQUIRED | UUID v4 unique to this session. Used as a replay-binding scope. |
| `coordinator` | REQUIRED | The coordinator's AID. MUST match the `iss` claim of every embedded `tct`. |
| `issued_at` | REQUIRED | Unix timestamp when this bundle was signed. |
| `expires_at` | REQUIRED | Unix timestamp after which the bundle MUST NOT be used. MUST equal the minimum `exp` claim across the embedded participant TCTs (see §6). |
| `participants` | REQUIRED | Array of participant entries. Each entry pairs a participant AID with the peer-issued TCT (compact JWS string) the coordinator issued to that participant during the bilateral handshake that fed into this bundle. |
| `signature` | REQUIRED | Coordinator's signature over the canonical **inner** `session_bundle` body, excluding the `signature` member itself. The `{"session_bundle": {…}}` form shown throughout this RFC is the **HTTP/transport envelope only**; the signed object is the inner `session_bundle` value, never the wrapper. Consumers MUST unwrap to the inner object before computing the signing input. Same JCS rules as RFC-AITP-0001 §5.4.1, whose wrapper-stripping requirement this restates for the bundle. |

The participant `tct` field is a verbatim peer-issued TCT compact JWS (RFC-AITP-0005 §1) — coordinator-issued, with the `aud` claim set to the participant's AID. Per RFC-AITP-0001 §5.4.5, the bundle never parses, transforms, or re-encodes the embedded string; consumers that need a TCT's claims base64url-decode its payload segment but MUST NOT re-serialize it. The bundle distributes the participant's *own* TCT back to that participant alongside everyone else's, so a single fetch reveals the full session roster.

---

## 4. Bundle Issuance

### 4.1 Pre-conditions

The coordinator MUST have completed a Mutual Handshake (RFC-AITP-0004) with every participant before assembling a bundle. The bundle is a function of those handshakes; it does NOT itself perform identity binding.

### 4.2 Construction

1. For each participant `P_i`, take the peer-issued TCT compact JWS the coordinator issued during the handshake (`coordinator → P_i`), verbatim.
2. Compute `expires_at = min(TCT_i.exp)` across all participants, reading each TCT's `exp` claim from its decoded payload.
3. Assemble the `session_bundle` body with `version`, fresh `session_id`, `coordinator`, `issued_at`, this `expires_at`, and the `participants` array (each `tct` an opaque string).
4. Sign the canonical JCS bytes of the **inner** `session_bundle` body — excluding the `signature` member, and excluding the `{"session_bundle": …}` transport wrapper — with the coordinator's private key. Concretely: `sig_input = sha256(canonical_json(session_bundle_without_signature))`, then `signature = base64url(sign(coordinator_private_key, sig_input))`. Add the wrapper only when transmitting. The embedded TCT strings are covered verbatim by this signature.

### 4.3 Distribution

The coordinator MAY distribute the bundle by any transport that preserves the canonical JSON (HTTPS POST, signed message bus, etc.). Each participant SHOULD verify the bundle on receipt.

#### 4.3.1 Bundle HTTP transport (non-normative for Draft)

Implementations that use HTTPS for bundle distribution SHOULD use the
following paths so independent implementations interoperate without
out-of-band configuration:

| Path | Method | Purpose |
|---|---|---|
| `/aitp/session/bundle` | `POST` | Coordinator issues and stores a bundle. Request body is the `session_bundle` object defined in §3 (including the coordinator's `signature`). |
| `/aitp/session/bundle/{session_id}` | `GET` | Participant fetches the bundle for a known `session_id`. Response body is the same `session_bundle` object. |

These paths are RECOMMENDED, not reserved. Coordinators offering an
HTTPS bundle endpoint MUST advertise the **actual concrete URL** they
expose via `extensions["rfc-aitp-0010.bundle_uri"]` in their Manifest
(see [`registries/extension-keys.md`](../registries/extension-keys.md)).
Participants that do not find this extension key in the coordinator's
Manifest MUST treat HTTPS as unavailable for that coordinator and use a
non-HTTPS transport (signed message bus, push delivery, etc.); they MUST
NOT probe `/aitp/session/bundle` directly. The absence of the extension
key is the discovery signal, not the HTTP response from a guessed path.

Bundle transport over HTTPS uses standard TLS server-cert validation
(RFC-AITP-0009 §3 implementation requirements). The bundle's signature
is verified per §5 regardless of which transport delivered it — the
HTTP transport is a delivery convenience, not a trust upgrade.

---

## 5. Verification

A participant receiving a bundle MUST, in order:

1. **Version check** — `session_bundle.version` MUST be `"aitp/0.2"` or a later supported version. Failure ⇒ `BUNDLE_VERSION_MISMATCH`.
2. **Expiry check** — `session_bundle.expires_at` MUST be in the future. Failure ⇒ `BUNDLE_EXPIRED`.
3. **Expiry-window invariant** — `session_bundle.expires_at` MUST equal the minimum `exp` claim across the embedded participant TCTs (§6). Failure ⇒ `BUNDLE_EXPIRY_WINDOW_INVARIANT`.
4. **Participants non-empty** — `participants` MUST contain at least one entry. Failure ⇒ `BUNDLE_EMPTY_PARTICIPANTS`.
5. **Coordinator key resolution** — fetch and verify the coordinator's Manifest per RFC-AITP-0003 §5; resolve the coordinator's public key from `manifest.aid`.
6. **Bundle signature** — unwrap to the inner `session_bundle` object, then verify `session_bundle.signature` against the coordinator's key over the canonical inner body with `signature` excluded (the embedded TCT strings are covered verbatim). A verifier that canonicalizes the `{"session_bundle": …}` wrapper computes different bytes than the coordinator signed and will reject every valid bundle. Failure ⇒ `BUNDLE_INVALID_SIGNATURE`.
7. **Per-participant TCT verification** — for each `participants[i].tct`, run the standard TCT verification order (RFC-AITP-0005 §7.2: strict parse, `typ`, AID-pinned `alg`, signature, claims). Every embedded TCT MUST have an `iss` claim equal to `session_bundle.coordinator` (failure ⇒ `BUNDLE_COORDINATOR_ISSUER_MISMATCH`) and an `aud` claim equal to `participants[i].aid` (failure ⇒ `BUNDLE_AUDIENCE_MISMATCH`); other TCT-level failures — including `TOKEN_TYP_MISMATCH` / `TOKEN_ALG_MISMATCH` rejections of an embedded token — surface as `BUNDLE_PARTICIPANT_TCT_INVALID`. The participant SHOULD verify its own TCT first.
8. **Self-membership check** — the receiving participant MUST find its own AID in `participants[*].aid` and confirm the embedded TCT's `aud` claim equals its own AID. Failure ⇒ `BUNDLE_NOT_MEMBER`.

Implementations MUST NOT consume a bundle whose signature does not validate, regardless of whether individual TCTs are otherwise well-formed. Implementations MAY collapse all of the above into the aggregate `SESSION_BUNDLE_INVALID` when a deployment policy requires a single-error surface, but new code SHOULD prefer the specific codes.

---

## 6. Expiry

`session_bundle.expires_at` MUST equal the minimum `exp` claim across the embedded participant TCTs — `min(exp(participants[*].tct))`, where `exp(·)` reads the `exp` claim from the TCT's decoded JWS payload. This ensures the bundle is never valid past the lifetime of its shortest-lived participant TCT: bundle validity cannot outlive any member TCT's `exp`. A bundle whose `expires_at` exceeds any embedded TCT's `exp` claim is non-conformant and MUST be rejected at issuance and at verification time.

When the bundle expires, the coordinator SHOULD re-run the bilateral handshakes for any expiring participants, mint fresh TCTs, and publish a new bundle with a fresh `session_id`. Bundle reuse across sessions is forbidden — a bundle from session X MUST NOT be presented in session Y.

---

## 7. Revocation

Bundle revocation is **per-pair degradation**, not whole-bundle invalidation:

- Revoking a single participant's TCT (adding its `jti` claim to the coordinator's deny list, RFC-AITP-0008 §1) removes that participant from the active session.
- The remaining participants' TCTs in the same bundle are unaffected and remain valid until their own `exp`.
- Consuming peers MUST re-check each embedded TCT's `jti` against the coordinator's `ListRevoked` feed at the cadence configured by `revocation_policy.max_staleness_secs` (RFC-AITP-0008 §3.2).

A coordinator that wishes to terminate a session entirely MUST add every embedded TCT's `jti` to its deny list. There is no "revoke the bundle" surface; the bundle is a redistribution of TCTs, and the TCT `jti` deny list is the only revocation primitive.

---

## 8. Error Codes

| Code | Meaning | Retryable |
|---|---|---|
| `BUNDLE_INVALID_SIGNATURE` | Coordinator's outer bundle signature failed verification under the coordinator's Manifest key | false |
| `BUNDLE_VERSION_MISMATCH` | `version` is not `"aitp/0.2"` (or a later version this implementation supports) | false |
| `BUNDLE_EXPIRED` | `expires_at` is in the past at verification time | false |
| `BUNDLE_EXPIRY_WINDOW_INVARIANT` | `expires_at` is greater than the minimum `exp` claim across the embedded participant TCTs (violates §6) | false |
| `BUNDLE_COORDINATOR_ISSUER_MISMATCH` | One or more embedded TCTs carry an `iss` claim that does not equal `coordinator` | false |
| `BUNDLE_AUDIENCE_MISMATCH` | A `participants[i].tct` carries an `aud` claim that does not equal `participants[i].aid` | false |
| `BUNDLE_EMPTY_PARTICIPANTS` | `participants` array is empty (a bundle MUST contain at least the receiver) | false |
| `BUNDLE_PARTICIPANT_TCT_INVALID` | At least one embedded participant TCT failed standard TCT verification (§5 step 7), including `typ`/`alg` rejection of the embedded JWS | false |
| `BUNDLE_NOT_MEMBER` | Receiver's AID is not in `participants[*].aid` | false |

The aggregate code `SESSION_BUNDLE_INVALID` is a fallback for implementations that do not distinguish the failure cases; new code SHOULD prefer the specific codes above. Implementations MAY return the aggregate when a deployment policy requires a single-error surface for bundles.

---

## 9. Conformance Surface

| Adapter operation | Description |
|---|---|
| `issue_session_bundle` | Coordinator op: take N coordinator-issued TCTs and produce a signed bundle. |
| `verify_session_bundle` | Participant op: run §5 verification on a received bundle. |

A conformant v0.2 implementation that opts into RFC-AITP-0010 MUST expose both operations in its conformance harness. Implementations that do not expose them MUST report SKIP for any `bundle-*` fixture rather than FAIL.

KAT vector `kat-session-bundle-001` lives in [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json) and pins (coordinator key kat-keypair-001 + one participant TCT compact JWS string → canonical **inner** bundle body → SHA-256 → Ed25519 signature). Its `object` is the signing input itself, as its `signing_input: "body"` field records — not the `{"session_bundle": {…}}` transport form — and its pinned `coordinator_signature_b64url` verifies over exactly those bytes. Implementations MUST reproduce the canonical bytes and the digest byte-for-byte and MUST verify the pinned signature. **Note for implementers holding an earlier copy:** through v0.2-draft this vector pinned the *wrapped* form and its signature was minted over it; both were corrected (see `CHANGELOG.md` for the old and new digests). The vector is reworked for `aitp/0.2`: the bundle's own JCS form survives, but its embedded TCT members are opaque compact JWS strings (minted per the RFC-AITP-0005 signed-example vectors), covered verbatim by the JCS body. Conformance fixtures exercising the bundle verification path live at [`schemas/conformance/bundle-001-success.json`](../schemas/conformance/bundle-001-success.json), [`bundle-002-not-member.json`](../schemas/conformance/bundle-002-not-member.json), and [`bundle-003-expired.json`](../schemas/conformance/bundle-003-expired.json).

---

## 10. Security Considerations

- **Coordinator compromise.** A malicious or compromised coordinator can fabricate participant lists, omit revocation entries, or reissue stale bundles. Bundle consumers MUST treat the coordinator's AID with normal peer-trust scrutiny — there is no implicit privilege.

  **Recovery procedure.** When a coordinator's signing key is known to be compromised:

  1. The legitimate coordinator operator MUST publish a new Manifest under a **new AID** derived from a fresh key pair, following the emergency rotation procedure in [RFC-AITP-0003 §8.1](RFC-AITP-0003-manifest.md#81-emergency-rotation-key-compromise). The compromised AID is abandoned — it cannot be repaired by republishing under the same key.
  2. All participants MUST treat bundles whose `coordinator` field equals the old (compromised) coordinator AID as untrusted from the moment of compromise notification, regardless of whether the bundle's `signature` still cryptographically verifies. The attacker holds the old signing key; outer-signature validity is no longer evidence of legitimate issuance.
  3. The legitimate coordinator SHOULD notify participants out-of-band (the same channel that bootstraps coordinator trust in the first place — operator broadcast, MACP `SessionEnd`, etc.) and distribute a **fresh bundle under the new AID** by re-running the bilateral handshakes with each participant (RFC-AITP-0004) and issuing fresh per-participant TCTs that the new bundle embeds.
  4. Bundle lifetime is bounded by `expires_at` (§6). Bundles whose `expires_at` is in the past MUST NOT be used regardless of provenance — including bundles signed by the compromised key. This means an unrevoked old bundle expires on its own schedule even if the compromise notification does not reach every consumer immediately; the worst-case exposure window for a stolen coordinator key is bounded by the minimum `exp` claim across the embedded participant TCTs plus the compromise-detection delay.
  5. Participants that learn of compromise MUST NOT silently downgrade to a non-bundle session topology that papers over the missing trust artifact. Either a fresh bundle under the new AID arrives, or the session terminates — there is no "operate without bundle until further notice" middle state in v0.2.

  This recovery model assumes coordinator-compromise detection is out-of-band; AITP v0.1/v0.2 do not specify push-based compromise notification. Push-based notification is a candidate for a future RFC.
- **Bundle replay.** A bundle issued in session X MUST NOT be reusable in session Y. The `session_id` field and the minimum-TCT-`exp` expiry bound (§6) are the primary defenses; consumers MUST reject bundles whose `session_id` they have already accepted with a different signature.
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
