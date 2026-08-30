# Changelog

## Unreleased

### Issue #28: RFC-AITP-0008 §1.5 cited RFC-AITP-0011 for a wrapper convention it does not have

**Editorial.** The `signature` field-table row in §1.5 stated that the
inner-body signing convention "matches the RFC-AITP-0010 session-bundle and
RFC-AITP-0011 multi-hop conventions: the wrapper key names the artifact for
transport routing but the issuer signs the inner body." RFC-AITP-0011 has no
artifact-name wrapper to cite: its multi-hop delegation token is a compact
JWS string (RFC-AITP-0011 §1, per RFC-AITP-0006 §2), which by construction
carries no JSON wrapper. RFC-AITP-0001 §5.4.1 is the authoritative
enumeration of artifact-name-wrapped JCS artifacts — exactly three:
`{"manifest": …}`, `{"revocation_list": …}`, `{"session_bundle": …}` — and
groups the delegation token with the compact-JWS profile instead. The
RFC-AITP-0010 half of the citation is correct and unaffected.

The `RFC-AITP-0011 multi-hop` half is deleted rather than retargeted:
there is no RFC-AITP-0011 section that supports the claim, because the
convention the sentence describes does not exist in that document. This is
the same resolution already used for the sibling defect earlier in this
file, where §5.4.1's `(RFC-AITP-0008 §3.3)` citation was deleted outright
rather than pointed at a different RFC-AITP-0008 section, for the same
reason — no section of the target document supports the claim.

- `rfcs/RFC-AITP-0008-revocation.md` §1.5 — the `signature` row's
  parenthetical now reads "This matches the RFC-AITP-0010 session-bundle
  convention: the wrapper key names the artifact for transport routing but
  the issuer signs the inner body," dropping the RFC-AITP-0011 clause and
  the now-inaccurate "conventions" plural.

**Version bump.** `RFC-AITP-0008-revocation.md` moves `0.2.3-draft` →
`0.2.4-draft` per VERSIONING.md:24's Editorial / clarification class (no
schema or wire change).

### RFC-AITP-0001 §5.4: subsection order, enumeration drift, and a bad citation

**Editorial.** RFC-AITP-0001 §5.4's subsections were physically out of order —
5.4.3, 5.4.4, 5.4.1, 5.4.2, 5.4.5 — so a reader following the numbering met the
algorithm-tag section (§5.4.3) before the signing-input section (§5.4.1) that
defines what is being signed. §5.4.1 and §5.4.2 move to sit before §5.4.3,
producing the plain ascending order 5.4.1–5.4.5. This is a pure block move: the
moved text is byte-identical to its pre-move form, and no heading text changed,
so every existing `#541-signing-input-jcs-profile`-style anchor link still
resolves — Markdown anchors are derived from heading text, not position.

Two of RFC-AITP-0001's four enumerations of JCS-profile artifacts omitted the
session bundle while the other two already included it — PR #22/#30 wrote
bundle handling into §5.4.1's body without retrofitting its own opening lines.
Both are corrected to name the session bundle, bringing all four enumerations
(the §5.4 profile table, the §5.4.1 opening sentence, the §5.4.3 field list,
and the §5.4.1 known-answer callout) into agreement:

- §5.4 profile table, JCS embedded-signature profile row — Artifacts cell gains
  "session trust bundles".
- §5.4.1 opening sentence — the parenthetical artifact list gains "session
  bundle".

Separately, §5.4.1's wrapper-note blockquote cited RFC-AITP-0008 §3.3 for the
claim that a cache shared among the components of a single deployment does not
make an artifact redistributable. §3.3 is "Revocation lookup ordering" —
signature checks before network-adjacent revocation lookup — and does not
discuss multi-component cache-sharing within a single deployment; no section of
RFC-AITP-0008 supports this specific claim. The `(RFC-AITP-0008 §3.3)`
parenthetical is deleted outright rather than retargeted; the sentence stands
on its own. The following sentence's `(RFC-AITP-0008 §3.2)` citation, which
supports a different and correctly-scoped claim, is unchanged.

