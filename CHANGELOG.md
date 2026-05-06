# Changelog

## Unreleased

RFC improvement pass driven by `plans/aitp-rfc-improvement-plan.md`,
followed by a deep audit pass that fixed cross-RFC contradictions, schema
drift, and stale-Reserved wording across docs. Tightens ambiguous PoP
language in three places, adds the missing rate-limit / emergency-rotation
/ session-revocation normative surfaces, promotes RFCs 0010 and 0011 from
Reserved to Draft (post-v0.1), adds a KAT vector and fixture for the
unified PoP signing-input convention, and lands the audit follow-ups
below.

### Audit follow-ups (correctness fixes)

- **RFC-AITP-0011 multi-hop chain model.** Replaced the ambiguous chain
  example with an explicit `DelegationStep` schema and a 3-hop worked
  example (A→B→C→D). Hop 0 of the chain is a peer-issued TCT projection
  (RFC-0006 §3.1 GrantProof shape); hops i>0 are intermediate-signed
  step bodies. RFC-0006 §9 gained the carve-out so multi-hop tokens
  with a non-empty `chain` are not auto-rejected by v0.2 implementations
  that opt in.
- **Schema `extensions` slot.** TCT, delegation, revocation-list,
  envelope, identity, and all four mutual-handshake payload schemas
  gained an `extensions` property so v0.2 extension data isn't rejected
  by v0.1 verifiers (RFC-0001 §7).
- **Envelope `message_type` enum sync.** RFC-0001 §5 prose and §5 field
  table now list `pop_challenge` and `pop_response` (already in the
  envelope schema). New §5.7 entries `POP_CHALLENGE_INVALID` and
  `POP_RESPONSE_INVALID`.
- **Cross-reference fix.** RFC-0004 §3 PoP-signing-input note now cites
  RFC-0005 §6.1 (was §6.2).
- **Error-code registry.** Added `DELEGATION_HOP_LIMIT_EXCEEDED`,
  `DELEGATION_CHAIN_HASH_MISMATCH`, `SESSION_BUNDLE_INVALID`,
  `SESSION_BUNDLE_NOT_MEMBER`, `SESSION_BUNDLE_EXPIRED` (post-v0.1).
- **discovery.md verification list.** Rewrote to match RFC-0003 §5
  step order; replaced the stale `manifest.identity` field name with
  `identity_hint`; removed the (incorrect) identity-proof verification
  step.
- **integration-guide.md downstream PoP signing input.** `sha256(nonce)`
  → `sha256(base64url_decode(nonce))` with cross-link to RFC-0001
  §5.4.2; the verify-endpoint example is now explicitly non-normative.
- **Stale "Reserved" wording sweep.** docs/architecture.md,
  docs/threat-model.md, docs/non-goals.md, docs/GLOSSARY.md, and
  docs/implementer-quickstart.md no longer describe RFCs 0010 and 0011
  as "Reserved" — they are Draft (post-v0.1).
- **Conformance README fixture index.** Added the rc.3 fixtures that
  were already on disk: `man-003`, `mh-009`, `env-004`, `id-005`/`006`/
  `007`, `rev-001`/`002`. Documented the `tct_token`+`sequence`
  context-fields shape (used by `tct-006`).
- **`mh-001` per-step `operation`.** Added explicit `operation:
  "process_handshake_message"` to each sequence step so the placeholder
  convention is satisfied.
- **KAT placeholder length.** `kat-manifest-001`'s
  `proof_of_possession.signature` was 88 chars; pattern is 86. Trimmed
  and recomputed `jcs_canonical_hex`, length, and SHA-256 (vector now
  re-validates byte-for-byte). Same fix in
  `aitp-revocation-list.schema.json` example.
- **Schema vs RFC `accepted_identity_types`.** Dropped
  `minItems: 1` from `aitp-manifest.schema.json` so the explicit `[]`
  case described normatively in RFC-0003 §3.2 is schema-valid.
- **RFC-0008 §4.1.** Issuer JTI history persistence downgraded to
  SHOULD with explicit cross-reference to §1.3 and explanation of the
  issuer-side untestable nature.
