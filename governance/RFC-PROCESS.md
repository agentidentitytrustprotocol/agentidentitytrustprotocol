# AITP RFC Process

AITP evolves through RFCs (Request for Comments). This document describes
the process for proposing, reviewing, and accepting changes.

---

## RFC Lifecycle

```
Idea → Draft → Review → Final Comment Period → Accepted | Rejected
```

### Stages

**Draft**
- Author opens a PR with a new file in `rfcs/XXXX-title.md`
- RFC is numbered sequentially
- Anyone may comment

**Review**
- RFC is discussed for a minimum of 14 days
- Core team triages and assigns a shepherd
- Shepherd is responsible for driving the RFC to resolution

**Final Comment Period (FCP)**
- Announced with a 7-day window
- No new substantive changes during FCP
- Core team votes

**Accepted**
- RFC is merged
- Corresponding spec changes are tracked in the RFC

**Rejected**
- PR is closed with explanation
- Rejected RFCs remain in the repository for reference

---

## RFC Template

```markdown
# RFC-XXXX: Title

- **Status:** Draft
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
