# DECISIONS

Repo-wide decision log. Entries are dated and append-only; a superseded decision
is marked so in place (see the version-bump entry below) rather than deleted, so
the log stays a record of what was decided and when, not just what is currently
true.

> **Relocated 2026-09-19 (issue #48).** This file lived at the repo root, excluded
> from git via `.git/info/exclude`, so no clone but the one that wrote it could ever
> see it — including the entry directly below, which chose to keep the errata record
> local for exactly the reason this relocation now reverses. It is tracked here
> going forward; new decisions should be appended to this file, not to a
> `.git/info/exclude`d one. The title above was `DECISIONS —
> w-p5-signing-input-divergence`, reflecting the single plan that originated the
> file; it has carried unrelated entries since 2026-08-29 and is retitled here to
> match what it already is.

## Errata record stays in `plans/` (untracked), RFCs + CHANGELOG carry the published record

- **Plan:** W-P5 signing-input divergence plan, Phase 1 (local planning notes, not tracked)
- **Date:** 2026-08-24
- **Decided by:** user, asked at the Phase 1 boundary
- **Context:** `plans/` is gitignored (`.gitignore:95`) and excluded from the release
  archive (`Makefile:release`, asserted by `.github/workflows/ci.yml`). The repo has no
  tracked errata document anywhere. So the Phase 1 errata edits — including the
  retraction of the false interop claim — cannot appear in the PR.
- **Options offered:** (a) publish a tracked `governance/ERRATA.md`; (b) un-ignore just
  the one errata file; (c) leave it local.
- **Chosen:** (c). The normative corrections land in the RFCs (Phase 2) and the
  digest delta lands in `CHANGELOG.md` (Phase 5); the errata file remains working
  analysis whose only readers are local.
- **Consequence, stated plainly:** the PR contains no errata document. Anyone reading
  the PR sees the RFC prose changes, the regenerated vectors, the CI checker and the
  CHANGELOG entry, but not the evidence tables behind them. Phase 5's CHANGELOG entry
  therefore has to carry enough of the "why" to stand alone.
- **Superseded 2026-09-19 (issue #48):** option (a) was taken after all, a month
  later, once the errata record had gone stale in a way its own invisibility hid.
  See `governance/spec-errata-from-independent-verifier-2026-07.md`'s relocation note.

## ~~No version bump~~ → REVERSED by the user: patch bump taken

**Superseded 2026-08-24.** The user directed that the version be bumped. Recorded
below is the original reasoning for taking none; what shipped is a patch bump of
the four RFCs whose text moved (`0.2.0-draft` → `0.2.1-draft`), with the protocol
literal and schema namespace deliberately unchanged. See CHANGELOG.md "Version
bump". Original entry:

### (superseded) No version bump, despite the vector Stability rule
- **Plan:** W-P5 signing-input divergence plan, Phase 4, open question 1 (local planning notes, not tracked)
- **Decided by:** me, under the plan's "clearly-best default" rule — **needs your sign-off**
- **The rule:** "an existing vector's output MUST NOT change without an RFC bump."
  This PR changes three.
- **Chosen:** no bump. v0.2 is still `draft`; RFC-AITP-0008 §1.5 already specified this
  exact migration ("MUST emit the inner form going forward"), so the vectors are being
  brought into line with a requirement that already shipped rather than having their
  contract changed under them; and the old and new values are published in CHANGELOG.md
  so a digest-pinning consumer can identify and update deterministically.
- **Rejected:** keeping the digests and amending three RFCs to bless the wrapper. That
  would contradict RFC-AITP-0003 §6.1 and both implementations' Manifest behaviour, and
  would require re-minting the *correct* Manifest signed example to match a wrong vector.
- **Blast radius if wrong:** low and reversible — adding a bump later is additive. But it
  is a governance call on a published spec, so it is yours to confirm.

## `signing_input` vocabulary is the two-value enum `body` / `envelope`
- **Plan:** W-P5 signing-input divergence plan, Phase 3, open question 2 (local planning notes, not tracked)
- **Chosen:** the smallest thing that answers the question the file must answer.
  `envelope` is retained as a *rejected* value so the erratum stays legible in history.
- **Alternative rejected:** naming the artifact (`revocation_list.body`), which encodes
  the artifact twice — the vector id already says which artifact it is.
- **Blast radius if wrong:** trivial; it is new metadata with one consumer
  (`scripts/verify-known-answer.mjs`) inside this repo.

---

## 2026-08-29 — docs/tests/integration-test follow-through for PR #22 and PR #30

Three assumptions logged during the docs/tests follow-through plan (local planning notes, not tracked) were
reconciled at the end of the run. None was a one-way door: all are editorial, none changes a wire
format, a schema namespace, or a pinned cryptographic value.

### A-DT-1 — Issue #27 shipped inside this plan · CONFIRMED

**Decision:** the `extensions` field-table omission in RFC-AITP-0004's four handshake payloads and
RFC-AITP-0008 §1.5 was fixed here (Phase 10, commit `94a13f9`) rather than deferred to its own change.

**Reasoning:** verified in all five places before deciding — the schemas define `extensions`
(`aitp-mutual-handshake.schema.json:101-104`, `:141-144`, `:172-175`, `:203-206`;
`aitp-revocation-list.schema.json:60-63`) and all five RFC tables omitted it. This is the identical
defect PR #30 fixed in RFC-AITP-0010 §3. Fixing the sixth instance while leaving five open is the
mechanism by which a defect class survives: the next person to meet one of the five has no way to
know it was already understood and fixed elsewhere.

Executing it also surfaced an error in the plan: RFC-AITP-0004's payloads are covered by the
signature *indirectly*, via `hex(sha256(payload_canonical_json))` inside the envelope signing input,
not as direct members of a signed body. Reusing RFC-0010's justification — as the plan instructed —
would have put a true conclusion on false reasoning, in the change whose subject is reasoning
correctly about what gets signed. Deferring the phase would have left that error undiscovered.

**Reversal:** drop commit `94a13f9`; nothing depends on it.

### A-DT-2 — One closing PR, not per-phase PRs · CONFIRMED (by instruction)

**Decision:** all 11 phases accumulate into a single PR.

**Reasoning:** the request said "create a Pr and Merge it" — singular. The plan's own Open Question
2 had recommended two PRs, splitting normative/editorial from tooling; the explicit instruction
overrides that recommendation. Recorded because the recommendation and the instruction disagreed,
and the disagreement should be visible rather than silently resolved.

**Reversal:** low cost before merge (split at the Phase 6/7 boundary), higher after.

### A-DT-3 — `signed-examples/session-bundle/` deferred · CONFIRMED

**Decision:** not added; filed as issue #32.

**Reasoning:** the session bundle is the only JCS-profile artifact with no verify-as-committed
signed example, and it is the artifact whose placement was wrong in the schema through a full
release — so the gap is worth naming. But closing it means minting and pinning new cryptographic
material, which is a different risk class from every other change in this branch (all editorial,
patch-level, no new signatures). It deserves its own review rather than riding along in a docs pass.

**Reversal:** none needed; purely additive later.

### Also filed rather than fixed

- **#31** — `README.md` is still a v0.1 document end to end. A patch correcting its compatibility
  model to v0.2 was written and then **reverted**: it was factually right, but would have left the
  only two v0.2 statements in the file under a v0.1 masthead. Half-migrating a document is the
  defect this branch spent eleven commits fixing, not a fix for it. Whether the README tracks the
  last release or the working state is the maintainer's call, not a patch.
- **#33** — `validate-json.sh`'s companion audit reads only the `/input` subtree (`:207`) and
  recognizes only `_claims` companions (`:190`). PR #30 named the second half; the first is newly found here and
  latent. Both are pipeline logic, not docs or test cases.

---

## 2026-09-19 — DECISIONS.md and the W-P5 errata record become tracked (issue #48)

- **Decided by:** me, under issue #48's own suggested fix (unambiguous — the issue names the
  defect and the two-part remedy; nothing here is a judgment call).
- **Chosen:** this file moves from the repo root (`.git/info/exclude`d) to
  `governance/DECISIONS.md` (tracked); `plans/spec-errata-from-independent-verifier-2026-07.md`
  (gitignored via `plans/`) moves to `governance/spec-errata-from-independent-verifier-2026-07.md`
  (tracked), filename unchanged for stable inbound references, and is re-statused against the
  current trees rather than left asserting a pre-fix world that no longer exists.
- **Not done:** a blanket un-gitignoring of `plans/`. That directory holds in-flight working
  analysis (open questions, rejected alternatives, per-phase scratch) that is useful locally and
  would be noise as permanent repo history; issue #48 itself frames the fix as moving the two
  specific tracked-worthy documents out, not un-gitignoring the tree. If a future `plans/*.md`
  earns the same treatment, move it the same way rather than reopening this question.
- **Blast radius if wrong:** low. Nothing depends on either file's path; both are read by humans
  cross-referencing decisions, not by any script in `scripts/` or by CI.

---

## 2026-09-19 — Do not spec `aitp-rs`'s DPoP / OAuth token-exchange surface yet (issue #49)

- **Decided by:** me, applying the recommendation issue #49 already argued for on
  verified facts; this entry supplies the tracked home the issue said was missing,
  and records the decision itself.
- **Context:** `aitp-rs` ships two OAuth/OIDC-adjacent implementations that no AITP
  RFC specifies — DPoP (RFC 9449, `crates/aitp-transport-http/src/dpop.rs`, ~854
  lines) and OAuth 2.0 Token Exchange (RFC 8693, `src/token_exchange.rs`, ~513
  lines). Re-verified 2026-09-19: this repo still has exactly the two incidental,
  non-normative hits issue #49 found — `RFC-AITP-0002-identity.md:81` (a
  parenthetical citing RFC 9449 §6 to describe the *static* `cnf.jkt` binding,
  which is not DPoP) and `:299` (a bibliography entry). Zero occurrences of `8693`
  or "token exchange" anywhere in this repo. No conformance fixtures, no
  RFC-AITP-0009 threat-model entry, no prior issue or PR on the subject.
