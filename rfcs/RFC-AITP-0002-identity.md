# RFC-AITP-0002
# Identity Binding

**Document:** RFC-AITP-0002
**Version:** 0.3.2-draft
**Status:** Community Standards Track (Review)
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)

---

## Abstract

This RFC defines how an agent's AID is bound to a verifiable claim from a trusted issuer. AITP does not define an identity system; this RFC defines how identity is *presented* and *verified* between peers. The verifying party is always another peer agent (not a third-party verifier or service): see [RFC-AITP-0001 §4 Architecture](RFC-AITP-0001-core.md#4-architecture).

**Where identity proof appears.** Identity proof — the verifiable JWT (for OIDC), signature (for pinned_key), or SVID-backed proof (for spiffe) — is exchanged inline during the Mutual Handshake (RFC-AITP-0004 §3). The Agent Manifest (RFC-AITP-0003 §3.1) carries only an **identity hint** (`identity_hint`): static `type`/`issuer`/`subject` metadata, with no `proof` field. The hint lets peers discover *which* identity provider an agent uses; the verifiable proof is presented fresh each handshake so it can be bound to a per-handshake nonce and to the verifying peer's AID. The `aud`, `cnf.jkt`, and `nonce` requirements in §2 apply to the handshake-level identity proof only, never to the Manifest hint.

v0.3 supports three identity types: `oidc` (§2), `pinned_key` (§3) and `spiffe` (§6). `spiffe` is at registry status Proposed ([`registries/identity-types.md`](../registries/identity-types.md)) and its conformance fixtures are `draft`. Future identity types extend this RFC without modifying the core envelope.

---

## 1. Identity Descriptor

