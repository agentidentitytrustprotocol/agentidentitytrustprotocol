# RFC-AITP-0003
# Agent Manifest

**Document:** RFC-AITP-0003
**Version:** 0.1.0-rc.3
**Status:** Release Candidate
**Depends on:** [RFC-AITP-0001 Core](RFC-AITP-0001-core.md), [RFC-AITP-0002 Identity](RFC-AITP-0002-identity.md)

---

## Abstract

This RFC defines the **Agent Manifest** — a signed, self-describing document that every AITP agent publishes so that peer agents can discover it, verify its identity, and determine trust-anchor compatibility before initiating a Mutual Handshake.

The Manifest solves the discovery problem in agent-to-agent ecosystems: there is no central directory and no shared verifier. A peer learns where to authenticate, which identity issuers the target accepts, and what capabilities the target offers — all from the Manifest, before the first handshake message is exchanged. The Manifest is the A2A equivalent of an OIDC discovery document (`/.well-known/openid-configuration`), and it is a prerequisite for [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md).

---

## 1. Design Goals

1. **Self-describing.** A peer learns everything needed to initiate a handshake from the Manifest alone. No out-of-band configuration required.
2. **Verifiable.** The Manifest is signed by the agent's private key. Tampering is detectable before any protocol exchange.
3. **Cacheable.** Manifests carry expiry timestamps. Peers MAY cache them up to `expires_at`.
4. **Mandatory.** Every AITP agent MUST publish a Manifest. There is no service-only profile in v0.1; every agent participates in A2A.
5. **Transport-agnostic.** The canonical delivery mechanism is HTTPS at a well-known URL. Manifests MAY also be exchanged inline during the Mutual Handshake.

---

## 2. Agent Manifest Schema

```json
{
  "manifest": {
    "version": "aitp/0.1",
    "aid": "aid:pubkey:<base64url>",
    "display_name": "WorkerAgent-7",

    "identity_hint": {
      "type": "oidc",
      "issuer": "https://auth.example.com",
      "subject": "worker-agent-7"
    },

    "handshake_endpoint": "https://agent-b.example.com/aitp/handshake",

    "accepted_trust_anchors": [
      "https://auth.openai.com",
      "https://auth.anthropic.com"
    ],

    "offered_capabilities": [
      "macp.mode.task.v1",
      "read_data"
    ],

    "required_peer_capabilities": [],

    "proof_of_possession": {
      "challenge": "<random 128-bit base64url>",
      "signature": "<base64url sig over challenge using agent private key>"
    },

    "published_at": 1711900000,
    "expires_at":   1711986400,

    "extensions": {},

    "signature": "<base64url sig over canonical manifest JSON excluding signature>"
  }
}
```

The canonical schema is [`schemas/json/aitp-manifest.schema.json`](../schemas/json/aitp-manifest.schema.json).

---

## 3. Fields

### 3.1 Required Fields

