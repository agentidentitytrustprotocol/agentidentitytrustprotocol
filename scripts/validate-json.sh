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
NON_NORMATIVE_DIR="${PROJECT_ROOT}/examples/non-normative"

CONFORMANCE_DIR="${PROJECT_ROOT}/schemas/conformance"
EXAMPLES_DIR="${PROJECT_ROOT}/examples"

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

# ── Conformance fixtures: syntax-only ────────────────────────────────────────
if [ -d "$CONFORMANCE_DIR" ]; then
    echo "── Conformance fixtures (${CONFORMANCE_DIR}) ──"
    for f in "${CONFORMANCE_DIR}"/*.json; do
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

# ── Examples: validate by directory against the matching schema ──────────────
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
        if ajv validate -s "${schema}" -d "${f}" --spec=draft2020 --strict=false >/dev/null 2>&1; then
            VALIDATED=$((VALIDATED + 1))
            echo "    ✓ Valid"
        else
            echo "    ✗ Invalid against ${label} schema"
            ajv validate -s "${schema}" -d "${f}" --spec=draft2020 --strict=false || true
            exit 1
        fi
    done
    echo
}

validate_dir_against "${EXAMPLES_DIR}/manifest"   "${MANIFEST_SCHEMA}"        "manifest"
validate_dir_against "${EXAMPLES_DIR}/tct"        "${TCT_SCHEMA}"             "tct"
validate_dir_against "${EXAMPLES_DIR}/delegation" "${DELEGATION_SCHEMA}"      "delegation"
validate_dir_against "${EXAMPLES_DIR}/revocation" "${REVOCATION_LIST_SCHEMA}" "revocation"

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

if [ $TOTAL -eq 0 ]; then
    echo "Warning: No JSON example or fixture files found"
    exit 1
fi

echo "─────────────────────────────────────"
echo "✓ All ${VALIDATED}/${TOTAL} JSON files validated"