- **RFC-PROCESS Draft-stage carve-out.** Added explicit Draft-stage
  carve-out so RFC-0010 and RFC-0011 can publish without KAT vectors
  and gain them as RC-promotion blockers; both RFCs now flag the
  deferral.
- **RFC-0001 §10 conformance step.** Conformance checklist now
  explicitly requires the `kat-manifest-pop-001` cross-check across
  every PoP code path.
- **RFC-0007 §1 ambiguity.** The cache/inline/well-known list is now
  explicitly described as sources, not strict priority — the
  `published_at` override rule below is authoritative.
- **RFC-0009 §3.3 → §3.1.** The rate-limiting subsection was the only
  one in §3; renumbered to §3.1 and updated the inline cross-reference.
- **README repo structure.** docs/ listing now includes
  `implementer-quickstart.md` and `operational-guidance.md`.
- **Makefile `make docs`.** Now also lists the conformance README and
  PLACEHOLDERS.md.

### Spec bug fixes

- **RFC-AITP-0003 §3 / §5 (Manifest PoP).** Field-table description now
  reads `sha256(base64url_decode(challenge))` explicitly. §5 step 3 gains a
  normative note pointing at the unified PoP signing-input convention and
  the new KAT vector.
- **RFC-AITP-0007 §2.3 (Resolution decision logic).** OIDC vs `aitp-keys`
  selection is now a branch on whether the issuer exposes
  `/.well-known/openid-configuration`, not a flat priority list.
- **RFC-AITP-0003 §3.2 (`accepted_identity_types` default).** Distinguishes
  *absent* (defaults to `["oidc"]`) from *empty array* (rejects every peer)
  and recommends omitting the field when the default is desired.

### New normative surface

- **RFC-AITP-0001 §5.4.2.** New "PoP signing input convention" subsection
  unifies `sha256(base64url_decode(x))` across Manifest PoP, handshake PoP,
  downstream TCT PoP, and the pinned-key identity proof input. All four
  call-sites cross-reference it.
- **RFC-AITP-0009 §3.1 (Rate limiting, RECOMMENDED).** Per-IP / per-AID
  defaults, payload-size cap, and the protocol-vs-rate-limit ordering
  rule.
- **RFC-AITP-0009 §1.11 (Manifest PoP bypass).** New threat entry tied
  to the unified signing-input rule and the new KAT vector.
- **RFC-AITP-0003 §8.1 (Emergency rotation).** Normative steps for key
  compromise: rekey + revoke all issued JTIs + out-of-band peer
  notification + short-TTL Manifest to accelerate cache expiry.
- **RFC-AITP-0008 §4.1 (Session invalidation model).** Per-subject JTI
  enumeration is the v0.1 mechanism; bulk-revoke API is reserved for a
  future RFC. Issuer JTI-history persistence requirement.
- **RFC-AITP-0005 §6.2 (Downstream PoP conformance note).** PoP exchange
  capability is mandatory; *enforcement* for non-marked grants stays
  deployment-configurable. Implementations must document the default and
  expose a config surface.

### Drafts promoted from Reserved

- **RFC-AITP-0010 Session Trust Bundle** is now Draft. Schema, trust
  model (coordinator-attested membership), per-pair revocation, expiry
  bound to `min(participant.tct.expires_at)`, granular error code
  surface (BUNDLE_INVALID_SIGNATURE, BUNDLE_VERSION_MISMATCH,
  BUNDLE_EXPIRED, BUNDLE_EXPIRY_WINDOW_INVARIANT,
  BUNDLE_COORDINATOR_ISSUER_MISMATCH, BUNDLE_AUDIENCE_MISMATCH,
  BUNDLE_EMPTY_PARTICIPANTS, BUNDLE_PARTICIPANT_TCT_INVALID,
  BUNDLE_NOT_MEMBER), conformance ops (`issue_session_bundle` /
  `verify_session_bundle`). Pinned KAT vector
  `kat-session-bundle-001` and three conformance fixtures
  (`bundle-001-success`, `bundle-002-not-member`, `bundle-003-expired`)
  with real Ed25519 signatures.