- `rfcs/RFC-AITP-0001-core.md` §5.4 — subsections reordered to 5.4.1–5.4.5; the
  profile table and §5.4.1's opening sentence now name the session bundle; the
  unsupported RFC-AITP-0008 §3.3 citation removed.

**Version bump.** `RFC-AITP-0001-core.md` moves `0.2.2-draft` → `0.2.3-draft`
per VERSIONING.md's Editorial / clarification class (no schema or wire
change). No other RFC's `Version:` header changes.

### §5.4.1's restatement promise, kept at each artifact's signing section

**Editorial.** RFC-AITP-0001 §5.4.1 states the member-vs-sibling signature
placement rule and says it is "restated at each artifact's own signing
section" — a restatement that did not exist. All three artifact RFCs
restated only the wrapper-stripping *mechanic* (strip the artifact-name key
before canonicalizing), never the *placement* rule or its rationale, so
`redistributable` and `point-to-point` appeared only in RFC-AITP-0001. Each
artifact RFC now carries a short paragraph, at its own signing section,
naming which placement it uses, why, and that artifact's actual
redistribution path, citing back to RFC-AITP-0001 §5.4.1 rather than
re-deriving the rule:

- `rfcs/RFC-AITP-0003-manifest.md` §6.1 — the Manifest carries `signature`
  as a member of the body because it is redistributable: it MAY be
  exchanged inline during the Mutual Handshake (§1; §4.3) rather than
  always fetched from its own origin.
- `rfcs/RFC-AITP-0008-revocation.md` §1.5 — the revocation snapshot carries
  `signature` as a sibling of the wrapper because it is point-to-point: a
  consuming peer polls it directly from the issuing peer's `ListRevoked`
  endpoint (§1.4) and never redistributes it onward. The consumer's own
  caching and staleness bound (§3.2) are private to that consumer and do
  not make the snapshot redistributable. The added paragraph is explicit
  that this sibling placement is **deliberate** — what §5.4.1's rule
  produces for a point-to-point artifact, not an exception carved out from
  it — so a future editor does not "fix" it into a member placement and
  break every deployed verifier.
- `rfcs/RFC-AITP-0010-session-trust-bundle.md` §3 — the bundle carries
  `signature` as a member of the body because it is signed once by the
  coordinator and distributed to every participant (§4.3).

**Version bump.** `RFC-AITP-0003-manifest.md` moves `0.2.1-draft` →
`0.2.2-draft`; `RFC-AITP-0008-revocation.md` moves `0.2.1-draft` →
`0.2.2-draft`; `RFC-AITP-0010-session-trust-bundle.md` moves
`0.2.2-draft` → `0.2.3-draft`. All three per VERSIONING.md's Editorial /
clarification class (no schema or wire change).

### Issue #27: five field tables catch up to the `extensions` member their schemas already define

**Editorial.** `aitp-mutual-handshake.schema.json` defines an optional `extensions`
object on all four handshake payloads (`MutualHelloPayload`, `MutualHelloAckPayload`,
`MutualCommitPayload`, `MutualCommitAckPayload`), and `aitp-revocation-list.schema.json`
defines one inside `revocation_list`, but the corresponding RFC field tables never
mentioned it — a strict consumer validating against the RFC's own documented surface
would reject a conformant message carrying `extensions`. This is the identical defect
RFC-AITP-0010 §3 had, fixed there in PR #30; these are the five remaining instances,
tracked as issue #27 and folded into this pass since it is the same defect class, not
separate work.

Each row was generated from its schema definition (`type`, `description`, and absence
from `required`), not transcribed by hand, and diffed against the schema afterward —
the four handshake payloads are structurally near-identical, which is exactly the
condition under which copy-paste error is likely.