```json
{
  "identity": {
    "type": "oidc | pinned_key | spiffe",
    "issuer": "<issuer URI — oidc only>",
    "subject": "<subject identifier>",
    "proof": "<jwt or signature>",
    "public_key": "<base64url — pinned_key only>",
    "svid_type": "<jwt-svid | x509-svid — spiffe only>",
    "x5c": ["<standard-base64 DER certificate — spiffe x509-svid only>"]
  }
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | REQUIRED | Identity mechanism: `oidc`, `pinned_key` or `spiffe`. |
| `issuer` | string | REQUIRED for `oidc`; MUST be absent for `pinned_key` and `spiffe` | Issuer URI (MUST match JWT `iss` claim). A `pinned_key` descriptor has no issuer: its trust anchor is the local `pinned_keys` store (§3.2), so an `issuer` member on it is rejected with `IDENTITY_FAILED`. The identity-descriptor schema enforces this in its `pinned_key` branch, and the same rule for `spiffe` in its `spiffe` branch (§6.1). |
| `subject` | string | REQUIRED | Agent subject identifier. For `spiffe`, the SPIFFE ID (§6.1). |
| `proof` | string | REQUIRED | JWT for OIDC; for pinned_key, a JCS-profile signature in the [RFC-AITP-0001 §5.4.3](RFC-AITP-0001-core.md#543-algorithm-tagged-signature-wire-format-jcs-profile-only) wire format, Ed25519 or P-256 (§3.1). For `spiffe`, a JWT-SVID (§6.3) or a signature by the X509-SVID key (§6.4). |
| `public_key` | string | REQUIRED for `pinned_key`; MUST be absent for `oidc` and `spiffe` | base64url-encoded public key. For `pinned_key`, this is the key the verifier looks up in its `pinned_keys` configuration (§3.2). For `oidc`, the agent's public key is already encoded in the verifying-peer envelope's `sender.agent_id` (the AID-identifier component) — there is no second copy in the descriptor, and including one would create an ambiguity over which key the JWT's `cnf.jkt` is meant to bind. The identity-descriptor schema (`schemas/json/aitp-identity.schema.json`) enforces this: its `oidc` branch forbids `public_key`, mirroring the `IdentityHint` rule that the Manifest schema applies to `identity_hint`. v0.3 verifiers MUST reject an OIDC `identity` descriptor that carries `public_key`. |
| `svid_type` | string | REQUIRED for `spiffe`; MUST be absent otherwise | `jwt-svid` or `x509-svid`: which SVID form backs `proof` (§6.1). |
| `x5c` | array of strings | REQUIRED for `spiffe` with `svid_type` `x509-svid`; MUST be absent otherwise | The X509-SVID and its intermediates, leaf first (§6.4). |
| `extensions` | object | OPTIONAL | Extension namespace per [RFC-AITP-0001 §7](RFC-AITP-0001-core.md#7-compatibility-model) and [RFC-AITP-0012](RFC-AITP-0012-extensions.md). Unknown keys *inside* `extensions` MUST be ignored; unknown members *outside* it are rejected with `UNKNOWN_FIELD`. The identity descriptor is **not** an exception to §7's "every signed object reserves an `extensions` slot" — it reserves one like every other signed object, in both the standalone and the handshake-embedded form. |

The canonical JSON Schema is [`schemas/json/aitp-identity.schema.json`](../schemas/json/aitp-identity.schema.json).

> **One descriptor, two schema files.** The canonical schema above is authoritative.
> [`schemas/json/aitp-mutual-handshake.schema.json`](../schemas/json/aitp-mutual-handshake.schema.json)
> carries a `$defs/IdentityDescriptor` **mirror** of it, because every schema in this repo is
> self-contained — none resolves a cross-file `$ref`, so an offline validator needs exactly one
> fetch per artifact. The mirror is a copy, not a second definition: it MUST equal the canonical
> file minus that file's `$schema`/`$id`/`title`/`examples` metadata, and
> [`scripts/check-doc-coherence.sh`](../scripts/check-doc-coherence.sh) stage 5 fails the build if
> the two drift. Implementers MUST follow the canonical file; a descriptor that validates
> standalone validates identically inside a handshake payload.
>
> The two had drifted (issue #40). The embedded copy was missing the `extensions` slot, the
> `public_key` grammar, and the `not: {required: [public_key]}` guard that enforces this section's
> MUST-reject rule for an OIDC descriptor carrying `public_key` — so that MUST went unenforced in
> the only path where the descriptor actually travels. Both are now the same object.

> **Note on `proof` inputs.** The proof input differs by type. For `oidc`, `proof` is a self-contained JWT (§2). For `pinned_key`, `proof` is a signature whose input binds fields drawn from the surrounding handshake envelope (§3.1) — including the `pop_nonce` carried on `MUTUAL_HELLO` / `MUTUAL_HELLO_ACK` (RFC-AITP-0004 §3). The descriptor itself does NOT carry the nonce; verifiers reconstruct the proof input from the envelope and the local `receiver_aid`. The pinned-key `subject` is not covered by `proof`; it is authenticated only by the enclosing envelope signature.

> **Note on P-256 pinned keys (informative).** `pinned_key` is not Ed25519-only. A Manifest `identity_hint` of type `pinned_key` whose `public_key` is the 44-char compressed P-256 identifier of an `aid:pubkey:p256:` AID is valid, and so is the matching handshake descriptor (§3.1, §3.3).

---

## 2. OIDC Identity Type

### 2.1 Proof format

`proof` MUST be a compact-serialized JWT ([RFC 7519](https://datatracker.ietf.org/doc/html/rfc7519)) issued by `issuer`.

### 2.2 Required JWT claims

| Claim | Description |
|---|---|
| `iss` | MUST match `identity.issuer`. |
| `sub` | MUST match `identity.subject`. |
| `aud` | MUST equal the verifying peer's AID (`aid:<method>:<identifier>`). Prevents replay of a JWT from one peer to another. |
| `exp` | MUST be in the future. |
| `iat` | MUST be within ±300 s of current time. |
| `nonce` | MUST equal the `pop_nonce` value carried on the same handshake message (`MUTUAL_HELLO` for the initiator's identity, `MUTUAL_HELLO_ACK` for the target's identity, per RFC-AITP-0004 §3). Binds the JWT to a specific handshake instance and prevents replay of the same JWT in a different session, even between the same `iss`/`sub`/`aud` triple. The `pop_nonce` is a 128-bit base64url string; the JWT carries it byte-identically (no decoding, no re-encoding). |
| `cnf.jkt` | MUST equal the [RFC 7638](https://datatracker.ietf.org/doc/html/rfc7638) JWK thumbprint of the public key encoded in the agent's `aid` (the same key that signed the agent's Manifest). Binds the JWT to the AID's signing key, preventing reuse with a different key pair (DPoP-style binding, per [RFC 9449 §6](https://datatracker.ietf.org/doc/html/rfc9449)). The thumbprint input is pinned in §2.2.1 below. |

The `aud`, `nonce`, and `cnf.jkt` requirements are AITP-specific reuses of standard JWT claims. They impose **no protocol changes on the identity provider** — any OIDC IdP that supports the standard `aud` and `nonce` claims and a `cnf` confirmation method (RFC 7800) can issue conformant JWTs.

#### 2.2.1 Canonical JWK form for `cnf.jkt`

The JWK used to compute `cnf.jkt` is the canonical JWK of the agent AID's public key in that AID's own algorithm, per [RFC-AITP-0001 §5.4.4](RFC-AITP-0001-core.md#544-jwk-thumbprint-for-cnf). The two v0.3 algorithms (RFC-AITP-0001 §5.3) give exactly these two forms:

- **Ed25519 AID** (`aid:pubkey:<identifier>` or `aid:pubkey:ed25519:<identifier>`). The OKP form, exactly:

  ```json
  {"crv":"Ed25519","kty":"OKP","x":"<aid-identifier>"}
  ```

  where `<aid-identifier>` is the 43-character identifier component of the AID, i.e. the unpadded base64url encoding of the 32-byte raw Ed25519 public key.

- **P-256 AID** (`aid:pubkey:p256:<identifier>`). The EC form, exactly:

  ```json
  {"crv":"P-256","kty":"EC","x":"<x>","y":"<y>"}
  ```

  where `<x>` and `<y>` are the unpadded base64url encodings of the 32-byte big-endian affine coordinates of the point obtained by decompressing the 33-byte SEC1 compressed point that the AID's 44-character identifier encodes. Each is 43 characters. The compressed identifier itself never appears in the JWK.

The thumbprint is computed per RFC 7638: serialize the JSON object for the AID's algorithm with its members in lexicographic order (`crv`, `kty`, `x` for OKP; `crv`, `kty`, `x`, `y` for EC), no whitespace, hash with SHA-256, encode the digest as unpadded base64url. Implementations MUST NOT include any other JWK members (no `kid`, no `alg`, no `use`) when computing the thumbprint — additional members would change the canonical serialization and the resulting hash. A verifier MUST derive the JWK form from the algorithm of the AID it is checking; computing the OKP form for a P-256 AID, or the reverse, yields a thumbprint that MUST NOT match.

> **Shared convention with the portable trust artifacts.** In `aitp/0.3` this same RFC 7638 `cnf.jkt` convention is also the proof-of-possession key binding on the compact-JWS portable trust artifacts — the TCT and the delegation token ([RFC-AITP-0001 §5.4.4](RFC-AITP-0001-core.md#544-jwk-thumbprint-for-cnf), which cites this section). The v0.1 raw-public-key `binding.cnf` form on the TCT no longer exists; identity binding and token binding now use one `cnf.jkt` convention.

> **Known-answer test.** For the pinned all-zero-seed Ed25519 keypair (`kat-keypair-001` in [`schemas/conformance/known-answer/keypairs.json`](../schemas/conformance/known-answer/keypairs.json)), `aid-identifier = O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik`, the canonical JWK input is `{"crv":"Ed25519","kty":"OKP","x":"O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik"}` (87 bytes), and the resulting `jkt` MUST be `9ZP03Nu8GrXPAUkbKNxHOKBzxPX83SShgFkRNK-f2lw`. For the pinned P-256 keypair (`kat-keypair-005-p256`), `aid = aid:pubkey:p256:AweBDql0zqV3PmO4l_N-O-mgnnpf6blxpE0QZawqOpMR`, the canonical JWK input is `{"crv":"P-256","kty":"EC","x":"B4EOqXTOpXc-Y7iX83476aCeel_puXGkTRBlrCo6kxE","y":"Y35HpPmUZKD9zkSojsfXA6kYPB0GVS2eLWt2BpSBxXc"}` (126 bytes), and the resulting `jkt` MUST be `6uuEaX_87uMh4VKEtSDkENgjC0g7Evt6vliSnD7XSDE` (`kat-jwk-thumb-005-p256`). Additional vectors live at [`schemas/conformance/known-answer/jwk-thumbprints.json`](../schemas/conformance/known-answer/jwk-thumbprints.json). Conformance fixture `id-023` is an OIDC identity binding whose agent AID is this P-256 key.

### 2.3 Verification steps

A peer verifying an identity binding MUST:

1. Resolve the issuer's public keys (see [RFC-AITP-0007](RFC-AITP-0007-key-resolution.md)).
2. Verify the JWT signature against the resolved keys.
3. Validate that `iss` matches the identity descriptor's `issuer`.
4. Validate `exp` is in the future.
5. Validate `iat` is within the timestamp tolerance.
6. **Validate `aud` equals the verifying peer's own AID.** Reject otherwise. This defeats cross-peer JWT replay.
7. **Validate `nonce` equals the `pop_nonce` from the surrounding handshake message** (`MUTUAL_HELLO` or `MUTUAL_HELLO_ACK`, whichever carried this identity). Reject otherwise. This defeats same-peer JWT replay across handshakes.
8. **Validate `cnf.jkt`.** Compute the JWK thumbprint (RFC 7638) of the public key encoded in the agent's AID; the JWT's `cnf.jkt` MUST equal that thumbprint. Reject otherwise. This binds the identity proof to the AID's signing key.
9. Confirm `issuer` appears in the local `trust_anchors` configuration (or in the peer's Manifest `accepted_trust_anchors` for the converse direction).

Peers MUST NOT accept JWTs from issuers not present in `trust_anchors`. Peers MUST NOT accept JWTs missing `aud`, `nonce`, or `cnf.jkt`.

### 2.4 Example

A decoded JWT payload (claims) for an OIDC identity binding presented by Agent A to Agent B (using the `kat-keypair-002` AID from [`schemas/conformance/known-answer/keypairs.json`](../schemas/conformance/known-answer/keypairs.json) for B):

```json
{
  "iss": "https://auth.openai.com",
  "sub": "agent-gpt4-instance-xyz",
  "aud": "aid:pubkey:A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg",
  "iat": 1711900000,
  "exp": 1711903600,
  "nonce": "AxwAx0m1v63X7ZsDG-3Npg",
  "cnf": {
    "jkt": "9ZP03Nu8GrXPAUkbKNxHOKBzxPX83SShgFkRNK-f2lw"
  }
}
```

The `aud` is B's AID exactly as B's AID is written, in whatever algorithm form it has (RFC-AITP-0001 §5.3): here the untagged Ed25519 form, `aid:pubkey:` followed by 43 unpadded-base64url characters; for a P-256 verifier it would be `aid:pubkey:p256:` followed by 44. The `aud` comparison is byte-for-byte; a verifier MUST NOT rewrite either side to another form of the same key. The `nonce` is the byte-identical `pop_nonce` from the corresponding `MUTUAL_HELLO` payload. The `cnf.jkt` is the RFC 7638 thumbprint of A's AID public key, computed per §2.2.1.

Wrapped in the identity descriptor:

```json
{
  "identity": {
    "type": "oidc",
    "issuer": "https://auth.openai.com",
    "subject": "agent-gpt4-instance-xyz",
    "proof": "<compact-serialized JWT carrying the claims above>"
  }
}
```

---

## 3. Pinned Key Identity Type

### 3.1 Proof format

`proof` is a signature over the full handshake context — sender, receiver, message identity, timestamp, and the per-handshake `pop_nonce` — using the agent's private key. Binding all five fields prevents a captured signature from being replayed against a different sender, receiver, message, or handshake.

```
proof_input =
    "aitp-pinned-key-v1\0"
    || sender_aid_bytes      || "\0"
    || receiver_aid_bytes    || "\0"
    || message_id_bytes      || "\0"
    || timestamp_ascii_decimal || "\0"
    || pop_nonce_decoded_bytes