- **RFC-AITP-0011 Multi-hop Delegation** is now Draft. Explicit
  `DelegationStep` schema (with hop-0-vs-hop-i>0 dispatch), `chain`
  array, `chain_hash` truncation defense, `max_delegation_hops = 3`
  default, transitive `scope ⊆ ... ⊆ chain[0].capabilities`, per-hop
  revocation lookup. v0.1 implementations still reject multi-hop tokens.
  Pinned KAT vectors `kat-multihop-chain-001` (3-hop chain
  reconstruction) and `kat-multihop-truncation-001` (chain_hash
  reference) plus four conformance fixtures (`del-mh-001-success`,
  `del-mh-002-scope-inflation`, `del-mh-003-chain-hash-mismatch`,
  `del-mh-004-revoked-hop`) with real Ed25519 signatures.
- **`kat-keypair-004`** added to `keypairs.json` (seed 0x01×32, AID
  `iojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w`) to support the 4-entity
  multi-hop fixtures.

### Conformance fixtures and KAT vectors

- New KAT vector `kat-manifest-pop-001` in
  `schemas/conformance/known-answer/jcs-sha256.json` pinning
  (challenge → decoded bytes → SHA-256 → Ed25519 signature with
  `kat-keypair-001`). Implementations cross-check this against every PoP
  code path.
- New conformance fixture
  `schemas/conformance/tct-006-pop-challenge-response.json` exercises a
  happy-path downstream PoP exchange end-to-end.
- New placeholders registered in `schemas/conformance/PLACEHOLDERS.md`:
  `__VALID_DOWNSTREAM_POP_SIG__`, `__NOW_PLUS_3600__`, plus the
  `tct-*` multi-step `sequence` operations
  (`issue_pop_challenge` / `produce_pop_response` / `verify_pop_response`).

### Documentation and process

- `docs/implementer-quickstart.md` gains a "decode-before-hash" gotcha
  box pointing at the unified §5.4.2 rule and the new KAT vector.
- `docs/threat-model.md` lists the Manifest PoP bypass row.
- `governance/RFC-PROCESS.md` adds a "KAT requirement" acceptance
  criterion: any RFC introducing a new signing input, hash construction,
  or canonicalization MUST ship a pinned KAT vector.
- README, `rfcs/README.md`, and `Makefile docs` reflect the new
  Draft-but-post-v0.1 status of RFCs 0010 and 0011 (was Reserved).

---

## v0.1.0-rc.3

Conformance suite expansion and tooling hardening. No protocol architecture
changes. Spec bumped to `rc.3` across all RFC headers, README, VERSIONING,
and the Makefile release default.

### Conformance fixtures

- Added 9 negative-case conformance fixtures covering replay
  (`env-004-replay-message-id-rejected`), pinned-key proof scenarios
  (`id-005`/`id-006`/`id-007`), manifest cache expiry
  (`man-003-cache-expired-rejected`), identity-type mismatch
  (`mh-009-identity-type-mismatch-rejected`), revocation freshness
  (`rev-001-stale-snapshot-fail-closed`, `rev-002-soft-fail-safe-subset`),
  and TCT lifetime overrun (`tct-005-expires-after-manifest-rejected`).
- Re-signed `kat-keypair-001-manifest.json` against the latest pinned-key
  proof binding (cross-checked against `aitp-rs` minting output).

### Tooling

- **Format constraints now enforced.** `scripts/validate-json-schema.sh` and
  `scripts/validate-json.sh` load `ajv-formats` (`-c ajv-formats`); `format:
  uri` and `format: uuid` constraints in the schemas are no longer silently
  ignored.
- **Known-answer vectors now validated in CI.** `validate-json.sh` recurses
  into `schemas/conformance/known-answer/` and `schemas/conformance/known-
  answer/signed-examples/`. Signed-example artifacts are validated against
  their canonical schemas after stripping the top-level `_kat_input`
  companion. Total artifacts now validated: 44 (was 28 in the rc.1 entry).

