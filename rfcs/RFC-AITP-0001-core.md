# RFC-AITP-0001
# Agent Identity & Trust Protocol (AITP) — Core

**Document:** RFC-AITP-0001
**Version:** 0.2.2-draft
**Status:** Community Standards Track (v0.2 Draft)
**Canonical wire format:** JSON
**Normative transport:** HTTPS (any HTTP/1.1+ runtime)
**Canonical signing input:** RFC 8785 (JCS) canonical JSON (protocol-internal artifacts); RFC 7515 compact JWS (portable trust artifacts, §5.4.5)
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

The numbering scheme treats `aitp/0.1` as the inaugural A2A protocol. This revision specifies **`aitp/0.2`**, a breaking revision with two delta sets relative to `aitp/0.1`:

1. **Cryptographic agility** — algorithm-tagged AIDs (§5.3), algorithm-tagged JCS signatures (§5.4.3), the JWK-thumbprint `cnf` form (§5.4.4), and mandatory dual-algorithm verification (Ed25519 + P-256).
2. **Portable trust artifacts as compact JWS** — the TCT, the grant voucher, and the delegation token are re-serialized as compact JWS with explicit typing (§5.4.5; RFC-AITP-0005, RFC-AITP-0006).

`aitp/0.1` verifiers reject unknown `version` values with `UNKNOWN_VERSION`, so the version bump is a clean break: no v0.1 implementation will silently misinterpret a v0.2 artifact.

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