- **Chosen:** do not write an RFC for this surface now. No normative text, no
  fixtures, no threat-model entry — the decision itself, not a spec, is the
  deliverable. Explicitly rejected: a "descriptive" RFC that documents current
  `aitp-rs` behavior without normative requirements. Issue #49's own framing is
  exactly right on why — a document with the authority of a spec and the content
  of a comment is the same failure mode that let the revocation signing-input
  divergence (errata 3, above) go unnoticed for a full release: prose that reads
  as settled but isn't actually checked against anything.
- **Reasoning:** the surface is (a) unconsumed — `seam-runtime`, the only known
  consumer, does not depend on `aitp-transport-http` at all; (b) unspecified —
  covered by no RFC, fixture, or threat model; (c) security-relevant — DPoP and
  token exchange both sit in the authentication path; and (d) the maintenance
  budget is one person. Specifying it now means fixturing and threat-modeling two
  IETF protocols' interaction with AITP for no current caller.
- **Reversal trigger, stated up front so this isn't re-litigated from nothing:** a
  real consumer. If an adopter needs OIDC/DPoP, the surface comes back *with* an
  RFC at that point — normative text, conformance fixtures, and an
  RFC-AITP-0009 threat-model entry, not a retroactive description of whatever
  `aitp-rs` happened to ship.
