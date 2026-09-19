# AITP RFC Process

AITP evolves through RFCs (Request for Comments). This document describes
the process for proposing, reviewing, and accepting changes.

---

## RFC Lifecycle

Every RFC in this repository is published under the **Community Standards
Track** — a community-governed process with no external standards-body
backing (see [CHARTER.md](CHARTER.md) for governance structure). This repo
defines no other track today; if one is ever added, it gets its own name
here rather than a second meaning for "Community Standards Track."

A numbered RFC file's `**Status:**` header MUST read exactly
`Community Standards Track (<Stage>)`, where `<Stage>` is one of the named
stages below — or, for the two placeholder states that precede a numbered
RFC having any content at all, the bare word `Reserved` or `Planned` (no
track prefix, since a reserved or merely-planned number has not entered
the track yet). `scripts/check-doc-coherence.sh`'s status-ladder stage
enforces this across all 13 RFC files.

```
Reserved → Planned → Idea → Draft → Review → Release Candidate → Final Comment Period → Accepted | Rejected
```

**Reserved**
- An RFC number is allocated and a document exists at its path — possibly
  written in real detail, with examples and worked cases (RFC-AITP-0012 is
  145 lines) — but its contents are explicitly non-normative for the
  current protocol revision (`aitp/0.2`): a future revision of *this same
  document* is expected to make it normative, rather than a new RFC
  superseding it.
- `**Status:**` reads bare `Reserved`.

**Planned**
- A stub document exists at the RFC's path — materially thinner than a
  Reserved document, explicitly self-described as a stub — naming what it
  will cover and pointing at the non-normative sketch (elsewhere in the
  spec, or inline) it will eventually formalize. Existing enough that
  other documents have a stable link to point at before the real document
  is written.
- `**Status:**` reads bare `Planned`.
- The distinction from Reserved is a matter of degree (how much of the
  mechanism is actually written down), not a bright line like "a file
  exists" — both RFC-AITP-0012 (Reserved) and RFC-AITP-0013 (Planned)
  have files, and both currently carry a handful of real MUST/MAY
  constraints on v0.2 implementations despite each calling itself
  non-normative. Neither is a numbered RFC's usual all-or-nothing
  normative/non-normative split; that pre-existing wrinkle is noted here
  rather than resolved, since resolving it changes those RFCs' actual
  content, which is out of scope for a status-vocabulary cleanup.

### Stages

**Idea**
- Discussed informally (an issue, a discussion thread) before any RFC file
  exists. No number is assigned yet.
- Not a numbered-RFC `**Status:**` value — an Idea has no file to carry one.

**Draft**
- Author opens a PR with a new file in `rfcs/RFC-AITP-XXXX-title.md`
- RFC is numbered sequentially
- Anyone may comment
- `**Status:**` reads `Community Standards Track (Draft)`

**Review**
- RFC is discussed for a minimum of 14 days
- Core team triages and assigns a shepherd
- Shepherd is responsible for driving the RFC to resolution
- `**Status:**` reads `Community Standards Track (Review)`

**Release Candidate (RC)**
- RFC text is considered substantively complete; further changes are limited
  to clarifications, editorial fixes, conformance fixture additions, and KAT
  vectors required by the KAT-requirement rule below
- Version header on the RFC file carries an `rc.N` suffix (e.g. `0.1.0-rc.3`);
  the `**Status:**` header on the RFC file reads
  `Community Standards Track (Release Candidate)`
- RC can iterate (`rc.1`, `rc.2`, …) as implementer feedback surfaces issues
- Multiple implementations SHOULD be in progress against the RC text
- Promotion to FCP requires:
  - all KAT vectors required by the rule below are present
  - the conformance fixture set is complete for every normative surface the
    RFC introduces (signing inputs, error codes, side-effect ordering, etc.)
  - at least one implementation passes the core conformance tier

**Final Comment Period (FCP)**
- Announced with a 7-day window
- No new substantive changes during FCP
- Core team votes
- `**Status:**` reads `Community Standards Track (Final Comment Period)`

**Accepted**
- RFC is merged
- `**Status:**` reads `Community Standards Track (Accepted)`
- Corresponding spec changes are tracked in the RFC

**Rejected**
- PR is closed with explanation
- Rejected RFCs remain in the repository for reference
- `**Status:**` reads `Community Standards Track (Rejected)`

---

## RFC Template

```markdown
# RFC-XXXX: Title

- **Status:** Community Standards Track (Draft)
- **Authors:** @handle
- **Created:** YYYY-MM-DD
- **Spec sections affected:** rfcs/RFC-AITP-XXXX-*.md

## Summary

One paragraph description.

## Motivation

Why is this needed? What problem does it solve?

## Design

Detailed proposal. Include schema changes and security implications.

## Alternatives considered

What else was considered and why was it rejected?

## Backward compatibility

How does this affect existing implementations?

## Open questions

Unresolved issues that need discussion.
```

---

## What Requires an RFC

- Any normative change to `rfcs/`
- New identity types
- Changes to the TCT schema
- New error codes
- Changes to security guarantees
- New JSON Schemas or breaking schema changes

What does NOT require an RFC:

- Fixing typos or clarifying non-normative text
- Adding conformance fixtures
- Adding examples
- Updating `docs/`

