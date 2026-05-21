# AITP Architecture

This document is non-normative. It explains the problem AITP solves, the
shape of the protocol, and how the pieces fit together so an implementer
can build a peer agent without re-reading every RFC. The authoritative
documents are the RFCs in [`rfcs/`](../rfcs/).

---

## 1. The problem

Two autonomous agents need to coordinate. They are run by different teams,
authenticate against different identity providers, and have no shared
verifier between them. Before they can exchange any binding work, each one
needs to answer four questions:

1. **Who are you?**
2. **Who attests to you?**
3. **What may you do here, right now?**
4. **For how long?**

Existing tools answer some of these but none gives a single signed artifact
that answers all four for an agent-to-agent interaction:

| Tool | Identity | Capability | Portable | A2A native |
|---|---|---|---|---|
| Bearer tokens / API keys | No | Binary (valid/invalid) | No | No |
| mTLS | Connection-level only | No | No | No |
| OIDC | User-shaped | None | Partially | No |

**The result:** every agent framework invents its own auth system, and the
results don't compose across organizations.

---

## 2. The shape

AITP defines one role: **peer agent**. Every participant publishes a
Manifest, performs Mutual Handshakes, issues TCTs for peers, verifies
TCTs from peers, and maintains a JTI deny list for the TCTs it issued.

There is no Verifier role and no Consumer role. There is no service-
consumer profile. Every agent is symmetric.

```
Agent A                         Agent B
   │                                │
   │  fetch + verify B's Manifest   │
   │  (RFC-0003)                    │
   │                                │
   │  Mutual Handshake              │
   │  (RFC-0004)                    │
   │   round 1: identity + nonces   │
   │   round 2: TCTs + PoP          │
   │                                │
   │  A holds TCT_A (B → A)         │
   │  B holds TCT_B (A → B)         │
```

A TCT is a signed, audience-bound, capability-scoped grant. The issuer is
the peer that produced it. The audience is the peer it was produced for.
The signature is verified locally — there is no third-party lookup.

---

## 3. The flows

### 3.1 Discovery

```
Peer A ──GET /.well-known/aitp-manifest──▶ Peer B
Peer A ◀── signed Manifest ──────────────── Peer B
                            (verify signature, PoP, identity, trust anchors)
```

Used before any handshake. The Manifest is the trust root for the peer's key.

### 3.2 Mutual Handshake

```
Peer A ──MUTUAL_HELLO──▶ Peer B
Peer A ◀──MUTUAL_HELLO_ACK── Peer B   (round 1: credentials + nonces)

Peer A ──MUTUAL_COMMIT──▶ Peer B
Peer A ◀──MUTUAL_COMMIT_ACK── Peer B  (round 2: TCTs + PoP signatures)

Peer A holds TCT_A (signed by B).
Peer B holds TCT_B (signed by A).
```

Four messages, two round trips, symmetric output.

### 3.3 Delegation

```
A peer-issues TCT to B with grants ⊇ S.

B builds a DelegationToken to C with scope = S, plus the embedded
GrantProof signed by A.

C presents the DelegationToken to A.
A checks audience, signatures, scope ⊆ grant_proof.capabilities, and PoP,
then peer-issues a TCT to C.

C ── request + TCT ─▶ Peer that consumes the grants.
```

Single-hop only in v0.1. The grant proof embedded in the delegation token
is what makes A's verification stateless.

---

## 4. The transports

The canonical wire format is **JSON** (`schemas/json/`). All AITP signatures
are computed over RFC 8785 (JCS) canonical JSON; there is no separate
Protobuf signing input in v0.1 (RFC-AITP-0001 §5.4.1).

| Transport | Use |
|---|---|
| HTTPS + JSON | Normative. Every conformant peer exposes its handshake endpoint and the well-known Manifest endpoint over HTTPS carrying canonical JSON. |
| Message bus / queue with the JSON envelope | Permitted; subject names are deployment-defined. |
| Other framings (binary RPC, CBOR, MessagePack) | Permitted as long as the AITP envelope round-trips unchanged and signature verification uses the canonical JSON form (RFC-AITP-0001 §5.4.1). Not part of v0.1 conformance. |

Transport bindings other than HTTPS+JSON are not part of v0.1 conformance,
but are not prohibited as long as the canonical JCS signing input is
preserved.

---

## 5. Where state lives

| State | Owner | Storage |
|---|---|---|
| Trust anchors | Each peer | Static config or `well-known` issuer endpoint. |
| Pinned keys | Each peer | Static config. |
| `message_id` deny list | Each peer (per envelope ingress) | In-memory, retained ≥ timestamp tolerance. |
| Outstanding PoP nonces | Each peer | In-memory, retained ≥ timestamp tolerance. |
| TCT JTI deny list | Each issuing peer | Persistent. SHOULD survive restarts. |
| Resolved issuer keys | Each peer | TTL cache (default 3600 s). |
| Resolved peer Manifests | Each peer | TTL cache (`manifest.expires_at`). |
| Held peer TCTs | Each peer | Until `expires_at` or revocation. |