proof = base64url(sign(agent_private_key, sha256(proof_input)))
```

`proof` uses the JCS-profile signature wire format of [RFC-AITP-0001 §5.4.3](RFC-AITP-0001-core.md#543-algorithm-tagged-signature-wire-format-jcs-profile-only), with the primitive of [§5.4.6](RFC-AITP-0001-core.md#546-signing-primitive-per-algorithm-jcs-profile-and-proofs).

- A `p256` sender MUST emit the tagged form `p256.<86-char-b64url>`.
- An `ed25519` sender MAY emit either the legacy untagged form or `ed25519.<86-char-b64url>`.
- The tag MUST match the algorithm of `sender.agent_id`, per §5.4.3 rule 3. An untagged proof is read as `ed25519`, so an untagged proof from a `p256` sender is an algorithm mismatch and is rejected with `IDENTITY_FAILED`, whatever its raw bytes would verify as.

`sign` is the per-algorithm primitive of [RFC-AITP-0001 §5.4.6](RFC-AITP-0001-core.md#546-signing-primitive-per-algorithm-jcs-profile-and-proofs): `sha256(proof_input)` is the digest `d`, hashed exactly once. An Ed25519 key signs `d` as its message; a P-256 key uses `d` directly as the ECDSA hashed message (`e = d`) and MUST NOT hash it again.

Where:

- `sender_aid_bytes` is the UTF-8 encoding of the full `aid:pubkey:...` string of the signing peer.
- `receiver_aid_bytes` is the UTF-8 encoding of the full `aid:pubkey:...` string of the receiving peer.
- `message_id_bytes` is the UTF-8 encoding of the envelope's `message_id` UUID string in canonical lowercase form (RFC-AITP-0001 §5.2).
- `timestamp_ascii_decimal` is the UTF-8 encoding of the envelope's `timestamp` as its base-10 ASCII decimal string (e.g. `1711900000` → `b"1711900000"`), matching how `message_id` is likewise encoded as a string rather than binary-packed.
- `pop_nonce_decoded_bytes` is the raw bytes obtained by base64url-decoding the handshake's `pop_nonce` (NOT the base64url string itself).
- `\0` is a single null byte separator.

> **Erratum.** This section's text stated, through `0.2.1-draft`, that `timestamp` was encoded as `timestamp_be_8_bytes` — an 8-byte big-endian signed 64-bit integer — contradicting how this section reads now. The pinned proof in this repository's conformance pack (`id-007`'s real Ed25519 signature over `kat-keypair-003`, reused verbatim as `kat-pinned-key-proof-001` below) has been ASCII-decimal-encoded since the original conformance commit; it was never re-signed to produce this correction. No pinned bytes changed — the prose moved to match the artifact, not the other way around. That said, this is **not** a no-op for implementations: an implementation that built its proof input by following the old `timestamp_be_8_bytes` text produces a different signature than one that follows the pinned vector, and MUST switch encodings to interoperate. `id-007` alone never surfaced this, because its expected outcome is rejection at §3.2 step 3 (the public key is absent from the local `pinned_keys` store) before proof verification is ever reached — a big-endian implementation could pass `id-007`, and the rest of the v0.2 conformance pack, without the defect being caught. `kat-pinned-key-proof-001` closes that gap: it pins `proof_input`, the Ed25519 signature over `sha256(proof_input)`, and additionally pins that the same signature does NOT verify when `timestamp` is instead packed as an 8-byte big-endian integer, making the encoding machine-checkable rather than a matter of reading the prose. See `CHANGELOG.md` for the old and new values.

> **Replay resistance.** v0.3 pinned-key proofs are bound to the full handshake context — the same five fields v0.1 bound (sender, receiver, message, timestamp, nonce); only `timestamp`'s on-the-wire encoding within the proof input changed, per the erratum above. A signature produced for one (sender, receiver, message, timestamp, nonce) tuple cannot be replayed against a different tuple.

> **Known-answer test.** The `kat-pinned-key-proof-001` vector in [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json) pins a concrete `(sender, receiver, message_id, timestamp, pop_nonce)` tuple, the resulting `proof_input` bytes, and the Ed25519 signature over `sha256(proof_input)` produced with `kat-keypair-003`. It also pins that the same signature does NOT verify when `timestamp` is instead encoded as an 8-byte big-endian integer, so the ASCII-decimal encoding is machine-checkable rather than a matter of prose interpretation. Two more vectors in the same file cover the other wire forms. `kat-pinned-key-proof-002-p256` is a `p256.`-tagged proof from the `kat-keypair-005-p256` AID, with a double-hash signature that MUST NOT verify. `kat-pinned-key-proof-003-tagged-ed25519` is an Ed25519 proof from the `aid:pubkey:ed25519:` spelling of `kat-keypair-003`; its `proof_input` differs from `-001`'s because the sender AID string is part of the input.

### 3.2 Verification steps

A peer verifying a pinned-key identity binding MUST:

1. Confirm `identity.type` is `pinned_key`. A verifier MUST NOT run pinned-key verification on a descriptor of any other `type`, even if it carries `public_key` and a well-formed `proof`.
2. Decode `public_key` and confirm it is byte-equal to the key encoded in `sender.agent_id`, under the same algorithm. A legacy untagged AID compares as `ed25519`.
3. Locate `(algorithm, public_key)` in the local `pinned_keys` configuration. Trust-store entries are keyed by the pair, never by raw bytes alone.
4. Reconstruct `proof_input` (§3.1), drawing each field from the inbound envelope (`sender.agent_id`, the verifying peer's own AID as `receiver`, `message_id`, `timestamp`) and the handshake message's `pop_nonce`.
5. Verify `proof` per [RFC-AITP-0001 §5.4.3](RFC-AITP-0001-core.md#543-algorithm-tagged-signature-wire-format-jcs-profile-only) and [§5.4.6](RFC-AITP-0001-core.md#546-signing-primitive-per-algorithm-jcs-profile-and-proofs) against that key.

Steps 1–3 MUST complete before any signature verification.

A failure at any step is `IDENTITY_FAILED`.

#### Trust-store requirement

Verifying that a peer's key "matches its AID" (key-possession proof
alone) is **not** sufficient. AID construction is deterministic from the
public key (RFC-AITP-0001 §5.3), so any agent can construct an AID for
any key it generates. The trust anchor is the **local pinned-key
configuration**, not the AID derivation; possession of a key tells you
only that the holder generated that AID, not that the AID is one you
have ever decided to trust.

Implementations MUST NOT offer a key-possession-only verification mode,
in any deployment mode, development and test included. Every pinned-key
verification MUST consult a configured `pinned_keys` store (step 3) and
reject any pinned-key identity whose `(algorithm, public_key)` is not
present in that store, regardless of how cryptographically sound the
proof signature is. An empty store trusts no pinned key.

### 3.3 Example

The `public_key` MUST be the unpadded-base64url AID-identifier form of RFC-AITP-0001 §5.3 for the sender AID's algorithm: 43 chars (32 raw bytes) for `ed25519`, or 44 chars (33-byte SEC1 compressed point) for `p256`. SPKI-DER, PEM, JWK and uncompressed-point forms are not permitted. A `p256` `public_key` MUST decode to a valid point on the curve. A verifier MUST reject the descriptor with `IDENTITY_FAILED` when the point is invalid or is the identity.

```json
{
  "identity": {
    "type": "pinned_key",
    "subject": "internal-worker-agent-1",
    "public_key": "dqFZIESm5PURJlvKc6YE2QsFKdHfYCvjChmpJXZg0fU",
    "proof": "<base64url signature, 86 chars unpadded, computed per §3.1>"
  }
}
```

A `p256` sender's descriptor carries the 44-char compressed key and a tagged proof (the values of `kat-pinned-key-proof-002-p256`):

```json
{
  "identity": {
    "type": "pinned_key",
    "subject": "internal-worker-agent-2",
    "public_key": "AweBDql0zqV3PmO4l_N-O-mgnnpf6blxpE0QZawqOpMR",
    "proof": "p256.<86-char base64url r || s, computed per §3.1>"
  }
}
```

### 3.4 One-way pinned-key admission (OPTIONAL profile `pinned-admission`)

The pinned-key identity of §3.1–§3.3 is otherwise presented only inside the four-message Mutual Handshake ([RFC-AITP-0004](RFC-AITP-0004-mutual-handshake.md)). Some deployments admit agents to a single verifier and need no TCT in return, for example a gateway, a coordination host or a resource server. For them this section defines a one-way profile: the verifier issues a challenge and the subject answers with one presentation envelope.

Inside the handshake, the envelope signature over the payload authenticates the descriptor's `type`, `subject` and `extensions`. The §3.1 proof alone covers only the five-field tuple. A standalone presentation therefore travels in an envelope, so that the envelope signature authenticates the descriptor in the same way.

A verifier MAY admit a subject without a Mutual Handshake when all of the following hold:

1. **Challenge.** The verifier issues a fresh `pop_nonce` of 16 bytes drawn from a CSPRNG ([RFC-AITP-0001 §11](RFC-AITP-0001-core.md#11-security-considerations)). The nonce is single-use, expires at most 300 seconds after issuance, and is bound to the verifier's own AID.
2. **Presentation.** The subject returns an [RFC-AITP-0001 §5](RFC-AITP-0001-core.md#5-message-envelope) envelope with `message_type` `identity_presentation`, whose `payload` is exactly `{identity, pop_nonce}`. The envelope signature ([RFC-AITP-0001 §5.4](RFC-AITP-0001-core.md#54-signature)) covers the whole envelope except `signature`, so it authenticates the descriptor's `type`, `subject` and `extensions` inside `payload`, and the envelope's own `message_type`, `version` and `extensions`. The verifier MUST reject an envelope whose `message_type` is not `identity_presentation` with `INVALID_ENVELOPE`. The `proof` is computed per §3.1 with `receiver_aid_bytes` taken from the verifier's AID and `pop_nonce_decoded_bytes` from the challenge nonce.
3. **Verification.** The verifier runs §3.2 steps 1–5 and the [RFC-AITP-0001 §5.5](RFC-AITP-0001-core.md#55-replay-protection) timestamp and `message_id` rules. A configured `pinned_keys` store is REQUIRED, per the §3.2 trust-store requirement.
4. **Consumption.** The verifier consumes the nonce atomically before it returns success.

A party that implements only this profile, as verifier or as presenter, MAY claim "AITP v0.3 pinned-admission" conformance. It MUST NOT claim conformance to [RFC-AITP-0001 §10](RFC-AITP-0001-core.md#10-conformance), which requires the Mutual Handshake and TCT issuance among other things.

#### Challenge and nonce rules

- `pop_nonce` MUST decode to exactly 16 bytes. A verifier MUST reject any other length with `IDENTITY_FAILED`, before any signature verification.
- A verifier accepts a nonce only if all three hold: it issued that nonce in a challenge whose `verifier_aid` (see the challenge format below) is the verifier's own AID, the AID the §3.1 proof uses as `receiver_aid_bytes`; the nonce has not expired; and it has not been consumed. Any other nonce is rejected with `IDENTITY_FAILED`, including a nonce the verifier issued with a different AID as the challenge's `verifier_aid`, for example under another AID it operates. Lookup and consumption MUST be one atomic step, so that two presentations racing on one nonce cannot both succeed.
- The atomic lookup-and-consume MUST run after every signature check has passed, so a forged presentation cannot burn a legitimate presenter's nonce. A verifier MAY also run a non-consuming lookup before signature verification, to shed presentations for unknown nonces cheaply.
- A consumed nonce is never accepted again, even with a fresh `message_id`. The `message_id` deny list alone does not stop that replay.
- The verifier MUST bound the number of outstanding nonces. When the bound is reached it MUST refuse new challenges with `CHALLENGE_REFUSED` (retryable), and MUST NOT evict unexpired nonces to make room: eviction would let one source cancel challenges already issued to others.
- The verifier MUST apply per-source rate limiting to challenge issuance and to presentations, as [RFC-AITP-0009 §3.1](RFC-AITP-0009-security.md#31-rate-limiting) requires at the handshake endpoint, with the same source-key rules. Within this profile, the verifier MUST answer a rate-limited challenge request or presentation with HTTP 429 and no AITP error envelope. This profile tightens RFC-AITP-0009 §3.1, which only RECOMMENDS (SHOULD) HTTP 429 at the handshake endpoint; the core handshake is unchanged.
- `message_id` follows [RFC-AITP-0005 §2.2](RFC-AITP-0005-tct.md#22-identifier-layout-jti). It MAY be derived from `pop_nonce` (with a tag registered in [`registries/jti-domain-tags.md`](../registries/jti-domain-tags.md)), since the nonce is already single-use.

#### Challenge format (informative)

The challenge is not an AITP envelope, and its transport is a deployment choice (an HTTP response body, for example). One suggested shape is:

```json
{
  "pop_nonce": "AQIDBAUGBwgJCgsMDQ4PEA",
  "verifier_aid": "aid:pubkey:O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik",
  "expires_at": 1711900250
}
```

`verifier_aid` tells the presenter which AID to use as `receiver_aid_bytes`. A rate-limited challenge request or presentation MUST get HTTP 429, per the rate-limiting rule above.

A refused challenge returns `CHALLENGE_REFUSED`. The challenge is not an envelope, so the refusal is not an AITP error envelope either: it travels in the challenge's own transport. Over HTTP, one suggested mapping is status 503 with a `Retry-After` header and the JSON body:

```json
{"error": "CHALLENGE_REFUSED"}
```

Whatever the transport, a `CHALLENGE_REFUSED` refusal (the verifier's outstanding-nonce bound is reached, for every source) MUST be distinguishable by the client from a per-source HTTP 429 (this source is over its limit). The HTTP mapping above is informative, like the challenge format.

#### Check order

The verifier MUST process a presentation in this order:

1. **`message_id` deny list** (RFC-AITP-0001 §5.5) ⇒ `REPLAY_DETECTED`. As at the handshake endpoint, a replay does not consume a rate-limit slot.
2. **Per-source rate limit** (RFC-AITP-0009 §3.1) ⇒ HTTP 429 with no AITP error envelope. Within this profile 429 is REQUIRED (see the rate-limiting rule above).
3. **Timestamp window** (RFC-AITP-0001 §5.5) ⇒ `TIMESTAMP_EXPIRED`.
4. **Envelope structure**, in the RFC-AITP-0001 §5.4 envelope check order: an unknown `version` first ⇒ `UNKNOWN_VERSION`; then schema-valid, `message_type` is `identity_presentation`, payload members exactly `identity` and `pop_nonce` ⇒ `INVALID_ENVELOPE` (`UNKNOWN_FIELD` when the only defect is an unknown member).
5. **Nonce length**: `pop_nonce` decodes to 16 bytes ⇒ `IDENTITY_FAILED`.
6. **§3.2 steps 1–3**: `type`, key equality and the `pinned_keys` lookup ⇒ `IDENTITY_FAILED`.
7. **Envelope signature** (RFC-AITP-0001 §5.4) ⇒ `INVALID_SIGNATURE`.
8. **§3.2 steps 4–5**: the proof over the tuple ⇒ `IDENTITY_FAILED`.
9. **Atomic nonce lookup-and-consume** ⇒ `IDENTITY_FAILED`.

On success the verifier records the `message_id` in its deny list and admits the subject. The result is an admission decision local to this verifier. No TCT is issued, and the presentation confers no capability on any other peer.

> **Conformance fixtures.** `id-019` is a passing presentation with a real §3.1 proof. `id-013` presents a consumed nonce again under a fresh `message_id`, `id-014` presents a 15-byte nonce, and `id-015` sends `id-019`'s presentation with only `message_type` changed; the proof still verifies there, because the proof does not cover `message_type`. `id-016` fills a two-nonce store and has the third challenge refused. It then presents both outstanding nonces successfully, and the refused source's retry succeeds. `id-020` presents an expired nonce and `id-021` a nonce whose challenge named a different `verifier_aid`; both carry real proofs, so they fail only at step 9. `id-022` replays an admitted presentation from a source that is also over its rate limit: the deny list answers first with `REPLAY_DETECTED`, and the source's next fresh presentation gets exactly HTTP 429. These eight fixtures are `status: extension` under `feature: aitp-pinned-admission`. Atomic consumption under concurrent presentations is not expressible as a sequential fixture. `tct-015`, `tct-016`, `tct-018`, `tct-019`, `tct-020` and `tct-021` ([RFC-AITP-0005 §5.3](RFC-AITP-0005-tct.md#53-self-issued-attestation-tcts)) cover the self-attestation side.

---

## 4. Trust Anchors

Trust anchors are locally configured by each agent. A peer MUST NOT accept identity from issuers not present in its configured trust anchors. The same list also surfaces in the agent's Manifest (`accepted_trust_anchors`, RFC-AITP-0003), so peers can pre-screen for compatibility before initiating a handshake.

```yaml
trust_anchors:
  - issuer: "https://auth.openai.com"
    keys:
      - "base64url_pubkey_1"
      - "base64url_pubkey_2"

