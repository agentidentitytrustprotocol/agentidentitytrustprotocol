# Proposal: sign the whole envelope (`aitp/0.3`)

**Stage:** Idea. This is an unnumbered proposal under [RFC-PROCESS.md](../../governance/RFC-PROCESS.md). It amends existing RFCs and does not ask for a new RFC number.
**Amends:** [RFC-AITP-0001](../RFC-AITP-0001-core.md) §5.2, §5.4, §5.4.1, §7; [RFC-AITP-0012](../RFC-AITP-0012-extensions.md) §6; `schemas/json/` (namespace `v0.3`); `schemas/conformance/` and `known-answer/`; [VERSIONING.md](../../VERSIONING.md).
**Spec baseline:** `ab214d2` (after the v0.2 erratum, #88).
**Tracking issue:** #87. **Origin:** Item 3 of proposal #72. It was withdrawn from #72 on 2026-10-16 and deferred to this proposal.
**Owner decisions (2026-10-18):** envelope fix only; strict cutover; the v0.2 erratum ships first (done in #88).

---

## Summary

The `aitp/0.2` envelope signature covers `message_id`, `timestamp`, `sender.agent_id` and the canonical `payload`. It does not cover `version`, `message_type` or `extensions` (RFC-AITP-0001 §5.4, as corrected by #88). This proposal replaces the envelope signing input with a domain-separated JCS form of the whole envelope minus `signature`. The new input is a wire break, so it ships as protocol revision `aitp/0.3`. No other signing input changes.

## Problem

- **What isn't covered.** An on-path party can add, change or strip envelope `extensions`, and can change `version` or `message_type`, without invalidating the signature. aitp-rs asserts this behaviour in `crates/aitp-core/src/envelope.rs:441` (`attaching_extensions_after_signing_does_not_invalidate_the_signature`).
- **What v0.2 does about it.** v0.2 tells receivers not to rely on those members (#88). That makes the hole known, but it doesn't close it.
- **Why that blocks future work.** RFC-AITP-0012 §6 "Replay surface" expects normative extensions bound to the envelope `message_id`. That needs an authenticated `extensions` slot.
- **`message_type` substitution.** The payload is signed, but the type that tells a receiver how to interpret it is not. Strict member checks (`UNKNOWN_FIELD`) make cross-type confusion hard, but they don't rule it out as a class.
- **Inconsistent with the other artifacts.** Every other JCS-profile artifact (Manifest, session bundle, revocation snapshot, handshake payloads) signs its whole body. The envelope is the only exception.

## Design

### 1. Envelope signing input v2 (RFC-AITP-0001 §5.4)

Replace the §5.4 envelope construction with:

```
sig_input_v2 = "aitp-envelope-v2" || 0x00 || JCS(envelope_without_signature)
d            = sha256(sig_input_v2)            ; 32 bytes
signature    = base64url(SIGN_alg(sender_private_key, d))
```

- **`envelope_without_signature`.** This is the received envelope object with the `signature` member removed and every other member kept, including `extensions` when present. JCS is RFC 8785, and its output is UTF-8 bytes. The domain tag is the 16 ASCII bytes `aitp-envelope-v2` followed by one `0x00` byte.
- **`SIGN_alg`, hashing and verification.** These stay as defined today: `SIGN_alg` per §5.4.6, `d` hashed exactly once, and verification strictness per §5.4.7. The algorithm-tagged wire format (§5.4.3) is unchanged.
- **Verifiers re-canonicalize the received object.** The JCS-profile rules of §5.4.1 apply, including the transport-wrapper stripping rule.
- **Why a domain tag.** It keeps an envelope signature from ever being accepted as another JCS-profile signature over a structurally similar object, and the reverse. The other artifacts sign bare JCS. The tag costs 17 bytes and makes the envelope's signing input unambiguous without changing any other artifact.

### 2. Text that becomes true again

Each of these changes back to "covered by the envelope signature":

- RFC-AITP-0001 §5.2 (`extensions` row);
- the §5.4 profile table;
- §5.4.1;
- RFC-AITP-0012 §6;
- `docs/GLOSSARY.md`;
- the env-007 description.

The #88 MUST NOT ("receivers MUST NOT treat `version`, `message_type` or `extensions` as sender-authenticated") is removed.

### 3. Protocol revision `aitp/0.3`

The signing input is a breaking change (VERSIONING.md, "Breaking change"). The revision literal is global, so:

- `version` on every JCS-profile object, and `ver` on every JWS artifact, becomes `aitp/0.3`.
- Schema `$id`s move to `https://aitp.dev/schema/v0.3/...` and `const` values change. A `schema-v0.2.x` tag freezes the old namespace.
- RFC document versions move to `0.3.0-draft` (pre-1.0 position mapping).
- **Strict cutover (owner decision).** An `aitp/0.3` implementation rejects any `aitp/0.2` artifact with `UNKNOWN_VERSION` (RFC-AITP-0001 §7). There is no dual-accept window. The reasoning: there are two implementations, no deployed third party, and accepting v0.2 envelopes would keep the forgeable form valid.

### 4. Conformance

- **env-007.** Mint it for real under v2. It currently uses a placeholder signature.
- **New `env-008-extensions-tampered-rejected`.** Sign, then change one `extensions` key. The expected result is `INVALID_SIGNATURE`.
- **New `env-009-message-type-substituted-rejected`.** Sign, then change `message_type` to another valid type whose payload schema also accepts the payload. The expected result is `INVALID_SIGNATURE`.
- **New `env-010-version-altered-rejected`.** Change `version` after signing. The expected result is `UNKNOWN_VERSION` if the new value is unknown, and `INVALID_SIGNATURE` if it is known. The fixture uses the unknown case, and the RFC states the check order: version before signature.
- **New KATs.** Add `kat-envelope-001` (Ed25519, `kat-keypair-001`) and `kat-envelope-002-p256` to `known-answer/`. Each pins the preimage hex, `d` and the signature. They are recomputed by two independent stacks (`scripts/verify-known-answer.mjs` and `scripts/recompute-known-answer-independent.py`), per the KAT requirement in RFC-PROCESS.md.
- **Re-mint existing vectors.** Every fixture and KAT whose signed bytes contain the revision literal is re-minted for `aitp/0.3`. That covers Manifests, revocation snapshots, session bundles, handshake payloads, and the TCT, grant-voucher and delegation `ver` claims. Placeholder-minted fixtures change only their literal.

## Cost

These figures are measured at the baseline:

- 8 canonical schemas carry `"const": "aitp/0.2"`;
- 108 conformance fixtures and 3 values in `known-answer/jcs-sha256.json` contain `aitp/0.2`;
- 13 RFC files mention it.

The envelope change itself is small. Most of the work is the mechanical revision bump: the literal swap, plus re-minting every signed vector with two-stack verification. aitp-rs and aitp-verifier-py each need:

- a v2 envelope signer and verifier;
- a revision constant;
- the re-vendored fixtures.

## Alternatives considered

1. **Declare envelope `extensions` unsigned permanently (stay on `aitp/0.2`).** This is what #88 already states for v0.2. It rules out the bound extensions that RFC-AITP-0012 §6 anticipates, and it leaves `version` and `message_type` unauthenticated. Rejected as the long-term answer.
2. **Append `hex(sha256(JCS(extensions)))` to the v1 pipe string.** This is a smaller diff, but it is still a wire break, so it still needs `aitp/0.3`. It still leaves `version` and `message_type` out, and it keeps a one-off construction that no other artifact uses. Rejected.
3. **Change only the envelope signing input inside `aitp/0.2`, selected by a new `alg` tag or a flag.** This breaks VERSIONING.md's rule that a breaking change is a revision bump. It also creates a downgrade path, because a receiver must still accept the v1 form. Rejected.
4. **Bundle the reserved identity types (`did`, `x509`, `wallet`, RFC-AITP-0002 §5) into `aitp/0.3`.** Declined by the owner on 2026-10-18. They wait for a concrete implementer need.

## Backward compatibility

`aitp/0.3` and `aitp/0.2` do not interoperate. Each rejects the other's artifacts with `UNKNOWN_VERSION`. A deployment upgrades both peers together. Nothing persisted is migrated: TCTs and Manifests are short-lived or re-issued, and the frozen `aitp/0.2` schemas stay available at their tag.

## Promotion and sequencing

When this proposal is accepted, it lands as two spec PRs:

1. **PR 1: the envelope change.** RFC-AITP-0001 §5.2, §5.4, §5.4.1 and §7, and RFC-AITP-0012 §6. It adds the env-008, env-009 and env-010 fixtures and the two envelope KATs, and mints env-007. The revision literal stays at `aitp/0.2` within PR 1. CI keeps running, but PR 1 alone is not a coherent release.
2. **PR 2: the revision bump to `aitp/0.3`.** It updates the literals, the schema namespace and the RFC versions, re-mints every affected vector, and makes the VERSIONING.md and CHANGELOG migration notes. Both PRs ship in one tagged release. Implementations vendor only after PR 2.

## Open questions

1. **Check order for `version`.** This proposal fixes the order as version check, then member-set check (`UNKNOWN_FIELD`), then signature. That is today's order for unknown versions, written down explicitly. Confirm during review.
2. **Release timing.** Should `aitp/0.3` wait for any other breaking item that is currently known? There are none at the baseline, so the recommendation is to ship as soon as both implementations pass.
