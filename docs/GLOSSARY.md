# AITP Glossary

Terms used across AITP RFCs, schemas, and registries. The authoritative definitions live in the RFC sections referenced from each entry; this glossary is a non-normative quick reference.

---

## Concept Index

A one-line "what is X / where is it defined" lookup for the core AITP concepts. For longer definitions, scroll to the alphabetical section below.

| Concept | One-line definition | Authoritative location |
|---|---|---|
| **AID** | Cryptographic agent identifier (`aid:pubkey:<43-char base64url>`). | [RFC-AITP-0001 §5.3](../rfcs/RFC-AITP-0001-core.md#53-agent-id-aid) |
| **Envelope** | Outer signed object every AITP message ships in. | [RFC-AITP-0001 §5](../rfcs/RFC-AITP-0001-core.md#5-message-envelope) |
| **JCS signing input** | Canonical JSON form (RFC 8785) of the inner artifact body — transport wrapper stripped, `signature` member excluded. | [RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#541-signing-input-jcs-profile) |
| **Replay protection** | `message_id` deduplication + `timestamp` tolerance window. | [RFC-AITP-0001 §5.5](../rfcs/RFC-AITP-0001-core.md#55-replay-protection) |
| **Identity binding** | How an AID is bound to a verifiable claim from a trusted issuer. | [RFC-AITP-0002](../rfcs/RFC-AITP-0002-identity.md) |
| **OIDC identity** | JWT proof with `aud` (verifying peer's AID) and `cnf.jkt` (AID key thumbprint). | [RFC-AITP-0002 §2](../rfcs/RFC-AITP-0002-identity.md#2-oidc-identity-type) |
| **Pinned-key identity** | Signature over `(sender, receiver, message_id, timestamp, pop_nonce)`. | [RFC-AITP-0002 §3.1](../rfcs/RFC-AITP-0002-identity.md#31-proof-format) |
| **Manifest** | Signed self-description served at `/.well-known/aitp-manifest`. | [RFC-AITP-0003](../rfcs/RFC-AITP-0003-manifest.md) |
| **`identity_hint`** | Static issuer/subject metadata in the Manifest (no JWT). | [RFC-AITP-0003 §3](../rfcs/RFC-AITP-0003-manifest.md#3-fields) |
| **Mutual Handshake** | Four-message peer authentication producing two TCTs. | [RFC-AITP-0004](../rfcs/RFC-AITP-0004-mutual-handshake.md) |
| **Grant intersection** | TCT grants are `requested_grants ∩ identity_policy ∩ offered_capabilities`. | [RFC-AITP-0004 §4.1](../rfcs/RFC-AITP-0004-mutual-handshake.md#41-grant-intersection) |
| **TCT** | Signed, audience-bound, capability-scoped peer-issued grant. | [RFC-AITP-0005](../rfcs/RFC-AITP-0005-tct.md) |
| **`cnf.jkt`** | Top-level confirmation claim on the TCT / delegation token — subject key thumbprint for downstream PoP. | [RFC-AITP-0005 §3](../rfcs/RFC-AITP-0005-tct.md#3-confirmation-claim-cnf) |
| **JTI** | UUID v4 token ID on a TCT; key for revocation lookups. | [RFC-AITP-0005 §2](../rfcs/RFC-AITP-0005-tct.md#2-claims) |
| **Delegation** | Single-hop subset grant (A → B → C); a compact JWS embedding the issuing peer's grant voucher. | [RFC-AITP-0006](../rfcs/RFC-AITP-0006-delegation.md) |
| **Key resolution** | Manifest-first for peers; cache → pinned → well-known for issuers. | [RFC-AITP-0007](../rfcs/RFC-AITP-0007-key-resolution.md) |
| **Revocation** | Per-issuing-peer JTI deny lists, pull-based. | [RFC-AITP-0008](../rfcs/RFC-AITP-0008-revocation.md) |
| **`extensions`** | Reserved field for future extension namespaces (`zk`, `tee`). | [RFC-AITP-0012](../rfcs/RFC-AITP-0012-extensions.md) |
| **PoP** | Proof-of-Possession: signature over a fresh nonce by the holder's private key. | [RFC-AITP-0003 §6](../rfcs/RFC-AITP-0003-manifest.md#6-manifest-signature), [RFC-AITP-0005 §6](../rfcs/RFC-AITP-0005-tct.md#6-binding-proof-of-possession) |
| **Trust anchor** | Locally configured trusted issuer (or pinned key) used to verify peers. | [RFC-AITP-0002 §4](../rfcs/RFC-AITP-0002-identity.md#4-trust-anchors) |

---

## A

**A2A (Agent-to-Agent).** The trust model AITP defines: two autonomous agents establish bilateral trust without a central verifier. There is no service-consumer profile in v0.1. See [RFC-AITP-0001 §1](../rfcs/RFC-AITP-0001-core.md).

**AID (Agent Identifier).** The canonical, public identifier of an agent. v0.1 form: `aid:pubkey:<43-char base64url>`, where the trailing 43 characters are the unpadded base64url encoding of a 32-byte raw Ed25519 public key. SPKI DER and PEM are not permitted in v0.1. See [RFC-AITP-0001 §5.3](../rfcs/RFC-AITP-0001-core.md).

**Audience.** The peer a TCT is bound to. The audience peer is the only one who can present the TCT for the capabilities it carries. See [RFC-AITP-0005 §3](../rfcs/RFC-AITP-0005-tct.md).

---

## B

**Binding.** The proof-of-possession mechanism that ties a TCT (and the inline TCT carried in MUTUAL_COMMIT) to its subject's private key, so a downstream consumer can challenge the holder. In `aitp/0.2` this is the top-level `cnf` claim on the token — a nested `binding.cnf` object, as `aitp/0.1` used, does not appear in v0.2 tokens. `cnf` is REQUIRED on every v0.2 peer-issued TCT. See [RFC-AITP-0005 §3](../rfcs/RFC-AITP-0005-tct.md#3-confirmation-claim-cnf), [§6](../rfcs/RFC-AITP-0005-tct.md#6-binding-proof-of-possession).

---

## C

**Capability.** An opaque string identifying an action a peer is willing to grant or accept. AITP does not define what a capability means — that is owned by the namespace prefix (e.g. `macp.*`, `aitp.handshake.v1`). See [RFC-AITP-0005 §4.2.1](../rfcs/RFC-AITP-0005-tct.md).

**`cnf` (Confirmation Claim).** The RFC 7800 confirmation claim on a TCT or delegation token, so a downstream verifier can challenge the holder. In `aitp/0.2` it is a top-level claim — not a nested `binding.cnf` object as in `aitp/0.1` — and takes the `jkt` form only: `{"jkt": "<RFC 7638 JWK thumbprint>"}`. `cnf.jkt` MUST equal the thumbprint of the public key encoded in the token's `sub` AID. See [RFC-AITP-0001 §5.4.4](../rfcs/RFC-AITP-0001-core.md#544-jwk-thumbprint-for-cnf), [RFC-AITP-0005 §3](../rfcs/RFC-AITP-0005-tct.md#3-confirmation-claim-cnf).

**Conformance fixture.** A JSON file under `schemas/conformance/` describing a scenario, its input, and the expected outcome. Implementations MUST produce the specified outcome for each fixture they support.

**Core Team.** The body responsible for shepherding RFCs and cutting releases. See [governance/CHARTER.md](../governance/CHARTER.md).

---

## D

**Delegation.** Single-hop: a peer that holds a TCT and a companion grant voucher can issue a delegation token granting a strict subset of its capabilities to a third peer. In `aitp/0.2` the delegation token is a compact JWS, signed by the delegator, that embeds the issuing peer's grant voucher verbatim as its `voucher` claim — the v0.1 `grant_proof` minimized-projection mechanism is gone. Multi-hop chains are specified in [RFC-AITP-0011](../rfcs/RFC-AITP-0011-multihop-delegation.md) (Draft) and are not part of v0.2 conformance. See [RFC-AITP-0006](../rfcs/RFC-AITP-0006-delegation.md).

---

## E

**Envelope.** The outer signed object every AITP message ships in. Carries `version`, `message_type`, `message_id`, `timestamp`, `sender`, `payload`, and `signature`. See [RFC-AITP-0001 §5](../rfcs/RFC-AITP-0001-core.md).

**Extensions.** The optional `extensions` namespace on protocol payloads. v0.1 reserves `extensions.zk` and `extensions.tee` for future normative use. See [RFC-AITP-0012](../rfcs/RFC-AITP-0012-extensions.md).

---

## G

**Grant.** One of the strings in a TCT's `grants` array. See *Capability*.

**`grant_proof`.** The `aitp/0.1` mechanism: a minimized projection of the source TCT carried inside a delegation token, verified by byte-exact reconstruction of the source TCT's canonical JSON. Retired in `aitp/0.2` and replaced by the **grant voucher** — an independently signed compact JWS (`typ: aitp-grant+jwt`) that the issuing peer mints alongside a TCT and the delegator embeds verbatim in its delegation token's `voucher` claim. Verification is an ordinary JWS check over transmitted bytes; no reconstruction step exists in v0.2. See [RFC-AITP-0005 §8](../rfcs/RFC-AITP-0005-tct.md#8-grant-voucher), [RFC-AITP-0006 §2](../rfcs/RFC-AITP-0006-delegation.md#2-delegation-token).

---

## I

**Identity binding.** The mechanism by which an AID is associated with an external identity claim (OIDC token, pinned key, …). Pluggable. See [RFC-AITP-0002](../rfcs/RFC-AITP-0002-identity.md).

**`identity_hint`.** Static identity metadata in the Manifest (`type`, `subject`, `issuer`). Not a verifiable proof — the verifiable identity proof is exchanged inline in the Mutual Handshake.

**Issuer.** For a TCT: the peer that signed it. For an OIDC identity: the OpenID Provider that minted the JWT.

---

## J

**JCS (RFC 8785, JSON Canonicalization Scheme).** The canonical JSON form used as the signing input for the *JCS embedded-signature profile* — the envelope, Manifest, revocation snapshot, session bundle, and handshake payloads — as distinct from the Compact JWS profile (TCT, grant voucher, delegation token). See [RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#541-signing-input-jcs-profile).

**`jkt` (JWK SHA-256 thumbprint).** RFC 7638 thumbprint of the agent's confirmation key, computed over the exact JWK form `{"crv":"Ed25519","kty":"OKP","x":"<aid-id>"}`.

**`jti` (JWT ID).** The unique identifier of a TCT. Used as the key for revocation lookups in the issuing peer's deny list.

---

## K

**Key resolution.** How a peer obtains another peer's signing key. Manifest-first for peer keys; cache → pinned → well-known for identity-issuer keys. See [RFC-AITP-0007](../rfcs/RFC-AITP-0007-key-resolution.md).

---

## M

**Manifest.** The signed self-description an agent publishes at `/.well-known/aitp-manifest`. The discovery layer of AITP. See [RFC-AITP-0003](../rfcs/RFC-AITP-0003-manifest.md).

**`message_id`.** The per-message UUID used for replay deduplication on the receiving peer. See [RFC-AITP-0001 §5.5](../rfcs/RFC-AITP-0001-core.md).

**Mutual Handshake.** The four-message peer authentication that produces two TCTs (one in each direction). See [RFC-AITP-0004](../rfcs/RFC-AITP-0004-mutual-handshake.md).

---

## P

**Peer.** Either party in an A2A interaction. AITP has no asymmetric roles — every peer is both an issuer and an audience.

**PoP (Proof-of-Possession).** A signature over a fresh, server-supplied or handshake-bound nonce that proves the presenter holds the private key matching a public key (e.g. the Manifest's AID, or a TCT's `cnf`). See [RFC-AITP-0003 §6](../rfcs/RFC-AITP-0003-manifest.md), [RFC-AITP-0005 §6](../rfcs/RFC-AITP-0005-tct.md).

**`#pop_required`.** The RECOMMENDED v0.1 convention for marking a TCT grant that requires downstream PoP: a grant string of the form `<capability>#pop_required` signals that a consumer MUST run the `pop_challenge` / `pop_response` exchange before authorizing the grant. Deployments MAY use a different marking scheme if both peers agree out-of-band. See [RFC-AITP-0005 §6](../rfcs/RFC-AITP-0005-tct.md#6-binding-proof-of-possession).

**`pop_nonce`.** The per-handshake challenge used to bind PoP signatures to a specific exchange. Echoed back in `pop_nonce_echo` to prevent cross-handshake replay.

---

## R

**Redistributable.** An artifact that can reach a verifier by some path other than that verifier's own pull from the issuer — relayed, embedded in another party's message, or served from a third party's cache. Redistributable JCS-profile artifacts (Manifest, session bundle) MUST carry `signature` as a member of the signed body; a point-to-point artifact pulled directly from its issuer and never passed on (the revocation snapshot) MAY carry it as a sibling of the transport wrapper. A verifier caching what it pulled does not make an artifact redistributable — caching changes how long a verifier holds it, not who hands it over. See [RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#541-signing-input-jcs-profile).

**Revocation.** Per-issuing-peer JTI deny lists. Each agent maintains the deny list for the TCTs it issued; verifiers consult the list belonging to the TCT's issuer. See [RFC-AITP-0008](../rfcs/RFC-AITP-0008-revocation.md).

**RFC.** A normative document under `rfcs/`. AITP RFCs are numbered RFC-AITP-NNNN. See [governance/RFC-PROCESS.md](../governance/RFC-PROCESS.md) for the lifecycle.

---

## S

**Scope.** A delegation token's `scope` array — the strict subset of the source TCT's capabilities the delegator is conveying.

**Subject.** For a TCT: the peer the grant is about. In v0.1 the subject equals the audience (the holder is the subject of the receipt).

---

## T

**TCT (Trust Context Token).** The canonical AITP artifact: a signed, audience-bound, capability-scoped grant produced by a peer. Verified locally — no third-party lookup. See [RFC-AITP-0005](../rfcs/RFC-AITP-0005-tct.md).

**Transport wrapper** (a.k.a. artifact-name wrapper). The outer JSON object whose single key names a JCS-profile artifact for routing — `{"manifest": …}`, `{"revocation_list": …}`, `{"session_bundle": …}`. It is routing metadata, never part of the signing bytes; issuers sign and verifiers reconstruct the inner artifact body. See [RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#541-signing-input-jcs-profile).

**Trust anchor.** An identity-issuer URL (or pinned key reference) a peer is willing to accept. Listed in a Manifest's `accepted_trust_anchors`. The intersection across two Manifests determines whether a handshake is even worth attempting.

---

## V

**Verifier.** AITP has *no* dedicated verifier role. Every peer is its own verifier for the peer it is authenticating. Avoid the term in normative text; use *receiver* or *peer* instead.
