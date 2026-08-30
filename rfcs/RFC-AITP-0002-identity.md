# RFC-AITP-0002
# Identity Binding

**Document:** RFC-AITP-0002
**Version:** 0.2.2-draft
**Status:** Community Standards Track (v0.2 Draft)
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)

---

## Abstract

This RFC defines how an agent's AID is bound to a verifiable claim from a trusted issuer. AITP does not define an identity system; this RFC defines how identity is *presented* and *verified* between peers. The verifying party is always another peer agent (not a third-party verifier or service): see [RFC-AITP-0001 §4 Architecture](RFC-AITP-0001-core.md#4-architecture).

**Where identity proof appears.** Identity proof — the verifiable JWT (for OIDC) or signature (for pinned_key) — is exchanged inline during the Mutual Handshake (RFC-AITP-0004 §3). The Agent Manifest (RFC-AITP-0003 §3.1) carries only an **identity hint** (`identity_hint`): static `type`/`issuer`/`subject` metadata, with no `proof` field. The hint lets peers discover *which* identity provider an agent uses; the verifiable proof is presented fresh each handshake so it can be bound to a per-handshake nonce and to the verifying peer's AID. The `aud`, `cnf.jkt`, and `nonce` requirements in §2 apply to the handshake-level identity proof only, never to the Manifest hint.

v0.2 supports two identity types: `oidc` and `pinned_key`. Future identity types extend this RFC without modifying the core envelope.

---

## 1. Identity Descriptor

