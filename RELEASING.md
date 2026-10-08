# Releasing AITP

The only sanctioned way to produce a release archive is `make release`.
It runs `git archive --format=zip --prefix=agentidentitytrustprotocol/ HEAD`,
so the archive holds exactly the **tracked files of the committed tree** —
nothing untracked or ignored (local notes, `temp/`, `plans/`,
`__pycache__/`, `.env`, editor or OS files) can end up in it, and there is
no exclusion list to keep in sync. Hand-built archives created with
`zip -r` from the working tree have a history of leaking `.git/`,
`__MACOSX/`, `.DS_Store` and local scratch files into the published
artifact; do not use them.

Because the archive is built from `HEAD`, uncommitted changes are not
included — commit (and tag) first, then build.

`scripts/zip-source.sh` is **not** a release tool: it zips the whole
working tree (including untracked files) as a local source snapshot with a
timestamped name. Never attach its output to a release.

## Procedure

1. **Update `CHANGELOG.md`.** Rename the `## Unreleased` heading to the
   version being released (e.g. `## v0.2.1-draft`) and start a fresh, empty
   `## Unreleased` block above it.
2. **Update RFC `Version:` headers** if any RFC content changed in this
   cycle, and keep the version prose in [`rfcs/README.md`](rfcs/README.md)
   in step (the doc-coherence check enforces this). RFCs that did not change
   keep their existing version.
3. **Run `make validate`.** It runs, in order: JSON Schema meta-validation,
   validation of the examples and conformance fixtures (including the
   fixture-input cross-check driven by `scripts/fixture-validation-map.json`),
   known-answer verification (every pinned canonical byte sequence, key and
   signature recomputed), and the eight-stage doc-coherence check (stages
   listed in the header of `scripts/check-doc-coherence.sh`).
4. **Commit, then tag the commit.** Release tags in use are
   `v<version>` for the specification (e.g. `v0.2.0-draft`) and
   `schema-v<version>` for the canonical JSON Schemas (e.g. `schema-v0.2.0`);
   see [VERSIONING.md](VERSIONING.md#release-tags).
5. **Run `make release`** to produce the archive from the tagged commit.
6. **Push the tag** and attach the archive to a GitHub Release.

## CI guard

`.github/workflows/ci.yml`:

- rejects any PR whose tree contains `.DS_Store` or `__MACOSX/`. If CI
  fails on this step, run:

  ```sh
  find . -name .DS_Store -not -path './.git/*' -delete
  find . -name __MACOSX -type d -not -path './.git/*' -exec rm -rf {} +
  ```

  before re-pushing;
- runs `make release` as a dry run and lists the archive. A short
  backstop pattern (VCS metadata, OS junk, `__pycache__/`, `.env`,
  `node_modules/`, local scratch paths) fails the build if such a path ever
  gets *committed*, since `git archive` would then include it.

## Override `RELEASE_VERSION`

`RELEASE_VERSION` only sets the archive's file name. It defaults to the
current protocol release, `v0.2.0-draft`. To produce an archive with a
different label:

```sh
make release RELEASE_VERSION=v0.2.1-draft
```

The output is written to `../agentidentitytrustprotocol-<version>.zip`
(one level above the repository), and the archive's top-level folder is
always `agentidentitytrustprotocol/`.
