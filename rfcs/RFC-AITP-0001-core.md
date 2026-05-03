# RFC-AITP-0001
# Agent Identity & Trust Protocol (AITP) — Core

**Document:** RFC-AITP-0001
**Version:** 0.1.0-draft
**Status:** Community Standards Track (Draft)
**Canonical wire format:** JSON
**Normative transport:** HTTPS (any HTTP/1.1+ runtime)
**Canonical signing input:** RFC 8785 (JCS) canonical JSON
**Intended status:** Stable Core

> This is an RFC-style open standard. It is not an IETF RFC.

---

## Abstract

The Agent Identity & Trust Protocol (AITP) is an **agent-to-agent (A2A)** trust protocol. Its purpose is to let two autonomous agents — running in different organizations, behind different identity providers, with no pre-configured shared verifier — establish bidirectional trust before they exchange any binding work.

AITP introduces one strict invariant:

> **Trust between two agents MUST be expressed as a pair of signed, audience-bound, capability-scoped Trust Context Tokens (TCTs) produced by a Mutual Handshake.**

There is no central verifier. Each agent is its own verifier for the peer it is authenticating. The output of the handshake is a TCT each peer holds about the other. A TCT is verified locally — its signature is checked against the issuing peer's public key, resolved from the peer's signed Agent Manifest.

AITP Core does not define decision theory, reputation models, identity issuance, authorization semantics inside a peer, or domain logic. AITP Core defines structure: the message envelope, replay protection, signature semantics, message types, transport requirements, canonical JSON mapping, error codes, and the registry hooks the rest of the spec depends on.

---

## 1. Status of This Memo

This document is Draft Standards Track. Implementations MAY adopt it experimentally. Backward-incompatible changes remain possible until Final status.

This is the **first published version** of AITP. The numbering scheme treats `aitp/0.1` as the inaugural A2A protocol.

---

## 2. Conventions and Terminology

The key words **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**, **SHOULD**, **SHOULD NOT**, **RECOMMENDED**, **MAY**, and **OPTIONAL** in this document are to be interpreted as described in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119).

| Term | Definition |
|---|---|
| **Agent** | Any software entity that emits or receives AITP envelopes. Every AITP agent has an AID and publishes an Agent Manifest. |
| **AID** | Agent ID — a cryptographic identifier of the form `aid:<method>:<identifier>`. |
| **Peer** | The other agent in a bilateral AITP exchange. Roles are symmetric. |
| **Initiating Peer / Target Peer** | Role labels for one round of the Mutual Handshake. The initiator sends `mutual_hello`; the target responds. Either peer may initiate. |
| **Issuing Peer** | The peer that signed a particular TCT. Equivalent to the TCT `issuer` AID. |
| **Subject Peer** | The peer the TCT was issued for. Equivalent to the TCT `subject` and `audience` AIDs. |
| **TCT** | Trust Context Token — the signed output of a Mutual Handshake. Each side of a successful handshake holds a TCT issued by the other. |
| **Trust Anchor** | A locally configured trusted issuer (e.g. an OIDC provider) and its public keys, used to verify a peer's identity binding. |
| **Identity Binding** | A verifiable claim binding an AID to a trusted issuer's subject. See RFC-AITP-0002. |
| **Manifest** | An agent's signed self-description. Defined in RFC-AITP-0003. |

---

## 3. Scope and Design Goals

AITP exists to make A2A trust establishment **explicit, auditable, and stateless on the consumer side**. It provides:

1. an explicit, signed message envelope with replay protection;
2. a pluggable identity-binding model (RFC-AITP-0002);
3. a signed Agent Manifest for peer discovery (RFC-AITP-0003);
4. a Mutual Handshake that produces peer-issued TCTs (RFC-AITP-0004);
5. an audience-bound, capability-scoped Trust Context Token (RFC-AITP-0005);
6. a stateless single-hop delegation model (RFC-AITP-0006);
7. transport independence through a canonical envelope;
8. a defined error and revocation surface;
9. registry hooks for identity types, capabilities, and error codes.

