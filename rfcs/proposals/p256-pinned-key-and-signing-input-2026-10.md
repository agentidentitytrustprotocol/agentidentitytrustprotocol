# Proposal: P-256 pinned keys, one P-256 signing input, and the related gaps

**Stage:** Idea. This is an unnumbered proposal under [RFC-PROCESS.md](../../governance/RFC-PROCESS.md). It amends existing RFCs and does not ask for a new RFC number.
**Amends:** [RFC-AITP-0001](../RFC-AITP-0001-core.md) §5.2, §5.4, §5.4.3, §11; [RFC-AITP-0002](../RFC-AITP-0002-identity.md) §1, §3.1–§3.3, §3.4 (new); [RFC-AITP-0005](../RFC-AITP-0005-tct.md) §2, §5.3 (new), §8.1, §9, §10.4; [RFC-AITP-0009](../RFC-AITP-0009-security.md) §4; `schemas/json/aitp-identity.schema.json`; `schemas/conformance/known-answer/`.
**Spec baseline:** `ab7f67c`. **Implementations checked:** aitp-rs `b19d3f2` (0.13.2) and aitp-verifier-py `f36bf9f`.
**Related open issues:** #68 (the `cnf.jkt` JWK is pinned to Ed25519, which is the OIDC-side P-256 gap). #69 (RFC-0004 §11.4 MUST vs RFC-0009 §3.1 SHOULD on rate limiting) now also bears on Item 5's challenge issuance. #67 is not affected.
**Revised:** 2026-10-16, after implementer review against a coordination-host deployment. Changes: Item 4 adds an external-signer note; Item 3 (envelope v2) is withdrawn from this proposal and deferred to a v0.3 proposal; Item 5 adds `pop_nonce` and challenge rate-limit rules and replaces the self-attestation subsection with an archival attestation profile using a marker grant; Item 6b allows deterministic v4-shaped identifiers and fixes the error codes; new Item 7 (implementation API notes, informative, including a reference nonce store); new "Promotion and sequencing" section; open questions resolved per owner decisions of 2026-10-16.

---

## Summary

AITP v0.2 makes P-256 a REQUIRED verification algorithm. The spec does not pin how P-256 is used:

- §5.4 writes every JCS-profile signature as `sign(sk, sha256(input))`.
- The P-256 algorithm is named "ECDSA on P-256 with SHA-256".

Read literally, that is ECDSA over `SHA-256(SHA-256(input))`. aitp-rs implements that double hash. aitp-verifier-py implements a single hash (ECDSA over `SHA-256(input)`). Signatures from one fail verification in the other. No committed P-256 JCS vector exists, so CI cannot see the disagreement. Separately, the `pinned_key` identity type is written as Ed25519-only (RFC-0002 §3.3), which contradicts the requirement that both algorithms be supported.

This proposal makes five normative changes (Item 3 is deferred) and adds KAT vectors for each:

1. Pin a **single-hash P-256 signing input** for every JCS-profile and proof signature.
2. Define **P-256 `pinned_key`** identities: key form, proof encoding and trust-store key.
3. ~~Resolve the envelope `extensions` signing contradiction.~~ Deferred to a v0.3 proposal (see Item 3).
4. Add **verification-strictness rules** for Ed25519 (strict) and P-256 (low-S).
5. Add a **one-way pinned-key admission and self-attestation profile**.
6. Fix three smaller inconsistencies: the descriptor `subject` claim, `jti` v4 enforcement, and descriptor `type` dispatch.

Item 7 is informative. It lists the library API shapes that Items 1–6 force on implementations, so that each one can absorb the change in a single breaking release.

## Motivation

- **Both algorithms are mandatory.** RFC-0001 §5.4.3 (`:364-367`) says "Both are mandatory in v0.2. A v0.2 peer MUST be able to verify both, even if it only signs with one." RFC-0009 §4 (`:223`) says the same.
- **KMS/HSM custody depends on P-256.** RFC-0001 §11 (`:628`) requires keys "in secure storage". Cloud KMS products and FIPS HSMs support ECDSA P-256 everywhere. Ed25519 support across them is uneven.
  - A deployment that wants its agents' private keys to never leave an HSM will choose P-256.
  - Today such a deployment cannot use `pinned_key` at all.
  - Its JCS signatures (Manifest, envelope, PoP, revocation snapshot, session bundle) do not interoperate across the two independent implementations.
- **KMS APIs sign a digest, once.** AWS KMS `Sign` with `MessageType=DIGEST`, GCP KMS `AsymmetricSign` with `digest.sha256`, Azure Key Vault `ES256` and PKCS#11 `CKM_ECDSA` all take the 32-byte SHA-256 digest and apply ECDSA to it directly. None of them adds a second hash.
  - A single-hash rule maps 1:1 onto these APIs.
  - The result is also exactly what any JOSE/WebCrypto `ES256` verifier checks over the pre-hash input.
- **The KAT rule did not catch this.** The RFC-PROCESS KAT rule exists to prevent "self-consistent but non-interoperable" bugs, and this is one.
  - `env-005-p256-envelope-success` is the only positive P-256 JCS fixture. It is placeholder-minted (`__VALID_ENVELOPE_SIG__`), so each implementation mints and verifies under its own convention.
  - `kat-keypair-005-p256` and `kat-jwk-thumb-005-p256` pin keys only, not signatures.

---