- `rfcs/RFC-AITP-0004-mutual-handshake.md` §§3.1–3.4 — each payload's field table gains
  an `extensions` row. RFC-AITP-0004's handshake payloads carry no `signature` member
  of their own; the envelope signature covers `hex(sha256(payload_canonical_json))`
  (RFC-AITP-0001 §5.4), so `extensions`, being a member of the canonicalized payload,
  is covered by the signature through that hash rather than by direct member-stripping.
  The row states this mechanism rather than reusing RFC-AITP-0010's "member of the
  signed body" wording verbatim, since the signing mechanism differs.
- `rfcs/RFC-AITP-0008-revocation.md` §1.5 — the revocation table gains an `extensions`
  row. Here `signature` sits outside `revocation_list` as a sibling of the wrapper
  (§1.5's existing "signature sits outside the body" note), so `revocation_list` — the
  body actually signed — has no member to strip, and `extensions`, being a member of
  that body, is covered by the signature directly, the same as RFC-AITP-0010 §3's row.
- Both rows carry the absent-vs-empty (`{}`) canonicalize-differently note from
  RFC-AITP-0010 §3's template, and cite RFC-AITP-0001 §7 and RFC-AITP-0012 for the
  namespacing rules.

**Version bump.** `RFC-AITP-0004-mutual-handshake.md` moves `0.2.0-draft` →
`0.2.1-draft`; `RFC-AITP-0008-revocation.md` moves `0.2.2-draft` → `0.2.3-draft`.
Both per VERSIONING.md:24's Editorial / clarification class (no schema or wire
change — the schemas were already correct; the RFC tables are catching up).
`rfcs/README.md`'s version sentence updated to match both new headers.

### Session bundle: the signature is a member of the signed body

**Breaking for anything validating a session bundle against the published JSON
schema.** RFC-AITP-0010 §3 places `signature` inside the inner `session_bundle`
body — its example, its field table, its construction steps and its verification
steps all agree — while `aitp-session-bundle.schema.json` required it as a
sibling of the `{"session_bundle": …}` wrapper and forbade it inside the body.
The three `bundle-*` conformance fixtures followed the schema. An artifact could
therefore satisfy the RFC and fail the schema, or the reverse, and no
implementation could satisfy both. The schema and the fixtures move; the RFC
prose was already correct and is unchanged.

The bundle is a **redistributable** artifact: a coordinator signs it once and it
is forwarded, cached and relayed to every participant over any transport that
preserves the canonical JSON — RFC-AITP-0010 §4.3 names a signed message bus
alongside HTTPS POST. A signature that sits beside the transport wrapper is lost
the moment a hop strips that wrapper, so the proof has to travel inside the
signed body. This is deliberately not the
convention used by the revocation snapshot, which is polled point-to-point from
the issuing peer's `ListRevoked` endpoint and never relayed, and which keeps its
sibling signature. RFC-AITP-0001 §5.4.1 records which artifact uses which
placement, and now also states the rule that decides between them, so the next
artifact author does not have to infer it from the examples.

**No pinned cryptographic value changes.** The signing input was never in
dispute: both readings canonicalize the bundle body with the `signature` member
excluded, so the bytes are identical. `kat-session-bundle-001` was re-verified
after the change — 922 canonical bytes, SHA-256
`c577854d144c912e145e8ec6cbab09361ceb709a43be5cbd1ef538085b1aa5e5`, and its
pinned `coordinator_signature_b64url` still verifies — and is byte-identical to
its previous state. Nothing was re-minted; the fixtures' `__VALID_A_SIG__`
placeholder simply moved position.

Why the break is acceptable: RFC-AITP-0010 declares its schema Draft, and the
session-bundle fixtures are opt-in (`required_for_v0_2: false`). `aitp-rs`
already serializes and parses the inner shape, so its output becomes
schema-valid with this change rather than being broken by it. `aitp-verifier-py`
reads and mints the sibling shape and will need the matching correction; that is
tracked as an issue against that repository.

