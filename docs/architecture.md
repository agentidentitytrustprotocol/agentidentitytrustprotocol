# AITP Architecture

This document is non-normative. It explains the problem AITP solves, the
shape of the protocol, and how the pieces fit together so an implementer
can build a peer agent without re-reading every RFC. It describes the
current protocol revision, **`aitp/0.2`**. The authoritative documents are
the RFCs in [`rfcs/`](../rfcs/README.md); where this page and an RFC
disagree, the RFC wins. For where implementation, deployment and tooling
docs live, see [ecosystem.md](ecosystem.md).

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
TCTs from peers, and maintains a JTI deny list for the TCTs it issued
([RFC-AITP-0001 §4](../rfcs/RFC-AITP-0001-core.md#4-architecture)).

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
   │   round 2: TCTs (+ optional    │
   │            grant vouchers)     │
   │            + PoP               │
   │                                │
   │  A holds TCT_A (B → A)         │
   │  B holds TCT_B (A → B)         │
```

A TCT is a signed, audience-bound, capability-scoped grant, serialized as a
compact JWS with `typ` `aitp-tct+jwt`
([RFC-AITP-0005 §1](../rfcs/RFC-AITP-0005-tct.md#1-serialization)). The
issuer (`iss`) is the peer that produced it; the audience (`aud`) is the
peer it was produced for, and `aud` MUST equal `sub`
([RFC-AITP-0005 §2](../rfcs/RFC-AITP-0005-tct.md#2-claims)). The signature
is verified locally against the issuer's Manifest key — there is no
third-party lookup.

### 2.1 Two signing profiles

AITP v0.2 signs its artifacts in one of two ways
([RFC-AITP-0001 §5.4](../rfcs/RFC-AITP-0001-core.md#54-signature)):

| Profile | Artifacts |
|---|---|
| **JCS embedded-signature profile** — signature is a field of the JSON object, computed over its RFC 8785 canonical form | envelopes, Agent Manifests, revocation snapshots, session trust bundles, handshake payloads |
| **Compact JWS profile** — the artifact *is* an RFC 7515 compact JWS; the signature covers the exact transmitted bytes | TCT, grant voucher, delegation token |

The boundary rule, quoted: "Any artifact that crosses a trust boundary and
may be verified by non-AITP code MUST be a compact JWS with an explicit
`typ`." On the JWS artifacts the verifier enforces `typ` and derives the
sole acceptable `alg` from the signer's AID
([RFC-AITP-0001 §5.4.5](../rfcs/RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts)).
For the canonical-JSON details (wrapper stripping, signing input, known-answer
vectors) see the aitp-rs
[JCS notes](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/jcs.md).

Signatures under both profiles use Ed25519 or ECDSA P-256; a v0.2 peer MUST
be able to verify both
([RFC-AITP-0001 §5.4.3](../rfcs/RFC-AITP-0001-core.md#543-algorithm-tagged-signature-wire-format-jcs-profile-only) for the JCS profile; §5.4.5 for the compact JWS profile).
The algorithm is fixed by the AID (`aid:pubkey:ed25519:…` or
`aid:pubkey:p256:…`; the legacy untagged `aid:pubkey:<43 chars>` form —
the v0.1 grammar, still accepted — means Ed25519;
[RFC-AITP-0001 §5.3](../rfcs/RFC-AITP-0001-core.md#53-agent-id-aid)).

---

## 3. The flows

The diagrams below are shape only. For the exact bytes of every message in
a real handshake, see the aitp-rs
[handshake transcripts](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/handshake-transcripts.md).

### 3.1 Discovery

```
Peer A ──GET /.well-known/aitp-manifest──▶ Peer B
Peer A ◀── {"manifest": {…signed…}} ─────── Peer B
          (unwrap; version → structural/member-set → expiry
           → PoP → signature → identity-type / trust-anchor compatibility)
```

Used before any handshake. The Manifest is the trust root for the peer's
key. Verification order is fixed by
[RFC-AITP-0003 §5](../rfcs/RFC-AITP-0003-manifest.md#5-manifest-verification):
version, structural check (`MANIFEST_INVALID`, then the member-set check,
`UNKNOWN_FIELD`), expiry, proof-of-possession, signature, then
compatibility. Manifest verification does **not** include identity-proof
verification: the Manifest carries only a static `identity_hint`, and the
verifiable identity proof is exchanged in the handshake. See
[discovery.md](discovery.md) for the step-by-step list and bootstrap
patterns.

### 3.2 Mutual Handshake

```
Peer A ──MUTUAL_HELLO──▶ Peer B
Peer A ◀──MUTUAL_HELLO_ACK── Peer B   (round 1: identity proofs, inline Manifests,
                                       requested grants, PoP nonces)

Peer A ──MUTUAL_COMMIT──▶ Peer B
Peer A ◀──MUTUAL_COMMIT_ACK── Peer B  (round 2: TCT + optional grant_voucher
                                       + PoP signature)

Peer A holds TCT_A (signed by B).
Peer B holds TCT_B (signed by A).
```

Four messages, two round trips, symmetric output
([RFC-AITP-0004 §2](../rfcs/RFC-AITP-0004-mutual-handshake.md#2-protocol-overview)).
Each commit payload carries the TCT and, unless the issuer's policy forbids
the peer from delegating, a companion `grant_voucher`
([RFC-AITP-0004 §4.5](../rfcs/RFC-AITP-0004-mutual-handshake.md#45-grant-voucher-issuance)).
Both are embedded as opaque compact-JWS strings inside the JCS-signed
handshake payload. Issued grants are
`requested ∩ identity policy ∩ own offered_capabilities`; an empty
intersection means no TCT and `POLICY_VIOLATION`
([RFC-AITP-0004 §4.1](../rfcs/RFC-AITP-0004-mutual-handshake.md#41-grant-intersection)).

### 3.3 Delegation

```
A peer-issues TCT + grant voucher to B   (voucher.grants = TCT grants,
                                          voucher.src_jti = TCT jti)

B signs a delegation token (compact JWS, typ aitp-delegation+jwt) to C:
  iss = B, sub = C, aud = A, scope ⊆ voucher.grants,
  exp ≤ voucher.exp, cnf.jkt = C's key, voucher = A's voucher verbatim

C presents the delegation token to A.
A verifies the outer JWS, then its own voucher, voucher.sub == outer iss,
expiry monotonicity, scope ⊆ voucher.grants, src_jti not revoked,
iss ≠ sub, and C's PoP — then peer-issues a TCT to C.
```

This is the grant-voucher model of
[RFC-AITP-0006](../rfcs/RFC-AITP-0006-delegation.md): the voucher is an
independently signed JWS, so every signature is checked over transmitted
bytes and no step reconstructs any byte sequence. The full nine-step order
and its error codes are in
[RFC-AITP-0006 §4](../rfcs/RFC-AITP-0006-delegation.md#4-verification-rules);
the revocation lookup on `voucher.src_jti` (step 7) runs only after every
signature check
([RFC-AITP-0008 §3.3](../rfcs/RFC-AITP-0008-revocation.md#33-revocation-lookup-ordering)).
If the issuer declined to mint a voucher, the subject cannot delegate.

Core v0.2 is single-hop only: a core implementation MUST reject a
delegation token carrying a `chain` claim with
`DELEGATION_MULTIHOP_NOT_SUPPORTED`. Multi-hop chains are the opt-in
[RFC-AITP-0011](../rfcs/RFC-AITP-0011-multihop-delegation.md).

---

## 4. The transports

The canonical wire format is **JSON** (`schemas/json/`). JCS-profile
artifacts are signed over their RFC 8785 canonical JSON form; there is no
Protobuf, CBOR or other transport-specific signing input. JWS-profile
artifacts are signed over their transmitted bytes and travel as opaque
strings
([RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#541-signing-input-jcs-profile)).

| Transport | Use |
|---|---|
| HTTPS + JSON | Normative. Every conformant peer exposes the well-known Manifest endpoint and its `handshake_endpoint` over HTTPS ([RFC-AITP-0001 §8](../rfcs/RFC-AITP-0001-core.md#8-transport)). |
| Message bus / queue with the JSON envelope | Permitted; subject names are deployment-defined. |
| Other framings (binary RPC, CBOR, MessagePack) | Permitted as long as signing and verification use the canonical JSON form. Not part of v0.2 conformance ([RFC-AITP-0001 §10](../rfcs/RFC-AITP-0001-core.md#10-conformance)). |

---

## 5. Where state lives

| State | Owner | Storage / lifetime | Source |
|---|---|---|---|
| Trust anchors, pinned keys | Each peer | Local config (`static_config`, `well_known_endpoint`, or `out_of_band`). | [RFC-AITP-0002 §4](../rfcs/RFC-AITP-0002-identity.md#4-trust-anchors) |
| `message_id` deny list | Each peer (envelope ingress) | Retained ≥ timestamp tolerance (default 300 s). | [RFC-AITP-0001 §5.5](../rfcs/RFC-AITP-0001-core.md#55-replay-protection) |
| Outstanding PoP nonces | Each peer | Transient; until the echo is verified. Never persisted across restarts. | [RFC-AITP-0004 §7](../rfcs/RFC-AITP-0004-mutual-handshake.md#7-state-management) |
| Resolved peer Manifests | Each peer | Cache until `manifest.expires_at`; a newer inline Manifest wins. | [RFC-AITP-0007 §1](../rfcs/RFC-AITP-0007-key-resolution.md#1-peer-key-resolution) |
| Resolved identity-issuer keys | Each peer | TTL cache (default 3600 s). | [RFC-AITP-0007 §2.1](../rfcs/RFC-AITP-0007-key-resolution.md#21-cache) |
| Held peer TCTs and their grant vouchers | Each peer | Stored verbatim until TCT `exp` or revocation. | [RFC-AITP-0004 §7](../rfcs/RFC-AITP-0004-mutual-handshake.md#7-state-management) |
| TCT JTI deny list (TCTs it issued) | Each issuing peer | SHOULD persist across restarts; in-memory only is not for production. | [RFC-AITP-0008 §1.3](../rfcs/RFC-AITP-0008-revocation.md#13-persistence) |
| Issued-JTI history | Each issuing peer | SHOULD persist issued JTIs until `max(issued_tct.exp)` per subject, so revoke-all-for-a-subject is complete. | [RFC-AITP-0008 §4.1](../rfcs/RFC-AITP-0008-revocation.md#41-session-invalidation-model-v02) |
| Cached revocation snapshots (other issuers') | Each consuming peer | Bounded by `revocation_policy.max_staleness_secs` (schema default 300) and the snapshot's `expires_at`; past that, `revocation_policy.mode` applies. | [RFC-AITP-0008 §3.2](../rfcs/RFC-AITP-0008-revocation.md#32-staleness) |

The RFCs do not require issuers to retain the grant vouchers they mint: during
delegation verification the issuer checks its own past signature
([RFC-AITP-0006 §4](../rfcs/RFC-AITP-0006-delegation.md#4-verification-rules)
step 3). How to back this state in a real deployment (replay caches,
shared stores) is covered in the aitp-rs
[deployment guide](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/deployment.md).

---

## 6. The big invariant

> To check a TCT presented by a peer, an agent needs only: (a) the peer's
> Manifest public key, (b) its own AID, and (c) the current time. No
> third-party call, no central registry.
> — [RFC-AITP-0001 §4](../rfcs/RFC-AITP-0001-core.md#4-architecture)

That covers signature, expiry, audience, grant and PoP validation.
Revocation status is the one exception: it is pull-based and may require
consulting the issuing peer's deny list
([RFC-AITP-0008](../rfcs/RFC-AITP-0008-revocation.md)). If a peer needs
anything else to make the decision, the system is doing too much.

---

## 7. What each RFC adds

Status is the single lifecycle ladder in
[`governance/RFC-PROCESS.md`](../governance/RFC-PROCESS.md); the live table
is [`rfcs/README.md`](../rfcs/README.md).

**Core (Draft; v0.2 core conformance):**

| RFC | Role |
|---|---|
| **0001 Core** | Envelope, AID grammar, the two signing profiles, replay protection, compatibility model (`UNKNOWN_FIELD`), envelope-level error codes, conformance. |
| **0002 Identity** | How an AID is bound to an identity: the identity descriptor, `oidc` (JWT with `aud`, `nonce`, `cnf.jkt`) and `pinned_key`; trust anchors. |
| **0003 Manifest** | The signed self-description every agent publishes; the discovery layer and trust root for the peer's key. |
| **0004 Mutual Handshake** | Four-message peer authentication producing two TCTs and optional grant vouchers. |
| **0005 TCT** | The peer-issued capability grant (compact JWS) and its companion grant voucher. |
| **0006 Delegation** | Single-hop delegation: a delegation JWS embedding the issuer's grant voucher. |
| **0007 Key Resolution** | Manifest-first peer keys; cache → pinned → well-known for identity issuers; `key_resolution.fail_mode`. |
| **0008 Revocation** | Per-issuer JTI deny list, signed revocation snapshots, `revocation_policy`, lookup ordering. |
| **0009 Security** | A2A threat model (including algorithm and token-type confusion) and required defenses. |

**Opt-in (Draft; normative text published, NOT part of v0.2 core conformance):**

- **0010 Session Trust Bundle** — coordinator-mediated trust for N-agent sessions. Core runners SKIP the `bundle-*` fixtures.
- **0011 Multi-hop Delegation** — chains beyond a single hop. Core implementations reject `del-mh-*` tokens with `DELEGATION_MULTIHOP_NOT_SUPPORTED`
  ([RFC-AITP-0001 §10](../rfcs/RFC-AITP-0001-core.md#10-conformance)).

**Reserved** (a real document whose contents are non-normative for `aitp/0.2`):

- **0012 Extensions** — reserves `extensions.zk`, `extensions.tee` and the selective-disclosure `ext.sd_grant` key. It still constrains v0.2 peers: they MUST NOT make a trust decision based on that extension data
  ([RFC-AITP-0012 §5](../rfcs/RFC-AITP-0012-extensions.md#5-compatibility)).

**Planned** (stub document only):

- **0013 TCT Renewal Extension** — eventual standardization of the non-normative shortened renewal endpoint ([RFC-AITP-0004 §8.1](../rfcs/RFC-AITP-0004-mutual-handshake.md#81-non-normative-shortened-renewal-extension)).

Every error code lives in [`registries/error-codes.md`](../registries/error-codes.md);
its [structural-rejection table](../registries/error-codes.md#structural-rejection)
names the code each artifact uses when it does not match its schema.

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
- It does not issue identities. AITP is a trust evaluation layer; in v0.2 identity comes from OIDC or pinned keys. `did`, `x509` and `wallet` are reserved future identity types ([RFC-AITP-0002 §5](../rfcs/RFC-AITP-0002-identity.md#5-future-identity-types-v03)).
- It does not define a policy language. Each agent's local policy decides what to grant.
- It does not define what `grants` mean. That is the namespace owner's domain ([RFC-AITP-0005 §4.2.1](../rfcs/RFC-AITP-0005-tct.md#421-capability-ownership)).
- It does not define a service-consumer model. AITP v0.2 is strictly peer-to-peer.
- It does not define audit logging beyond requiring that authentication failures are logged with sufficient context for forensic analysis ([RFC-AITP-0009 §3](../rfcs/RFC-AITP-0009-security.md#3-implementation-security-requirements)).
- It does not specify how a peer's Manifest URL is discovered initially — that is operations (DNS, service discovery, configuration); see [discovery.md](discovery.md).

See [`docs/non-goals.md`](non-goals.md) for the full list and rationale.

---

## 10. Reading order for implementers

1. [RFC-AITP-0001 Core](../rfcs/RFC-AITP-0001-core.md) — envelope, AID, signing profiles, replay.
2. [RFC-AITP-0002 Identity](../rfcs/RFC-AITP-0002-identity.md) — identity binding.
3. [RFC-AITP-0003 Manifest](../rfcs/RFC-AITP-0003-manifest.md) — discovery + the trust root for peer keys.
4. [RFC-AITP-0004 Mutual Handshake](../rfcs/RFC-AITP-0004-mutual-handshake.md) — the protocol.
5. [RFC-AITP-0005 TCT](../rfcs/RFC-AITP-0005-tct.md) — the artifact and its grant voucher.
6. [RFC-AITP-0006 Delegation](../rfcs/RFC-AITP-0006-delegation.md) — single-hop.
7. [RFC-AITP-0007 Key Resolution](../rfcs/RFC-AITP-0007-key-resolution.md) — operational glue.
8. [RFC-AITP-0008 Revocation](../rfcs/RFC-AITP-0008-revocation.md) — JTI deny list.
9. [RFC-AITP-0009 Security](../rfcs/RFC-AITP-0009-security.md) — what you must enforce.

Then run the [conformance suite](../schemas/conformance/README.md); see the
aitp-rs [conformance guide](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/conformance.md)
for running it against an implementation.

---

## See also

- [`docs/ecosystem.md`](ecosystem.md) — which repository owns SDKs, verifier, control plane, playground.
- [`docs/integration-guide.md`](integration-guide.md) — consuming a peer-issued TCT.
- [`docs/threat-model.md`](threat-model.md) — distilled threat surface.
- [`docs/discovery.md`](discovery.md) — initial peer discovery patterns.
- [`docs/GLOSSARY.md`](GLOSSARY.md) — terminology quick reference.
