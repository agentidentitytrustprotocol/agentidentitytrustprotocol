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
#   3. Section-citation resolution — every `RFC-AITP-NNNN §X.Y` citation
#      resolves to a heading that actually exists in the named RFC, and
#      every bare `§X.Y` self-reference inside an RFC resolves to a heading
#      in that same RFC. See the stage's own comment below for exact scope.
#   4. Error-code coherence — every `error_code` a conformance fixture
#      asserts is defined in registries/error-codes.md. One-way by design:
#      a registry code no fixture exercises is a coverage question, not a
#      coherence defect.
#
# All four checks exist because the class of bug they catch — one fact
# asserted in two places with nothing checking that they agree — is exactly
# the shape of the bugs PR #22 and PR #30 fixed, one level up in the docs.
# See RFC-AITP-0001 §5.4.1 and plans/docs-tests-followthrough-jcs-and-bundle-fixes.md.
# Stage 3 closes out issue #29: PR #34 added stages 1 and 2 (RFC version
# coherence and markdown anchor resolution); the section-citation resolver
# below is the remaining piece. Stage 4 arrived with issue #37's
# `UNKNOWN_FIELD` addition, which surfaced that a fixture could assert a
# code the registry never defined and every other stage would stay green.

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
# The joiner allows a bare comma, "and", or an Oxford ", and" between list
# items -- `,\s*(?:and\s+)?|\s+and\s+` -- so "A, B and C", "A, B, and C", and
# "A and B" all match in full. (The old `(?:,\s*|\s+and\s+)` alternation had
# no branch for ", and ", so on an Oxford-comma list the regex backtracked
# to matching only the final RFC-AITP-NNNN, silently dropping every earlier
# RFC in the list from both the match and the "checked" count.)
assertion_re = re.compile(
    r'((?:RFC-AITP-\d{4}(?:,\s*(?:and\s+)?|\s+and\s+))*RFC-AITP-\d{4})'
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

# ── 3. Section-citation resolution (RFC-AITP-NNNN §X.Y and bare §X.Y) ──────
echo "── Section-citation resolution (RFC-AITP-NNNN §X.Y and bare §X.Y) ──"

if ! python3 - "$ROOT" <<'PYEOF'
import glob, os, re, sys

root = sys.argv[1]
rfc_dir = os.path.join(root, "rfcs")
docs_dir = os.path.join(root, "docs")

# Scope (issue #29). This resolves *citation existence*, not whether the
# cited section supports the claim next to it -- that half is not
# mechanizable ("does the target support the claim" requires reading both
# sides) and remains issue #29's residue after this stage lands.
#
# IN SCOPE:
#   (a) `RFC-AITP-NNNN §X.Y` (also §X, §X.Y.Z, and a `RFC-AITP-NNNN §X/§Y`
#       or `RFC-AITP-NNNN §X, §Y` compound form for the same target RFC),
#       anywhere under rfcs/ or docs/, checked against the named RFC's own
#       heading numbers.
#   (b) bare `§X.Y` self-references *inside an RFC file*, checked first
#       against that file's own headings -- this is where most citations
#       live, per hand audit of this corpus. If (and only if) that fails,
#       and the nearest earlier explicit `RFC-AITP-MMMM §...` citation in
#       the *same top-level (`## `) section* names a heading that MMMM
#       does have, the bare cite is treated as continuing that citation
#       (e.g. RFC-AITP-0008 §1.5's blockquote cites "RFC-AITP-0001 §5.4.1"
#       once and then says "per §5.4.1" two sentences later in the same
#       paragraph -- self-file RFC-AITP-0008 has no §5.4.1, but the
#       fallback resolves it against RFC-AITP-0001, which does). This is
#       a narrow, deterministic rule over an already-hand-verified corpus,
#       not a guess: it only ever engages after self-file resolution has
#       already failed, and only reaches for a target the surrounding
#       prose named explicitly moments earlier.
#
# OUT OF SCOPE (deliberately, not an oversight):
#   - bare `§X.Y` in non-RFC docs (docs/*.md). The target document is not
#     reliably determinable from the citation alone there (unlike inside
#     an RFC, there is no enclosing document with its own heading set to
#     try first), and a guessed target produces false failures -- a
#     checker that cries wolf gets switched off. See docs/discovery.md's
#     "§1.3 (...), §1.4 (...)" and docs/GLOSSARY.md's "[§6](...)" for real
#     examples of this pattern left unchecked on purpose.
#   - external citations: `RFC <digits> §X` (e.g. `RFC 8785 §3.2.3`) and
#     `SEC <digit> §X` (e.g. `SEC 1 §2.3.3`, SECG's SEC1). AITP citations
#     always carry the hyphenated `RFC-AITP-NNNN` prefix, so these are
#     lexically distinguishable and never resolved against local files.

rfc_files = sorted(glob.glob(os.path.join(rfc_dir, "RFC-AITP-*.md")))
scan_files = sorted(
    glob.glob(os.path.join(rfc_dir, "*.md")) + glob.glob(os.path.join(docs_dir, "*.md"))
)

if not rfc_files or not scan_files:
    print(f"Warning: no RFC or doc files found under {rfc_dir} / {docs_dir}")
    sys.exit(1)

# Same heading pattern as the anchor-resolution stage's headings, restricted
# to the numbered form: `^#{2,4} X(.Y)*` optionally followed by `.` or a
# space (so "5.4.10" isn't mistaken for a partial match of "5.4.1", and
# unnumbered headings like RFC-AITP-0013's or RFC-AITP-0004's `#### Fields`
# are silently skipped rather than crashing the parser).
heading_re = re.compile(r'^(#{2,4})\s+(\d+(?:\.\d+)*)(?:[.\s]|$)')
top_section_re = re.compile(r'^##\s')

def headings_for(path):
    nums = set()
    in_fence = False
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            stripped = line.rstrip("\n")
            if stripped.strip().startswith("```") or stripped.strip().startswith("~~~"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            m = heading_re.match(stripped)
            if m:
                nums.add(m.group(2))
    return nums

rfc_headings = {}
for path in rfc_files:
    m = re.search(r'RFC-AITP-(\d{4})', os.path.basename(path))
    if m:
        rfc_headings[m.group(1)] = (path, headings_for(path))

SEC = r'§(\d+(?:\.\d+)*)'
# `RFC-\s*AITP-` (not a literal `RFC-AITP-`) so a hard-wrapped citation like
# "(RFC-\nAITP-0004 §3.4)" still matches once newlines are flattened to
# spaces below -- the wrap lands mid-hyphen, not on a normal word boundary.
prefixed_re = re.compile(r'RFC-\s*AITP-(\d{4})\s+' + SEC + r'(?:\s*[/,]\s*' + SEC + r')*')
external_re = re.compile(r'(?:RFC|SEC)\s+\d+\s+' + SEC)
bare_re = re.compile(SEC)

def top_section_bounds(text):
    bounds, pos = [], 0
    for line in text.split("\n"):
        if top_section_re.match(line):
            bounds.append(pos)
        pos += len(line) + 1
    return bounds

def section_index(bounds, pos):
    idx = 0
    for i, b in enumerate(bounds):
        if b <= pos:
            idx = i
        else:
            break
    return idx

total_prefixed = 0
total_bare = 0
unresolved = []

for src in scan_files:
    with open(src, encoding="utf-8") as fh:
        text = fh.read()
    # Citations can be line-wrapped by markdown; operate on the whole file
    # with newlines flattened to spaces (same length, so char offsets --
    # and therefore line numbers computed against the original text --
    # stay valid) rather than scanning line by line.
    flat = text.replace("\n", " ")
    rel = os.path.relpath(src, root)

    spans_covered = []
    prefixed_matches = list(prefixed_re.finditer(flat))
    for m in prefixed_matches:
        spans_covered.append((m.start(), m.end()))
    for m in external_re.finditer(flat):
        spans_covered.append((m.start(), m.end()))

    for m in prefixed_matches:
        num = m.group(1)
        # Python's re keeps only the LAST capture of a repeated group
        # (`(?:...§(...))*`), so reading m.groups() would silently drop every
        # section but the first and the last in a 3+-part compound citation
        # like "§5.1, §99.9, §5.2" -- and since the whole match span still
        # gets recorded in spans_covered, the dropped section would also be
        # excluded from the bare-cite pass below and checked by nothing.
        # re.findall over the matched span sees every repetition instead.
        secs = re.findall(SEC, m.group(0))
        total_prefixed += len(secs)
        line_no = text.count("\n", 0, m.start()) + 1
        entry = rfc_headings.get(num)
        if entry is None:
            unresolved.append(f"    ✗ {rel}:{line_no}: cites RFC-AITP-{num}, which is not a known RFC")
            continue
        tpath, heads = entry
        tname = os.path.relpath(tpath, root)
        for sec in secs:
            if sec not in heads:
                unresolved.append(
                    f"    ✗ {rel}:{line_no}: RFC-AITP-{num} §{sec} -- no heading §{sec} in {tname}"
                )

    self_match = re.search(r'RFC-AITP-(\d{4})', os.path.basename(src))
    if src not in rfc_files or self_match is None:
        continue  # bare §X.Y in non-RFC docs: out of scope, see comment above

    self_num = self_match.group(1)
    self_heads = rfc_headings[self_num][1]
    bounds = top_section_bounds(text)
    pref_events = sorted((m.start(), m.group(1), section_index(bounds, m.start())) for m in prefixed_matches)

    idx = 0
    last_foreign = None
    last_foreign_section = None
    for m in bare_re.finditer(flat):
        s, e = m.start(), m.end()
        if any(s < ce and e > cs for cs, ce in spans_covered):
            continue  # already accounted for as part of a prefixed/external citation
        while idx < len(pref_events) and pref_events[idx][0] < s:
            last_foreign, last_foreign_section = pref_events[idx][1], pref_events[idx][2]
            idx += 1
        total_bare += 1
        sec = m.group(1)
        line_no = text.count("\n", 0, s) + 1
        if sec in self_heads:
            continue
        if (
            last_foreign
            and last_foreign != self_num
            and last_foreign_section == section_index(bounds, s)
        ):
            entry = rfc_headings.get(last_foreign)
            if entry and sec in entry[1]:
                continue  # continues the nearest earlier same-section citation
        unresolved.append(f"    ✗ {rel}:{line_no}: bare §{sec} -- no heading §{sec} in this file")

total = total_prefixed + total_bare
if total == 0:
    print(f"Warning: no RFC-AITP-NNNN §X.Y or bare §X.Y citations found under {root}")
    sys.exit(1)

if unresolved:
    for u in sorted(set(unresolved)):
        print(u)
    print(f"    ({len(unresolved)} of {total} section citations are unresolved)")
    sys.exit(1)

print(
    f"    ✓ all {total} section citations resolve "
    f"({total_prefixed} RFC-AITP-NNNN §X.Y, {total_bare} bare self-reference)"
)
PYEOF
then
    FAIL=1
fi
echo

# ── 4. Error-code coherence (fixture error_code vs registries/error-codes.md) ─
echo "── Error-code coherence (fixture \`error_code\` vs the registry) ──"

# A conformance fixture asserts an error_code; the registry is where codes are
# defined. Nothing checked that an asserted code actually exists, so a fixture
# could pin a code no implementation could ever return -- a typo, or a code
# renamed in the registry and left behind here -- and every stage would stay
# green. Same one-fact-two-places shape as the version and citation stages.
#
# Direction is deliberately one-way: every code a fixture ASSERTS must exist in
# the registry. The reverse (a registry code no fixture exercises) is a coverage
# question, not a coherence defect, and is not checked here.
if ! python3 - "$PROJECT_ROOT" <<'PYEOF'
import json, glob, os, re, sys

root = sys.argv[1]
reg_path = os.path.join(root, "registries", "error-codes.md")
if not os.path.isfile(reg_path):
    print("    Warning: registries/error-codes.md not found")
    sys.exit(1)

defined = set(re.findall(r'^\|\s*`([A-Z][A-Z0-9_]*)`', open(reg_path).read(), re.M))
if not defined:
    print("    Warning: no error codes parsed from registries/error-codes.md")
    sys.exit(1)

fixtures = sorted(glob.glob(os.path.join(root, "schemas", "conformance", "*.json")))
if not fixtures:
    print("    Warning: no conformance fixtures found")
    sys.exit(1)

asserted, bad = set(), []
for path in fixtures:
    try:
        doc = json.load(open(path))
    except Exception:
        continue
    if not isinstance(doc, dict):
        continue
    code = (doc.get("expected") or {}).get("error_code")
    if not isinstance(code, str) or not code:
        continue
    asserted.add(code)
    if code not in defined:
        bad.append((os.path.relpath(path, root), code))

if bad:
    for rel, code in sorted(bad):
        print(f"    \u2717 {rel}: error_code `{code}` is not defined in registries/error-codes.md")
    sys.exit(1)

print(f"    \u2713 all {len(asserted)} distinct fixture error code(s) are defined in the registry")
PYEOF
then
    FAIL=1
fi


echo "─────────────────────────────────────"
if [ "$FAIL" -ne 0 ]; then
    echo "✗ Documentation coherence checks failed"
    exit 1
fi
echo "✓ Documentation is coherent (versions, anchors, section citations, and fixture error codes)"