AITP does **not** define:

- identity issuance — that lives in OIDC providers, DID methods, etc.;
- reputation algorithms;
- authorization semantics inside a peer (what the peer does with `grants`);
- a third-party verifier or trust authority;
- audit-logging requirements;
- service-consumer flows. AITP is peer-to-peer.

---

## 4. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Agent A                             │
│   (identity, AID, signed Manifest, accepted anchors)    │
└──────────────────────────┬──────────────────────────────┘
                           │
              Mutual Handshake (RFC-0004)
                           │
                          ▼ ▲
                          ▲ ▼
                           │
                  TCT_B (A → B)   TCT_A (B → A)
                           │
┌──────────────────────────┴──────────────────────────────┐
│                     Agent B                             │
│   (identity, AID, signed Manifest, accepted anchors)    │
└─────────────────────────────────────────────────────────┘
```

Each agent's responsibilities are symmetric:

- Publish a signed Manifest at `/.well-known/aitp-manifest`.
- Verify peers' Manifests, identity proofs, and proof-of-possession.
- Issue a peer-issued TCT for the peer when policy allows.
- Verify the peer's TCT against the peer's Manifest public key.
- Maintain a local JTI deny list for TCTs it has issued.
- Honor its own `offered_capabilities` when granting; honor its own `required_peer_capabilities` when accepting.

Trust verification is **stateless and local**. To check a TCT presented by a peer, an agent needs only: (a) the peer's Manifest public key, (b) its own AID, and (c) the current time. No third-party call, no central registry.

This applies to TCT signature, expiry, audience, grant, and PoP validation. Revocation status is pull-based — checking whether a `jti` is revoked requires consulting the issuing peer's deny list (RFC-AITP-0008), which may involve a network call.

---

## 5. Message Envelope

Every AITP protocol message — `mutual_hello`, `mutual_hello_ack`, `mutual_commit`, `mutual_commit_ack`, `tct`, `error` — is wrapped in a standard envelope.

### 5.1 Schema

```json
{
  "version": "aitp/0.1",
  "message_type": "<string>",
  "message_id": "<uuid-v4>",
  "timestamp": 1711900000,
  "sender": {
    "agent_id": "aid:pubkey:<base64url>"
  },
  "payload": {},
  "signature": "<base64url>"
}
```

### 5.2 Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `version` | string | REQUIRED | MUST be `"aitp/0.1"` for this RFC. |
| `message_type` | string | REQUIRED | One of: `mutual_hello`, `mutual_hello_ack`, `mutual_commit`, `mutual_commit_ack`, `tct`, `error`. |
| `message_id` | string | REQUIRED | UUID v4, hyphenated lowercase. |
| `timestamp` | integer | REQUIRED | Unix timestamp (seconds). |
| `sender.agent_id` | string | REQUIRED | AID of the sending agent. |
| `payload` | object | REQUIRED | Message-type-specific content. |
| `signature` | string | REQUIRED | base64url-encoded envelope signature. |

The canonical schema is the JSON Schema at [`schemas/json/aitp-envelope.schema.json`](../schemas/json/aitp-envelope.schema.json).

### 5.3 Agent ID (AID)

An AID is a stable, cryptographic identifier derived from a public key:

```
aid:<method>:<identifier>
```

v0.1 supported methods:

| Method | Format | Example |
|---|---|---|
| `pubkey` | unpadded base64url of the 32-byte raw Ed25519 public key | `aid:pubkey:11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo` |

v0.1 supports Ed25519 only. The AID identifier component is the unpadded base64url (RFC 4648 §5) encoding of the 32-byte raw Ed25519 public key — exactly **43 characters** drawn from the alphabet `[A-Za-z0-9_-]`. Implementations MUST NOT use SPKI DER encoding, PEM wrappers, or any other encoding. AIDs MUST be exactly 43 characters in the identifier component; verifiers MUST reject AIDs of any other length.

> **Known-answer test.** Pinned (seed → public key → AID) vectors live at [`schemas/conformance/known-answer/keypairs.json`](../schemas/conformance/known-answer/keypairs.json). For example, the all-zero 32-byte seed produces public key `O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik` and AID `aid:pubkey:O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik`. Implementations MUST reproduce these values byte-for-byte.

An AID is not trusted by itself. It MUST be bound to an identity via an [Identity Binding](RFC-AITP-0002-identity.md) before any trust decision is made. The relationship between an AID, its identity binding, and its Manifest is defined in RFC-AITP-0003.

### 5.4 Signature

The signature covers the canonical serialization of:

```
sig_input = message_id + "|" + timestamp_string + "|" + sender.agent_id + "|" + hex(sha256(payload_canonical_json))
signature = base64url(sign(sender_private_key, sha256(sig_input)))
```

The `payload` object MUST be canonicalized per **[RFC 8785 — JSON Canonicalization Scheme (JCS)](https://datatracker.ietf.org/doc/html/rfc8785)** before hashing. JCS specifies compact JSON with no whitespace, lexicographically sorted keys at every nesting level, ECMAScript-style number formatting, and well-defined Unicode handling. Implementations MUST NOT use ad-hoc canonicalization; cross-implementation signature interop depends on JCS.

All `signature`, `pop_signature`, `cnf`, `proof`, and the AID identifier component (`aid:<method>:<identifier>`) are encoded as **unpadded base64url** per [RFC 4648 §5](https://datatracker.ietf.org/doc/html/rfc4648#section-5). Implementations MUST NOT emit `=` padding. Implementations SHOULD reject input that contains `=` padding; if they choose to accept it for compatibility with non-conformant senders, they MUST normalize to unpadded form before any signature verification.

Implementations MUST use:

| Algorithm | Identifier |
|---|---|
| Ed25519 | `ed25519` (REQUIRED) |

Ed25519 is the only signature algorithm in v0.1. Crypto agility is reserved for a future major version.

The algorithm is **not** encoded in the envelope. Verifiers determine the algorithm from the resolved key type bound to the sender's AID. This prevents algorithm-downgrade attacks.

#### 5.4.1 Signing input

All AITP v0.1 signatures (envelope, Manifest, TCT, delegation token, revocation snapshot) are computed over the **canonical JSON** form of the object per RFC 8785 (JCS). JSON is the only canonical form in v0.1: there is no Protobuf signing input, no CBOR signing input, no transport-specific signing input.

Implementations MAY transport AITP messages over any binary or text frame (raw JSON over HTTP, JSON inside a gRPC `bytes` field, MessagePack, CBOR, etc.) but MUST convert to canonical JSON before signing or verifying. Non-JSON transports are not part of the v0.1 conformance profile; their use is a deployment choice that does not affect the trust contract.

A signed object that round-trips through any transport MUST produce identical canonical JSON when verified. If a transport adds wrappers or renames fields, the implementation MUST strip them before reconstructing the canonical form.

> **Known-answer test.** Pinned (object → JCS canonical bytes → SHA-256 digest) vectors for the four signed AITP artifacts (TCT, Manifest, delegation token, revocation snapshot) live at [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json). Implementations MUST reproduce both the canonical byte sequence and the digest byte-for-byte. Mismatches typically indicate JCS sort-order, number-formatting, or Unicode-escaping bugs.

### 5.5 Replay Protection

Verifiers MUST enforce both controls:

1. **Timestamp window.** Reject envelopes where `abs(now() - envelope.timestamp) > tolerance`. Default tolerance: 300 seconds. Configurable per deployment.
2. **Message-ID deduplication.** Maintain a deny list of seen `message_id` values for at least the timestamp tolerance window. Reject any envelope whose `message_id` appears in the deny list.

### 5.6 Error Envelope

An error envelope uses `message_type: "error"` and an `AitpError` payload:

```json
{
  "code": "<error_code>",
  "reason": "<human-readable string>",
  "retryable": true
}
```

Verifiers MUST NOT reveal which specific policy check failed beyond the error code. `reason` strings are informational only and MUST NOT be used in automated decision-making.

### 5.7 Error Code Registry (envelope-level)

| Code | Meaning | Retryable |
|---|---|---|
| `INVALID_ENVELOPE` | Envelope failed schema validation | false |
| `INVALID_SIGNATURE` | Signature verification failed | false |
| `REPLAY_DETECTED` | Duplicate `message_id` | false |
| `TIMESTAMP_EXPIRED` | Timestamp outside tolerance | true |
| `UNKNOWN_VERSION` | Unsupported protocol version | false |
| `IDENTITY_FAILED` | Identity binding could not be verified | false |
| `POLICY_VIOLATION` | Requested capability not granted | false |
| `GRANT_OVERFLOW` | Peer-issued TCT grants exceed `offered_capabilities` | false |
| `INSUFFICIENT_GRANTS` | Received TCT lacks a capability listed in own `required_peer_capabilities` | false |
| `KEY_RESOLUTION_FAILED` | Could not resolve issuer or peer keys | true |
| `MANIFEST_EXPIRED` | Peer's Manifest is past `expires_at` | false |
| `MANIFEST_SIGNATURE_INVALID` | Peer's Manifest signature failed | false |
| `MANIFEST_POP_FAILED` | Peer's Manifest proof-of-possession failed | false |
| `MANIFEST_VERSION_UNKNOWN` | Peer's Manifest `version` not supported | false |
| `INCOMPATIBLE_TRUST_ANCHORS` | No trust-anchor overlap | false |
| `POP_VERIFICATION_FAILED` | Mutual-handshake PoP signature failed | false |
| `NONCE_MISMATCH` | `pop_nonce_echo` did not match the sent nonce | false |
| `AUDIENCE_MISMATCH` | TCT audience ≠ self AID | false |

Mode-specific error codes are defined in their respective RFCs (mutual handshake in RFC-AITP-0004, delegation in RFC-AITP-0006). The full registry is maintained in [`registries/error-codes.md`](../registries/error-codes.md).

---

## 6. Capability Negotiation

Capability negotiation is part of the Mutual Handshake. Discovery-time screening (`offered_capabilities` and `required_peer_capabilities` on the Manifest) is normative in [RFC-AITP-0003 §3](RFC-AITP-0003-manifest.md); handshake-time grant intersection is normative in [RFC-AITP-0004 §4](RFC-AITP-0004-mutual-handshake.md). Capability string format and the registry of well-known prefixes are in [`registries/capabilities.md`](../registries/capabilities.md).

There is no separate "protocol capability" object in v0.1. Implementations either support the full mandatory protocol surface (envelope + manifest + mutual handshake + TCT) or they are not conformant.

---

## 7. Compatibility Model

AITP uses a layered compatibility model:

- **Protocol version** governs envelope and base behavior (`version` field, e.g. `aitp/0.1`).
- **JSON Schema namespace** governs canonical schema compatibility (the `$id` URIs under `https://aitp.dev/schema/v0.1/`).
- **TCT version** governs the canonical token contract.
- **Manifest version** governs the agent self-description format.

