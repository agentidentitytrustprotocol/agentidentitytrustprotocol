# Operational Guidance

This document is non-normative. It points operators at the normative rules
that govern running AITP in production and at the sibling-repository docs
that explain the mechanics. The authoritative protocol is in the RFCs under
[`rfcs/`](../rfcs/README.md); how to configure and deploy a specific
implementation is owned by that implementation's repository (see
[ecosystem.md](ecosystem.md)). Where this page states a rule or a default
value, the RFC or schema it comes from is cited next to it — if the two ever
disagree, the RFC wins.

---

## Handshake renewal

TCTs expire per their `exp` claim. In v0.2 core there is **no in-band
renewal message**: a peer that needs a continuing trust relationship runs a
fresh Mutual Handshake before expiry, and agents MUST NOT use an expired peer
TCT ([RFC-AITP-0004 §8](../rfcs/RFC-AITP-0004-mutual-handshake.md#8-handshake-renewal)).
Every TCT is therefore issued only after a fresh proof-of-possession exchange,
and renewal re-verifies identity at expiry
([RFC-AITP-0004 §12](../rfcs/RFC-AITP-0004-mutual-handshake.md#12-non-goals)).

Operational pattern:

- Track each held peer TCT's `exp` and start the renewing handshake early
  enough that it completes before `exp` on your slowest path. How much lead
  time that is depends on your links; the RFCs set no value.
- On success, replace the old TCT (and its companion grant voucher, if any)
  with the new one. On failure, stop using the old TCT once it expires; a new
  handshake is required.
- If the peer rotated its key in the meantime, its inline Manifest carries a
  newer `published_at`; accept it if it verifies and discard the cached copy
  ([RFC-AITP-0004 §11.3](../rfcs/RFC-AITP-0004-mutual-handshake.md#113-race-condition-on-manifest-refresh)).

### Shortened renewal (opt-in, not part of v0.2 conformance)

[RFC-AITP-0004 §8.1](../rfcs/RFC-AITP-0004-mutual-handshake.md#81-non-normative-shortened-renewal-extension)
sketches a non-normative shortened renewal endpoint; its standardization is
reserved as [RFC-AITP-0013](../rfcs/RFC-AITP-0013-tct-renewal-extension.md)
(status: Planned). The points an operator needs:

- It MUST be gated behind an explicit opt-in and advertised through the
  Manifest extension key `rfc-aitp-0005.renew_uri`
  ([registry](../registries/extension-keys.md)). Peers that do not find the
  key MUST renew with a full Mutual Handshake and MUST NOT probe a guessed
  path (RFC-AITP-0004 §8.1).
- The current TCT MUST still be unexpired, and the issuer MUST re-evaluate
  its grant policy — shortened renewal is not a bypass for revocation,
  Manifest rotation or trust-anchor changes (RFC-AITP-0004 §8.1).
- The response is a fresh TCT with a new `jti`, accompanied per issuer
  policy by a freshly minted grant voucher; vouchers bound to the old TCT's
  `jti` do not carry over to the renewed token (RFC-AITP-0004 §8.1,
  [RFC-AITP-0013](../rfcs/RFC-AITP-0013-tct-renewal-extension.md#sketch-under-aitp02-non-normative)).
- v0.2 conformance testers MUST NOT require it (RFC-AITP-0004 §8.1).

How the reference implementation exposes it (wire format, issuer-side
algorithm, SDK calls, known limitations):
[aitp-rs `docs/tct-renewal.md`](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/tct-renewal.md).

---

## Manifest and key rotation

- Rotate the Manifest on a schedule proportional to its lifetime — the
  recommended schedule is the table in
  [RFC-AITP-0003 §8](../rfcs/RFC-AITP-0003-manifest.md#8-manifest-rotation).
  When the signing key changes, the Manifest MUST be re-signed immediately.
- On key compromise, the steps in
  [RFC-AITP-0003 §8.1](../rfcs/RFC-AITP-0003-manifest.md#81-emergency-rotation-key-compromise)
  are normative (new key and AID, revoke every TCT issued under the old AID,
  notify peers out of band).
- A Manifest MUST be republished whenever the runtime `trust_anchors`
  configuration changes, and operators SHOULD check the two agree at build
  or deploy time
  ([RFC-AITP-0003 §5.1](../rfcs/RFC-AITP-0003-manifest.md#51-trust-anchor-consistency-requirement)).
- Signing keys SHOULD be rotated on a schedule; the recommended interval is
  90 days ([RFC-AITP-0009 §3](../rfcs/RFC-AITP-0009-security.md#3-implementation-security-requirements)).

Storing seeds and performing a rotation with the reference implementation:
[aitp-rs key management — Rotation](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/key-management.md#rotation).

---

## Spec-owned defaults

These are the values the RFCs and schemas themselves set. Implementation-
specific knobs (replay-store backends, session routing, connection limits)
are documented by the implementation — for aitp-rs see
[deployment](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/deployment.md)
and the
[transport hardening register](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/transport-hardening.md).

| Setting | Default | Source |
|---|---|---|
| Envelope timestamp tolerance | 300 s, configurable | [RFC-AITP-0001 §5.5](../rfcs/RFC-AITP-0001-core.md#55-replay-protection) |
| `message_id` deny-list retention | at least the timestamp tolerance window (shrinking it below the window breaks replay protection) | RFC-AITP-0001 §5.5 |
| Handshake transient state (nonces, inline Manifest, unconfirmed TCT/voucher) | at most the timestamp tolerance window, or until the handshake completes or fails | [RFC-AITP-0004 §7](../rfcs/RFC-AITP-0004-mutual-handshake.md#7-state-management) |
| Identity-issuer key cache TTL (`key_resolution.cache_ttl_secs`) | 3600 s, configurable; expired entries MUST NOT be used unless `offline_mode` is on | [RFC-AITP-0007 §2.1](../rfcs/RFC-AITP-0007-key-resolution.md#21-cache); [`aitp-trust-anchors.schema.json`](../schemas/json/aitp-trust-anchors.schema.json) |
| Peer Manifest cache | never beyond the Manifest's `expires_at` | [RFC-AITP-0007 §5](../rfcs/RFC-AITP-0007-key-resolution.md#5-security-considerations); RFC-AITP-0003 §8 |
| `key_resolution.fail_mode` | `fail_closed` | [RFC-AITP-0007 §3](../rfcs/RFC-AITP-0007-key-resolution.md#3-failure-handling); schema `key_resolution.fail_mode.default` |
| `revocation_policy.mode` | `fail_closed` | [RFC-AITP-0008 §3.1](../rfcs/RFC-AITP-0008-revocation.md#31-modes); schema `revocation_policy.mode.default` |
| `revocation_policy.max_staleness_secs` | 300 s | [RFC-AITP-0008 §3](../rfcs/RFC-AITP-0008-revocation.md#3-revocation-policy); schema `revocation_policy.max_staleness_secs.default` in [`aitp-trust-anchors.schema.json`](../schemas/json/aitp-trust-anchors.schema.json) |
| Re-verification of long-lived peer TCTs against the issuer's `ListRevoked` | every 5 minutes (RECOMMENDED for sessions longer than 1 hour) | [RFC-AITP-0008 §4](../rfcs/RFC-AITP-0008-revocation.md#4-session-revocation); [RFC-AITP-0009 §3](../rfcs/RFC-AITP-0009-security.md#3-implementation-security-requirements) |

---

## Failure modes

Key resolution and revocation lookup are configured **independently**
(`key_resolution.fail_mode` vs `revocation_policy.mode`; RFC-AITP-0007 §3).
Both default to `fail_closed`, and an agent MUST NOT downgrade `key_resolution.fail_mode`
based on transient errors — the configured mode is the policy
([RFC-AITP-0007 §5](../rfcs/RFC-AITP-0007-key-resolution.md#5-security-considerations)).

### Identity-issuer key resolution (`key_resolution.fail_mode`)

Applies when no key for an identity issuer can be obtained from cache, pinned
configuration or the well-known endpoint
([RFC-AITP-0007 §3](../rfcs/RFC-AITP-0007-key-resolution.md#3-failure-handling)).

| Mode | Behaviour | Source |
|---|---|---|
| `fail_closed` (default) | Reject with `KEY_RESOLUTION_FAILED`. | RFC-AITP-0007 §3 |
| `soft_fail` | Allow with grants restricted to a deployment-configured safe subset — but only after the identity has been verified against a cached still-valid key, a pinned key, or a deployment-local trust context. With no configured safe subset, or no such trust basis, it MUST behave as `fail_closed`. | [RFC-AITP-0007 §3.1](../rfcs/RFC-AITP-0007-key-resolution.md#31-soft-fail-grant-restriction), [§3.2](../rfcs/RFC-AITP-0007-key-resolution.md#32-soft-fail-and-identity-verification) |
| `fail_open` | Suppresses the *network* error only when a cached still-valid or pinned issuer key already exists; it **never bypasses the signature check**, which still runs and fails if there is no such key. MUST NOT be offered as a production default; appropriate for deployments with pinned issuer keys where network failures should not block handshakes. | [RFC-AITP-0007 §3.3](../rfcs/RFC-AITP-0007-key-resolution.md#33-fail_open-and-identity-verification) |

For **peer Manifest** key resolution every mode behaves as `fail_closed`:
without a verified Manifest the handshake fails (RFC-AITP-0007 §3.2).
Air-gapped deployments MUST set `offline_mode: true`, which skips
well-known fetches and consults only cache and pinned keys
([RFC-AITP-0007 §4](../rfcs/RFC-AITP-0007-key-resolution.md#4-offline-mode)) —
offline mode is a separate setting, not a fail mode.

### Revocation lookup (`revocation_policy.mode`)

Applies when no fresh revocation snapshot is available — the issuer's
`ListRevoked` endpoint is unreachable and the cached snapshot is older than
`max_staleness_secs`
([RFC-AITP-0008 §3.2](../rfcs/RFC-AITP-0008-revocation.md#32-staleness)).

| Mode | Behaviour | Pinned by | Source |
|---|---|---|---|
| `fail_closed` (default) | An absent or stale snapshot means revocation status is unknown, treated as revoked: reject the TCT with `TCT_REVOKED` (not a snapshot error code). | `rev-001` | [RFC-AITP-0008 §3.1](../rfcs/RFC-AITP-0008-revocation.md#31-modes) |
| `soft_fail` | Allow with grants restricted to read-only or a configured safe subset; the degraded state MUST be logged. | `rev-002` | RFC-AITP-0008 §3.1 |
| `fail_open` | Allow and log a warning; grants are **not** narrowed. For read-only, non-sensitive operations; MUST NOT be the default for high-value operations. | `rev-009` | RFC-AITP-0008 §3.1, [§5](../rfcs/RFC-AITP-0008-revocation.md#5-security-considerations) |

Whatever the mode, network revocation lookups (fetching `ListRevoked`, DNS
resolution of issuer endpoints, writes to a shared revocation cache) MUST
wait until the token's signatures have verified; only a purely local,
side-effect-free deny-list check may run earlier
([RFC-AITP-0008 §3.3](../rfcs/RFC-AITP-0008-revocation.md#33-revocation-lookup-ordering),
fixture `rev-004`).

---

## Rate limiting and the handshake endpoint

The `handshake_endpoint` is public. Implementations **MUST** rate-limit it per
source AID or IP; the RECOMMENDED default is 10 handshake initiations per
minute per source AID
([RFC-AITP-0004 §11.4](../rfcs/RFC-AITP-0004-mutual-handshake.md#114-denial-of-service-on-handshake-endpoint)).
[RFC-AITP-0009 §3.1](../rfcs/RFC-AITP-0009-security.md#31-rate-limiting-recommended)
gives the RECOMMENDED defaults — 30 requests per source IP and 10 per
initiator AID per 60 s, at most 1000 concurrent in-flight handshake sessions,
and a 64 KB maximum `MUTUAL_HELLO` payload — to be tuned for high-volume
deployments. Rate-limited requests SHOULD get HTTP 429 with no AITP `error`
envelope, since they never reached the protocol layer (RFC-AITP-0009 §3.1).

The check order at the endpoint is normative (RFC-AITP-0009 §3.1):

1. `message_id` deny list (replay) — before rate limiting, so a replayed
   envelope does not consume the sender's rate-limit slot;
2. rate limiting;
3. timestamp tolerance;
4. Content-Type and body-size validation;
5. envelope signature verification;
6. payload cryptographic checks.

In a multi-instance deployment the replay deny list must be shared (or
routing made sticky) for this to hold; how to do that with aitp-rs is in
[deployment](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/deployment.md)
and
[transport hardening](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/transport-hardening.md).

---

## See also

- [RFC-AITP-0004 Mutual Handshake](../rfcs/RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0007 Key Resolution](../rfcs/RFC-AITP-0007-key-resolution.md)
- [RFC-AITP-0008 Revocation](../rfcs/RFC-AITP-0008-revocation.md)
- [RFC-AITP-0009 Security](../rfcs/RFC-AITP-0009-security.md)
- [threat-model.md](threat-model.md) · [integration-guide.md](integration-guide.md) · [ecosystem.md](ecosystem.md)
