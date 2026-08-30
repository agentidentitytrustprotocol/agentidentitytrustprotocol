#!/usr/bin/env bash
#
# Check that the repo's documentation stays coherent with itself:
#
#   1. Version coherence — every `Version:` header in rfcs/RFC-AITP-*.md is
#      quoted accurately wherever rfcs/README.md names that RFC together with
#      a version string.
#   2. Anchor resolution — every intra-repo markdown link of the form
#      `path.md#anchor` resolves to a heading that actually exists in the
#      target file, using GitHub's slug algorithm.
#
# Both checks exist because the class of bug they catch — one fact asserted
# in two places with nothing checking that they agree — is exactly the shape
# of the bugs PR #22 and PR #30 fixed, one level up in the docs. See
# RFC-AITP-0001 §5.4.1 and plans/docs-tests-followthrough-jcs-and-bundle-fixes.md.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT="${1:-${DEFAULT_ROOT}}"

echo "Checking documentation coherence under ${ROOT} ..."
echo

FAIL=0

# ── 1. Version coherence (rfcs/README.md vs each RFC's own header) ─────────
echo "── Version coherence (rfcs/README.md vs RFC headers) ──"

if ! python3 - "$ROOT" <<'PYEOF'
import glob, os, re, sys

root = sys.argv[1]
rfc_dir = os.path.join(root, "rfcs")
readme = os.path.join(rfc_dir, "README.md")

rfc_files = sorted(glob.glob(os.path.join(rfc_dir, "RFC-AITP-*.md")))
if not rfc_files:
    print(f"Warning: no RFC-AITP-*.md files found under {rfc_dir}")
    sys.exit(1)

version_re = re.compile(r'^\*\*Version:\*\*\s*(\S+)', re.MULTILINE)
headers = {}
for path in rfc_files:
    m = re.search(r'RFC-AITP-(\d{4})', os.path.basename(path))
    if not m:
        continue
    number = m.group(1)
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    vm = version_re.search(text)
    if not vm:
        sys.exit(f"    ✗ {os.path.basename(path)}: no **Version:** header found")
    headers[number] = vm.group(1)

if not os.path.isfile(readme):
    sys.exit(f"    ✗ {readme} not found")

with open(readme, encoding="utf-8") as fh:
    readme_text = fh.read()

# Matches prose of the shape:
#   "RFC-AITP-0001 and RFC-AITP-0010 are at `0.2.3-draft`"
#   "RFC-AITP-0004 is at `0.2.1-draft`"
# i.e. one or more RFC-AITP-NNNN references, joined by ", " or " and ",
# immediately followed by "is/are at" and a backtick-quoted version. This
# deliberately does NOT fire on prose that merely mentions an RFC (e.g. a
# citation or an index-table row) without asserting its version this way.
assertion_re = re.compile(
    r'((?:RFC-AITP-\d{4}(?:,\s*|\s+and\s+))*RFC-AITP-\d{4})'
    r'\s+(?:is|are)\s+at\s+`([0-9]+\.[0-9]+\.[0-9]+-[A-Za-z0-9.]+)`'
)

checked = 0
mismatches = []
for match in assertion_re.finditer(readme_text):
    rfc_list, claimed_version = match.group(1), match.group(2)
    line_no = readme_text.count("\n", 0, match.start()) + 1
    for number in re.findall(r'RFC-AITP-(\d{4})', rfc_list):
        checked += 1
        actual = headers.get(number)
        if actual is None:
            mismatches.append(
                f"    ✗ rfcs/README.md:{line_no}: cites RFC-AITP-{number}, "
                f"which has no known Version: header"
            )
        elif actual != claimed_version:
            mismatches.append(
                f"    ✗ rfcs/README.md:{line_no}: claims RFC-AITP-{number} is "
                f"`{claimed_version}`, but its header says `{actual}`"
            )

if checked == 0:
    print("Warning: no version-coherence assertions found in rfcs/README.md")
    sys.exit(1)

if mismatches:
    for m in mismatches:
        print(m)
    sys.exit(1)

print(f"    ✓ {checked} version assertion(s) in rfcs/README.md match their RFC headers")
PYEOF
then
    FAIL=1
fi
echo