Major protocol version mismatches are not compatible. Minor versions are expected to be backward compatible. Verifiers receiving an unknown `version` MUST respond with `UNKNOWN_VERSION`.

Unknown JSON fields outside explicit `extensions` namespaces MUST be rejected. Signed AITP objects depend on canonical JCS representation; silently ignoring unknown fields would create signature ambiguity across implementations (one peer hashes the field in, another hashes it out, and the same wire bytes verify differently). Forward compatibility is provided exclusively through explicit `extensions` objects (see [RFC-AITP-0012](RFC-AITP-0012-extensions.md)) — every signed object reserves an `extensions` slot, and unknown keys *inside* `extensions` MUST be ignored.

---

## 8. Transport

The normative transport for AITP v0.1 is **HTTPS carrying canonical JSON**. The endpoints normatively required of every conformant peer:

| Endpoint | Method | Purpose | Defined in |
|---|---|---|---|
| `/.well-known/aitp-manifest` | GET | Fetch this peer's signed Manifest | [RFC-AITP-0003 §4](RFC-AITP-0003-manifest.md) |
| `<handshake_endpoint>` | POST | Receive `mutual_hello` / `mutual_commit` envelopes | [RFC-AITP-0004](RFC-AITP-0004-mutual-handshake.md) |

> **Other endpoints are deployment-defined in v0.1.** TCT verification, delegation verification, and revocation list publication (RFC-AITP-0005 §10, RFC-AITP-0006, RFC-AITP-0008) are operational surfaces. Peers that expose them MAY advertise their URLs in the Manifest's `extensions` namespace ([RFC-AITP-0012](RFC-AITP-0012-extensions.md)); v0.1 does not normatively pin those advertisement fields.

