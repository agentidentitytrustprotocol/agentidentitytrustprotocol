# Initial Peer Discovery

This document is **non-normative**. AITP does not define how Agent A first learns Agent B's hostname or AID. The protocol begins at the Agent Manifest (RFC-AITP-0003); everything before that is operational ([RFC-AITP-0003 §12](../rfcs/RFC-AITP-0003-manifest.md#12-non-goals): a directory service "MAY be built on top of Manifests by the ecosystem").

This document lists the patterns we have seen work, and a single recommendation: **whatever you choose, the Manifest is the trust root once found.** Initial discovery may be untrusted; the cryptographic verification starts the moment a Manifest is fetched.

---

## What "discovery" means here

Two distinct questions are often conflated:

1. **Bootstrap discovery** — how does A learn that "Agent B" exists at `https://b.example.com`?
2. **Peer authentication** — how does A know the entity at `https://b.example.com/.well-known/aitp-manifest` is the agent A intended to talk to?

**AITP only answers (2)** — through the Manifest signature, the embedded `aid`, and the proof-of-possession over a publish-time challenge. (1) is left to deployment. The patterns below are how implementations have addressed (1).

---

## Pattern 1: Out-of-band configuration (recommended starting point)

The simplest, most secure pattern for closed deployments.

```yaml
peers:
  worker-7:
    manifest_url: https://worker-7.agents.example.com/.well-known/aitp-manifest
    expected_aid: aid:pubkey:ed25519:O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik
  coordinator-1:
    manifest_url: https://coordinator.agents.example.com/.well-known/aitp-manifest
    expected_aid: aid:pubkey:ed25519:A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg
```

**Trust posture.** An operator-curated allowlist. The `expected_aid` field is a deployment convention, not a protocol field; it is optional but recommended — it lets A reject a Manifest that has been served from the right hostname but with the wrong key (key-substitution under a compromised host).