Conformance tooling now checks this class of divergence mechanically: every
fixture's `input` is validated against the artifact schemas on each run, so a
schema and the fixtures describing it can no longer disagree unnoticed.

- `schemas/json/aitp-session-bundle.schema.json` — `signature` moves into the
  inner body's `properties` and `required`; the top level requires only
  `session_bundle`. Its description now states the signing input and the
  placement rule inline, instead of deferring to the revocation list's
  convention — that cross-reference was how the wrong shape propagated.
- `schemas/conformance/bundle-001-success.json`,
  `bundle-002-not-member.json`, `bundle-003-expired.json` — `signature` moved
  inside the body, placeholder value unchanged.
- `rfcs/RFC-AITP-0001-core.md` §5.4.1 — states the rule that decides signature
  placement, so it no longer reads as a list of precedents: redistributable
  artifacts carry the proof inside the signed body, point-to-point artifacts MAY
  carry it as a sibling of the wrapper.
- `rfcs/RFC-AITP-0010-session-trust-bundle.md` §3 — erratum sentence recording
  that earlier schemas mis-stated the placement, and an `extensions` row so the
  field table documents every property the schema defines. The slot was already
  in the schema and reserved for every signed object by RFC-AITP-0001 §7; only
  the table omitted it. `aitp-rs` rejects bundles carrying it and is tracked
  separately.

**Version bump.** `RFC-AITP-0001-core.md` and
`RFC-AITP-0010-session-trust-bundle.md` move `0.2.1-draft` → `0.2.2-draft`, and
no other RFC's `Version:` header changes.

Calling this both *breaking* and a *patch bump* is not a contradiction, and the
distinction is worth stating in VERSIONING.md's own vocabulary. **The protocol
did not change.** The wire artifact RFC-AITP-0010 specifies is exactly what it
always was; what moved is a schema that described it incorrectly, plus the
fixtures that copied the schema. Breakage falls on consumers who validated
against the incorrect schema — real, and named plainly at the top of this entry
— not on anything that follows the RFC. So this is not a breaking protocol
change in the sense VERSIONING.md's table means, and it does not bump the JSON
Schema namespace path segment: `$id` stays at `v0.2` and no `schema-vX.Y.Z` tag
is implied. VERSIONING.md's editorial clause names known-answer vectors and
signed examples rather than the canonical schemas, so the closest-fitting rule
is applied by analogy rather than quoted: an artifact corrected to match what
the RFC already required is a patch bump on the RFCs whose text moves.
RFC-AITP-0001 moves only because the placement principle is added to it.

### JCS signing input: the artifact-name wrapper is not signed

**Breaking for anything pinning the known-answer digests.** Three JCS-profile
known-answer vectors pinned the transport wrapper as their canonical bytes
instead of the inner artifact body. One of them — `kat-session-bundle-001` —
pinned a real signature over those wrapped bytes, as did the committed
`signed-examples/revocation/` snapshot; `kat-manifest-001` and
`kat-revocation-001` carry no signature member, so for those two only the
canonical bytes and digest were wrong. RFC-AITP-0003 §6.1, RFC-AITP-0008 §1.5 and RFC-AITP-0001 §5.4.1 all
specified the inner body; the vectors were the outlier. RFC-AITP-0008 §1.5
already required implementations to emit the inner form going forward, so this is
that migration applied to the vectors.

Old and new values, so a consumer can tell which copy they hold:

