# Conformance reports and badges

A conformance badge says that one implementation, at one version, passed the fixtures behind one claim, at one spec commit. This page defines the report a runner emits, the three claims a badge may show, and the rule that decides each one. A matrix or badge generator computes badges from committed reports with these rules; nobody awards them by hand.

## The report

A runner run against [`schemas/conformance/`](../schemas/conformance/README.md) emits one JSON document that validates against [`schemas/json/aitp-conformance-report.schema.json`](../schemas/json/aitp-conformance-report.schema.json) (`$id` `https://agentidentitytrustprotocol.io/schema/v0.3/conformance-report.json`). How a runner is invoked stays implementation-defined. The report format does not.

| Field | Meaning |
|---|---|
| `report_version` | `"1"`. Versions the report's shape, not the protocol. |
| `implementation` | `name`, `version` and `repository` (an `https://` URL) of the implementation tested, plus an optional full `commit`. |
| `runner` | Optional. The runner that drove the implementation, when it is a separate tool, for example `aitp-conformance` driving a Python adapter. |
| `spec` | `commit` (full SHA of this repository), `version` (the newest release tag at or before that commit, for example `v0.3.2-draft`) and `protocol` (`aitp/0.3`). |
| `fixtures_dir_digest` | Ties the report to the exact fixture files run. See [Fixture digest](#fixture-digest). |
| `features_enabled` | The fixture `feature` flags the run opted into. |
| `results` | One entry per non-`reserved` fixture: `id`, plus `status`, `feature` and `required_for_v0_2` copied from the fixture, the `outcome`, and optionally `error_code` (the code the implementation returned), `reason` and `duration_ms`. `reason` is required for any outcome but `pass`. |
| `totals` | Counts of each outcome for each tier (`core`, `extension`, `draft`). |
| `gates` | One entry per claim evaluated: `name` (the claim string), `passed`, `criteria` and, when it failed, the `blocking` fixture ids. |
| `generated_at` | RFC 3339 UTC time the run finished. |
| `provenance` | Optional `ci_run_url`: the public CI run that produced the report. |

Each result carries one of four outcomes:

| Outcome | Meaning |
|---|---|
| `pass` | The implementation produced the fixture's expected outcome and error code. |
| `fail` | It did not, or the adapter errored. |
| `skip` | The fixture was not run: its feature is not enabled, the adapter lacks the operation (`OP_NOT_SUPPORTED`), a side effect is not instrumented, or an enabled draft feature negates the assertion. |
| `excluded_by_role` | The implementation does not play the role the fixture tests, for example it never verifies a grant-context TCT. The `reason` names the role. |

`excluded_by_role` is not a `skip`. A skip says "could not run this"; a role exclusion says "this does not apply to what I am". Both block the core claim. A role exclusion of a core fixture never blocks an extension claim.

Reports are not signed. A signature would add a trust root that nobody has asked for. A report is trusted because anyone can reproduce it: the spec commit and fixture digest fix the input, and `provenance.ci_run_url` points to the public run.

## Claims

A badge shows one of the claim strings of [RFC-AITP-0001 §10](../rfcs/RFC-AITP-0001-core.md#10-conformance), and no others. There are no named conformance profiles: the profile names the README once listed were removed because no RFC defines them ([DECISIONS.md, 2026-10-08](../governance/DECISIONS.md#2026-10-08--docs-refresh-v02-reconcile-decided-by-opus-all-reversible)). A new claim needs the RFC process.

| Claim | Gated on | Rule (`criteria`) |
|---|---|---|
| `AITP v0.3` | Every `status: core` fixture with `required_for_v0_2: true` | `core-required-all-pass`: each has outcome `pass`. |
| `AITP v0.3 pinned-admission` | Every fixture with `feature: aitp-pinned-admission` ([RFC-AITP-0002 §3.4](../rfcs/RFC-AITP-0002-identity.md#34-one-way-pinned-key-admission-optional-profile-pinned-admission)) | `feature-all-pass`: the feature is in `features_enabled` and each has outcome `pass`. |
| `AITP v0.3 self-attestation` | Every fixture with `feature: aitp-self-attestation` ([RFC-AITP-0005 §5.3](../rfcs/RFC-AITP-0005-tct.md#53-self-issued-attestation-tcts)) | `feature-all-pass`: the feature is in `features_enabled` and each has outcome `pass`. |

Each claim is decided on its own fixture set. The core rule uses `required_for_v0_2`, the core-tier key of `aitp/0.3` (it keeps its old name, see [VERSIONING.md](../VERSIONING.md)), so `del-004`, a core fixture in the v0.1-frozen token shape, is reported but gates nothing. Draft fixtures (`del-mh-*`, `bundle-*`) gate no claim.

Rules a runner and a badge generator both follow:

- **A skipped core fixture blocks `AITP v0.3`.** That includes `OP_NOT_SUPPORTED`, as the [runner enforcement rules](../schemas/conformance/README.md#conformance-runner-enforcement-rules) already require.
- **A role-excluded core fixture blocks `AITP v0.3` only.** An implementation that verifies no grant-context TCTs can still earn both extension claims, and that is the honest result: a party that implements only the pinned-admission profile MAY claim it and MUST NOT claim RFC-AITP-0001 §10 conformance ([RFC-AITP-0002 §3.4](../rfcs/RFC-AITP-0002-identity.md#34-one-way-pinned-key-admission-optional-profile-pinned-admission)), and an attestation verifier MAY claim self-attestation on its own ([RFC-AITP-0005 §5.3](../rfcs/RFC-AITP-0005-tct.md#53-self-issued-attestation-tcts)).
- **A draft feature that negates a core assertion blocks `AITP v0.3` for that run.** With `experimental-multihop-delegation` enabled, `del-007` (which expects `DELEGATION_MULTIHOP_NOT_SUPPORTED`) is skipped, so the core gate fails. Run the core claim without draft features. The extension claims can share that run.
- **A runner evaluates `AITP v0.3` in every report,** plus every extension claim whose feature it enabled.
- **The core claim covers the fixtures,** which is item 9 of RFC-AITP-0001 §10. Items 1 to 8, among them the known-answer vectors, stay the implementer's own claim; report version 1 does not carry known-answer results.

The schema enforces the failing direction: a report whose gate says `passed: true` over a blocking result does not validate. [`scripts/check-conformance-report.py`](../scripts/check-conformance-report.py) checks the rest. It recomputes `totals` and every gate from `results`, checks that each gate's `passed` and `blocking` match, and, given `--fixtures-dir` at `spec.commit`, checks the digest and that the results cover exactly the fixtures with correctly copied metadata.

## Badges

A badge shows the claim string, the implementation and version, the spec `version` and short `commit`, and the date from `generated_at`, for example:

`AITP v0.3 · aitp-example 1.4.0 · spec v0.3.2-draft (308bb75) · 2026-10-24`

A badge is generated only from a report that:

1. validates against the report schema;
2. passes `scripts/check-conformance-report.py --fixtures-dir`, run against this repository's `schemas/conformance/` at `spec.commit`;
3. has the claim's gate at `passed: true`.

A badge never drops the spec commit or the date. A pass at one commit says nothing about a later fixture set.

## Fixture digest

`fixtures_dir_digest` is `sha256:` followed by the lowercase hex SHA-256 of a `sha256sum`-format listing of every top-level `*.json` file in `schemas/conformance/`. The listing has one line per file, `<lowercase hex SHA-256 of the file bytes>`, two spaces, the file name, and a newline. Lines are sorted by file name in byte order. The `known-answer/` and `reports/` subdirectories are not included. From a checkout:

```sh
cd schemas/conformance && LC_ALL=C sha256sum -- *.json | sha256sum
# macOS: LC_ALL=C shasum -a 256 -- *.json | shasum -a 256
python3 scripts/check-conformance-report.py --digest schemas/conformance
```

The first two print the bare hex value; the script prints it with the `sha256:` prefix.

## Samples

[`schemas/conformance/reports/`](../schemas/conformance/reports/) holds sample reports for a fictional implementation, generated from the fixtures at `308bb75`. `make validate` checks each one:

- `report-example.json`: a full implementation that earns all three claims.
- `report-example-extensions-only.json`: an attestation gateway that plays no grant-TCT, voucher, revocation, delegation or OIDC role. It earns both extension claims, and its `AITP v0.3` gate fails, listing the role-excluded fixtures under `blocking`.
- `invalid/`: a core skip under a passed core gate and a missing `spec.commit`, which the schema rejects, and totals that disagree with the results, which only the checker catches.

[`scripts/report-validation-map.json`](../scripts/report-validation-map.json) records what each sample must do. Like the fixture map, it is fail-closed: a file with no entry fails the build.
