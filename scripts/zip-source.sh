#!/usr/bin/env bash
#
# Zip the source tree, excluding VCS metadata and noise.
# Output: ../<repo-name>-source-<UTC-timestamp>.zip
#
# Excluded:
#   .git/            (VCS metadata)
#   .DS_Store        (macOS resource forks)
#   __MACOSX/        (macOS zip cruft)
#   node_modules/    (regenerable)
#
# Everything else — including plans/, docs/, schemas/, conformance fixtures,
# CHANGELOG, etc. — is included. The output is written ONE LEVEL UP from the
# repo root so re-running the script does not include its own previous output.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_NAME="$(basename "${REPO_ROOT}")"
PARENT_DIR="$(dirname "${REPO_ROOT}")"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE_NAME="${REPO_NAME}-source-${STAMP}.zip"
ARCHIVE_PATH="${PARENT_DIR}/${ARCHIVE_NAME}"

echo "Zipping ${REPO_ROOT}"
echo "  → ${ARCHIVE_PATH}"

if ! command -v zip >/dev/null 2>&1; then
    echo "Error: 'zip' is not installed."
    exit 1
fi

cd "${PARENT_DIR}"

zip -r -q "${ARCHIVE_NAME}" "${REPO_NAME}" \
    -x "${REPO_NAME}/.git/*" \
    -x "${REPO_NAME}/**/.DS_Store" \
    -x "${REPO_NAME}/.DS_Store" \
    -x "${REPO_NAME}/**/__MACOSX/*" \
    -x "${REPO_NAME}/**/node_modules/*"

SIZE_BYTES="$(wc -c < "${ARCHIVE_NAME}" | tr -d ' ')"
SIZE_HUMAN="$(du -h "${ARCHIVE_NAME}" | cut -f1)"
FILE_COUNT="$(unzip -l "${ARCHIVE_NAME}" | tail -1 | awk '{print $2}')"

echo
echo "✓ Wrote ${ARCHIVE_PATH}"
echo "  Size:    ${SIZE_HUMAN} (${SIZE_BYTES} bytes)"
echo "  Entries: ${FILE_COUNT}"