- **Not this repo's decision alone:** the `aitp-rs` side of this — a note in that
  repo stating the surface is unspecified and unsupported by the AITP spec — is
  tracked there as `aitp-rs`#151 (open as of this writing). This entry is the
  spec-repo half; #151 is the implementation-repo half. Neither supersedes the
  other.
- **Blast radius if wrong:** low and reversible. Nothing is removed from
  `aitp-rs` — its DPoP/token-exchange code keeps working for whoever already
  uses it. The only cost of waiting is that an adopter who needs it today has to
  ask for the RFC rather than finding one already written; the cost of writing
  one now, unused, is a maintenance surface (two IETF RFCs' worth of interaction
  semantics) with no one to tell if it's wrong.

## 2026-10-08 — docs-refresh-v0.2 reconcile (decided by Opus; all reversible)

- **v0.1 allow-list by in-line wording, not HTML comments.** docs/ is synced to MDX where `<!-- -->` breaks the build. Confirmed: `legacy` / `v0.1-frozen` / `v0.1 line` mark a mention as historical (scripts/check-doc-coherence.sh stage 7). Reversible in one regex.
- **CODE_OF_CONDUCT contact is an interim.** No address exists and GitHub private reporting is disabled; the doc asks for a no-details contact-request issue and invents nothing. Confirmed as interim; a real address is the maintainer's to supply.
- **README conformance profile names removed.** `aitp-a2a-peer` / `aitp-session-participant` / `aitp-full` were defined in no RFC; conformance is selected by fixture `feature` flags (RFC-AITP-0001 §10). Confirmed. Defining profiles would need the RFC process.

---

## 2026-10-24 — Revocation snapshots are per issuer; no third-party revocation authority in `aitp/0.3` (aitp-control-plane#153)

- **Decided by:** the owner (OQ-6, 2026-10-24), taking the plan's recommended default.
- **Context:** aitp-control-plane#153. The control plane signs one revocation list with its
  own AID, but it issues no TCTs; the entries are for tokens other agents issued. RFC-AITP-0008
  §1.5 (`rfcs/RFC-AITP-0008-revocation.md:112`, the **Verification** paragraph) requires a
  verifier to discard a snapshot "if its signed `issuer` is not the issuing peer whose token is
  being checked", and the §1.5 `issuer` row says the `issuer` MUST equal the `iss` of every TCT
  the entries cover. A conformant verifier therefore discards the control plane's list for every
  token and falls through to `revocation_policy.mode`. Under `fail_open` an operator's revocation
  is silently ignored; under `fail_closed` every token is rejected.
- **Options:**
  1. Keep §1.5 as written: a snapshot is valid only for tokens its signer issued. Central
     management becomes a relay, and each issuer signs its own list.
  2. Add a delegated "revocation authority", named in the issuer Manifest or in the verifier's
     trust anchors, whose list may cover other issuers' tokens.
  3. Leave the question to the control plane's own docs.
