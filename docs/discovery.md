# Initial Peer Discovery

This document is **non-normative**. AITP does not define how Agent A first learns Agent B's hostname or AID. The protocol begins at the Agent Manifest (RFC-AITP-0003); everything before that is operational.

This document lists the patterns we have seen work, and a single recommendation: **whatever you choose, the Manifest is the trust root once found.** Initial discovery may be untrusted; the cryptographic verification starts the moment a Manifest is fetched.

---

## What "discovery" means here

Two distinct questions are often conflated:

1. **Bootstrap discovery** — how does A learn that "Agent B" exists at `https://b.example.com`?
2. **Peer authentication** — how does A know the entity at `https://b.example.com/.well-known/aitp-manifest` is the agent A intended to talk to?

**AITP only answers (2)** — through the Manifest signature, the embedded `aid`, and the proof-of-possession over a publish-time challenge. (1) is left to deployment. The patterns below are how implementations have addressed (1).

---

## Pattern 1: Out-of-band configuration (RECOMMENDED for v0.1)

The simplest, most secure pattern for closed deployments.

```yaml
peers:
  worker-7:
    manifest_url: https://worker-7.agents.example.com/.well-known/aitp-manifest
    expected_aid: aid:pubkey:MCowBQYDK2VdAyEA_workerExamplePub
  coordinator-1:
    manifest_url: https://coordinator.agents.example.com/.well-known/aitp-manifest
    expected_aid: aid:pubkey:MCowBQYDK2VdAyEA_coordExamplePub
```

**Trust posture.** A operator-curated allowlist. The `expected_aid` field is optional but RECOMMENDED — it lets A reject a Manifest that has been served from the right hostname but with the wrong key (key-substitution under a compromised host).

**When to use.** Small ecosystems, regulated environments, anything where peers are explicitly partnered.

**Trade-offs.** Doesn't scale; every new peer requires configuration on every existing peer.

---

## Pattern 2: DNS SRV record

The standard internet-protocol pattern. An organization publishes:

```
_aitp._tcp.example.com.   3600   IN   SRV   10 5 443 worker-7.agents.example.com.
```

A then fetches `https://worker-7.agents.example.com/.well-known/aitp-manifest`.

**Trust posture.** DNS resolution itself is not authenticated unless DNSSEC is in use. **The Manifest's signature and PoP are the actual trust anchors** — DNS just gets you to a hostname. An attacker who can spoof DNS still cannot forge a valid Manifest signature without the agent's private key.

**When to use.** Public agent ecosystems where organizations publish their own agents; cross-organization interop.

**Trade-offs.** Requires DNS access. SRV records have spotty client-library support. Scales linearly.

---

## Pattern 3: Service registry / catalog

A directory service maintained by the ecosystem (or by an organization for its own agents). A queries the registry for "agents offering capability X" and gets back a list of `(aid, manifest_url)` pairs.

**Trust posture.** The registry is **not part of the trust path**. A treats every registry entry as untrusted until it has fetched and verified the corresponding Manifest. A compromised registry can introduce or hide agents but cannot impersonate one.

**When to use.** Larger ecosystems, capability-based routing, marketplaces.

**Trade-offs.** The registry itself is operational complexity. It needs its own auth and consistency story.

---

## What does not change across patterns

In all three patterns, the moment A has a candidate `manifest_url`, the AITP normative flow takes over (RFC-AITP-0003 §5):

1. Fetch the Manifest over HTTPS (validate the TLS certificate).
2. Verify `manifest.signature` against the public key in `manifest.aid`.
3. Verify `proof_of_possession.signature` against the same key.
4. Verify `manifest.identity` per RFC-AITP-0002.
5. Check `manifest.expires_at` is in the future.
6. Check trust-anchor compatibility before initiating a handshake.

If any of these fail, the candidate is rejected — regardless of how it was discovered. **Cryptographic verification is the trust boundary.**

---

## A recommendation

Pick **one** discovery pattern per deployment and stick with it. Mixing patterns inside a single agent ecosystem leads to inconsistent operational posture (some peers have AID pinning, others don't; some go through DNSSEC, others don't). Consistency at the deployment layer makes incident response tractable.

For new deployments without an existing directory, start with Pattern 1 (out-of-band configuration). Move to Pattern 2 or 3 only when the operational cost of Pattern 1 exceeds the implementation cost of the alternative.

---

## See also

- [RFC-AITP-0003 Agent Manifest](../rfcs/RFC-AITP-0003-manifest.md) — what discovery hands you off to.
- [RFC-AITP-0007 Key Resolution](../rfcs/RFC-AITP-0007-key-resolution.md) — Manifest caching and refresh.
- [RFC-AITP-0009 Security](../rfcs/RFC-AITP-0009-security.md) §1.3 (Manifest tampering), §1.4 (Manifest replay).
