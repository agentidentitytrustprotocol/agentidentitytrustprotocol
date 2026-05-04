#!/usr/bin/env bash
#
# Validate that all AITP JSON Schemas are themselves valid (meta-validation).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCHEMA_DIR="${PROJECT_ROOT}/schemas/json"

echo "Meta-validating JSON Schemas under ${SCHEMA_DIR} ..."
echo

if ! command -v ajv >/dev/null 2>&1; then
    echo "Error: ajv-cli is not installed"
    echo "Install with: npm install -g ajv-cli ajv-formats"
    echo "Or run: make install-tools"
    exit 1
fi

TOTAL=0
VALIDATED=0

for schema_file in "${SCHEMA_DIR}"/*.schema.json; do
    if [ -f "$schema_file" ]; then
        TOTAL=$((TOTAL + 1))
        echo "Validating: $(basename "$schema_file")"
        if ajv compile -s "${schema_file}" --spec=draft2020 --strict=false -c ajv-formats; then
            VALIDATED=$((VALIDATED + 1))
            echo "  ✓ Valid"
        else
            echo "  ✗ Invalid"
            exit 1
        fi
        echo
    fi
done

if [ $TOTAL -eq 0 ]; then
    echo "Warning: No JSON Schema files found in ${SCHEMA_DIR}"
    exit 1
fi

echo "─────────────────────────────────────"
echo "✓ All ${VALIDATED}/${TOTAL} JSON Schemas are valid"