- **Chosen:** option 1. RFC-AITP-0008 §1.5 is unchanged. A snapshot is per issuer, and
  `aitp/0.3` has no third-party revocation authority. RFC-AITP-0008 (0.3.2-draft) gains an
  informative note saying so, and `docs/operational-guidance.md`
  [Centralised revocation management](../docs/operational-guidance.md#centralised-revocation-management)
  describes the relay pattern: the registry records intent with the token's `iss`, relays each
  entry to its issuer, and each issuer signs and serves its own `ListRevoked`.
- **Pinned by:** the new core fixture `rev-011-third-party-signed-list-discarded`. The committed
  kat-keypair-001 TCT is checked against the committed kat-keypair-005-p256 snapshot, which is
  fresh and correctly signed by its own (third-party) issuer and does not list the token. Under
  `fail_closed` the expected outcome is `TCT_REVOKED`. No earlier fixture covered another
  issuer's snapshot: `tct-022` and `del-mh-006` discard a snapshot for a bad signature, and
  `rev-001` for staleness.
- **Reasoning:** the issuer rule is what stops a compromised third party from un-revoking or
  mass-revoking tokens it never issued. Option 2 is a new wire feature and a new trust root. It
  needs an RFC, fixtures and an RFC-AITP-0009 threat-model entry, and it would land days before
  the freeze. Option 3 is already failing: the control plane's `docs/api.md` tells relying
  parties to pin the control plane's AID as the expected issuer, which is the non-conformant
  arrangement #153 reports.
- **Consequences:** an agent that issues TCTs but publishes no list has no revocation source, and
  under the default `fail_closed` its TCTs are rejected (RFC-AITP-0008 §1.4, fixture `tct-024`).
  The guidance says so plainly. Replicas of one issuer must sign with the same key and serve the
  same entry set. The control plane's audit trail stays a record of intent, not an authority.
  The control-plane side (relay, record `iss`, fix `docs/api.md`) is that repository's work.
- **Reversal trigger:** a real deployment that cannot have each issuer publish its own list. A
  delegated revocation authority then comes back as an opt-in extension RFC after the freeze,
  with normative text, fixtures and a threat-model entry. It is a post-1.0 candidate, not a
  change to §1.5.
- **Blast radius if wrong:** low before the freeze, because nobody uses the protocol yet. After
  the freeze the per-issuer rule is part of the frozen surface, and only an additive opt-in
  extension can relax it.

---

## 2026-10-24 — No Core Team yet: the maintainer shepherds, and every stage gate waits 30 days in public (S2.2, OQ-8)

- **Decided by:** the owner (OQ-8, 2026-10-24), taking the plan's recommended default.
- **Context:** RFC-PROCESS.md assigns a Core Team shepherd at Review and a Core Team vote at
  FCP. No Core Team is seated. `CHARTER.md` § Core Team lets the maintainer act in its place for
  editorial and registry matters, and says substantive RFCs SHOULD wait for a seated Core Team
  or a public review of at least 30 days. RFC-AITP-0001 to RFC-AITP-0009 are about to enter
  Review (adoption plan S2.3).
- **Options:**
  1. Seat a Core Team now and track it in `governance/CORE-TEAM.md`. Nobody other than the owner
     has consented, and a roster of the owner alone meets the letter of the charter, not its point.
  2. Invoke the charter's substitute: a public review of at least 30 days at every stage gate.
  3. Wait to start review until a Core Team exists.
- **Chosen:** option 2.
  - The maintainer is the shepherd for every RFC.
  - An RFC leaves Review, Release Candidate or FCP only after a public review of at least 30
    days at that stage. This replaces the 14-day Review minimum and FCP's 7-day window.
  - Each window is announced in a pinned Discussions thread on this repository with its open and
    close dates. Comments go there or on the RFC's pull request.
  - The first window, the Review of RFC-AITP-0001 to RFC-AITP-0009, closes no earlier than
    2027-01-10, because 30 days from its opening would fall in the December holidays.
  - Goal: two consenting Core Team members other than the owner, seated by 2027-03-31 and before
    any of RFC-AITP-0001 to RFC-AITP-0009 enters FCP. Seats follow `CHARTER.md` § Joining the
    Core Team. Agents, bots and people who have not consented are never listed.
  - A Core Team seated during a window takes over the decision at that gate, but the roster PR
    does not restart the window.
  - No `governance/CORE-TEAM.md` exists until there is someone to list.
- **Reasoning:** an honest substitute beats a roster of one. The charter already names the 30-day
  review as the alternative, so this uses it rather than inventing a rule. Option 3 stalls the
  whole plan on recruiting, which the review itself is meant to help.
- **Consequences:** every promotion takes at least 30 days, so the `aitp/0.3` core cannot reach
  Accepted before roughly three windows have closed. Reviewers have one place to comment.
  `RFC-PROCESS.md` (Review stage) and `CONTRIBUTING.md` (Review windows) state the rule.
- **Reversal trigger:** two consenting non-owner members are seated. `CORE-TEAM.md` is then
  created and the Core Team shepherds and votes as the process says. If 2027-03-31 passes without
  them, the owner records a new decision here before any core RFC enters FCP.
- **Blast radius if wrong:** low. The rule only slows promotions down, and it changes no RFC text.

---

## 2026-10-24 — State the intent to move AITP to a neutral foundation; apply to LF AAIF later (OQ-1)

- **Decided by:** the owner (OQ-1, 2026-10-24), taking the plan's recommended default.
- **Context:** the project lead holds the AITP name, the `agentidentitytrustprotocol.io` domain
  (registered to zer07labs, paid until 2028-06-19) and the GitHub organization. Implementers
  weigh whether a single company can take the protocol back. The charter said nothing about it.
- **Options:**
  1. State the intent to transfer to a neutral foundation now, and apply when there is evidence
     of a community.
  2. Apply to the Linux Foundation's Agentic AI Foundation (AAIF) now. A one-person project is
     likely to be turned down.
  3. Stay owner-held with no stated intent. This caps adoption.
- **Chosen:** option 1. `CHARTER.md` gains "Neutral home": who holds what, and the intent to
  transfer the name, domains and GitHub organization to a neutral foundation. The project
  applies to LF AAIF once it has at least one external contributor (a person other than the
  project lead with a merged pull request in an AITP repository) and at least one implementation
  the project lead does not maintain. The section is a charter amendment. With no Core Team
  seated, the maintainer makes it under the interim authority of `CHARTER.md` § Core Team, and
  it is announced in the CHANGELOG as § Amendments requires.
- **Reasoning:** a public statement costs nothing and answers the implementer's question now. An
  application without contributors or a second implementation would be judged on evidence that
  does not exist yet.
- **Consequences:** the domain renewal stays the project lead's job until transfer. Both
  conditions are visible facts (merged PRs, the conformance matrix), so anyone can check when the
  application is due.
- **Reversal trigger:** LF AAIF declines the application, or stops taking protocol projects. The
  project then names another neutral foundation in `CHARTER.md`. The intent to transfer is not
  withdrawn.
- **Blast radius if wrong:** low. It is a statement of intent; nothing moves until the
  conditions are met.

---

## 2026-10-24 — Conformance report format and per-claim badge rules (S3.1)

- **Decided by:** Opus, implementing S3.1 of the 90-day adoption plan. The plan fixed the field list, per-claim badges, `excluded_by_role` and unsigned reports. It left the choices below open, and every consumer (aitp-rs, aitp-verifier-py, aitp-website) will build on them, so each is recorded with a reversal trigger.
- **Context:** `aitp-conformance --output json` emits a bare array and the gate result goes only to stderr. No two runners share an output format, so no matrix can compare them. The new `schemas/json/aitp-conformance-report.schema.json` (`$id` `https://agentidentitytrustprotocol.io/schema/v0.3/conformance-report.json`) and `docs/conformance-badge.md` define one format. The report is not a wire artifact.
- **Chosen:**
  1. **Fixture digest = SHA-256 of a `sha256sum` listing.** `fixtures_dir_digest` is `sha256:` plus the SHA-256 of the `sha256sum`-format listing (file hash, two spaces, name, newline) of the top-level `*.json` files in `schemas/conformance/`, sorted by name in byte order. The plan said "sha256 over sorted fixture file bytes". Plain concatenation has no file boundaries and ignores names, so a rename or a byte moved between two files would not change it. The listing form can be reproduced with `sha256sum` alone. *Reversal trigger:* a consumer cannot compute it portably, or the fixture set moves into subdirectories. Either takes `report_version` "2".
  2. **`gates[]`, one per claim, not one `gate{}`.** The plan listed `gate{name,passed,criteria}` but also made badges per claim. One object cannot carry three claims, so `gates` is an array. `name` is restricted to the three RFC-AITP-0001 §10 claim strings and `criteria` to `core-required-all-pass` / `feature-all-pass`. *Reversal trigger:* an RFC adds a claim; the enum grows with it.
  3. **The core claim gates on `required_for_core`, not on every `status: core` fixture.** `del-004` is core but frozen in the v0.1 shape (`required_for_core: false`), and no `aitp/0.3` runner is required to pass it. Results copy `required_for_core` for this reason. *Reversal trigger:* the core-tier key is renamed or `del-004` is removed. The rule then follows the new key.
  4. **Four outcomes: `pass`, `fail`, `skip`, `excluded_by_role`.** There is no separate "feature-negated" outcome. A core assertion that an enabled draft feature negates (`del-007` under `experimental-multihop-delegation`) is a `skip`, and it blocks the core claim for that run. aitp-rs's exit-code gate exempts such skips, but a badge has to make a claim about the core behaviour itself, so the core claim is run without draft features. *Reversal trigger:* a draft RFC is promoted into the core and its negated fixtures are retired, or an implementation cannot turn a draft feature off.
  5. **Shapes.** `report_version` is the string `"1"`, the same convention as the adapter `init` version. `generated_at` is an RFC 3339 UTC string, not Unix seconds as wire artifacts use, because the badge shows a date. `reserved` fixtures never appear in `results`, and `spec.protocol` is fixed to `aitp/0.3`. (The plan listed a `v0.1` status, but the fixture schema has `reserved` and no `v0.1`.) *Reversal trigger:* any breaking change to the shape takes `report_version` "2", with no dual-accept period (no users).
  6. **Report version 1 carries fixture results only.** The core claim attests item 9 of RFC-AITP-0001 §10. The known-answer vectors (item 8) are not in the report. *Reversal trigger:* a runner reports known-answer results. They are then added as an optional field, which does not break version 1.
- **Enforcement:** the schema rejects a gate that passed over a blocking result, along with a missing `spec.commit`. `scripts/check-conformance-report.py` recomputes the totals and gates, and with `--fixtures-dir` it also checks the digest and fixture coverage. `make validate` checks the sample reports in `schemas/conformance/reports/` against `scripts/report-validation-map.json`, in both directions.
- **Blast radius if wrong:** low to medium. No wire byte or fixture changes. A format change costs one bump PR in each emitter (aitp-rs RS3.1, aitp-verifier-py VP3.1) and in the matrix generator (aitp-website WEB3.1).

---

## 2026-10-24 — Freeze the `aitp/0.3` wire until 1.0, with a security-fix exception only (S2.1)

- **Decided by:** the owner, taking the adoption plan's S2.1 approach. Opus drafted the text and
  settled the two points the plan left open (the prose/artifact direction and the
  `required_for_v0_2` rename), both recorded below.
- **Context:** before this entry the pre-1.0 policy allowed any protocol revision with a strict
  cutover, so no adopter could rely on today's wire staying valid. RFC-AITP-0001 to
  RFC-AITP-0009 are about to enter Review (S2.3), and a Review stage limits nothing about wire
  changes on its own.
- **Options:**
  1. No changes at all to RFC-AITP-0001 to RFC-AITP-0009. This blocks additive identity types
     and opt-in extension RFCs, which change no existing outcome.
  2. Freeze the wire with no exception. Nobody believes a promise that leaves a security defect
     unfixed.
  3. Freeze the wire, allow additive and opt-in work, and except disclosed security fixes.
- **Chosen:** option 3. [`VERSIONING.md` § What is frozen](../VERSIONING.md#what-is-frozen-aitp03-line)
  lists what is frozen (signing inputs, message and field sets outside `extensions`, error codes
  and their meanings, the `aitp/0.3` literal, the known-answer set with additions only, and the
  schema validation outcome of every existing artifact) and what stays allowed (additive identity
  types, opt-in extension RFCs, clarifications, new fixtures and vectors, schema refactors that
  leave every existing fixture's outcome unchanged, and security fixes under `SECURITY.md` with a
  strict cutover). Two points the plan did not settle:
  - **Prose against pinned artifact.** A contradiction is settled toward the pinned bytes, with
    an erratum note in the prose. Changing a pinned output is a wire change and is taken only as
    a security fix.
  - **`required_for_v0_2`.** Fixture metadata key names are frozen, with this key listed as the
    one pending rename, to a name with no version label, made together with the aitp-rs and
    aitp-verifier-py runners and the conformance report schema. A general "renames are allowed
    before 1.0" rule was rejected, because it would leave every key open. *Done 2026-10-24:*
    renamed to `required_for_core`, with no alias; see the entry below.
- **Who classifies:** the maintainer, acting as shepherd under the `CHARTER.md` § Core Team
  substitute (the S2.2 entry above), decides whether an erratum or a review comment is a
  clarification or a wire change, and whether a wire change is a security fix. Once a Core Team
  is seated, it decides. Each classification is recorded with the change (for the first review
  window, in its disposition record).
- **Reasoning:** freezing the wire and not the prose keeps the review useful: reviewers can
  still get the text fixed, and implementers know the bytes will not move. The exception is
  limited to what `SECURITY.md` already handles, so it does not become a general escape hatch.
- **Consequences:** a non-security wire change found during review is deferred to 1.0 and
  recorded as deferred. "New optional fields" outside `extensions` are no longer a
  backward-compatible addition on this line. The fixture key rename, if taken, costs one
  coordinated change across the spec and both runners.
- **Reversal trigger:** a security fix only. A disclosed defect that cannot be fixed without a
  wire change ships under `SECURITY.md` as a new `aitp/0.3.x` tag with an advisory and a strict
  cutover, and the freeze otherwise stands. Nothing else lifts it before 1.0. A dual-accept
  window for such a fix is reconsidered only once real deployments exist.
- **Blast radius if wrong:** medium. The freeze binds the project, not code: if it proves too
  tight, the cost is wire changes waiting for 1.0, not broken implementations.

## 2026-10-24 — Rename the fixture core-tier key to `required_for_core`

- **Decided by:** Opus, under the S2.1 freeze text that listed this rename as pending.
- **Context:** `required_for_v0_2` marked the `aitp/0.3` core tier under a stale version label.
  Key names freeze with the line, so a label-free name had to land before external runners exist.
- **Chosen:** `required_for_core`, a boolean with unchanged values. There is no alias, because
  there are no users; aitp-rs and aitp-verifier-py change their runners in the same window.
  `required_for_v0_1` (true only on `del-004`) is left as is: it records history, not a live tier.
- **Rejected:** `required_for_v0_3`, which would go stale again at 0.4. `core: true` collides
  with `status: core`, which `del-004` carries while being outside the tier.
- **Reversal trigger:** none on this line; key names are frozen.


## 2026-10-24 — RFC-AITP-0014: AITP as an A2A Agent Card security scheme (S5.1)

- **Decided by:** Opus, implementing S5.1 under the owner's OQ-2 decision (an A2A Agent Card
  security scheme plus a Manifest binding, riding on A2A rather than a standalone protocol).
- **Context:** A2A 1.0.0 (release tag `v1.0.1`, protobuf package `lf.a2a.v1`) has a closed
  `SecurityScheme` oneof (API key, HTTP auth, OAuth 2.0, OpenID Connect, mTLS) and no custom
  scheme type. Its extension mechanism (`capabilities.extensions[]`, activated by the
  `A2A-Extensions` header) carries parameters but cannot add fields to core A2A objects. The
  `aitp/0.3` wire is frozen (S2.1), so the binding has to be opt-in and change nothing in
  RFC-AITP-0001 to RFC-AITP-0009. RFC-AITP-0014 enters at Draft.
- **Chosen:**
  1. **Extension URI `https://agentidentitytrustprotocol.io/ext/a2a/v1`.** A breaking change
     takes a new URI (A2A section 4.6.3), even while the RFC is Draft. One-way door once a
     third party publishes Cards with it. *Reversal trigger:* the project domain changes, or A2A
     defines a registry of extension URIs that requires another form; either means `…/v2` or a
     new URI, with no alias.
  2. **The TCT rides in an `apiKeySecurityScheme` with `location: "header"` and
     `name: "x-aitp-tct"`, not an HTTP `Bearer` scheme.** `Bearer` would take the
     `Authorization` header that A2A deployments use for the user's OAuth token, so AITP could
     not be required together with OAuth, and it would label a key-bound token as a bearer
     token. This makes the `x-aitp-tct` convention normative for the A2A binding only.
     *Reversal trigger:* A2A adds a custom or extensible scheme type; AITP then moves to it under
     a new extension URI.
  3. **Extension `params` use A2A's camelCase (`aid`, `manifestUrl`, `securityScheme`,
     `acceptedIdentityTypes`).** They are A2A extension parameters, not AITP wire members, so
     the AITP snake_case rule does not apply. *Reversal trigger:* none expected; renaming takes a
     new URI.
  4. **The Manifest extension key `rfc-aitp-0014.a2a_interfaces` (registered Proposed): an
     array of the exact A2A interface URLs, inside the signed Manifest.** It is the
     card-shadowing defense, and it uses `extensions`, so the frozen Manifest field set is
     untouched. *Reversal trigger:* review shows exact-URL matching is unworkable for real
     deployments (for example many tenants on one host); a prefix or origin rule would then be a
     new key, not a change to this one.
  5. **No new AITP error code.** A Card/Manifest mismatch or a malformed binding is
     `IDENTITY_FAILED`; an unreachable Manifest is `MANIFEST_NOT_FOUND`; server-side failures
     reuse the RFC-AITP-0005 codes inside A2A's 401/403 error classes. The error-code registry is
     frozen. *Reversal trigger:* implementers report that `IDENTITY_FAILED` cannot be told apart
     from handshake identity failures in practice; a new code would then wait for 1.0.
  6. **The A2A server verifies the TCT it receives as its issuer.** The TCT the client holds has
     `iss` = the server and `aud` = `sub` = the client, so RFC-AITP-0005 §5.2's "`aud` matches
     its own AID" cannot be read literally by the server. RFC-AITP-0014 §5.2 states the
     issuer-side reading: `iss` is the server's own AID, `aud` = `sub` names the presenter, and
     possession of the `sub` key is proven by downstream PoP or channel binding. This is an
     interpretation, not a wire change, and matches what the playground already does
     (`verify_capability_tct`). **Resolved by issue #120 (2026-10-24):** the rule moved into
     RFC-AITP-0005 as §10.5, "Issuer as resource server", which covers every transport, and
     RFC-AITP-0014 §5.2 now cites it instead of restating it. See the entry "RFC-AITP-0005 §10.5:
     the issuer-side TCT check" below.
  7. **An A2A Card signature is neither necessary nor sufficient.** A2A does not say whose key
     signs a Card; the Manifest's key is the AID. *Reversal trigger:* A2A binds the card-signing
     key to an agent identity the client can check against the AID.