### Documentation

- README §Reading order now lists `docs/implementer-quickstart.md` and
  `docs/operational-guidance.md`. Both files exist on disk; the rc.1 README
  silently omitted them.
- `Makefile` `docs` target reorganised into "Normative" and "Reserved"
  reading sections so reserved RFC-0010/0011/0012 are no longer presented
  as items 16-18 of a single linear sequence.

### CI

- Release dry-run added: CI now runs `make release` and lists the produced
  archive contents so accidental inclusion of `plans/`, `.claude/`,
  `CLAUDE.md`, or `.DS_Store` is caught at PR time.

---

## v0.1.0 (final simplification pass)

Editorial pass for v0.1.0. No protocol architecture changes — TCT
audience model, delegation scope, per-grant PoP policy, and the 12-RFC
layout are unchanged. The pass eliminates internal contradictions,
strengthens one underspecified security check, and removes redundant
documentation surface.

### Correctness fixes

- **Pinned-key proof binding.** RFC-AITP-0002 §3.1 now requires the
  pinned-key proof input to bind sender AID, receiver AID, `message_id`,
  `timestamp`, and the handshake `pop_nonce` (with a domain-separator
  prefix and null separators). The earlier `message_id|timestamp` form
  did not bind sender or receiver and admitted cross-peer replay.
  Implementations MUST NOT accept the legacy two-field input.
- **Unknown-fields rule unified.** README and VERSIONING now defer to
  RFC-AITP-0001 §7: unknown fields outside `extensions` MUST be
  rejected; unknown keys *inside* `extensions` MUST be ignored. The two
  earlier "ignored" sentences were wrong and have been corrected.
- **Key-resolution failure mode disambiguated.** RFC-AITP-0007 §3 now
  uses `key_resolution.fail_mode` (default `fail_closed`), not
  `revocation_policy.mode`. The two fields govern different failure
  classes (key resolution vs. revocation lookup) and have always been
  separately configurable in the trust-anchors schema.
- **Session Trust Bundle over-promising removed.** RFC-AITP-0004 §9
  no longer claims that bilateral TCTs propagate to all participants.
  RFC-AITP-0010 is reserved with no normative content; v0.1 is
  bilateral only. Added explicit non-goal in §12.
- **RFC-0012 signing-input contradiction fixed.** Extensions ARE part
  of the signed object — the §5 bullet now says they are ignored *for
  trust decisions*, not absent from the signature.
- **RFC-0001 §8 endpoint table reconciled.** Trimmed to the two
  endpoints v0.1 normatively requires (`/.well-known/aitp-manifest`,
  `<handshake_endpoint>`). TCT verification, delegation verification,
  and revocation list publication are deployment-defined; peers MAY
  advertise them under `extensions`.
- **RFC-0004 ↔ RFC-0005 forward dependency.** RFC-0004's "Depends on"
  line no longer lists RFC-0005; the reverse reference is preserved
  via "Referenced by".

### Editorial simplification

- **Docs consolidated.** `docs/why-aitp.md` and `docs/overview.md`
  merged into [`docs/architecture.md`](docs/architecture.md), now the
  single non-normative orientation document. Reading order, comparison
  table, flows, transports, state, invariant, and design rationale all
  live there.
- **`docs/operational-guidance.md`** added: renewal patterns, Manifest
  rotation, cache TTL tuning, failure modes, rate limiting. RFC-0004
  §8 now contains only the normative paragraph and points here.
- **`docs/implementer-quickstart.md`** added: one-page reading order
  with context for someone building an AITP peer.
- **`docs/GLOSSARY.md`** gains a Concept Index table mapping each
  concept to a one-line definition and authoritative RFC location.
- **RFC-AITP-0004 §1** condensed from four subsections to a four-item
  list of normative principles. The "why four messages?" rationale
  moved to architecture.md §8. §11 security subsections renumbered
  (11.1–11.4).
- **RFC-AITP-0001 §6** Capability Negotiation reduced to a
  cross-reference to RFC-0003 (discovery-time) and RFC-0004 (handshake-
  time). Section numbering preserved to avoid breaking cross-refs.
