# Pull Request

## Summary

<!-- One-paragraph description of what this PR does and why. -->

## Type of change

- [ ] Spec clarification (non-normative)
- [ ] Normative change to an RFC (requires RFC process)
- [ ] JSON Schema change
- [ ] Conformance fixture
- [ ] Tooling / CI / docs

## Checklist

- [ ] `make validate` passes (runs all of the checks below, as CI does)
  - [ ] JSON Schemas validate (`make json-schema-validate`)
  - [ ] JSON examples and fixtures validate (`make json-validate`)
  - [ ] Pinned known-answer values verify (`make kat-verify`)
  - [ ] Docs stay coherent (`make doc-coherence`)
- [ ] `CHANGELOG.md` has an entry under `## Unreleased`
- [ ] Affected RFC is updated and version-bumped if normative
- [ ] Backward compatibility considered and documented

## RFC reference

<!-- If this PR implements or modifies an RFC, link the RFC and the related issue. -->