pinned_keys:
  - subject: "internal-worker-agent-1"
    algorithm: "ed25519"          # OPTIONAL; ed25519 | p256
    public_key: "base64url_pubkey"
    allowed_capabilities:
      - "macp.mode.task.v1"

spiffe_bundles:                   # spiffe identity type only (§6.2)
  - trust_domain: "prod.example.com"
    bundle:                       # SPIFFE bundle: an RFC 7517 JWK Set
      keys:
        - { kty: "EC", use: "jwt-svid", kid: "...", crv: "P-256", x: "...", y: "..." }
        - { kty: "EC", use: "x509-svid", crv: "P-256", x: "...", y: "...", x5c: ["..."] }
```

`pinned_keys` entries are keyed by `(algorithm, public_key)` (§3.2 step 3). `algorithm` is OPTIONAL: when absent it is inferred from the key length (43 chars is `ed25519`, 44 chars is `p256`), and when present it MUST agree with that length.

The canonical schema is [`schemas/json/aitp-trust-anchors.schema.json`](../schemas/json/aitp-trust-anchors.schema.json).

### 4.1 Distribution modes

| Mode | Description |
|---|---|
| `static_config` | Keys baked into deployment config (RECOMMENDED for v0.3). |
| `well_known_endpoint` | Fetched from `https://<issuer>/.well-known/aitp-keys`. |
| `out_of_band` | Manually provisioned (air-gapped / offline environments). |

