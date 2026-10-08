# AITP Glossary

Terms used across AITP RFCs, schemas, and registries, for the current protocol revision `aitp/0.2`. The authoritative definitions live in the RFC sections referenced from each entry; this glossary is a non-normative quick reference. Where an entry and the RFC differ, the RFC wins.

---

## Concept Index

A one-line "what is X / where is it defined" lookup for the core AITP concepts. For longer definitions, scroll to the alphabetical section below.

| Concept | One-line definition | Authoritative location |
|---|---|---|
| **AID** | Cryptographic agent identifier: `aid:pubkey:ed25519:<43>`, `aid:pubkey:p256:<44>`, or the legacy untagged `aid:pubkey:<43>` (Ed25519). | [RFC-AITP-0001 §5.3](../rfcs/RFC-AITP-0001-core.md#53-agent-id-aid) |
| **Envelope** | Outer JCS-signed object every AITP protocol message ships in. | [RFC-AITP-0001 §5](../rfcs/RFC-AITP-0001-core.md#5-message-envelope) |
| **Signing profiles** | JCS embedded-signature profile (protocol-internal artifacts) vs compact JWS profile (portable trust artifacts). | [RFC-AITP-0001 §5.4](../rfcs/RFC-AITP-0001-core.md#54-signature) |
| **JCS signing input** | Canonical JSON form (RFC 8785) of the inner artifact body — transport wrapper stripped, `signature` member excluded. | [RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#541-signing-input-jcs-profile) |
| **Compact JWS profile** | TCT, grant voucher and delegation token as RFC 7515 compact JWS; header exactly `alg` + `typ`; signature over transmitted bytes. | [RFC-AITP-0001 §5.4.5](../rfcs/RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts) |
| **Replay protection** | `message_id` deduplication + `timestamp` tolerance window. | [RFC-AITP-0001 §5.5](../rfcs/RFC-AITP-0001-core.md#55-replay-protection) |
| **`UNKNOWN_FIELD`** | Rejection code for a member outside an object's schema and outside its `extensions` / `ext` namespace. | [RFC-AITP-0001 §7](../rfcs/RFC-AITP-0001-core.md#7-compatibility-model) |
| **Structural rejection** | Per-artifact code for an object that does not match its schema. | [Error-code registry](../registries/error-codes.md#structural-rejection) |
| **Identity descriptor** | The `identity` object (`type`, `issuer`, `subject`, `proof`, `public_key`) carried in round 1 of the handshake. | [RFC-AITP-0002 §1](../rfcs/RFC-AITP-0002-identity.md#1-identity-descriptor) |
| **OIDC identity** | JWT proof with `aud` (verifying peer's AID), `nonce` (the handshake `pop_nonce`) and `cnf.jkt` (AID key thumbprint). | [RFC-AITP-0002 §2](../rfcs/RFC-AITP-0002-identity.md#2-oidc-identity-type) |
| **Pinned-key identity** | Signature over `(sender, receiver, message_id, timestamp, pop_nonce)`. | [RFC-AITP-0002 §3.1](../rfcs/RFC-AITP-0002-identity.md#31-proof-format) |
| **Manifest** | Signed self-description served at `/.well-known/aitp-manifest`. | [RFC-AITP-0003](../rfcs/RFC-AITP-0003-manifest.md) |
| **`identity_hint`** | Static identity metadata in the Manifest (no JWT, no `proof`). | [RFC-AITP-0003 §3.1](../rfcs/RFC-AITP-0003-manifest.md#31-required-fields) |
| **Mutual Handshake** | Four-message peer authentication producing two TCTs (and optional grant vouchers). | [RFC-AITP-0004](../rfcs/RFC-AITP-0004-mutual-handshake.md) |
| **Grant intersection** | TCT grants are `requested_grants ∩ identity_policy ∩ offered_capabilities`. | [RFC-AITP-0004 §4.1](../rfcs/RFC-AITP-0004-mutual-handshake.md#41-grant-intersection) |
| **TCT** | Signed, audience-bound, capability-scoped peer-issued grant; compact JWS, `typ` `aitp-tct+jwt`. | [RFC-AITP-0005](../rfcs/RFC-AITP-0005-tct.md) |
| **`cnf.jkt`** | Top-level confirmation claim on the TCT / delegation token — RFC 7638 thumbprint of the subject key. | [RFC-AITP-0005 §3](../rfcs/RFC-AITP-0005-tct.md#3-confirmation-claim-cnf) |
| **JTI** | UUID v4 token ID on a TCT; the revocation handle. | [RFC-AITP-0005 §2](../rfcs/RFC-AITP-0005-tct.md#2-claims) |
| **Grant voucher** | Companion compact JWS (`typ` `aitp-grant+jwt`) minted with a TCT; what makes delegation verifiable. | [RFC-AITP-0005 §8](../rfcs/RFC-AITP-0005-tct.md#8-grant-voucher) |
| **Delegation** | Single-hop subset grant (A → B → C); a compact JWS embedding the issuing peer's grant voucher. | [RFC-AITP-0006](../rfcs/RFC-AITP-0006-delegation.md) |
| **Key resolution** | Manifest-first for peers; cache → pinned → well-known for identity issuers. | [RFC-AITP-0007](../rfcs/RFC-AITP-0007-key-resolution.md) |
| **Revocation** | Per-issuing-peer JTI deny lists, published as signed snapshots, pull-based. | [RFC-AITP-0008](../rfcs/RFC-AITP-0008-revocation.md) |
| **`extensions` / `ext`** | The extension namespace: `extensions` on JCS-profile objects, the `ext` claim on JWS artifacts. | [RFC-AITP-0001 §7](../rfcs/RFC-AITP-0001-core.md#7-compatibility-model), [RFC-AITP-0012](../rfcs/RFC-AITP-0012-extensions.md) |
| **PoP** | Proof-of-Possession: signature over `sha256` of a decoded fresh nonce by the holder's private key. | [RFC-AITP-0001 §5.4.2](../rfcs/RFC-AITP-0001-core.md#542-pop-signing-input-convention) |
| **Trust anchor** | Locally configured trusted issuer (or pinned key) used to verify peer identities. | [RFC-AITP-0002 §4](../rfcs/RFC-AITP-0002-identity.md#4-trust-anchors) |
| **Session Trust Bundle** | Coordinator-signed bundle of participant TCTs for an N-agent session (opt-in Draft). | [RFC-AITP-0010](../rfcs/RFC-AITP-0010-session-trust-bundle.md) |

---

## A

**A2A (Agent-to-Agent).** The trust model AITP defines: two autonomous agents establish bilateral trust without a central verifier. There is no service-consumer profile in v0.2. See [RFC-AITP-0001 §3](../rfcs/RFC-AITP-0001-core.md#3-scope-and-design-goals).

**`accepted_identity_types`.** Optional Manifest field listing the identity binding types the agent accepts from peers (`"oidc"`, `"pinned_key"`). Absent means `["oidc"]`; an explicit `[]` accepts none and yields `INCOMPATIBLE_IDENTITY_TYPE` for every peer. The absent-vs-empty distinction is preserved in the signed bytes. See [RFC-AITP-0003 §3.2](../rfcs/RFC-AITP-0003-manifest.md#32-optional-fields).

**`accepted_signature_algorithms`.** Optional Manifest field listing the signature algorithms the agent accepts (`"ed25519"`, `"p256"`). Absent defaults to the mandatory set for the Manifest's `version` — `["ed25519", "p256"]` for `aitp/0.2`; an explicit `[]` accepts none. See [RFC-AITP-0003 §3.2](../rfcs/RFC-AITP-0003-manifest.md#32-optional-fields).

**`accepted_trust_anchors`.** Required Manifest field: the "OIDC issuer URIs this agent accepts from peers". At discovery, a fetcher whose own identity is `oidc` requires the target Manifest's `accepted_trust_anchors` to contain an issuer in the fetcher's own `trust_anchors` (else `INCOMPATIBLE_TRUST_ANCHORS`); for a `pinned_key` fetcher it is not consulted — `accepted_identity_types` is checked instead. The publisher MUST keep it consistent with its runtime `trust_anchors`. See [RFC-AITP-0003 §5](../rfcs/RFC-AITP-0003-manifest.md#5-manifest-verification) step 6 and [RFC-AITP-0003 §5.1](../rfcs/RFC-AITP-0003-manifest.md#51-trust-anchor-consistency-requirement).

**AID (Agent Identifier).** The canonical, public identifier of an agent, `aid:<method>:<identifier>`. v0.2 forms:

- `aid:pubkey:ed25519:<43 chars>` — unpadded base64url of the 32-byte raw Ed25519 public key;
- `aid:pubkey:p256:<44 chars>` — unpadded base64url of the 33-byte SEC1-compressed P-256 public key;
- `aid:pubkey:<43 chars>` — the legacy untagged form (the v0.1 grammar), still accepted indefinitely and meaning Ed25519.

New AIDs SHOULD use the tagged form. The legacy form is canonically equivalent to the `ed25519` tagged form for trust decisions but not byte-equal, so an issuer MUST publish each AID in one form for its lifetime. SPKI DER and PEM are not permitted. See [RFC-AITP-0001 §5.3](../rfcs/RFC-AITP-0001-core.md#53-agent-id-aid).

**`alg` pinning.** On compact-JWS artifacts there is no algorithm negotiation: the verifier derives the sole acceptable `alg` from the signer's AID (`EdDSA` for Ed25519 AIDs, `ES256` for P-256) and rejects anything else — including `none` — with `TOKEN_ALG_MISMATCH`. See [RFC-AITP-0001 §5.4.5](../rfcs/RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts), [RFC-AITP-0009 §1.12](../rfcs/RFC-AITP-0009-security.md#112-algorithm-confusion).

**Audience (`aud`).** The `aud` claim of a TCT: the AID of the peer the TCT is valid for. It is a single string (never an array or wildcard) and MUST equal `sub`. A consuming peer whose own AID differs rejects the TCT with `AUDIENCE_MISMATCH`. See [RFC-AITP-0005 §5](../rfcs/RFC-AITP-0005-tct.md#5-audience).

---

## B

**Binding (proof-of-possession binding).** What ties a TCT or delegation token to its subject's private key so a downstream consumer can challenge the holder: the top-level `cnf` claim, `{"jkt": …}`. `cnf` is REQUIRED on every v0.2 peer-issued TCT; there is no bearer-TCT profile. See [RFC-AITP-0005 §3](../rfcs/RFC-AITP-0005-tct.md#3-confirmation-claim-cnf), [RFC-AITP-0005 §6](../rfcs/RFC-AITP-0005-tct.md#6-binding-proof-of-possession).

---

## C

**Capability.** An opaque string identifying an action a peer is willing to grant or accept. AITP does not define what a capability means — that is owned by the namespace prefix (e.g. `macp.*`, `aitp.*`, `com.example.*`). See [RFC-AITP-0005 §4.2.1](../rfcs/RFC-AITP-0005-tct.md#421-capability-ownership) and [`registries/capabilities.md`](../registries/capabilities.md).

**`cnf` (Confirmation Claim).** The RFC 7800 confirmation claim on a TCT or delegation token. In `aitp/0.2` it is a top-level claim in the `jkt` form only: `{"jkt": "<RFC 7638 JWK thumbprint>"}`. `cnf.jkt` MUST equal the thumbprint of the public key encoded in the token's `sub` AID; verifiers derive the expected value from `sub`. See [RFC-AITP-0001 §5.4.4](../rfcs/RFC-AITP-0001-core.md#544-jwk-thumbprint-for-cnf), [RFC-AITP-0005 §3](../rfcs/RFC-AITP-0005-tct.md#3-confirmation-claim-cnf).

**Compact JWS profile.** The signing profile for the portable trust artifacts (TCT, grant voucher, delegation token): each is an RFC 7515 compact JWS `header.payload.signature`. The protected header contains exactly `alg` and `typ`; the payload carries `ver` and the artifact's claims; unknown claims outside `ext` are rejected with `UNKNOWN_FIELD`; verifiers never re-serialize. Embedded in JSON, the artifact is an opaque string. See [RFC-AITP-0001 §5.4.5](../rfcs/RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts).

**Conformance fixture.** A JSON file under `schemas/conformance/` describing a scenario, its input, and the expected outcome. Implementations MUST produce the specified outcome for each fixture they support; the opt-in `bundle-*` fixtures are SKIPped and `del-mh-*` tokens rejected by core implementations. See [RFC-AITP-0001 §10](../rfcs/RFC-AITP-0001-core.md#10-conformance) and [`schemas/conformance/README.md`](../schemas/conformance/README.md).

**Coordinator.** In a Session Trust Bundle, the agent that completed a Mutual Handshake with every participant and signs the bundle. Its signing key is the bundle's root of trust; consumers verify its Manifest like any peer's. See [RFC-AITP-0010 §2](../rfcs/RFC-AITP-0010-session-trust-bundle.md#2-trust-model).

**Core Team.** The body responsible for shepherding RFCs and cutting releases. See [governance/CHARTER.md](../governance/CHARTER.md).

---

## D

**Delegation.** Single-hop: a peer that holds a TCT and its companion grant voucher can issue a delegation token granting a subset of its capabilities to a third peer. The delegation token is a compact JWS (`typ` `aitp-delegation+jwt`), signed by the delegator, with `aud` equal to the issuing peer's AID, `scope ⊆ voucher.grants`, and the issuing peer's grant voucher embedded verbatim as its `voucher` claim. Core implementations reject a `chain` claim with `DELEGATION_MULTIHOP_NOT_SUPPORTED`; multi-hop chains are the opt-in [RFC-AITP-0011](../rfcs/RFC-AITP-0011-multihop-delegation.md). See [RFC-AITP-0006](../rfcs/RFC-AITP-0006-delegation.md).

---

## E

**Envelope.** The outer JCS-signed object every AITP protocol message ships in. Carries `version`, `message_type`, `message_id`, `timestamp`, `sender`, `payload`, `signature`, and an optional `extensions`. See [RFC-AITP-0001 §5](../rfcs/RFC-AITP-0001-core.md#5-message-envelope).

**`ext`.** The OPTIONAL private claim on compact-JWS artifacts that mirrors the `extensions` slot: unknown keys *inside* `ext` MUST be ignored; unknown claims outside it are rejected with `UNKNOWN_FIELD`. See [RFC-AITP-0001 §5.4.5](../rfcs/RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts), [RFC-AITP-0012 §1.1](../rfcs/RFC-AITP-0012-extensions.md#11-the-ext-claim-on-compact-jws-artifacts).

**`ext.sd_grant`.** Extension key reserved for a future SD-JWT-style selective-disclosure grant voucher. v0.2 peers MUST NOT make a trust decision based on it. See [RFC-AITP-0012 §4](../rfcs/RFC-AITP-0012-extensions.md#4-selective-disclosure-grant-voucher-extsd_grant).

**Extensions.** The optional `extensions` object on JCS-profile objects (envelope, Manifest, handshake payloads, identity descriptor, revocation snapshot, session bundle). It is covered by the signature like any other member; unknown keys inside it MUST be ignored, while an unknown member beside it is rejected with `UNKNOWN_FIELD` ([RFC-AITP-0001 §7](../rfcs/RFC-AITP-0001-core.md#7-compatibility-model)). [RFC-AITP-0012](../rfcs/RFC-AITP-0012-extensions.md) (Reserved, non-normative for `aitp/0.2`) reserves `extensions.zk` and `extensions.tee`; v0.2 peers MUST NOT make a trust decision based on them.

---

## G

**Grant.** One of the strings in a TCT's `grants` array (non-empty). See *Capability*.

**Grant voucher.** A compact JWS (`typ` `aitp-grant+jwt`) the TCT issuer mints at TCT issuance time, with the same `iss`, `sub`, `grants`, `iat` and `exp` as the TCT plus `src_jti` = the TCT's `jti`. It travels in the optional `grant_voucher` field of `MUTUAL_COMMIT` / `MUTUAL_COMMIT_ACK`; the subject embeds it verbatim in a delegation token's `voucher` claim. It has no `jti` and no `cnf`. An issuer MAY decline to mint one, in which case the subject cannot delegate. It discloses the subject's full grant list from that issuer. See [RFC-AITP-0005 §8](../rfcs/RFC-AITP-0005-tct.md#8-grant-voucher), [RFC-AITP-0004 §4.5](../rfcs/RFC-AITP-0004-mutual-handshake.md#45-grant-voucher-issuance).

---

## I

**Identity binding.** The mechanism by which an AID is associated with an external identity claim. v0.2 defines `oidc` and `pinned_key`; `did`, `x509` and `wallet` are reserved future types. See [RFC-AITP-0002](../rfcs/RFC-AITP-0002-identity.md), [`registries/identity-types.md`](../registries/identity-types.md).

**Identity descriptor.** The `identity` object a peer presents in `MUTUAL_HELLO` / `MUTUAL_HELLO_ACK`: `type`, `subject`, `proof`, plus `issuer` (required for `oidc`) and `public_key` (required for `pinned_key`, MUST be absent for `oidc`), and an optional `extensions`. Structural defects — including an `oidc` descriptor carrying `public_key` — are rejected with `IDENTITY_FAILED`. The canonical schema is `aitp-identity.schema.json`; the handshake schema carries a mirror of it. See [RFC-AITP-0002 §1](../rfcs/RFC-AITP-0002-identity.md#1-identity-descriptor).

**`identity_hint`.** Static identity metadata in the Manifest — not a verifiable proof; the proof is exchanged inline in the Mutual Handshake. It MUST contain `type` and `subject`; for `oidc` it MUST also contain `issuer` and MUST NOT contain `public_key`; for `pinned_key` it MUST also contain `public_key`. It MUST NOT contain `proof`. See [RFC-AITP-0003 §3.1](../rfcs/RFC-AITP-0003-manifest.md#31-required-fields).

**Issuer.** For a TCT: the peer that signed it (`iss`). For an OIDC identity: the OpenID Provider that minted the JWT.

---

## J

**JCS (RFC 8785, JSON Canonicalization Scheme).** The canonical JSON form used as the signing input for the *JCS embedded-signature profile* — the envelope, Manifest, revocation snapshot, session bundle, and handshake payloads — as distinct from the compact JWS profile (TCT, grant voucher, delegation token). See [RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#541-signing-input-jcs-profile); implementation notes in the aitp-rs [JCS guide](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/jcs.md).

**`jkt` (JWK SHA-256 thumbprint).** RFC 7638 thumbprint of a public key, base64url-unpadded (43 chars). It is algorithm-agnostic: an Ed25519 `jkt` is computed from `{"crv":"Ed25519","kty":"OKP","x":"…"}` and a P-256 `jkt` from `{"crv":"P-256","kty":"EC","x":"…","y":"…"}`. See [RFC-AITP-0001 §5.4.4](../rfcs/RFC-AITP-0001-core.md#544-jwk-thumbprint-for-cnf), [RFC-AITP-0002 §2.2.1](../rfcs/RFC-AITP-0002-identity.md#221-canonical-jwk-form-for-cnfjkt).

**`jti` (JWT ID).** The UUID v4 identifier of a TCT and its revocation handle in the issuing peer's deny list. See [RFC-AITP-0005 §2](../rfcs/RFC-AITP-0005-tct.md#2-claims).

---

## K

**Key resolution.** How a peer obtains another party's signing key. Manifest-first for peer keys; cache → pinned → well-known for identity-issuer keys. See [RFC-AITP-0007](../rfcs/RFC-AITP-0007-key-resolution.md).

**`key_resolution.fail_mode`.** What happens when identity-issuer key resolution exhausts every source: `fail_closed` (schema default; `KEY_RESOLUTION_FAILED`), `fail_open`, or `soft_fail`. `fail_open` MUST NOT bypass signature validation — it only suppresses the network error when a cached or pinned issuer key already exists. `soft_fail` with no configured safe subset behaves as `fail_closed`. Configured independently of `revocation_policy.mode`. See [RFC-AITP-0007 §3](../rfcs/RFC-AITP-0007-key-resolution.md#3-failure-handling).

---

## M

**Manifest.** The signed self-description an agent publishes at `/.well-known/aitp-manifest`, served as `{"manifest": {…}}`; the signed object is the inner body. The discovery layer of AITP. See [RFC-AITP-0003](../rfcs/RFC-AITP-0003-manifest.md).

**`MANIFEST_INVALID`.** The structural-rejection code for a Manifest that does not validate against its schema (RFC-AITP-0003 §5 step 2), so a shape defect is not misreported as `MANIFEST_SIGNATURE_INVALID`. See [RFC-AITP-0003 §5](../rfcs/RFC-AITP-0003-manifest.md#5-manifest-verification).

**`message_id`.** The per-message UUID used for replay deduplication on the receiving peer. See [RFC-AITP-0001 §5.5](../rfcs/RFC-AITP-0001-core.md#55-replay-protection).

**Mutual Handshake.** The four-message peer authentication that produces two TCTs (one in each direction), each with an optional companion grant voucher. See [RFC-AITP-0004](../rfcs/RFC-AITP-0004-mutual-handshake.md).

---

## N

**`nonce` (OIDC identity JWT).** The JWT claim that MUST equal the `pop_nonce` carried on the same handshake message, byte-identically; it binds the identity proof to one handshake. See [RFC-AITP-0002 §2.2](../rfcs/RFC-AITP-0002-identity.md#22-required-jwt-claims).

---

## P

**Peer.** Either party in an A2A interaction. AITP has no asymmetric roles — every peer is both an issuer and an audience.

**PoP (Proof-of-Possession).** A signature proving the presenter holds the private key for a public key (the Manifest's AID, a handshake peer's AID, or a TCT's `cnf`). Every PoP signing input uses the base64url-*decoded* nonce or challenge bytes, never the ASCII string — `sha256(base64url_decode(nonce_or_challenge))`. Sites: Manifest PoP ([RFC-AITP-0003 §3.1](../rfcs/RFC-AITP-0003-manifest.md#31-required-fields), verified at [RFC-AITP-0003 §5](../rfcs/RFC-AITP-0003-manifest.md#5-manifest-verification) step 4), handshake round-2 PoP (RFC-AITP-0004 §3.3), downstream TCT PoP ([RFC-AITP-0005 §6.1](../rfcs/RFC-AITP-0005-tct.md#61-downstream-pop-exchange)), and the pinned-key identity proof. See [RFC-AITP-0001 §5.4.2](../rfcs/RFC-AITP-0001-core.md#542-pop-signing-input-convention).

**`#pop_required`.** The RECOMMENDED convention for marking a TCT grant that requires downstream PoP: a grant string of the form `<capability>#pop_required` signals that a consumer MUST run the `pop_challenge` / `pop_response` exchange before authorizing the grant. Deployments MAY use a different marking scheme if both peers agree out-of-band. See [RFC-AITP-0005 §6](../rfcs/RFC-AITP-0005-tct.md#6-binding-proof-of-possession).

**`pop_nonce`.** The per-handshake 128-bit challenge (22 base64url chars) used to bind PoP signatures to a specific exchange. Echoed back in `pop_nonce_echo` (mismatch ⇒ `NONCE_MISMATCH`) and also carried as the OIDC identity JWT's `nonce`. See [RFC-AITP-0004 §3](../rfcs/RFC-AITP-0004-mutual-handshake.md#3-message-definitions).

---

## R

**Redistributable.** An artifact that can reach a verifier by some path other than that verifier's own pull from the issuer — relayed, embedded in another party's message, or served from a third party's cache. Redistributable JCS-profile artifacts (Manifest, session bundle) MUST carry `signature` as a member of the signed body; a point-to-point artifact pulled directly from its issuer and never passed on (the revocation snapshot) MAY instead carry it as a sibling *of the wrapped body* — i.e. a second member of the transport wrapper object, alongside the artifact-name key, rather than a member of the body itself. (It is not a sibling of the wrapper: nothing sits outside the outer object.) A verifier caching what it pulled does not make an artifact redistributable — caching changes how long a verifier holds it, not who hands it over. See [RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#541-signing-input-jcs-profile).

**Revocation.** Per-issuing-peer JTI deny lists. Each agent maintains the deny list for the TCTs it issued and publishes it as a signed snapshot via `ListRevoked`; verifiers consult the list belonging to the TCT's issuer, only after every signature check, and reject a listed TCT with `TCT_REVOKED`. Revoking a TCT also kills its voucher and every delegation built on it (`src_jti`). See [RFC-AITP-0008](../rfcs/RFC-AITP-0008-revocation.md).

**`revocation_policy.mode` / `max_staleness_secs`.** What a consuming peer does when it has no fresh revocation snapshot for an issuer. `max_staleness_secs` is the maximum age of a cached snapshot (schema default 300). `mode` is `fail_closed` (schema default — an absent snapshot is treated as revoked, `TCT_REVOKED`), `fail_open` (allow and log), or `soft_fail` (allow with restricted grants). See [RFC-AITP-0008 §3.1](../rfcs/RFC-AITP-0008-revocation.md#31-modes), [RFC-AITP-0008 §3.2](../rfcs/RFC-AITP-0008-revocation.md#32-staleness).

**RFC.** A normative document under `rfcs/`. AITP RFCs are numbered RFC-AITP-NNNN. See [governance/RFC-PROCESS.md](../governance/RFC-PROCESS.md) for the lifecycle.

---

## S

**Scope.** A delegation token's `scope` array — the capabilities delegated to the delegatee. It MUST satisfy `scope ⊆ voucher.grants`, else `DELEGATION_SCOPE_EXCEEDED`. See [RFC-AITP-0006 §4](../rfcs/RFC-AITP-0006-delegation.md#4-verification-rules) step 6.

**Session Trust Bundle.** A JCS-signed `session_bundle` a coordinator builds from its N bilateral handshakes, carrying each participant's TCT, so session members get coordinator-attested membership without an O(N²) mesh. Draft, opt-in; not part of v0.2 core conformance. See [RFC-AITP-0010](../rfcs/RFC-AITP-0010-session-trust-bundle.md).

**`src_jti`.** Grant-voucher claim holding the companion TCT's `jti`. Delegation verification looks it up in the issuer's deny list (after all signature checks) and rejects with `DELEGATION_SOURCE_TCT_REVOKED`. See [RFC-AITP-0005 §8.1](../rfcs/RFC-AITP-0005-tct.md#81-serialization).

**Status ladder.** The single RFC lifecycle: `Reserved → Planned → Idea → Draft → Review → Release Candidate → Final Comment Period → Accepted | Rejected`. RFCs 0001–0011 are Draft (0010 and 0011 opt-in), 0012 is Reserved, 0013 is Planned; see [`rfcs/README.md`](../rfcs/README.md) for the live table and [governance/RFC-PROCESS.md](../governance/RFC-PROCESS.md#rfc-lifecycle) for the stage definitions.

**Structural rejection.** Rejecting an artifact that does not match its schema (missing REQUIRED member, wrong type, value outside its grammar) before any cryptography. The registry's table fixes the code per artifact — e.g. `INVALID_ENVELOPE`, `MANIFEST_INVALID`, `IDENTITY_FAILED`, `REVOCATION_SNAPSHOT_INVALID`; the compact-JWS artifacts collapse onto their signature-family code (`TCT_SIGNATURE_INVALID`, `DELEGATION_INVALID_VOUCHER`, `DELEGATION_INVALID_SIGNATURE`). `UNKNOWN_FIELD` wins when an unknown member is the only defect. See the [structural-rejection table](../registries/error-codes.md#structural-rejection).

**Subject (`sub`).** For a TCT: the peer the grant was issued for. The TCT's `aud` MUST equal `sub`, and `cnf.jkt` MUST match the key in `sub`. See [RFC-AITP-0005 §2](../rfcs/RFC-AITP-0005-tct.md#2-claims).

---

## T

**TCT (Trust Context Token).** The canonical AITP artifact: a signed, audience-bound, capability-scoped grant produced by a peer, serialized as a compact JWS with `typ` `aitp-tct+jwt` and claims `ver`, `jti`, `iss`, `sub`, `aud`, `iat`, `exp`, `grants`, `cnf` (and optional `ext`). Verified locally — no third-party lookup. See [RFC-AITP-0005](../rfcs/RFC-AITP-0005-tct.md); verification order in [RFC-AITP-0005 §7.2](../rfcs/RFC-AITP-0005-tct.md#72-verification-order).

**Transport wrapper** (a.k.a. artifact-name wrapper). The outer JSON object whose key names a JCS-profile artifact for routing — `{"manifest": …}`, `{"revocation_list": …}`, `{"session_bundle": …}`. Not always single-keyed: the revocation-list wrapper additionally carries a sibling `signature` member, `{"revocation_list": …, "signature": "…"}` (RFC-AITP-0008 §1.5), because the revocation snapshot is the one JCS-profile artifact whose signature sits outside the signed body rather than inside it (see *Redistributable*, above). The artifact-naming key itself is routing metadata, never part of the signing bytes; issuers sign and verifiers reconstruct the inner artifact body. See [RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#541-signing-input-jcs-profile).

**Trust anchor.** An identity issuer (with its keys) or pinned key that a peer is locally configured to accept (`trust_anchors`, `pinned_keys`). A peer MUST NOT accept identity from issuers outside its trust anchors. The OIDC issuer list is also published in the peer's Manifest as `accepted_trust_anchors` (see that entry for how it is used at discovery). See [RFC-AITP-0002 §4](../rfcs/RFC-AITP-0002-identity.md#4-trust-anchors).

**`typ` (explicit typing).** Every AITP JWS carries an explicit RFC 8725 type — `aitp-tct+jwt`, `aitp-grant+jwt`, `aitp-delegation+jwt` — and a verifier rejects any token whose `typ` is not exactly the one expected in that context with `TOKEN_TYP_MISMATCH`. This prevents a voucher or delegation token being accepted as a TCT. See [RFC-AITP-0001 §5.4.5](../rfcs/RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts), [RFC-AITP-0009 §1.13](../rfcs/RFC-AITP-0009-security.md#113-token-type-confusion).

---

## U

**`UNKNOWN_FIELD`.** The single core code for a signed object carrying a member outside its schema and outside its extension namespace (`extensions` on JCS-profile objects, `ext` on JWS claims). Unknown keys *inside* the namespace are ignored, never rejected. Each artifact RFC runs this check before its cryptographic steps (for a TCT, after `typ` enforcement). See [RFC-AITP-0001 §7](../rfcs/RFC-AITP-0001-core.md#7-compatibility-model), [`registries/error-codes.md`](../registries/error-codes.md).

---

## V

**Verifier.** AITP has *no* dedicated verifier role. Every peer is its own verifier for the peer it is authenticating. Avoid the term in normative text; use *receiver* or *peer* instead.

**`voucher`.** The delegation-token claim carrying the issuing peer's grant voucher compact JWS verbatim; the delegator MUST NOT decode-and-re-encode it. The issuer checks that `voucher.iss` is itself and that `voucher.sub` equals the delegation's `iss`, else `DELEGATION_INVALID_VOUCHER`. See [RFC-AITP-0006 §2](../rfcs/RFC-AITP-0006-delegation.md#2-delegation-token), [RFC-AITP-0006 §4](../rfcs/RFC-AITP-0006-delegation.md#4-verification-rules).