The TCT itself is *not* stored by the consuming peer beyond the validity
window. Each request re-presents it.

---

## 6. The big invariant

> A peer's authorization decision MUST be derivable from a single TCT, the
> issuing peer's public key (resolved from the issuing peer's Manifest), the
> consuming peer's own AID, and the current time.

If a peer needs anything else to make the decision, the system is doing too
much. AITP exists to keep that invariant true.

---

## 7. What each RFC adds

| RFC | Role |
|---|---|
| **0001 Core** | The shared envelope, replay protection, signatures, error codes. |
| **0002 Identity** | How an AID is bound to a verifiable claim (OIDC or pinned key). |
| **0003 Manifest** | The signed self-description every agent publishes. The discovery layer. |
| **0004 Mutual Handshake** | Four-message peer authentication producing two TCTs. |
| **0005 TCT** | The canonical peer-issued capability grant. |
| **0006 Delegation** | Single-hop delegation: A → B, then B → C, with A still in control. |
| **0007 Key Resolution** | Manifest-first peer keys; cache → pinned → well-known for issuers. |
| **0008 Revocation** | JTI deny list per issuing peer. Each agent revokes what it issued. |
| **0009 Security** | A2A threat model and required defenses. |

Post-v0.1 (Draft normative text published, NOT part of v0.1 conformance):

- **0010 Session Trust Bundle** — coordinator-mediated trust for N-agent sessions.
- **0011 Multi-hop Delegation** — chains beyond a single hop.

Reserved (numbering pinned, no normative text yet):

- **0012 Extensions** — `extensions.zk` and `extensions.tee` namespaces.

Planned (numbering pinned, stub document only):

- **0013 TCT Renewal Extension** — eventual standardization of the non-normative shortened renewal endpoint (RFC-AITP-0004 §8.1).

---

## 8. Design rationale: why four messages?

A two-message handshake (simultaneous exchange of credentials and TCTs)
would require each agent to issue a TCT before verifying the peer's
proof-of-possession. An attacker who intercepted one message could obtain
a TCT without ever proving key ownership.

The four-message design (RFC-AITP-0004) separates credential exchange
(round 1) from TCT delivery (round 2), so TCTs are only issued after PoP
is verified. The protocol pays one extra round trip to keep the trust
contract clean: no TCT is ever issued to a party that has not proven
possession of its claimed key.

---

## 9. What AITP does not do

- It does not authenticate the transport. Run AITP over TLS.
- It does not issue identities. AITP is a trust evaluation layer; identity comes from OIDC, DIDs, or pinned keys.
- It does not define a policy language. Each agent's local policy decides what to grant.
- It does not define what `grants` mean. That is the consuming peer's domain.
- It does not define a service-consumer model. AITP v0.1 is strictly peer-to-peer.
- It does not define audit logging beyond "log auth failures with enough context".
- It does not specify how a peer's Manifest URL is discovered initially — that is operations (DNS, service discovery, configuration).

See [`docs/non-goals.md`](non-goals.md) for the full list and rationale.

---

## 10. Reading order for implementers

1. [RFC-AITP-0001 Core](../rfcs/RFC-AITP-0001-core.md) — envelope, replay, signature.
2. [RFC-AITP-0002 Identity](../rfcs/RFC-AITP-0002-identity.md) — identity binding.
3. [RFC-AITP-0003 Manifest](../rfcs/RFC-AITP-0003-manifest.md) — discovery + the trust root for peer keys.
4. [RFC-AITP-0004 Mutual Handshake](../rfcs/RFC-AITP-0004-mutual-handshake.md) — the protocol.
5. [RFC-AITP-0005 TCT](../rfcs/RFC-AITP-0005-tct.md) — the artifact.
6. [RFC-AITP-0006 Delegation](../rfcs/RFC-AITP-0006-delegation.md) — single-hop.
7. [RFC-AITP-0007 Key Resolution](../rfcs/RFC-AITP-0007-key-resolution.md) — operational glue.
8. [RFC-AITP-0008 Revocation](../rfcs/RFC-AITP-0008-revocation.md) — JTI deny list.
9. [RFC-AITP-0009 Security](../rfcs/RFC-AITP-0009-security.md) — what you must enforce.

---

## See also

- [`docs/integration-guide.md`](integration-guide.md) — consuming a peer-issued TCT.
- [`docs/threat-model.md`](threat-model.md) — distilled v0.1 threat surface.
- [`docs/discovery.md`](discovery.md) — initial peer discovery patterns.
- [`docs/GLOSSARY.md`](GLOSSARY.md) — terminology quick reference.
