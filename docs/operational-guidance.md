# Operational Guidance

This document collects non-normative operational patterns for AITP
deployments. The authoritative protocol is in the RFCs under
[`rfcs/`](../rfcs/); this is the playbook.

---

## Handshake renewal

TCTs expire. Peers that need a continuing trust relationship rerun the
Mutual Handshake (RFC-AITP-0004) before expiry. AITP v0.1 conformance
defines only the **full Mutual Handshake** as a renewal mechanism —
round 1 is full credential exchange, round 2 issues fresh TCTs, and the
contract is uniform across initial and renewing handshakes. A
non-normative **shortened renewal extension** is described in
[RFC-AITP-0004 §8.1](../rfcs/RFC-AITP-0004-mutual-handshake.md#81-non-normative-shortened-renewal-extension)
and discussed below; it is opt-in and not part of v0.1 conformance.

### Recommended pattern

- Track each held peer TCT's `expires_at`.
- When a TCT is within **5 minutes** of expiry, initiate a fresh
  Mutual Handshake to the peer's `handshake_endpoint`.
- On success, replace the expired TCT with the renewed one and discard
  the old `jti`.
- On failure, mark the peer relationship as expired and stop using the
  old TCT immediately. Subsequent operations require a new handshake.

### Race conditions to handle

- A renewal initiated 5 minutes before expiry MAY complete after
  `expires_at` if the peer is slow. Implementations SHOULD start renewal
  earlier on slow links — 10–15 minutes before expiry for low-latency
  SLAs.
- A peer that rotates its key during the renewal window will return a
  Manifest with a newer `published_at`. The renewing peer MUST accept
  the newer Manifest and discard its cached copy (RFC-AITP-0004 §11.3).

### Why no in-band renewal in v0.1 conformance?

A shortened "renewal" message that skipped credential exchange would
re-introduce the trust gap: an attacker holding an expired TCT could
present it as proof of an existing relationship and skip identity
verification. Forcing every renewal through the full handshake keeps the
contract uniform: every TCT is issued only after a fresh PoP exchange.

### Shortened renewal (experimental)

[RFC-AITP-0004 §8.1](../rfcs/RFC-AITP-0004-mutual-handshake.md#81-non-normative-shortened-renewal-extension)
defines a non-normative, opt-in shortened renewal endpoint that some
implementations (notably the reference library `aitp-rs`) offer behind
an explicit feature flag. It is **not** part of v0.1 conformance and is
not assumed by interoperating peers unless advertised.

**When you might enable it.** High-frequency, low-value renewals between
two long-lived peers under the same operator (e.g. internal services
that handshake hundreds of times per minute) where the full
four-message handshake adds measurable latency and the operator accepts
the narrower trust-rebinding semantics described below.

**Discovery.** A peer that supports shortened renewal advertises it in
its Manifest:

```json
{
  "extensions": {
    "rfc-aitp-0005.renew_uri": "https://agent-b.example.com/aitp/handshake/renew"
  }
}
```

The key is registered in
[`registries/extension-keys.md`](../registries/extension-keys.md). Peers
without that extension key MUST fall back to a full Mutual Handshake.

**Wire format and constraints.** See RFC-AITP-0004 §8.1 for the request
/ response shape. Operationally:

- The current TCT MUST still be valid (`expires_at > now`) when the
  renewal request is sent. Shortened renewal cannot resurrect an
  already-expired TCT — that path requires a full handshake.
- The issuer MUST re-evaluate its grant policy, revocation list, and
  Manifest expiry on every shortened renewal. Skipping identity
  re-presentation is not a license to skip authorization.
- Implementations SHOULD impose a "ceiling" on consecutive shortened
  renewals (e.g. force a full handshake every N renewals or every M
  hours of wall-clock continuity) so that long-lived sessions
  periodically re-bind identity end-to-end. The reference default is
  every **24 hours** or every **8 shortened renewals**, whichever comes
  first.

**Failure modes.** A shortened renewal MAY fail with any of the standard
handshake error codes plus the new
[`TCT_EXPIRES_AFTER_MANIFEST`](../registries/error-codes.md) when the
issuer's Manifest has rotated below the requested new expiry. On any
failure the renewing peer MUST fall back to a full Mutual Handshake
before continuing to use the (still-valid-but-soon-expiring) TCT.

**Backwards compatibility.** A peer that does not advertise
`rfc-aitp-0005.renew_uri` MUST be renewed via full Mutual Handshake. A
peer that advertises it MAY also accept full Mutual Handshakes — the
extension is additive, never substitutive.

---

## Manifest rotation

Agents publish their Manifest at `/.well-known/aitp-manifest`. Per
RFC-AITP-0003 §8, rotation SHOULD follow a schedule proportional to
`expires_at - published_at`:

| Manifest TTL | Recommended rotation |
|---|---|
| ≤ 1 hour | Every 30 minutes |
| ≤ 24 hours | Every 12 hours |
| ≤ 7 days | Every 3 days |

When the agent's signing key changes, the Manifest MUST be re-signed
immediately. Operators SHOULD treat the published Manifest and the
runtime `trust_anchors` config as a single deploy unit, since divergence
causes silent handshake failures (RFC-AITP-0003 §5.1).

---

## Cache TTL tuning

| Cache | Default TTL | When to lower | When to raise |
|---|---|---|---|
| `message_id` deny list | ≥ timestamp tolerance (300 s) | Never below tolerance | Increase if clock skew is high |
| Resolved issuer keys | 3600 s | Lower when the issuer publishes a fast key-rotation schedule | Only if the issuer publishes a documented rotation schedule longer than 1 hour. If the rotation interval is unknown, keep the 3600 s default. Never raise to "match" a multi-day rotation interval — that would mean caching keys long after they may have been retired. |
| Resolved peer Manifests | `manifest.expires_at` | Lower if peers rotate frequently | Don't exceed `expires_at` |

The `message_id` deny list is the only cache where shrinking is
*incorrect*: the protocol's replay defense depends on it covering the
full timestamp tolerance window.

---

## Failure modes

| Mode | Trigger | Default | Use when |
|---|---|---|---|
| `key_resolution.fail_mode` | No identity-issuer key obtainable from cache, pinned config, or well-known fetch | `fail_closed` | Production identity flows |
| `revocation_policy.mode` | Revocation list cannot be fetched within `max_staleness_secs` | `fail_closed` | High-value capabilities |
| `revocation_policy.mode = soft_fail` | Same as above | — | Non-critical capabilities with a configured safe subset |

`fail_open` is acceptable only in development environments and
explicitly air-gapped offline modes (RFC-AITP-0007 §4). Operators MUST
NOT auto-downgrade modes based on transient errors — the configured
mode is the policy.

---

## Rate limiting

The handshake endpoint is publicly reachable. RFC-AITP-0004 §11.4 sets a
RECOMMENDED default of 10 handshake initiations per minute per source
AID. Production deployments SHOULD also rate-limit per source IP and
implement exponential backoff for repeat failures from the same
attacker.

---

## See also

- [RFC-AITP-0004 Mutual Handshake](../rfcs/RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0007 Key Resolution](../rfcs/RFC-AITP-0007-key-resolution.md)
- [RFC-AITP-0008 Revocation](../rfcs/RFC-AITP-0008-revocation.md)
- [`docs/integration-guide.md`](integration-guide.md)