Every AITP protocol message — `mutual_hello`, `mutual_hello_ack`, `mutual_commit`, `mutual_commit_ack`, `tct`, `pop_challenge`, `pop_response`, `error` — is wrapped in a standard envelope. (`pop_challenge` and `pop_response` are introduced by [RFC-AITP-0005 §6.1](RFC-AITP-0005-tct.md#61-downstream-pop-exchange) and are part of v0.2 conformance for any peer that issues TCTs.)

### 5.1 Schema

```json
{
  "version": "aitp/0.2",
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
| `version` | string | REQUIRED | MUST be `"aitp/0.2"` for this RFC. |
| `message_type` | string | REQUIRED | One of: `mutual_hello`, `mutual_hello_ack`, `mutual_commit`, `mutual_commit_ack`, `tct`, `pop_challenge`, `pop_response`, `error`. |
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

v0.2 supported methods:

| Method | Format | Example |
|---|---|---|
| `pubkey` (legacy, Ed25519) | unpadded base64url of the 32-byte raw Ed25519 public key (43 chars) | `aid:pubkey:11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo` |
| `pubkey:ed25519` (algorithm-tagged) | unpadded base64url of the 32-byte raw Ed25519 public key (43 chars) | `aid:pubkey:ed25519:11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo` |
| `pubkey:p256` | unpadded base64url of the 33-byte SEC1 compressed P-256 public key (44 chars) | `aid:pubkey:p256:A8XBp7TBpRl6Q1QXZqXxZcGo1bRCw9KkV-Mn8eqXC8GE` |

v0.2 introduces the algorithm-tagged grammar
`aid:pubkey:<algorithm>:<identifier>` while preserving the legacy
v0.1 form `aid:pubkey:<43-char-identifier>` (which implicitly
means Ed25519). The legacy form is **accepted indefinitely** for
interop — implementations MUST parse both. New AIDs published
under the v0.2 profile SHOULD use the algorithm-tagged form. The
legacy form is canonically equivalent to
`aid:pubkey:ed25519:<same-identifier>` for trust decisions; the
two forms are NOT byte-equal in canonical signing bytes, so
issuers MUST publish each AID in exactly one form for the
duration of its lifetime.

The algorithm tag, when present, is part of the AID identifier —
verifiers MUST reject AIDs whose algorithm tag is not in the
registered set above.

Implementations MUST NOT use SPKI DER encoding, PEM wrappers, or
any other encoding for the identifier component. The unpadded
base64url alphabet `[A-Za-z0-9_-]` is the only accepted character
set. Identifier length is algorithm-specific:

- `ed25519` (and the legacy untagged form) — exactly **43 chars**
  (32 raw bytes).
- `p256` — exactly **44 chars** (33 raw bytes; SEC1 compressed
  point per [SEC 1 §2.3.3](https://www.secg.org/sec1-v2.pdf)).

> **Known-answer test.** Pinned (seed → public key → AID) vectors live at [`schemas/conformance/known-answer/keypairs.json`](../schemas/conformance/known-answer/keypairs.json). For example, the all-zero 32-byte seed produces public key `O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik` and AID `aid:pubkey:O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik`. Implementations MUST reproduce these values byte-for-byte.

An AID is not trusted by itself. It MUST be bound to an identity via an [Identity Binding](RFC-AITP-0002-identity.md) before any trust decision is made. The relationship between an AID, its identity binding, and its Manifest is defined in RFC-AITP-0003.

### 5.4 Signature

AITP v0.2 defines **two signing profiles**:

| Profile | Artifacts | Defined in |
|---|---|---|
| **JCS embedded-signature profile** — the signature is a field of the JSON object, computed over the object's RFC 8785 canonical form | envelopes, Agent Manifests, revocation snapshots, handshake payloads | §5.4.1–§5.4.4 |
| **Compact JWS profile** — the artifact *is* an RFC 7515 compact JWS string; the signature covers the exact transmitted bytes | TCT, grant voucher, delegation token | §5.4.5 |

The boundary rule is normative:

> Any artifact that crosses a trust boundary and may be verified by
> non-AITP code MUST be a compact JWS with an explicit `typ`.
> Artifacts exchanged and verified only between full AITP protocol
> stacks remain JCS-signed JSON.

The portable trust artifacts (TCT, grant voucher, delegation token) are
the artifacts most likely to be verified by code that is not a full
AITP stack — a resource server checking a capability, an auditor, a
gateway in another language. Under the JWS profile, verifiers never
re-canonicalize: the signature covers the transmitted bytes, which
eliminates the re-serialization signature-bypass bug class entirely
for those artifacts. Protocol-internal messages keep the JCS profile,
where both ends are full AITP stacks and canonical-form interop is
pinned by known-answer tests.

The envelope signature follows the JCS profile. It covers the
canonical serialization of:

```
sig_input = message_id + "|" + timestamp_string + "|" + sender.agent_id + "|" + hex(sha256(payload_canonical_json))
signature = base64url(sign(sender_private_key, sha256(sig_input)))
```

The `payload` object MUST be canonicalized per **[RFC 8785 — JSON Canonicalization Scheme (JCS)](https://datatracker.ietf.org/doc/html/rfc8785)** before hashing. JCS specifies compact JSON with no whitespace, lexicographically sorted keys at every nesting level, ECMAScript-style number formatting, and well-defined Unicode handling. Implementations MUST NOT use ad-hoc canonicalization; cross-implementation signature interop depends on JCS.

All `signature`, `pop_signature`, `cnf`, `proof`, and the AID identifier component (`aid:<method>:<identifier>`) are encoded as **unpadded base64url** per [RFC 4648 §5](https://datatracker.ietf.org/doc/html/rfc4648#section-5). Implementations MUST NOT emit `=` padding. Implementations SHOULD reject input that contains `=` padding; if they choose to accept it for compatibility with non-conformant senders, they MUST normalize to unpadded form before any signature verification.

For each algorithm the unpadded base64url encoding length is
fixed; verifiers MUST reject any field whose encoded length
differs from the algorithm's expected size:

| Field | Algorithm | Raw bytes | Unpadded base64url length |
|---|---|---|---|
| AID identifier — Ed25519 | `ed25519` | 32 | 43 chars |
| AID identifier — P-256 | `p256` | 33 (SEC1 compressed) | 44 chars |
| `cnf.jkt` (TCT / delegation claims, §5.4.4) | (any) | 32 (SHA-256 thumbprint) | 43 chars |
| `signature`, `pop_signature` — Ed25519 | `ed25519` | 64 | 86 chars |
| `signature`, `pop_signature` — P-256 ECDSA | `p256` | 64 (R\|\|S, fixed-length) | 86 chars |
| `pop_nonce`, Manifest `proof_of_possession.challenge` | (any) | 16 (128-bit nonce) | 22 chars |

The canonical JSON Schemas under [`schemas/json/`](../schemas/json/)
carry these constraints as `pattern` regexes; implementations MUST
validate against the schema before attempting cryptographic
verification.

#### 5.4.3 Algorithm-tagged signature wire format (JCS profile only)

This section applies to **JCS-profile signature fields only**
(envelope `signature`, manifest `signature`, revocation `signature`, session bundle `signature`,
PoP `pop_signature`, identity `proof`). Compact-JWS artifacts
(§5.4.5) carry their algorithm in the JOSE protected header `alg`
parameter instead, pinned by the same AID-derived rule.

JCS-profile signature fields MAY carry an algorithm tag prefix in
v0.2:

```
<base64url-signature> := <86-char-b64url>                  (legacy v0.1, Ed25519 implicit)
                       | "ed25519." <86-char-b64url>       (v0.2 tagged, Ed25519)
                       | "p256." <86-char-b64url>          (v0.2 tagged, P-256)
```

The untagged 86-char form remains valid and is interpreted as
`ed25519` for backward compatibility with v0.1. The tagged form is
an ASCII algorithm name (`ed25519` or `p256`), a single period
(`.`), then the unpadded base64url-encoded signature bytes.
Verifiers MUST:

1. Split on the first `.` to obtain the algorithm tag and signature
   bytes.
2. Reject if the algorithm tag is not in the registered set, or if
   the encoded signature length doesn't match the algorithm's
   expected size.
3. Reject if the algorithm tag does NOT match the signing AID's
   algorithm (e.g. an `ed25519`-AID signing with a `p256.` tagged
   signature). This prevents downgrade attacks where a P-256-only
   peer is tricked into accepting an Ed25519 signature labelled as
   P-256.

The algorithm tag is part of the canonical bytes that get hashed
for outer signatures: changing the tag changes the bytes and
therefore the hash. This binds the algorithm to the signed data.

Implementations MUST use one of:

| Algorithm | Identifier | Status |
|---|---|---|
| Ed25519 (RFC 8032) | `ed25519` | REQUIRED |
| ECDSA on P-256 with SHA-256 | `p256` | REQUIRED |

Both are mandatory in v0.2. A v0.2 peer MUST be able to verify
both, even if it only signs with one. Manifests MAY advertise
which algorithms a peer is willing to accept via the
`accepted_signature_algorithms` field (RFC-AITP-0003 §3.2).

A verifier that encounters a signature whose algorithm tag it does
not implement MUST reject with `INVALID_SIGNATURE`, never
`KEY_RESOLUTION_FAILED`. "Algorithm not supported" is a
signature-verification failure: the key may well be resolvable, but
the signature cannot be checked. `KEY_RESOLUTION_FAILED` is reserved
for the distinct case where the issuer or peer key itself cannot be
resolved (RFC-AITP-0007). The distinction is load-bearing because
`KEY_RESOLUTION_FAILED` is retryable (§5.7) while `INVALID_SIGNATURE`
is not — reporting an unsupported-algorithm condition as
`KEY_RESOLUTION_FAILED` would invite a caller to retry a request that
can never succeed.

#### 5.4.4 JWK thumbprint for `cnf`

Proof-of-possession key binding on the portable trust artifacts
(TCT, delegation token — RFC-AITP-0005, RFC-AITP-0006) uses the
[RFC 7800](https://datatracker.ietf.org/doc/html/rfc7800) `cnf`
claim with the `jkt` confirmation method:

```json
"cnf": { "jkt": "<RFC 7638 JWK thumbprint of the bound public key>" }
```

The thumbprint is the base64url-unpadded SHA-256 over the canonical
JWK JSON per [RFC 7638](https://datatracker.ietf.org/doc/html/rfc7638).
It is algorithm-agnostic: a P-256 `jkt` is computed from the JWK
`{"crv":"P-256","kty":"EC","x":"…","y":"…"}` shape, an Ed25519 `jkt`
from `{"crv":"Ed25519","kty":"OKP","x":"…"}`.

In `aitp/0.2` this is the **only** `cnf` form on the portable trust
artifacts — the v0.1 raw-public-key `binding.cnf` form does not
appear in v0.2 tokens. Verifiers derive the *expected* thumbprint
from the artifact's subject AID (which encodes the public key, §5.3)
and MUST reject the token if `cnf.jkt` does not match. This is the
same convention the OIDC identity binding already uses for its
`cnf.jkt` (RFC-AITP-0002 §2.2.1).

Pinned thumbprint vectors for the KAT keypairs live at
[`schemas/conformance/known-answer/jwk-thumbprints.json`](../schemas/conformance/known-answer/jwk-thumbprints.json);
they are load-bearing for v0.2 `cnf.jkt` verification and
implementations MUST reproduce them byte-for-byte.

#### 5.4.1 Signing input (JCS profile)

All JCS-profile signatures (envelope, Manifest, revocation snapshot, handshake payloads) are computed over the **canonical JSON** form of the object per RFC 8785 (JCS). JSON is the only canonical form for the JCS profile: there is no Protobuf signing input, no CBOR signing input, no transport-specific signing input.

The portable trust artifacts (TCT, grant voucher, delegation token) are **not** JCS-signed in v0.2 — they are compact JWS strings (§5.4.5) whose signatures cover the transmitted bytes directly. (In `aitp/0.1` the TCT and delegation token were JCS-signed; that profile is retired for those artifacts.)

Implementations MAY transport AITP messages over any binary or text frame (raw JSON over HTTP, JSON inside a gRPC `bytes` field, MessagePack, CBOR, etc.) but MUST convert to canonical JSON before signing or verifying. Non-JSON transports are not part of the v0.1 conformance profile; their use is a deployment choice that does not affect the trust contract.

A signed object that round-trips through any transport MUST produce identical canonical JSON when verified. If a transport adds wrappers or renames fields, the implementation MUST strip them before reconstructing the canonical form.

> **The artifact-name wrapper is such a wrapper.** Three JCS-profile artifacts are carried inside a JSON object whose key names the artifact: `{"manifest": {…}}` (RFC-AITP-0003 §6.1), `{"revocation_list": {…}, "signature": "…"}` (RFC-AITP-0008 §1.5), and `{"session_bundle": {…}}` (RFC-AITP-0010 §3). The artifact-naming key is **routing metadata for the transport** — it tells a recipient what kind of document arrived — and is never part of the signing bytes. Issuers sign, and verifiers reconstruct, the **inner artifact body**; the wrapper is added on the way out and stripped on the way in.
>
> The two profiles differ only in where the signature sits, and neither placement changes the rule. For the Manifest and the session bundle the `signature` member lives *inside* the body and is excluded from the signing input (`canonical_json(body_without_signature)`). For the revocation snapshot the `signature` is a *sibling of* the wrapped body, not a member of it — so the body is signed as-is, with nothing to strip, and the sibling is discarded along with the wrapper. In every case the signing input is the inner artifact body carrying no signature of its own.
>
> **Which placement a new artifact takes follows from who hands it over, not from precedent.** An artifact is *redistributable* if it can reach a verifier by any path other than that verifier's own pull from the issuer — relayed by a third party, embedded in another party's message, or served onward from a cache someone else controls. A redistributable artifact MUST carry its `signature` as a member of the signed body, so that the proof survives every hop that strips the transport wrapper. An artifact that is *point-to-point* — pulled by the verifier directly from the issuing peer and never passed on — MAY instead carry the signature as a sibling of the wrapper, since no hop separates the body from its proof. **A verifier caching what it pulled does not make an artifact redistributable:** caching changes how long that verifier holds the artifact, not who hands it over, and the body and its sibling proof stay together. This includes a cache shared among the components of a single deployment (RFC-AITP-0008 §3.3) — the deployment is still the party that pulled and verifies it. This is why the two placements above are what they are: a Manifest may be exchanged inline during the Mutual Handshake rather than fetched from its origin (RFC-AITP-0003 §1), and a session bundle is signed once by the coordinator and distributed to every participant (RFC-AITP-0010 §4.3), while a revocation snapshot is polled by the consuming peer directly from the issuing peer's `ListRevoked` endpoint and not passed along (RFC-AITP-0008 §1.4) — its consumer-side caching and staleness bounds (RFC-AITP-0008 §3.2) are private to that consumer and leave it point-to-point. A new artifact derives its placement from this rule; it MUST NOT be chosen by copying whichever existing artifact it happens to resemble.
>
> Stated once here because it holds for every JCS-profile artifact that uses an artifact-name wrapper, present and future; restated at each artifact's own signing section. JCS-profile artifacts that are *not* wrapped — the envelope (§5) and handshake payloads — carry no artifact-name wrapper, so this note does not apply to them; their signing inputs are defined in §5.4.

> **URL canonicalization.** String fields holding URLs (e.g.
> `accepted_trust_anchors`, `handshake_endpoint`,
> `identity_hint.issuer`) are signed as the **verbatim wire string** —
> NOT the RFC 3986 §6 canonical form. An implementation that
> deserializes such fields into a typed URL value (which normalizes
> trailing slashes, lowercases the scheme, etc.) MUST preserve the
> original byte form for re-serialization, or it will compute a
> different signing input than the issuer did. Implementations
> SHOULD model URL fields as opaque strings at the serde layer and
> validate URL syntax separately when transport-layer parsing is
> needed.

> **Optional-array round-trip.** Optional array fields (e.g.
> `accepted_identity_types`, the `extensions` map) MUST preserve
> the absent-vs-explicit-empty distinction in canonical bytes.
> Implementations modeling such fields as `Vec<T>` with
> `skip_serializing_if = "Vec::is_empty"` collapse the two states
> and will diverge from issuers that wrote an explicit `[]`. Use
> `Option<Vec<T>>` (or equivalent) so the signing view emits the
> same bytes the issuer signed.

> **Known-answer test.** Pinned (signing input → JCS canonical bytes → SHA-256 digest) vectors for the JCS-profile artifacts (Manifest, revocation snapshot, session bundle) live at [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json). **Each vector's `object` is the signing input itself — the inner artifact body, wrapper stripped and `signature` excluded — not the transport shape;** every vector states this explicitly in its `signing_input` field, whose value for these artifacts is `"body"`. Implementations MUST reproduce both the canonical byte sequence and the digest byte-for-byte, and MUST take the pinned bytes as the thing they sign, not merely as a canonicalization exercise. Mismatches typically indicate JCS sort-order, number-formatting, or Unicode-escaping bugs — or signing the wrapper. (The v0.1 TCT and delegation JCS vectors are retired with the move to compact JWS; JWS KAT vectors are pinned under `known-answer/signed-examples/`.)

#### 5.4.2 PoP signing input convention

All AITP v0.1 proof-of-possession signing inputs follow a single rule:

```
hash_input = sha256(base64url_decode(nonce_or_challenge))
```

The hash input is always the raw bytes obtained by base64url-decoding the nonce or challenge — never the ASCII bytes of the encoded form. The rule applies uniformly to:

- **Manifest PoP** — [RFC-AITP-0003 §3](RFC-AITP-0003-manifest.md) (`proof_of_possession.challenge`, 16 raw bytes / 22 base64url chars).
- **Handshake round-2 PoP** — [RFC-AITP-0004 §3](RFC-AITP-0004-mutual-handshake.md) (`pop_nonce`, 16 raw bytes / 22 base64url chars).
- **Downstream TCT PoP** — [RFC-AITP-0005 §6.1](RFC-AITP-0005-tct.md) (`nonce` in the `pop_challenge` / `pop_response` exchange).
- **Pinned-key identity proof input** — [RFC-AITP-0002 §3.1](RFC-AITP-0002-identity.md) (via `pop_nonce_decoded_bytes`).

Implementations MUST hash the decoded bytes; hashing the ASCII form is non-conformant. An implementation that consistently hashes the encoded string will be internally self-consistent but will fail cross-implementation verification — this is the most common interop bug observed in early AITP implementations.

> **Known-answer test.** A pinned PoP signing-input vector (`kat-manifest-pop-001`) lives at [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json). It pins (challenge → decoded bytes → SHA-256 digest → Ed25519 signature with `kat-keypair-001`). Implementations MUST add a KAT cross-check that runs the same input through every PoP code path and confirms each produces the pinned signature byte-for-byte.

#### 5.4.5 Compact JWS profile (portable trust artifacts)

The portable trust artifacts — the **TCT** (RFC-AITP-0005), the
**grant voucher** (RFC-AITP-0005 §8), and the **delegation token**
(RFC-AITP-0006) — are serialized as
[RFC 7515](https://datatracker.ietf.org/doc/html/rfc7515) **compact
JWS** strings:

```
base64url(protected_header) "." base64url(payload) "." base64url(signature)
```

The payload is a JSON claims object using registered JWT claims
([RFC 7519](https://datatracker.ietf.org/doc/html/rfc7519)) plus the
AITP private claims defined per artifact. The signature covers the
exact transmitted bytes (`ASCII(header || '.' || payload)`); verifiers
MUST NOT re-serialize, re-canonicalize, or otherwise reconstruct any
byte sequence to verify these artifacts.

**Protected header.** The header MUST contain **exactly** the
parameters `alg` and `typ`, and no others. Verifiers MUST reject a
token whose header contains any additional parameter (including
`crit`, `kid`, `jku`, `jwk`, `x5u`, `x5c`). Key resolution is by AID
and Manifest (RFC-AITP-0007) — never from header-supplied material.

**Explicit typing (`typ`).** Per
[RFC 8725 §3.11](https://datatracker.ietf.org/doc/html/rfc8725#section-3.11),
every AITP JWS carries an explicit type, and verifiers MUST reject a
token whose `typ` does not exactly match the single value expected
for the verification context, with `TOKEN_TYP_MISMATCH`:

| Artifact | `typ` | Media type |
|---|---|---|
| Trust Context Token | `aitp-tct+jwt` | `application/aitp-tct+jwt` |
| Grant voucher | `aitp-grant+jwt` | `application/aitp-grant+jwt` |
| Delegation token | `aitp-delegation+jwt` | `application/aitp-delegation+jwt` |

**Algorithm pinning (`alg`).** There is no algorithm negotiation.
Before signature verification, the verifier MUST derive the **sole
acceptable** `alg` value from the signer's AID (§5.3) and MUST reject
any other value — including `none`, in any capitalization — with
`TOKEN_ALG_MISMATCH`:

| Signer AID method | Sole acceptable `alg` |
|---|---|
| `aid:pubkey:<43-char>` (legacy) or `aid:pubkey:ed25519:…` | `EdDSA` |
| `aid:pubkey:p256:…` | `ES256` |

The AID, not the token, decides — this is the JWS-profile
restatement of the §5.4.3 rule, and it forecloses the JOSE
algorithm-confusion and `alg: none` attack classes
(RFC-AITP-0009 §1).

**Version claim (`ver`).** Every AITP JWS payload carries the private
claim `ver` with the protocol version literal (`"aitp/0.2"` for this
RFC). Verifiers MUST reject tokens with an unknown `ver` with
`UNKNOWN_VERSION`. The `typ` values above are version-stable; protocol
versioning rides exclusively on `ver`.

**Strict parsing.** Verifiers MUST reject:

- a token that does not consist of exactly three non-empty `.`-separated
  segments (no unsecured JWS, no detached payload, no JSON
  serialization);
- any segment containing characters outside the unpadded base64url
  alphabet `[A-Za-z0-9_-]`, including `=` padding (no normalization
  is performed for JWS segments — the bytes are the signature input);
- a payload that is not a JSON object, or that contains duplicate
  keys.

Unknown claims in the payload MUST be rejected, with one exception:
the OPTIONAL `ext` private claim, an object with the same semantics
as the `extensions` slot on JCS-profile objects (§7) — unknown keys
*inside* `ext` MUST be ignored.

**ECDSA signature encoding.** `ES256` signatures use the JOSE raw
`R || S` fixed-length 64-byte encoding (not ASN.1/DER), per
RFC 7518 §3.4.

A compact JWS is transport-safe verbatim: it MAY be carried in HTTP
headers, query-less URLs, or JSON string fields without further
encoding. When embedded in a JSON document (e.g. a handshake payload
or session bundle), the artifact is carried as an **opaque JSON
string** — embedding documents never parse, transform, or re-encode
it, and outer JCS signatures cover the string verbatim.

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
| `POP_CHALLENGE_INVALID` | Downstream `pop_challenge` envelope malformed, replayed, or expired | false |
| `POP_RESPONSE_INVALID` | Downstream `pop_response` envelope or `pop_signature` failed verification | false |
| `NONCE_MISMATCH` | `pop_nonce_echo` did not match the sent nonce | false |
| `AUDIENCE_MISMATCH` | TCT `aud` ≠ self AID | false |
| `TOKEN_ALG_MISMATCH` | JWS `alg` is not the sole AID-derived value (§5.4.5) — includes `none` and unknown algorithms | false |
| `TOKEN_TYP_MISMATCH` | JWS `typ` does not match the expected value for the verification context (§5.4.5) | false |

Mode-specific error codes are defined in their respective RFCs (mutual handshake in RFC-AITP-0004, delegation in RFC-AITP-0006). The full registry is maintained in [`registries/error-codes.md`](../registries/error-codes.md).

---

## 6. Capability Negotiation

Capability negotiation is part of the Mutual Handshake. Discovery-time screening (`offered_capabilities` and `required_peer_capabilities` on the Manifest) is normative in [RFC-AITP-0003 §3](RFC-AITP-0003-manifest.md); handshake-time grant intersection is normative in [RFC-AITP-0004 §4](RFC-AITP-0004-mutual-handshake.md). Capability string format and the registry of well-known prefixes are in [`registries/capabilities.md`](../registries/capabilities.md).

There is no separate "protocol capability" object in v0.1. Implementations either support the full mandatory protocol surface (envelope + manifest + mutual handshake + TCT) or they are not conformant.

---

## 7. Compatibility Model

AITP uses a layered compatibility model:

- **Protocol version** governs envelope and base behavior (`version` field on JCS-profile objects, `ver` claim on JWS-profile artifacts; `aitp/0.2` for this RFC).
- **JSON Schema namespace** governs canonical schema compatibility (the `$id` URIs under `https://aitp.dev/schema/v0.2/`).
- **TCT version** governs the canonical token contract (the `ver` claim).
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

A conformant AITP v0.2 implementation MUST:

1. Use the JSON wire format (§5.1), the JCS signing input for protocol-internal artifacts (§5.4.1), and the compact JWS profile for portable trust artifacts (§5.4.5). Non-JSON framings (binary RPC, CBOR, MessagePack, etc.) are not part of v0.2 conformance; using them is a deployment choice that does not satisfy v0.2 conformance on its own.
2. Parse and verify the envelope as defined in §5.
3. Verify identity bindings as defined in [RFC-AITP-0002](RFC-AITP-0002-identity.md).
4. Publish and consume Agent Manifests as defined in [RFC-AITP-0003](RFC-AITP-0003-manifest.md).
5. Implement the Mutual Handshake defined in [RFC-AITP-0004](RFC-AITP-0004-mutual-handshake.md).
6. Issue and verify peer-issued TCTs and grant vouchers as defined in [RFC-AITP-0005](RFC-AITP-0005-tct.md), enforcing the §5.4.5 algorithm-pinning and explicit-typing rules.
7. Reject expired, mismatched-audience, or revoked TCTs, and reject tokens failing `alg`/`typ` enforcement with `TOKEN_ALG_MISMATCH` / `TOKEN_TYP_MISMATCH`.
8. Reproduce the canonical-bytes and digest pins in [`schemas/conformance/known-answer/`](../schemas/conformance/known-answer/) byte-for-byte. The v0.2-mandatory KATs are: the JCS signing-input vectors for the JCS-profile artifacts (`kat-manifest-001`, `kat-revocation-001`; each pins the inner artifact body per §5.4.1), the unified PoP signing-input vector `kat-manifest-pop-001`, the compact-JWS vectors under `known-answer/signed-examples/` (TCT, grant voucher, delegation), and the JCS-profile signed examples there (Manifest, revocation snapshot) — verified as committed, without re-minting (RFC-AITP-0003 §6.1, RFC-AITP-0008 §1.5). Implementations MUST run `kat-manifest-pop-001` through every PoP code path (Manifest PoP, handshake PoP, downstream TCT PoP, pinned-key identity proof) and confirm each produces the pinned signature — see §5.4.2. Implementations that opt into the post-v0.2 draft RFCs MUST additionally reproduce the multi-hop chain vectors (RFC-AITP-0011) and the session-bundle vector (RFC-AITP-0010); core-only implementations MAY skip those.
9. Pass the conformance fixtures in [`schemas/conformance/`](../schemas/conformance/). The v0.2 fixture surface is the `env-*`, `man-*`, `mh-*`, `id-*`, `tct-*`, `vch-*`, `del-*`, and `rev-*` IDs. The `del-mh-*` and `bundle-*` fixtures are draft opt-in (RFC-AITP-0010 / RFC-AITP-0011) — core implementations are expected to reject `del-mh-*` tokens with `DELEGATION_MULTIHOP_NOT_SUPPORTED` and to skip the `bundle-*` operations (`SKIP` rather than `FAIL`).

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
- [RFC 7515 — JSON Web Signature (JWS)](https://datatracker.ietf.org/doc/html/rfc7515)
- [RFC 7518 — JSON Web Algorithms (JWA)](https://datatracker.ietf.org/doc/html/rfc7518)
- [RFC 7519 — JSON Web Token](https://datatracker.ietf.org/doc/html/rfc7519)
- [RFC 7638 — JSON Web Key (JWK) Thumbprint](https://datatracker.ietf.org/doc/html/rfc7638)
- [RFC 7800 — Proof-of-Possession Key Semantics for JWTs](https://datatracker.ietf.org/doc/html/rfc7800)
- [RFC 8725 — JSON Web Token Best Current Practices](https://datatracker.ietf.org/doc/html/rfc8725)
- [RFC 8785 — JSON Canonicalization Scheme (JCS)](https://datatracker.ietf.org/doc/html/rfc8785)