- **Rejected:** a standalone AITP discovery protocol for A2A (a third trust root), a
  documentation-only mapping (leaves shadowing and tampering open), `mtlsSecurityScheme` as the
  carriage (AITP identity is the AID key, not a certificate chain), and a JSON Schema for the
  Agent Card (A2A owns that object).
- **Blast radius if wrong:** low. The RFC is an opt-in Draft and no core fixture or wire
  artifact depends on it. The costly items are 1 and 4 once external Cards and Manifests use
  them; both are reversed by a new URI or key, not by editing the old ones.

## 2026-10-24 — `spiffe` is a new identity type at Proposed; `x509` stays Web PKI (S5.2, OQ-7)

- **Status:** UNCONFIRMED (owner to confirm). Taken as the plan's default for OQ-7.
- **Decided by:** Opus, implementing adoption-plan S5.2.
- **Context:** SPIFFE workload identities (SVIDs) are the identity layer of most service-mesh and
  SPIRE deployments. RFC-AITP-0002 §5 reserved `x509` for an X.509 chain without saying which PKI.
- **Options:**
  1. A new `spiffe` row with `svid_type` `jwt-svid` | `x509-svid`; `x509` stays reserved for Web PKI.
  2. Define `x509` now and treat an X509-SVID as one profile of it.
  3. Two rows, `jwt-svid` and `x509-svid`.