**AID forms.** The example uses the algorithm-tagged form (`aid:pubkey:ed25519:…` or `aid:pubkey:p256:…`), which new v0.2 AIDs SHOULD use. The legacy untagged form `aid:pubkey:<43 chars>` (the v0.1 grammar) remains valid indefinitely and means Ed25519; it is "canonically equivalent to `aid:pubkey:ed25519:<same-identifier>` for trust decisions" but not byte-equal, so compare `expected_aid` by key and algorithm rather than as a raw string ([RFC-AITP-0001 §5.3](../rfcs/RFC-AITP-0001-core.md#53-agent-id-aid)).

**When to use.** Small ecosystems, regulated environments, anything where peers are explicitly partnered.

**Trade-offs.** Doesn't scale; every new peer requires configuration on every existing peer.

---

## Pattern 2: DNS SRV record

The standard internet-protocol pattern. An organization publishes:

```
_aitp._tcp.example.com.   3600   IN   SRV   10 5 443 worker-7.agents.example.com.
```

A then fetches `https://worker-7.agents.example.com/.well-known/aitp-manifest`. (The `_aitp._tcp` label is a deployment convention; AITP does not register it.)

**Trust posture.** DNS resolution itself is not authenticated unless DNSSEC is in use. **The Manifest's signature and PoP are the actual trust anchors** — DNS just gets you to a hostname. An attacker who can spoof DNS still cannot forge a valid Manifest signature without the agent's private key. TLS-certificate validation is mandatory and pinning is RECOMMENDED for production ([RFC-AITP-0003 §11.2](../rfcs/RFC-AITP-0003-manifest.md#112-dns-and-tls-dependency)).

**When to use.** Public agent ecosystems where organizations publish their own agents; cross-organization interop.

**Trade-offs.** Requires DNS access. SRV records have spotty client-library support. Scales linearly.

---

## Pattern 3: Service registry / catalog

A directory service maintained by the ecosystem (or by an organization for its own agents). A queries the registry for "agents offering capability X" and gets back a list of `(aid, manifest_url)` pairs.

**Trust posture.** The registry is **not part of the trust path**. A treats every registry entry as untrusted until it has fetched and verified the corresponding Manifest. A compromised registry can introduce or hide agents but cannot impersonate one.

**When to use.** Larger ecosystems, capability-based routing, marketplaces.

**Trade-offs.** The registry itself is operational complexity. It needs its own auth and consistency story.

**An existing implementation.** The `aitp-control-plane` repository ships an API-only registry of this kind (with audit, revocation-list and webhook services) that sits outside the trust path; see its [registry API](https://github.com/agentidentitytrustprotocol/aitp-control-plane/blob/main/docs/api.md#registry).

---

## What does not change across patterns

In all three patterns, the moment A has a candidate `manifest_url`, the AITP normative flow takes over. Perform every step, in order, and stop at the first failure. Steps 3–8 are [RFC-AITP-0003 §5](../rfcs/RFC-AITP-0003-manifest.md#5-manifest-verification) steps 1–6; error codes are from [RFC-AITP-0003 §10](../rfcs/RFC-AITP-0003-manifest.md#10-error-codes), plus the structural-rejection codes (`MANIFEST_INVALID`, `UNKNOWN_FIELD`) in [`registries/error-codes.md`](../registries/error-codes.md#structural-rejection).

1. **Fetch** the Manifest over HTTPS, validating the TLS certificate. Plain HTTP MUST be rejected. A non-2xx response, unreachable host, DNS or TLS failure means the Manifest could not be retrieved ⇒ `MANIFEST_NOT_FOUND` (retryable; [RFC-AITP-0003 §4.1](../rfcs/RFC-AITP-0003-manifest.md#41-http-requirements)).
2. **Unwrap.** The well-known endpoint returns `{"manifest": {…}}`; that wrapper is "the HTTP/transport envelope only". Verify the inner object ([RFC-AITP-0003 §6.1](../rfcs/RFC-AITP-0003-manifest.md#61-what-is-signed)).
3. **Version check** — `manifest.version` MUST be `"aitp/0.2"` (or a later version this implementation supports) ⇒ else `MANIFEST_VERSION_UNKNOWN`.
4. **Structural check** — the Manifest MUST validate against [`aitp-manifest.schema.json`](../schemas/json/aitp-manifest.schema.json) ⇒ else `MANIFEST_INVALID`. Then the member-set check: any member outside the §3 fields and outside `extensions` ⇒ `UNKNOWN_FIELD`; unknown keys *inside* `extensions` are ignored. Both run before any cryptography.
5. **Expiry check** — `manifest.expires_at` MUST be in the future ⇒ else `MANIFEST_EXPIRED`.
6. **Proof-of-possession** — verify `proof_of_possession.signature` against the public key in `manifest.aid` ⇒ else `MANIFEST_POP_FAILED`. The signing input is `sha256(base64url_decode(challenge))` — the decoded raw bytes, not the ASCII string ([RFC-AITP-0001 §5.4.2](../rfcs/RFC-AITP-0001-core.md#542-pop-signing-input-convention)). Getting this wrong is the "Manifest PoP Bypass" threat of [RFC-AITP-0009 §1.11](../rfcs/RFC-AITP-0009-security.md#111-manifest-pop-bypass).
7. **Manifest signature** — verify `manifest.signature` against the same key over the canonical inner body without `signature` ⇒ else `MANIFEST_SIGNATURE_INVALID`.
8. **Identity-type / trust-anchor compatibility** — screen the published Manifest against the fetching peer's own identity, before initiating the handshake. If the fetcher's identity is `oidc`, the Manifest's `accepted_trust_anchors` MUST contain an issuer in the fetcher's own `trust_anchors` ⇒ else `INCOMPATIBLE_TRUST_ANCHORS`. If the fetcher's identity is `pinned_key` (or any non-OIDC type), the Manifest's `accepted_identity_types` (default `["oidc"]` when absent) MUST include the fetcher's type ⇒ else `INCOMPATIBLE_IDENTITY_TYPE`. The two codes are distinct and not interchangeable.

Manifest verification does NOT include identity-proof verification. The Manifest carries `identity_hint` — static metadata declaring which identity provider the agent uses — not a verifiable JWT. Fresh identity proof is exchanged inline during the Mutual Handshake ([RFC-AITP-0004 §5.1](../rfcs/RFC-AITP-0004-mutual-handshake.md#51-on-receiving-mutual_hello-b-verifies-a) step 6).

If any step fails, the candidate is rejected — regardless of how it was discovered. **Cryptographic verification is the trust boundary.**

---

## A recommendation

Pick **one** discovery pattern per deployment and stick with it. Mixing patterns inside a single agent ecosystem leads to inconsistent operational posture (some peers have AID pinning, others don't; some go through DNSSEC, others don't). Consistency at the deployment layer makes incident response tractable.

For new deployments without an existing directory, start with Pattern 1 (out-of-band configuration). Move to Pattern 2 or 3 only when the operational cost of Pattern 1 exceeds the implementation cost of the alternative.

---

## See also

- [RFC-AITP-0003 Agent Manifest](../rfcs/RFC-AITP-0003-manifest.md) — what discovery hands you off to.
- [RFC-AITP-0007 Key Resolution](../rfcs/RFC-AITP-0007-key-resolution.md) — Manifest caching and refresh.
- [RFC-AITP-0009 Security](../rfcs/RFC-AITP-0009-security.md) — RFC-AITP-0009 §1.3 (Manifest tampering), RFC-AITP-0009 §1.4 (Manifest replay across agents), RFC-AITP-0009 §1.11 (Manifest PoP bypass).
- [ecosystem.md](ecosystem.md) — implementations, SDKs and the control-plane registry.