- **Manifest `description` field removed.** RFC-AITP-0003 §3.2 and
  the JSON schema now expose only `display_name`. `description`
  duplicated `display_name` and added no value.

### Examples and conformance

- `examples/mutual-handshake/peer-signed-full-flow.json` moved to
  `examples/non-normative/peer-signed-full-flow.json`. The transcript
  is a multi-message narrative, not a single schema-valid object;
  putting it in `non-normative/` (with a README) prevents reader
  confusion. Validation script and `examples/README.md` updated.
- All 25 JSON artifacts validate under `make validate`.

### Release hygiene

- **`make release`** is now the only sanctioned way to produce an
  archive. CI rejects any PR whose tree contains `.DS_Store` or
  `__MACOSX/`. New `RELEASING.md` documents the procedure;
  `governance/RFC-PROCESS.md` cross-references it.
- **Registry stability headers.** `registries/capabilities.md` and
  `registries/error-codes.md` carry explicit v0.1 stability statements.
- **Error code naming convention** documented in
  `registries/error-codes.md`: `<OBJECT>_<FAILURE>` for object-level
  failures, bare codes for envelope-level.

---

## v0.1.0-rc.1

Release candidate intended for external security review. After this point, further changes should come from human reviewer feedback rather than additional AI iterations.

### Architecture

- **Manifest identity split** — Manifests now carry `identity_hint` (static `type`/`subject`/`issuer` metadata, no JWT). The verifiable identity proof is exchanged inline in the Mutual Handshake (`payload.identity`), where it can be bound to the per-handshake nonce and the verifying peer's AID. Manifest verification (RFC-AITP-0003 §5) no longer includes identity-proof verification.
- **AID encoding pinned** — `aid:pubkey:<id>` is the unpadded base64url of a 32-byte raw Ed25519 public key — exactly 43 characters. SPKI DER and PEM are not permitted in v0.1.
- **`cnf.jkt` thumbprint pinned** — JWK input for the thumbprint is exactly `{"crv":"Ed25519","kty":"OKP","x":"<aid-id>"}`. No additional members.
- **Single canonical signing input** — RFC-AITP-0001 §5.4.1 makes JCS canonical JSON the only signing input across all transports.
- **Unknown-field rejection** — RFC-AITP-0001 §7 now rejects unknown JSON fields outside explicit `extensions` namespaces. Silent acceptance was creating signature ambiguity.
- **Strengthened delegation `grant_proof`** — added `source_tct_jti` for revocation lookup, added a `grant_proof.subject == issued_by` check, documented the issuance flow in RFC-AITP-0006 §3.1. New error codes: `INVALID_GRANT_PROOF` (broadened) and `SOURCE_TCT_REVOKED`.
- **`accepted_identity_types`** — new optional Manifest field (default `["oidc"]`). Lets non-OIDC peers screen for compatibility at discovery time.
- **`required_peer_capabilities` enforcement** — new `INSUFFICIENT_GRANTS` error. Receivers MUST verify peer-issued TCTs include every capability in their own `required_peer_capabilities`.

### Wire format: JSON only

- **Removed Protobuf entirely from the v0.1 specification.** v0.1 ships JSON-only to eliminate the JSON↔Protobuf drift bugs that dominated review tax (binding/grants mismatches, signing-profile ambiguity, Manifest wrapper inconsistency, revocation snapshot mismatch).
- Deleted `schemas/proto/`, `buf/`, `buf.yaml`, the `packages/` placeholder, and `scripts/validate-proto.sh`. There is no `experimental/` or parked Protobuf binding in this repository — the canonical JSON Schemas under `schemas/json/` are the entire wire-format surface.
- Stripped every Protobuf, gRPC, and `aitp.v1.<Message>` reference from RFCs, README, VERSIONING, CONTRIBUTING, `docs/architecture.md`, `docs/integration-guide.md`, and `docs/why-aitp.md`. The transport tables now describe HTTPS + JSON only; non-JSON framings are permitted as long as the canonical JCS signing input is preserved (RFC-AITP-0001 §5.4.1) but are not part of v0.1 conformance.
- `.github/workflows/ci.yml`: removed the `lint-protobuf` job and the `protoc` step. CI runs JSON Schema and example/fixture validation only.
- `.github/PULL_REQUEST_TEMPLATE.md`: dropped the Protobuf checklist items.
- `Makefile`: removed `proto-lint`, `proto-compile`, `proto-gen-all`, and the per-language `gen-*` targets. `make validate` is now the only validation entry point.
- A future RFC may re-introduce a Protobuf binding in v0.2 if production deployments demand it; until then, AITP is JSON-native.