## Item 1: P-256 signing input for the JCS profile and proofs (RFC-0001 §5.4, §5.4.2, §5.4.3; RFC-0002 §3.1)

### Problem

- RFC-0001 §5.4 (`:235`): `signature = base64url(sign(sender_private_key, sha256(sig_input)))`.
- RFC-0002 §3.1 (`:166`): `proof = base64url(sign(agent_private_key, sha256(proof_input)))`.
- RFC-0001 §5.4.2: PoP signs `sha256(base64url_decode(nonce))`.
- RFC-0001 §5.4.3 (`:364`) names the algorithm "ECDSA on P-256 with SHA-256".

`sign()` is never defined for P-256, so two readings are possible:

| Reading | ECDSA input `e` | Implemented by |
|---|---|---|
| Double hash: `ECDSA-SHA256.Sign(sk, sha256(input))` | `SHA-256(SHA-256(input))` | aitp-rs. `aitp-crypto/src/keys.rs:189,502-503` calls RustCrypto `Signer::sign`, which hashes again. It is fed `Sha256::digest(..)` at every JCS site, e.g. `aitp-envelope/src/lib.rs:36-38`, `aitp-manifest/src/builder.rs:209-210,266-267`, `aitp-handshake/src/identity_pinned.rs:178-179`. |
| Single hash: ECDSA applied to the digest | `SHA-256(input)` | aitp-verifier-py, `crypto.py:160-177` (`ec.ECDSA(utils.Prehashed(SHA256))`). The env-005 `$comment` also reads this way: "ECDSA P-256/SHA-256 over the envelope signing input". |

**Reproduced at the baseline SHAs:**

- aitp-rs P-256 signatures over the env-005 envelope and over a pinned-key proof both fail `aitp-verifier-py` `verify_digest`.
- The same signatures fail pyca `ECDSA(SHA256)` over the input.
- They verify only as ECDSA-SHA256 over `sha256(input)`.
- For the candidate tuple in Item 1's KAT, aitp-rs `sign_pinned_key_proof` emits exactly the double-hash value. The single-hash value is byte-identical when computed by OpenSSL (pyca, deterministic) and by RustCrypto `sign_prehash`.

Ed25519 is unaffected. PureEdDSA signs the 32-byte digest as its message, and both implementations agree.

### Proposed normative text

Replace the pseudocode in RFC-0001 §5.4 with the block below, and add a new subsection §5.4.6.

```
d         = sha256(sig_input)                  ; 32 bytes
signature = base64url(SIGN_alg(sender_private_key, d))
```

> **§5.4.6 Signing primitive per algorithm (JCS profile and proofs).** Every JCS-profile signature and every proof signature hashes its signing input exactly once with SHA-256, producing the 32-byte digest `d`. This covers the envelope, Manifest, Manifest PoP, handshake PoP, TCT PoP, renewal PoP, revocation snapshot, session bundle and the pinned-key `proof`. `SIGN_alg` is then:
>
> - `ed25519`: PureEdDSA (RFC 8032 §5.1.6) with `d` as the message.
> - `p256`: ECDSA on P-256 (FIPS 186-5 §6.4) with the hash step **already performed**. `d` is used directly as the hashed message (`e = d`) and MUST NOT be hashed again.
>
> Equivalently, the `p256` signature is a standard ECDSA-P256-SHA256 (JOSE `ES256`) signature over the pre-hash input (`sig_input`, `proof_input`, the canonical artifact bytes, or the decoded nonce). A verifier MAY check it either way. Signers MUST use a prehash/digest interface (for example `PrehashSigner`, `Prehashed(SHA256)`, KMS `MessageType=DIGEST`, or `CKM_ECDSA`) and MUST NOT pass `d` to an interface that hashes its input. An implementation that hashes `d` again (`e = SHA-256(d)`) is non-conformant.

- Amend RFC-0002 §3.1 and §3.2 step 3 to cite §5.4.6. The pseudocode stays the same.
- Amend RFC-0001 §5.4.2 to cite §5.4.6.

**KAT (blocking).** Add `kat-pinned-key-proof-002-p256`, which pins the single-hash value. Every other P-256 KAT listed under KAT vectors below follows the same rule.

---

## Item 2: P-256 `pinned_key` identities (RFC-0002 §1, §3.1–§3.3; identity schema)

### Problem

**The spec text is Ed25519-only:**

- RFC-0002 §3.3 (`:221`): "The `public_key` MUST be the same **43-char** unpadded-base64url AID-identifier form." A P-256 identifier is 44 chars.
- The identity schema allows `{43,44}` for `public_key`. Its `proof` description still says "an unpadded base64url **Ed25519** signature".

**So are both implementations:**

- aitp-rs `verify_pinned_key` refuses non-Ed25519 senders (`identity_pinned.rs:124-126`) and requires a 32-byte key (`:133-137`).
- The trust-store trait cannot represent a P-256 key: `PinnedKeyStore::is_trusted(&[u8; 32])` (`state_machine.rs:30-34`).
- aitp-verifier-py hard-codes `PublicKey.from_raw("ed25519", …)` and expects a raw 64-byte proof (`identity.py:331,337`).

**The encoding is unspecified.** The spec does not say whether a P-256 proof carries the `p256.` tag. RFC-0001 §5.4.3 already lists identity `proof` among the tagged fields, but RFC-0002 never references it.

### Proposed normative text

