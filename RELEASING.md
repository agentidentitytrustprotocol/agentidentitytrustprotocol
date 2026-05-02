# Releasing AITP

The only sanctioned way to produce a release archive is `make release`.
Hand-built archives created with `zip -r` from the working tree have a
history of leaking `.git/`, `__MACOSX/`, `.DS_Store`, in-progress AI-
assistant scratch files (`/plans/`, `.claude/`, `CLAUDE.md`), and node
modules into the published artifact. The Makefile target excludes all of
those by default.

## Procedure

1. **Bump version in `CHANGELOG.md`.** Move the in-progress entry to a
   new versioned heading and start a fresh "Unreleased" block.
2. **Update RFC `Version:` headers** if any RFC content changed in this
   cycle. RFCs that did not change keep their existing version.
3. **Run `make validate`** to confirm JSON Schemas, examples, and
   conformance fixtures are clean.
4. **Run `make release`** to produce the sanctioned archive. The target
   excludes:
   - `*/.git/*`
   - `*/__MACOSX/*`
   - `*/.DS_Store`
   - `*/temp/*`
   - `*/.claude/*`
   - `*/CLAUDE.md`
   - `*/plans/*`
   - `*/node_modules/*`
5. **Tag the commit** with the released version (e.g. `git tag v0.1.0`).
6. **Push the tag** and attach the archive to a GitHub Release.

## CI guard

`.github/workflows/ci.yml` rejects any PR whose tree contains
`.DS_Store` or `__MACOSX/`. If CI fails on this step, run:

```sh
find . -name .DS_Store -not -path './.git/*' -delete
find . -name __MACOSX -type d -not -path './.git/*' -exec rm -rf {} +
```

before re-pushing.

## Override `RELEASE_VERSION`

The Makefile defaults to the next planned version. To produce an
ad-hoc archive with a different label:

```sh
make release RELEASE_VERSION=v0.1.0-rc.2
```

The output is written to `../agentidentitytrustprotocol-<version>.zip`.
