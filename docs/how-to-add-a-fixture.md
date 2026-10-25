# How to add a conformance fixture

A conformance fixture is one JSON file under `schemas/conformance/` that states an input and the outcome every conformant implementation must produce. The fixture format, the runner rules and the full index are in [`schemas/conformance/README.md`](../schemas/conformance/README.md). This page is the checklist for adding one.

Every fixture added here also reaches the implementations: after the merge, `notify-spec-consumers.yml` dispatches the new spec commit to each consumer, and the consumer's bump PR runs it ([CONTRIBUTING.md § Consuming the spec](../CONTRIBUTING.md#consuming-the-spec)).

## 1. Pick the id

Use the prefix for the surface under test (`env-`, `man-`, `mh-`, `id-`, `tct-`, `vch-`, `rev-`, `del-`, `del-mh-`, `bundle-`; see [Structure](../schemas/conformance/README.md#structure)) and the next free number. The file name is `<id>-<short-slug>.json`.

## 2. Write the fixture

Start from a fixture of the same prefix and keep the metadata block first ([Fixture Format](../schemas/conformance/README.md#fixture-format)):

- `rfc` names the most specific RFC the fixture exercises.
- `status` is `core` for behaviour every `aitp/0.3` implementation must have. Opt-in surfaces are `draft` or `extension` and name their `feature`.
- `description` says what the input is and what the verifier must do, citing the rule as `RFC-AITP-NNNN §X.Y`. The doc-coherence check resolves every such citation to a real heading.
- `expected.error_code` must be defined in [`registries/error-codes.md`](../registries/error-codes.md).
- Reuse the committed signed examples under `schemas/conformance/known-answer/signed-examples/` wherever possible. Values a runner computes at run time are written as the placeholder tokens in [`PLACEHOLDERS.md`](../schemas/conformance/PLACEHOLDERS.md).

## 3. Map its embedded artifacts

Every fixture MUST have a matching entry in `scripts/fixture-validation-map.json`, keyed by the fixture's `id` field (not its file name). `make json-validate` (`scripts/validate-json.sh`) treats an unmapped fixture as a build failure, never a silent skip: a validator that quietly skips what it does not recognise is worse than no validator at all.

For each artifact embedded in the fixture's `input` (a session bundle, TCT claims, a Manifest, …), the entry names:

- `pointer`: the RFC 6901 JSON pointer to the artifact inside the fixture.
- `schema`: the schema file under `schemas/json/` it must satisfy.
- `expect`: `valid`, `invalid`, or `invalid_known_defect`.
- `reason`: required whenever `expect` is not `valid`; says why the artifact is expected to fail validation.
- `wrap`: optional; re-wraps the artifact as `{KEY: artifact}` for a schema that describes the wrapped transport form rather than the body.

A fixture with no embedded artifacts to validate MUST say so with a `no_artifacts` entry naming a reason, instead of being left out.

`expect` is checked in **both directions**. An artifact declared `invalid` that starts validating fails the build exactly as loudly as one declared `valid` that stops validating. If you fix a fixture's underlying defect, update its map entry in the same commit.

Example entry:

```json
"bundle-002": {
  "artifacts": [
    {
      "pointer": "/input/session_bundle",
      "schema": "aitp-session-bundle.schema.json",
      "expect": "valid"
    }
  ]
}
```

`scripts/normalize-fixture-input.py` substitutes the placeholder tokens (`__VALID_A_SIG__`, `__NOW_PLUS_3600__`, …) before an artifact is checked against its schema.

## 4. Update the index and counts

In [`schemas/conformance/README.md`](../schemas/conformance/README.md):

- add a row to the matching table under [Fixture Index](../schemas/conformance/README.md#fixture-index);
- update the tier counts and the total under [Fixture summary](../schemas/conformance/README.md#fixture-summary).

If the fixture reuses committed known-answer examples, say which ones in its `$comment`, and add the cross-checks to both `scripts/verify-known-answer.mjs` and `scripts/recompute-known-answer-independent.py` (raising each script's `EXPECTED_MIN_CHECKS`).

## 5. Record it and validate

1. Add an entry under `## Unreleased` in [`CHANGELOG.md`](../CHANGELOG.md) naming the change class (fixture addition, core or opt-in) and the fixture id.
2. `git add` the new file. The doc-coherence check reads only tracked files, so an untracked fixture is invisible to it.
3. Run `make validate`. It must pass locally before you open the PR, exactly as CI runs it.
