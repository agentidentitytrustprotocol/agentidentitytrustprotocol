# Changelog

## Unreleased

### Conformance report schema and badge criteria

**Change class.** New non-wire schema, docs and CI. No wire byte, RFC, fixture or vector changes, and no RFC version bump. Runners that emit their own JSON need to switch to the report format (no users, so no transition period).

**Changes.**
- New `schemas/json/aitp-conformance-report.schema.json` (`$id` `https://agentidentitytrustprotocol.io/schema/v0.3/conformance-report.json`). A report gives the implementation, the spec commit and version, a digest of the fixture files, the enabled features, and one result per fixture: `status`, `feature` and `required_for_v0_2` copied from the fixture, and an outcome of `pass`, `fail`, `skip` or `excluded_by_role`. It also gives totals by tier, one gate per RFC-AITP-0001 §10 claim, the generation time and an optional CI run URL. Reports are unsigned; they are trusted because they can be reproduced. The schema rejects a gate that passed over a blocking result.
- New `docs/conformance-badge.md` sets the badge rule for each claim. "AITP v0.3" needs every `required_for_v0_2` core fixture to pass, so a skip or a role exclusion blocks it. "AITP v0.3 pinned-admission" and "AITP v0.3 self-attestation" need every fixture carrying their feature to pass. A role-excluded core fixture never blocks an extension claim. Every badge shows the spec commit, the version and the date. The page also defines the fixture digest.
- New `scripts/check-conformance-report.py` recomputes the totals and gates from the results. With `--fixtures-dir` it also checks the digest and fixture coverage, and `--digest` prints a directory's digest.
- New sample reports in `schemas/conformance/reports/`: a full implementation, an extensions-only gateway with role exclusions, and three invalid reports. `scripts/validate-json.sh` checks them against the new `scripts/report-validation-map.json`, which is fail-closed and checked in both directions.
- `schemas/conformance/README.md`: a runner emits a conformance report. The runner interface stays implementation-defined. README, `docs/implementer-quickstart.md` and `make docs` link the badge page.
- `governance/DECISIONS.md` records the format choices the plan left open, each with a reversal trigger.

### Governance gate before a Core Team is seated

**Change class.** Governance, docs. No RFC, schema, fixture or vector change, and no RFC version bump.