Request and response bodies are AITP envelopes serialized as JSON with `Content-Type: application/json`. The well-known Manifest endpoint and `handshake_endpoint` (advertised in the Manifest) are the only paths v0.1 normatively requires.

Implementations MAY transport AITP messages over other framings (binary RPC, message bus, etc.) but MUST convert to canonical JSON before signing or verifying (§5.4.1). v0.1 does not standardize any non-JSON binding.

---

## 9. Registry Hooks

AITP maintains four registries under [`registries/`](../registries/):

- **identity-types** — registered values for `IdentityDescriptor.type`
- **capabilities** — well-known capability strings
- **error-codes** — protocol-level error codes (envelope, manifest, handshake, delegation)
- **media-types** — content types used in transport bindings

New entries are added via the [RFC process](../governance/RFC-PROCESS.md). Experimental identifiers SHOULD use reverse-domain notation.

---

## 10. Conformance

A conformant AITP v0.1 implementation MUST:

1. Use the JSON wire format (§5.1) and the JCS signing input (§5.4.1). Non-JSON framings (binary RPC, CBOR, MessagePack, etc.) are not part of v0.1 conformance; using them is a deployment choice that does not satisfy v0.1 conformance on its own.
2. Parse and verify the envelope as defined in §5.
3. Verify identity bindings as defined in [RFC-AITP-0002](RFC-AITP-0002-identity.md).
4. Publish and consume Agent Manifests as defined in [RFC-AITP-0003](RFC-AITP-0003-manifest.md).
5. Implement the Mutual Handshake defined in [RFC-AITP-0004](RFC-AITP-0004-mutual-handshake.md).
6. Issue and verify peer-issued TCTs as defined in [RFC-AITP-0005](RFC-AITP-0005-tct.md).
7. Reject expired, mismatched-audience, or revoked TCTs.
8. Pass the conformance fixtures in [`schemas/conformance/`](../schemas/conformance/).