Replace RFC-0002 §3.3's first sentence with:

> The `public_key` MUST be the unpadded-base64url AID-identifier form of RFC-AITP-0001 §5.3 for the sender AID's algorithm: 43 chars (32 raw bytes) for `ed25519`, or 44 chars (33-byte SEC1 compressed point) for `p256`. SPKI-DER, PEM, JWK and uncompressed-point forms are not permitted. A `p256` `public_key` MUST decode to a valid point on the curve. A verifier MUST reject the descriptor with `IDENTITY_FAILED` when the point is invalid or is the identity.

Add to RFC-0002 §3.1:

> `proof` uses the JCS-profile signature wire format of RFC-AITP-0001 §5.4.3, with the primitive of §5.4.6.
>
> - A `p256` sender MUST emit the tagged form `p256.<86-char-b64url>`.
> - An `ed25519` sender MAY emit either the legacy untagged form or `ed25519.<86-char-b64url>`.
> - The tag MUST match the algorithm of `sender.agent_id`, per §5.4.3 rule 3.

Replace RFC-0002 §3.2 with:

> 1. Confirm `identity.type` is `pinned_key`. A verifier MUST NOT run pinned-key verification on a descriptor of any other `type`, even if it carries `public_key` and a well-formed `proof`.
> 2. Decode `public_key` and confirm it is byte-equal to the key encoded in `sender.agent_id`, under the same algorithm. A legacy untagged AID compares as `ed25519`.
> 3. Locate `(algorithm, public_key)` in the local `pinned_keys` configuration. Trust-store entries are keyed by the pair, never by raw bytes alone.
> 4. Reconstruct `proof_input` (§3.1).
> 5. Verify `proof` per RFC-AITP-0001 §5.4.3 and §5.4.6 against that key.
>
> Steps 1–3 MUST complete before any signature verification.

- Schema: change the `proof` description to "a JCS-profile signature per RFC-AITP-0001 §5.4.3, Ed25519 or P-256".
- Schema: add `pattern: ^((ed25519|p256)\.)?[A-Za-z0-9_-]{86}$` under the `pinned_key` branch.
- Add an informative note that a Manifest `identity_hint` of kind `pinned_key` with a P-256 AID is valid.

**KAT and fixtures:**

- `kat-pinned-key-proof-002-p256` (positive).
- `id-010-pinned-key-p256-success`.
- `id-011-pinned-key-p256-untagged-proof-rejected`: an untagged proof from a P-256 sender is read as Ed25519 and rejected as an algorithm mismatch.
- `id-012-pinned-key-p256-uncompressed-key-rejected`.

---

## Item 3: Envelope `extensions` is "signed" but outside the signing input — DEFERRED to v0.3

**Status in this proposal:** withdrawn (decision 2026-10-16). This proposal makes no normative change here. The problem and the candidate fix below are kept as the starting point for a separate `aitp/0.3` proposal. Until then, implementations should not rely on envelope `extensions`, `version` or `message_type` being authenticated; Item 5 is written so that it does not depend on them.

### Problem

Three places say `extensions` is signed:

- RFC-0001 §5.2 (`:154`): "covered by the envelope signature like any other member (§5.4.1)".
- RFC-0012 §6 (`:134`): "the JCS canonical form covers the entire `extensions` field".
- The env-007 rationale: "the signature verifies over the envelope signing input INCLUDING `extensions`".

But the §5.4 envelope `sig_input` is `message_id|timestamp|sender.agent_id|hex(sha256(JCS(payload)))`. It covers neither `extensions` nor `version` nor `message_type`.

aitp-rs implements the §5.4 formula, and its test suite asserts the gap:

- `aitp-core/src/envelope.rs:199-220`.
- `aitp-envelope/tests/signing.rs:198` (`attaching_extensions_after_signing_does_not_invalidate_the_signature`).

Because env-007 is placeholder-minted, the contradiction is not testable. Today any on-path party can add, alter or strip envelope `extensions`, and can alter `version` or `message_type`, without invalidating the signature.

### Proposed normative text (preferred: sign it)

Replace the §5.4 envelope signing input with a domain-separated v2 input that covers every envelope member except `signature`:

```
sig_input_v2 = "aitp-envelope-v2\0" || JCS(envelope_without_signature)
```

- This aligns the envelope with the Manifest and session-bundle rule ("canonical JSON of the body without `signature`").
- It makes §5.2, RFC-0012 §6 and env-007 true as written.
- It binds `version` and `message_type`, which closes message-type substitution as a class.

**Alternative (smaller, weaker).** Keep the v1 input and correct §5.2, RFC-0012 §6 and env-007 to say envelope `extensions` is **unsigned**, and MUST NOT carry anything a verifier relies on. This proposal does not recommend it: RFC-0012 §6 "Replay surface" already anticipates normative extensions bound to `message_id`, which an unsigned slot cannot provide.

**Fixtures:**

- Mint env-007 for real.
- Add `env-008-extensions-tampered-rejected`: an `extensions` member is changed after signing, and the expected result is `INVALID_SIGNATURE`.
- Add `kat-envelope-001` and `kat-envelope-002-p256` (signed-examples) pinning `sig_input_v2` bytes, digest and signature.

---

## Item 4: Verification strictness (RFC-0001 §5.4.3; RFC-0009 §4)

### Problem

The spec states no rule for malleability or weak keys. The two implementations diverge:

