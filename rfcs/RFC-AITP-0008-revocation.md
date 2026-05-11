# RFC-AITP-0008
# Revocation

**Document:** RFC-AITP-0008
**Version:** 0.1.0-rc.3
**Status:** Release Candidate
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md), [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)

---

## Abstract

AITP defines three revocation surfaces: token revocation via the JTI deny list, key revocation by the identity issuer, and a long-running session re-verification pattern. In the agent-to-agent model, **each agent is the authoritative source for revoking the TCTs it issued**.

---

## 1. Token Revocation (JTI Deny List)

The primary revocation mechanism for v0.1 is a JTI deny list **per issuing peer**.

### 1.1 Revoking a TCT

The peer that issued a TCT (its `issuer` AID) is the only party that can revoke it. Revocation adds the TCT's `jti` to the issuing peer's deny list. The deny list is consulted by other peers via the issuing peer's `ListRevoked` HTTPS endpoint (RFC-AITP-0005 §10) or a per-token `Verify` call.

### 1.2 Deny-list entries

The deny list is internally a set of entry records. Each entry has the shape below; the canonical wire format that wraps these entries (with `version`, `issuer`, `published_at`, `expires_at`, and a signature) is defined in §1.5 and is the only form peers consume over the network.

```json
{
  "jti": "550e8400-e29b-41d4-a716-446655440000",
  "revoked_at": 1711900000,
  "reason": "key_compromised"
}
```

The `reason` field is OPTIONAL informational metadata. Implementations MUST NOT use `reason` strings in automated decision-making; revocation is a binary state determined solely by the presence of a `jti` in the signed list.

### 1.3 Persistence

The deny list SHOULD be persisted to survive restarts. In-memory-only deny lists are acceptable for v0.1 prototypes but **not for production use**.

### 1.4 Distribution

Distribution is pull-based in v0.1. A consuming peer SHOULD poll the issuing peer's `ListRevoked` endpoint with a configurable cadence. Push-based revocation is reserved for a future RFC.

### 1.5 Signed revocation response

`ListRevoked` responses MUST be signed by the issuing peer to prevent a network attacker from forging or suppressing entries:

```json
{
  "revocation_list": {
    "version":    "aitp/0.1",
    "issuer":     "<issuing-peer-AID>",
    "published_at": <unix-seconds>,
    "expires_at":   <unix-seconds>,
    "entries": [
      { "jti": "...", "revoked_at": <ts>, "reason": "..." }
    ]
  },
  "signature": "<base64url sig over canonical revocation_list JSON>"
}
```

The canonical schema is [`schemas/json/aitp-revocation-list.schema.json`](../schemas/json/aitp-revocation-list.schema.json).

| Field | Required | Description |
|---|---|---|
| `version` | REQUIRED | MUST be `"aitp/0.1"`. |
| `issuer` | REQUIRED | The issuing peer's AID. MUST equal the `issuer` of every TCT covered by the entries. |
| `published_at` | REQUIRED | Unix timestamp when this list snapshot was signed. |
| `expires_at` | REQUIRED | Unix timestamp after which this snapshot MUST NOT be cached. |
| `entries` | REQUIRED | Array of revoked-entry records (may be empty). |
| `signature` | REQUIRED | base64url signature over canonical `revocation_list` JSON (excluding `signature`), signed by the issuing peer's private key. Canonical JSON MUST be produced per [RFC 8785 (JCS)](https://datatracker.ietf.org/doc/html/rfc8785); see [RFC-AITP-0001 §5.4](RFC-AITP-0001-core.md#54-signature). The signing input is the **inner** `revocation_list` body — the `{"revocation_list": {...}, "signature": "..."}` envelope is the wire / HTTP transport shape, NOT part of the canonical signing bytes. (This matches the RFC-AITP-0010 session-bundle and RFC-AITP-0011 multi-hop conventions: the wrapper key names the artifact for transport routing but the issuer signs the inner body.) A worked example (`kat-revocation-001`) showing the canonical bytes and SHA-256 digest of a fixed revocation snapshot body lives at [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json); implementations MUST reproduce it byte-for-byte. Implementations migrating from rc.3-era code (which signed the wrapped form) MAY accept either canonical shape during a transition window but MUST emit the inner form going forward. |

**Verification.** A consuming peer MUST verify the signature against the issuing peer's public key (resolved from the issuing peer's Manifest, RFC-AITP-0003). A snapshot whose `expires_at` is in the past, or whose signature does not validate, MUST be discarded; the peer SHOULD treat the absence of a fresh snapshot per its configured `revocation_policy.mode` (§3).

**Empty lists are signed.** Even when an issuing peer has revoked nothing, it MUST publish a signed snapshot with an empty `entries` array. This prevents a network attacker from suppressing a fresh signed list and serving an older one with revocations stripped.

---

## 2. Key Revocation

Identity issuers MAY publish a list of revoked key IDs at their well-known endpoint or a dedicated revocation endpoint:

```json
{
  "revoked_keys": [
    {
      "kid": "key-1",
      "revoked_at": 1711900000
    }
  ]
}
```

When a key used to sign a peer's identity proof appears in the issuer's revoked-key list, the identity MUST be rejected.

A peer that learns its own AID key has been compromised SHOULD immediately:
1. Revoke all TCTs it issued (add their `jti` to its deny list).
2. Re-publish its Manifest with a fresh `aid` derived from a new key pair.
3. Notify any peers it knows of out-of-band.

---

## 3. Revocation Policy

```yaml
revocation_policy:
  mode: fail_closed | fail_open | soft_fail
  max_staleness_secs: 300
```

### 3.1 Modes

**`fail_closed`** (most secure)
- Issuing peer's `ListRevoked` endpoint unreachable → reject the request.
- Use for: high-value capabilities, financial actions, irreversible operations.

**`fail_open`** (availability-first)
- Endpoint unreachable → allow the request, log a warning.
- Use for: read-only, non-sensitive operations.

**`soft_fail`**
- Endpoint unreachable → allow the request with restricted grants.
- Grants restricted to read-only or a configured safe subset.
- The degraded state MUST be logged.

The schema default for `revocation_policy.mode` is **`fail_closed`** (see `aitp-trust-anchors.schema.json`). Deployments that need availability-first behavior MUST opt into `soft_fail` or `fail_open` explicitly; secure-by-default means revocation enforcement does not silently degrade. Production deployments handling high-value capabilities (financial operations, irreversible actions, privileged data access) SHOULD keep the `fail_closed` default. `soft_fail` is appropriate only where availability outweighs the risk of operating on a potentially revoked TCT, and the safe-subset restriction has been deliberately configured.

### 3.2 Staleness

`max_staleness_secs` defines the maximum age of a cached revocation list. If the cached list is older than this value and the endpoint is unreachable, the configured `mode` applies.

---

## 4. Session Revocation

For long-running peer interactions, the issuing peer MAY signal revocation by adding the TCT's `jti` to its deny list. Consuming peers SHOULD periodically re-verify TCTs for long-lived sessions.

Re-verification interval: RECOMMENDED every 5 minutes for sessions lasting more than 1 hour.

### 4.1 Session invalidation model (v0.1)

In v0.1, "session invalidation" — terminating every active interaction with a specific subject peer — is achieved by revoking every TCT the issuer has ever issued to that subject. There is no separate session-level revocation surface. The deny list (§1) is the single source of truth.

An issuer wishing to terminate all active sessions with peer B MUST:

1. Add every TCT JTI ever issued to B (within their unexpired window) to its deny list.
2. Publish a new signed revocation snapshot (§1.5) reflecting the additions. Empty-snapshot signing rules apply if the issuer had nothing else revoked.
3. OPTIONALLY publish a short-TTL Manifest ([RFC-AITP-0003 §8](RFC-AITP-0003-manifest.md#8-manifest-rotation)) to accelerate consuming peers' cache expiry — useful when revocations propagate slower than the issuer wants.

A "session-level revoke-all" API (one operation that covers a subject without enumerating individual JTIs) is reserved for a future RFC. v0.1 implementations SHOULD surface per-JTI revocation as the primary admin API; bulk-revocation-by-subject is a quality-of-life concern, not a protocol requirement.

**Limitation (issuer JTI history).** An issuer that does not maintain a complete history of issued JTIs cannot guarantee total session revocation — it can only revoke the JTIs it remembers. Issuers SHOULD persist issued JTIs at least until `max(issued_tct.expires_at)` for the relevant subject so the bulk-revocation operation above is complete. After that point all unrevoked TCTs are guaranteed expired, so the JTI is no longer needed for session-revocation completeness; it MAY be garbage-collected from the issuer-side history table.

This is an **issuer-side persistence** requirement and is not visible on the wire. It is a SHOULD (not a MUST) because the deficiency manifests as an *issuer's inability to enumerate its own subject TCTs* rather than as a protocol-level error a peer can observe; an issuer that fails to enumerate is silently providing weaker session-revocation guarantees than its consuming peers will assume. See [§1.3](#13-persistence) for the related deny-list persistence guidance — the deny list and the issued-JTI history are two distinct issuer-side structures with the same persistence motivation.

---

## 5. Security Considerations

- The issuing peer's `ListRevoked` endpoint is itself a trust surface; it MUST be served over HTTPS, and its responses SHOULD be signed by the issuing peer.
- `fail_open` trades security for availability and MUST NOT be the default for high-value operations.
- Clock skew between the issuing peer and consuming peers reduces effective revocation latency. Implementations SHOULD use a monotonic clock when comparing `revoked_at`.
- A compromised peer can stop honoring its own revocations. Defense in depth: high-value operations SHOULD use short TTLs (RFC-AITP-0005 §8.1) so that revocation latency is bounded by the TCT lifetime.

---

## 6. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)
- [RFC-AITP-0007 Key Resolution](RFC-AITP-0007-key-resolution.md)