See [RFC-AITP-0007 Key Resolution](RFC-AITP-0007-key-resolution.md) for resolution order and failure handling.

---

## 5. Future Identity Types

The following identity types are reserved:

| Type | Description |
|---|---|
| `did` | W3C Decentralized Identifier with Verifiable Credential. |
| `x509` | X.509 certificate chain (Web PKI). |
| `wallet` | Blockchain-wallet signature. |

`x509` stays reserved for Web PKI certificates. A SPIFFE X509-SVID is not an `x509` identity: it is the `x509-svid` form of the `spiffe` type (§6).

Peers receiving an unknown `type` MUST respond with `IDENTITY_FAILED`. New types are registered via the RFC process and recorded in [`registries/identity-types.md`](../registries/identity-types.md).

---

## 6. SPIFFE Identity Type

The `spiffe` type binds an AID to a [SPIFFE](https://spiffe.io/) workload identity. The identity is a SPIFFE ID, proven by an SVID (SPIFFE Verifiable Identity Document) that chains to the SPIFFE trust bundle of the ID's trust domain. Two SVID forms are defined:

- A JWT-SVID ([JWT-SVID](https://github.com/spiffe/spiffe/blob/49a9cbbc018c39ec6643ad3301632f9f4549258b/standards/JWT-SVID.md)) is checked much like the OIDC JWT of §2.
- An X509-SVID ([X509-SVID](https://github.com/spiffe/spiffe/blob/49a9cbbc018c39ec6643ad3301632f9f4549258b/standards/X509-SVID.md)) is checked in two parts: path validation of its certificate chain, and a signature by its key over the handshake context.

This section cites the SPIFFE standards at commit `49a9cbbc018c39ec6643ad3301632f9f4549258b` of [`spiffe/spiffe`](https://github.com/spiffe/spiffe). Where this section says less than those standards, the standards apply. Where it says more, the extra rule is an AITP rule and is marked **Tightening**.

`spiffe` is at registry status **Proposed** ([`registries/identity-types.md`](../registries/identity-types.md)):

- Its conformance fixtures, `id-024` to `id-030`, are `status: draft` under `feature: experimental-spiffe-identity`.
- `kat-spiffe-x509-proof-001` pins the §6.4.1 proof input.
- No RFC-AITP-0001 §10 claim requires a verifier to support `spiffe`. A verifier that does not support it treats it like any other type it does not accept (§6.6).

### 6.1 Descriptor

```json
{
  "identity": {
    "type": "spiffe",
    "subject": "spiffe://prod.example.com/ns/payments/sa/agent",
    "svid_type": "jwt-svid | x509-svid",
    "proof": "<JWT-SVID (§6.3) or X509-SVID key signature (§6.4.1)>",
    "x5c": ["<leaf>", "<intermediate>", "..."]
  }
}
```

- `subject` MUST be a SPIFFE ID ([SPIFFE-ID](https://github.com/spiffe/spiffe/blob/49a9cbbc018c39ec6643ad3301632f9f4549258b/standards/SPIFFE-ID.md) §2): the scheme `spiffe`, a trust domain, and a path, with no query, fragment, port or userinfo.
  - The trust domain MUST use only lowercase letters, digits, `.`, `-` and `_`, and be at most 255 bytes (SPIFFE-ID §2.1, §2.3).
  - The path MUST be non-empty and MUST NOT end in `/`. Each segment uses only letters, digits, `.`, `-` and `_`, and MUST NOT be empty, `.` or `..` (SPIFFE-ID §2.2).
  - The whole ID is at most 2048 bytes (SPIFFE-ID §2.3).
  - A SPIFFE ID with no path names a trust domain, not a workload, so it is not a valid `subject`. This matches X509-SVID §3.1, which requires a non-root path on a leaf SVID.
  - SPIFFE compares the scheme and trust domain case-insensitively and the path case-sensitively (SPIFFE-ID §2.4). **Tightening:** `subject` MUST be in canonical form, with the scheme and trust domain in lowercase, and every comparison in this section is byte-for-byte. A verifier MUST reject a `subject` with an uppercase scheme or trust domain with `IDENTITY_FAILED`. It MUST NOT fold case to make a comparison match.
- `svid_type` is REQUIRED:
  - `jwt-svid`: `proof` is a JWT-SVID (§6.3).
  - `x509-svid`: `proof` is a signature by the X509-SVID's key, and `x5c` carries the certificates (§6.4).
- `x5c` is REQUIRED when `svid_type` is `x509-svid`, and MUST be absent otherwise.
  - Each entry is a DER certificate in standard base64 with padding ([RFC 4648 §4](https://datatracker.ietf.org/doc/html/rfc4648#section-4)), as in the JWK `x5c` member ([RFC 7517 §4.7](https://datatracker.ietf.org/doc/html/rfc7517#section-4.7)).
  - The first entry is the X509-SVID (the leaf). Any further entries are intermediate CA certificates, each certifying the one before it.
- `issuer` and `public_key` MUST be absent. A `spiffe` descriptor's trust anchor is the local SPIFFE bundle of its trust domain (§6.2), not an issuer URI. Its key binding comes from the SVID, not from a copied key.
- `extensions` is as in §1.

The identity-descriptor schema enforces these rules in its `spiffe` branch. It cannot express the byte-exact canonical form or any certificate rule; those are verifier checks.

### 6.2 Trust bundles

The verifier holds a local `spiffe_bundles` store: a list of `{trust_domain, bundle}` entries in its trust-anchors configuration (§4, [`schemas/json/aitp-trust-anchors.schema.json`](../schemas/json/aitp-trust-anchors.schema.json)).

- `bundle` is a SPIFFE bundle: an [RFC 7517](https://datatracker.ietf.org/doc/html/rfc7517) JWK Set ([SPIFFE Trust Domain and Bundle](https://github.com/spiffe/spiffe/blob/49a9cbbc018c39ec6643ad3301632f9f4549258b/standards/SPIFFE_Trust_Domain_and_Bundle.md) §4). It MAY carry `spiffe_sequence` and `spiffe_refresh_hint` members (Trust Domain and Bundle §4.1.1, §4.1.2).
- Trust domain names MUST be unique in the store. A verifier MUST reject a configuration that lists one trust domain twice, as SPIFFE requires of a bundle map (Trust Domain and Bundle §5.1.1).
- The verifier selects the bundle by the trust domain of `subject`, and uses only that bundle (Trust Domain and Bundle §3). A key from another trust domain's bundle MUST NOT validate the SVID, even when its signature would verify.
- Bundle keys are selected by `use`:
  - A JWK with `use` `jwt-svid` is a JWT-SVID signing key and carries a `kid` (JWT-SVID §6.1).
  - A JWK with `use` `x509-svid` is an X.509 CA and carries exactly one CA certificate in `x5c` (X509-SVID §6.1).
  - A JWK whose `use` is missing or unknown is ignored (Trust Domain and Bundle §4.2.2).
- If the bundle has no keys of the `use` an SVID needs, every SVID of that form from the trust domain is invalid (Trust Domain and Bundle §4.1.3, JWT-SVID §6.2).
- The bundle MUST come from the verifier's own configuration, or from a source the verifier trusts on its own account, such as its SPIFFE Workload API or a configured SPIFFE federation endpoint. A verifier MUST NOT take a bundle or any other trust material from the peer's handshake message or Manifest.

### 6.3 JWT-SVID

`proof` is a JWT-SVID: a compact JWS ([JWT-SVID](https://github.com/spiffe/spiffe/blob/49a9cbbc018c39ec6643ad3301632f9f4549258b/standards/JWT-SVID.md) §2, §5.1) signed by a `jwt-svid` key of the subject trust domain's bundle. The checks follow the OIDC checks of §2, with the bundle in place of the issuer's keys.

| Item | Rule |
|---|---|
| Serialization | Compact JWS. The protected header MUST contain only `alg`, `kid` and `typ` (JWT-SVID §2). |
| `alg` | One of `RS256`, `RS384`, `RS512`, `ES256`, `ES384`, `ES512`, `PS256`, `PS384`, `PS512` (JWT-SVID §2.1). Any other value MUST be rejected, `none`, `HS*` and `EdDSA` included. |
| `kid` | **Tightening:** REQUIRED (JWT-SVID §2.2 makes it optional). It selects the verification key: the `jwt-svid` JWK with this `kid` in the bundle, which JWT-SVID §6.1 requires to carry a `kid`. If no JWK matches, verification fails. The verifier MUST NOT try other keys. |
| `typ` | OPTIONAL. When present it MUST be `JWT` or `JOSE` (JWT-SVID §2.3). |
| `sub` | MUST equal `identity.subject` byte-for-byte (JWT-SVID §3.1). |
| `aud` | REQUIRED (JWT-SVID §3.2). **Tightening:** it MUST hold exactly one value, as a string or a one-element array, and that value MUST equal the verifying peer's AID byte-for-byte, as in §2.2. JWT-SVID §3.2 allows several values and only strongly recommends one. A multi-audience SVID can be replayed by every audience it names (JWT-SVID §7.2), so AITP rejects it. |
| `exp` | REQUIRED, and MUST be in the future (JWT-SVID §3.3). |
| `iat` | **Tightening:** REQUIRED, and MUST be within ±300 s of current time, as in §2.2. |
| `nonce` | **Tightening:** REQUIRED, and MUST equal the `pop_nonce` of the same handshake message byte-for-byte, as in §2.2. |
| `cnf.jkt` | **Tightening:** REQUIRED, and MUST equal the RFC 7638 thumbprint of the sender AID's key, computed per §2.2.1. |

Other claims MAY be present and are ignored (JWT-SVID §3).

A bare JWT-SVID is a bearer token (JWT-SVID §7.1): anyone who captures one can present it in a new handshake until it expires. The `nonce` and `cnf.jkt` rules prevent this. They bind the SVID to one handshake and to one key pair, as they do for OIDC (§7).

> **Issuer support (informative).** The SPIFFE Workload API's `JWTSVIDRequest` carries only `audience` and `spiffe_id`, so a stock SPIRE deployment cannot put `nonce` or `cnf` claims into a JWT-SVID. A `jwt-svid` identity therefore needs a SPIFFE issuer that can mint those two claims on request, such as a SPIRE plugin or a custom issuer. A deployment without one can use `x509-svid` (§6.4), which works with stock SVIDs. This trade-off is recorded in `governance/DECISIONS.md`.

### 6.4 X509-SVID

`x5c[0]` is the X509-SVID. `proof` is a signature by the X509-SVID's private key over the handshake context (§6.4.1).

The verifier MUST check the chain and the leaf:

1. **Path validation.** Validate `x5c` as an [RFC 5280 §6](https://datatracker.ietf.org/doc/html/rfc5280#section-6) certification path at the current time (X509-SVID §5.1).
   - The trust anchors are the certificates of the `x509-svid` JWKs in the subject trust domain's bundle, and only those.
   - Intermediates come only from `x5c[1..]`. The verifier MUST NOT fetch certificates through AIA, and MUST NOT use a system trust store or any other bundle.
2. **SPIFFE ID.** The leaf MUST carry exactly one URI SAN, and it MUST equal `identity.subject` byte-for-byte (X509-SVID §2). A leaf with more than one URI SAN MUST be rejected, even if one of them matches.
3. **Leaf constraints.** The leaf's basic constraints `cA` MUST be false (X509-SVID §4.1). Its key usage MUST include `digitalSignature` and MUST NOT include `keyCertSign` or `cRLSign` (X509-SVID §4.3).
4. **Leaf key.** **Tightening:** the leaf's public key MUST be an Ed25519 key or a P-256 key, the two algorithms of the RFC-AITP-0001 §5.4.6 signing primitive. Any other key type is rejected, RSA and P-384 included.

SPIFFE defines no revocation for SVIDs, which are short-lived instead. AITP adds none: the verifier checks the validity period (step 1) and nothing more.

The leaf key MAY differ from the AID key. In a stock SPIRE deployment it always does, because the Workload API generates the SVID key pair and hands it to the workload. Two signatures bind the two keys together:

- the §6.4.1 proof, made with the SVID key, covers the sender AID; and
- the envelope signature, made with the AID key ([RFC-AITP-0001 §5.4](RFC-AITP-0001-core.md#54-signature)), covers the whole payload, including `subject`, `x5c` and `proof`.

The holder of the SVID key therefore vouches for this AID in this handshake, and the holder of the AID key vouches for this SVID.

#### 6.4.1 Proof input

```
proof_input =
    "aitp-spiffe-x509-v1\0"
    || sender_aid_bytes        || "\0"
    || receiver_aid_bytes      || "\0"
    || message_id_bytes        || "\0"
    || timestamp_ascii_decimal || "\0"
    || pop_nonce_decoded_bytes
proof = sign(svid_private_key, sha256(proof_input))
```

The fields are encoded as in §3.1. Only the domain prefix differs, so a pinned-key proof can never be read as an X509-SVID proof, or the reverse.

`sign` is the primitive of [RFC-AITP-0001 §5.4.6](RFC-AITP-0001-core.md#546-signing-primitive-per-algorithm-jcs-profile-and-proofs). `sha256(proof_input)` is hashed exactly once; a P-256 key MUST NOT hash it again.

`proof` uses the [RFC-AITP-0001 §5.4.3](RFC-AITP-0001-core.md#543-algorithm-tagged-signature-wire-format-jcs-profile-only) wire format:

- Its tag MUST match the algorithm of the **leaf key**, not of the AID.
- A P-256 leaf MUST use the `p256.` tag.
- An untagged proof is read as `ed25519`. An untagged proof under a P-256 leaf is therefore an algorithm mismatch and is rejected.

> **Known-answer test.** `kat-spiffe-x509-proof-001` in [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json) pins a concrete tuple and its 194-byte `proof_input`. The sender AID is `kat-keypair-002`, and the proof is an Ed25519 signature by `kat-keypair-003` acting as the leaf key, so the leaf key differs from the AID key, as in a stock deployment. The vector also pins that the proof does not verify over the pinned-key input (§3.1) of the same tuple.

### 6.5 Verification steps

A peer verifying a `spiffe` identity binding MUST:

1. Confirm that `identity.type` is `spiffe`, that `svid_type` is `jwt-svid` or `x509-svid`, and that the descriptor satisfies §6.1, including the canonical form of `subject`.
2. Take the trust domain from `subject`: the authority between `spiffe://` and the next `/`.
3. Look up that trust domain in the local `spiffe_bundles` store (§6.2). If there is no entry, verification fails.
4. From that bundle, take the keys whose `use` matches `svid_type`: `jwt-svid` JWKs for a JWT-SVID, `x509-svid` CAs for an X509-SVID. If there are none, verification fails.
5. Verify the SVID:
   - For `jwt-svid`, run every §6.3 check.
   - For `x509-svid`, run every §6.4 check, then verify `proof` under the leaf key over the §6.4.1 input. Rebuild that input from the inbound envelope (`sender.agent_id`, the verifying peer's own AID as `receiver`, `message_id`, `timestamp`) and the handshake message's `pop_nonce`.

Steps 1–4 MUST complete before any signature verification.

A failure at any step is `IDENTITY_FAILED`. This section defines no new error code.

### 6.6 Manifest hint and compatibility

A Manifest `identity_hint` of type `spiffe` carries only `type` and `subject`, the SPIFFE ID. It MUST NOT carry `issuer` or `public_key` ([RFC-AITP-0003 §3.1](RFC-AITP-0003-manifest.md)). The hint is never trust material: the verifier checks the handshake descriptor against its own bundle store, whatever the hint says.

A verifier that does not list `spiffe` in its `accepted_identity_types` rejects a `spiffe` peer with `INCOMPATIBLE_IDENTITY_TYPE` (RFC-AITP-0003 §5 step 6, RFC-AITP-0004 §5.1 step 8), as it would any other non-OIDC type it does not accept. `accepted_trust_anchors` lists OIDC issuers only, and is not consulted for a `spiffe` peer.

---

## 7. Security Considerations

- The `iss` check for OIDC defends against issuer-confusion attacks.
- The `aud` claim binds the JWT to a specific verifying peer; without it, a JWT issued for one peer can be replayed against any other peer that trusts the same issuer.
- The `nonce` claim binds the JWT to a specific handshake instance. Without it, a JWT minted for one handshake against the right `aud` could be captured and replayed in a later handshake to the same peer (e.g. if the captured JWT has not yet expired). The `nonce` is bound to the same `pop_nonce` that drives the Mutual Handshake's PoP exchange, so identity-proof freshness and key-possession freshness share the same defense.
- The `cnf.jkt` claim binds the JWT to the AID's signing key. A stolen JWT cannot be paired with a different key pair to impersonate a different agent, and an agent cannot prove identity without also controlling the private key that signs its Manifest and envelopes.
- Together, `aud`, `nonce`, and `cnf.jkt` make the OIDC identity binding **non-transferable across peers, handshakes, and key pairs** in the same way TCTs are non-transferable.
- The pinned-key proof input (§3.1) MUST bind sender AID, receiver AID, `message_id`, `timestamp`, AND the handshake `pop_nonce`. Earlier drafts that signed only `message_id|timestamp` did not bind sender or receiver and admitted cross-peer replay; the v0.1 proof input (unchanged in v0.2) is the minimum that prevents it. Implementations MUST NOT accept the legacy two-field input.
- A peer MUST NOT relax issuer-list checks based on `reason` strings or any client-supplied hint.
- A JWT-SVID is a bearer token (JWT-SVID §7.1). The `nonce` and `cnf.jkt` claims (§6.3) bind it to one handshake and to the AID key. Without them, a captured SVID could be replayed until it expired.
- If a JWT-SVID names several audiences, each audience can replay it to the others (JWT-SVID §7.2). §6.3 therefore allows exactly one `aud` value, the verifying peer's AID.
- The X509-SVID key and the AID key are usually different keys (§6.4). Neither signature alone binds the SVID to the AID; the §6.4.1 proof and the envelope signature do so together. A verifier MUST check both.
- An SVID MUST be checked only against the bundle of its own trust domain (§6.2). A key trusted for one trust domain proves nothing about an ID in another.
- Trust domain names are not globally unique: two independent deployments can choose the same name (SPIFFE-ID §2.1.1). A `spiffe_bundles` entry trusts whoever controls the bundle configured for that name. Operators MUST source each bundle from the deployment they intend to trust.
- In the `pinned-admission` profile (§3.4), the verifier holds challenge state before it knows who is asking, so challenge issuance is an amplification and exhaustion surface. Three rules defend it, and each is load-bearing. The outstanding-nonce bound stops memory exhaustion. Refusing rather than evicting stops one source from cancelling challenges already issued to others. Consuming the nonce only after every signature check stops a forged presentation from burning a legitimate presenter's nonce.

---

## 8. References

- [RFC 7519 — JSON Web Token](https://datatracker.ietf.org/doc/html/rfc7519)
- [RFC 7638 — JSON Web Key Thumbprint](https://datatracker.ietf.org/doc/html/rfc7638)
- [RFC 7800 — Proof-of-Possession Key Semantics for JWTs (`cnf`)](https://datatracker.ietf.org/doc/html/rfc7800)
- [RFC 9449 — OAuth 2.0 Demonstrating Proof of Possession (DPoP)](https://datatracker.ietf.org/doc/html/rfc9449)
- [RFC 4648 — The Base16, Base32, and Base64 Data Encodings](https://datatracker.ietf.org/doc/html/rfc4648)
- [RFC 5280 — Internet X.509 PKI Certificate and CRL Profile](https://datatracker.ietf.org/doc/html/rfc5280)
- [RFC 7517 — JSON Web Key (JWK)](https://datatracker.ietf.org/doc/html/rfc7517)
- [RFC 7518 — JSON Web Algorithms (JWA)](https://datatracker.ietf.org/doc/html/rfc7518)
- [SPIFFE-ID — The SPIFFE Identity and Verifiable Identity Document](https://github.com/spiffe/spiffe/blob/49a9cbbc018c39ec6643ad3301632f9f4549258b/standards/SPIFFE-ID.md)
- [X509-SVID — The X.509 SPIFFE Verifiable Identity Document](https://github.com/spiffe/spiffe/blob/49a9cbbc018c39ec6643ad3301632f9f4549258b/standards/X509-SVID.md)
- [JWT-SVID — The JWT SPIFFE Verifiable Identity Document](https://github.com/spiffe/spiffe/blob/49a9cbbc018c39ec6643ad3301632f9f4549258b/standards/JWT-SVID.md)
- [The SPIFFE Trust Domain and Bundle](https://github.com/spiffe/spiffe/blob/49a9cbbc018c39ec6643ad3301632f9f4549258b/standards/SPIFFE_Trust_Domain_and_Bundle.md)
- [SPIFFE Workload API (`workloadapi.proto`)](https://github.com/spiffe/spiffe/blob/49a9cbbc018c39ec6643ad3301632f9f4549258b/standards/workloadapi.proto)
- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0007 Key Resolution](RFC-AITP-0007-key-resolution.md)