| Vector | Old canonical bytes / SHA-256 | New canonical bytes / SHA-256 |
|---|---|---|
| `kat-manifest-001` | 636 B · `cef51854ee7b83bb0da9e0c274a5da88255fa69657cf62939cb43cdd9746c5ae` | 623 B · `b93915e980ebca05a68a81465ac36e416bc3dec40e068f21770cba6c415884af` |
| `kat-revocation-001` | 241 B · `739feb36cc2530ad3188f6c3a9ee7459820533382ee24387a8c261787397e0d9` | 221 B · `dad7eb6db48c924ef30de7c20a6702715b512dd8aee12c9eed33139ba7008bfb` |
| `kat-session-bundle-001` | 941 B · `dc99e7252ab25d2896eb2468d32b8d33b48a62150525ece727038cc29b4f2640` | 922 B · `c577854d144c912e145e8ec6cbab09361ceb709a43be5cbd1ef538085b1aa5e5` |

Re-minted signatures — the bundle vector and the revocation signed example, the
only two pinned signatures that covered wrapped bytes (RFC-AITP-0008 §1.5 notes
that both revocation artifacts, the vector and the signed example, were
corrected):

| Signature | Old | New |
|---|---|---|
| `kat-session-bundle-001.coordinator_signature_b64url` | `Su2JiXGiOhxs-StL7NLhT9-yZVHi-4SSiMSLRFu_Kkmh1ZPu7GxKJ0OX2hJ7P6NXFiQM6Uy4rXF7WTpr2M2_AA` | `czzmjpVf5rtZ2-FvfMcviSUCeY2WSu69v2ZECpflHAKVaEikz4w6m5fOVuBZkCL8DXX-lkY905NvYxjQTg_TBw` |
| `signed-examples/revocation/kat-keypair-001-snapshot.json` `signature` | `2OYmur9NnrFsrz4Qeso_fGj2Bk0g2y6yNf4H7dqrqEvKZ-YfndY3GavquOIodWGs4EFdgmaHoer0NWc7sPF1DQ` | `DTmCoELd0lIRCRBdhDuLmEqvFK1VqpTSGyPEG6-C0InTOeF8LB4a-Rf4ercCvhLYD6H1t9_T-7FgQ1ufBfKkCQ` |

`signed-examples/manifest/kat-keypair-001-manifest.json` is **unchanged** — it was
already signed over the inner body, and is the control showing the correction did
not overshoot.

**Version bump.** `known-answer/README.md` requires that "an existing vector's
output MUST NOT change without an RFC bump", and this changes three. The four
RFCs whose text moves are bumped **`0.2.0-draft` → `0.2.1-draft`**:
RFC-AITP-0001, RFC-AITP-0003, RFC-AITP-0008, RFC-AITP-0010. The other nine
documents are untouched — the seven other Draft-stage RFCs stay at
`0.2.0-draft`, and RFC-AITP-0012 / RFC-AITP-0013 keep their `0.2.0-reserved` /
`0.2.0-planned` placeholders — and VERSIONING.md now records that document
versions may diverge within one protocol revision.

Patch level, per VERSIONING.md's *Editorial / clarification* class, because the
normative requirement did not change — the artifacts were wrong. RFC-AITP-0003
§6.1 and RFC-AITP-0008 §1.5 already specified the inner body, and RFC-AITP-0008
§1.5 already required implementations to emit it going forward; RFC-AITP-0010
gains an explicit statement of a rule RFC-AITP-0001 §5.4.1 already imposed on
every JCS-profile artifact. The vectors are being brought into line with
requirements that already shipped.

**Two layers deliberately do NOT move.** The protocol literal stays `aitp/0.2`:
no message shape changed, every `version` field and `ver` claim is untouched, and
RFC-AITP-0008 §1.5's transition clause presumes issuers and verifiers remain on
the same protocol revision while they migrate. The JSON Schema namespace stays
`https://aitp.dev/schema/v0.2/`: no schema shape changed — only two `description`
strings in the revocation schema, and descriptions are not part of the contract.
Moving either would signal a break that did not occur and would invalidate every
fixture and both implementations for no benefit.

