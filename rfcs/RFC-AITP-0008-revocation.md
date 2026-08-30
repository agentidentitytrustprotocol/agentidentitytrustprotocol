# RFC-AITP-0008
# Revocation

**Document:** RFC-AITP-0008
**Version:** 0.2.2-draft
**Status:** Community Standards Track (v0.2 Draft)
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md), [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)

---

## Abstract

AITP defines three revocation surfaces: token revocation via the JTI deny list, key revocation by the identity issuer, and a long-running session re-verification pattern. In the agent-to-agent model, **each agent is the authoritative source for revoking the TCTs it issued**.

---

## 1. Token Revocation (JTI Deny List)

The primary revocation mechanism for v0.2 is a JTI deny list **per issuing peer**. The TCT's `jti` claim is the revocation handle, unchanged from v0.1 (RFC-AITP-0005 §2).

### 1.1 Revoking a TCT

The peer that issued a TCT (the AID in its `iss` claim) is the only party that can revoke it. Revocation adds the TCT's `jti` claim to the issuing peer's deny list. The deny list is consulted by other peers via the issuing peer's `ListRevoked` HTTPS endpoint (RFC-AITP-0005 §11) or a per-token `Verify` call.

Revoking a TCT also kills everything derived from it. The companion grant voucher carries the TCT's `jti` as its `src_jti` claim (RFC-AITP-0005 §8.1) and has no independent revocation handle; delegation verification looks up `voucher.src_jti` against this same deny list (RFC-AITP-0006 §4 step 7) and rejects with `DELEGATION_SOURCE_TCT_REVOKED`. One deny-list entry therefore invalidates the TCT, its voucher, and every delegation token built on that voucher.

**Wire-level rejection code.** A consuming peer that finds a TCT's `jti` in the issuing peer's signed deny list (after the ordering requirement in §3.3 has been satisfied) MUST reject the TCT with `TCT_REVOKED`. This is the only correct code for revocation rejection — `TCT_EXPIRED` is reserved for `exp` being in the past (RFC-AITP-0005 §9), `TCT_EXPIRES_AFTER_MANIFEST` is reserved for the Manifest-bound violation (RFC-AITP-0005 §10.4), and `TCT_SIGNATURE_INVALID` is reserved for cryptographic signature failure. Implementations that fold revocation into a generic expiry code lose the operator's ability to distinguish "issuer revoked this token early" from "this token reached its natural deadline."

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

The deny list SHOULD be persisted to survive restarts. In-memory-only deny lists are acceptable for v0.2 prototypes but **not for production use**.

### 1.4 Distribution

Distribution is pull-based in v0.2. A consuming peer SHOULD poll the issuing peer's `ListRevoked` endpoint with a configurable cadence. Push-based revocation is reserved for a future RFC.

### 1.5 Signed revocation response

`ListRevoked` responses MUST be signed by the issuing peer to prevent a network attacker from forging or suppressing entries:

> **Serialization unchanged in v0.2; the signing input is not.** The
> revocation snapshot is a protocol-internal artifact, exchanged only
> between full AITP stacks, and it remains under the **JCS
> embedded-signature profile** (RFC-AITP-0001 §5.4) in v0.2. It is NOT
> re-serialized as compact JWS — the v0.2 JWS migration covers only the
> portable trust artifacts (TCT, grant voucher, delegation token;
> RFC-AITP-0001 §5.4.5).
>
> Several things did change, and an implementation carrying rc.3-era
> code must act on all of them:
>
> - the `version` literal (`aitp/0.1` → `aitp/0.2`);
> - the **algorithm-tagged grammars** for `issuer` and `signature`
>   (RFC-AITP-0001 §5.4.3) — `issuer` now also accepts the
>   `aid:pubkey:ed25519:` and `aid:pubkey:p256:` forms, `signature` now
>   also accepts an `ed25519.` / `p256.` tag prefix, and verification of
>   **both** Ed25519 and P-256 is mandatory in v0.2;
> - **the signing input**. rc.3 signed the wrapped
>   `{"revocation_list": …}` form; v0.2 signs the inner
>   `revocation_list` body (see the `signature` row in the field table
>   below).
>
> Do not read "the profile is unchanged" as "there is nothing to
> migrate" — the serialization is unchanged, the grammar is wider, and
> the bytes an issuer signs are different.