**Ed25519:**

- aitp-rs uses dalek `verify_strict` (`aitp-crypto/src/keys.rs:363`).
- Common Ed25519 libraries differ on small-order keys, non-canonical encodings and the cofactored versus cofactorless equation, and the spec does not choose.
- A verifier that accepts a small-order public key can be shown a signature that verifies for **any message** (the identity key with `R = identity, S = 0` is the textbook case). Under a possession-only or key-resolving verifier, a signature from such an AID would commit to nothing.

**P-256:**

- aitp-rs rejects high-S signatures (`keys.rs:536`). Its comment cites "RFC-AITP-0001 §5.4.3 … RFC-AITP-0009 §4", but neither section says so.
- aitp-verifier-py and every stock JOSE `ES256` library accept high-S.
- Cloud KMS and HSM signers commonly do not normalize S, so they return high-S about half the time.
- So a conformant-looking KMS-backed signer is rejected roughly 50% of the time by aitp-rs and accepted by verifier-py.

### Proposed normative text (new §5.4.7, cross-referenced from RFC-0009 §4)

> **§5.4.7 Verification strictness.**
>
> **Ed25519.** Verifiers MUST reject:
>
> - a signature whose `S` is not canonical (`S ≥ L`);
> - a public key or `R` that is not a canonical point encoding;
> - a public key of small order (including the identity).
>
> Verifiers MUST use the cofactorless equation `[S]B = R + [k]A`. This is the "strict" verification profile (for example ed25519-dalek `verify_strict`).
>
> **P-256.** Signers MUST emit low-S signatures (`S ≤ n/2`), normalizing `S` to `n − S` when needed, including when the raw signature comes from an external signer such as a KMS or HSM. Verifiers MUST reject `S > n/2`, `R` or `S` equal to 0, and `R` or `S` ≥ `n`, using `INVALID_SIGNATURE` (or the artifact-specific signature code).
>
> **Both profiles.** These rules apply to JCS-profile and compact-JWS signatures alike. For JWS they are stricter than RFC 7518, and an off-the-shelf JOSE library MUST be wrapped accordingly.
>
> **External signers.** When the private key is held by a KMS, HSM or remote signer, the implementation that assembles the AITP artifact is the "signer" for the purposes of this section. It MUST normalize `S` and SHOULD verify the assembled signature against the AID's key before emitting it. A KMS returning a DER-encoded signature MUST be converted to the fixed 64-byte `r || s` form before tagging.

The low-S rule makes the existing aitp-rs behaviour (`keys.rs:502-509` normalize on sign, `:530-541` reject on verify) normative. aitp-verifier-py has to add the reject.

**Fixtures:**

- `sig-001-ed25519-small-order-key-rejected`.
- `sig-002-ed25519-noncanonical-s-rejected`.
- `sig-003-p256-high-s-rejected`, which is the low-S sibling of a valid KAT signature.
- `tct-0xx-es256-high-s-rejected`.

---

## Item 5: One-way pinned-key admission and the self-attestation profile (new RFC-0002 §3.4; RFC-0005 §2, §5.1, §9)

### Problem

**Pinned admission is defined only inside the four-message Mutual Handshake (RFC-0004).** Deployments that admit agents to a single verifier have no profile to claim. Examples are a gateway, a coordination host or a resource server. RFC-0001 §6 is all-or-nothing.

Inside the handshake, the descriptor's `type`, `subject` and `extensions` are authenticated by the envelope signature over the payload. In a standalone presentation nothing authenticates them: the proof covers only the five-field tuple.

**Self-issued TCTs are unaddressed.** RFC-0005 never says whether `iss == sub` is allowed (`iss == sub == aud` is the self-attestation case). RFC-0006 and RFC-0011 forbid self-delegation, but RFC-0005 says nothing.

**TTL is unbounded without a Manifest.** RFC-0005 §9 bounds `exp` only by the issuer's Manifest `expires_at` (`:393`). An issuer without a published Manifest has no ceiling.

### Proposed normative text