---

## RFC Acceptance Criteria

### KAT requirement

Any RFC that introduces a new **signing input, hash construction,
canonicalization step, or PoP pattern** MUST include at least one
known-answer test (KAT) vector. The vector MUST pin:

- The **preimage bytes in hex** (not just a description of how to
  construct them). When the construction is `sha256(base64url_decode(x))`
  — the convention used by every PoP site in v0.1 (see
  [RFC-AITP-0001 §5.4.2](../rfcs/RFC-AITP-0001-core.md)) — the preimage
  bytes are the *decoded* bytes, not the ASCII bytes of the base64url
  string. Publishing the preimage as hex eliminates the ambiguity that
  caused the alpha.4 PoP-nonce bug and the beta.1 Manifest-PoP bug.
- The **SHA-256 digest in hex** (or other hash output if the RFC
  introduces a new hash).
- The **base64url-encoded Ed25519 signature** under `kat-keypair-001`
  from [`schemas/conformance/known-answer/keypairs.json`](../schemas/conformance/known-answer/keypairs.json),
  if the construction terminates in a signature. RFCs that need a
  different keypair MAY use any pinned keypair from that file but MUST
  cite which one in the KAT entry.

KAT vectors live in
[`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json)
or a sibling file under the same `known-answer/` directory and are
the primary cross-implementation interop check for the RFC. An RFC
that introduces a new signing/hashing surface without a KAT will be
held in Review — there is no deterministic way for two
implementations to verify they agree on the construction, and history
shows that "looks right by reading" is not sufficient (see the
alpha.4 PoP nonce bug and the beta.1 Manifest PoP bug — both were
input-shape mismatches that a KAT would have caught immediately).

A KAT is not required for RFCs that only adjust process, governance,
documentation, or non-normative narrative text. It IS required for
any RFC that lands in `rfcs/RFC-AITP-*.md` and changes what bytes are
fed to a signing or hashing primitive.

**Enforcement.** PRs that introduce a new signing input, hash
construction, or PoP pattern without a corresponding KAT vector will
not be merged. This rule exists because the decode-before-hash
convention (`sha256(base64url_decode(x))`) is non-obvious from the
spec text alone and has caused two cross-implementation interop bugs
in v0.1 (handshake PoP nonce; Manifest PoP challenge). Reviewers
SHOULD reject any normative addition to a signing surface whose KAT
vector is missing or specifies the preimage in any encoding other
than hex.

**Per-PR checklist (signing-input changes).** Every PR that adds a new
signing input, hash construction, or PoP pattern MUST include at least
one Known-Answer Test vector in
[`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json)
(or a sibling file under `known-answer/`) pinning:

- the **preimage in hex** (raw decoded bytes — not the base64url ASCII string),
- the **SHA-256 digest in hex**,
- the **base64url-encoded Ed25519 signature** under `kat-keypair-001`
  (or a different pinned keypair from
  [`keypairs.json`](../schemas/conformance/known-answer/keypairs.json),
  cited in the KAT entry).

**Reviewer responsibility.** A reviewer MUST confirm the KAT vector was
**computed independently of the implementation being added in the same
PR** — typically by recomputing the digest from the published preimage
hex with a standalone tool (`openssl dgst -sha256`, `python -c
"import hashlib; ..."`, etc.) and verifying the signature with an
independent Ed25519 library. A KAT vector that was generated by the
same code path the PR introduces is not an interop check; it only
proves the code is self-consistent. PRs whose KAT vector lacks
independent verification MUST be returned for revision before merge.

**Draft-stage carve-out.** Draft RFCs (status `Draft` and not yet
RC) MAY publish without a KAT vector if the RFC explicitly notes the
deferral and lists the KAT vector as a blocker for promotion to
Release Candidate. RFCs are NOT permitted to leave Review for FCP
without a KAT vector when one is required by the rule above; the
carve-out is an editorial convenience, not an exemption. The
implementation work that produces the KAT — choosing pinned keypair,
canonicalizing the body, computing the digest, and signing — is
itself part of the cross-implementation interop check that promotion
to RC depends on.

---

## Core Team

The core team is responsible for shepherding RFCs and voting on acceptance.
See [CHARTER.md](CHARTER.md) for governance structure.

---

## Releasing AITP

The only sanctioned way to produce a release archive is `make release`.
See [RELEASING.md](../RELEASING.md) for the full procedure and CI guard
details.

1. **Bump version in `CHANGELOG.md`** — move the in-progress entry to a
   new versioned heading and start a fresh "Unreleased" block.
2. **Update RFC `Version:` headers** if any RFC content changed.
3. **Run `make validate`** to confirm JSON Schemas, examples, and
   conformance fixtures are clean.
4. **Run `make release`** to produce the sanctioned archive (excludes
   `.git/`, `__MACOSX/`, `.DS_Store`, `temp/`, `.claude/`, `CLAUDE.md`,
   `plans/`, `node_modules/`).
5. **Tag the commit** with the released version (e.g. `git tag v0.1.0`).
6. **Push the tag** and attach the archive to a GitHub Release.

CI rejects any PR whose tree contains `.DS_Store` or `__MACOSX/`.