```json
{
  "identity": {
    "type": "oidc | pinned_key",
    "issuer": "<issuer URI>",
    "subject": "<subject identifier>",
    "proof": "<jwt or signature>",
    "public_key": "<base64url — optional for oidc, required for pinned_key>"
  }
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | REQUIRED | Identity mechanism: `oidc` or `pinned_key`. |
| `issuer` | string | REQUIRED for `oidc` | Issuer URI (MUST match JWT `iss` claim). |
| `subject` | string | REQUIRED | Agent subject identifier. |
| `proof` | string | REQUIRED | JWT for OIDC; base64url signature for pinned_key. |
| `public_key` | string | REQUIRED for `pinned_key`; MUST be absent for `oidc` | base64url-encoded public key. For `pinned_key`, this is the key the verifier looks up in its `pinned_keys` configuration (§3.2). For `oidc`, the agent's public key is already encoded in the verifying-peer envelope's `sender.agent_id` (the AID-identifier component) — there is no second copy in the descriptor, and including one would create an ambiguity over which key the JWT's `cnf.jkt` is meant to bind. The identity-descriptor schema (`schemas/json/aitp-identity.schema.json`) enforces this: its `oidc` branch forbids `public_key`, mirroring the `IdentityHint` rule that the Manifest schema applies to `identity_hint`. v0.2 verifiers MUST reject an OIDC `identity` descriptor that carries `public_key`. |

The canonical JSON Schema is [`schemas/json/aitp-identity.schema.json`](../schemas/json/aitp-identity.schema.json).

> **Note on `proof` inputs.** The proof input differs by type. For `oidc`, `proof` is a self-contained JWT (§2). For `pinned_key`, `proof` is a signature whose input binds fields drawn from the surrounding handshake envelope (§3.1) — including the `pop_nonce` carried on `MUTUAL_HELLO` / `MUTUAL_HELLO_ACK` (RFC-AITP-0004 §3). The descriptor itself does NOT carry the nonce; verifiers reconstruct the proof input from the envelope plus the descriptor's `subject` and the local `receiver_aid`.

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

The JWK used to compute `cnf.jkt` is the canonical OKP Ed25519 form, exactly:

```json
{"crv":"Ed25519","kty":"OKP","x":"<aid-identifier>"}
```

where `<aid-identifier>` is the 43-character AID identifier component from `aid:pubkey:<aid-identifier>` (i.e. the unpadded base64url encoding of the 32-byte raw Ed25519 public key, per RFC-AITP-0001 §5.3).

The thumbprint is computed per RFC 7638: serialize this exact 3-field JSON object with members in lexicographic order, no whitespace, hash with SHA-256, encode the digest as unpadded base64url. Implementations MUST NOT include any other JWK members (no `kid`, no `alg`, no `use`) when computing the thumbprint — additional members would change the canonical serialization and the resulting hash.

> **Shared convention with the portable trust artifacts.** In `aitp/0.2` this same RFC 7638 `cnf.jkt` convention is also the proof-of-possession key binding on the compact-JWS portable trust artifacts — the TCT and the delegation token ([RFC-AITP-0001 §5.4.4](RFC-AITP-0001-core.md#544-jwk-thumbprint-for-cnf), which cites this section). The v0.1 raw-public-key `binding.cnf` form on the TCT no longer exists; identity binding and token binding now use one `cnf.jkt` convention.

> **Known-answer test.** For the pinned all-zero-seed Ed25519 keypair (`kat-keypair-001` in [`schemas/conformance/known-answer/keypairs.json`](../schemas/conformance/known-answer/keypairs.json)), `aid-identifier = O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik`, the canonical JWK input is `{"crv":"Ed25519","kty":"OKP","x":"O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik"}` (87 bytes), and the resulting `jkt` MUST be `9ZP03Nu8GrXPAUkbKNxHOKBzxPX83SShgFkRNK-f2lw`. Additional vectors live at [`schemas/conformance/known-answer/jwk-thumbprints.json`](../schemas/conformance/known-answer/jwk-thumbprints.json).

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

The `aud` is exactly `aid:pubkey:` followed by 43 unpadded-base64url characters (RFC-AITP-0001 §5.3). The `nonce` is the byte-identical `pop_nonce` from the corresponding `MUTUAL_HELLO` payload. The `cnf.jkt` is the RFC 7638 thumbprint of A's AID public key, computed per §2.2.1.

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

Where:

- `sender_aid_bytes` is the UTF-8 encoding of the full `aid:pubkey:...` string of the signing peer.
- `receiver_aid_bytes` is the UTF-8 encoding of the full `aid:pubkey:...` string of the receiving peer.
- `message_id_bytes` is the UTF-8 encoding of the envelope's `message_id` UUID string in canonical lowercase form (RFC-AITP-0001 §5.2).
- `timestamp_ascii_decimal` is the UTF-8 encoding of the envelope's `timestamp` as its base-10 ASCII decimal string (e.g. `1711900000` → `b"1711900000"`), matching how `message_id` is likewise encoded as a string rather than binary-packed.
- `pop_nonce_decoded_bytes` is the raw bytes obtained by base64url-decoding the handshake's `pop_nonce` (NOT the base64url string itself).
- `\0` is a single null byte separator.

> **Replay resistance.** v0.2 pinned-key proofs are bound to the full handshake context (the proof input is unchanged from v0.1). A signature produced for one (sender, receiver, message, nonce) tuple cannot be replayed against a different tuple.

> **Known-answer test.** The `kat-pinned-key-proof-001` vector in [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json) pins a concrete `(sender, receiver, message_id, timestamp, pop_nonce)` tuple, the resulting `proof_input` bytes, and the Ed25519 signature over `sha256(proof_input)` produced with `kat-keypair-003`. It also pins that the same signature does NOT verify when `timestamp` is instead encoded as an 8-byte big-endian integer, so the ASCII-decimal encoding is machine-checkable rather than a matter of prose interpretation.

### 3.2 Verification steps

A peer verifying an identity binding MUST:

1. Locate `public_key` in the local `pinned_keys` configuration.
2. Reconstruct `proof_input` using the same byte layout as §3.1, drawing each field from the inbound envelope (`sender.agent_id`, the verifying peer's own AID as `receiver`, `message_id`, `timestamp`) and the handshake message's `pop_nonce`.
3. Verify the proof signature against the pinned public key over `sha256(proof_input)`.

Peers MUST NOT accept pinned-key identities for public keys not present in the local configuration.

#### Production requirement

Verifying that a peer's key "matches its AID" — i.e. *key-possession proof
alone* — is **not** sufficient for production deployments. AID
construction is deterministic from the public key (RFC-AITP-0001 §5.3),
so any agent can construct an AID for any key it generates. The trust
anchor is the **local pinned-key configuration**, not the AID
derivation; possession of a key tells you only that the holder generated
that AID, not that the AID is one you have ever decided to trust.

Implementations MUST NOT offer key-possession-only verification (i.e.
"accept any pinned-key identity whose proof signature validates against
the public key embedded in `manifest.aid`") as a production default. It
MAY be offered as an explicitly named development mode (e.g.
`unsafe_no_trust_store`) that:

- requires explicit, non-default opt-in,
- logs a high-severity warning each time a key is accepted, and
- is documented as unsafe for any non-development deployment.

All production code paths MUST consult a configured `pinned_keys` store
and reject any pinned-key identity whose `public_key` is not present in
that store, regardless of how cryptographically sound the proof
signature is.

### 3.3 Example

The `public_key` MUST be the same 43-char unpadded-base64url AID-identifier form defined in RFC-AITP-0001 §5.3. SPKI-DER and PEM forms are not permitted.

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
    public_key: "base64url_pubkey"
    allowed_capabilities:
      - "macp.mode.task.v1"
```