The alternative — keeping the digests and amending three RFCs to bless the
wrapper — would have contradicted RFC-AITP-0003 §6.1 and both implementations'
Manifest behaviour, and would have required re-minting the *correct* Manifest
signed example to match a wrong vector.

**Migration.** RFC-AITP-0008 §1.5 permits accepting either canonical shape during
a transition window while emitting the inner form. Implementations that signed
the wrapper for revocation snapshots or session bundles will fail against these
vectors until they move; that failure is the intended signal. The Manifest is
unaffected in practice — implementations already signed its inner body, which is
why `kat-manifest-001` was wrong for the whole of v0.2-draft without anything
noticing.

- **RFC-AITP-0001 §5.4.1**: states that the artifact-name wrapper
  (`{"manifest": …}`, `{"revocation_list": …}`, `{"session_bundle": …}`) is a
  transport wrapper covered by the section's existing requirement to strip
  wrappers before canonicalizing, and covers both signature placements — a member
  of the body for the Manifest and session bundle, a sibling of the wrapper for
  the revocation snapshot. Scoped away from the unwrapped JCS artifacts.
- **RFC-AITP-0010**: gains the unwrap rule it never stated, in §3's `signature`
  row, §4.2 step 4 and §5 step 6. §9's KAT paragraph also claimed the vector pins
  two participant TCTs; it pins one.
- **RFC-AITP-0003 §6.1, RFC-AITP-0008 §1.5**: "MUST reproduce it byte-for-byte"
  now names the signing input, and both require the committed signed examples be
  verified as committed, without re-minting.
- **Known-answer vectors** carry a `signing_input` member so the file states its
  own convention.
- **`schemas/conformance/PLACEHOLDERS.md`**: `__VALID_A_SIG__` had been defined as
  "context-dependent — minting tool resolves from surrounding fixture shape",
  which let two minting tools choose different conventions and each verify its own
  output. Replaced with a table resolving it per enclosing artifact. This narrows
  an ambiguity rather than renaming a placeholder, so it does not require the RFC
  process under this file's own Stability section.
- **Fixture `$comment` corrections**: `rev-001`, `rev-002` and `rev-003` asserted
  "the JCS-profile snapshot signing input is unchanged in v0.2", which was false
  and is a plausible reason the migration was never made; `bundle-001` described
  the input as the bundle bytes "excluding nothing"; `tct-004` and `del-mh-004`
  used the same "context-dependent" placeholder language and now name the inner
  `revocation_list` body explicitly.

### Conformance: pinned values are now executed, not just parsed

`make validate` and CI run `scripts/verify-known-answer.mjs`, which recomputes
every pinned canonical byte sequence and digest, re-derives every public key and
JWK thumbprint, and verifies every pinned signature — including the two
JCS-profile signed examples, which no implementation's test suite executed
cross-implementation. Previously nothing in this repository checked any pinned
cryptographic value; validation was JSON syntax and schema only.

For each JCS artifact it asserts both that the signature verifies over the inner
body **and** that it fails over the wrapped form, and it hard-codes the
inner-body rule rather than trusting each vector's own declaration — so the
wrapped form cannot be reintroduced even by a self-consistent change. Node
standard library only, no new dependency.

`scripts/regen-known-answer.py` regenerates the vectors by executing
`aitp-verifier-py`; the checker verifies them with an independent implementation.
Vectors are generated, never hand-transcribed.


### v0.2.0-draft — JWS-TCT migration

**Breaking revision**: the
protocol version literal becomes `aitp/0.2`, and the portable trust
artifacts (TCT, grant voucher, delegation token) are re-serialized as
RFC 7515 compact JWS with explicit typing, while protocol-internal
artifacts (envelopes, Manifests, revocation snapshots, handshake
payloads) keep the JCS embedded-signature convention. This folds in
the previously specified v0.2 crypto-agility deltas (algorithm-tagged
AIDs and signatures, JWK-thumbprint `cnf`, mandatory Ed25519+P-256
verification) under the same version literal.

