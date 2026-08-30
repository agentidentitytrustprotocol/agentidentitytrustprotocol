#!/usr/bin/env bash
#
# Validate AITP JSON examples and conformance fixtures against the published schemas.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENVELOPE_SCHEMA="${PROJECT_ROOT}/schemas/json/aitp-envelope.schema.json"
TCT_SCHEMA="${PROJECT_ROOT}/schemas/json/aitp-tct.schema.json"
IDENTITY_SCHEMA="${PROJECT_ROOT}/schemas/json/aitp-identity.schema.json"
DELEGATION_SCHEMA="${PROJECT_ROOT}/schemas/json/aitp-delegation.schema.json"
TRUST_ANCHORS_SCHEMA="${PROJECT_ROOT}/schemas/json/aitp-trust-anchors.schema.json"
MANIFEST_SCHEMA="${PROJECT_ROOT}/schemas/json/aitp-manifest.schema.json"
REVOCATION_LIST_SCHEMA="${PROJECT_ROOT}/schemas/json/aitp-revocation-list.schema.json"
SESSION_BUNDLE_SCHEMA="${PROJECT_ROOT}/schemas/json/aitp-session-bundle.schema.json"
FIXTURE_META_SCHEMA="${PROJECT_ROOT}/schemas/json/aitp-conformance-fixture.schema.json"
NON_NORMATIVE_DIR="${PROJECT_ROOT}/examples/non-normative"

CONFORMANCE_DIR="${PROJECT_ROOT}/schemas/conformance"
EXAMPLES_DIR="${PROJECT_ROOT}/examples"
KAT_DIR="${PROJECT_ROOT}/schemas/conformance/known-answer"
KAT_SIGNED_DIR="${KAT_DIR}/signed-examples"

echo "Validating AITP JSON artifacts..."
echo

if ! command -v ajv >/dev/null 2>&1; then
    echo "Error: ajv-cli is not installed"
    echo "Install with: npm install -g ajv-cli ajv-formats"
    echo "Or run: make install-tools"
    exit 1
fi

TOTAL=0
VALIDATED=0

# Plain JSON syntax check + (best-effort) schema match for files that look like
# the canonical objects. Conformance fixtures are scenario records — we do a
# syntax check only.

syntax_check() {
    local file="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$file"
    elif command -v node >/dev/null 2>&1; then
        node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$file"
    else
        return 0
    fi
}