```json
{
  "revocation_list": {
    "version":    "aitp/0.2",
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
| `version` | REQUIRED | MUST be `"aitp/0.2"`. |
| `issuer` | REQUIRED | The issuing peer's AID. MUST equal the `iss` claim of every TCT covered by the entries. (The snapshot keeps its JCS-profile field name `issuer`; only the JWS-profile artifacts use the registered claim names.) |
| `published_at` | REQUIRED | Unix timestamp when this list snapshot was signed. |
| `expires_at` | REQUIRED | Unix timestamp after which this snapshot MUST NOT be cached. |
| `entries` | REQUIRED | Array of revoked-entry records (may be empty). |
| `signature` | REQUIRED | base64url signature over canonical `revocation_list` JSON (excluding `signature`), signed by the issuing peer's private key. Canonical JSON MUST be produced per [RFC 8785 (JCS)](https://datatracker.ietf.org/doc/html/rfc8785); see [RFC-AITP-0001 §5.4](RFC-AITP-0001-core.md#54-signature). The signing input is the **inner** `revocation_list` body — the `{"revocation_list": {...}, "signature": "..."}` envelope is the wire / HTTP transport shape, NOT part of the canonical signing bytes. (This matches the RFC-AITP-0010 session-bundle and RFC-AITP-0011 multi-hop conventions: the wrapper key names the artifact for transport routing but the issuer signs the inner body.) A worked example (`kat-revocation-001`) lives at [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json). Its `object` is **the signing input defined above** — the inner `revocation_list` body — as its `signing_input: "body"` field records; implementations MUST reproduce its canonical bytes and digest byte-for-byte, and MUST use that same input when they sign. A real signed snapshot is pinned at [`known-answer/signed-examples/revocation/`](../schemas/conformance/known-answer/signed-examples/revocation/); conformant implementations MUST verify it as committed, without re-minting. **Note for implementers holding an earlier copy:** through v0.2-draft both artifacts pinned the *wrapped* form, contradicting this row; they were corrected to the inner body (see `CHANGELOG.md`, which carries the old and new digests). Implementations migrating from rc.3-era code (which signed the wrapped form) MAY accept either canonical shape during a transition window but MUST emit the inner form going forward. |

**Verification.** A consuming peer MUST verify the signature against the issuing peer's public key (resolved from the issuing peer's Manifest, RFC-AITP-0003). A snapshot whose `expires_at` is in the past, or whose signature does not validate, MUST be discarded; the peer SHOULD treat the absence of a fresh snapshot per its configured `revocation_policy.mode` (§3).

**Empty lists are signed.** Even when an issuing peer has revoked nothing, it MUST publish a signed snapshot with an empty `entries` array. This prevents a network attacker from suppressing a fresh signed list and serving an older one with revocations stripped.

> **Why the signature sits outside the body — what the rule produces, not an exception to it.** Per [RFC-AITP-0001 §5.4.1](RFC-AITP-0001-core.md#541-signing-input-jcs-profile), a *point-to-point* artifact — pulled by the verifier directly from the issuing peer and never passed on — MAY carry `signature` as a sibling of the wrapper instead of a member of the body. The revocation snapshot is point-to-point: a consuming peer polls it directly from the issuing peer's `ListRevoked` endpoint (§1.4) and never redistributes it onward. The consuming peer's own caching and staleness bound (§3.2) govern how long that peer holds the snapshot, not who hands it to whom, and per §5.4.1 do not make the snapshot redistributable. **The sibling placement here is deliberate, derived from the rule for this artifact's own redistribution path — not an exception to the rule — and MUST NOT be "corrected" to a member placement.**

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

> **Related conditional check.** The Manifest-expiry bound on the TCT itself
> ([RFC-AITP-0005 §10.4](RFC-AITP-0005-tct.md#104-manifest-expiry-bound-conditional))
> uses the issuer's Manifest `expires_at`, not the revocation snapshot's
> `expires_at`. The two policies are independent: a TCT may be revoked
> before its Manifest expires (deny-list hit; `TCT_REVOKED`), or its
> Manifest may expire before the TCT does (`TCT_EXPIRES_AFTER_MANIFEST`
> when the check is performed and applicable). Implementations MUST NOT
> conflate the two — both checks can fire for the same TCT.

### 3.3 Revocation lookup ordering

Implementations MUST complete the TCT's compact-JWS verification —
strict parse, `typ` enforcement, AID-pinned `alg`, signature, issuer key
binding, audience, and `exp` (RFC-AITP-0005 §7.2 steps 1–5) — **before**
consulting any network revocation source. The TCT claims `iss` and `jti`
are used as lookup keys for the deny list; verifying the signature first
ensures these claims are authenticated and cannot be forged by an
attacker to trigger attacker-chosen network fetches.

This ordering applies uniformly to the compact-JWS artifacts. When
verifying a delegation token, **every** signature check — the outer
delegation JWS *and* the embedded grant voucher JWS — MUST complete
before the revocation lookup on `voucher.src_jti` (RFC-AITP-0006 §4,
where the lookup is deliberately step 7). `voucher.src_jti` is
attacker-controlled bytes until both signatures have verified, exactly
as `iss` and `jti` are for a bare TCT.

A purely local, side-effect-free revocation check (e.g. an in-memory
deny list with no network I/O, no DNS resolution, and no cache write)
MAY run before signature verification, since it cannot be exploited for
DoS amplification or cache pollution. **All network-adjacent revocation
lookups** — HTTP fetches of `ListRevoked`, DNS resolution of issuer
endpoints, writes to a shared revocation cache — MUST be deferred until
after signature verification.

**Security rationale.** The TCT's `iss` and `jti` claims are
attacker-controlled bytes until the JWS signature is verified. An
implementation that routes revocation lookups via the `iss` claim before
signature verification enables:

- **Network amplification DoS.** The attacker sets `iss` to any AID,
  forcing the verifier to make an HTTP fetch to that AID's revocation
  endpoint. The fetch is attacker-triggered but originates from the
  verifier, so the verifier becomes a reflector against arbitrary AIDs.
- **Cache pollution.** Attacker-chosen `jti` values, paired with
  attacker-chosen `iss` values, can be inserted into the verifier's
  revocation cache for AIDs the attacker does not control.
- **Telemetry manipulation.** Revocation-hit metrics (counters,
  per-issuer lookup rates, last-fetched timestamps) become manipulable
  by an off-path attacker who can submit unverified TCTs.
- **Side-channel disclosure.** Which AIDs the verifier is willing to
  contact for revocation lookup leaks via outbound DNS / HTTP traffic.

A purely local, in-memory deny-list check (no network I/O, no DNS
resolution, no cache writes derived from issuer-provided input) is
exempt from this ordering requirement — it cannot be exploited for
amplification, pollution, or telemetry manipulation. All other checks —
HTTPS fetches of `ListRevoked`, DNS resolution of issuer endpoints,
writes to a shared revocation cache, external calls keyed off the `iss`,
`jti`, or `voucher.src_jti` claims — MUST wait until after `verify_tct`
returns success.

Anchoring revocation lookup to a *verified* `iss` and `jti` removes
all four attack surfaces.

The `rev-004` conformance fixture pins this ordering: the runner
instruments the revocation source and asserts it was NOT called when
the TCT signature is invalid (`side_effects.revocation_lookup_called:
false`). An implementation that fetches `ListRevoked` before signature
verification fails the fixture even if it ultimately returns the
correct `TCT_SIGNATURE_INVALID` error code.

---

## 4. Session Revocation

For long-running peer interactions, the issuing peer MAY signal revocation by adding the TCT's `jti` to its deny list. Consuming peers SHOULD periodically re-verify TCTs for long-lived sessions.

Re-verification interval: RECOMMENDED every 5 minutes for sessions lasting more than 1 hour.

### 4.1 Session invalidation model (v0.2)

In v0.2, "session invalidation" — terminating every active interaction with a specific subject peer — is achieved by revoking every TCT the issuer has ever issued to that subject. There is no separate session-level revocation surface. The deny list (§1) is the single source of truth; the `src_jti` linkage (§1.1) means the same revocations also invalidate the subject's vouchers and any delegations built on them.

An issuer wishing to terminate all active sessions with peer B MUST:

1. Add every TCT JTI ever issued to B (within their unexpired window) to its deny list.
2. Publish a new signed revocation snapshot (§1.5) reflecting the additions. Empty-snapshot signing rules apply if the issuer had nothing else revoked.
3. OPTIONALLY publish a short-TTL Manifest ([RFC-AITP-0003 §8](RFC-AITP-0003-manifest.md#8-manifest-rotation)) to accelerate consuming peers' cache expiry — useful when revocations propagate slower than the issuer wants.

A "session-level revoke-all" API (one operation that covers a subject without enumerating individual JTIs) is reserved for a future RFC. v0.2 implementations SHOULD surface per-JTI revocation as the primary admin API; bulk-revocation-by-subject is a quality-of-life concern, not a protocol requirement.

**Limitation (issuer JTI history).** An issuer that does not maintain a complete history of issued JTIs cannot guarantee total session revocation — it can only revoke the JTIs it remembers. Issuers SHOULD persist issued JTIs at least until `max(issued_tct.exp)` for the relevant subject so the bulk-revocation operation above is complete. After that point all unrevoked TCTs are guaranteed expired, so the JTI is no longer needed for session-revocation completeness; it MAY be garbage-collected from the issuer-side history table.

This is an **issuer-side persistence** requirement and is not visible on the wire. It is a SHOULD (not a MUST) because the deficiency manifests as an *issuer's inability to enumerate its own subject TCTs* rather than as a protocol-level error a peer can observe; an issuer that fails to enumerate is silently providing weaker session-revocation guarantees than its consuming peers will assume. See [§1.3](#13-persistence) for the related deny-list persistence guidance — the deny list and the issued-JTI history are two distinct issuer-side structures with the same persistence motivation.

---

## 5. Security Considerations

- The issuing peer's `ListRevoked` endpoint is itself a trust surface; it MUST be served over HTTPS, and its responses SHOULD be signed by the issuing peer.
- `fail_open` trades security for availability and MUST NOT be the default for high-value operations.
- Clock skew between the issuing peer and consuming peers reduces effective revocation latency. Implementations SHOULD use a monotonic clock when comparing `revoked_at`.
- A compromised peer can stop honoring its own revocations. Defense in depth: high-value operations SHOULD use short TTLs (RFC-AITP-0005 §9.1) so that revocation latency is bounded by the TCT lifetime.

---

## 6. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0005 TCT](RFC-AITP-0005-tct.md)
- [RFC-AITP-0007 Key Resolution](RFC-AITP-0007-key-resolution.md)