- **RFC-AITP-0001 §5.4** split into two signing profiles with a
  normative boundary rule; new §5.4.5 Compact JWS profile (exact-bytes
  signatures, header restricted to `alg`+`typ`, RFC 8725 explicit
  typing, AID-derived algorithm pinning rejecting `none`, `ver` claim,
  strict base64url parsing, optional `ext` claim). New error codes
  `TOKEN_ALG_MISMATCH` / `TOKEN_TYP_MISMATCH`.
- **RFC-AITP-0005** rewritten: TCT as compact JWS (`typ:
  aitp-tct+jwt`; claims `ver/jti/iss/sub/aud/iat/exp/grants/cnf`);
  `cnf` is the RFC 7800 `{"jkt": …}` form only; new §8 **grant
  voucher** (`typ: aitp-grant+jwt`, minted alongside the TCT, carries
  `src_jti` for revocation linkage); §12 design notes record the
  rejected alternatives (dual serialization, byte-deterministic JWS,
  full JOSE migration).
- **RFC-AITP-0006** rewritten: `grant_proof` and its byte-reconstruction
  verification are deleted; the delegation token is a compact JWS
  embedding the issuer's voucher verbatim; nine-step verification with
  no reconstruction; privacy erratum recorded (the v0.1 minimization
  claim was illusory). Error code `DELEGATION_INVALID_GRANT_PROOF`
  renamed `DELEGATION_INVALID_VOUCHER`.
- **RFC-AITP-0004**: `MUTUAL_COMMIT`/`MUTUAL_COMMIT_ACK` carry `tct`
  and optional `grant_voucher` as opaque compact JWS strings; TCT
  verification steps restated per RFC-0005 §7.2.
- **RFC-AITP-0008**: terminology sweep (`jti` claim, `voucher.src_jti`);
  snapshot stays on the JCS profile, though its signing input is
  **not** unchanged from rc.3 — see the signing-input correction under
  Unreleased; §3.3
  verify-before-revocation-lookup re-affirmed for JWS artifacts.
- **RFC-AITP-0009**: new threat entries §1.12 algorithm confusion,
  §1.13 token-type confusion, §1.14 `alg: none`; reconstruction
  surface removal noted; §4 crypto-agility restated per profile.
- **RFC-AITP-0010/0011 (Draft)**: bundles embed TCT JWS strings;
  multi-hop rewritten — `chain` is an array of verbatim delegation JWS
  strings, `chain_hash` is the digest-array form, per-hop `jti`
  revocation handles, voucher only on `chain[0]`.
- **Registries**: media types `application/aitp-tct+jwt`,
  `application/aitp-grant+jwt`, `application/aitp-delegation+jwt`
  (`aitp-tct+json` superseded); error-code definitions restated in
  voucher/claim terms.
- **Schemas**: `$id` namespace bumped to
  `https://aitp.dev/schema/v0.2/` (VERSIONING.md clarified: flat
  directory + git tags, no parallel trees); `aitp-tct` / new
  `aitp-grant-voucher` / `aitp-delegation` validate decoded JWS
  claims; handshake and session-bundle schemas carry compact-JWS
  strings; AID and signature patterns extended to the v0.2
  algorithm-tagged grammar; fixture metadata gains
  `required_for_v0_2`.
- **KAT vectors**: `kat-tct-001`/`kat-delegation-001` JCS vectors
  retired; `kat-manifest-001`/`kat-revocation-001` re-minted for
  `aitp/0.2`; multihop/session-bundle vectors re-specified for the
  v0.2 shapes; `jwk-thumbprints.json` gains keypair-004 and the first
  P-256 vector and is now load-bearing for `cnf.jkt`;
  `signed-examples/` populated with **real Ed25519 compact-JWS** TCT,
  grant voucher, and delegation artifacts (independently verified with
  a non-AITP JOSE stack) plus re-signed Manifest/revocation examples;
  off-the-shelf JOSE smoke test documented in the KAT README.