# ── 2. Anchor resolution (GitHub slug algorithm) ────────────────────────────
echo "── Anchor resolution (intra-repo path.md#anchor links) ──"

if ! python3 - "$ROOT" <<'PYEOF'
import os, re, sys

root = sys.argv[1]

md_files = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "node_modules")]
    for name in filenames:
        if name.endswith(".md"):
            md_files.append(os.path.join(dirpath, name))
md_files.sort()

if not md_files:
    print(f"Warning: no markdown files found under {root}")
    sys.exit(1)

def slugify(text):
    # GitHub's heading-anchor algorithm: lowercase; strip everything except
    # alphanumerics, spaces, hyphens and UNDERSCORES; spaces become hyphens.
    # Headings in this repo carry `code`, (parens), periods and § -- all
    # stripped by this rule, e.g. "5.4.1 Signing input (JCS profile)" ->
    # "541-signing-input-jcs-profile".
    #
    # Underscores are KEPT. GitHub preserves them, and this repo has many
    # headings that depend on it -- RFC-AITP-0004's MUTUAL_HELLO,
    # MUTUAL_HELLO_ACK, MUTUAL_COMMIT and MUTUAL_COMMIT_ACK sections, and
    # RFC-AITP-0008 §3.3's `fail_open`. Stripping them would compute
    # "31-mutualhello" where GitHub computes "31-mutual_hello", so a
    # correct link to any of those headings would be reported broken. A
    # checker whose false positives outnumber its true ones gets ignored,
    # which is worse than not having it.
    text = text.strip().lower()
    kept = [ch for ch in text if ch.isalnum() or ch in (" ", "-", "_")]
    return "".join(kept).replace(" ", "-")

heading_re = re.compile(r'^(#{1,6})\s+(.*?)\s*$')
link_re = re.compile(r'\[[^\]]*\]\(([^)\n]+\.md)#([^)\n]+)\)')

def headings_for(path):
    slugs = set()
    in_fence = False
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.readlines()
    except OSError:
        return None
    seen = {}
    for line in lines:
        stripped = line.rstrip("\n")
        if stripped.strip().startswith("```") or stripped.strip().startswith("~~~"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = heading_re.match(stripped)
        if not m:
            continue
        base = slugify(m.group(2))
        if base in seen:
            seen[base] += 1
            slug = f"{base}-{seen[base]}"
        else:
            seen[base] = 0
            slug = base
        slugs.add(slug)
    return slugs

heading_cache = {}

def get_headings(path):
    norm = os.path.normpath(path)
    if norm not in heading_cache:
        heading_cache[norm] = headings_for(norm)
    return heading_cache[norm]

total_links = 0
broken = []
for src in md_files:
    with open(src, encoding="utf-8") as fh:
        text = fh.read()
    for match in link_re.finditer(text):
        target_rel, anchor = match.group(1), match.group(2)
        total_links += 1
        line_no = text.count("\n", 0, match.start()) + 1
        target_path = os.path.normpath(os.path.join(os.path.dirname(src), target_rel))
        rel_src = os.path.relpath(src, root)
        rel_target = os.path.relpath(target_path, root)
        if not os.path.isfile(target_path):
            broken.append(
                f"    ✗ {rel_src}:{line_no}: links to {rel_target}#{anchor}, "
                f"but {rel_target} does not exist"
            )
            continue
        slugs = get_headings(target_path)
        if anchor.lower() not in slugs:
            broken.append(
                f"    ✗ {rel_src}:{line_no}: #{anchor} does not resolve in {rel_target}"
            )

if total_links == 0:
    print(f"Warning: no path.md#anchor links found under {root}")
    sys.exit(1)

if broken:
    for b in sorted(set(broken)):
        print(b)
    print(f"    ({len(broken)} of {total_links} intra-repo anchor links are broken)")
    sys.exit(1)

print(f"    ✓ all {total_links} intra-repo path.md#anchor links resolve")
PYEOF
then
    FAIL=1
fi
echo

echo "─────────────────────────────────────"
if [ "$FAIL" -ne 0 ]; then
    echo "✗ Documentation coherence checks failed"
    exit 1
fi
echo "✓ Documentation is coherent (versions and anchors)"