The canonical schema is [`schemas/json/aitp-trust-anchors.schema.json`](../schemas/json/aitp-trust-anchors.schema.json).

### 4.1 Distribution modes

| Mode | Description |
|---|---|
| `static_config` | Keys baked into deployment config (RECOMMENDED for v0.2). |
| `well_known_endpoint` | Fetched from `https://<issuer>/.well-known/aitp-keys`. |
| `out_of_band` | Manually provisioned (air-gapped / offline environments). |

See [RFC-AITP-0007 Key Resolution](RFC-AITP-0007-key-resolution.md) for resolution order and failure handling.

---

## 5. Future Identity Types (v0.3+)

The following identity types are reserved:

| Type | Description |
|---|---|
| `did` | W3C Decentralized Identifier with Verifiable Credential. |
| `x509` | X.509 certificate chain (Web PKI). |
| `wallet` | Blockchain-wallet signature. |

Peers receiving an unknown `type` MUST respond with `IDENTITY_FAILED`. New types are registered via the RFC process and recorded in [`registries/identity-types.md`](../registries/identity-types.md).

---

## 6. Security Considerations

- The `iss` check for OIDC defends against issuer-confusion attacks.
- The `aud` claim binds the JWT to a specific verifying peer; without it, a JWT issued for one peer can be replayed against any other peer that trusts the same issuer.
- The `nonce` claim binds the JWT to a specific handshake instance. Without it, a JWT minted for one handshake against the right `aud` could be captured and replayed in a later handshake to the same peer (e.g. if the captured JWT has not yet expired). The `nonce` is bound to the same `pop_nonce` that drives the Mutual Handshake's PoP exchange, so identity-proof freshness and key-possession freshness share the same defense.
- The `cnf.jkt` claim binds the JWT to the AID's signing key. A stolen JWT cannot be paired with a different key pair to impersonate a different agent, and an agent cannot prove identity without also controlling the private key that signs its Manifest and envelopes.
- Together, `aud`, `nonce`, and `cnf.jkt` make the OIDC identity binding **non-transferable across peers, handshakes, and key pairs** in the same way TCTs are non-transferable.
- The pinned-key proof input (§3.1) MUST bind sender AID, receiver AID, `message_id`, `timestamp`, AND the handshake `pop_nonce`. Earlier drafts that signed only `message_id|timestamp` did not bind sender or receiver and admitted cross-peer replay; the v0.1 proof input (unchanged in v0.2) is the minimum that prevents it. Implementations MUST NOT accept the legacy two-field input.
- A peer MUST NOT relax issuer-list checks based on `reason` strings or any client-supplied hint.

---

## 7. References

- [RFC 7519 — JSON Web Token](https://datatracker.ietf.org/doc/html/rfc7519)
- [RFC 7638 — JSON Web Key Thumbprint](https://datatracker.ietf.org/doc/html/rfc7638)
- [RFC 7800 — Proof-of-Possession Key Semantics for JWTs (`cnf`)](https://datatracker.ietf.org/doc/html/rfc7800)
- [RFC 9449 — OAuth 2.0 Demonstrating Proof of Possession (DPoP)](https://datatracker.ietf.org/doc/html/rfc9449)
- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0003 Agent Manifest](RFC-AITP-0003-manifest.md)
- [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0007 Key Resolution](RFC-AITP-0007-key-resolution.md)