### Schemas

- All 7 JSON Schemas tightened with v0.1 Ed25519 patterns:
  - AIDs: `^aid:pubkey:[A-Za-z0-9_-]{43}$`
  - Signatures: `^[A-Za-z0-9_-]{86}$`
  - PoP nonces and Manifest challenges: `^[A-Za-z0-9_-]{22}$`
  - Public keys (`cnf`, pinned `public_key`, trust-anchor keys): `^[A-Za-z0-9_-]{43}$`
- Manifest schema renames `identity` to `identity_hint`, drops `proof` from the hint's required set.
- Manifest schema: signed object is the inner `manifest`; the `{"manifest": {...}}` wrapper is HTTP-only and not part of the signing input (RFC-AITP-0003 §6.1).
- Inline-handshake TCT now requires `binding`; both TCT schemas require `grants` minItems 1.
- TCT schema gains capability-ownership normative text (RFC-AITP-0005 §4.2.1): grant strings are opaque to AITP and owned by the namespace prefix.
- Trust-anchors schema defaults `revocation_policy.mode` and `key_resolution.fail_mode` to `fail_closed` (was `soft_fail`).
- Delegation schema gains `source_tct_jti` (uuid v4) on `grant_proof`; `signature` documented as a verbatim copy of the source TCT's signature.

### Documentation and registries

- RFC-AITP-0001 §5.3 pins the AID character count and forbids SPKI/PEM.
- RFC-AITP-0002 §2.2.1 pins the JWK form for `cnf.jkt`.
- RFC-AITP-0005 §4.2.1 documents capability-ownership semantics.
- RFC-AITP-0005 §9.3 replaces stale "verify PoP when `binding.cnf` is present" wording with the per-grant policy form.
- RFC-AITP-0006 §3.1 documents the delegation issuance flow (TCT → grant_proof mapping table).
- RFC-AITP-0007 §2.3: OIDC discovery (`/.well-known/openid-configuration` → `jwks_uri`) is the primary key-resolution path; `/.well-known/aitp-keys` is a fallback for non-OIDC issuers.
- RFC-AITP-0008 §3.1 qualifies `soft_fail` and reflects the new schema default.
- RFC-AITP-0008 §1.5 + new `RevocationListSnapshot` make the signed snapshot normative.
- RFC-AITP-0009 §1.6 and §6.4 align with the per-grant PoP model.
- `docs/integration-guide.md` rewrites the Python example: JCS via `pyjcs`, strict no-padding base64url decode, unknown-field rejection, full 43-char placeholder.
- `docs/discovery.md`, `examples/delegation/single-hop.json`, `examples/manifest/agent-b-manifest.json`, `examples/mutual-handshake/peer-signed-full-flow.json`, `examples/tct/tct-peer-issued.json` regenerated with v0.1-compliant placeholders.
- `docs/non-goals.md` §12 added: data references and operational context.
- `registries/error-codes.md` updated for new codes (`INSUFFICIENT_GRANTS`, `SOURCE_TCT_REVOKED`, broadened `INVALID_GRANT_PROOF`).
- `registries/README.md` link to `RFC-AITP-0005-tct.md` corrected (was 0004).
- `README.md` `aitp-session-participant` profile marked as forthcoming until RFC-AITP-0010 reaches Draft; stale `tct-peer-issued-with-binding.json` reference removed.
- `governance/CHARTER.md` created (was a dangling reference from `RFC-PROCESS.md`).

