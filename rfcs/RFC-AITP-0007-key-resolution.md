# RFC-AITP-0007
# Key Resolution

**Document:** RFC-AITP-0007
**Version:** 0.1.0-rc.3
**Status:** Release Candidate
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md), [RFC-AITP-0002 Identity](RFC-AITP-0002-identity.md), [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)

---

## Abstract

Key resolution is the process of obtaining the public key needed to verify a signature. AITP has two distinct resolution flows:

1. **Peer key resolution** — used to verify a peer's envelope signature, Manifest signature, and peer-issued TCT signature. The peer's public key is resolved from the peer's Manifest.
2. **Identity-issuer key resolution** — used to verify an identity proof (e.g. an OIDC JWT). The issuer's public keys are resolved via cache → pinned → well-known.

This RFC defines both flows.

---

## 1. Peer Key Resolution

The peer's public key is encoded in `manifest.aid` (specifically, the AID's `<identifier>` portion). Resolution order:

```
1. Manifest cache       (in-memory, TTL-backed by manifest.expires_at)
2. Inline manifest      (received during the Mutual Handshake)
3. Well-known endpoint  (https://<peer-host>/.well-known/aitp-manifest)
```

Implementations MUST:

- Treat the cached Manifest as authoritative until `expires_at`.
- Prefer the inline Manifest received in `MUTUAL_HELLO` / `MUTUAL_HELLO_ACK` if it has a newer `published_at` than the cached one (RFC-AITP-0004 §11.3).
- Re-fetch from `well-known` when the cache is past `expires_at`.

A peer key resolution failure MUST result in `KEY_RESOLUTION_FAILED`.

---

## 2. Identity-Issuer Key Resolution

For OIDC identity bindings (RFC-AITP-0002 §2), the issuer's keys are resolved separately. Order:

```
1. Cache              (in-memory, TTL-backed)
2. Pinned Keys        (local trust_anchors configuration)
3. Well-known URL     (network fetch)
```

Resolution stops at the first success.

### 2.1 Cache

- Keys fetched from well-known URLs MUST be cached.
- Cache TTL: default `3600` seconds, configurable.
- Cache SHOULD be refreshed asynchronously before TTL expiry.
- Expired cache entries MUST NOT be used unless `offline_mode` is enabled.

### 2.2 Pinned Keys

Pinned keys are statically configured in the local trust-anchor configuration. See [RFC-AITP-0002 §4](RFC-AITP-0002-identity.md#4-trust-anchors). Pinned keys are always preferred over network-fetched keys for the same issuer.

### 2.3 Well-known Endpoint

For **OIDC issuers**, key resolution MUST use the standard OIDC discovery flow:

1. Fetch `https://<issuer>/.well-known/openid-configuration` (HTTPS only).
2. Parse the response and extract the `jwks_uri` value.
3. Fetch the JWK Set from `jwks_uri` (HTTPS only).
4. Use the keys (matching the JWT header's `kid`) to verify the OIDC identity proof.

This makes AITP work with **any standards-compliant OIDC provider** without requiring the provider to publish an AITP-specific endpoint. The OIDC Core 1.0 and OIDC Discovery 1.0 specifications already define every step.

For **non-OIDC AITP-native key publication** (e.g. an internal identity service that does not implement OIDC discovery), implementations MAY also accept:

```
https://<issuer>/.well-known/aitp-keys
```

with response format:

```json
{
  "issuer": "https://auth.example.com",
  "keys": [
    {
      "kid": "key-1",
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "<base64url-encoded-public-key>"
    }
  ],
  "published_at": 1711900000,
  "expires_at": 1711990000
}
```

When both endpoints are present, OIDC discovery (`openid-configuration` → `jwks_uri`) MUST be tried first; the AITP-native endpoint is a fallback for non-OIDC issuers only. All fetches MUST use HTTPS. Plain HTTP MUST be rejected.

---

## 3. Failure Handling

When an identity-issuer key resolution flow exhausts all sources, the agent applies the configured `key_resolution.fail_mode` (NOT `revocation_policy.mode`, which governs revocation lookup failures only):

| Mode | Behavior |
|---|---|
| `fail_closed` | Reject the request. Return `KEY_RESOLUTION_FAILED`. |
| `fail_open` | Allow the request. Log a warning. No capability restrictions. |
| `soft_fail` | Allow the request with grants restricted to a configured safe subset. |

The two modes have different defaults and semantics: `key_resolution.fail_mode` defaults to `fail_closed` and applies when no key for the identity issuer can be obtained, while `revocation_policy.mode` (RFC-AITP-0008 §3.1) applies when a revocation list cannot be fetched. Operators MUST configure them independently. See [`schemas/json/aitp-trust-anchors.schema.json`](../schemas/json/aitp-trust-anchors.schema.json).

### 3.1 Soft-fail grant restriction

In `soft_fail`, when key resolution fails, the agent MUST restrict grants to exclude any capability marked as requiring verified identity in policy. The safe subset is deployment-configured. **If no safe subset is configured, `soft_fail` MUST behave as `fail_closed`.**

For peer-key resolution failures, `soft_fail` is not applicable. Without a peer's Manifest there is nothing to verify against; the handshake cannot proceed.

---

## 4. Offline Mode

When `offline_mode: true`:

- Identity-issuer well-known endpoint resolution is skipped entirely.
- Only cache and pinned keys are consulted for identity issuers.
- For peer Manifests, only cached and inline Manifests are accepted; outbound `/.well-known/aitp-manifest` fetches MUST NOT be made.
- Implementations MUST set `offline_mode: true` in air-gapped environments.

```yaml
key_resolution:
  offline_mode: true
  cache_ttl_secs: 3600
  fail_mode: fail_closed
```

---

## 5. Security Considerations

- Both well-known endpoints (peer Manifest and identity-issuer keys) are trust roots. Servers MUST present a valid TLS certificate; clients MUST validate it.
- Cache poisoning is mitigated by HTTPS. Implementations SHOULD also verify a static fingerprint when available.
- An agent MUST NOT downgrade `fail_mode` based on transient errors. The configured mode is the policy.
- A peer cache MUST be invalidated when the cached Manifest's `expires_at` passes; serving an expired Manifest hides peer key rotation.

---

## 6. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0002 Identity](RFC-AITP-0002-identity.md)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)