| Field | Type | Description |
|---|---|---|
| `version` | string | MUST be `"aitp/0.1"`. |
| `aid` | string | The agent's AID. Format: `aid:<method>:<identifier>`. |
| `identity_hint` | object | Static issuer/subject metadata. Tells peers which identity provider this agent uses, but does NOT contain a verifiable JWT. Fresh identity proof is exchanged in `MUTUAL_HELLO` (RFC-AITP-0004 §3). The hint MUST contain `type` and `subject`; for `oidc` it MUST also contain `issuer`; for `pinned_key` it MUST also contain `public_key`. The hint MUST NOT contain a `proof` field. |
| `handshake_endpoint` | string | HTTPS URL where peer agents initiate the Mutual Handshake. |
| `accepted_trust_anchors` | array of string | OIDC issuer URIs this agent accepts from peers. MUST be consistent with the agent's internal verification configuration (see §5.1). |
| `offered_capabilities` | array of string | Capabilities this agent is willing to grant to authenticated peers. |
| `proof_of_possession` | object | Demonstrates the publisher holds the private key for `aid`. |
| `proof_of_possession.challenge` | string | Random 128-bit value chosen at publish time, encoded as exactly 22 chars of unpadded base64url (RFC-AITP-0001 §5.4). |
| `proof_of_possession.signature` | string | `base64url(sign(agent_private_key, sha256(base64url_decode(challenge))))`. Exactly 86 chars unpadded base64url. The hash input MUST be the 16 raw bytes obtained by base64url-decoding `challenge` (not the base64url string itself). This follows the same convention as RFC-AITP-0004 §3 and RFC-AITP-0005 §6.1: every PoP signing input in AITP v0.1 hashes decoded bytes, never encoded strings. See the unified PoP signing-input convention in [RFC-AITP-0001 §5.4.2](RFC-AITP-0001-core.md#542-pop-signing-input-convention). |
| `published_at` | integer | Unix timestamp (seconds) when this Manifest was signed. |
| `expires_at` | integer | Unix timestamp (seconds) after which this Manifest MUST NOT be used. |
| `signature` | string | Agent's signature over the canonical Manifest (see §6). |

### 3.2 Optional Fields

| Field | Type | Description |
|---|---|---|
| `display_name` | string | Human-readable agent name. Not used in trust decisions. |
| `required_peer_capabilities` | array of string | Capabilities the peer MUST hold for this agent to accept a handshake. |
| `accepted_identity_types` | array of string | Identity binding types this agent accepts from peers (RFC-AITP-0002). Allowed values: `"oidc"`, `"pinned_key"`. **Default semantics:** an *absent* `accepted_identity_types` field (omitted from the wire format entirely) is treated as `["oidc"]`. An *explicitly empty* array `[]` means no identity type is accepted and will cause `INCOMPATIBLE_TRUST_ANCHORS` for every peer. Publishers that want the `["oidc"]` default behavior SHOULD omit the field rather than publishing `["oidc"]` explicitly — this keeps the canonical JSON shorter and avoids confusion about whether an empty array is intentional. Used at discovery time to screen for compatibility when the peer's identity is not OIDC-based. **Canonical-form rule:** the absent / explicit-empty distinction MUST be preserved in the JCS canonical bytes used for signing — verifiers reconstruct the signing input from the wire form, so an issuer that signs an absent field must serialize an absent field at verification time, and one that signs `[]` must serialize `[]`. Implementations modeling this as a typed optional (e.g. `Option<Vec<String>>`) keep both states distinguishable through the round-trip; implementations that conflate absent with empty Vec will produce diverging signatures across peers. |
| `accepted_signature_algorithms` | array of string | Signature algorithms this agent accepts from peers (RFC-AITP-0001 §5.4.3). Allowed values: `"ed25519"`, `"p256"`. **Default semantics** mirror `accepted_identity_types`: absent → defaults to `["ed25519", "p256"]` (the v0.2 mandatory set), explicit `[]` → reject every peer. A publisher restricting to one algorithm publishes a single-element array. The same canonical-form rule applies — preserve absent vs explicit-empty in the JCS signing bytes. |
| `extensions` | object | Reserved for future extension fields. Unknown extensions MUST be ignored. |

---

## 4. Well-known Endpoint

Every AITP agent MUST publish its Manifest at:

```
https://<agent-host>/.well-known/aitp-manifest
```

### 4.1 HTTP requirements

- The endpoint MUST be served over HTTPS. Plain HTTP MUST be rejected.
- The response MUST set `Content-Type: application/json`.
- The response SHOULD set `Cache-Control: max-age=<seconds>` consistent with `expires_at - published_at`.

### 4.2 Example response

```http
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: max-age=86400

{ "manifest": { ... } }
```

### 4.3 Inline exchange

Manifests are also exchanged inline at the start of the Mutual Handshake (in the `MUTUAL_HELLO` and `MUTUAL_HELLO_ACK` payloads, see [RFC-AITP-0004](RFC-AITP-0004-mutual-handshake.md) §3). The inline Manifest MUST be identical to the published Manifest. If a peer has a cached copy and receives an inline Manifest with a newer `published_at`, it MUST use the more recently published version.

---

## 5. Manifest Verification

Before a peer uses a Manifest to initiate a handshake, it MUST verify the following in order:

1. **Version check** — `manifest.version` MUST be `"aitp/0.1"` or a later version this implementation supports.
2. **Expiry check** — `manifest.expires_at` MUST be in the future.
3. **Proof-of-possession** — Verify `proof_of_possession.signature`:

   ```
   expected_sig = base64url(sign(agent_private_key, sha256(base64url_decode(challenge))))
   ```

   The hash input is the 16 raw bytes obtained by base64url-decoding `challenge` (not the ASCII bytes of the encoded form). Verification uses the public key encoded in `manifest.aid`.

   > **Note.** The pattern `sha256(base64url_decode(x))` appears in every PoP signing input in v0.1: Manifest PoP (here), handshake PoP (RFC-AITP-0004 §3), downstream TCT PoP (RFC-AITP-0005 §6.1), and the pinned-key identity proof input (RFC-AITP-0002 §3.1). Implementations that hash the ASCII string form instead of the decoded bytes will be internally consistent but will fail cross-implementation verification. Implementations SHOULD add a KAT cross-check that verifies a given (challenge → decoded → sha256 → signature) vector against all PoP code paths; the pinned `kat-manifest-pop-001` vector at [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json) provides the reference inputs and outputs.
4. **Manifest signature** — Verify `manifest.signature` using the public key from `manifest.aid` (see §6).
5. **Identity-type and trust-anchor compatibility** — The fetching peer MUST screen the published Manifest against its own identity. Two cases:
   - If the fetching peer's identity is `oidc`, the published Manifest's `accepted_trust_anchors` MUST contain at least one issuer that matches an issuer in the fetching peer's own `trust_anchors` configuration.
   - If the fetching peer's identity is `pinned_key` (or any non-OIDC type), the published Manifest's `accepted_identity_types` (default `["oidc"]` when absent) MUST include the fetching peer's identity type. `accepted_trust_anchors` is not consulted in this case — pinned-key identities are not minted by an OIDC issuer.

   If neither check passes, the peers cannot mutually authenticate; the handshake MUST NOT be initiated and the peer SHOULD log `INCOMPATIBLE_TRUST_ANCHORS`.

A Manifest that fails any of the above checks MUST be discarded. The peer MUST NOT initiate a Mutual Handshake using an unverified Manifest.

Manifest verification does NOT include identity-proof verification. The Manifest carries `identity_hint` — static metadata declaring which identity provider this agent uses — not a verifiable JWT. Fresh identity proof is exchanged inline during the Mutual Handshake (RFC-AITP-0004 §5.1 step 6), where the proof can be bound to a fresh nonce and to the verifying peer's AID via the JWT `aud` claim.

### 5.1 Trust-anchor consistency requirement

`accepted_trust_anchors` is a public commitment about which identity issuers this agent will verify peer identities against. The fetching peer uses it to pre-screen for compatibility (step 5 above) before initiating a handshake.

**Implementations MUST keep `accepted_trust_anchors` consistent with the agent's internal verification configuration.** If the published Manifest claims to accept `https://auth.example.com` but the agent's runtime `trust_anchors` config does not include `https://auth.example.com`, the discovery-time check will pass and the handshake will fail — wasting both peers' resources and obscuring the misconfiguration.

A Manifest MUST be republished whenever the underlying `trust_anchors` configuration changes. Operators SHOULD enforce this with a build-time or deploy-time check that compares the two sources of truth.

---

## 6. Manifest Signature

### 6.1 What is signed

The `{"manifest": {...}}` form shown throughout this RFC is the **HTTP/transport envelope only**. The signed object is the inner `manifest` value (the `AgentManifest` itself), never the wrapper. Verifiers receiving a Manifest at the well-known endpoint MUST unwrap to the inner object before computing the signing input. Inline Manifests in handshake messages (`payload.manifest`) are already the inner form — the wrapper is not present there.

The `signature` field covers the canonical JSON serialization of the inner Manifest object **excluding the `signature` field itself**:

```
sig_input  = sha256(canonical_json(manifest_without_signature))
signature  = base64url(sign(agent_private_key, sig_input))
```

Canonical JSON MUST be produced per [RFC 8785 (JCS)](https://datatracker.ietf.org/doc/html/rfc8785). See [RFC-AITP-0001 §5.4](RFC-AITP-0001-core.md#54-signature) for the unified canonicalization and base64url encoding rules. A worked example (`kat-manifest-001`) showing the canonical bytes and SHA-256 digest of a fixed Manifest body lives at [`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json); implementations MUST reproduce it byte-for-byte.

### 6.2 Signing algorithm

Ed25519. Future versions MAY add algorithms via the RFC process.

---

## 7. Discovery Flow

The complete discovery-and-screen flow before initiating a handshake:

```
Initiating Peer (A)              Target Peer (B)
       |                                 |
       |  GET /.well-known/aitp-manifest |
       |-------------------------------->|
       |<------- Manifest (JSON) --------|
       |                                 |
       | Apply §5 verification, in order:|
       | 1. Version check                |
       | 2. expires_at in the future     |
       | 3. proof_of_possession.signature|
       | 4. manifest.signature           |
       | 5. identity-type / trust-anchor |
       |    compatibility                |
       |                                 |
       |  [compatible] → proceed to      |
       |  RFC-AITP-0004 Mutual Handshake |
       |                                 |
       |  [incompatible] → abort;        |
       |  log INCOMPATIBLE_TRUST_ANCHORS |
```

---

## 8. Manifest Rotation

Agents SHOULD rotate their Manifest (re-sign with a fresh `published_at` and `proof_of_possession.challenge`) on a schedule:

| Manifest TTL | Recommended rotation |
|---|---|
| ≤ 1 hour | Every 30 minutes |
| ≤ 24 hours | Every 12 hours |
| ≤ 7 days | Every 3 days |

When the signing key is rotated, the Manifest MUST be re-signed immediately. Peers SHOULD NOT cache Manifests beyond their `expires_at` field.

### 8.1 Emergency rotation (key compromise)

Rotation on the schedule above is advisory. Rotation on **key compromise** is normative. A peer that discovers (or has reasonable suspicion) that its signing key is compromised MUST:

1. Immediately generate a new signing key and re-publish its Manifest under the new AID derived from the new key.
2. Revoke every TCT it has issued under the old AID by publishing a signed revocation snapshot ([RFC-AITP-0008 §1.5](RFC-AITP-0008-revocation.md#15-signed-revocation-response)) covering all known JTIs.
3. Notify known peer agents of the new AID through out-of-band channels (the protocol does not provide a normative push mechanism in v0.1; see [RFC-AITP-0009 §1.10](RFC-AITP-0009-security.md#110-key-compromise)).

The old AID MUST be treated as untrusted by the compromised peer immediately. If the compromised peer can still publish (e.g. the host is intact but the signing key was leaked), it SHOULD set a short `expires_at` on the old Manifest before rekeying (e.g. `expires_at = now + 300`) so cached copies expire quickly. Peers that hold a cached old Manifest MUST re-fetch when its `expires_at` passes; until then, the cached Manifest is the authoritative key for the old AID.

There is no AID-level revocation mechanism in v0.1. The AID is derived from the public key, so a new key produces a new AID; trust in the old AID is terminated by setting the old Manifest's `expires_at` to a value in the past (or letting it expire naturally) and by revoking every TCT issued under it. Peers that learn of a key compromise out-of-band MUST NOT continue to trust the old AID even if its cached Manifest has not yet expired.

---

## 9. Manifest delivery in v0.1

The normative delivery mechanism is the well-known HTTPS endpoint defined in §4. Inline delivery during the Mutual Handshake (`payload.manifest`) is the second supported path. v0.1 conformance does not require any RPC service for Manifest fetching.

---

## 10. Error Codes

New error codes introduced by this RFC:

| Code | Meaning | Retryable |
|---|---|---|
| `MANIFEST_EXPIRED` | `expires_at` is in the past | false |
| `MANIFEST_SIGNATURE_INVALID` | Signature verification failed | false |
| `MANIFEST_POP_FAILED` | Proof-of-possession verification failed | false |
| `INCOMPATIBLE_TRUST_ANCHORS` | No overlap in accepted trust anchors | false |
| `MANIFEST_VERSION_UNKNOWN` | `version` not supported by this implementation | false |

---

## 11. Security Considerations

### 11.1 Manifest as a trust root

The Manifest is the first thing a peer trusts about another agent. A compromised Manifest (wrong public key, wrong endpoint) can redirect all subsequent handshakes. The proof-of-possession field is the primary defense: it binds the Manifest to the key that controls `aid`. A Manifest without a valid PoP MUST be rejected.

### 11.2 DNS and TLS dependency

The well-known endpoint introduces a dependency on DNS and TLS. Agents MUST validate the TLS certificate of the agent host before trusting a fetched Manifest. DNS spoofing that redirects `/.well-known/aitp-manifest` to a different host is mitigated by TLS-certificate pinning (RECOMMENDED for production deployments).

### 11.3 Caching attacks

An attacker who can serve a cached, expired Manifest to a victim agent can prevent the victim from detecting a key rotation. Agents MUST enforce `expires_at` strictly and MUST re-fetch Manifests that have expired.

### 11.4 Manifest replay across agents

The PoP signature over `challenge` prevents Manifests from being replayed across agents. Because `challenge` is chosen randomly at publish time and signed, an attacker cannot present Agent B's Manifest as if it were Agent C's.

---

## 12. Non-Goals

- **Agent registry.** AITP does not define a global registry of agents or their Manifests. Discovery is direct (well-known URL) or inline (during the Mutual Handshake). A directory service MAY be built on top of Manifests by the ecosystem.
- **Capability negotiation semantics.** `offered_capabilities` is informational. The binding grant intersection happens during the Mutual Handshake (RFC-AITP-0004), not at discovery time.
- **Agent authentication to humans.** The Manifest is for machine-to-machine discovery only.

---

## 13. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0002 Identity](RFC-AITP-0002-identity.md)
- [RFC-AITP-0004 Mutual Handshake](RFC-AITP-0004-mutual-handshake.md)
- [RFC-AITP-0005 Trust Context Token](RFC-AITP-0005-tct.md)
- [RFC-AITP-0010 Session Trust Bundle](RFC-AITP-0010-session-trust-bundle.md) *(Draft, post-v0.1)*
- [RFC 5785 — Well-Known URIs](https://datatracker.ietf.org/doc/html/rfc5785)
- [RFC 7517 — JSON Web Key](https://datatracker.ietf.org/doc/html/rfc7517)