**Changes.**
- `governance/DECISIONS.md` invokes the `CHARTER.md` § Core Team substitute: the maintainer shepherds every RFC, and an RFC leaves Review, Release Candidate or FCP only after a public review of at least 30 days. The first window closes no earlier than 2027-01-10. The goal is two consenting non-owner Core Team members by 2027-03-31 and before any core RFC enters FCP. No roster file is created.
- `governance/RFC-PROCESS.md` (Review stage) says how the shepherd role is filled before seating. `CONTRIBUTING.md` gains "Review windows": the rule, where to comment, and the first window's earliest close.
- `governance/CHARTER.md` gains "Neutral home" (charter amendment, made under the maintainer's interim authority): who holds the name, domain and GitHub organization, the intent to transfer them to a neutral foundation, and when the project applies to LF AAIF. Recorded in `DECISIONS.md` with a reversal trigger.

### Security policy and review scope

**Change class.** Project process, docs. No RFC, schema, fixture or vector change, and no RFC version bump.

**Changes.**
- New `SECURITY.md`. It separates spec defects from implementation bugs, takes reports only through GitHub private vulnerability reporting, acknowledges within 3 business days, and sets a 90-day embargo, a CVE path through the advisory, and a strict cutover for security fixes that change the wire.
- New `docs/security-review-scope.md`: the surfaces of an external review with RFC section cites, the known open items, and the runtime fuzz gaps.
- `CODE_OF_CONDUCT.md` gives a private conduct contact.
- The issue template's security link opens a private advisory on this repository.

### Contributor funnel and org settings

**Change class.** Project process, docs + CI. No RFC, schema, fixture or vector change, and no RFC version bump.

**Changes.**
- New `scripts/handoff/org-settings.sh` manages the organization's public repository settings: description, homepage and topics; Discussions on the spec repo, aitp-rs and aitp-verifier-py; private vulnerability reporting everywhere; the `good first issue` and `help wanted` labels (plus `spec-bug` and `rfc` here); the org variable `AITP_BOT_CLIENT_ID`; and a pull request correcting the org `.github/SECURITY.md` claim that every repository SHA-pins its Actions. It is a dry-run by default, writes a snapshot before `--apply`, and `--rollback <snapshot>` restores it. CI runs shellcheck, `bash -n` and a read-only dry-run on it.
- New `.github/CODEOWNERS`.
- New `docs/how-to-add-a-fixture.md`, the fixture checklist. The fixture-map rules move there from `CONTRIBUTING.md`, which now points to it, to Discussions and to the `good first issue` label.
- `notify-website.yml` and `notify-spec-consumers.yml` mint the App token with `client-id` (org variable `AITP_BOT_CLIENT_ID`) instead of the deprecated `app-id`.

### One spec-pin policy across consumers

**Change class.** Project process + CI. No RFC, schema, fixture or vector change, and no RFC version bump.

**Changes.**
- `CONTRIBUTING.md` gains "Consuming the spec". A consumer pins the spec by full commit SHA in one committed file, and its blocking CI checks out that SHA. The pin is bumped only by `aitp-ci` `bump-spec-ref` through a held PR. A floating-`main` job is allowed only as a non-blocking canary.
- `docs/ecosystem.md` gains "Spec consumers and their pins", which gives each consumer's SHA-pin file and bump mechanism: aitp-rs `tests/schemas/SPEC_VERSION`, aitp-verifier-py `SPEC_VERSION` (planned, VP1.1), aitp-docs `sources.lock.json` `sources.spec.sha` (bump planned, DOC1.1) and the TypeScript verifier `SPEC_VERSION` (planned).
- `notify-spec-consumers.yml` also dispatches `spec-released` to aitp-verifier-py, and its token is scoped to both repos. Until VP1.1 adds the listener (`bump-spec.yml`), that dispatch is a no-op there.
- `CONTRIBUTING.md` "Technical requirements" lists the doc-coherence stage for the retired schema namespace host.

## v0.3.2-draft (2026-10-24)

Protocol revision `aitp/0.3`, unchanged on the wire. Tags: `v0.3.2-draft`, `schema-v0.3.2`. Moves the schema `$id` namespace to `https://agentidentitytrustprotocol.io/schema/v0.3/` (RFC-AITP-0001 at `0.3.3-draft`), adds fixtures tct-024 and tct-025 (no revocation source: the default policy rejects) and rev-011 (a snapshot signed by anyone but the token's issuer is discarded; RFC-AITP-0008 at `0.3.2-draft`), runs the independent Python known-answer recompute in `make validate`, and pins CI actions to commit SHAs. Reference implementations at release: aitp-rs 0.19.0 and aitp-verifier-py `b762f8c` pass rev-011 and fail only the new tct-024 (both accept its token); aitp-rs RS1.2 and aitp-verifier-py VP1.1 track the fix.

### Schema namespace moves to agentidentitytrustprotocol.io

**Change class.** Schema metadata (non-wire). No validation outcome, wire byte, signature, fixture or vector changes. The `$id` is an identifier that nothing dereferences, so this is not a breaking schema change and the namespace path stays `v0.3/` (VERSIONING.md now says so). There is no alias for the old host: the project has no users, so this is a clean break.

**Changes.**
- Every canonical schema's `$id` moves from `https://aitp.dev/schema/v0.3/<name>.json` to `https://agentidentitytrustprotocol.io/schema/v0.3/<name>.json`. The project does not own `aitp.dev`; it owns `agentidentitytrustprotocol.io`.
- The conformance-fixture schema's `$id` was the only one named after its file (`aitp-conformance-fixture.schema.json`); it is now `conformance-fixture.json`, like the other ten (`tct.json`, `envelope.json`, ...). File names in `schemas/json/` are unchanged.
- README.md "Compatibility model", VERSIONING.md (layer table and the `aitp/0.3` migration note) and RFC-AITP-0001 §7 name the new namespace. VERSIONING.md adds that a change to the namespace host or to a schema's `$id` name that alters no validation outcome is schema metadata, not breaking.
- `docs/ecosystem.md` gains a "Schema namespace" section: the project owns the host, `aitp-website` serves each schema at its `$id` URL as a convenience, and the canonical copy is `schemas/json/` at a `schema-vX.Y.Z` tag.
- `scripts/check-doc-coherence.sh` stage 10 fails when any tracked file except this CHANGELOG names `aitp.dev`.

**Version bumps.** RFC-AITP-0001 `0.3.2-draft` → `0.3.3-draft`.

### RFC-AITP-0008: revocation snapshots are per issuer; no third-party revocation authority

**Change class.** Clarification (non-normative) and fixture addition (core). RFC-AITP-0008 moves to `0.3.2-draft` for an informative note. No requirement, schema, registry or vector changes. §1.5 already discards a snapshot whose signed `issuer` is not the issuer of the token being checked. Decision recorded in `governance/DECISIONS.md` (OQ-6), prompted by aitp-control-plane#153.

**Changes.**
- RFC-AITP-0008 §1.5 (`0.3.2-draft`) gains an informative note after the **Verification** paragraph: a snapshot speaks only for its signer, `aitp/0.3` has no third-party revocation authority, and a list signed that way is discarded like any other.
- `docs/operational-guidance.md` gains a non-normative section, "Centralised revocation management". A registry or control plane records revocations as intent and relays each entry to the issuer of the token, and each issuer signs and serves its own `ListRevoked`. It also says that an agent that issues TCTs but publishes no list has its TCTs rejected under `fail_closed` (`tct-024`), and that replicas of one issuer must sign with one key and serve one entry set.
- **New fixture `rev-011-third-party-signed-list-discarded`** (`core`, expected `TCT_REVOKED`). The committed TCT `signed-examples/tct/kat-keypair-001-issues-002.json` is checked under `fail_closed` against the committed, unmodified snapshot `signed-examples/revocation/kat-keypair-005-snapshot.json`. That snapshot is fresh and verifies under its own signed `issuer` (kat-keypair-005-p256), which is not the TCT's `iss`, and it does not list the TCT's `jti`. A verifier that honours the list because its signature verifies accepts the token, and fails the fixture. Nothing is minted.
- `scripts/verify-known-answer.mjs` (`EXPECTED_MIN_CHECKS` 170 → 171) and `scripts/recompute-known-answer-independent.py` (`EXPECTED_MIN_CHECKS` 238 → 244) both check the fixture against the committed examples, verify the snapshot under its own issuer, and check that this issuer is not the TCT's `iss` and that the `jti` is unlisted.
- `scripts/fixture-validation-map.json` maps the token claims and the snapshot. `FIXTURE_INPUT_MIN_CHECKS` rises from 243 to 245.
- `rfcs/README.md` records the RFC-AITP-0008 version.
- Conformance index: `core` 84 → 85, total 110 → 111.

### Spec drift and CI hygiene

**Change class.** Editorial + CI. No wire, schema, fixture or vector change.

**Changes.**
- `README.md` `**Version:**` is `0.3.1-draft`; it still said `0.3.0-draft` after the v0.3.1-draft release. `scripts/check-doc-coherence.sh` stage 1 now fails when that header is not the newest `## v…` release heading in this file.
- RFC-AITP-0001 §1: backward-incompatible changes remain possible "until the document reaches Accepted", not "until Final status". The RFC lifecycle has no Final stage (governance/RFC-PROCESS.md).
- `governance/spec-errata-from-independent-verifier-2026-07.md`: the closed record's "Draft→Final" stage word is now "Draft→Accepted", with a dated editorial note. The finding is unchanged.
- `docs/threat-model.md` "Known limitations" gains the signature-string malleability row that RFC-AITP-0009 §2 already lists (RFC-AITP-0001 §5.4.3; ECDSA high-S closed by §5.4.7). New coherence stage 9 checks that the index cites every RFC-AITP-0009 §1.N threat and has one known-limitation row per RFC-AITP-0009 §2 row.
- `make validate` now runs `make kat-independent`: `scripts/recompute-known-answer-independent.py --quiet`, the Python recompute that shares no code with `scripts/verify-known-answer.mjs`. It gains a `--quiet` mode and a coverage floor (`EXPECTED_MIN_CHECKS = 238`). Its one dependency, python-ecdsa 0.19.2 (with six 1.17.0), is hash-pinned in the new `scripts/requirements-kat.txt`; CI sets up Python 3.12 with a pip cache and installs it with `--require-hashes`.
- Every GitHub Action in `.github/workflows/` is pinned to a full commit SHA with a `# vX.Y.Z` comment (checkout v7.0.1, setup-node v7.1.0, setup-python v7.1.0, create-github-app-token v3.3.0, repository-dispatch v4.0.1). Dependabot (actions only) bumps the SHA and the comment together.
- New `.github/ISSUE_TEMPLATE/config.yml`: blank issues off; contact links for private security reports (org `SECURITY.md`) and Discussions. The bug template no longer offers a "Proto schema" area; AITP ships JSON only.
- The `spec-bug` and `rfc` labels the issue templates apply now exist in the repository.
- Docs that counted the doc-coherence stages ("eight-stage") now point at the script header instead, so the count cannot drift again.

**Version bumps.** RFC-AITP-0001 `0.3.1-draft` → `0.3.2-draft`.

### Conformance: no revocation source, default policy, rejects

**Change class.** Fixture addition (core). No RFC text, schema, registry or vector change, and no RFC version bump. The rule is already normative: an issuer with no snapshot source falls under `revocation_policy.mode` (RFC-AITP-0008 §1.4), and the mode's schema default is `fail_closed` (§3.1). No fixture pinned it, because a fixture without a revocation input does not test revocation. aitp-rs 0.19.0 and aitp-verifier-py `b762f8c` both accept the token in `tct-024`.

**Changes.**
- `schemas/conformance/README.md` "Revocation inputs" defines the members of `issuer_revocation_list` in one table. The new member `available: false` states that the verifier has no revocation source for the issuer, which is not an empty list, and such an entry carries no `snapshot`. When `fail_mode` is absent, the runner MUST run the verifier with its default revocation policy, and the expected outcome assumes `fail_closed`. A missing `issuer_revocation_list` still means "not tested".
- **New fixture `tct-024-no-revocation-source-default-fail-closed`** (`core`, expected `TCT_REVOKED`): `issuer_revocation_list` is `{issuer, available: false}` with no `fail_mode`.
- **New fixture `tct-025-no-revocation-source-explicit-fail-open`** (`core`, expected success): the same input with `fail_mode: "fail_open"`. An implementation that reads an unavailable source as "nothing is revoked" passes `tct-025` and fails `tct-024`.
- Both use the committed TCT `signed-examples/tct/kat-keypair-001-issues-002.json`, as `tct-022` does. Nothing is minted.
- `scripts/verify-known-answer.mjs` and `scripts/recompute-known-answer-independent.py` both check that the token is the committed one and verifies, that `issuer_revocation_list` names its `iss`, is unavailable and has no snapshot, and that the two inputs differ only in `fail_mode`. `EXPECTED_MIN_CHECKS` rises from 167 to 170.
- `scripts/fixture-validation-map.json` maps both fixtures. `FIXTURE_INPUT_MIN_CHECKS` rises from 241 to 243.
- `docs/operational-guidance.md` cites the new fixtures in the revocation-mode table.
- Conformance index: `core` 82 → 84, total 108 → 110.

## v0.3.1-draft (2026-10-21)

Protocol revision `aitp/0.3`, unchanged on the wire. Tags: `v0.3.1-draft`, `schema-v0.3.1`. Clarifies revocation handling (RFC-AITP-0006, RFC-AITP-0008 and RFC-AITP-0011 at `0.3.1-draft`) and adds fixtures tct-022, tct-023, del-008 and del-mh-006. Reference implementations passing the conformance suite at release: aitp-rs 0.19.0 and aitp-verifier-py `138b79d`.

### Conformance: fixtures without a revocation input do not test revocation

- `schemas/conformance/README.md` gains a "Revocation inputs" section. A fixture that supplies neither `issuer_revocation_list` nor `revocation_snapshots` is not testing revocation, and its expected outcome assumes "not revoked". In a deployment, `revocation_policy.mode` still governs an absent or discarded snapshot (RFC-AITP-0008 §1.5, §3.1); the dedicated revocation fixtures cover that.
- `del-001` and `del-mh-001` say so in their `description`. No expected outcome changes.
- The convention is per issuer: in a fixture that supplies `revocation_snapshots` for only some issuers, the issuers without an entry are not under test either. RFC-AITP-0011 §6 (0.3.1-draft) now also states the deployment rule: a hop issuer whose snapshot cannot be obtained falls under `revocation_policy.mode`, as RFC-AITP-0008 §3.1 requires.

### RFC-AITP-0008: a discarded revocation snapshot MUST fall back to `revocation_policy.mode`

**Change class.** Normative tightening, security. Reported by aitp-rs#271: a verifier that discarded an invalid snapshot and then accepted the token turned `fail_closed` into fail-open for anyone able to corrupt or forge a snapshot in transit.

**Changes.**
- RFC-AITP-0008 §1.5: a snapshot is discarded if it fails any structural or signature check (`REVOCATION_SNAPSHOT_INVALID`, `UNKNOWN_FIELD`, `REVOCATION_SNAPSHOT_SIGNATURE_INVALID`), if it has expired, if it is stale beyond `max_staleness_secs`, or if its signed `issuer` is not the issuing peer. A discarded snapshot is treated exactly as an absent one: the peer MUST apply `revocation_policy.mode` (`fail_closed` rejects with `TCT_REVOKED`; `fail_open` allows and logs; `soft_fail` allows with restricted grants and logs), and MUST NOT treat it as meaning no revocation check is needed. §3.1's mode bullets and its `fail_closed` note now say the same. The snapshot codes remain what `verify_revocation_snapshot` reports (`rev-005`, `rev-007`, `rev-008`, `rev-010`); `verify_tct` reports per the mode.
- RFC-AITP-0006 §4 step 7: A's own deny list is local state, so the discarded-snapshot rule and the mode do not apply to that lookup. If an implementation keeps its own list as a signed snapshot and it fails verification, the delegation token MUST be rejected with the snapshot's own code whatever the mode; it is never treated as absent.
- RFC-AITP-0011 §6: a hop issuer's discarded snapshot is absent, and the verifier applies its mode to that hop's lookup (`fail_closed`: the hop counts as revoked, so `DELEGATION_SOURCE_TCT_REVOKED`; `fail_open`: not revoked).
- `registries/error-codes.md`, `docs/operational-guidance.md` and `docs/GLOSSARY.md` say the same.
- **New fixtures `tct-022-invalid-snapshot-fail-closed`** (`core`, expected `TCT_REVOKED`) **and `tct-023-invalid-snapshot-fail-open`** (`core`, expected success). Both use the committed TCT `signed-examples/tct/kat-keypair-001-issues-002.json` and the committed snapshot `signed-examples/revocation/kat-keypair-001-snapshot.json`, with the least-significant bit of the snapshot signature's last raw byte flipped. The TCT's `jti` is not listed. They differ only in the existing `issuer_revocation_list.fail_mode` key. Nothing is minted; `PLACEHOLDERS.md` says a runner MUST NOT re-mint either value.
- **New fixture `del-008-own-snapshot-signature-invalid`** (`core`, expected `REVOCATION_SNAPSHOT_SIGNATURE_INVALID`), derived from `del-002`: A's own snapshot carries `__TAMPERED_SIGNATURE__` and no longer lists `src_jti`.
- **New fixture `del-mh-006-invalid-hop-snapshot-fail-closed`** (`draft`, `feature: experimental-multihop-delegation`, expected `DELEGATION_SOURCE_TCT_REVOKED`), derived from `del-mh-004`: B's snapshot carries `__TAMPERED_SIGNATURE__` and no longer lists `chain[0].jti`. `del` and `del-mh` fixtures have no policy input key, so it relies on the schema default `fail_closed`; no key is introduced.
- `scripts/verify-known-answer.mjs` and `scripts/recompute-known-answer-independent.py` both check `tct-022` and `tct-023`: the token is the committed one and verifies, the body is the committed one, the signature is the committed one with the bit flipped and does not verify, and the `jti` is not listed. `EXPECTED_MIN_CHECKS` rises from 165 to 167.
- `scripts/fixture-validation-map.json` maps all four fixtures. `FIXTURE_INPUT_MIN_CHECKS` rises from 227 to 241.
- Conformance index: `core` 79 → 82, multi-hop `draft` 5 → 6, total 104 → 108.

**Version bumps.** RFC-AITP-0006, RFC-AITP-0008 and RFC-AITP-0011: `0.3.0-draft` → `0.3.1-draft`.

### Media-type registry and VERSIONING layers row follow `aitp/0.3`

**Change class.** Editorial; no wire, fixture or vector change. Reported by aitp-docs.

**Changes.**
- `registries/media-types.md`: the envelope media type is `application/aitp+json; version=0.3`, and `version=0.2` moves to Superseded. The description no longer says the signing input is the inner payload: the signature covers the whole envelope except `signature` (RFC-AITP-0001 §5.4).
- `VERSIONING.md` layers table: a revision mismatch is rejected with the artifact's unknown-version code, not always `UNKNOWN_VERSION`, matching the Forward / backward compatibility section.

**Version bumps.** None.

### Conformance: unknown-version fixtures for revocation snapshots and session bundles

**Change class.** Fixtures only. No RFC text, schema, registry or vector changes, and no RFC version bump. Until now only the Manifest (`man-002`) and the envelope (`env-010`, `env-011`) had an unknown-version fixture, so the per-artifact codes `VERSIONING.md` names for the other two JCS-profile artifacts were not pinned. aitp-rs#265 reported `UNKNOWN_VERSION` for an unknown-version revocation snapshot.

**Changes.**
- **New fixture `rev-010-version-unknown`** (`core`). The committed signed snapshot `signed-examples/revocation/kat-keypair-001-snapshot.json` with `version` changed to `aitp/9.9` after signing, and its committed signature. Expected: `REVOCATION_SNAPSHOT_INVALID` (RFC-AITP-0008 §1.5: structural validation, including the schema's `version` const, runs before any signature work).
- **New fixture `bundle-008-version-unknown`** (`draft`, `feature: experimental-session-bundle`, so an implementation that has not opted into RFC-AITP-0010 reports SKIP). The committed signed bundle `signed-examples/session-bundle/kat-keypair-001-bundle.json` with `version` changed to `aitp/9.9` after signing, and its committed coordinator signature. `coordinator_manifest` is the committed `signed-examples/manifest/kat-keypair-001-manifest.json`. Expected: `BUNDLE_VERSION_MISMATCH` (RFC-AITP-0010 §5 step 1 runs before the step 6 signature check).
- No signature was minted. Both fixtures follow the `env-010` pattern: the signature verifies over the signed example and not over the fixture, so a verifier that checked the signature first would report the signature code. `make kat-verify` (`scripts/verify-known-answer.mjs`) and `scripts/recompute-known-answer-independent.py` both assert this, and that only `version` differs. `PLACEHOLDERS.md` says a runner MUST NOT re-mint either signature.
- `scripts/fixture-validation-map.json` maps both fixtures. The snapshot and the bundle are expected to be schema-invalid, because the `version` const rejects `aitp/9.9`; the bundle's Manifest is expected to be valid. `FIXTURE_INPUT_MIN_CHECKS` rises from 224 to 227, and `verify-known-answer.mjs` `EXPECTED_MIN_CHECKS` from 162 to 165.
- Conformance index: `core` 78 → 79, session-bundle `draft` 7 → 8, total 102 → 104.

## v0.3.0-draft (2026-10-20)

Protocol revision `aitp/0.3`. Tags: `v0.3.0-draft`, `schema-v0.3.0`. The v0.2 line is frozen at `f9ee7ea` under `v0.2.1-draft` / `schema-v0.2.1`. Reference implementations passing the conformance suite at release: aitp-rs 0.17.0 and aitp-verifier-py `f335f4f`.

### The JCS-profile signature string is not canonical; unknown-version codes are per artifact

**Change class.** Editorial and security considerations; no wire change, no fixture or vector change. Reported by aitp-rs while implementing `aitp/0.3`.

**Changes.**
- RFC-AITP-0001 §5.4.3 states that a signature field is outside its own signing input, so an Ed25519 signature verifies in both the untagged and the `ed25519.` form, and a relaying party can switch between them. Implementations MUST NOT use raw object bytes (or their hash) as identity for replay detection, deduplication, caching or audit correlation; they key on `message_id` or the JCS form without the signature. RFC-AITP-0009 §2 lists it as a known limitation. Making the tag mandatory is left to a later revision.
- `VERSIONING.md` no longer says every unknown version is `UNKNOWN_VERSION`. It names each artifact's code: `UNKNOWN_VERSION` (envelope, JWS-profile artifacts), `MANIFEST_VERSION_UNKNOWN`, `REVOCATION_SNAPSHOT_INVALID`, `BUNDLE_VERSION_MISMATCH`. This matches RFC text and the fixtures already.

**Version bumps.** RFC-AITP-0001 0.3.0-draft → 0.3.1-draft; RFC-AITP-0009 0.3.0-draft → 0.3.1-draft.

### `aitp/0.3` revision bump: literal, schema namespace `v0.3`, RFCs `0.3.0-draft`, re-minted vectors (#87)

**Change class.** Breaking: a new protocol revision. PR 2 of 2 for #87 (proposal #89). PR 1 changed the envelope signing input under the `aitp/0.2` literal; this PR promotes that change to its own revision. The envelope signing input is the only change of substance. Everything else here follows from the new literal. Strict cutover: an `aitp/0.3` implementation rejects `aitp/0.2` with `UNKNOWN_VERSION`, with no dual-accept window. Migration notes: [`VERSIONING.md`](VERSIONING.md#migrating-from-aitp02-to-aitp03).

**The v0.2 line is frozen at `f9ee7ea`.** That is the last commit whose literal is `aitp/0.2`. The existing `v0.2.0-draft` and `schema-v0.2.0` tags point at `ea22c71`. A freeze tag for `f9ee7ea` (for example `schema-v0.2.1`) is cut at release, together with the first `aitp/0.3` tags. This PR creates no tags.

**Changes.**

1. **Literal.** `aitp/0.2` → `aitp/0.3` wherever it names the current revision: the `version` and `ver` schema consts, the RFC text and examples, conformance fixtures, known answers, signed examples, `examples/`, the docs and the registries. Historical mentions (what the v0.2 line introduced, errata against it, earlier vector values) are kept. The "AITP v0.2 self-attestation" and pinned-admission claim strings become "AITP v0.3 …". `scripts/check-doc-coherence.sh` stage 7 now treats `aitp/0.2` and `v0.2` like `aitp/0.1` and `v0.1`: a mention in `docs/*.md` or `README.md` must be marked historical (`v0.2 line`, `v0.2-frozen`, and the existing markers).
2. **Schema namespace.** Every canonical schema `$id` moves from `https://aitp.dev/schema/v0.2/` to `https://aitp.dev/schema/v0.3/`.
3. **RFC versions reset.** Every RFC `Version:` header is `0.3.0-draft`, except RFC-AITP-0012 (`0.3.0-reserved`) and RFC-AITP-0013 (`0.3.0-planned`). Before the reset, the v0.2 line had RFC-AITP-0001 at `0.2.14-draft`, 0002 at `0.2.11-draft`, 0003 at `0.2.7-draft`, 0004 at `0.2.5-draft`, 0005 at `0.2.7-draft`, 0006 and 0007 at `0.2.1-draft`, 0008 at `0.2.9-draft`, 0009 at `0.2.5-draft`, 0010 at `0.2.6-draft`, 0011 at `0.2.2-draft`, 0012 at `0.2.3-reserved` and 0013 at `0.2.0-planned`. Status values are unchanged. `rfcs/README.md` replaces its per-document divergence narrative with the reset statement. RFC-AITP-0001 §1 lists the `aitp/0.3` delta. RFC-AITP-0002 §5 is retitled "Future Identity Types", so its anchor is now `#5-future-identity-types`. Headings that named v0.2 now name v0.3, and every link to them is updated.
4. **New fixture `env-011-previous-revision-rejected`** (`core`). It is env-007's envelope with `version` set to `aitp/0.2` and a fresh `message_id`, correctly signed by kat-keypair-001 over `sig_input_v2`. Expected: `UNKNOWN_VERSION`. It pins the strict cutover with a signature that is valid for its own bytes, unlike env-010 (`aitp/9.9`, signature not over the altered value). Signature: `qXNURAet0h9miBTCFOBSjsj01ptplj_702PekH0hTCLRMmGziQvW-7jLMsTfP4ZyF5--0FNgJKMJ-RmFo3aOBg`.
5. **Conformance gating key.** Fixtures keep `required_for_v0_2` as the core-tier key. For `aitp/0.3` it marks the core fixtures. It was not renamed to `required_for_v0_3` because the runners in aitp-verifier-py and aitp-rs read it by name.
6. **Docs.** `VERSIONING.md` gains the migration section, the freeze note and the reset rule for document versions. The README status line, `docs/implementer-quickstart.md` (new "Migrating from the v0.2 line" note), `docs/architecture.md` and `docs/GLOSSARY.md` describe `aitp/0.3`. `Makefile` `RELEASE_VERSION` is `v0.3.0-draft`.

**Re-minted known answers and signed examples.** Every vector and signed example that contains the literal was re-minted by script (`scripts/recompute-known-answer-independent.py` holds the reference re-signing; the generator was a one-off). No value was hand-edited. Keys, `jti` values, `message_id`s and timestamps are unchanged. The literal keeps its length, so canonical byte lengths are unchanged (manifest 623, revocation 221, session bundle 922). Unchanged outputs: `kat-manifest-pop-001/002`, the three pinned-key proofs, `kat-p256-jcs-sign-001`, `kat-derived-uuid-001`, the signature-strictness vectors, and the envelope `_must_not_verify.v1_signature` negatives (they sign the retired v1 input, which has no `version` in it). The `jcs_canonical_hex` and `sig_input_v2_hex` fields change only in the literal's last byte (`0x32` → `0x33`) and are not listed below.

For each compact JWS, the table gives the signature segment. The header segment is unchanged, and the payload segment changes only in the `ver` claim. The full tokens are in the files named. "(+N more)" means the same token also appears in N other places, which were all replaced. The three placeholder tokens in the `schemas/json/` examples are not listed: they carry no real signature, and only their payload segment changed.

| Where | Output | Old | New |
|---|---|---|---|
| `known-answer/jcs-sha256.json` kat-multihop-chain-001 `voucher_jws` (+2 more) | JWS signature segment, aitp-grant+jwt (eddsa) | `uKxWQg6TclhPsW__-YyFqJw_X33Rbo35znEIrsSp5CJ-_JNdwUGKxTGT9a6ZTSOX3inc1ZCiLGVfR3M_oylNBg` | `OogyowLFI9n6PvXwxbinyOoB17A9EsZFCiWGdA2mMx9ubyl8unTdgns9augiicZ4uJZ8p2o_MfRq6I4Ah_aiDg` |
| `known-answer/jcs-sha256.json` kat-multihop-chain-001 `chain[0]` | JWS signature segment, aitp-delegation+jwt (eddsa) | `T-cwho7uLL_Ufdgzz5vp5PvzuXy1ZuE4v9QtGfqOnhJGtzW5hLF8HcaSrZD-eUgla_9kb_19j89JDoRpkbm7BA` | `njX4k0y5hos96ZqDFgYFF1zoATPmL9v21W6bcpSMuQye184qVtl0MoIzdiWL1LaSYOfRZ727ygGumBa39RIdBA` |
| `known-answer/jcs-sha256.json` kat-multihop-chain-001 `outer_delegation_jws` | JWS signature segment, aitp-delegation+jwt (eddsa) | `VfzwUyVTVMgzs1dRAtgMSvpa2pIAtdVLCcP2HSVKyfbrezXH7aMwsoHSSU286b3xhg2ib_C7PRnnYkavJbFQBg` | `wblq_gps-IbkF6Bg1TEXzNZZQxCOKw9EX5Uq4M2V73JDjeC33LyDoPKuNSzFG8Sr-dko7RHZGUuiAT2dJJg7BQ` |
| `known-answer/jcs-sha256.json` kat-session-bundle-001 `object.participants[0].tct` (+2 more) | JWS signature segment, aitp-tct+jwt (eddsa) | `-hVZMF6zG0ACQkRmTUb5fdw06_qlnJ772YFoqvrbG6h_frC1BL2hDVm1RmfxjVVZ7uRoa3Xl4OqZxb6dOoRADw` | `MA6HEWmgaHoDtSr6QBZww15p9ZI-v1tUZ7_-boxN_5tHbArt3stiGvbxSzgOOrCM2MLvifypmKqBXxp3QQaLAg` |
| `known-answer/signed-examples/delegation/single-hop-001-002-003.json` `delegation_token` | JWS signature segment, aitp-delegation+jwt (eddsa) | `UKugx0f-zgVB86OZBgcpqaDaDe_Lcm0rn9VcBvGAIDhNMDxGAyeluSgy2IuatiYkygiAXsFyXckleV56c0NhDQ` | `PMWJVZdsI1TJ3AWAVGrj0WQIH_iPbmENcQ4Iq6m-Xt3mURL0tyqVLWCu0uKUAQS48vM9NDEod_QSPAlkgSDZAg` |
| `known-answer/signed-examples/tct/kat-keypair-001-self-attestation.json` `tct_token` (+2 more) | JWS signature segment, aitp-tct+jwt (eddsa) | `YzU-zyPNAwlbABwJoSCMpDA75Hq6l4kqa_cMK9fHKWJu-PWV-xuJAMNyIXFl3Td782cylxVSi8lwGjpyK93fCg` | `vfC9qoCsxg-cVyWJWlxPogvGwVpje-nTlNyxt-4Z1nc8772PGNUlq6orqHZj2sZOWXo8npbb3Bt8GBsigi8kAg` |
| `known-answer/signed-examples/tct/kat-keypair-005-issues-002.json` `tct_token` | JWS signature segment, aitp-tct+jwt (es256) | `I--AfnNlrWyTD3d1r8B56W0oKHl8J0gCl_6GoHQn_igudDtrO8DJXR7senv2pIfadwAaLX80jJzdn17IT3E48w` | `M4zp079NQoQQmpmUAgC_XEX3S5hB2nzcCMuIBOPiVZMMmxhJR0sxCjgU8L7kr1-K981Vq7pz4zSL6RwnOm_6mQ` |
| `known-answer/signed-examples/tct/kat-keypair-005-issues-002.json` `_must_not_verify.double_hash_jws` | JWS signature segment, aitp-tct+jwt (es256-double-hash) | `ABcqK7O6p_B2eGkpXZx8gzx2GiLAOwUIeW-GgkKEGKd8YEDDlg7Eku9mJlaOvMzGzN488Dvqs_nTOn5P7-1W4Q` | `YmTgEtYrZxrPUqNbk-Ok5_kvHPgNoFJYGe1XVkQ5Mi5D0VbjbGVtYH_L-Xl9lb3zV5TiKt5cDAGvG6cLa70Jcg` |
| `known-answer/signed-examples/tct/kat-keypair-005-self-attestation.json` `tct_token` | JWS signature segment, aitp-tct+jwt (es256) | `HlqcmBHTvuTgfm9oiQVmphGhjThe4wLzznGf9Jj9dGoBIfhXxxsBfexENsKgvg37lPnUyu6MEpUsRqmgURRQ1g` | `0ednWtdn8a2dK_E2kRN1nU2_RgzLt--yoqQN934wVaEnXFB4KUwfE_-wk9ocKC4qid12UQJ7xTvzH6eJtkOMYg` |
| `known-answer/signed-examples/tct/kat-keypair-005-self-attestation.json` `_must_not_verify.double_hash_jws` | JWS signature segment, aitp-tct+jwt (es256-double-hash) | `ejdm5TOKhTh3tSByt4O6BB9rsXl-xFkNsfvTg7_0w0hmoNotZqmfds7k1mB40fvEpmpexdQGb56iFm37joroww` | `8rUmhgqf8P13UnNprIBGxY2nD_GQHXNzdHgb0NWgZusWVZi4TRwQTqetC5bMxgw_GUs_EBGf4fkAk03R_JZHoQ` |
| `tct-017-es256-high-s-rejected.json` `input.tct_token` | JWS signature segment, aitp-tct+jwt (es256-high-s) | `GFCDkPR-71zxwDQTX7mirDjjh5NCpwii_7xiOfDAr5PkvfhFK5048g6QR-NIPMHRHOefKBRYGl3STQNLtRy1uw` | `IEn-V6rYE6NP3KXKb_t7xTfMwGSRd6OylXdHHGoYU-GxK_RNlgRfVoZcTcdVEyQB4OEdej8auqvMuV9EuYEY7w` |
| `known-answer/jcs-sha256.json` kat-multihop-chain-001 | per-entry digest (b64url sha256 of the hop-1 token) | `ser99B3D-7baXJGh8Dte_3mWfdBq8Xc1MbVpeO7UVPo` | `FWa7vsIfjAvCy8dLR-1kItxCAey44zR6aPzPQWeB5bk` |
| `known-answer/jcs-sha256.json` kat-multihop-chain-001 | chain_hash | `27qTmatfcU_X78-J80ezX7lbK1BViLdyeNh2XfJ-Zbw` | `IR1G_oJO2OG57f7jFqs0tSBDq9sSHOJsar88DWjKXU4` |
| `signed-examples/manifest/kat-keypair-001-manifest.json` | `manifest.signature` | `xpd4haK69GQAz7QopVupP-A4LvgDA73kFmJfHqpScgjsc4uqq7HQlmty_6H9drrdYQcImNgi4bMkebXSlr0KAA` | `8XoWmxeOk-rGXPZCpjfrkmsBbw1wcLVolcnuCYHhXrEW75eS5HCYfYvzycIKgyJne54Dk2t0Cm9mdqks7mVABg` |
| `signed-examples/manifest/kat-keypair-005-manifest.json` | `manifest.signature` | `p256.-udvH6qwriW7E_9k9rfm4FETZ-2aBtLd9eMIG1CjVp0Zi03X_pDVXD4iTzBddPtH-MuM6pdRZUq7RVowjgPZOg` | `p256.BbkRZRheHRDskHFFOn5ZHq8a-0gA80l0XilXLeQv584ouqAdyTo3wkrCnPicBKNR1ui6bh6eDkpEQR1eTRHTdQ` |
| `signed-examples/manifest/kat-keypair-005-manifest.json` | `_must_not_verify.double_hash_signature` | `p256.VZ1rGRElpiZpZXoi17yeUrOMHEl6C1ldHluR-mthwGp9flNnRLQJ7OD6jw_rMoyPuJebta8PNtgfRwWdAPUvhw` | `p256.Kbsc5ojUkMS_dX4kJbWGvfV3jrQfaXV2zqcK7TQ_T9sNTCDodpMowVK1-o3DR1Ys2pM-BYZl-KoD9FfPykTNbg` |
| `signed-examples/revocation/kat-keypair-001-snapshot.json` | `signature` | `DTmCoELd0lIRCRBdhDuLmEqvFK1VqpTSGyPEG6-C0InTOeF8LB4a-Rf4ercCvhLYD6H1t9_T-7FgQ1ufBfKkCQ` | `wWcNpzrG_gT0B21GXeMFXDq9nU4dvGPXmUsoVE1Z7W7ttcaQ0nOf5WDbQWAeGx6FM_sZ0J1wlHoIXtHUR9IACQ` |
| `signed-examples/revocation/kat-keypair-005-snapshot.json` | `signature` | `p256.RKOXAVAzSvLJQKB9cuBNz-XSZG6CsckieAcdpQDfobAQvXDq3_n43neCtAEbV0VafKKWUVWN9xro-LPufdMi0w` | `p256.G6F0v2yvar_yXBxjqbjH77tHufVG_yNxKT2A3e7HETpKDTm2eOXbCc2p65juU0YYpP4eRImlg6UPCcQey6cNeg` |
| `signed-examples/revocation/kat-keypair-005-snapshot.json` | `_must_not_verify.double_hash_signature` | `p256.2Kp4eIL7V4w00Bw3Tnb-uOnSEdi4L7op6RFDIhicDUta_DmCnAI1QPyihwszAuQoMd9oHS3DMerFffKw-Ebkqw` | `p256.yZs-HwVBtwCbFbkipayk1kce2iTcBoFFFkb1IDDSV9YgbkdHTsH8IGHZKd7YkKRmwQR6klmUYc5e33lD86cZtA` |
| `signed-examples/session-bundle/kat-keypair-001-bundle.json` | `session_bundle.signature` | `czzmjpVf5rtZ2-FvfMcviSUCeY2WSu69v2ZECpflHAKVaEikz4w6m5fOVuBZkCL8DXX-lkY905NvYxjQTg_TBw` | `Bi3qnf2aSxg3Fyrv-T0XBX4xxUMchHLMfRI1C1rdQioRaTmL_B4X_t1nt7iDHUb9ePeFIi8fMQAWGdB8mPoDAw` |
| `signed-examples/envelope/kat-keypair-001-envelope.json` | `sig_input_v2_sha256_hex` | `f1b0e17ced992c275fc58068a564e1ba3dfdd319963bcd77cb9c516bcdc704a0` | `5b2d7921353114373df6dc6384f96275140b9be534fa75f8cef13a00005e17b4` |
| `signed-examples/envelope/kat-keypair-001-envelope.json` | `envelope.signature` | `v9IsSYtz353H8F9RlXHwRh8g9rLoPa_KW5sHCBtOx3_AlZbWfMUqn-ReGckaic4PjcJGowRIb-tNAntRYqWgAw` | `mW2htyofIn3wJhfxaIRespw-WQpV6KYRtGiOJBJyWu_Dzj1ThhY7xFTKQiJJu3_nToWu11UviiXHRhehaswTAw` |
| `signed-examples/envelope/kat-keypair-005-envelope.json` | `sig_input_v2_sha256_hex` | `18ef5b4a02d6bfb05ff93cd173c05d6be48f729e0aa296fbee982f4ba8f94885` | `e676a375b5f2e6db0531d9280dc21311aad9c51d73a0fd4fc5cb945e68ee043f` |
| `signed-examples/envelope/kat-keypair-005-envelope.json` | `envelope.signature` | `p256.zpVe0l_qTePUWQ0q829FnebYx0S5IDrFWSKgp1hNuo173QViku6Ocsmy-TsDgPlbSKiEgBDh63kGcSAHm7E2dA` | `p256.BytCJBGZPIVZAKoijm5pbVUortpHaAOYtBL8Lr0F2sMQwXYW-uBPJjCEIY0c8vJ1Lsk9DZGAS65OMP2ZhkOkew` |
| `signed-examples/envelope/kat-keypair-005-envelope.json` | `_must_not_verify.double_hash_signature` | `p256.XLbKANH7oZ0YUWvx2nUcQ4pReaYe5zHp6RTKWEijVrg7JQ3HTr88MAHSi0uIV134gVaMGAuD6x4qkhbM4bdM0Q` | `p256.Yk_AxecAVPzLz7eKOenvVBmN2Y5UuGBXql8ZMvMq72kixZeuKYIAw1bD4Bd4-dlg13iXCpNoiY6xWMpwTdFEqA` |
| kat-manifest-001 | `sha256_hex` | `b93915e980ebca05a68a81465ac36e416bc3dec40e068f21770cba6c415884af` | `3bdbfe4370bf785aa7d37f0735bef33807118cb4e1240dee27813a4e31b59518` |
| kat-manifest-001 | `sha256_b64url` | `uTkV6YDrygWmioFGWsNuQWvD3sQOBo8hdwy6bEFYhK8` | `O9v-Q3C_eFqn038HNb7zOAcRjLThJA3uJ4E6TjG1lRg` |
| kat-revocation-001 | `sha256_hex` | `dad7eb6db48c924ef30de7c20a6702715b512dd8aee12c9eed33139ba7008bfb` | `016b1c2e7c2213e5eb5d617a4da1196dc57edade0d683656f11a066f12e9b25e` |
| kat-revocation-001 | `sha256_b64url` | `2tfrbbSMkk7zDefCCmcCcVtRLdiu4Sye7TMTm6cAi_s` | `AWscLnwiE-XrXWF6TaEZbcV-2t4NaDZW8RoGbxLpsl4` |
| kat-session-bundle-001 | `sha256_hex` | `c577854d144c912e145e8ec6cbab09361ceb709a43be5cbd1ef538085b1aa5e5` | `b0e7a9e50cd88037992c19eded7cf7282a36d200c491f9d42e4bc9d623fe8bf0` |
| kat-session-bundle-001 | `sha256_b64url` | `xXeFTRRMkS4UXo7Gy6sJNhzrcJpDvly9HvU4CFsapeU` | `sOep5QzYgDeZLBnt7Xz3KCo20gDEkfnULkvJ1iP-i_A` |
| kat-session-bundle-001 | `coordinator_signature_b64url` | `czzmjpVf5rtZ2-FvfMcviSUCeY2WSu69v2ZECpflHAKVaEikz4w6m5fOVuBZkCL8DXX-lkY905NvYxjQTg_TBw` | `Bi3qnf2aSxg3Fyrv-T0XBX4xxUMchHLMfRI1C1rdQioRaTmL_B4X_t1nt7iDHUb9ePeFIi8fMQAWGdB8mPoDAw` |

**Verification.**

- `scripts/verify-known-answer.mjs`: 161 → 162 checks. The version literals are now read from the envelope schema `const`. env-011 is checked: its signature verifies over `sig_input_v2`, it differs from env-007 only in `version` and `message_id`, and the expected code is `UNKNOWN_VERSION`.
- `scripts/recompute-known-answer-independent.py`: 150 → 211 checks. It now re-signs the Ed25519 signed examples and vectors byte for byte as well (the kat-keypair-001 Manifest, snapshot, bundle, envelope and TCTs; the single-hop delegation; the multi-hop voucher, chain, digests, `chain_hash` and truncation; and the jcs-sha256 bodies) and env-011.
- `scripts/fixture-validation-map.json` maps env-011. Its envelope is expected to be schema-invalid, because the `version` const rejects `aitp/0.2`. `FIXTURE_INPUT_MIN_CHECKS` rises from 223 to 224.
- Conformance index: `core` 77 → 78, total 101 → 102.

### Envelope signing input v2: sign the whole envelope (#87)

**Change class.** Normative, wire-breaking change to the envelope signing input in RFC-AITP-0001 §5.4, with matching text in RFC-AITP-0002 §3.4, RFC-AITP-0012 §6, `docs/GLOSSARY.md` and `registries/message-types.md`. One known answer is re-minted, one is added, env-007 gets a committed signature and three core fixtures are added. Strict cutover: a verifier implementing this revision rejects envelopes signed over the old input, and the reverse. The `aitp/0.2` version literal is unchanged. PR 1 of 2 for #87 (proposal #89).

**The gap.** The envelope signing input was `message_id|timestamp|sender.agent_id|hex(sha256(JCS(payload)))`. It left `version`, `message_type` and `extensions` unsigned, so anyone on the path could change them without breaking the signature. The previous entry documented the gap; this one closes it.

**The fix.**

1. **RFC-AITP-0001 §5.4.** The envelope signs `sig_input_v2 = "aitp-envelope-v2" || 0x00 || JCS(envelope_without_signature)`: the 16 ASCII bytes of the domain tag, one zero byte, then the RFC 8785 form of the whole envelope minus `signature`. `d = sha256(sig_input_v2)` is signed per §5.4.6 and verified with the §5.4.7 strictness rules. Every member except `signature` is now covered, including `version`, `message_type` and `extensions`. The #88 sentences saying those members are not signed are removed. §5.2, the §5.4 profile table, §5.4.1 and §5.4.6 now describe the new input.
2. **Envelope check order (normative, RFC-AITP-0001 §5.4).** (1) `version`: an unknown value ⇒ `UNKNOWN_VERSION`, before schema validation. (2) Member set and structure ⇒ `UNKNOWN_FIELD` / `INVALID_ENVELOPE`. (3) Signature ⇒ `INVALID_SIGNATURE`. Steps 1 and 2 run after RFC-AITP-0009 §3.1's replay, rate-limit, timestamp and Content-Type/body-size steps, and step 3 is its envelope-signature step. RFC-AITP-0009 is not edited. §7 cross-references the order.
3. **RFC-AITP-0002 §3.4.** The pinned-admission rule that receivers MUST NOT rely on `message_type` being signed (added with #78) is replaced: the envelope signature now covers it. Step 4 of the §3.4 check order now follows the RFC-AITP-0001 §5.4 envelope check order. `id-015`, which expects `INVALID_ENVELOPE` at that step, is unaffected.
4. **RFC-AITP-0012 §6, glossary, message-type registry.** Envelope `extensions` and `message_type` are covered by the signature like any other member.

**Known answers.**

- `kat-envelope-001-p256` (`signed-examples/envelope/kat-keypair-005-envelope.json`, env-005's envelope) is re-minted. The file now carries `"signing_input": "sig_input_v2"`, `sig_input_v2_hex`, `sig_input_v2_len_bytes` and `sig_input_v2_sha256_hex` in place of `sig_input` and `sig_input_sha256_hex`.
  - Old: `sig_input` sha256 `899070806444e28a20a08e8621aa7d1b56346876b90e2110ca22db512e138bf6`; signature `p256.x8byAWOkPakdN1zUauZZWaBm0hacdCOcWJ236euSREtnL_wz-SQFm-p-c4WSoWv_aPRH6QAYP2QMSkNcoYvCiQ`; double-hash negative `p256.2q_zGfNz6HV1qtA1BDMsEb85Ixl7YrR1SG0Vq07fnktQ-D3G7j96yi33yokBEDiWUIi3At4QzVvGSmHBBTN04A`.
  - New: `sig_input_v2` 254 bytes, sha256 `18ef5b4a02d6bfb05ff93cd173c05d6be48f729e0aa296fbee982f4ba8f94885`; signature `p256.zpVe0l_qTePUWQ0q829FnebYx0S5IDrFWSKgp1hNuo173QViku6Ocsmy-TsDgPlbSKiEgBDh63kGcSAHm7E2dA`; double-hash negative `p256.XLbKANH7oZ0YUWvx2nUcQ4pReaYe5zHp6RTKWEijVrg7JQ3HTr88MAHSi0uIV134gVaMGAuD6x4qkhbM4bdM0Q`.
  - The old signature is kept as `_must_not_verify.v1_signature`, beside the v1 input it signs (`v1_sig_input`). It MUST NOT verify over `sig_input_v2`.
- `kat-envelope-002-ed25519` (new, `signed-examples/envelope/kat-keypair-001-envelope.json`) is env-007's envelope with its non-empty `extensions`, signed by kat-keypair-001: `sig_input_v2` 343 bytes, sha256 `f1b0e17ced992c275fc58068a564e1ba3dfdd319963bcd77cb9c516bcdc704a0`; signature `v9IsSYtz353H8F9RlXHwRh8g9rLoPa_KW5sHCBtOx3_AlZbWfMUqn-ReGckaic4PjcJGowRIb-tNAntRYqWgAw`. Its `_must_not_verify.v1_signature` is `9m2fJO0wxMk3xtffyKKR0TUwyKcNo7XF8HipC7DdOXDX4qGnUjFVB1XQ6Rufg0foC3Lwz7w61C65Qdt0XTNjAA`, the signature over the retired input.

**Fixtures.**

- `env-007` now commits the `kat-envelope-002-ed25519` signature in place of a placeholder, so `extensions` coverage is pinned by real bytes.
- New `core` fixtures, each env-007's envelope and committed signature with one member changed after signing: `env-008` renames an `extensions` key (`INVALID_SIGNATURE`), `env-009` changes `message_type` to `mutual_hello_ack` (`INVALID_SIGNATURE`), and `env-010` changes `version` to `aitp/9.9` (`UNKNOWN_VERSION`, which pins the version-first order). Under the v1 input all three changes would still verify. `PLACEHOLDERS.md` says runners MUST NOT re-mint these literals.
- Conformance index: `core` (v0.2-required) 74 → 77, total 97 → 101. The self-attestation row is corrected from 2 to 3: `tct-021` (#79) was never counted in it.

**Verification.**

- `scripts/verify-known-answer.mjs` (149 → 161 checks). For both envelope vectors it rebuilds `sig_input_v2` and requires the hex, length and digest. It verifies the signature, and requires that it does not verify over the untagged JCS or the v1 input. It requires `v1_signature` to verify over the v1 input and not over `sig_input_v2`, and checks the P-256 double-hash negative. For env-008 to env-010 it requires that exactly one member differs from env-007, that the committed signature fails over the changed envelope, and the expected codes.
- `scripts/recompute-known-answer-independent.py` (132 → 150 checks) re-signs both vectors and both v1 negatives byte for byte (python-ecdsa; RFC 8032 reference arithmetic), and checks env-007 to env-010 the same way.
- `scripts/fixture-validation-map.json` maps the three new fixtures. env-010's envelope is expected to be schema-invalid, because the `version` const rejects `aitp/9.9`. `FIXTURE_INPUT_MIN_CHECKS` rises from 220 to 223.

**Version bumps.** RFC-AITP-0001 0.2.13-draft → 0.2.14-draft; RFC-AITP-0002 0.2.10-draft → 0.2.11-draft; RFC-AITP-0012 0.2.2-reserved → 0.2.3-reserved.

### Envelope erratum: `version`, `message_type` and `extensions` are not signed in `aitp/0.2` (#87)

**Change class.** Normative correction to RFC-AITP-0001 and RFC-AITP-0012, plus matching wording in `docs/GLOSSARY.md` and the env-007 fixture text. No wire, schema, error-code, known-answer or fixture-outcome change.

**The gap.** RFC-AITP-0001 §5.2, the §5.4 profile table, §5.4.1, RFC-AITP-0012 §6, the glossary and env-007 all said envelope `extensions` are covered by the envelope signature. The §5.4 envelope signing input is `message_id|timestamp|sender.agent_id|hex(sha256(JCS(payload)))`. It covers none of `version`, `message_type` or `extensions`, and aitp-rs's tests assert the gap.

**The fix.** The text now states what the signing input covers. RFC-AITP-0001 §5.4 adds: receivers MUST NOT treat `version`, `message_type` or `extensions` as sender-authenticated, and MUST NOT base a trust decision on envelope `extensions`. Signing the whole envelope is proposed for `aitp/0.3` in #87.

**Version bumps.** RFC-AITP-0001 0.2.12-draft → 0.2.13-draft; RFC-AITP-0012 0.2.1-reserved → 0.2.2-reserved.

### Delegation and session-bundle fixtures carry signed issuer and coordinator Manifests (aitp-rs #237, #238, #239)

**Change class.** Conformance fixtures only: new fixture input fields, two new negative fixtures and the README, `PLACEHOLDERS.md` and validation-map entries that go with them. No RFC text, schema, error code or known-answer value changes.

**The gap.** RFC-AITP-0006 §4 step 1 and RFC-AITP-0011 §3 step 1 resolve each hop issuer's key from that issuer's Manifest, and RFC-AITP-0010 §5 step 5 checks a bundle signature against the coordinator's Manifest key. No `del-*`, `del-mh-*` or `bundle-*` fixture supplied those Manifests. A runner had to invent them, for example by deriving the key from the `aid:pubkey:` string or building stand-ins, and so no fixture could tell a Manifest-key verifier from one that takes the key from the AID.

**The fix.**

1. **`input.issuer_manifests`** (an array of Manifest bodies). `del-001`, `del-002`, `del-003`, `del-005`, `del-006` and `del-007` carry the Manifest of B (kat-keypair-002). `del-mh-001` to `del-mh-004` carry the Manifests of B and C (kat-keypair-002, -003). The voucher needs none, because A checks it against its own key (RFC-AITP-0006 §4 step 3). `del-004` stays frozen in the v0.1 shape.
2. **`input.coordinator_manifest`** (one Manifest body), the Manifest of the coordinator A (kat-keypair-001), in `bundle-001` to `bundle-006`.
3. Every Manifest is a full RFC-AITP-0003 body with `__VALID_POP_SIG__` and `__VALID_MANIFEST_SIG__` placeholders, minted with the key of its own `aid` exactly as for `man-*`. Nothing new is pinned.
4. **New negatives**, both `status: draft` under their family's feature. `del-mh-005` is del-mh-001 with C's Manifest swapped for D's (kat-keypair-004), so `chain[1]`'s issuer has no Manifest. `bundle-007` is bundle-001 with the coordinator Manifest swapped for B's. Both expect `KEY_RESOLUTION_FAILED` (RFC-AITP-0007 §1).
5. **README "Manifest inputs".** These fields are the verifier's whole Manifest source. A runner MUST NOT derive a key from the AID, synthesize a Manifest, or fetch one.
6. Conformance index: `draft` session bundle 6 → 7, multi-hop 4 → 5, total 95 → 97. `core` is unchanged at 74.

**Verification.** `scripts/fixture-validation-map.json` validates every new Manifest against `aitp-manifest.schema.json`, so the fixture-input floor `FIXTURE_INPUT_MIN_CHECKS` rises from 187 to 220. With the new fixtures, aitp-rs 0.15.0 passes every changed fixture. It fails `del-mh-005`, because its adapter still adds stand-in Manifests, and `bundle-007`, because it reports `SESSION_BUNDLE_INVALID`. Both are fixed on the aitp-rs side.

**Version bumps.** None.

### Pinned-admission and self-attestation follow-ups (#79)

**Change class.** Normative clarifications to RFC-AITP-0001, RFC-AITP-0002 and RFC-AITP-0005, a registry note in `registries/error-codes.md`, and one new extension-gated conformance fixture. No known answer is re-minted and no new signature is minted.

**The fix.**

1. **HTTP 429 is a MUST within the pinned-admission profile.** RFC-AITP-0002 §3.4 now requires a rate-limited challenge request or presentation to get HTTP 429 with no AITP error envelope, tightening RFC-AITP-0009 §3.1's SHOULD for this profile only. The core handshake is unchanged. The §3.4 check order, `id-022` (step 3 expects exactly 429) and `PLACEHOLDERS.md` now say the same.
2. **Trust-at-`iat` has a rejection code.** When a relying party's own records do not establish that a self-attestation's issuer key was trusted at `iat`, it rejects with `TCT_SIGNATURE_INVALID` (RFC-AITP-0005 §5.3 "Lifetime", §7.3 exception, §10.4). New fixture `tct-021` (`status: extension`, `feature: aitp-self-attestation`) presents `kat-tct-002` verbatim with every input as in `tct-020` except `trust_store`, which lists kat-keypair-003 but not the issuer. No new fixture input field was needed: `trust_store` already is the relying party's record of keys trusted at `iat`.
3. **"Structural" wording (editorial).** The attestation-shape, missing-statement-key and grant-context (`iss == sub`, marker grant) rejections run after the signature verifies, so RFC-AITP-0005 §5.3 and the `TCT_SIGNATURE_INVALID` registry row no longer call them structural; they reuse the TCT's signature-family code. No behaviour change.
4. **`CHALLENGE_REFUSED` transport.** `registries/error-codes.md` notes that `CHALLENGE_REFUSED` is the one code not delivered in an error envelope: it travels in the challenge's own transport. RFC-AITP-0002 §3.4 adds an informative HTTP mapping (503, `Retry-After`, body `{"error":"CHALLENGE_REFUSED"}`) and requires the refusal to be distinguishable from the per-source 429.
5. **Self-attestation claim string.** RFC-AITP-0005 §5.3 adds: an implementation that verifies attestations MAY claim "AITP v0.2 self-attestation" conformance and, if it does, MUST pass the fixtures gated on `aitp-self-attestation`. RFC-AITP-0001 §10 item 9 names both claim strings.

**Verification.** `scripts/verify-known-answer.mjs` (148 to 149 checks) and `scripts/recompute-known-answer-independent.py` (128 to 129 checks) both verify that `tct-021` carries `kat-tct-002` byte for byte, that its signature verifies, that only `trust_store` differs from `tct-020` and that it lacks the issuer, and both include `tct-021` in the self-attestation gating check.

**Version bumps.** RFC-AITP-0001 0.2.11-draft → 0.2.12-draft; RFC-AITP-0002 0.2.9-draft → 0.2.10-draft; RFC-AITP-0005 0.2.6-draft → 0.2.7-draft.

### RFC-AITP-0002 §2.2.1: the OIDC `cnf.jkt` JWK follows the AID's algorithm (#68)

**Change class.** Normative change to RFC-AITP-0002 §2.2.1 and §2.4, with a new core conformance fixture. No schema, error code or known-answer value changes.

**The gap.** §2.2.1 pinned the JWK behind the OIDC `cnf.jkt` to the Ed25519 OKP form "exactly", with a 43-character identifier, and §2.4 described `aud` as 43 characters. P-256 AIDs are mandatory to verify in v0.2 (RFC-AITP-0001 §5.3), so an OIDC-bound agent with a `p256` AID had no conformant `cnf.jkt`. RFC-AITP-0001 §5.4.4 called the convention algorithm-agnostic and "the same" as §2.2.1, which it was not.

**The fix (owner decision).**

- **§2.2.1** defers to RFC-AITP-0001 §5.4.4 and gives both forms. An Ed25519 AID uses `{"crv":"Ed25519","kty":"OKP","x":…}`, as before. A P-256 AID uses `{"crv":"P-256","kty":"EC","x":…,"y":…}`, where `x` and `y` are the unpadded base64url 32-byte big-endian coordinates of the decompressed SEC1 point in the `pubkey:p256` identifier. The RFC 7638 member order is stated for both. A verifier derives the form from the AID's algorithm. The known-answer note adds the P-256 case (`kat-jwk-thumb-005-p256`, `6uuEaX_87uMh4VKEtSDkENgjC0g7Evt6vliSnD7XSDE`).
- **§2.4** no longer says `aud` is 43 characters. `aud` is the verifier's AID in whatever algorithm form it has, compared byte for byte.
- **Schemas.** No change. No schema constrains the JWT's `aud` or `cnf.jkt`. Every `cnf.jkt` pattern elsewhere is `{43}`, which is right for any SHA-256 thumbprint, and the AID patterns already accept the `p256:` form.
- **Fixture `id-023`** (`status: core`, expected success). An OIDC identity whose sender and Manifest AID is `kat-keypair-005-p256`. The proof is the existing `__VALID_JWT__` placeholder, whose `cnf.jkt` recipe `PLACEHOLDERS.md` now spells out for both algorithms. No new placeholder or literal vector is minted. `make kat-verify` and `scripts/recompute-known-answer-independent.py` each rebuild the EC JWK from the sender AID and require `kat-jwk-thumb-005-p256`.
- Conformance index: `core` 73 → 74, total 94 → 95.

aitp-rs (`aitp-conformance` placeholder minting, `aitp-handshake` OIDC verification) and aitp-verifier-py (`jwk.py`, `minter.py`, `identity.py`) already derive the thumbprint from the AID's algorithm, so neither needs a change for `id-023`.

**Version bumps.** RFC-AITP-0002 0.2.8-draft → 0.2.9-draft.

### `ListRevoked` is the one REQUIRED issuer endpoint, advertised in the Manifest; `Verify` and `Revoke` become OPTIONAL (#67)

**Change class.** Normative change, at the patch position under `VERSIONING.md`'s pre-1.0 mapping. No artifact bytes, schemas, fixtures or known answers change.

**The gap.** RFC-AITP-0005 §11 said every TCT issuer MUST expose `Verify`, `Revoke` and `ListRevoked`. RFC-AITP-0001 §8 said those surfaces were "deployment-defined in v0.1" and required only the well-known Manifest and `handshake_endpoint`. RFC-AITP-0008 §1.4 had consumers poll `ListRevoked` without saying how they find it, and neither RFC pinned an advertisement field, although `rfc-aitp-0008.revocation_list_uri` was already registered.

**The fix (owner decision).**

- **RFC-AITP-0005 §11.** The table gains a Requirement column. `ListRevoked` is MUST. `Verify` (a convenience) and `Revoke` (an administrative surface, not a peer-protocol operation) are MAY. A TCT issuer MUST advertise its `ListRevoked` URL in its Manifest's `extensions` under `rfc-aitp-0008.revocation_list_uri`. A verifier MUST NOT reject a Manifest solely because the key is absent; the issuer's revocation status is then unavailable and the RFC-AITP-0008 §3 policy applies. Concrete paths stay deployment-defined. §10.3 points the revocation check at the advertised URL.
- **RFC-AITP-0001 §8.** The required-endpoint table gains the advertised `ListRevoked` URL (for TCT issuers, which every handshaking peer is). The stale "deployment-defined in v0.1" note and "the only paths v0.1 normatively requires" sentence now say v0.2 and list `Verify`, `Revoke` and delegation verification as OPTIONAL, deployment-defined surfaces. §10 item 6 adds serving the signed snapshot at the advertised URL.
- **RFC-AITP-0008 §1.4.** Issuers MUST serve and advertise `ListRevoked`; consumers SHOULD poll the URL advertised in the issuer's Manifest. A Manifest without the key is handled as revocation-unavailable under `revocation_policy.mode`, like an unreachable endpoint. §1.1 marks `Verify` as OPTIONAL.
- **Registries.** `rfc-aitp-0008.revocation_list_uri` stays Provisional in `registries/extension-keys.md` (Stable needs two interoperating implementations; only aitp-rs consumes it today), but its row now records that RFC-AITP-0005 §11 requires it. The `aitp.tct.verify.v1` and `aitp.tct.revoke.v1` capability rows now name the OPTIONAL operations they signal.
- **Docs.** `docs/integration-guide.md` marks the three operations' requirement levels.

**Signed examples not re-minted.** The RFC-AITP-0003 §2 Manifest example and the two signed-example Manifests under `schemas/conformance/known-answer/signed-examples/manifest/` carry `"extensions": {}` and so lack the key. They remain valid inputs to Manifest verification, which does not require the key; they are not re-minted.

**Version bumps.** RFC-AITP-0001: `0.2.10-draft` → `0.2.11-draft`. RFC-AITP-0005: `0.2.5-draft` → `0.2.6-draft`. RFC-AITP-0008: `0.2.8-draft` → `0.2.9-draft`. `rfcs/README.md`'s version-summary sentence is extended to match.

### Conformance placeholders: unmintable values fail, and the last runner-chosen keys are pinned (#77)

**Change class.** Conformance-runner and documentation change to `schemas/conformance/PLACEHOLDERS.md`. No RFC text, fixture bytes or known answers change.

**The gap.** A runner that could not mint a placeholder could substitute a sentinel, and negative fixtures then "passed" on garbage. aitp-rs did this for `id-006`, `del-004`, `id-001`/`002`/`003`, `mh-003`, `mh-004` and `mh-008` before fixing its runner. Three minting inputs were also left to the runner: the signing form of `__LEGACY_PINNED_PROOF__`, the other peer named by `__JWT_AUD_TARGETS_DIFFERENT_PEER__`, and the issuer key behind `__VALID_JWT_FROM_UNKNOWN_ISSUER__`. Two runners could mint different bytes for the same fixture.

**The fix.**

- **Unmintable placeholders.** A runner that cannot mint a placeholder MUST report the fixture as FAIL, or SKIP where it does not claim the fixture's operation. It MUST NOT substitute a sentinel and score the result.
- **`__LEGACY_PINNED_PROOF__`.** Pinned to the RFC-AITP-0001 §5.4.6 form: Ed25519 over SHA-256 of the ASCII bytes `message_id`, `|`, `timestamp` (decimal), signed by the presented pinned key. The legacy input is the only defect.
- **`__JWT_AUD_TARGETS_DIFFERENT_PEER__`.** The other peer is `kat-keypair-004`'s AID.
- **`__VALID_JWT_FROM_UNKNOWN_ISSUER__`.** The issuer key is the Ed25519 key from seed `0x55` × 32, which no `keypairs.json` entry uses. It MUST NOT appear in any trust-anchor list.

These match what aitp-rs (`aitp-conformance`) and aitp-verifier-py already mint, so neither implementation's results change.

**Version bumps.** None.

### The known-answer `ext` key becomes `io.agentidentitytrustprotocol.kat`, and each conformance fixture runs against fresh verifier state

**Change class.** Known-answer and conformance-runner change. No RFC text changes, and no protocol rule changes. Two known-answer tokens are re-minted, so their bytes change.

**The gap.**

- The self-attestation known answers carried their statement under the `ext` key `org.aitp.kat`. The reverse-domain convention of [`registries/extension-keys.md`](registries/extension-keys.md) implies the key's owner controls the domain. The project controls `agentidentitytrustprotocol.io`, not `aitp.org`.
- `PLACEHOLDERS.md` said verifier state (the nonce store, the `message_id` deny list, rate-limit counters) carries across a sequence's steps. Nothing said it must not carry across fixtures. `id-019` and `id-013` present the same `pop_nonce` (`AQIDBAUGBwgJCgsMDQ4PEA`) under the same `message_id`, so a runner that keeps one verifier for the whole suite fails whichever runs second. The aitp-rs implementation hit this.

**The fix.**

- **Extension key (owner decision).** `org.aitp.kat` becomes `io.agentidentitytrustprotocol.kat` in both self-attestation known answers, `tct-019` and `tct-020` (`expected_ext_key`), and both verification scripts. The key is not in the extension-key registry, since it is test-only.
- **Re-minted known answers.** The key is inside the signed claims, so the payload, the signature and the token change. Every other claim is identical: `ver`, `iss`/`sub`/`aud`, `iat` 1711900000, `exp` 4867660000, `grants` `["aitp.attestation"]`, `cnf.jkt` and the statement string. Each `jti` is derived over the vector id, not the claims, so it does not change.
  - `kat-tct-002-self-attestation` (EdDSA, kat-keypair-001), `jti` `327b37ab-9817-4e87-8cbe-dec5109497f5`. `tct-020` carries the new token verbatim.
  - `kat-tct-003-p256-self-attestation` (ES256, kat-keypair-005-p256), `jti` `44fc6843-33db-41a1-9d79-331a0f6db692`. The signature is over one SHA-256 of the signing input (RFC-AITP-0001 §5.4.6), RFC 6979 and low-S (§5.4.7). The `_must_not_verify.double_hash_jws` negative is regenerated over the new signing input.
  - `tct-019`'s token is a `__JWS_TCT__` placeholder whose `ext` carries only `com.example.note`, so only its `expected_ext_key` changes.
  - The new tokens supersede the candidate file in aitp-rs-seam at commit `bbb5fda`, which the entry below says they matched.
- **Fixture isolation.** The [`sequence` section](schemas/conformance/README.md#multi-step-sequence-form) of the conformance README gains a runner rule: each fixture MUST run against fresh verifier state, with no deny-list, nonce-store or rate-limit state carried in from another fixture. State persists only across the steps of one fixture's `sequence`. The reset mechanism is left to the harness. `PLACEHOLDERS.md`'s pinned-admission sequence row says the same.

**Tooling.** Both stacks reproduce the new tokens byte for byte: `scripts/verify-known-answer.mjs` (148 checks, unchanged) and `scripts/recompute-known-answer-independent.py`, which builds the claims from scratch (128 checks, unchanged). Neither holds a token string; each expects the new key in the `ext` statement.

**Version bumps.** None. No RFC names the extension key or carries the token strings: RFC-AITP-0005 §5.3 cites the known answers by vector id only.

### One-way pinned-key admission (RFC-AITP-0002 §3.4) and self-attestation TCTs (RFC-AITP-0005 §5.3) (proposal #72 Item 5)

**Change class.** Normative change, at the patch position under `VERSIONING.md`'s pre-1.0 mapping. It is additive with one tightening. It adds an OPTIONAL profile, a `message_type` value, a registry, an error code and a TCT form, none of which changes any existing artifact's bytes. The tightening: in a grant context, a verifier now rejects a self-issued TCT (`iss == sub`), and any TCT carrying the new `aitp.attestation` marker grant. No conformant handshake could produce either, since RFC-AITP-0004 TCTs are always peer-issued.

**The gap.** A `pinned_key` identity could be presented only inside the four-message Mutual Handshake. A deployment that admits agents to a single verifier (a gateway, a coordination host) had to run the whole handshake, or invent a one-shot exchange of its own. A bare §3.1 proof sent outside an envelope leaves the descriptor's `type`, `subject` and `extensions` unauthenticated. Separately, an agent had no defined way to sign a durable statement about itself in a portable token. Nothing in RFC-AITP-0005 said what a verifier does with a self-issued TCT. RFC-AITP-0012 §6 forbade trust decisions on any `ext` content, which ruled out a signed statement there.

**The fix.**

- **RFC-AITP-0002 §3.4 (new), the OPTIONAL `pinned-admission` profile.**
  - **Exchange.** An out-of-band challenge (informative shape `{pop_nonce, verifier_aid, expires_at}`) is answered by one `identity_presentation` envelope whose payload is exactly `{identity, pop_nonce}`. Rules 1–4 cover Challenge, Presentation, Verification and Consumption.
  - **Nonce rules.**
    - The nonce is exactly 16 bytes; any other length is `IDENTITY_FAILED` before any signature check.
    - It was issued in a challenge whose `verifier_aid` is the verifier's own AID (the proof's `receiver_aid_bytes`), and it is unexpired and unconsumed.
    - The atomic lookup-and-consume runs after every signature check. A consumed nonce is never accepted again, even under a fresh `message_id`.
    - The outstanding-nonce store is bounded. When it is full the verifier refuses new challenges with `CHALLENGE_REFUSED` and never evicts.
    - Per-source rate limiting follows RFC-AITP-0009 §3.1.
  - **Check order.** Nine steps: `message_id` deny list, then rate limit, then the rest. A wrong `message_type` is `INVALID_ENVELOPE`.
  - **Conformance.** A party implementing only this profile MAY claim "AITP v0.2 pinned-admission". It MUST NOT claim RFC-AITP-0001 §10 conformance.
  - **Fixtures.** The profile's fixtures are `status: extension` under `feature: aitp-pinned-admission`, not core: a default runner SKIPs them, and an implementation claiming the profile MUST pass them.
- **RFC-AITP-0005 §5.3 (new), self-issued attestation TCTs.**
  - **Form.** `iss == sub == aud` and the sole grant is `aitp.attestation`, a marker that confers no capability. The statement sits in `ext` under a namespaced key; a relying party rejects an attestation lacking the key it expects, and any attestation-shape defect, with `TCT_SIGNATURE_INVALID`. There is no distinct `typ`: anything other than `aitp-tct+jwt` is `TOKEN_TYP_MISMATCH`. `cnf` is required, and `jti` MAY be derived.
  - **Grant contexts** (RFC-AITP-0004 §4, §10, §11 and the RFC-AITP-0006 source TCT): `iss == sub`, or the marker, ⇒ `TCT_SIGNATURE_INVALID`, not `AUDIENCE_MISMATCH`. An issuer MUST NOT mint the marker with `iss ≠ sub`.
  - **Section changes.**
    - §7.2 step 5 gains the grant-context rule.
    - §7.3 gains an exception for a self-attestation without a Manifest: a relying party MUST NOT make a trust decision on it unless its own records show the issuer key was trusted at `iat`.
    - §9.1 and §10.4 say the TTL bounds and the passive Manifest-expiry skip do not cover attestations; only an explicit waiver does.
    - A note after the §4.1 examples marks `aitp.attestation` as the two-segment exception, and RFC-AITP-0004 §4.1 grant intersection is unaffected.
- **RFC-AITP-0012 §5/§6.** The self-attestation statement is the one normative use of `ext` in v0.2, so it is carved out of §6's "MUST NOT make a trust decision". It grants no capability.
- **RFC-AITP-0001.** The §5 intro and the §5.2 `message_type` row list `identity_presentation` and point to the new registry. §9 now reads "seven registries" and has a `message-types` bullet. §10 item 9 excludes from the mandatory fixture set the `status: extension` fixtures gated on the pinned-admission profile and on relying-party attestation verification; an implementation claiming either MUST pass the fixtures gated on it.
- **Registries.**
  - New [`registries/message-types.md`](registries/message-types.md) lists all nine envelope `message_type` values, with an "Adding a message type" procedure. A row is added to `registries/README.md`.
  - `capabilities.md`: an `aitp.attestation` row (Provisional) and a naming exception note.
  - `message-types.md`'s authentication note is informative: it points to RFC-AITP-0001 §5.4 and RFC-AITP-0002 §3.4 and adds no requirement.
  - `error-codes.md`: a new "Pinned-admission codes" section with `CHALLENGE_REFUSED` (retryable, core), in the same four columns as the other per-RFC sections. The `TCT_SIGNATURE_INVALID` description is widened to cover the structural defects, including the grant-context self-issued and marker cases.
  - The "six registries" enumerations in `CONTRIBUTING.md`, `governance/GOVERNANCE.md` and `governance/CHARTER.md`, and the `README.md` tree, become seven.
- **Schemas.** `aitp-envelope.schema.json` adds `identity_presentation` to the `message_type` enum. The `aitp-tct.schema.json` `exp` and `grants` descriptions mention the self-attestation waiver and the marker grant.

**New known answers** (`signed-examples/tct/`; each value was produced, and checked, by both the Node and the Python stack). Both tokens match byte for byte the candidate file in aitp-rs-seam at commit `bbb5fda`, whose marker grant is `aitp.attestation`. They differ from the earlier candidates at aitp-rs-seam commit `d5cb954`, which used `aitp:attestation`: the grant string is inside the signed payload, so the payload, the signature and the token all change. The re-minted tokens of the extension-key rename (entry above) supersede both: the `ext` key is inside the signed payload too, so neither candidate file matches the committed tokens any more.

- `kat-tct-002-self-attestation` (`kat-keypair-001-self-attestation.json`): EdDSA, kat-keypair-001, `jti` `327b37ab-9817-4e87-8cbe-dec5109497f5`.
- `kat-tct-003-p256-self-attestation` (`kat-keypair-005-self-attestation.json`): ES256, kat-keypair-005-p256, RFC 6979 and low-S, `jti` `44fc6843-33db-41a1-9d79-331a0f6db692`, with a double-hash token that MUST NOT verify.
- Both use `iat` 1711900000 and `exp` 4867660000. The `jti` is the RFC-AITP-0005 §2.2 derived UUID over the registered tag `aitp-kat-attestation-v1` and the vector id. The `ext` is `{"io.agentidentitytrustprotocol.kat":{"statement":"<id> archival attestation"}}`. As first merged, the key was `org.aitp.kat`; both tokens were re-minted under the new key (entry above).

**Fixtures.**

- `id-019`: pinned-admission success, with a real proof over the 193-byte tuple.
- `id-013`: nonce reuse under a fresh `message_id`, sequence form, both proofs real ⇒ `IDENTITY_FAILED`.
- `id-014`: a 15-byte nonce with a real proof over the 192-byte tuple ⇒ `IDENTITY_FAILED`, before any signature check.
- `id-015`: `id-019` with `message_type` `mutual_hello` ⇒ `INVALID_ENVELOPE`.
- `id-016`: a dynamic sequence. The outstanding-nonce bound is 2, the third challenge gets `CHALLENGE_REFUSED`, both earlier nonces then present, and the retry succeeds.
- `tct-015`: self-issued TCT in a grant context ⇒ `TCT_SIGNATURE_INVALID`.
- `tct-016`: the marker with `iss ≠ sub` ⇒ `TCT_SIGNATURE_INVALID`.
- `tct-018` (core): the marker beside, and after, an ordinary grant ⇒ `TCT_SIGNATURE_INVALID`.
- `id-020`: an expired nonce, with a real proof ⇒ `IDENTITY_FAILED`.
- `id-021`: a nonce whose challenge named another `verifier_aid`, with a real proof bound to `self_aid` ⇒ `IDENTITY_FAILED`.
- `id-022`: a sequence. A replay from a source that has used its one rate-limit slot gets `REPLAY_DETECTED`, because the deny list runs first; a fresh message from that source gets HTTP 429; the same message from a new source fails at the consumed nonce.
- `tct-019`: an otherwise valid attestation whose `ext` lacks the relying party's expected key ⇒ `TCT_SIGNATURE_INVALID`, through the new `verify_attestation` operation.
- `tct-020`: `kat-tct-002` itself, verified as an attestation by a third-party relying party ⇒ success. It pins the §5.3 rule that verifying an attestation is not a grant context.
- Gating: the eight pinned-admission fixtures (`id-013` to `id-016`, `id-019` to `id-022`) are `status: extension`, `feature: aitp-pinned-admission`. `tct-019` and `tct-020` are `status: extension`, `feature: aitp-self-attestation`, since consuming attestations is a relying-party role RFC-AITP-0001 §10 does not require. `tct-015`, `tct-016` and `tct-018` stay core, because the grant-context rejection binds every verifier.
- `PLACEHOLDERS.md` gains the `verify_identity_presentation`, `issue_presentation_challenge` and `verify_attestation` operations, the fixture inputs `now`, `presentation_rate_limit`, per-step `source`, `expected_ext_key` and `waive_manifest_cap`, an `http_status` expectation for a rate-limited step, a note that `verify_tct` is a grant context, and the `__ISSUED_NONCE_1__`, `__ISSUED_NONCE_2__` and `__VALID_PINNED_PROOF__` placeholders, which `normalize-fixture-input.py` classifies.
- The conformance index gains thirteen rows. `core` goes from 70 to 73, a new `extension` tier holds the ten gated fixtures, and the total goes from 81 to 94. The coverage notes name atomic consumption under concurrent presentations as not expressible by a sequential fixture.

**Tooling.**

- `scripts/verify-known-answer.mjs`:
  - verifies both new tokens, plus the ES256 double-hash negative;
  - `checkSelfAttestations()` recomputes each `jti` from the registered tag, checks iss == sub == aud, the sole marker grant, `cnf.jkt` against the issuer thumbprint, and the `ext` statement;
  - `checkPinnedAdmission()` re-verifies the `id-013`, `id-014`, `id-015` and `id-019` proofs against their tuples (`id-014` at 15 bytes), checks that `id-015` differs from `id-019` only in `message_type`, and checks the structure of `id-016`, `tct-015` and `tct-016` and the `CHALLENGE_REFUSED` registry row;
  - re-verifies the `id-020` and `id-021` proofs, checks that `id-022` reuses the `id-019` and `id-013` envelopes and its step order, checks `tct-018` and `tct-019`, verifies that `tct-020` carries `kat-tct-002` verbatim, and checks the extension gating of all ten gated fixtures;
  - `EXPECTED_MIN_CHECKS` 126 → 148.
- `scripts/recompute-known-answer-independent.py` builds both claim sets from scratch, re-mints the EdDSA token and the ES256 signature byte for byte (RFC 6979, low-S) along with the double-hash negative, re-signs the fixture proofs of `id-013`, `id-014`, `id-019`, `id-020` and `id-021`, and checks `id-022`, `tct-018`, `tct-019`, `tct-020` and the gating. It goes from 103 to 128 checks.
- `scripts/validate-json.sh`: `FIXTURE_INPUT_MIN_CHECKS` 156 → 187.
- `docs/GLOSSARY.md` gains entries for the pinned-admission profile, `identity_presentation`, the self-attestation TCT and `aitp.attestation`, and two concept-index rows.

**Version bumps.** RFC-AITP-0001: `0.2.9-draft` → `0.2.10-draft`. RFC-AITP-0002: `0.2.7-draft` → `0.2.8-draft`. RFC-AITP-0005: `0.2.4-draft` → `0.2.5-draft`. RFC-AITP-0012: `0.2.0-reserved` → `0.2.1-reserved`. Its status stays Reserved, but §5/§6 now carry normative text, the self-attestation carve-out. `rfcs/README.md`'s version-summary sentence is extended to match.

### `pinned_key` accepts P-256 keys; RFC-AITP-0002 §3.2 is five trust-store-gated steps; `issuer` is forbidden on `pinned_key` (proposal #72 Items 2 and 6c)

**Change class.** Normative change, at the patch position under `VERSIONING.md`'s pre-1.0 mapping. It adds a key type (P-256) to `pinned_key` and tightens verification. No conformant Ed25519 pinned proof changes: `kat-pinned-key-proof-001` and `id-007` keep their bytes. Two things a verifier accepted before are now rejected: a `pinned_key` descriptor carrying `issuer`, and any key-possession-only verification mode.

**The gap.** RFC-AITP-0002 §3 was Ed25519-only in prose ("the same 43-char … form") while the schema already allowed 44-char keys, and it never said whether a P-256 proof carries the `p256.` tag. §3.2 had three steps, none of which checked `identity.type`, compared `public_key` with `sender.agent_id`, or keyed the trust store by algorithm. It also allowed an opt-in possession-only `unsafe_no_trust_store` mode. Nothing forbade `issuer` on a `pinned_key` descriptor. The conformance pack had no passing pinned-key fixture.

**The fix.**

- **RFC-AITP-0002 §3.1.** `proof` uses the RFC-AITP-0001 §5.4.3 wire format with the §5.4.6 primitive. A `p256` sender MUST emit `p256.<86>`; an `ed25519` sender MAY emit untagged or `ed25519.`; the tag MUST match `sender.agent_id`'s algorithm, so an untagged proof from a `p256` sender is rejected.
- **RFC-AITP-0002 §3.2** is rewritten as five steps: confirm `type` is `pinned_key`; confirm `public_key` is byte-equal to the `sender.agent_id` key under the same algorithm; locate `(algorithm, public_key)` in `pinned_keys`; reconstruct `proof_input`; verify. Steps 1–3 MUST complete before any signature verification. The possession-only development mode is deleted: no deployment mode may offer it, and every pinned-key verification consults a configured store. The erratum's "§3.2 step 1" now reads step 3.
- **RFC-AITP-0002 §3.3.** `public_key` is 43 chars for `ed25519` or 44 chars (SEC1 compressed) for `p256`. SPKI-DER, PEM, JWK and uncompressed forms are not permitted. An invalid P-256 point, or the identity, is `IDENTITY_FAILED`. A P-256 example is added.
- **RFC-AITP-0002 §1.** `issuer` MUST be absent for `pinned_key`. `proof` is described as a §5.4.3 signature. A new informative note says a P-256 `pinned_key` `identity_hint` is valid.
- **RFC-AITP-0002 §4.** `pinned_keys` entries are keyed by `(algorithm, public_key)`, with an optional `algorithm`.
- **Schemas.**
  - `aitp-identity.schema.json`: the non-`oidc` branch adds `proof` pattern `^((ed25519|p256)\.)?[A-Za-z0-9_-]{86}$` and `not: {required: [issuer]}`. The `proof` description and the `pinned_key` example are updated (the example now passes the pattern), and a P-256 example is added. The `aitp-mutual-handshake.schema.json` mirror is updated to match.
  - `aitp-trust-anchors.schema.json`: `pinned_keys` items take an optional `algorithm` (`ed25519` | `p256`). When present it MUST match the key length (43 or 44).
- **GLOSSARY** (Identity descriptor) and **`registries/identity-types.md`** (`pinned_key` row) are updated to match.

**New known answers** (`jcs-sha256.json`, copied byte-for-byte from the proposal's candidate set):

- `kat-pinned-key-proof-002-p256`: the -001 tuple with the `kat-keypair-005-p256` sender and message_id `…440702`; 199-byte `proof_input`, digest `ab9942f8…dd3f`, proof `p256.X9FVRk-1…E-wr1Q`, plus a double-hash proof that MUST NOT verify.
- `kat-pinned-key-proof-003-tagged-ed25519`: the -001 tuple with the `aid:pubkey:ed25519:` spelling of `kat-keypair-003`; 201-byte `proof_input`, digest `933d816e…43da`, proof `pQFHOAiS…VeJ3Bg`.

**Fixtures.**

- New: `id-010` (P-256 success), `id-011` (untagged P-256 proof), `id-011b` (`oidc`-typed descriptor with a valid pinned proof; Item 6c), `id-012` (87-char uncompressed P-256 key), `id-017` (Ed25519 success, the positive counterpart of `id-007`) and `id-018` (`issuer` on `pinned_key`). The four failures expect `IDENTITY_FAILED`. `id-011b`, `id-012` and `id-018` are schema-invalid, so their map entries are `expect: invalid`.
- **Trust-store rule.** `input.trust_store` is an array of AID strings whose tags give the algorithm. Absent means an empty store, and the harness MUST NOT invent trust (conformance README, PLACEHOLDERS.md operation note). Every pinned-key failure fixture except `id-007` now trusts its sender, so it fails only for its named defect: `trust_store` is added to `id-004`, `id-005`, `id-006` and `mh-009`.
- `id-006` gets its own placeholder, `__PINNED_PROOF_OVER_WRONG_NONCE__` (PLACEHOLDERS.md, `normalize-fixture-input.py`). The shared `__INVALID_POP_SIG_OVER_WRONG_NONCE__` is unchanged, since `mh-008` uses it.
- `id-007`: its description and rationale cite §3.2 step 3, and the key is qualified as Ed25519.
- The conformance index gains the six rows; `core` goes from 64 to 70, and the total from 75 to 81.

**Tooling.**

- `scripts/verify-known-answer.mjs`:
  - checks -002 (proof_input, digest, strict P-256, the double-hash negative, and that the untagged form fails only on its tag) and -003 (tagged AID, both tag spellings verify, differs from -001);
  - new `checkPinnedFixtures()` re-verifies every reused proof against its fixture's own tuple, derives `id-012`'s uncompressed point from the sender AID, and enforces the trust-store rule;
  - `EXPECTED_MIN_CHECKS` 110 → 126.
- `scripts/recompute-known-answer-independent.py` re-signs -001, -002 and -003 byte-for-byte, verifies each pinned-key fixture's proof against its tuple (including `mh-009`'s), and recomputes `id-012`'s point with python-ecdsa.
- `scripts/validate-json.sh`: `FIXTURE_INPUT_MIN_CHECKS` 138 → 156.

**Version bumps.** RFC-AITP-0002: `0.2.6-draft` → `0.2.7-draft`. `rfcs/README.md`'s version-summary sentence is extended to match.

### P-256 signs a single SHA-256 digest (RFC-AITP-0001 §5.4.6), and verifiers are strict (§5.4.7)

**Change class.** Normative change, at the patch position under `VERSIONING.md`'s pre-1.0 mapping. §5.4.6 is a clarification: `sign()` was never defined for P-256, and the two implementations had read it two ways. §5.4.7 adds verifier MUST-reject rules. Neither changes any Ed25519 signature an RFC 8032 signer produces. It is a wire change for P-256 JCS signatures from implementations that hashed the digest twice. No interoperable P-256 JCS deployment can exist today, because the two existing implementations already disagree. No existing pinned value changes: every new vector is an addition.

**The gap.** RFC-AITP-0001 §5.4 wrote `sign(sender_private_key, sha256(sig_input))` and never defined `sign` for P-256. One reading feeds the digest to an ECDSA-SHA256 interface that hashes again (`e = SHA-256(SHA-256(input))`, aitp-rs). The other uses the digest as the hashed message (`e = SHA-256(input)`, aitp-verifier-py). Neither verifies the other's signatures. The spec also stated no malleability rule: aitp-rs rejected high-S P-256 and used strict Ed25519, while aitp-verifier-py and stock JOSE libraries accept high-S.

**The fix.**

- **RFC-AITP-0001 §5.4.6 (new).** Every JCS-profile and proof signature hashes its input once (`d = sha256(input)`). Ed25519 signs `d` as its message. P-256 uses `e = d`, which MUST NOT be hashed again; this is the same as ES256 over the pre-hash input. Signers MUST use a prehash interface. The §5.4 pseudocode now reads `d = sha256(sig_input)` and `signature = base64url(SIGN_alg(sender_private_key, d))`. §5.4.2, §5.4.3 and the §5.4.5 ECDSA paragraph point to §5.4.6 and §5.4.7.
- **RFC-AITP-0001 §5.4.7 (new).**
  - Ed25519: reject `S ≥ L`, non-canonical point encodings and small-order public keys; use the cofactorless equation. A verifier MAY also reject a small-order `R` (as ed25519-dalek `verify_strict` does), so that both strict libraries in use conform; no conforming signer produces one.
  - P-256: signers emit low-S, including when an external KMS or HSM signs; verifiers reject `S > n/2` and `R` or `S` that is 0 or ≥ n. KMS DER output is converted to raw `r || s`.
  - These rules apply to the JCS and JWS profiles alike. They do not apply to JOSE objects defined outside AITP (an IdP's OIDC ID token, an RFC 9449 DPoP proof), and replay caches for those objects MUST key on `nonce`/`jti`, not on raw token bytes.
- **RFC-AITP-0002 §3.1** cites §5.4.6 for the pinned-key `proof`; the pseudocode is unchanged. **RFC-AITP-0009 §4** cross-references §5.4.6–§5.4.7.

**New known answers.** Every P-256 value is signed with RFC 6979 deterministic `k` and low-S. Each carries a double-hash value that MUST NOT verify.

- `jcs-sha256.json`:
  - `kat-p256-jcs-sign-001` (digest `cee8d8fb…b17c`, signature `p256.SJXh3QaG…mdBk80g`, plus its high-S sibling);
  - `kat-manifest-pop-002-p256` (the `kat-manifest-pop-001` challenge signed by `kat-keypair-005-p256`).
- `keypairs.json`: `kat-keypair-001-tagged`, the `aid:pubkey:ed25519:` spelling of kat-keypair-001.
- New `signature-strictness.json`: `sig-001` (Ed25519 small-order key), `sig-002` (Ed25519 `S + L`) and `sig-003` (P-256 high-S). The checker asserts that a lax verifier accepts each one and the strict verifier rejects it.
- `signed-examples/`, signed by `kat-keypair-005-p256`:
  - `envelope/kat-keypair-005-envelope.json`, which is env-005's envelope with its signature filled in (`sig_input` digest `89907080…8bf6`);
  - `manifest/kat-keypair-005-manifest.json`, including the PoP;
  - `revocation/kat-keypair-005-snapshot.json`;
  - `tct/kat-keypair-005-issues-002.json` (ES256).
- New conformance fixture `tct-017-es256-high-s-rejected`: a literal committed high-S ES256 TCT that stock JOSE accepts. The expected result is `TCT_SIGNATURE_INVALID`.

**Tooling.**

- `scripts/verify-known-answer.mjs`:
  - verifies P-256 JCS and ES256 signatures and enforces §5.4.7 in BigInt, requiring agreement with `crypto.verify`; strict Ed25519 now applies to every existing Ed25519 check too;
  - checks every double-hash negative;
  - deep-compares env-005 against the envelope example;
  - checks the PoP of every Manifest example;
  - `EXPECTED_MIN_CHECKS` 66 → 110.
- `scripts/validate-json.sh`:
  - validates the new `envelope/` signed example;
  - strips every `_`-prefixed companion;
  - `FIXTURE_INPUT_MIN_CHECKS` 137 → 138.
- New `scripts/recompute-known-answer-independent.py` is a maintainer tool outside CI, like `regen-known-answer.py`. It uses python-ecdsa and pure-Python RFC 8032 Ed25519, and recomputes every new value from the committed inputs.
- READMEs updated: `known-answer/`, `signed-examples/`, the conformance index (`core` 63 → 64, total 74 → 75), and `PLACEHOLDERS.md`.

**Version bumps.**

- RFC-AITP-0001: `0.2.8-draft` → `0.2.9-draft`.
- RFC-AITP-0002: `0.2.5-draft` → `0.2.6-draft`.
- RFC-AITP-0009: `0.2.4-draft` → `0.2.5-draft`.
- `rfcs/README.md`'s version-summary sentence updated to match.

**Migration.** P-256 signers that pass `sha256(input)` to a hashing ECDSA interface switch to a prehash interface, and normalize S. P-256 verifiers add the low-S and range rejects. Ed25519 verifiers move to the strict profile.

### RFC-AITP-0005 §2.2: `jti` and `message_id` are strictly UUID v4, with a derived-identifier construction and a jti domain-tag registry (proposal #72 Items 6b and 6a)

Normative change. Two new fixtures, one new known-answer vector, one new registry, one schema tightening. No wire change for conformant issuers.

RFC-AITP-0005 §2 said "UUID v4" and `aitp-tct.schema.json` enforced the v4 pattern, but no verification step required the check and neither checked implementation enforced it. The spec was also silent on whether a deterministic, hash-derived `jti` was allowed.

- **RFC-AITP-0005 §2.2 (new).** `jti` MUST be a lowercase hyphenated RFC 9562 UUID v4 (version nibble `4`, variant bits `10`); a verifier MUST reject any other form before signature verification, with `TCT_SIGNATURE_INVALID` (the TCT's structural-rejection code; no new error code). The remaining 122 bits are either CSPRNG-random or **derived**: `h = SHA-256(domain_tag || 0x00 || input)`, identifier `h[0..16]` with `h[6] = (h[6] & 0x0f) | 0x40` and `h[8] = (h[8] & 0x3f) | 0x80`. Domain tags are printable ASCII, so the `0x00` separator keeps tags that are prefixes of each other apart. A verifier MUST NOT try to tell random from derived. §7.2 step 1's claims clause now carries the check. §8.1: the voucher's `src_jti` inherits the layout (structural code `DELEGATION_INVALID_VOUCHER`).
- **RFC-AITP-0001.** §5.2: `message_id` follows the same layout and is rejected otherwise, before signature verification, with `INVALID_ENVELOPE`. §11: the CSPRNG requirement covers `message_id` "unless derived per RFC-AITP-0005 §2.2". §9 listed "four registries" and omitted `extension-keys`; it now lists all six.
- **RFC-AITP-0009 §3** keeps its RNG sentence consistent with that exception, for `message_id` and TCT `jti`.
- **RFC-AITP-0011 §1 and §1.1** cite the RFC-AITP-0005 §2.2 layout for the per-hop `jti` (structural code `DELEGATION_INVALID_SIGNATURE`). "Fresh" is dropped, since a hop `jti` may be derived.
- **RFC-AITP-0002 §1 (Item 6a).** The descriptor note said verifiers reconstruct the pinned-key proof input from "the envelope plus the descriptor's `subject`", but the §3.1 `proof_input` does not contain `subject`. The note now says the pinned-key `subject` is not covered by `proof` and is authenticated only by the enclosing envelope signature.
- **`registries/jti-domain-tags.md` (new)** lists four tags with owner, derivation input and status: `aitp-kat-derived-uuid-v1` and `aitp-kat-attestation-v1` (AITP, test and known-answer use only), and `seam-tct-jti-v1` and `seam-pop-mid-v1` (zer07 Labs, seam-runtime). It is indexed in `registries/README.md`, CONTRIBUTING.md, `governance/GOVERNANCE.md`, `governance/CHARTER.md`, RFC-AITP-0001 §9 and the README tree.
- **Fixtures.** `tct-013` (a UUID v7 `jti`) and `tct-014` (version `4`, variant nibble `c`) are validly signed and expect `TCT_SIGNATURE_INVALID`. Both are schema-invalid, so their map entries are `expect: invalid`. The v0.2 core fixture count goes from 61 to 63.
- **Known answer.** `kat-derived-uuid-001` in `jcs-sha256.json` pins the tag, input, preimage, SHA-256 and resulting UUID `27b131ae-bcc6-4466-ab32-1d0f896453b1`. `make kat-verify` recomputes the UUID from the tag and input, checks that the tag is registered, and checks that dropping the separator or either bit mask would give a different value. `EXPECTED_MIN_CHECKS` goes from 62 to 66 and `FIXTURE_INPUT_MIN_CHECKS` from 130 to 137.
- **Schema.** `aitp-revocation-list.schema.json` entry `jti` goes from `format: uuid` to the v4 pattern the TCT schema uses. No committed value changes.
- **RFC-AITP-0008 §1** said `TCT_SIGNATURE_INVALID` "is reserved for cryptographic signature failure". That contradicted the structural-rejection table that `tct-013`/`tct-014` rely on, so it now reads "signature-family failure" and cites that table. This was stale wording; no behaviour changes.

Impact: verifiers that accepted any UUID version now reject non-v4 `jti` / `message_id` values, which the schemas already forbade. Issuers that derive identifiers must set the version and variant bits, which changes derived identifiers once. Recorded as a patch-position bump per `VERSIONING.md`.

**Version bumps.** RFC-AITP-0001: `0.2.7-draft` → `0.2.8-draft`; RFC-AITP-0002: `0.2.4-draft` → `0.2.5-draft`; RFC-AITP-0005: `0.2.3-draft` → `0.2.4-draft`; RFC-AITP-0009: `0.2.3-draft` → `0.2.4-draft`; RFC-AITP-0011: `0.2.1-draft` → `0.2.2-draft`; RFC-AITP-0008: `0.2.7-draft` → `0.2.8-draft`. `rfcs/README.md`'s version-summary sentence updated to match.

### RFC-AITP-0009 §3.1 / RFC-AITP-0004 §11.4: handshake rate limiting is one MUST, keyed on the transport (issue #69)

Normative change. No schema, fixture or wire change.

RFC-AITP-0004 §11.4 said "Implementations MUST apply rate limiting per source AID or IP"; RFC-AITP-0009 §3 listed it under SHOULD and §3.1 called it "RECOMMENDED, not REQUIRED". The owner decision (2026-10-16) is MUST, with the numeric defaults staying RECOMMENDED.

- **RFC-AITP-0009 §3 / §3.1** is now the single normative home. §3 moves rate limiting from the SHOULD list to the MUST list; §3.1 (heading `Rate limiting`, was `Rate limiting (RECOMMENDED)`) says implementations MUST apply per-source rate limiting, and that the default *values* are RECOMMENDED, not REQUIRED. The normative check order is unchanged.
- **Source key.** The key used before authentication MUST include a transport-level identifier (peer IP — from a forwarding header only behind a configured trusted proxy — or a TLS client-certificate fingerprint). A pre-verification `sender.agent_id` is self-asserted, so a per-AID limit MUST NOT be the only limit (it would let an attacker spend another agent's budget by naming its AID); per-AID limiting in addition is RECOMMENDED, and a global backstop MAY be added. The old "per source AID or IP" wording allowed an AID-only key.
- **RFC-AITP-0004 §11.4** cites RFC-AITP-0009 §3.1 and no longer repeats a default.
- `docs/operational-guidance.md` and `docs/threat-model.md` follow, including the renamed `#31-rate-limiting` anchor.

This is a tightening, recorded as a patch-position bump per `VERSIONING.md` (the minor position is reserved for the protocol revision). The one-way `pinned-admission` profile (proposal #72, Item 5) cites RFC-AITP-0009 §3.1 for its challenge rate limit.

**Version bumps.** RFC-AITP-0004: `0.2.4-draft` → `0.2.5-draft`; RFC-AITP-0009: `0.2.2-draft` → `0.2.3-draft`. `rfcs/README.md`'s version-summary sentence updated to match.

### Editorial: RFC-AITP-0001, RFC-AITP-0003 and RFC-AITP-0009 restate current v0.2 text

Editorial. No schema, fixture or wire change, and no RFC 2119 keyword added, removed or changed: each edit restates a rule already normative elsewhere in the RFC set.

- **RFC-AITP-0001.** Five sentences describing current behaviour still said "v0.1": §5.4.1's non-JSON-transport sentence, §5.4.2's PoP signing-input rule, §6's "no protocol capability object", and §8's normative-transport and non-JSON-binding sentences now say v0.2, matching §10 item 1 and RFC-AITP-0003 §3.1 ("every PoP signing input in AITP v0.2 hashes decoded bytes"). §8's operational-surfaces note cites RFC-AITP-0005 §11 (Peer-Issued TCT Verification API), not §10 (Consumer Rules); the rest of that note is unchanged.
- **RFC-AITP-0003.** §6.2 named Ed25519 as the only Manifest signing algorithm; it now points to RFC-AITP-0001 §5.4.3, which already lists the Manifest `signature` among the algorithm-tagged JCS fields and makes Ed25519 and P-256 both mandatory in v0.2. The §7 discovery-flow diagram gains §5 step 2 (structural and member-set check), which it had skipped, and names both §5 step 6 rejection codes.
- **RFC-AITP-0009.** §4's list of JCS-profile artifacts adds session trust bundles, matching RFC-AITP-0001 §5.4.

**Version bumps.** RFC-AITP-0001: `0.2.6-draft` → `0.2.7-draft`; RFC-AITP-0003: `0.2.6-draft` → `0.2.7-draft`; RFC-AITP-0009: `0.2.1-draft` → `0.2.2-draft` (editorial per `VERSIONING.md`). `rfcs/README.md`'s version-summary sentence updated to match.

### Docs refresh, part 2: top-level docs, release archive, and repository metadata brought to v0.2

Documentation, tooling-text and release-tooling change only. No RFC, schema, fixture or wire change.

- **README.** The maintenance-posture line now matches the [RFC index](rfcs/README.md): RFCs 0001–0011 are Draft (0010/0011 opt-in), 0012 Reserved, 0013 Planned, and nothing in the v0.2 line has reached Release Candidate (it previously said nothing in the repository had, which the v0.1 line's `0.1.0-rc.3` contradicts). The repository tree gains the files it omitted — `aitp-grant-voucher`, `aitp-session-bundle` and `aitp-conformance-fixture` schemas, the conformance fixture families, `known-answer/` and `PLACEHOLDERS.md`, `registries/extension-keys.md`, `governance/CHARTER.md`, `docs/ecosystem.md`, and the top-level CHANGELOG/VERSIONING/RELEASING/CONTRIBUTING files. The "Conformance profiles" table is removed: `aitp-a2a-peer`, `aitp-session-participant` and `aitp-full` were defined nowhere else; the section now cites RFC-AITP-0001 §10 and the fixtures' `feature`-flag opt-in. The release-workflow pointer goes to RELEASING.md (was CONTRIBUTING.md), the CI line names the eight-stage doc-coherence check, and a new **Ecosystem** section links `docs/ecosystem.md`, the SDK, independent verifier, playground and MCP entry points, and the published site.
- **`make release` builds from `git archive`.** The target now runs `git archive --format=zip --prefix=agentidentitytrustprotocol/ HEAD`, so the archive holds tracked files only. The old `zip -r` of the working tree depended on a hand-kept exclusion list (duplicated in RELEASING.md and the RFC process) that missed untracked local files such as `scripts/__pycache__/` (left behind by `make validate`), `.env` and local notes, and on the checkout directory's name. The CI release dry-run's grep is kept as a backstop for junk that gets *committed*, and widened to match.
- **RELEASING.md** rewritten for that target: current tag examples (`v0.2.0-draft`, `schema-v0.2.0`), the `## Unreleased` step as the changelog now uses it, what `make validate` actually runs, the `RELEASE_VERSION` default, and `scripts/zip-source.sh` described as a local snapshot tool, not a release path.
- **VERSIONING.md.** Its own five-row status ladder (with `Final` and `Deprecated`, neither of which is a lifecycle stage) is replaced by a pointer to the single ladder in `governance/RFC-PROCESS.md`; the RFC-version row and the `rfc-aitp-NNNN` tag rule no longer mention a `-final` suffix or "Final" status.
- **CHANGELOG.md** restructured: a `## Unreleased` heading now holds the post-`v0.2.0-draft` entries, the entries released in that tag sit under `## v0.2.0-draft`, and the untagged v0.1-line passes after `rc.3` get an H2 parent. Entries were moved verbatim; the only wording change is the issue #17 erratum, which cited a "Draft-to-Final gate" that no governance document defines. The missing entry for PR #35 (issue #31) is added.
- **CONTRIBUTING.md** lists all five registries and their actual status vocabularies (including `Reserved`, and `spec_status` for error codes), describes doc-coherence by pointing at the script header, lists 0010/0011 as Draft opt-in, 0012 Reserved and 0013 Planned (it called 0010 and 0011 "reserved"), and links RELEASING.md.
- **CODE_OF_CONDUCT.md** gains a Reporting section. No dedicated address exists yet, so it describes a no-details contact-request issue; a real address should replace it when one exists.
- **Makefile / CI / PR template text.** The Makefile header no longer says JCS is the signing input for everything (it names both profiles, RFC-AITP-0001 §5.4); `make docs` stops labelling the `docs/` guides "Normative", adds threat-model, non-goals, ecosystem and the Planned RFC-AITP-0013; `make help` and the CI step names describe the eight doc-coherence stages; the PR template checklist adds `make validate`, `make kat-verify`, `make doc-coherence` and a changelog entry.
- **Governance and metadata.** GOVERNANCE/CHARTER drop "proto", add `Reserved → Planned` to the lifecycle and list all five registries; RFC-PROCESS's template matches real RFC headers, the "new error codes" rule now says registry additions need no new RFC *document*, and its duplicated release steps are replaced by a link to RELEASING.md; DECISIONS no longer cites untracked `plans/` paths as live links; the 2026-07 errata file gets a correction note (the cited "Draft→Final two-implementations" gate does not exist); the manifesto's delegation sentence is v0.2 (grant voucher); `rfcs/README.md` adds the #43 and #59 bump reasons; the known-answer README's keypair count (Ed25519 ×5, P-256 ×1) and signed-examples row are corrected; `examples/revocation/README.md` cites RFC-AITP-0008 §1.2, not the nonexistent §1.6.
- **Doc-coherence guard rails (`scripts/check-doc-coherence.sh`, now eight stages).** Every stage now reads one shared file set — `git ls-files` in a git work tree, a filesystem walk otherwise — so untracked local notes (`plans/`, `temp/`, `PROGRESS.md`) are no longer scanned by the anchor stage, and an intra-repo link to an untracked file is reported as broken. The section-citation stage covers every tracked markdown file, not just `rfcs/` and `docs/` (README, CONTRIBUTING, VERSIONING, RELEASING, governance/, examples/, schemas/, registries/, manifesto/, and the `## Unreleased` part of this changelog; released changelog entries are history and are not re-checked). New stage 7 fails on v0.1-era tokens in `docs/*.md` and README.md: `grant_proof` and `binding.cnf` always, and `0.1.0-rc`, `aitp/0.1` and `v0.1` unless the paragraph or list item marks itself historical in-line with "legacy", "v0.1-frozen" or "v0.1 line" (wording, not an HTML comment, because `docs/` is synced to MDX). New stage 8 checks links into sibling repositories: `blob/main` only, no `/tree/`, no `aitp-cp`; when `../<repo>` is a local checkout it also verifies the path on that checkout's `origin/main` and any `#anchor` against its headings — offline, and skipped with a note in CI, which has no sibling checkouts. Stages 4 and 5 read the undefined `$PROJECT_ROOT` and so only worked when run from the repository root; they now use the script's root argument like the others. README's `aitp/0.1` mention now says "the v0.1 line" so it reads (and checks) as history.

### PR #65: `docs/` brought to v0.2, with sibling-repo docs linked instead of duplicated

Documentation change only; no RFC, schema, fixture or wire change.

- New `docs/ecosystem.md`: which sibling repository owns what (reference implementation and SDKs, independent verifier, control plane, playground, console, knowledge base/MCP server, website), one canonical link per concern, and the link convention (full `blob/main` URLs to sibling files; relative links in-repo).
- `architecture.md`, `discovery.md` and `GLOSSARY.md` rewritten for v0.2: the two signing profiles, grant-voucher delegation, the Manifest verification order, structural-rejection and status-ladder vocabulary.
- `implementer-quickstart.md` and `integration-guide.md`: the TCT verification order now mirrors RFC-AITP-0005 §7.2, and the hand-written verifier sample is replaced by links to the SDKs and the independent verifier.
- `operational-guidance.md`, `threat-model.md` and `non-goals.md`: unsupported claims removed (a "24 h / 8 renewals" reference default, IdP requirements and trust-penalty formulas that no RFC states); `fail_open` described per RFC-AITP-0007 and RFC-AITP-0008; the DPoP / RFC 8693 token-exchange non-goal added.
- `scripts/check-doc-coherence.sh`'s anchor stage skips absolute URLs, so sibling links with `#anchors` are not mistaken for intra-repo ones.

### Issue #61: `fail_open`, the third RFC-AITP-0008 §3.1 policy mode, gets a conformance vector

No schema, RFC, or wire change — this closes a conformance-pack gap, not a spec ambiguity.

**The gap.** RFC-AITP-0008 §3.1 defines three revocation-policy modes: `fail_closed`, `fail_open`, `soft_fail`. Only two had a pinned vector (`rev-001` for `fail_closed`, `rev-002` for `soft_fail`); the string `fail_open` appeared in no fixture at all. An implementation could alias `fail_open` to `fail_closed` (hard rejection instead of the degraded-but-successful verdict §3.1 describes) or treat it as unrecognized, and still pass the entire pack. Found during an `aitp-verifier-py` hardening pass and filed as issue #61.

**The fix.** New conformance vector `rev-009-fail-open-stale-snapshot`: identical input to `rev-002-soft-fail-safe-subset` in every field except `policy.fail_mode`, so the `rev-001`/`rev-002`/`rev-009` trio now pins all three §3.1 modes against one stale-snapshot shape with exactly one field differing. Expected outcome `success`, grants un-narrowed (unlike `soft_fail`, which restricts to a safe subset). `schemas/conformance/README.md`'s fixture index and summary counts (`core` 60 → 61, total 71 → 72) and `scripts/fixture-validation-map.json` updated to match.

### Issue #60: RFC-AITP-0006 §4 step 7's source-TCT revocation lookup gets a vector on the core single-hop path

No schema, RFC, or wire change — this closes a conformance-pack gap, not a spec ambiguity.

**The gap.** No fixture anywhere in `schemas/conformance/` exercised RFC-AITP-0006 §4 step 7 (the source-TCT revocation lookup) on the core single-hop delegation path. The only fixture touching step 7 at all was `del-mh-004-revoked-hop`, a `draft`, opt-in RFC-AITP-0011 multi-hop vector (`required_for_v0_2: false`). A v0.2 implementation that opts out of multi-hop could pass the entire required pack with step 7 unimplemented on the one path every core runner must exercise. `del-002` was also a permanently free id — `del-001`, `del-003`–`del-007` shipped, `del-002` never did. Found during an `aitp-verifier-py` hardening pass and filed as issue #60.

**The fix.** New conformance vector `del-002-source-tct-revoked`: `status: core`, `required_for_v0_2: true`, byte-identical to `del-001-success` except `voucher_claims.src_jti` is present in a `revocation_snapshots` record signed by A (the voucher issuer), using the same `{issuer_aid, snapshot}` shape `del-mh-004` already established. Expected `DELEGATION_SOURCE_TCT_REVOKED`. `PLACEHOLDERS.md`'s `del-*` row now documents `revocation_snapshots` (previously only the `del-mh-*` row did), with a note that core §4 names exactly one lookup — no per-hop sweep, no independent voucher revocation handle. `schemas/conformance/README.md`'s fixture index and summary counts (`core` 59 → 60, total 70 → 71) and `scripts/fixture-validation-map.json` updated to match.

### Issue #59: RFC-AITP-0003 §3.1 states the oidc-side `identity_hint` MUST NOT carry `public_key`, and a conformance vector pins it

Editorial. No schema or wire change — `aitp-manifest.schema.json`'s `$defs/IdentityHint` already forbade `public_key` on the `oidc` branch (`then.not.required`); the RFC's field table never said so.

**The gap.** §3.1's `identity_hint` row stated the two MUST-contain rules ("for `oidc` it MUST also contain `issuer`"; "for `pinned_key` it MUST also contain `public_key`") but never stated the oidc-side MUST-NOT. RFC-AITP-0002 §1 states the equivalent rule for the handshake's identity *descriptor* — a different object, exchanged with a live JWT proof in `MUTUAL_HELLO` — but nothing in RFC-AITP-0003 cross-referenced it for the Manifest's static `identity_hint`. `id-008` conformance-tests the descriptor; nothing tested the hint. Found during an `aitp-verifier-py` hardening pass and filed as issue #59.

**The fix.** §3.1's field table now states the oidc-side MUST NOT explicitly, with a cross-reference to RFC-AITP-0002 §1's rationale (the AID already encodes the public key, so a second copy is an ambiguity, not redundancy). New conformance vector `man-007-identity-hint-oidc-public-key-rejected` pins it: an otherwise well-formed Manifest whose `identity_hint` has `type: "oidc"` and also carries `public_key`, expected `MANIFEST_INVALID`. `schemas/conformance/README.md`'s fixture index and summary counts (`core` 58 → 59, total 69 → 70) and `scripts/fixture-validation-map.json` both updated to match.

**Version bump.** RFC-AITP-0003: `0.2.5-draft` → `0.2.6-draft` (editorial per `VERSIONING.md`). `rfcs/README.md`'s version-summary sentence updated to match. No other RFC's header moves.

### Issue #43: RFC-AITP-0010 §4.3.1 states the bundle HTTP body MUST be the wrapped envelope

Editorial. §4.3.1 is non-normative for Draft; this tightens its wording, it does not newly bind an unspecified surface.

**The ambiguity.** §4.3.1's path table described the POST/GET body as "the
`session_bundle` object defined in §3 (including the coordinator's
`signature`)." Read against §3's own field-table row for `signature` —
which states the `{"session_bundle": {…}}` form is "the HTTP/transport
envelope only" and the *signed* object is the inner value — "the
`session_bundle` object" could mean either the wrapped envelope or the
bare inner object, and the parenthetical no longer distinguishes anything
now that `signature` is a required member of the inner body (post the
schema-placement correction). Two reference-adjacent implementations
already disagree in practice: one accepts either shape at this endpoint,
the other requires the wrapped form and rejects a bare body.

**The fix.** §4.2 step 4 already settles this — the coordinator signs the
inner body, then "add[s] the wrapper only when transmitting" — so the wire
form, at every transport including this HTTP binding, is the wrapped
envelope. The path table now says so directly (MUST be wrapped; a bare
body MUST be rejected), and a new erratum blockquote records the
correction and its reasoning.

**Version bump.** RFC-AITP-0010: `0.2.4-draft` → `0.2.5-draft` (editorial
per `VERSIONING.md`). No other RFC's header moves.

### Issue #44: RFC-AITP-0005 §7.2 states the TCT's `typ`-before-claims-membership order explicitly

Editorial. No wire, schema, or fixture change; the ordering being clarified was already what `tct-010` tested.

**The ambiguity.** §7.2 step 1 ("Parse strictly") folded in the claims-set
membership check (the `UNKNOWN_FIELD` rule) and closed with "before any
cryptographic step below" — read literally, that places the membership
check ahead of step 2's `typ` enforcement, since `typ` enforcement isn't a
cryptographic step either. But `tct-010` requires the opposite: a grant
voucher presented as a TCT must be rejected with `TOKEN_TYP_MISMATCH`
*before* its non-TCT claims (e.g. `src_jti`) ever reach the membership
check, which would otherwise fire `UNKNOWN_FIELD` first. Both documents
were correct about *what* is checked; only the relative order between two
of step 1's own clauses was left to be reinterpreted per-implementation —
exactly the gap `aitp-rs`'s delegation code fell into on `/reconcile`
before being caught against `aitp-verifier-py` (no fixture exists for the
equivalent ordering on delegation tokens, RFC-AITP-0006 §4 — noted, not
fixed here).

**The fix.** Step 1's claims-membership clause now states explicitly that
it executes *after* step 2's `typ` enforcement, and step 2 cross-references
the same note, citing `tct-010` as the pinned example. Step numbers are
unchanged — RFC-AITP-0001 §7, RFC-AITP-0008 §3.3, RFC-AITP-0009 §1 and six
conformance fixtures cite them by number, and the PR that added the
`UNKNOWN_FIELD` check (see the "Issues #39 and #40" entry in this file)
already chose to fold the membership check into step 1 rather than
renumber for exactly this reason. RFC-AITP-0008 §3.3's own restatement of
the verification order is corrected to match (it had listed the membership
check ahead of `typ`, the same latent ambiguity from the other direction).

**Version bump.** RFC-AITP-0005: `0.2.1-draft` → `0.2.2-draft` (editorial /
clarification, per `VERSIONING.md`). No other RFC's header moves.

### Issue #50: README states its maintenance posture — single maintainer, best-effort, and what's actually stable

The README had no maintenance statement anywhere in it — the closest thing
was `governance/CHARTER.md`'s single sentence that the repository maintainer
acts in the Core Team's place until one is seated, three clicks from the
README and phrased as a fallback rule, not a status. A reader had no way to
learn bus-factor or stability tier without independently reading the
governance docs.

Adds a **Maintenance posture** section (after "Standards posture", before
"Capability negotiation"): status is maintained/single-maintainer/best-effort,
stated plainly and linked to `governance/CHARTER.md` and
`governance/RFC-PROCESS.md`; stability restates that the tagged `aitp/0.2`
line (`v0.2.0-draft`, `schema-v0.2.0` — issue #46) is still `Draft` on every
RFC per the status ladder (issue #47), with nothing yet at Release Candidate;
cadence is "changes land when a consumer needs them," which is what the
commit history actually shows.

### Issue #49: recorded the decision not to spec the DPoP / token-exchange surface yet

Docs only — no schema, RFC, vector, or tooling change.

`aitp-rs` ships ~1.4 kLOC of DPoP (RFC 9449) and OAuth 2.0 Token Exchange
(RFC 8693) code that no AITP RFC specifies, with no consumer, no conformance
fixture, and no recorded decision about whether to spec it. `governance/DECISIONS.md`
now records the decision explicitly: do not write an RFC for it now — the
surface is unconsumed, unspecified, security-relevant, and the maintenance
budget is one person — with the reversal trigger stated up front (a real
consumer brings the surface back with an RFC, not a retroactive description of
whatever shipped). The `aitp-rs`-side note is tracked there as `aitp-rs`#151.

### Issue #48: the decision log and the W-P5 errata record are now tracked

Docs only — no schema, RFC, vector, or tooling change.

`DECISIONS.md` (repo root) and `plans/spec-errata-from-independent-verifier-2026-07.md`
were both excluded from git — the first via `.git/info/exclude`, the second via
`.gitignore`'s blanket `plans/` rule — so neither was visible to anyone who cloned
this repo. The errata file is the canonical record of the W-P5 signing-input
divergence and had gone stale in the same way: it still asserted a pre-fix world
(errata "proposed", the cross-implementation gate "not satisfied") months after
every item in it shipped, and its own invisibility is what let that go unnoticed.

Both files move to `governance/` and are now tracked: `governance/DECISIONS.md`
and `governance/spec-errata-from-independent-verifier-2026-07.md` (filename
unchanged for the cross-repo tracking issues that already cite it by name). The
errata file is re-statused against the current trees — a new "Current status"
section up top corrects the stale claims, and every completed action item is
checked off — while its historical narrative is left intact as the record of
what was found and why each fix was chosen. `README.md`'s repository-layout
tree gains the two new entries. The rest of `plans/` stays gitignored; it is
in-flight working analysis, not a tracked record.

### Issue #47: one RFC status ladder, applied to all 13 RFCs, now CI-checked

Editorial. No normative, schema, or wire change; only how each RFC's own current stage is spelled.

**The defect.** Four incompatible status vocabularies existed across this
repo (`governance/RFC-PROCESS.md`'s formal `Idea → Draft → Review →
Release Candidate → Final Comment Period → Accepted | Rejected` ladder;
`rfcs/README.md`'s near-duplicate of it; a third, informal "Reserved" /
"Planned" pair used only in prose; and `registries/*.md`'s unrelated
`Proposed` / `Provisional` / `Stable` / `Deprecated` axis for individual
extension keys and capabilities — a genuinely different thing, left
untouched here). Nine of the thirteen RFC files' `**Status:**` header read
`Community Standards Track (v0.2 Draft)`, a string on **none** of the four
ladders; two more read bare `Draft`; nothing checked any of it.

**The fix.**
- `governance/RFC-PROCESS.md` is now the single normative source: the
  ladder diagram gains `Reserved` and `Planned` as named pre-`Idea`
  placeholder states (with real definitions — RFC-AITP-0012 and
  RFC-AITP-0013 both already have real, if non-normative, documents at
  those states, so "no document exists yet" would have been false; see
  the new stage descriptions for what actually distinguishes them), an
  `Idea` stage description is added (the diagram named it but the stage
  list never described it), and every stage now states the exact
  `**Status:**` string it implies.
- Every RFC's `**Status:**` header is normalized to
  `Community Standards Track (<Stage>)` for the 11 RFCs with real
  normative content, or bare `Reserved` / `Planned` for RFC-AITP-0012 and
  RFC-AITP-0013 (a placeholder number hasn't entered the track yet, so no
  track prefix). This drops the redundant `v0.2` — already recorded
  precisely by each RFC's own `Version:` header — rather than trying to
  make it part of the lifecycle vocabulary.
- `scripts/check-doc-coherence.sh` gains a sixth stage: every one of the
  13 RFC files, plus the repo `README.md`, must declare a `**Status:**`
  drawn from this exact ladder — and the *specific* stage each is expected
  to be at today (so RFC-AITP-0012 claiming `Draft` fails, not just an
  unrecognized string).
- `rfcs/README.md`'s status table, lifecycle section, and the version-
  coherence prose are updated to match; its previously self-contradictory
  "Planned (RFC number reserved, no document yet)" heading — followed
  immediately by "A stub document exists" — is corrected to describe what
  is actually true (a materially thinner stub than Reserved, not an
  absent document).

**Version bump.** All 11 non-placeholder RFCs take a patch bump (editorial
per `VERSIONING.md`) since their `**Status:**` line's text changed:
RFC-AITP-0008 `0.2.6-draft` → `0.2.7-draft`; RFC-AITP-0001 `0.2.5-draft` →
`0.2.6-draft`; RFC-AITP-0003 and RFC-AITP-0010 `0.2.4-draft` →
`0.2.5-draft`; RFC-AITP-0002 and RFC-AITP-0004 `0.2.3-draft` →
`0.2.4-draft`; RFC-AITP-0005 `0.2.1-draft` → `0.2.2-draft`;
RFC-AITP-0006, RFC-AITP-0007, RFC-AITP-0009, and RFC-AITP-0011
`0.2.0-draft` → `0.2.1-draft`. RFC-AITP-0012 and RFC-AITP-0013 are
unmoved — their `**Status:**` values did not change.

**Merge-time renumbering.** This PR's branch computed the bumps above from
`main` as it stood before issue #44 and issue #43 merged, so its own diff
lands RFC-AITP-0005 and RFC-AITP-0010 on the same version numbers those two
PRs *also* independently landed them on (`0.2.2-draft` and `0.2.5-draft`
respectively) — two distinct editorial changes computed from the same
starting point, not one. Collapsing them into a single bump would make a
consumer pinning `0.2.2-draft` unable to tell whether they have the §7.2
verification-order fix, the status-ladder normalization, or both.
Reconciled at merge time per `VERSIONING.md`'s per-document editorial-history
rule: RFC-AITP-0005 is `0.2.3-draft` (`0.2.1` → `0.2.2` issue #44 → `0.2.3`
this issue) and RFC-AITP-0010 is `0.2.6-draft` (`0.2.4` → `0.2.5` issue #43
→ `0.2.6` this issue). `rfcs/README.md`'s version-coherence sentence reflects
the reconciled numbers, not the numbers this PR's own diff originally stated.

**Not in scope.** `registries/extension-keys.md` and
`registries/capabilities.md`'s `Proposed` / `Provisional` / `Stable` /
`Deprecated` axis, and `registries/error-codes.md`'s `spec_status ∈
{core, draft}` axis, measure the lifecycle of individual registry
*entries* (one extension key, one capability string, one error code) —
a different thing from an RFC *document's* lifecycle, and forcing them
into this ladder would blur that distinction rather than fix anything.

### Issue #45: the three JCS signed examples now declare their own `signing_input`

Non-breaking, tooling only — no vector output, digest or signature changes.

The W-P5 signing-input convention ("the signing input is the inner artifact
body") was machine-readable on the `jcs-sha256.json` vectors via their
`signing_input` member, but not on the three real-signature fixtures under
`signed-examples/` (`manifest/`, `revocation/`, `session-bundle/`) that are
the actual cross-implementation regression detector. A reader holding one of
those files alone had to trust `scripts/verify-known-answer.mjs`'s hardcoded
`jcsArtifacts` table to know what was signed — the same kind of undeclared
convention that let `aitp-rs` read a wrapped object as the signing input in
the first place.

Each of the three files now carries a top-level `"signing_input": "body"`
companion, matching the vocabulary already established in `jcs-sha256.json`.
`verify-known-answer.mjs` reads and asserts it (three new checks;
`EXPECTED_MIN_CHECKS` 59 → 62) instead of only assuming the convention
in code, and `scripts/validate-json.sh`'s signed-example schema check now
strips `signing_input` alongside `_kat_input` before validating the fixture
against its wire schema. `signed-examples/README.md` documents the new
companion.

## v0.2.0-draft

Tagged `v0.2.0-draft` (and `schema-v0.2.0`) at commit `ea22c71` (PR #42). The entries below, newest first, are what that tag contains beyond the v0.1 line.

### Issues #39 and #40: structural-rejection codes, and one identity descriptor instead of two

Both issues came out of the same place — `aitp-verifier-py` implementing
RFC-AITP-0001 §7 across every artifact — and both are the same defect this
repo keeps finding: **one fact stated in two places with nothing checking
they agree.** #39 is a rule stated in the RFCs but not in the registry; #40
is an object defined in two schema files that had drifted apart.

#### #39 — a shape defect was being reported as a signature failure

**The gap.** The registry had a code meaning "this object's shape is wrong"
for some artifacts and not others. The envelope has `INVALID_ENVELOPE`; the
session bundle has `SESSION_BUNDLE_INVALID`. The Manifest had neither — the
closest code was `MANIFEST_SIGNATURE_INVALID`, which says the signature
failed when it was never reached, sending an operator to look at keys and
signing while the real defect is a missing member. The revocation snapshot
had no code family at all, for structure or signature, so implementations
borrowed `TCT_SIGNATURE_INVALID` — a code about an individual *token's* JWS,
used for the signed *list* that names tokens.

**Three new core codes.**

| Code | Artifact | Replaces the borrowed |
|---|---|---|
| `MANIFEST_INVALID` | Manifest failed schema validation | `MANIFEST_SIGNATURE_INVALID` |
| `REVOCATION_SNAPSHOT_INVALID` | Snapshot failed schema validation | `TCT_SIGNATURE_INVALID` |
| `REVOCATION_SNAPSHOT_SIGNATURE_INVALID` | Snapshot signature failed under the issuer's key | `TCT_SIGNATURE_INVALID` |

**The convention is now written down, which was the actual ask.** Issue #39
offered a fork: add codes, *or* state normatively that structural failures
collapse onto signature-family codes. The answer is both, because the two
apply to different artifacts. The registry gains a **Structural rejection**
section with a normative per-artifact table, and it records why the split
exists: the compact-JWS artifacts (TCT, voucher, delegation token) *do*
collapse onto their signature-family code — a payload that will not decode
into the expected claim set is indistinguishable to the caller from one
whose signature failed, and separating them leaks parse detail about an
unauthenticated token. The JCS-profile artifacts do not collapse, because
they are validated against a published schema and the caller is expected to
fix the object. That distinction was real in practice and written nowhere,
which is exactly how two implementations diverge and both believe they are
conformant.

**What did *not* change, deliberately.** A snapshot that is stale or
unreachable is **absent**, not invalid, so none of the new codes apply to
it. Under `fail_closed` an absent snapshot means revocation status is
unknown and unknown is treated as revoked — that is what fail-closed means —
so the underlying TCT is still rejected with `TCT_REVOKED`, as conformance
fixture `rev-001` has always pinned. `REVOCATION_UNAVAILABLE` was considered
and rejected: it would have changed a pinned fixture's expected code, and
"unknown ⇒ revoked" is the standard fail-closed reading rather than a defect.
RFC-AITP-0008 §3.1 now states this explicitly, since it was previously only
inferable from the fixture. `rev-001`'s own description also lost a hedge —
it offered `KEY_RESOLUTION_FAILED` as an alternative "depending on the call
site" while `expected.error_code` asserted exactly one code. A fixture that
names two acceptable codes pins neither.

#### #40 — the identity descriptor was defined twice and the copies disagreed

**The gap.** `aitp-identity.schema.json` and the `$defs/IdentityDescriptor`
inside `aitp-mutual-handshake.schema.json` describe the same object. Both set
`additionalProperties: false`, so any divergence is load-bearing. The issue
reported one: the canonical file reserves an `extensions` slot and the
embedded copy did not, so a descriptor carrying `extensions` validated
standalone and failed inside a handshake payload.

**The copy had drifted further than reported.** It was also missing the
`public_key` grammar and — the one that matters — the
`not: {required: [public_key]}` guard on the `oidc` branch. RFC-AITP-0002 §1
states that as a MUST ("v0.2 verifiers MUST reject an OIDC `identity`
descriptor that carries `public_key`", because the key is already in the
envelope's `sender.agent_id` and a second copy makes `cnf.jkt`'s binding
ambiguous). The canonical schema enforced it; the embedded copy did not — so
the MUST was unenforced in the only path where a descriptor actually
travels.

**Resolution: the canonical file wins, and the copy is now a mirror.**
RFC-AITP-0002 §1 already names `aitp-identity.schema.json` as canonical, so
the answer to "which is authoritative" was in the spec; nothing had ever
checked the other file against it. The identity descriptor is **not** an
exception to §7's "every signed object reserves an `extensions` slot" — the
section's field table now carries the `extensions` row that was missing,
which is what made the exception look plausible.

The mirror stays a copy rather than becoming a `$ref`: no schema in this
repo resolves a cross-file reference, so an offline validator needs exactly
one fetch per artifact, and a network-resolvable `$ref` would make every
schema's usability depend on `aitp.dev` serving each `$id`. Duplication is
the deliberate trade; the new check below is what makes it safe.

#### Tooling — a fifth coherence stage

`scripts/check-doc-coherence.sh` gains **stage 5, shared-definition
coherence**: an object mirrored into another schema's `$defs` must equal its
canonical definition, modulo the file-level metadata a subschema cannot
carry. Verified non-vacuous against three drift modes (slot removed, guard
removed, whole `$defs` entry deleted); each fails the build with the
specific key named. Stage 4 caught a fixture asserting an undefined code;
stage 5 catches a schema disagreeing with another schema. Same bug class,
one level further down.

#### Conformance — five fixtures

| Fixture | Asserts |
|---|---|
| `man-006` | Manifest missing REQUIRED `handshake_endpoint` ⇒ `MANIFEST_INVALID` |
| `rev-007` | Snapshot missing REQUIRED `published_at` ⇒ `REVOCATION_SNAPSHOT_INVALID` |
| `rev-008` | Snapshot signature invalid ⇒ `REVOCATION_SNAPSHOT_SIGNATURE_INVALID` |
| `id-008` | OIDC descriptor carrying `public_key` ⇒ `IDENTITY_FAILED` |
| `id-009` | Unknown key inside `identity.extensions` ⇒ **success** |

`man-006`/`rev-007` are deliberately distinct from `man-004`/`rev-005`: those
pin an *extra* member (`UNKNOWN_FIELD`, the more specific code), these pin a
*missing* REQUIRED one. `id-009` is the load-bearing one — it is the only
fixture that can catch an implementation that enforces §7 by rejecting every
unrecognized member, which passes every reject fixture while violating §7's
MUST-ignore half for this artifact. `id-008`'s map entry doubles as the
regression guard for #40: before the mirror was aligned, that artifact
validated. Fixture total 64 → 69 (core 53 → 58); fixture-input artifacts
121 → 130.

#### Version bumps — minor class, patch position

Per VERSIONING.md's pinned pre-1.0 position mapping: new error codes are a
backward-compatible addition (minor *class*), made inside protocol revision
`aitp/0.2`, so they take a patch-position bump. The registry's own Stability
note said "minor bump" without the class/position distinction — written
before that mapping was pinned — and is corrected here.

| RFC | Version | Change |
|---|---|---|
| RFC-AITP-0001 | `0.2.4-draft` → `0.2.5-draft` | §5.7 gains the three new codes |
| RFC-AITP-0002 | `0.2.2-draft` → `0.2.3-draft` | §1 gains the `extensions` row and the canonical/mirror note |
| RFC-AITP-0003 | `0.2.3-draft` → `0.2.4-draft` | §5 step 2 gains structural validation ⇒ `MANIFEST_INVALID` |
| RFC-AITP-0004 | `0.2.2-draft` → `0.2.3-draft` | §6 failure matrix gains three structural rows |
| RFC-AITP-0008 | `0.2.5-draft` → `0.2.6-draft` | §1.5 names both revocation codes; §3.1 states the fail-closed collapse |

No schema namespace change, no protocol-literal change: `aitp/0.2` and
`https://aitp.dev/schema/v0.2/` are unchanged. RFC-AITP-0003 §5's step
*numbers* are unchanged too — structural validation folds into step 2
alongside the member-set check rather than renumbering, because those
numbers are cited from RFC-AITP-0001 §7 and RFC-AITP-0004.

**Downstream.** Both implementations must adopt the new codes; issues filed
in `aitp-verifier-py` and `aitp-rs`. The `id-009` accept case is the one to
watch — an implementation modeling `identity.extensions` as anything other
than an open map will over-reject and still pass every reject fixture.

### Issue #37: `UNKNOWN_FIELD` — RFC-AITP-0001 §7's unknown-member rejection gets an error code and a step in every verification algorithm

**The gap.** RFC-AITP-0001 §7 has always stated a MUST with an explicit
security rationale: unknown JSON fields outside explicit `extensions`
namespaces MUST be rejected, because signed AITP objects depend on canonical
JCS representation and silently ignoring unknown fields creates signature
ambiguity across implementations (one peer hashes the field in, another
hashes it out, and the same wire bytes verify differently). But no error
code existed for the rejection — `INVALID_ENVELOPE` is envelope-scoped,
`SESSION_BUNDLE_INVALID` is a bundle aggregate fallback, and Manifest, TCT,
and revocation had nothing that fits — and no artifact RFC's numbered
verification algorithm carried the check as a step. An implementer told to
reject had no code to reject with and no step in the algorithm they actually
follow. (Found via issue #37: `aitp-verifier-py` added §7 enforcement across
every artifact and the entire conformance pack stayed green before and
after.)

**The code.** One deliberately generic core code, **`UNKNOWN_FIELD`** (not
retryable): a signed object carried a member outside its schema and outside
its `extensions` / `ext` extension namespace. One code for every signed
object rather than per-object `<OBJECT>_UNKNOWN_FIELD` variants — like
`UNKNOWN_VERSION`, the failing object is whichever one was being verified,
and the registry's naming-convention section now says so. The asymmetry §7
mandates is restated everywhere the code appears: sibling-of-namespace ⇒
reject with `UNKNOWN_FIELD`; inside-namespace ⇒ ignore, never reject. The
two spellings are called out explicitly: JCS-profile artifacts (envelope,
Manifest, handshake payloads, revocation snapshot, session bundle) use
`extensions`; the compact-JWS artifacts (TCT, grant voucher, delegation
token) use the `ext` claim, where the unknown member is an unknown *claim*
in the decoded payload.

**Per-artifact verification steps.** §7 states the rule universally, but
implementers follow each artifact's own numbered algorithm, so each one
gains the check explicitly, positioned before the cryptographic steps —
a malformed object is rejected before any signature verification is spent
on it, and no unknown member survives into a reconstructed JCS signing
input:

- `rfcs/RFC-AITP-0003-manifest.md` §5 — new **step 2 (Member-set check)**;
  old steps 2–5 renumber to 3–6. §3.2's `extensions` row upgraded from the
  v0.1-era "Unknown extensions MUST be ignored" wording to the house
  two-sided form naming the code; §10 notes that Manifest verification
  additionally returns the core `UNKNOWN_FIELD`.
- `rfcs/RFC-AITP-0004-mutual-handshake.md` §5 — **step 2 of each of the
  four payload procedures** is now the member-set check: extended in place
  in §5.1/§5.2 (which already had a "parse the payload" step 2), inserted
  as a new step 2 in §5.3/§5.4 (which had none), renumbering §5.3 steps
  2–7 → 3–8 and §5.4 steps 2–6 → 3–7. §6's failure-path table gains an
  `UNKNOWN_FIELD` row and its shifted step citations are corrected. All
  four payload `extensions` rows now name the code.
- `rfcs/RFC-AITP-0005-tct.md` §7.2 — the check is folded into **step 1
  (Parse strictly)** rather than inserted as a new step: the claims-set
  membership check is parse-time work, and §7.2's step numbers 2–6 are
  load-bearing (cited by RFC-AITP-0009 §1, RFC-AITP-0008 §3.3, and the
  `tct-002/003/004/008/009/010` and `rev-004` conformance fixtures), so
  folding avoids renumbering them. The step spells out the JWS mapping:
  the unknown member is an unrecognized *claim*, the namespace is `ext`
  (not `extensions`), and the protected header needs no separate check
  because §5.4.5 already pins it to exactly `alg` + `typ`.
- `rfcs/RFC-AITP-0008-revocation.md` §1.5 — the **Verification**
  paragraph now begins with member-set validation (wrapper carries exactly
  `revocation_list` + `signature`; body members are table fields or inside
  `extensions`) before any signature work; the `extensions` row names the
  code; §3.3's lookup-ordering parenthetical notes that "strict parse"
  includes the §7.2 step 1 unknown-claim rejection (its "steps 1–5"
  citation stays accurate).
- `rfcs/RFC-AITP-0010-session-trust-bundle.md` §5 — member-set validation
  is added as an explicit **unnumbered lead-in** that precedes every
  numbered step, deliberately not a numbered step because §5's step
  numbers are load-bearing (cited by §8's `BUNDLE_PARTICIPANT_TCT_INVALID`
  row and pinned by the `bundle-002`/`bundle-003` fixtures). §8 records
  that the rejection surfaces as the core `UNKNOWN_FIELD`, not a
  `BUNDLE_*` code; the §3 `extensions` row names the code. The pre-v0.2
  sibling-`signature` wrapper shape stays a §3/schema rejection
  (`bundle-004` pins `SESSION_BUNDLE_INVALID` for it), distinct from an
  unknown member inside the signed body.
- `rfcs/RFC-AITP-0001-core.md` — §7 keeps its security rationale verbatim
  and gains: the code itself, the explicit statement of the designed
  asymmetry, the `ext` spelling note for compact-JWS artifacts, and an
  index of the per-artifact steps above. §5.4.5's existing "unknown claims
  MUST be rejected" sentence gains the code. §5.7's envelope-level table
  gains the row. §5.2's field table gains the `extensions` row the
  canonical envelope schema has always defined (`aitp-envelope.schema.json`
  lists it; the prose table omitted it — the same prose/schema divergence
  class this repo keeps closing, surfaced here because `env-006`/`env-007`
  pin envelope-level behavior in both directions).

**Step-citation fixes forced by the renumbering.** RFC-AITP-0003 §5.1's
"step 5 above" and §10's "§5 step 5" → step 6; RFC-AITP-0004 §5.4's two
"§5.3 step 4" references → step 5, and §6's failure-table citations of
§5.3/§5.4 steps #2/#3/#4 → #3/#4/#5; and one citation outside the RFC set,
`schemas/json/aitp-manifest.schema.json`'s `accepted_trust_anchors`
description ("RFC-AITP-0003 §5 step 5" → "step 6" — a description string
only; no schema constraint changed).

**Registry and VERSIONING reconciliation.** `registries/error-codes.md`
gains the `UNKNOWN_FIELD` row in the core (envelope-level) table and in the
Mutual Handshake table, plus the naming-convention sentence covering bare
cross-object codes. This change is also the first to sit on the seam
between the registry's stability note ("new codes can be added without an
RFC") and VERSIONING.md's change classes ("backward-compatible addition —
minor RFC bump. … new error codes"), so both now state the relationship
explicitly: the registry note waives the need for a new RFC *document*,
while the change class governs how the `Version:` header moves on the
existing RFCs whose normative text gains the code. The two compose — no
new document, minor bump — and neither policy's substance changed.

**Conformance coverage — nine fixtures, in matched pairs.** Issue #37 was
opened because `aitp-verifier-py` added §7 enforcement across every artifact
and *the entire conformance pack stayed green before and after* — the rule
was normative but untested, so an implementation could ignore it and pass.
Each artifact family now carries a **reject/accept pair** exercising both
sides of the asymmetry with the placement of the unknown member as the only
variable, which is what makes the pair a test of §7 rather than of schema
strictness in general:

| Artifact | Unknown member outside the namespace | Unrecognized key inside it |
|---|---|---|
| Envelope | `env-006` (`trace_id`) → `UNKNOWN_FIELD` | `env-007` → success |
| Manifest | `man-004` (`deployment_region`) → `UNKNOWN_FIELD` | `man-005` → success |
| TCT (claims) | `tct-011` (`device_id`) → `UNKNOWN_FIELD` | `tct-012` (`ext`) → success |
| Revocation snapshot | `rev-005` (`list_owner`) → `UNKNOWN_FIELD` | `rev-006` → success |
| Session bundle | `bundle-006` (`coordinator_note`) → `UNKNOWN_FIELD` | `bundle-005` (pre-existing) → success |

The accept side is load-bearing, not padding: a runner that rejects *all*
unrecognized members passes every reject fixture while violating the
MUST-ignore half of §7, and only the accept fixture catches it. The TCT pair
uses `ext` rather than `extensions`, pinning the compact-JWS spelling in an
executable artifact. Each fixture is wired into
`scripts/fixture-validation-map.json` with its expected schema verdict —
`expect: "invalid"` with a stated reason for the five reject fixtures
(schema `additionalProperties` is the mechanism, and the map records why
that is the *correct* expected outcome rather than a defect), `expect:
"valid"` for the accept fixtures, so a schema that silently started
permitting unknown members would fail the map rather than pass it.
`schemas/conformance/README.md`'s tier table moves 55 → 64 fixtures (core
45 → 53, draft session-bundle 5 → 6) and every new fixture is listed in its
family table. `scripts/validate-json.sh`'s `FIXTURE_INPUT_MIN_CHECKS` floor
moves 110 → 121.

**Tooling — the registry gets a coherence gate.** Adding an error code
surfaced that nothing verified a fixture's asserted `error_code` actually
exists in `registries/error-codes.md`. A fixture could pin a code no
implementation could ever return — a typo, or a code renamed in the registry
and left behind here — and every stage stayed green: the same
one-fact-in-two-places-with-nothing-checking-they-agree shape as the version
and citation stages. `scripts/check-doc-coherence.sh` gains a fourth stage
cross-checking every fixture-asserted code against the registry (29 distinct
codes today, all resolving), fail-closed on a zero-scan like its siblings.
The direction is deliberately one-way: every code a fixture *asserts* must
be defined. A registry code no fixture exercises is a coverage question, not
a coherence defect, and is not checked here.


**Version bump summary — minor class, patch position.** A new error code is
a **backward-compatible addition** under VERSIONING.md's change classes,
which prescribe a *minor* RFC bump — unlike every prior entry in this file,
which was Editorial / patch. The position that bump lands in is a separate
question from its class, and this change is the one that forced it to be
answered: pre-1.0, the **minor position is reserved for the protocol
revision**. It moved `0.1.x` → `0.2.x` only because `aitp/0.2` was itself a
breaking revision. A minor-*class* change made **inside** an existing
protocol revision therefore takes a **patch-position** bump and records its
class here. Doing otherwise would put a `0.3.0-draft` document inside
protocol `aitp/0.2` — readable as a protocol break — and leave document
versions permanently offset once `aitp/0.3` arrives. VERSIONING.md now pins
this mapping explicitly (its Pre-1.0 position mapping note), with this
change as the worked example; the earlier draft of this entry flagged the
question as unresolved policy, and it is now resolved rather than left open.

The six RFCs whose normative text gains the code or a verification step
move:
`RFC-AITP-0001-core.md` `0.2.3-draft` → `0.2.4-draft`,
`RFC-AITP-0003-manifest.md` `0.2.2-draft` → `0.2.3-draft`,
`RFC-AITP-0004-mutual-handshake.md` `0.2.1-draft` → `0.2.2-draft`,
`RFC-AITP-0005-tct.md` `0.2.0-draft` → `0.2.1-draft`,
`RFC-AITP-0008-revocation.md` `0.2.4-draft` → `0.2.5-draft`,
`RFC-AITP-0010-session-trust-bundle.md` `0.2.3-draft` → `0.2.4-draft`.
The protocol literal is a separate layer and does **not** move: the wire
version stays `aitp/0.2`, the schema namespace stays
`https://aitp.dev/schema/v0.2/`, and each document's Status line still
reads "v0.2 Draft" — VERSIONING.md's RFC-version layer says the `Version:`
header "tracks each document's own editorial history, not the protocol
literal."

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

### Issue #17 erratum 1 / Issue #25: RFC-AITP-0002 §3.1 pinned-key `timestamp` encoding, §2.4 example nonce, and seven fixture nonces/one attacker AID

**Two independent defects, fixed together because the second was found while re-minting the first's artifacts.**

**1. `timestamp_be_8_bytes` → `timestamp_ascii_decimal` (signing-input change).** RFC-AITP-0002 §3.1 stated, through `0.2.0-draft`, that the pinned-key proof's `timestamp` field was an 8-byte big-endian signed 64-bit integer. `aitp-verifier-py` — the independent implementation written for issue #17 (the RFC process's Release Candidate → Final Comment Period promotion requires at least one implementation passing the core conformance tier) — could not reproduce the one pinned proof in the conformance pack, `id-007`, against that encoding. Both encodings were checked against `id-007`'s real Ed25519 signature (`kat-keypair-003`, seed `0xff×32`) before anything was changed: the ASCII-decimal string verifies, the big-endian packing does not. The byte-pinned artifact is the interop contract, so the prose moved to match it, not the reverse — the artifact has been ASCII-decimal since the original conformance commit; nothing was re-signed.

`id-007` alone never exercised this: its expected outcome is rejection at §3.2 step 1 (the key is absent from the local `pinned_keys` store), reached *before* proof verification, so a big-endian implementation could pass `id-007` — and the rest of the v0.2 conformance pack — without the defect surfacing. New vector `kat-pinned-key-proof-001` (`schemas/conformance/known-answer/jcs-sha256.json`) closes that gap: it pins the `(sender, receiver, message_id, timestamp, pop_nonce)` tuple, the resulting `proof_input` bytes (193 bytes), `sha256(proof_input)`, and the signature — reusing `id-007`'s signature verbatim — and additionally pins that the *same* signature does NOT verify when `timestamp` is instead packed as an 8-byte big-endian integer, so the encoding is machine-checked rather than read from prose. See the erratum blockquote added to RFC-AITP-0002 §3.1.

Old and new prose:

| | Old (`0.2.0-draft` and earlier) | New (`0.2.1-draft`) |
|---|---|---|
| §3.1 `proof_input` field | `timestamp_be_8_bytes` — envelope `timestamp` as an 8-byte big-endian signed 64-bit integer | `timestamp_ascii_decimal` — envelope `timestamp` as its UTF-8 base-10 ASCII decimal string (e.g. `1711900000` → `b"1711900000"`) |

**Classification: Editorial / patch bump, by analogy to the JCS-wrapper correction above — with a caveat.** No schema shape and no pinned bytes changed; the correction brings the prose into line with an artifact that was always right, which is the same shape of fix VERSIONING.md's editorial clause names for a vector that contradicts normative text. The caveat: that clause is written for the *opposite* direction (artifact was wrong, prose was right) and VERSIONING.md's "no schema or wire change" description does not cleanly cover this direction, because an implementation that correctly followed the *old* prose is producing wrong-by-the-real-contract signatures today and must change its wire behavior to interoperate — this is documented explicitly in the new erratum blockquote so it isn't missed. See the recommendation below on extending VERSIONING.md.

RFC-AITP-0002 moves `0.2.0-draft` → `0.2.1-draft` for this change.

**2. §2.4 example nonce, and seven fixture `pop_nonce`/`pop_nonce_echo` literals (issue #25).** Independently, seven `pop_nonce` literals across three handshake conformance fixtures violated the 22-character unpadded-base64url `PopNonce` pattern the schema enforces. All seven sit in semantic-failure fixtures where the nonce's specific value is incidental to the scenario; they are replaced with valid deterministic 22-character values, preserving the relation each fixture tests: `id-004`'s captured-vs-fresh nonces must differ, `mh-005`'s echoed nonce must differ from what was sent, `mh-008`'s echoed nonce must equal what was sent. RFC-AITP-0002 §2.4's worked OIDC example pins the same `nonce` value as `id-004`'s corrected fresh `pop_nonce` (both represent "the fresh nonce for this handshake") and moves with it — leaving the fixture alone would have recreated the prose-vs-artifact divergence pattern this repository keeps closing.

Also independently, `mh-002`'s attacker `sender.agent_id` / `manifest.aid` used an AID whose signing seed was never published, so no independent implementation could re-mint the fixture's `MANIFEST_SIGNATURE_INVALID` scenario (reaching it requires first producing a *valid* attacker PoP, per RFC-AITP-0003 §5's check ordering). A documented attacker keypair, `kat-keypair-006-attacker` (seed `0xAA×32`, `schemas/conformance/known-answer/keypairs.json`), replaces it. Nothing pinned elsewhere referenced the old AID.

Old and new values:

| Fixture / field | Old | New |
|---|---|---|
| RFC-AITP-0002 §2.4 example `nonce` | `Tm9uY2VfRnJlc2hfRm9yX1RoaXNfSGFuZHNoYWtl` | `AxwAx0m1v63X7ZsDG-3Npg` |
| `id-004` `original_pop_nonce` | `Tm9uY2VfQ2FwdHVyZWRfRnJvbV9PbGRfSGFuZHNoYWtl` | `xwCb5ctck4W8hev_1sxkEw` |
| `id-004` `pop_nonce` | `Tm9uY2VfRnJlc2hfRm9yX1RoaXNfSGFuZHNoYWtl` | `AxwAx0m1v63X7ZsDG-3Npg` |
| `mh-005` `sent_pop_nonce` | `QWdlbnRBUG9wTm9uY2VFeHBlY3RlZA` | `fRVe56NIsF6e0msvD0ORaQ` |
| `mh-005` `pop_nonce` | `QWdlbnRCUG9wTm9uY2VOZXcxMjhiaXQ` | `Vl4YHtl6OQcOdQiSlkaHhg` |
| `mh-005` `pop_nonce_echo` | `QXR0YWNrZXJTd2FwcGVkTm9uY2VWYWx1ZQ` | `xatQKgEJw3UX1Wu0PkqHOA` |
| `mh-008` `self_pop_nonce_sent_in_hello_ack` / `pop_nonce_echo` (same value, two fields) | `Yl9wb3Bfbm9uY2VfMTI4Yml0X2Jhc2U2NHVybA` | `awVp2Fly6Is8p899W-ALmw` |
| `mh-002` `sender.agent_id` / `manifest.aid` (same value, two fields) | `aid:pubkey:OzIbdL3LFp9yYMYFkru2PZtNYpQkoMWK_0ZAp18KKwY` | `aid:pubkey:5zTqbCtiV95yNV5HKqBaTEh-a0Y8Ap7TBt8vAbVja1g` (`kat-keypair-006-attacker`) |

None of these are pinned cryptographic values — no signature covers any of the seven nonces or the attacker AID in these fixtures (`mh-002`, `mh-005`, `mh-008` carry only placeholder signatures; `id-004`'s real signature is over the *captured* proof context, whose sender/receiver/message_id/timestamp did not change, only `original_pop_nonce`, and that signature is likewise a placeholder in the fixture). This is fixture hygiene restoring schema conformance and re-mintability, not a correction to a normative requirement.

**Classification: Editorial / patch bump.** No requirement changed; invalid example literals were replaced with valid ones carrying the same test relations. RFC-AITP-0002 moves `0.2.1-draft` → `0.2.2-draft` for the §2.4 nonce correction specifically (the fixture-only changes in `id-004`, `mh-002`, `mh-005`, `mh-008` do not themselves move any RFC's `Version:` header).

- `rfcs/RFC-AITP-0002-identity.md` §3.1 — `timestamp_be_8_bytes` → `timestamp_ascii_decimal`; new **Erratum** blockquote; **Replay resistance** blockquote qualified (the five *bound fields* are unchanged from v0.1, not the encoding) and its tuple corrected from four fields to five (`sender, receiver, message, timestamp, nonce`) — it previously omitted `timestamp` even though §3.1 binds it; new **Known-answer test** blockquote citing `kat-pinned-key-proof-001`. §2.4 example `nonce` corrected.
- `schemas/conformance/known-answer/jcs-sha256.json` — new vector `kat-pinned-key-proof-001`.
- `schemas/conformance/id-004-pinned-key-cross-peer-replay.json`, `mh-002-manifest-signature-invalid.json`, `mh-005-nonce-mismatch.json`, `mh-008-pop-verification-failed.json` — nonce/AID literals corrected per the tables above.
- `schemas/conformance/known-answer/keypairs.json` — new `kat-keypair-006-attacker` entry.

**Version bump summary.** RFC-AITP-0002 moves `0.2.0-draft` → `0.2.1-draft` (§3.1 timestamp erratum) → `0.2.2-draft` (§2.4 nonce correction), both Editorial / clarification per VERSIONING.md:24 (see the classification caveat on the first change, above). `rfcs/README.md`'s version sentence updated to name both corrections instead of only the §2.4 one.

**Recommendation on VERSIONING.md (not acted on — flagged for separate decision).** VERSIONING.md:24's editorial clause is written unidirectionally: it blesses a patch bump when "a known-answer vector or signed example contradicts the normative text" and "the artifact was wrong." The §3.1 change runs the other way — the artifact (the real, previously-committed `id-007` signature) was always right; the *prose* was wrong. I patch-bumped it here by analogy, consistent with how this same class of question was resolved for the JCS-wrapper correction earlier in this file, but recommend VERSIONING.md be reworded to state the rule bidirectionally — "whichever of the normative text or the pinned artifact is wrong moves to match the other" — rather than leaving the reverse direction to be inferred by analogy each time it recurs. This is a recommendation only; VERSIONING.md is unchanged by this entry.

### Issue #31 / PR #35: README brought to v0.2, the only version this repository contains

The README's masthead said `Version: 0.1.0-rc.3` / Release Candidate while every artifact in the repository was v0.2 (schemas pin `aitp/0.2` and `$id …/schema/v0.2/`; the RFCs were `0.2.x-draft`). Version becomes `0.2.0-draft` and Status `Draft`, matching `rfcs/README.md`. The canonical-signing-input line, which claimed JCS for everything, is taken from RFC-AITP-0001's own masthead (JCS for protocol-internal artifacts, compact JWS for portable trust artifacts). The compatibility model's `aitp/0.1` and `schema/v0.1/` lines are corrected; RFC-AITP-0010 and 0011 are described as opt-in drafts outside v0.2 core conformance; RFC-AITP-0005 and 0006 are described as compact JWS, with RFC-AITP-0005 also defining the grant voucher; the "Using AITP" note says JSON Schema codegen covers the JCS artifacts and the decoded JWS claims but not producing or verifying the JWS itself. The repository tree gains RFC-AITP-0013 and `examples/grant-voucher/voucher.json`.

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

## v0.1 line after `rc.3` (never tagged)

Two passes made after `v0.1.0-rc.3` and before the v0.2 migration. They were never released under a v0.1 tag; their changes first shipped as part of the `v0.2.0-draft` tag.

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