---

## 11. Security Considerations

See [RFC-AITP-0009 Security](RFC-AITP-0009-security.md) for the full threat model. Implementations MUST use a cryptographically secure RNG for `message_id` and nonces, store private keys in secure storage, and validate all inputs against the JSON Schema before processing.

---

## 12. References

- [RFC-AITP-0002 Identity](RFC-AITP-0002-identity.md)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0005 Trust Context Token](RFC-AITP-0005-tct.md)
- [RFC-AITP-0006 Single-Hop Delegation](RFC-AITP-0006-delegation.md)
- [RFC-AITP-0007 Key Resolution](RFC-AITP-0007-key-resolution.md)
- [RFC-AITP-0008 Revocation](RFC-AITP-0008-revocation.md)
- [RFC-AITP-0009 Security & Threat Model](RFC-AITP-0009-security.md)
- [RFC 2119 — Key words for use in RFCs](https://datatracker.ietf.org/doc/html/rfc2119)
- [RFC 4648 — Base16, Base32, Base64 Encoding (§5 base64url)](https://datatracker.ietf.org/doc/html/rfc4648#section-5)
- [RFC 7519 — JSON Web Token](https://datatracker.ietf.org/doc/html/rfc7519)
- [RFC 8785 — JSON Canonicalization Scheme (JCS)](https://datatracker.ietf.org/doc/html/rfc8785)