- **Chosen:** option 1, at registry status **Proposed**, with draft fixtures under
  `feature: experimental-spiffe-identity` and `required_for_core: false`.
- **Reasoning:**
  - SPIFFE trust is per trust domain and comes from a bundle, not from a Web PKI root store. Folding
    it into `x509` would mix two trust models under one name.
  - One row keeps the trust-domain and bundle rules in one place for both SVID forms.
  - Proposed keeps the type out of every RFC-AITP-0001 §10 claim until an implementation exists.
- **Reversal trigger:** the owner prefers option 2 or 3, or a second implementer finds that the
  `svid_type` split does not fit. Since there are no users, the reversal renames the row and the
  fixtures with no alias.
- **Blast radius if wrong:** low. The type is opt-in, draft and not in any claim.

## 2026-10-24 — SPIFFE binding rules: the tightenings over the SPIFFE standards (S5.2)

- **Status:** UNCONFIRMED (owner to confirm), together with OQ-7 above.
- **Decided by:** Opus, implementing S5.2. The sources are the `spiffe/spiffe` standards at commit
  `49a9cbbc018c39ec6643ad3301632f9f4549258b`, re-read for this change.
- **Chosen**, each marked **Tightening** in RFC-AITP-0002 §6:
  - **JWT-SVID `nonce` and `cnf.jkt` are required**, as for OIDC. A bare JWT-SVID is a bearer token
    (JWT-SVID §7.1). The cost: the Workload API's `JWTSVIDRequest` carries only `audience` and
    `spiffe_id`, so stock SPIRE cannot mint these claims, and `jwt-svid` needs a custom issuer or
    plugin. Rejected alternative: encode the binding in the audience value (for example
    `aud = <verifier AID>#<nonce>`). That works with stock SPIRE but overloads `aud` and does not
    bind the AID key.
  - **JWT-SVID `aud` holds exactly one value**, the verifier AID (JWT-SVID §3.2 allows several and
    §7.2 warns against it).
  - **JWT-SVID `kid` is required** (JWT-SVID §2.2 makes it optional; §6.1 requires it on every
    bundle JWK), so key selection is exact and no verifier tries keys in turn.
  - **The X509-SVID leaf key MAY differ from the AID key.** Stock SPIRE generates the SVID key, so
    requiring them to be equal would rule out stock SVIDs. The binding is the leaf-key proof over a
    domain-separated input that covers the sender AID, together with the AID-key envelope
    signature that covers `x5c` and `proof`.
  - **The X509-SVID leaf key is Ed25519 or P-256 only**, the RFC-AITP-0001 §5.4.6 primitive. RSA
    and P-384 leaves are rejected.
  - **`subject` must be in canonical form** (lowercase scheme and trust domain) and is compared
    byte for byte.
  - **No revocation**, as in SPIFFE: SVIDs are short-lived.
  - **No new error codes:** `IDENTITY_FAILED` and `INCOMPATIBLE_IDENTITY_TYPE` cover every failure.
