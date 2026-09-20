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

- **Plan:** `plans/w-p5-signing-input-divergence.md` (Phase 1)
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
- **Plan:** `plans/w-p5-signing-input-divergence.md` (Phase 4, open question 1)
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
- **Plan:** `plans/w-p5-signing-input-divergence.md` (Phase 3, open question 2)
- **Chosen:** the smallest thing that answers the question the file must answer.
  `envelope` is retained as a *rejected* value so the erratum stays legible in history.
- **Alternative rejected:** naming the artifact (`revocation_list.body`), which encodes
  the artifact twice — the vector id already says which artifact it is.
- **Blast radius if wrong:** trivial; it is new metadata with one consumer
  (`scripts/verify-known-answer.mjs`) inside this repo.

---

## 2026-08-29 — docs/tests/integration-test follow-through for PR #22 and PR #30

Three assumptions logged during `plans/docs-tests-followthrough-jcs-and-bundle-fixes.md` were
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