# ── Conformance fixtures: syntax check + metadata block schema ──────────────
# Fixture scenario content (input/expected) is fixture-shape-specific; we
# syntax-check that, then validate the leading metadata block against
# aitp-conformance-fixture.schema.json so a v0.1 conformance runner can
# trust id / rfc / status / required_for_v0_1 / feature.
if [ -d "$CONFORMANCE_DIR" ]; then
    echo "── Conformance fixtures (${CONFORMANCE_DIR}) ──"
    for f in "${CONFORMANCE_DIR}"/*.json; do
        [ -f "$f" ] || continue
        TOTAL=$((TOTAL + 1))
        echo "  $(basename "$f")"
        if ! syntax_check "$f"; then
            echo "    ✗ Invalid JSON"
            exit 1
        fi
        if ajv validate -s "${FIXTURE_META_SCHEMA}" -d "${f}" --spec=draft2020 --strict=false -c ajv-formats >/dev/null 2>&1; then
            VALIDATED=$((VALIDATED + 1))
            echo "    ✓ Valid JSON + metadata block conforms"
        else
            echo "    ✗ Metadata block fails aitp-conformance-fixture schema"
            ajv validate -s "${FIXTURE_META_SCHEMA}" -d "${f}" --spec=draft2020 --strict=false -c ajv-formats || true
            exit 1
        fi
    done
    echo
fi

# ── Conformance fixture INPUTS: validate each artifact against its schema ────
# The metadata loop above checks a fixture's id/rfc/status block. It never looks
# at `input`, which is where the artifacts live — and that gap is why a schema
# and the fixtures it describes were able to disagree about the session bundle's
# signature placement through a full release. This stage closes it.
#
# The contract is fail-closed, because a validator that silently skips is worse
# than no validator at all — it reports success over the thing it did not look at:
#
#   * every fixture MUST have an entry in scripts/fixture-validation-map.json;
#     a new fixture with no entry is an ERROR, not a skip
#   * every map entry MUST name a fixture that exists; stale entries are an ERROR
#   * `expect` is checked BIDIRECTIONALLY — an artifact declared invalid that
#     starts validating fails the build exactly as a valid one that stops does
#   * a fixture with no artifacts MUST say so explicitly, with a reason
#   * an unrecognized placeholder token is an ERROR (see normalize-fixture-input.py)
#   * every schema the map names must compile before anything is validated
#     against it — ajv exits 1 for both "schema is broken" and "document is
#     invalid", so a schema that stopped compiling would otherwise satisfy every
#     negative expectation vacuously
#   * every decoded-claims companion the normalizer strips must itself be
#     validated somewhere in the map — a companion that is stripped and never
#     checked is exempt from validation entirely
#
# One gap remains, and is named here rather than papered over: the unmapped-file
# check sees a new fixture *file*, and the companion audit sees a new
# decoded-claims companion anywhere in an existing fixture document — but a
# plain JCS artifact (envelope, manifest, bundle, snapshot) added as a new key
# inside an already-mapped fixture trips neither, since the floor only ever
# rises and there is no naming convention (unlike `_claims`) to key a check
# off of. That case is caught by review, not by this stage.
#   * at least FIXTURE_INPUT_MIN_CHECKS validations must actually run
#
# Lower FIXTURE_INPUT_MIN_CHECKS only in the same commit that removes fixtures,
# and say why in the commit message — the same rule verify-known-answer.mjs uses
# for EXPECTED_MIN_CHECKS.
FIXTURE_INPUT_MIN_CHECKS=130
FIXTURE_MAP="${SCRIPT_DIR}/fixture-validation-map.json"
NORMALIZER="${SCRIPT_DIR}/normalize-fixture-input.py"

if [ -d "$CONFORMANCE_DIR" ]; then
    echo "── Conformance fixture inputs vs artifact schemas (${CONFORMANCE_DIR}) ──"

    # Integrity-check the map against the fixture directory and emit the
    # worklist. Any structural problem exits non-zero here, before a single
    # artifact is validated.
    WORKLIST_BASE="$(mktemp)"
    WORKLIST="${WORKLIST_BASE}.tsv"
    mv "$WORKLIST_BASE" "$WORKLIST"
    if ! python3 - "$FIXTURE_MAP" "$CONFORMANCE_DIR" "$WORKLIST" "$NORMALIZER" <<'MAPEOF'
import glob, importlib.util, json, os, sys

map_path, conformance_dir, worklist_path, normalizer_path = sys.argv[1:5]

try:
    with open(map_path, encoding="utf-8") as handle:
        entries = json.load(handle)["fixtures"]
except (OSError, KeyError, json.JSONDecodeError) as exc:
    sys.exit(f"    \u2717 cannot read fixture validation map: {exc}")

fixtures = {}
for path in sorted(glob.glob(os.path.join(conformance_dir, "*.json"))):
    try:
        with open(path, encoding="utf-8") as handle:
            fixture_id = json.load(handle)["id"]
    except (OSError, KeyError, json.JSONDecodeError) as exc:
        sys.exit(f"    \u2717 {os.path.basename(path)}: cannot read fixture id: {exc}")
    if fixture_id in fixtures:
        sys.exit(f"    \u2717 duplicate fixture id {fixture_id!r}: "
                 f"{os.path.basename(fixtures[fixture_id])} and {os.path.basename(path)}")
    fixtures[fixture_id] = path
    # Fixture ids are short and filenames are descriptive (bundle-001 ->
    # bundle-001-success.json), so they are not required to be equal — but a
    # filename that does not start with its id means one of the two was renamed
    # without the other, and the map is keyed by id.
    stem = os.path.basename(path)[:-len(".json")]
    if not (stem == fixture_id or stem.startswith(fixture_id + "-")):
        sys.exit(f"    \u2717 {os.path.basename(path)}: fixture id {fixture_id!r} is not a "
                 f"prefix of the filename; rename one to match the other")

unmapped = sorted(set(fixtures) - set(entries))
if unmapped:
    sys.exit("    \u2717 fixture(s) with no entry in fixture-validation-map.json: "
             + ", ".join(unmapped)
             + "\n      Every fixture must declare which artifacts its input carries, or say"
               "\n      explicitly that it carries none (\"no_artifacts\" with a reason). Refusing"
               "\n      to skip: an unmapped fixture would be silently unchecked.")

stale = sorted(set(entries) - set(fixtures))
if stale:
    sys.exit("    \u2717 map entr(ies) naming a fixture that does not exist: " + ", ".join(stale))

# Every `<x>_claims` companion the normalizer strips must be validated in its
# own right, or stripping it would be a silent exemption — the precise failure
# this stage exists to prevent, and one that no other check here would notice.
# Auditing the fixture tree rather than trusting the map extends that guarantee
# to companions added *inside* an already-mapped fixture, which the unmapped-file
# check cannot see. The walk covers the WHOLE fixture document (not just
# `input`), so a companion under `expected` or any other top-level key is caught
# too. It does NOT cover a non-companion artifact added the same way (see the
# stage's comment block).
#
# The predicate is imported from the normalizer rather than restated, so the set
# of members that get stripped and the set the map must cover are the same set by
# construction.
spec = importlib.util.spec_from_file_location("normalizer", normalizer_path)
normalizer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(normalizer)


def companion_pointers(node, path):
    found = []
    if isinstance(node, dict):
        companions = normalizer.companion_keys(node)
        for key, value in node.items():
            if key in companions:
                target = node[key]
                if isinstance(target, list):
                    found.extend(f"{path}/{key}/{i}" for i in range(len(target)))
                else:
                    found.append(f"{path}/{key}")
            found.extend(companion_pointers(value, f"{path}/{key}"))
    elif isinstance(node, list):
        for index, item in enumerate(node):
            found.extend(companion_pointers(item, f"{path}/{index}"))
    return found

for fixture_id, path in sorted(fixtures.items()):
    with open(path, encoding="utf-8") as handle:
        declared = {a.get("pointer") for a in entries[fixture_id].get("artifacts", [])}
        uncovered = [p for p in companion_pointers(json.load(handle), "")
                     if p not in declared]
    if uncovered:
        sys.exit(f"    \u2717 {fixture_id}: decoded-claims companion(s) stripped during "
                 f"normalization but never validated: {', '.join(uncovered)}\n"
                 f"      Add a map entry pointing each at its claims schema. A companion that is "
                 f"stripped\n      and unvalidated is exempt from checking entirely.")

rows = []
for fixture_id, entry in sorted(entries.items()):
    artifacts = entry.get("artifacts", [])
    if not artifacts:
        reason = (entry.get("no_artifacts") or {}).get("reason")
        if not reason:
            sys.exit(f"    \u2717 {fixture_id}: no artifacts and no \"no_artifacts\" reason. "
                     f"State why this fixture carries no validatable artifact.")
        continue
    for artifact in artifacts:
        pointer = artifact.get("pointer")
        schema = artifact.get("schema")
        expect = artifact.get("expect")
        if not pointer or not schema or expect not in ("valid", "invalid", "invalid_known_defect"):
            sys.exit(f"    \u2717 {fixture_id}: artifact needs pointer, schema and "
                     f"expect in valid|invalid|invalid_known_defect; got {artifact!r}")
        if expect != "valid" and not artifact.get("reason"):
            sys.exit(f"    \u2717 {fixture_id} {pointer}: expect={expect} requires a "
                     f"\"reason\" naming why this artifact does not validate.")
        rows.append("\t".join([fixture_id, fixtures[fixture_id], pointer, schema,
                               expect, artifact.get("wrap", "")]))

with open(worklist_path, "w", encoding="utf-8") as handle:
    handle.write("\n".join(rows) + ("\n" if rows else ""))
MAPEOF
    then
        rm -f "$WORKLIST"
        exit 1
    fi

    # Compile every schema the map names before validating anything against it.
    # ajv-cli exits 1 for "schema failed to compile" exactly as it does for
    # "document is invalid", so the two are indistinguishable inside the loop —
    # and a schema that stops compiling would otherwise satisfy every negative
    # expectation vacuously, which is the failure mode this stage exists to
    # prevent. Checking compilability up front removes the ambiguity entirely.
    for schema_file in $(cut -f4 "$WORKLIST" | sort -u); do
        schema_path="${PROJECT_ROOT}/schemas/json/${schema_file}"
        if [ ! -f "$schema_path" ]; then
            echo "    ✗ map names a schema that does not exist: ${schema_file}"
            rm -f "$WORKLIST"
            exit 1
        fi
        if ! ajv compile -s "$schema_path" --spec=draft2020 --strict=false -c ajv-formats >/dev/null 2>&1; then
            echo "    ✗ ${schema_file} does not compile — every validation against it would be meaningless"
            ajv compile -s "$schema_path" --spec=draft2020 --strict=false -c ajv-formats 2>&1 | sed 's/^/      /' || true
            rm -f "$WORKLIST"
            exit 1
        fi
    done

    FIXTURE_CHECKS=0
    KNOWN_DEFECTS=0
    while IFS=$'\t' read -r fid fpath pointer schema expect wrap; do
        [ -n "$fid" ] || continue
        schema_path="${PROJECT_ROOT}/schemas/json/${schema}"
        # ajv-cli infers its parser from the extension; the temp file must be .json.
        art_base="$(mktemp)"
        art="${art_base}.json"
        mv "$art_base" "$art"
        if [ -n "$wrap" ]; then
            norm_ok=$(python3 "$NORMALIZER" "$fpath" "$pointer" "$art" --wrap "$wrap" 2>&1) || norm_ok="FAILED:${norm_ok}"
        else
            norm_ok=$(python3 "$NORMALIZER" "$fpath" "$pointer" "$art" 2>&1) || norm_ok="FAILED:${norm_ok}"
        fi
        case "$norm_ok" in
            FAILED:*)
                echo "    ✗ ${fid} ${pointer}: ${norm_ok#FAILED:}"
                rm -f "$art" "$WORKLIST"
                exit 1
                ;;
        esac
        # ajv-cli exits 1 for "document is invalid" and 2 for "could not run"
        # (schema failed to compile, bad flags). Only the former is an outcome;
        # conflating them would let a schema that stops compiling satisfy every
        # negative expectation vacuously.
        # `set -e` aborts on a failing command substitution in an assignment, and
        # a nonzero ajv exit is an expected outcome here, not a script failure.
        set +e
        ajv_err="$(ajv validate -s "$schema_path" -d "$art" --spec=draft2020 --strict=false -c ajv-formats 2>&1 >/dev/null)"
        ajv_status=$?
        set -e
        if [ "$ajv_status" -eq 0 ]; then
            observed="valid"
        elif [ "$ajv_status" -eq 1 ]; then
            observed="invalid"
        else
            echo "    ✗ ${fid} ${pointer}: ajv failed to run against ${schema} (exit ${ajv_status})"
            echo "${ajv_err}" | sed 's/^/      /'
            rm -f "$art" "$WORKLIST"
            exit 1
        fi
        expected_outcome="invalid"
        [ "$expect" = "valid" ] && expected_outcome="valid"
        if [ "$observed" != "$expected_outcome" ]; then
            echo "    ✗ ${fid} ${pointer} vs ${schema}: expected ${expect}, got ${observed}"
            if [ "$observed" = "invalid" ]; then
                ajv validate -s "$schema_path" -d "$art" --spec=draft2020 --strict=false -c ajv-formats || true
            else
                echo "      This artifact was declared ${expect} and now validates. Either the"
                echo "      defect was fixed (update fixture-validation-map.json) or the schema"
                echo "      was weakened. A negative expectation that silently starts passing is"
                echo "      exactly the vacuous pass this stage exists to prevent."
            fi
            rm -f "$art" "$WORKLIST"
            exit 1
        fi
        rm -f "$art"
        FIXTURE_CHECKS=$((FIXTURE_CHECKS + 1))
        [ "$expect" = "invalid_known_defect" ] && KNOWN_DEFECTS=$((KNOWN_DEFECTS + 1))
    done < "$WORKLIST"
    rm -f "$WORKLIST"

    if [ "$FIXTURE_CHECKS" -lt "$FIXTURE_INPUT_MIN_CHECKS" ]; then
        echo "    ✗ only ${FIXTURE_CHECKS} fixture-input checks ran; expected at least ${FIXTURE_INPUT_MIN_CHECKS}"
        echo "      Coverage went backwards. If artifacts were deliberately removed, lower"
        echo "      FIXTURE_INPUT_MIN_CHECKS in the same commit and say why."
        exit 1
    fi
    echo "  ✓ ${FIXTURE_CHECKS} fixture artifacts validated against their schemas"
    if [ "$KNOWN_DEFECTS" -gt 0 ]; then
        echo "    (${KNOWN_DEFECTS} recorded as known defects — see \"reason\" in fixture-validation-map.json)"
    fi
    echo
fi

# ── Examples: validate by directory against the matching schema ──────────────
# v0.2: example files MAY carry top-level documentation companions whose keys
# start with "_" (e.g. `_decoded_claims`, `_wire_note`); these are stripped
# before schema validation, mirroring the signed-example `_kat_input` rule.
validate_dir_against() {
    local dir="$1"
    local schema="$2"
    local label="$3"
    [ -d "$dir" ] || return 0
    echo "── ${label} examples (${dir}) ──"
    for f in "${dir}"/*.json; do
        [ -f "$f" ] || continue
        TOTAL=$((TOTAL + 1))
        echo "  $(basename "$f")"
        local tmp_base tmp
        tmp_base="$(mktemp)"
        tmp="${tmp_base}.json"
        mv "$tmp_base" "$tmp"
        if ! python3 -c "import json,sys;d=json.load(open(sys.argv[1]));d={k:v for k,v in d.items() if not k.startswith('_')};json.dump(d,open(sys.argv[2],'w'))" "$f" "$tmp"; then
            rm -f "$tmp"
            echo "    ✗ Could not strip documentation companions"
            exit 1
        fi
        if ajv validate -s "${schema}" -d "${tmp}" --spec=draft2020 --strict=false -c ajv-formats >/dev/null 2>&1; then
            VALIDATED=$((VALIDATED + 1))
            echo "    ✓ Valid"
            rm -f "$tmp"
        else
            echo "    ✗ Invalid against ${label} schema"
            ajv validate -s "${schema}" -d "${tmp}" --spec=draft2020 --strict=false -c ajv-formats || true
            rm -f "$tmp"
            exit 1
        fi
    done
    echo
}

# v0.2: a TCT / grant-voucher / delegation example file carries the wire form
# (an opaque compact JWS string) plus a decoded-claims object; the claims
# object is what validates against the claims schema. Accepted layouts:
#   { "<x>_token": "<compact JWS>", "decoded_claims": { ... } }   (signed KATs)
#   { "tct_token": "...", "_decoded_claims": { ... } }            (doc examples)
validate_jws_dir() {
    local dir="$1"
    local schema="$2"
    local label="$3"
    [ -d "$dir" ] || return 0
    echo "── ${label} JWS artifacts (${dir}) ──"
    for f in "${dir}"/*.json; do
        [ -f "$f" ] || continue
        TOTAL=$((TOTAL + 1))
        echo "  $(basename "$f")"
        local tmp_base tmp
        tmp_base="$(mktemp)"
        tmp="${tmp_base}.json"
        mv "$tmp_base" "$tmp"
        if ! python3 - "$f" "$tmp" <<'PYEOF'
import json, re, sys
d = json.load(open(sys.argv[1]))
claims = d.get('decoded_claims') or d.get('_decoded_claims')
if claims is None:
    sys.exit('no decoded_claims / _decoded_claims companion found')
tokens = [v for k, v in d.items() if k.endswith('_token')]
if not tokens:
    sys.exit('no *_token field found')
pat = re.compile(r'^[A-Za-z0-9_<>-]+\.[A-Za-z0-9_<>-]+\.[A-Za-z0-9_<>-]+$')
for t in tokens:
    if not pat.match(t):
        sys.exit('token is not a three-segment compact JWS shape: %r' % t[:40])
json.dump(claims, open(sys.argv[2], 'w'))
PYEOF
        then
            rm -f "$tmp"
            echo "    ✗ JWS artifact file malformed"
            exit 1
        fi
        if ajv validate -s "${schema}" -d "${tmp}" --spec=draft2020 --strict=false -c ajv-formats >/dev/null 2>&1; then
            VALIDATED=$((VALIDATED + 1))
            echo "    ✓ Valid (decoded claims + token shape)"
            rm -f "$tmp"
        else
            echo "    ✗ Decoded claims invalid against ${label} schema"
            ajv validate -s "${schema}" -d "${tmp}" --spec=draft2020 --strict=false -c ajv-formats || true
            rm -f "$tmp"
            exit 1
        fi
    done
    echo
}

GRANT_VOUCHER_SCHEMA="${PROJECT_ROOT}/schemas/json/aitp-grant-voucher.schema.json"

validate_dir_against "${EXAMPLES_DIR}/manifest"      "${MANIFEST_SCHEMA}"        "manifest"
validate_jws_dir     "${EXAMPLES_DIR}/tct"           "${TCT_SCHEMA}"             "tct"
validate_jws_dir     "${EXAMPLES_DIR}/delegation"    "${DELEGATION_SCHEMA}"      "delegation"
validate_jws_dir     "${EXAMPLES_DIR}/grant-voucher" "${GRANT_VOUCHER_SCHEMA}"   "grant-voucher"
validate_dir_against "${EXAMPLES_DIR}/revocation"    "${REVOCATION_LIST_SCHEMA}" "revocation"

# Non-normative examples are multi-message narratives, not single payloads.
# Validate JSON syntax only (their inner messages are validated separately
# via the dedicated manifest/tct/delegation example directories).
if [ -d "$NON_NORMATIVE_DIR" ]; then
    echo "── Non-normative examples (${NON_NORMATIVE_DIR}) ──"
    for f in "${NON_NORMATIVE_DIR}"/*.json; do
        [ -f "$f" ] || continue
        TOTAL=$((TOTAL + 1))
        echo "  $(basename "$f")"
        if syntax_check "$f"; then
            VALIDATED=$((VALIDATED + 1))
            echo "    ✓ Valid JSON"
        else
            echo "    ✗ Invalid JSON"
            exit 1
        fi
    done
    echo
fi

# ── Known-answer test vectors (top-level): syntax-only ──────────────────────
# These are pinned interop reference values (keypairs, JWK thumbprints, JCS
# digests). They are not single canonical objects, so we syntax-check only.
if [ -d "$KAT_DIR" ]; then
    echo "── Known-answer vectors (${KAT_DIR}) ──"
    for f in "${KAT_DIR}"/*.json; do
        [ -f "$f" ] || continue
        TOTAL=$((TOTAL + 1))
        echo "  $(basename "$f")"
        if syntax_check "$f"; then
            VALIDATED=$((VALIDATED + 1))
            echo "    ✓ Valid JSON"
        else
            echo "    ✗ Invalid JSON"
            exit 1
        fi
    done
    echo
fi

# ── Signed-example KAT artifacts: schema-validate after stripping _kat_input ─
# Files under signed-examples/ carry a top-level `_kat_input` companion that
# documents the minting parameters. The signed object beside it MUST validate
# against the canonical schema. We strip `_kat_input` to a temp file, then
# validate the remainder.
validate_signed_kat() {
    local dir="$1"
    local schema="$2"
    local label="$3"
    [ -d "$dir" ] || return 0
    echo "── signed-example ${label} (${dir}) ──"
    for f in "${dir}"/*.json; do
        [ -f "$f" ] || continue
        TOTAL=$((TOTAL + 1))
        echo "  $(basename "$f")"
        # ajv-cli infers parser from file extension; the temp file must end in .json.
        local tmp_base tmp
        tmp_base="$(mktemp)"
        tmp="${tmp_base}.json"
        mv "$tmp_base" "$tmp"
        if ! python3 -c "import json,sys;d=json.load(open(sys.argv[1]));d.pop('_kat_input',None);json.dump(d,open(sys.argv[2],'w'))" "$f" "$tmp"; then
            rm -f "$tmp"
            echo "    ✗ Could not strip _kat_input"
            exit 1
        fi
        if ajv validate -s "${schema}" -d "${tmp}" --spec=draft2020 --strict=false -c ajv-formats >/dev/null 2>&1; then
            VALIDATED=$((VALIDATED + 1))
            echo "    ✓ Valid (signed payload)"
            rm -f "$tmp"
        else
            echo "    ✗ Invalid against ${label} schema (after stripping _kat_input)"
            ajv validate -s "${schema}" -d "${tmp}" --spec=draft2020 --strict=false -c ajv-formats || true
            rm -f "$tmp"
            exit 1
        fi
    done
    echo
}

# JCS-profile signed examples validate as whole objects (after stripping
# _kat_input); JWS-profile artifacts validate via their decoded claims +
# token shape (validate_jws_dir tolerates the _kat_input companion since it
# only reads decoded_claims and *_token fields).
validate_signed_kat "${KAT_SIGNED_DIR}/manifest"      "${MANIFEST_SCHEMA}"        "manifest"
validate_jws_dir    "${KAT_SIGNED_DIR}/tct"           "${TCT_SCHEMA}"             "tct"
validate_jws_dir    "${KAT_SIGNED_DIR}/grant-voucher" "${GRANT_VOUCHER_SCHEMA}"   "grant-voucher"
validate_jws_dir    "${KAT_SIGNED_DIR}/delegation"    "${DELEGATION_SCHEMA}"      "delegation"
validate_signed_kat "${KAT_SIGNED_DIR}/revocation"    "${REVOCATION_LIST_SCHEMA}" "revocation"
validate_signed_kat "${KAT_SIGNED_DIR}/session-bundle" "${SESSION_BUNDLE_SCHEMA}"  "session-bundle"

if [ $TOTAL -eq 0 ]; then
    echo "Warning: No JSON example or fixture files found"
    exit 1
fi

echo "─────────────────────────────────────"
echo "✓ All ${VALIDATED}/${TOTAL} JSON files validated"