- **Reversal trigger:** an implementer shows that a tightening blocks a real SPIRE deployment. The
  first candidate is the JWT-SVID `nonce`/`cnf`, where the alternative is the audience-encoded
  binding above. Any reversal ships with new fixtures before the type leaves Proposed.
- **Blast radius if wrong:** low. Draft fixtures only, no claim depends on them.

## 2026-10-24 — RFC-AITP-0005 §10.5: the issuer-side TCT check (issue #120)

- **Status:** UNCONFIRMED (owner to confirm). RFC-AITP-0005 is in Review, so public review can
  still change the text.
- **Decided by:** Opus, resolving issue #120.
- **Context:** A TCT is usually consumed by the peer that issued it: the subject presents it back
  to the issuer to invoke a capability. RFC-AITP-0005 §5.2 and §7.2 step 5 said only "`aud` == own
  AID", which the issuer cannot meet, because `aud` names the subject. RFC-AITP-0014 §5.2 stated an
  issuer-side reading for A2A only (S5.1 decision 6), and `docs/mcp-mapping.md` pointed MCP at it
  as text under review.
- **Options:**
  1. Leave the rule in each transport binding (RFC-AITP-0014 §5.2, and later MCP).
  2. Define one transport-neutral check in RFC-AITP-0005 and have bindings cite it.
  3. Change the wire: give the TCT a separate audience for the issuer.
