# Threat Model — Quick Reference

The normative threat model is [RFC-AITP-0009 Security](../rfcs/RFC-AITP-0009-security.md). This page is a non-normative index into it: each row names the threat, the defense in one line, and the section that states it. Read the cited section for the actual requirements.

## Threats addressed in v0.2

| Threat | Defense (summary) | Normative source |
|---|---|---|
| Impersonation | Envelopes signed by the sender's AID key; identity binding by PoP or trusted-issuer credential; round-2 handshake PoP; TCT bound to the subject key via `cnf.jkt`. | [RFC-AITP-0009 §1.1](../rfcs/RFC-AITP-0009-security.md#11-impersonation) |
| Replay | `message_id` deny list + timestamp window + handshake nonce echoes + TCT `exp` + `jti` revocation. | [RFC-AITP-0009 §1.2](../rfcs/RFC-AITP-0009-security.md#12-replay); [RFC-AITP-0001 §5.5](../rfcs/RFC-AITP-0001-core.md#55-replay-protection) |
| Manifest tampering | Manifest signature + PoP over a publish-time challenge, both verified before any handshake. | [RFC-AITP-0009 §1.3](../rfcs/RFC-AITP-0009-security.md#13-manifest-tampering) |
| Manifest replay across agents | PoP verified under the key in `manifest.aid`; the signature covers `aid`. | [RFC-AITP-0009 §1.4](../rfcs/RFC-AITP-0009-security.md#14-manifest-replay-across-agents) |
| Confused deputy | Delegation tokens carry `aud` = the issuing peer A's AID (`DELEGATION_AUDIENCE_MISMATCH` otherwise); TCT `aud` MUST be the subject peer's AID (`AUDIENCE_MISMATCH`); no wildcard audiences. | [RFC-AITP-0009 §1.5](../rfcs/RFC-AITP-0009-security.md#15-confused-deputy) |
| Token theft and misuse | `cnf.jkt` binds the TCT to the subject's key; downstream PoP; short TTLs; `jti` revocation. | [RFC-AITP-0009 §1.6](../rfcs/RFC-AITP-0009-security.md#16-token-theft-and-misuse) |
| Delegation scope escalation | Delegation embeds A's signed grant voucher; `scope ⊆ voucher.grants` (`DELEGATION_SCOPE_EXCEEDED`); `voucher.sub` MUST equal the outer `iss` (`DELEGATION_INVALID_VOUCHER`); stateless. | [RFC-AITP-0009 §1.7](../rfcs/RFC-AITP-0009-security.md#17-delegation-scope-escalation); [RFC-AITP-0006 §4](../rfcs/RFC-AITP-0006-delegation.md#4-verification-rules) |
| Peer-AID confusion | TCT `iss` is a peer AID; its key is resolved from that peer's Manifest, never from `trust_anchors`. | [RFC-AITP-0009 §1.8](../rfcs/RFC-AITP-0009-security.md#18-peer-aid-confusion) |
| PoP nonce binding failure | `pop_nonce_echo` MUST equal the value sent in the previous round, checked before any TCT or PoP is constructed. | [RFC-AITP-0009 §1.9](../rfcs/RFC-AITP-0009-security.md#19-pop-nonce-binding-failure) |
| Key compromise (partial) | Revoke issued `jti`s, re-publish under a new AID, short TTLs; no real-time detection. | [RFC-AITP-0009 §1.10](../rfcs/RFC-AITP-0009-security.md#110-key-compromise); [RFC-AITP-0003 §8.1](../rfcs/RFC-AITP-0003-manifest.md#81-emergency-rotation-key-compromise) |
| Manifest PoP bypass (wrong signing input) | `sign(sha256(base64url_decode(challenge)))`, verified before any other Manifest field is trusted; pinned KAT `kat-manifest-pop-001`. | [RFC-AITP-0009 §1.11](../rfcs/RFC-AITP-0009-security.md#111-manifest-pop-bypass) |
| Algorithm confusion | No negotiation: the sole acceptable JWS `alg` is derived from the signer's AID before any cryptography (`TOKEN_ALG_MISMATCH`); headers carrying key material are rejected. | [RFC-AITP-0009 §1.12](../rfcs/RFC-AITP-0009-security.md#112-algorithm-confusion) |
| Token-type confusion | Every AITP JWS carries an exact `typ` (`aitp-tct+jwt`, `aitp-grant+jwt`, `aitp-delegation+jwt`), enforced early (`TOKEN_TYP_MISMATCH`). | [RFC-AITP-0009 §1.13](../rfcs/RFC-AITP-0009-security.md#113-token-type-confusion) |
| Unsecured JWS (`alg: none`) | `none` can never equal the AID-derived `alg`; strict three-non-empty-segment parsing rejects signature-less tokens. | [RFC-AITP-0009 §1.14](../rfcs/RFC-AITP-0009-security.md#114-unsecured-jws-alg-none) |
| Signature ambiguity from unknown fields | Unknown members outside `extensions` / `ext` are rejected with `UNKNOWN_FIELD` before any signature check, so no two implementations hash different bytes for the same object. | [RFC-AITP-0001 §7](../rfcs/RFC-AITP-0001-core.md#7-compatibility-model) |
| Revocation-lookup DoS (reflection, cache pollution) | Network revocation lookups keyed on `iss` / `jti` / `voucher.src_jti` run only after every signature has verified; pinned by fixture `rev-004`. | [RFC-AITP-0008 §3.3](../rfcs/RFC-AITP-0008-revocation.md#33-revocation-lookup-ordering) |
| Handshake-endpoint DoS | MUST rate-limit per source AID or IP; RECOMMENDED limits and a normative replay → rate-limit → timestamp → size → signature → payload check order. | [RFC-AITP-0004 §11.4](../rfcs/RFC-AITP-0004-mutual-handshake.md#114-denial-of-service-on-handshake-endpoint); [RFC-AITP-0009 §3.1](../rfcs/RFC-AITP-0009-security.md#31-rate-limiting-recommended) |

Operational settings that implement several of these defenses (tolerances, cache lifetimes, fail modes, rate limits) are collected with their sources in [operational-guidance.md](operational-guidance.md).

## Known limitations in v0.2

The authoritative list is [RFC-AITP-0009 §2](../rfcs/RFC-AITP-0009-security.md#2-known-limitations-v02).

| Limitation | Status |
|---|---|
| No real-time key-revocation push | Pull-based; staleness bounded by `max_staleness_secs` ([RFC-AITP-0008 §3.2](../rfcs/RFC-AITP-0008-revocation.md#32-staleness)). |
| No Sybil resistance | Delegated to identity providers. |
| No runtime integrity attestation | TEE extension reserved in [RFC-AITP-0012](../rfcs/RFC-AITP-0012-extensions.md). |
| No ZK compliance proofs | ZK extension reserved in RFC-AITP-0012. |
| Multi-hop delegation is not core | Specified in [RFC-AITP-0011](../rfcs/RFC-AITP-0011-multihop-delegation.md) (Draft, opt-in). |
| Multi-agent session scaling is not core | Specified in [RFC-AITP-0010](../rfcs/RFC-AITP-0010-session-trust-bundle.md) (Draft, opt-in). |
| No cross-domain trust federation | Future specification. |

## Attack walkthroughs

Worked scenarios — C replaying B's delegation at D, B escalating scope, a replayed `MUTUAL_HELLO`, a stolen TCT, a swapped Manifest — are in [RFC-AITP-0009 §6](../rfcs/RFC-AITP-0009-security.md#6-attack-walkthroughs). In short:

1. **C presents B's delegation token to D.** D rejects: the delegation's `aud` is A's AID, not D's (`DELEGATION_AUDIENCE_MISMATCH`).
2. **B claims more scope than A granted.** A rejects: `scope ⊆ voucher.grants` fails (`DELEGATION_SCOPE_EXCEEDED`).
3. **Replayed `MUTUAL_HELLO`.** Rejected: its `message_id` is already in B's deny list.
4. **Stolen TCT.** The attacker cannot prove possession of the key matching `cnf.jkt`; consumers enforcing PoP reject it.
5. **Swapped Manifest.** The PoP must verify under the key in `manifest.aid`; without that private key (and a valid TLS certificate for the host) the swap fails.