### Conformance fixtures

- Added `id-001` (OIDC JWT missing `aud`), `id-002` (`aud` targets wrong peer), `id-003` (missing `cnf.jkt`).
- All fixtures and examples re-stripped of `=` base64url padding.
- All inline manifests in fixtures and examples migrated to `identity_hint` (no `proof`).
- `del-003` updated to use `issuingPeer` AID and the new `source_tct_jti` field.
- `schemas/conformance/README.md` documents the multi-step `sequence` form (mh-001).

### Repository hygiene

- Deleted the stale `temp/` directory.
- Removed the Claude-assistant block from `.gitignore`.
- Added `make release` target (sanctioned release archive build).

### Decisions recorded

- **TCT audience model**: Option A (subject = audience; "holder receipt"). The TCT proves what its holder is allowed to do at the issuer; it is referenced, not presented as a bearer token. Option B ("OAuth-style presented token") was considered and rejected as a larger architectural change.
- **Downstream PoP marking mechanism**: deferred to v0.2. v0.1 retains the per-grant deployment-defined wording.
- **Wire format**: JSON only for v0.1. Protobuf has been fully removed from this repository to keep the v0.1 surface unambiguous. v0.2 may introduce a Protobuf binding via a dedicated mapping RFC if production deployments demand it.

---

## v0.1 (Draft) — revision 4

Editorial cleanup pass. Removes stale "OPTIONAL/SHOULD" wording around downstream PoP that contradicts the per-grant-policy model in RFC-AITP-0005 §6, removes `verifier` terminology from the delegation example (AITP has no verifier role), qualifies the "stateless and local" claim, and adds an `accepted_identity_types` field so non-OIDC identities have a screening surface. No protocol changes.

### RFC text fixes

- RFC-AITP-0001 §4: qualified the "stateless and local" verification claim — applies to TCT signature/expiry/audience/grant/PoP, but not to revocation status, which is pull-based and may involve a network call.
- RFC-AITP-0005 §9.3: replaced the stale "Verify PoP when `binding.cnf` is present" SHOULD with the per-grant-policy form aligned with §6. Conformance posture stated explicitly.
- RFC-AITP-0009 §1.6: replaced the lone SHOULD on TCT PoP with a tiered MUST/SHOULD that matches RFC-AITP-0005 §6.
- RFC-AITP-0009 §6.4: rewrote the "stolen TCT" walkthrough note so it no longer marks downstream PoP as OPTIONAL.

### Schema

- `accepted_identity_types` (optional, defaults to `["oidc"]` when absent) added to RFC-AITP-0003 §3.2 and the manifest JSON Schema. Lets non-OIDC identities (e.g. `pinned_key`) screen for compatibility at discovery time without abusing `accepted_trust_anchors`.
- RFC-AITP-0003 §5 step 6: updated screening logic to consult `accepted_identity_types` for non-OIDC peers and `accepted_trust_anchors` for OIDC peers.

> Note: this revision predates the v0.1.0-rc.1 Protobuf removal. The originally-listed `aitp.v1.AgentManifest` proto field has no v0.1 equivalent; only the JSON Schema entry remains.

### Examples

- `examples/delegation/single-hop.json`: renamed `verifierExamplePub` → `issuingPeerExamplePub` and `verifier_signature_placeholder` → `issuingPeer_signature_placeholder`. AITP has no `verifier` role.

### Documentation

- `schemas/conformance/README.md`: added "Multi-step `sequence` form" subsection documenting the alternate fixture shape used by `mh-001`.

### Repository hygiene

- `.gitignore`: removed the Claude Code assistant block (`CLAUDE.md`, `.claude/`, `/plans/`). These belong in the user's global git ignore, not the repo.

---

## v0.1 (Draft) — revision 3

Consistency and clarification pass over the v0.1 draft. No protocol changes.

### Schema fixes