- **Chosen:** option 2, as RFC-AITP-0005 §10.5. The verifier requires `iss` == its own AID, runs
  §7.2 with step 5's audience check read from the issuer's side, establishes the presenter's AID
  from downstream PoP (§6.1/§6.2) or a channel binding to the `sub` key, requires presenter AID ==
  `sub` == `aud`, and MUST NOT take the expected audience from the token's own claims. An issuer
  with neither PoP nor a channel binding MUST NOT accept the TCT: for this case §10.5 makes the
  §6 SHOULD (PoP for all grants unless the channel binds the key) a MUST. §5.2 now
  names the two modes, and §13 states that a TCT presented without PoP or channel binding is a
  bearer token. No wire change and no new code: `TCT_SIGNATURE_INVALID`, `POP_RESPONSE_INVALID`
  and `POP_CHALLENGE_INVALID` cover every failure. RFC-AITP-0005 goes to `0.3.2-draft`, and
  RFC-AITP-0014 goes to `0.3.1-draft`.
- **Fixtures:** `tct-026` to `tct-029`, core (`required_for_core: true`, `feature: null`).
  Presenting a TCT back to its issuer is the normal way a TCT is consumed, and the PoP mechanics
  it relies on are already MUSTs under §6.2, so a core implementation that cannot pass these does
  not implement the TCT. `tct-027` to `tct-029` use a new single-step operation,
  `verify_tct_as_issuer`, with the new input keys `outstanding_pop_challenges` and
  `issuer_policy.pop_posture`. Consumers need an adapter update to run them; there are no users,
  so no transition is provided.
- **Reasoning:**
  - One rule in the core RFC is checked by every binding the same way. A per-transport copy can
    drift, and a new transport could omit it.
  - Option 3 breaks the `aitp/0.3` freeze for no gain: PoP or a channel binding already proves
    who presents the token.
  - Taking the audience from the token itself makes the check pass for anyone holding a copy,
    which is why §10.5 forbids it.
- **Reversal trigger:** public review settles a different reading of §5.2 and §10. RFC-AITP-0014
  §5.2 and the MCP mapping cite §10.5, so they follow it without their own change.
- **Blast radius if wrong:** medium. The rule and the four fixtures are core, so a reversal
  changes core conformance for every consumer.

## 2026-10-24 — Conformance fixtures for `INCOMPATIBLE_IDENTITY_TYPE` (RFC-AITP-0004 §5.1 step 8)

- **Status:** UNCONFIRMED (owner to confirm).
- **Decided by:** Opus, while adding the first fixtures for the step 8 identity-type check.
- **Context:** RFC-AITP-0004 §5.1 step 8 requires the receiver to reject a peer whose
  `identity.type` is not in its own `accepted_identity_types` (default `["oidc"]`). No fixture
  exercised the code, and no fixture input stated the receiver's own list: the only
  `accepted_identity_types` values in `mh-*` and `id-*` fixtures sit in the sender's Manifest.
- **Chosen:**
  1. **New input key `self_accepted_identity_types`**, named after the existing
     `self_trust_anchors`. When it is absent, the receiver runs with the default `["oidc"]` and the
     runner adds no types. Without that rule `mh-011` (the default case) could not be written.
  2. **Scope of the default.** An `mh-*` MUTUAL_HELLO fixture runs through step 8. An `id-*`
     fixture stops at step 6, as `PLACEHOLDERS.md` already said ("the result of step 6"). So the
     pinned-key successes `id-010` and `id-017` keep their outcome with no receiver types stated.
     Under the default they would fail step 8, so the scoping is what keeps them unchanged; it is
     written down now rather than left implied. Every earlier `mh-*` fixture that reaches step 8
     presents `oidc`, and `mh-009` (`pinned_key`) fails at step 6.
  3. **Tier: core.** The fixtures pin a MUST in a core RFC using the core identity types `oidc` and
     `pinned_key`, so a core implementation that fails them does not implement §5.1. VERSIONING.md
     allows new fixtures that pin required behaviour; new fixtures may join the core tier.
  4. **Check order (`mh-014`).** §5.1 says its numbered steps "make the order explicit", and it
     verifies the identity proof at step 6, before policy at step 8. So when both fail, the code is
     `IDENTITY_FAILED`, not `INCOMPATIBLE_IDENTITY_TYPE`. The check order is frozen (VERSIONING.md,
     "Error codes and their meanings"), so `mh-014` pins it. A receiver that screens the type
     before verifying the proof fails `mh-014`.
- **Rejected:** putting the receiver's list in a `self_manifest` object. It would carry many fields
  no step reads, and every existing fixture states receiver policy as flat `self_*` keys.
- **Reversal trigger:** public review moves the identity-type check before step 6. That changes a
  frozen check order, so it waits for 1.0 or a security fix, and `mh-014` changes with it.
- **Blast radius if wrong:** low to medium. Five core fixtures; an implementation that skips the
  check or reorders it now fails them, which is the intent.