> **RFC-0002 §3.4 One-way pinned-key admission (OPTIONAL profile `pinned-admission`).** A verifier MAY admit a subject without a mutual handshake when all of the following hold:
>
> 1. The verifier issues a fresh 16-byte `pop_nonce` from a CSPRNG. The nonce is single-use, expires after at most 300 s, and is bound to the verifier's own AID.
> 2. The subject returns an RFC-0001 §5 envelope (`message_type` = `identity_presentation`, a new registry entry) whose payload is `{identity, pop_nonce}`. The envelope signature (RFC-0001 §5.4, which covers `sha256(JCS(payload))`) authenticates the descriptor's `type`, `subject` and `extensions`, because they are inside the payload. The verifier MUST NOT rely on envelope-level `extensions`, `version` or `message_type` (Item 3, deferred) and MUST reject an envelope whose `message_type` is not `identity_presentation`. The `proof` is computed per §3.1 with `receiver_aid` equal to the verifier's AID.
> 3. Verification is §3.2 steps 1–5 plus the RFC-0001 §5.5 timestamp and `message_id` rules. A configured `pinned_keys` store is REQUIRED. The possession-only development mode MUST NOT be used.
> 4. The verifier consumes the nonce atomically before returning success.
>
> A party implementing only this profile, as either verifier or presenter, MAY claim "AITP v0.2 pinned-admission" conformance. It MUST NOT claim RFC-0001 §6 full conformance.
>
> **Challenge and nonce rules.**
>
> - `pop_nonce` MUST decode to exactly 16 bytes. A verifier MUST reject any other length with `IDENTITY_FAILED` before signature verification.
> - A nonce is accepted only if this verifier issued it, it has not expired and it has not been consumed. Lookup and consumption MUST be one atomic step.
> - The verifier MUST bound outstanding nonces and MUST apply per-source rate limiting to nonce issuance, at the level RFC-AITP-0004 §11.4 / RFC-AITP-0009 §3.1 settle on (#69). When the bound is reached it MUST refuse new challenges rather than evict unexpired nonces of other sources.
> - `message_id` follows Item 6b. It MAY be derived deterministically from `pop_nonce`, since the nonce is already single-use.

> **RFC-0005 §5.3 Self-issued attestation TCTs.** A TCT with `iss == sub == aud` is a self-attestation: a statement by the issuer about itself. It confers no capability.
>
> - **Grant contexts.** A verifier MUST reject `iss == sub` in any context that evaluates the TCT as a capability grant (RFC-0004 §4, RFC-0006), using `AUDIENCE_MISMATCH` (the choice of code is open).
> - **Marker grant.** `grants` stays non-empty (§2). An attestation carries exactly one grant, the reserved value `aitp:attestation`. An issuer MUST NOT mint `aitp:attestation` with `iss ≠ sub`, and a verifier in a grant context MUST reject any TCT containing it.
> - **Statement.** The attested content goes in `ext`, under a namespaced key per RFC-AITP-0012. Because `ext` is inside the JWS payload it is signed. For attestations the "unknown keys in `ext` MUST be ignored" rule applies only to keys the relying party does not consume. A relying party MUST reject an attestation whose `ext` lacks the key it expects.
> - **`cnf` and `jti`.** Attestation TCTs MUST carry `cnf`. `jti` follows Item 6b and MAY be deterministic, so that re-minting the same statement yields the same token.
> - **Lifetime.** An attestation MAY be long-lived (archival evidence, for example a decision record's commitment). When the issuer publishes no Manifest the §10.4 bound does not apply. A verifier MUST then make an explicit decision to waive the Manifest cap, and MUST establish that the issuer key was trusted at `iat` from its own records (an enrollment or key-history record). It MUST NOT treat a far-future `exp` alone as evidence of validity.
> - **Revocation.** RFC-0008 `jti` revocation applies unchanged.

The 2026-10-13 text said attestations "grant nothing" while `grants` is required non-empty, and capped TTL by "the issuer key's declared validity period", which `pinned_key` identities do not declare. The marker grant and the explicit waiver resolve both. The marker grant is the v0.2 answer (decision 2026-10-16); a distinct attestation `typ` is not pursued in this proposal. Implementations need a supported `ext` setter and a deterministic-`jti` setter on their TCT builders (Item 7).

**KAT and fixtures:**

- `kat-tct-002-self-attestation` (Ed25519) and `kat-tct-003-p256-self-attestation` (ES256), each with a 100-year `exp`, a deterministic `jti` and an `ext` statement.
- `tct-0xx-self-issued-grant-rejected`.
- `tct-0xx-attestation-marker-with-distinct-iss-rejected`.
- `id-013-pinned-admission-nonce-reuse-rejected`.
- `id-014-pinned-admission-nonce-wrong-length-rejected`.
- `id-015-pinned-admission-wrong-message-type-rejected`.
- `id-016-pinned-admission-rate-limit-refuses-new-challenge` (behavioural; the bound is reached and a new challenge is refused, while outstanding nonces stay valid).

---

## Item 6: Smaller inconsistencies

### 6a. The descriptor note says `subject` is in the proof input

**Problem.** RFC-0002 §1 (`:61`) says "verifiers reconstruct the proof input from the envelope plus the descriptor's `subject`". The §3.1 `proof_input` does not include `subject`. Implementers may wrongly treat `subject` as authenticated by the proof.

**Text.** Delete "plus the descriptor's `subject`". Add: "`subject` is not covered by `proof`; it is authenticated only by the enclosing envelope signature."

### 6b. `jti` v4 is required but unenforced

**Problem.** RFC-0005 §2 (`:65`) requires "UUID v4", and the TCT schema pattern enforces `-4xxx-[89ab]xxx-`. Neither implementation checks it:

- aitp-rs deserializes `Uuid` of any version (`aitp-tct/src/types.rs:39`).
- aitp-rs lets `TctBuilder::jti` override with any version (`builder.rs:101`).
- aitp-verifier-py checks only that `jti` is a `str`.

The spec is also silent on whether a deterministic, hash-derived v4-shaped `jti` is acceptable.

**Text:**

> `jti` MUST be a lowercase hyphenated string in the RFC 9562 UUID v4 layout: version nibble `4`, variant bits `10`. A verifier MUST reject any other form before signature verification.
>
> The remaining 122 bits MUST be either:
>
> - **random**: drawn from a CSPRNG (RFC-0001 §11), or
> - **derived**: the leading bits of `SHA-256(domain_tag || input)`, where `domain_tag` is an issuer-chosen ASCII label unique to that use, and `input` is unique per token for that issuer. The issuer MUST guarantee that distinct tokens never share an `input`.
>
> A verifier cannot tell the two apart, and MUST NOT try.

Derived identifiers are needed for idempotent re-issuance and for archival attestations (Item 5). For example, a host that re-mints the commitment for the same record after a restart must produce the same `jti`. Requiring CSPRNG bits would forbid that. Requiring the v4 layout keeps the schema pattern valid, and lets generic UUID parsers that check version or variant accept the value.

- Add fixtures `tct-0xx-jti-not-v4-rejected` (a v7 UUID) and `tct-0xx-jti-v4-variant-bits-wrong-rejected`.
- Add `kat-derived-uuid-001`, which pins a `domain_tag`, `input`, SHA-256 and the resulting v4-shaped string, so that SDKs in every language produce the same bits.
- **Error codes.** A non-v4 identifier is a structural defect, so it uses the per-artifact structural-rejection code from `registries/error-codes.md` (the normative table at `:32-42`): `TCT_SIGNATURE_INVALID` for a TCT `jti`, `DELEGATION_INVALID_VOUCHER` for a voucher `src_jti`, `INVALID_ENVELOPE` for an envelope `message_id`. No new code. Rationale: that table already decides that the compact-JWS artifacts collapse structural failure onto their signature-family code, so that an unauthenticated token leaks no parse detail. A dedicated `jti` code would contradict it for one claim.
- Treat `message_id` the same way (RFC-0001 §5.2). The RFC-0001 §11 (`:628`) sentence "MUST use a cryptographically secure RNG for `message_id`" becomes "for nonces, and for `message_id` unless derived per RFC-0005 §2".
- Grant-voucher `src_jti` (RFC-0005 §8.1) inherits the rule because it equals a TCT `jti`.

### 6c. `type` dispatch

Covered by the Item 2 rewrite of §3.2 step 1. This adds an explicit fixture, `id-011b-oidc-typed-descriptor-with-pinned-proof-rejected`: a descriptor of type `oidc` that carries `public_key` and a valid pinned proof MUST be rejected with `IDENTITY_FAILED`. That is already a MUST in RFC-0002 §1, but no fixture reaches it through the pinned path.

---

## Item 7: Implementation API notes (informative)

This item is not normative text. It records the library API changes that Items 1–6 imply, as checked against aitp-rs `b19d3f2` (0.13.2). An implementation can then absorb them in one breaking release instead of shipping several. aitp-rs tracks them in aitp-rs#205.

**7a. Signer abstraction (Items 1, 4).** Today `AitpSigningKey` is a sealed enum over in-process keys (`aitp-crypto/src/keys.rs:63-85`), and the raw-sign path is `pub(crate)` (`:197-213`). A KMS- or HSM-held key cannot sign any AITP artifact. Implementations should expose:

- a signer trait, in sync and async forms (it ships in aitp-rs 0.14.0 regardless of any one deployment's custody plans, because P-256 and future KMS/HSM keys need it), whose request type separates the two primitives: an Ed25519 message (the 32-byte `d`, or the JWS signing input) versus a P-256 32-byte digest. A P-256 backend then cannot be handed a pre-hash input by mistake.
- a public raw-sign entry point for non-AITP framings that a deployment signs with the same key: operator JWS, application tickets, receipts. It uses the same primitive, low-S normalization and verify-before-emit guard.
- library-side low-S normalization and DER-to-`r||s` conversion of whatever the backend returns, plus a verify-before-emit check (Item 4, "External signers").
- **Cloud-KMS fit.** These requirements were checked against AWS KMS, the first deployment backend (Seam, 2026-10-16):
  - **Errors.** The async form is fallible with a typed error that separates transient failures (throttling, timeout, unavailable key) from permanent ones (wrong key spec, disabled key). Callers can then retry the transient ones without guessing.
  - **Ed25519 must be pure EdDSA.** The backend MUST use pure EdDSA over the exact message bytes (AWS `ED25519_SHA_512` with `MessageType=RAW`). It MUST NOT use HashEdDSA (`ED25519_PH_SHA_512`): AWS prehashes again even with `DIGEST`, and its output does not verify as Ed25519.
  - **Message-size limit.** The AWS RAW limit is 4096 bytes. The JCS paths already sign the 32-byte `d`, but a JWS signing input can exceed 4096 bytes. The trait therefore exposes a backend's maximum message size, and the library returns a typed error before calling the backend, never a truncated input.
  - **P-256 signs the digest.** A P-256 backend receives `d` and signs it as a digest (AWS `ECDSA_SHA_256` with `MessageType=DIGEST`), per Item 1.
  - **Key identity at startup.** A backend reports its public key (AWS `GetPublicKey`). The library checks it against the configured key once, at startup, so a mis-pointed key id fails before the first artifact is signed.
  - **ECDSA is randomized.** Ed25519 output is deterministic, but P-256 output from a KMS is not. A deployment that needs byte-identical re-signing on retry (Seam's TCT seal) must keep that key on Ed25519.
  - **The backend stays deployment-side.** aitp-rs ships the trait and the in-process implementations. A concrete AWS KMS backend lives in the deployment, so the library takes no cloud-SDK dependency.

**7b. `pinned_key` verification (Item 2).** `verify_pinned_key` (`aitp-handshake/src/identity_pinned.rs:115-161`) should:

- dispatch on `type` (§3.2 step 1);
- take a required trust store keyed by `(algorithm, key bytes)`, consulted before the proof check (§3.2 step 3);
- return the verified algorithm and key, so callers never re-derive the subject from untrusted descriptor fields.

The store trait is `[u8; 32]`-keyed today (`state_machine.rs:30-52`), and a store is optional with a possession-only default (`:69-74`). Both change. There is no possession-only opt-out (resolved 2026-10-16).

**7c. TCT builder and verifier (Items 5, 6b).**

- The builder needs a supported `ext` setter. `ext` is hard-coded to `None` today (`aitp-tct/src/builder.rs:148,163`).
- It needs a supported `jti` setter that validates the v4 layout. Today `.jti()` is documented "Tests/fixtures only" (`:100-104`) and accepts any version.
- The `jti: Uuid` deserializer (`types.rs:39`) should enforce the v4 layout.
- The permissive verify-context constructors (`TctVerifyContext::now` and `permissive_at`, `verifier.rs`) should be deprecated in favour of the strict builder. The Item 5 Manifest-cap waiver should be an explicit, named builder call.

**7d. Reference `pinned-admission` nonce store (Item 5).** Implementations should ship a reference verifier for the one-way profile: nonce issuance bound to the verifier AID, atomic consume, a bounded store that refuses new challenges, and per-source rate-limit hooks. Deployments then do not each re-implement the replay-critical part. aitp-rs ships one in 0.14.0 (decision 2026-10-16).

**7e. Strict verification everywhere.** Any public verify helper (Ed25519 or P-256, raw or JCS) should apply §5.4.7. aitp-rs already does this for `verify` and `verify_raw`. Deployments that call a crypto library directly for non-AITP framings should route through these helpers instead.

---

## Promotion and sequencing

Per RFC-PROCESS this proposal is at Idea. "Any normative change to `rfcs/`" requires an RFC, but these items amend existing RFCs, so the path is a patch or minor `Version:` bump on each amended RFC (VERSIONING.md), not a new number.

1. **Split into reviewable PRs**, each carrying its own KATs and fixtures (the KAT requirement is blocking because every item touches a signing surface):
   - **A.** Items 1 and 4 (§5.4.6, §5.4.7), with `kat-p256-jcs-sign-001`, `kat-pinned-key-proof-002-p256`, the signed-examples and the `sig-*` fixtures.
   - **B.** Items 2 and 6c (RFC-0002 §3, the identity schema), with `id-010..012` and `id-011b`.
   - **C.** Item 6b and the 6a note (RFC-0005 §2, RFC-0001 §5.2/§11), with the `jti` fixtures and `kat-derived-uuid-001`.
   - **D.** Item 5 (RFC-0002 §3.4, RFC-0005 §5.3, a `message_type` registry entry), with `kat-tct-002/003` and `id-013..016`. Depends on C, and on #69 for the rate-limit level.
   - Item 3 (envelope v2) is not part of this proposal; it moves to a separate `aitp/0.3` proposal.
2. **Ordering against implementations.** A–D merge, or at least reach a frozen KAT set, before aitp-rs cuts the 0.14.0 release that implements them. aitp-rs vendors the frozen fixtures in its Phase 0.
3. **Independent recomputation.** Each P-256 KAT is recomputed by aitp-verifier-py, which needs the low-S reject from Item 4, before the PR leaves Draft. aitp-rs's cross-implementation check job then runs the new vectors in both directions.

---

## KAT vectors to add

All P-256 vectors use `kat-keypair-005-p256`, RFC 6979 deterministic `k` and low-S, so they are byte-reproducible. Per RFC-PROCESS, each pins the preimage hex, the SHA-256 hex and the signature, and is independently recomputed.

| ID | File | Pins |
|---|---|---|
| `kat-p256-jcs-sign-001` | `jcs-sha256.json` | Generic §5.4.6: preimage → `d` → `p256.` signature, plus a `double_hash_signature_MUST_NOT_verify` negative |
| `kat-pinned-key-proof-002-p256` | `jcs-sha256.json` | §3.1 proof from a P-256 sender (candidate below) |
| `kat-pinned-key-proof-003-tagged-ed25519` | `jcs-sha256.json` | Same as `-001`, but the sender uses the tagged `aid:pubkey:ed25519:` AID. Pins that the AID string bytes, not the key, enter `proof_input` |
| `kat-keypair-001-tagged` | `keypairs.json` | Tagged Ed25519 AID form for `kat-keypair-001` (today all five Ed25519 KAT AIDs are untagged) |
| `kat-manifest-pop-002-p256` | `jcs-sha256.json` | §5.4.2 PoP with P-256 |
| `kat-envelope-002-p256` | `signed-examples/envelope/` | Replaces env-005 placeholder minting with committed bytes |
| `kat-keypair-005-manifest` | `signed-examples/manifest/` | P-256 Manifest signature and PoP |
| `kat-keypair-005-issues-002` | `signed-examples/tct/` | ES256 TCT (JWS profile, single hash by JOSE definition) |
| `kat-keypair-005-snapshot` | `signed-examples/revocation/` | P-256 revocation snapshot |

**Candidate value for `kat-pinned-key-proof-002-p256`.** Computed independently with OpenSSL via pyca/cryptography 50.0.1 (deterministic) and with RustCrypto `p256` 0.14 `sign_prehash`. The two results are byte-identical.

```json
{
  "id": "kat-pinned-key-proof-002-p256",
  "sender_aid": "aid:pubkey:p256:AweBDql0zqV3PmO4l_N-O-mgnnpf6blxpE0QZawqOpMR",
  "receiver_aid": "aid:pubkey:O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik",
  "message_id": "770e8400-e29b-41d4-a716-446655440702",
  "timestamp": 1711900000,
  "pop_nonce": "AAAAAAAAAAAAAAAAAAAAAA",
  "proof_input_hex": "616974702d70696e6e65642d6b65792d7631006169643a7075626b65793a703235363a4177654244716c307a715633506d4f346c5f4e2d4f2d6d676e6e706636626c78704530515a6177714f704d52006169643a7075626b65793a4f326f6e764d3632704331696f366a514b6d384e6332557946586364346b4f6d4f7342496f59745a32696b0037373065383430302d653239622d343164342d613731362d34343636353534343037303200313731313930303030300000000000000000000000000000000000",
  "proof_input_len_bytes": 199,
  "sha256_hex": "ab9942f8b527a342e7860197a42b0e787ae8c5a40c81a2beb4e1cf6e0fe9dd3f",
  "signing_keypair_id": "kat-keypair-005-p256",
  "proof": "p256.X9FVRk-1kawJ_rKSXlW3ySlC2A0WfSCArxzswSPWtSRQol3VSaNYx9u-Q3kdL0SKbd51HSYlJZ_IzjU0E-wr1Q",
  "double_hash_proof_MUST_NOT_verify": "p256.xDGuosZC63lLwIMmOad0wD8kaK163ugpr3O2ZEP4W3NgWXFqNe_Fq_Ig74Wl6ubMVQp_mMr0ym9CB7i3rqeBgw"
}
```

The `double_hash_…` value is exactly what aitp-rs 0.13.2 `sign_pinned_key_proof` emits today for this tuple.

---

## Compatibility and migration

**Ed25519.** No wire change from Items 1, 2, 4 and 6. Strict verification (Item 4) rejects only signatures that RFC 8032-conformant signers never produce.

**P-256 JCS signatures (Item 1).** This is a wire change for aitp-rs-produced P-256 Manifests, envelopes, PoPs, snapshots and bundles. It is acceptable now:

- No P-256 JCS signature is pinned anywhere in the conformance pack.
- The two existing implementations already disagree, so no interoperable P-256 JCS deployment can exist.
- There is no dual-accept window. Accepting both hash conventions would keep the ambiguity alive and double the verification surface.
- Implementations ship the fix together with the KATs.

**P-256 `pinned_key` (Item 2).** Purely additive on the wire, since P-256 was previously rejected. Trust-store APIs keyed by 32-byte arrays must change, which is a breaking API change in aitp-rs.

**Envelope v2 signing input (Item 3).** Deferred to `aitp/0.3`; no change in this proposal.

**One-way profile (Item 5).** Additive. A new `message_type` registry entry is needed. The `iss == sub` rejection in grant contexts has no effect on any conformant v0.2 flow, because handshake-issued TCTs always have `iss ≠ sub`. Existing self-issued TCTs that carry their statement in `grants` instead of `ext`, or that lack the marker grant, have to be re-minted under §5.3. Long-lived ones remain verifiable under their original rules for as long as the relying party keeps that code path.

Known deployment impact: the coordination host that motivated the revision (Seam) currently accepts a bare, envelope-less pinned presentation. It and its client SDKs move to the `identity_presentation` envelope, and its self-issued commitment TCT moves its binding from `grants` to `ext` with the marker grant. Both are accepted by that deployment's owner.

**`jti` and `message_id` v4 layout (Item 6b).** This rejects tokens the schema already forbids. Issuers that derive identifiers deterministically keep doing so, but must set the version and variant bits. That changes the identifier bytes, so derived identifiers that are pinned in archives or digests change once. Clients in other languages that derive `message_id` must ship the same bit-setting before verifiers enforce it.

## Alternatives considered

- **Double hash as the rule, matching aitp-rs.** Rejected:
  - It makes AITP P-256 JCS signatures unverifiable by stock ES256 or WebCrypto verifiers over the natural input.
  - It contradicts the env-005 rationale and the independent implementation.
  - It gives KMS integrations no benefit.
- **Raw-hash ECDSA without a single-hash framing.** This is the same bytes as the proposed rule. The "equivalently ES256 over the input" sentence is kept because it is the most testable statement.
- **An untagged 64-byte P-256 `proof`.** Rejected: it conflicts with RFC-0001 §5.4.3's untagged-means-Ed25519 rule and reopens algorithm confusion.

## Open questions

None remain.

**Resolved (2026-10-16):**

- Possession-only development mode (RFC-0002 §3.2): removed. Every `pinned_key` verification consults a trust store. Tests use an in-memory store, not a bypass. Item 7b's "loudly named opt-out" is withdrawn.
- Derived `jti` domain tag: registered. A new `registries/jti-domain-tags.md` lists each tag with its owner and derivation, so two deployments cannot collide on a tag. Seam registers its TCT seal tag.

- Envelope v2 (Item 3): out of this proposal; carried to a v0.3 proposal.
- Non-v4 `jti` error code: the existing structural-rejection codes (Item 6b).
- Attestations: marker grant `aitp:attestation` in v0.2; no distinct `typ` here.
- Bare presentation variant: dropped; one-way admission uses the `identity_presentation` envelope.
- Reference nonce store: implementations ship one (Item 7d).