- `binding` is now REQUIRED on the inline TCT in the Mutual Handshake schema (matches the main TCT schema and RFC-AITP-0005 §6).
- `grants` arrays now require `minItems: 1` in both TCT schema and the inline handshake TCT (matches RFC-AITP-0004 §4.1, which forbids empty-grants TCTs).

> Note: this revision predates the v0.1.0-rc.1 Protobuf removal. An earlier `tct.proto` comment fix listed in the original revision-3 notes no longer has a v0.1 equivalent.

### RFC clarifications

- RFC-AITP-0003 §5: swapped Manifest verification steps so signature precedes identity proof. Identity verification now uses an authenticated public key.
- RFC-AITP-0004: clarified the inline `identity` field in MUTUAL_HELLO/MUTUAL_HELLO_ACK — it is a fresh, handshake-bound proof that MUST match `manifest.identity` `type`/`subject` and (for OIDC) MUST carry the `pop_nonce` as the JWT `nonce` claim.
- RFC-AITP-0005 §3: removed the §3 "Optional Fields" framing. `binding.cnf` is REQUIRED for every v0.1 peer-issued TCT (already in the schema and §6); the §3 text is now consistent.
- RFC-AITP-0006: added rationale for why `grant_proof` is a minimized projection of the original TCT rather than the full TCT.
- RFC-AITP-0008 §3.1: qualified `soft_fail` as the recommended default for non-critical deployments only; production handling of high-value capabilities SHOULD default to `fail_closed`.

### Examples and conformance

- Stripped `=` base64url padding from every example AID, nonce, `cnf`, and signature placeholder per RFC-AITP-0001 §5.4 (unpadded base64url).
- Added three new identity-failure conformance fixtures: `id-001` (JWT missing `aud`), `id-002` (JWT `aud` targets wrong peer), `id-003` (JWT missing `cnf.jkt`).

### Documentation

- README: marked the `aitp-session-participant` profile as forthcoming until RFC-AITP-0010 reaches Draft status.
- `docs/non-goals.md`: added §12 Data references and operational context.

### Repository hygiene

- Removed the stale `temp/` directory containing superseded RFC drafts and proto/schema files.

---

## v0.1 (Draft) — current

The first published version of AITP. **Agent-to-agent (A2A) from the start.** No service-consumer profile.

### Included

- **Envelope** with replay protection, signatures, and a unified error registry (RFC-AITP-0001).
- **Identity binding** via OIDC and pinned-key (RFC-AITP-0002).
- **Agent Manifest** as the signed self-description, served at `/.well-known/aitp-manifest` (RFC-AITP-0003).
- **Mutual Handshake** — four-message peer authentication producing two TCTs (RFC-AITP-0004).
- **Trust Context Token** — the canonical peer-issued capability grant (RFC-AITP-0005).
- **Single-hop delegation** with stateless grant verification (RFC-AITP-0006).
- **Key resolution** — Manifest-first for peers; cache → pinned → well-known for identity issuers (RFC-AITP-0007).
- **Revocation** — per-issuing-peer JTI deny lists, three failure modes (RFC-AITP-0008).
- **Security & threat model** for A2A interactions (RFC-AITP-0009).
- **JSON Schemas** for envelope, identity, manifest, mutual-handshake payloads, TCT, delegation, trust anchors.
- **Conformance fixtures** for replay rejection, expired TCT, and delegation scope-exceeded.

### Reserved (numbering pinned, no normative text)

- RFC-AITP-0010 Session Trust Bundle — multi-agent session scaling.
- RFC-AITP-0011 Multi-hop Delegation — chains beyond a single hop.
- RFC-AITP-0012 Extensions — `extensions.zk` and `extensions.tee` namespaces.

### Explicitly out of scope in v0.1

- Service-consumer (`Agent → Verifier → Service`) trust flows.
- ECDSA P-256 (Ed25519 only in v0.1).
- TCT `evidence_ref` field (informational-only fields removed for clarity).
- TCT `audience: "*"` wildcard (every TCT is bound to one peer).
- `shared_verifier` handshake mode (peer-signed is the only mode).
- Hello / Challenge / Response service handshake (replaced by the Mutual Handshake).