- **Conformance fixtures**: full surface re-minted to v0.2 placeholder
  form (the version bump invalidates previously minted signatures;
  aitp-rs re-materializes them). New attack fixtures `tct-008`
  (alg `none`), `tct-009` (alg confusion), `tct-010` (typ confusion),
  `del-005`/`del-006` (voucher issuer/subject mismatch), `del-007`
  (v0.2 multihop structural rejection), `vch-001`/`vch-002` (voucher
  verification), `env-005` (P-256 envelope — unblocks the deferred
  aitp-rs item). `del-004` frozen in the v0.1 shape for v0.1 runners.
  PLACEHOLDERS.md gains the compact-JWS whole-token placeholder family
  with claims-sibling minting convention.

### rc.4 — RFC unified-final pass

Driven by `plans/aitp-rfc-unified-final-plan.md`. Closes the gap between
the published RFCs and the reference library, tightens four security
surfaces, and adds machine-readable conformance metadata so v0.1 runners
can correctly skip post-v0.1 fixtures.

- **RFC-AITP-0004 §8.1.** New non-normative shortened-renewal extension
  describing the wire format for an opt-in renewal endpoint advertised
  via `extensions["rfc-aitp-0005.renew_uri"]`. Eventual standardization
  reserved as **RFC-AITP-0013** (Planned).
- **RFC-AITP-0010.** Added a top-of-file conformance-scope statement —
  the `bundle-*` fixture set is SKIP for v0.1 runners; the RFC's
  MUST-level normative text applies only to draft opt-in
  implementations.
- **RFC-AITP-0008 §3.3.** Mandates that all network-adjacent revocation
  lookups defer until *after* signature verification; closes the
  attacker-chosen-network-fetch class of bugs.
- **RFC-AITP-0007 §3.2.** `soft_fail` now MUST behave as `fail_closed`
  when no trust basis exists for an issuer. Peer-Manifest key resolution
  is `fail_closed` regardless of mode — no safe subset for unverified
  identity.
- **RFC-AITP-0002 §3.2.** Pinned-key key-possession-only verification is
  forbidden as a production default; production code paths MUST consult
  a configured `pinned_keys` store.
- **Conformance fixtures.** Every fixture under `schemas/conformance/`
  carries a metadata block (`rfc`, `status`, `required_for_v0_1`,
  `feature`). New JSON Schema
  `schemas/json/aitp-conformance-fixture.schema.json` enforces the block;
  CI validates every fixture against it. Bundle and multi-hop fixtures
  are tagged `status: "draft"`; v0.1 core fixtures are tagged
  `status: "core"`. New fixture `del-004-multihop-rejected-v01` proves
  v0.1 implementations reject any non-empty `chain` field with
  `DELEGATION_MULTIHOP_NOT_SUPPORTED`.
- **Error-code registry.** Added `TCT_EXPIRES_AFTER_MANIFEST` and
  `INCOMPATIBLE_IDENTITY_TYPE`. Every table now carries a `spec_status`
  column (`core` or `draft`).
- **New registry.** `registries/extension-keys.md` pins the four
  AITP-defined Manifest extension keys (`verify_uri`, `renew_uri`,
  `delegation_verify_uri`, `revocation_list_uri`) so independent
  implementations don't fork the strings.
- **RFC process.** Strengthened the KAT requirement to mandate hex
  preimage bytes (the decode-before-hash convention is non-obvious from
  text alone — has caused two interop bugs); explicit non-merge gate for
  PRs introducing new signing inputs without KAT vectors.
- **Operational guidance.** New "Shortened renewal (experimental)"
  section in `docs/operational-guidance.md` documenting when to enable
  the opt-in extension, the discovery key, the 24h/8-renewal full-bind
  ceiling, and the failure-mode fallback to full handshake.

---

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
