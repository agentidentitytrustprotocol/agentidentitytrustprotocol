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
#      in any tracked markdown file (RFCs, docs/, README, CONTRIBUTING,
#      VERSIONING, RELEASING, governance/, examples/, schemas/, registries/,
#      manifesto/ ...) resolves to a heading that actually exists in the
#      named RFC, and every bare `§X.Y` self-reference inside an RFC resolves
#      to a heading in that same RFC. See the stage's own comment below for
#      exact scope.
#   4. Error-code coherence — every `error_code` a conformance fixture
#      asserts is defined in registries/error-codes.md. One-way by design:
#      a registry code no fixture exercises is a coverage question, not a
#      coherence defect.
#   5. Shared-definition coherence — an object defined canonically in one
#      schema and mirrored into another's `$defs` must match its canonical
#      definition. The schemas are deliberately self-contained (no cross-file
#      `$ref` anywhere), so mirroring is the mechanism and this stage is what
#      keeps it honest.
#   6. Status-ladder coherence — every RFC's `**Status:**` header (and the
#      repo `README.md`'s) is drawn from the single lifecycle ladder that
#      governance/RFC-PROCESS.md defines, in the exact stage every RFC's
#      current standing is expected to be — not merely "some recognized
#      word," which would let RFC-AITP-0012 claim `Draft` and pass.
#   7. Stale-vocabulary check — docs/*.md (the files the website syncs) and
#      README.md carry no v0.1-era token: `grant_proof` and `binding.cnf`
#      never; `0.1.0-rc`, `aitp/0.1` and `v0.1` only in a paragraph or list
#      item that marks itself historical in-line. The allow-list rule is in
#      the stage's own comment below.
#   8. Sibling-link form — every `github.com/agentidentitytrustprotocol/
#      <repo>/blob/...` URL in a tracked markdown file uses `blob/main`, no
#      such URL uses `/tree/`, and none names the local alias `aitp-cp`.
#      When `../<repo>` is a local git checkout, the linked path must exist
#      on its `origin/main` and a `#anchor` on a markdown target must match
#      a heading there. That existence/anchor sub-check is local-only and
#      offline: CI checks out this repository alone, so it prints a
#      "skipped (sibling checkout absent)" note and passes.
#
# File set. Every stage reads one shared list of files: `git ls-files` when
# ROOT is the top of a git work tree (so untracked local notes -- plans/,
# temp/, PROGRESS.md -- are never scanned, and an intra-repo link to an
# untracked file is reported as broken), or a plain filesystem walk
# (skipping .git/ and node_modules/) when ROOT is not one, e.g. an unpacked
# release archive. A brand-new file is therefore checked once it is
# `git add`ed, not before.
#
# All eight checks exist because the class of bug they catch — one fact
# asserted in two places with nothing checking that they agree — is exactly
# the shape of the bugs PR #22 and PR #30 fixed, one level up in the docs.
# See RFC-AITP-0001 §5.4.1 and the docs/tests follow-through plan for PR #22 / PR #30
# (local planning notes, not tracked).
# Stage 3 closes out issue #29: PR #34 added stages 1 and 2 (RFC version
# coherence and markdown anchor resolution); the section-citation resolver
# below is the remaining piece. Stage 4 arrived with issue #37's
# `UNKNOWN_FIELD` addition, which surfaced that a fixture could assert a
# code the registry never defined and every other stage would stay green.
# Stage 5 arrived with issue #40, which found the handshake schema's embedded
# identity descriptor missing a MUST that its canonical schema states. Stage 6
# arrived with issue #47, which found four incompatible RFC status ladders and
# nine of thirteen RFCs using a status string ("Community Standards Track
# (v0.2 Draft)") that appeared on none of them. Stages 7 and 8, stage 3's
# reach beyond rfcs/ and docs/, and the shared file set arrived with the
# v0.2 docs refresh, which found every docs/ page still speaking v0.1
# vocabulary, a wrong § citation in an examples/ README that no stage
# scanned, and nothing at all checking links into the sibling repositories.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT="${1:-${DEFAULT_ROOT}}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Shared file set and Python helpers (see "File set" in the header) ───────
ROOT_REAL="$(cd "$ROOT" && pwd -P)"
TOP="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$TOP" ] && [ "$(cd "$TOP" && pwd -P)" = "$ROOT_REAL" ]; then
    git -C "$ROOT" ls-files -z | tr '\0' '\n' > "$WORK/files.txt"
    FILE_SOURCE="git ls-files: tracked files only"
else
    (cd "$ROOT" && find . \( -name .git -o -name node_modules \) -prune -o -type f -print \
        | sed 's|^\./||' | LC_ALL=C sort) > "$WORK/files.txt"
    FILE_SOURCE="filesystem walk: ROOT is not the top of a git work tree"
fi

# Every stage does `import doccheck`. The module is written to the temp dir so
# the script stays one file and leaves no __pycache__ behind.
cat > "$WORK/doccheck.py" <<'PYEOF'
import os

def files(root, prefix="", suffix=""):
    """The shared file set (repo-relative paths), filtered by prefix/suffix.
    A path git lists but the work tree has deleted is dropped."""
    with open(os.environ["AITP_DOC_FILES"], encoding="utf-8") as fh:
        rels = [l for l in fh.read().split("\n") if l]
    return sorted(
        r for r in rels
        if r.startswith(prefix) and r.endswith(suffix)
        and os.path.isfile(os.path.join(root, r))
    )

def file_set(root):
    return set(files(root))

def flat_in(rel, d):
    """True when `rel` sits directly in directory `d` (no subdirectory)."""
    return rel.startswith(d + "/") and "/" not in rel[len(d) + 1:]

def rfc_files(root):
    return [r for r in files(root, "rfcs/RFC-AITP-", ".md") if flat_in(r, "rfcs")]

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


def heading_slugs(lines):
    """GitHub anchor slugs of the ATX headings in `lines`, ignoring fenced
    code, with GitHub's -1, -2 ... suffixes on repeated headings."""
    import re
    heading_re = re.compile(r'^(#{1,6})\s+(.*?)\s*$')
    slugs, seen, in_fence = set(), {}, False
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
PYEOF

export AITP_DOC_FILES="$WORK/files.txt"
export PYTHONPATH="$WORK${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONDONTWRITEBYTECODE=1

echo "Checking documentation coherence under ${ROOT} ..."
echo "(file set: ${FILE_SOURCE})"
echo

FAIL=0

# ── 1. Version coherence (rfcs/README.md vs each RFC's own header) ─────────
echo "── Version coherence (rfcs/README.md vs RFC headers) ──"

if ! python3 - "$ROOT" <<'PYEOF'
import os, re, sys
import doccheck

root = sys.argv[1]
rfc_dir = os.path.join(root, "rfcs")
readme = os.path.join(rfc_dir, "README.md")

rfc_files = [os.path.join(root, r) for r in doccheck.rfc_files(root)]
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
from doccheck import files, file_set, heading_slugs

root = sys.argv[1]

# The shared file set (see "File set" in the header): untracked local notes
# are neither scanned as sources nor accepted as link targets.
md_files = [os.path.join(root, r) for r in files(root, suffix=".md")]
known = file_set(root)

if not md_files:
    print(f"Warning: no markdown files found under {root}")
    sys.exit(1)

# slugify() and heading_slugs() -- GitHub's slug rules -- are in the shared
# helpers at the top of this script; stage 8 uses the same ones.
link_re = re.compile(r'\[[^\]]*\]\((?![a-zA-Z][a-zA-Z0-9+.-]*:)([^)\n]+\.md)#([^)\n]+)\)')

def headings_for(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return heading_slugs(fh.readlines())
    except OSError:
        return None

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
        if rel_target not in known:
            broken.append(
                f"    ✗ {rel_src}:{line_no}: links to {rel_target}#{anchor}, "
                f"but {rel_target} does not exist (or is not tracked)"
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
import os, re, sys
import doccheck

root = sys.argv[1]
rfc_dir = os.path.join(root, "rfcs")

# Scope (issue #29). This resolves *citation existence*, not whether the
# cited section supports the claim next to it -- that half is not
# mechanizable ("does the target support the claim" requires reading both
# sides) and remains issue #29's residue after this stage lands.
#
# IN SCOPE:
#   (a) `RFC-AITP-NNNN §X.Y` (also §X, §X.Y.Z, and a `RFC-AITP-NNNN §X/§Y`
#       or `RFC-AITP-NNNN §X, §Y` compound form for the same target RFC),
#       in rfcs/*.md and in EVERY tracked markdown file outside rfcs/ --
#       docs/, README, CONTRIBUTING, VERSIONING, RELEASING, CHANGELOG,
#       governance/, examples/, schemas/, registries/, manifesto/, .github/
#       -- checked against the named RFC's own heading numbers. In
#       CHANGELOG.md only the `## Unreleased` section is scanned: released
#       entries are a historical record whose citations were right as of
#       their release (v0.1-line entries cite sections later renumbered),
#       and history is not rewritten to satisfy a checker.
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
#   - bare `§X.Y` in non-RFC markdown (docs/, README, ...). The target document is not
#     reliably determinable from the citation alone there (unlike inside
#     an RFC, there is no enclosing document with its own heading set to
#     try first), and a guessed target produces false failures -- a
#     checker that cries wolf gets switched off. Bare `§X.Y` in prose
#     elsewhere in docs/ is left unchecked on purpose.
#   - external citations: `RFC <digits> §X` (e.g. `RFC 8785 §3.2.3`) and
#     `SEC <digit> §X` (e.g. `SEC 1 §2.3.3`, SECG's SEC1). AITP citations
#     always carry the hyphenated `RFC-AITP-NNNN` prefix, so these are
#     lexically distinguishable and never resolved against local files.

rfc_files = [os.path.join(root, r) for r in doccheck.rfc_files(root)]
scan_files = [
    os.path.join(root, r) for r in doccheck.files(root, suffix=".md")
    if doccheck.flat_in(r, "rfcs") or not r.startswith("rfcs/")
]

if not rfc_files or not scan_files:
    print(f"Warning: no RFC or markdown files found under {root}")
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
    rel = os.path.relpath(src, root)
    if rel == "CHANGELOG.md":
        # Scan `## Unreleased` only (see IN SCOPE (a) above). Truncating keeps
        # every earlier offset, so line numbers stay right.
        h2 = [m.start() for m in re.finditer(r'^## ', text, re.M)]
        unreleased = [p for p in h2 if text.startswith("## Unreleased", p)]
        if unreleased:
            later = [p for p in h2 if p > unreleased[0]]
            text = text[:later[0]] if later else text
        else:
            text = ""
    flat = text.replace("\n", " ")

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
if ! python3 - "$ROOT" <<'PYEOF'
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

import doccheck
fixtures = [
    os.path.join(root, r) for r in doccheck.files(root, "schemas/conformance/", ".json")
    if doccheck.flat_in(r, "schemas/conformance")
]
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
echo

# ── 5. Shared-definition coherence (embedded $defs vs the canonical schema) ──
echo "── Shared-definition coherence (embedded \$defs vs canonical schema) ──"

# One object, defined in two schema files, with nothing checking they agree --
# the same shape of bug as every stage above, one level down in the schemas.
# `aitp-mutual-handshake.schema.json` carries its own copy of the identity
# descriptor because no schema here resolves a cross-file $ref (each file is
# self-contained by design, so an offline validator needs exactly one fetch).
# The copy had drifted: it was missing `extensions`, the `public_key` pattern,
# and -- load-bearing -- the `not: {required: [public_key]}` guard that
# RFC-AITP-0002 §1 states as a MUST ("v0.2 verifiers MUST reject an OIDC
# identity descriptor that carries public_key"). An OIDC descriptor carrying
# public_key validated inside a handshake payload, which is the only place the
# descriptor actually travels. See issue #40.
#
# The canonical file is authoritative (RFC-AITP-0002 §1 names it as such); the
# embedded copy MUST equal it minus the file-level metadata keys that cannot
# appear in a $defs subschema ($schema/$id/title/examples) and minus the
# $comment marking it as a mirror.
if ! python3 - "$ROOT" <<'PYEOF'
import json, os, sys

root = sys.argv[1]

# (canonical schema, embedding schema, $defs name)
MIRRORS = [
    ("aitp-identity.schema.json", "aitp-mutual-handshake.schema.json", "IdentityDescriptor"),
]
META = {"$schema", "$id", "title", "examples", "$comment"}

if not MIRRORS:
    print("    Warning: no mirrored definitions configured")
    sys.exit(1)

def load(name):
    path = os.path.join(root, "schemas", "json", name)
    if not os.path.isfile(path):
        print(f"    ✗ {name} not found")
        sys.exit(1)
    return json.load(open(path))

def strip(node):
    return {k: v for k, v in node.items() if k not in META}

failed = False
for canon_name, host_name, def_name in MIRRORS:
    canon = load(canon_name)
    host = load(host_name)
    embedded = (host.get("$defs") or {}).get(def_name)
    if embedded is None:
        print(f"    ✗ {host_name}: $defs/{def_name} is missing (expected a mirror of {canon_name})")
        failed = True
        continue
    want, got = strip(canon), strip(embedded)
    if want != got:
        failed = True
        print(f"    ✗ {host_name} $defs/{def_name} has drifted from {canon_name}:")
        for key in sorted(set(want) | set(got)):
            if want.get(key) != got.get(key):
                if key not in got:
                    print(f"        - `{key}` missing from the embedded copy")
                elif key not in want:
                    print(f"        - `{key}` present only in the embedded copy")
                else:
                    print(f"        - `{key}` differs")
        print(f"      {canon_name} is canonical (RFC-AITP-0002 §1); edit it, not the copy.")

if failed:
    sys.exit(1)

print(f"    ✓ all {len(MIRRORS)} embedded definition(s) match their canonical schema")
PYEOF
then
    FAIL=1
fi
echo

# ── 6. Status-ladder coherence (RFC Status headers vs governance/RFC-PROCESS.md) ─
echo "── Status-ladder coherence (RFC Status headers vs governance/RFC-PROCESS.md) ──"

if ! python3 - "$ROOT" <<'PYEOF'
import glob, os, re, sys

root = sys.argv[1]
rfc_dir = os.path.join(root, "rfcs")

# Mirrors the ladder in governance/RFC-PROCESS.md. If that ladder changes,
# update this set and EXPECTED below in the same PR.
LADDER = {"Idea", "Draft", "Review", "Release Candidate", "Final Comment Period", "Accepted", "Rejected"}
BARE_STAGES = {"Reserved", "Planned"}  # no track prefix -- see RFC-PROCESS.md
TRACK = "Community Standards Track"
status_re = re.compile(r'^\*\*Status:\*\*\s*(.+?)\s*$', re.MULTILINE)

# The stage each numbered RFC is expected to declare today, so a status that
# is merely "a recognized word" but the wrong one for that document still
# fails (e.g. RFC-AITP-0012 claiming Draft instead of Reserved).
EXPECTED = {
    "0001": "Draft", "0002": "Draft", "0003": "Draft", "0004": "Draft",
    "0005": "Draft", "0006": "Draft", "0007": "Draft", "0008": "Draft",
    "0009": "Draft", "0010": "Draft", "0011": "Draft",
    "0012": "Reserved", "0013": "Planned",
}

def extract_stage(raw, label, failures):
    if raw in BARE_STAGES:
        return raw
    prefix = f"{TRACK} ("
    if raw.startswith(prefix) and raw.endswith(")"):
        stage = raw[len(prefix):-1]
        if stage in LADDER:
            return stage
    failures.append(
        f"    ✗ {label}: Status {raw!r} is not `{TRACK} (<Stage>)` for a "
        f"ladder Stage, nor one of {sorted(BARE_STAGES)}"
    )
    return None

import doccheck
rfc_files = [os.path.join(root, r) for r in doccheck.rfc_files(root)]
if not rfc_files:
    sys.exit(f"    ✗ no RFC-AITP-*.md files found under {rfc_dir}")

failures = []
seen = set()
for path in rfc_files:
    m = re.search(r'RFC-AITP-(\d{4})', os.path.basename(path))
    if not m:
        continue
    number = m.group(1)
    seen.add(number)
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    sm = status_re.search(text)
    if not sm:
        failures.append(f"    ✗ {os.path.basename(path)}: no **Status:** header found")
        continue
    stage = extract_stage(sm.group(1), os.path.basename(path), failures)
    if stage is None:
        continue
    expected = EXPECTED.get(number)
    if expected is not None and stage != expected:
        failures.append(
            f"    ✗ {os.path.basename(path)}: Status stage is {stage!r}, expected {expected!r}"
        )

missing = sorted(set(EXPECTED) - seen)
if missing:
    failures.append(f"    ✗ expected RFC-AITP-{{{','.join(missing)}}} not found under {rfc_dir}")

# The repo README.md's own Status line uses the same vocabulary (bare Draft
# stages only -- the root README describes the whole repo, never Reserved
# or Planned).
readme_path = os.path.join(root, "README.md")
with open(readme_path, encoding="utf-8") as fh:
    readme_text = fh.read()
rm = status_re.search(readme_text)
if not rm:
    failures.append("    ✗ README.md: no **Status:** header found")
else:
    extract_stage(rm.group(1), "README.md", failures)

if failures:
    for f in failures:
        print(f)
    sys.exit(1)

print(f"    ✓ all {len(seen)} RFC Status headers and README.md draw from the RFC-PROCESS.md ladder")
PYEOF
then
    FAIL=1
fi

echo

# ── 7. Stale-vocabulary check (docs/*.md and README.md) ─────────────────────
echo "── Stale vocabulary (v0.1-era tokens in docs/*.md and README.md) ──"

# docs/*.md is exactly what the website sync ingests (a flat glob, no
# subdirectories) and README.md is the repository's front page; both must
# speak v0.2. Two token classes:
#
#   ALWAYS STALE -- `grant_proof` (v0.1 delegation proof; v0.2 delegates via
#     the grant voucher) and `binding.cnf` (v0.1 key binding; v0.2 TCTs carry
#     `cnf.jkt`). Neither has a legitimate use on these pages; a historical
#     mention belongs in CHANGELOG.md, which this stage does not scan.
#
#   STALE UNLESS MARKED HISTORICAL -- `0.1.0-rc`, `aitp/0.1`, and `v0.1` (not
#     `v0.10`). A hit is allowed only when its paragraph or list item -- the
#     run of non-blank lines around it, cut at headings, list-item starts, table
#     rows and code fences -- also contains one of these in-line markers
#     (case-insensitive):
#         legacy          e.g. "the legacy untagged `aid:pubkey:<43>` form"
#         v0.1-frozen     e.g. a fixture pinned to v0.1 bytes, like del-004
#         v0.1 line       e.g. "the earlier v0.1 line reached `0.1.0-rc.3`"
#     The marker is wording a reader sees, so the exemption documents itself.
#     It is deliberately NOT an HTML comment: docs/ is synced into MDX, where
#     `<!-- -->` breaks the build. Keep the marker list this short; a hit
#     that needs a new marker is usually stale prose, not history.
if ! python3 - "$ROOT" <<'PYEOF'
import os, re, sys
import doccheck

root = sys.argv[1]
targets = [r for r in doccheck.files(root, "docs/", ".md") if doccheck.flat_in(r, "docs")]
if os.path.isfile(os.path.join(root, "README.md")):
    targets.append("README.md")
if not targets:
    print("    Warning: no docs/*.md or README.md found")
    sys.exit(1)

ALWAYS = [
    (re.compile(r'grant_proof'), "`grant_proof` (v0.2 delegates via the grant voucher)"),
    (re.compile(r'binding\.cnf'), "`binding.cnf` (v0.2 TCTs carry `cnf.jkt`)"),
]
UNLESS_HISTORICAL = [
    (re.compile(r'0\.1\.0-rc'), "`0.1.0-rc`"),
    (re.compile(r'aitp/0\.1(?!\d)'), "`aitp/0.1`"),
    (re.compile(r'(?<![\w.])v0\.1(?!\d)'), "`v0.1`"),
]
MARKER = re.compile(r'\blegacy\b|\bv0\.1-frozen\b|\bv0\.1 line\b', re.IGNORECASE)
block_break = re.compile(r'^\s*(?:#{1,6}\s|[-*+]\s|\d+[.)]\s|```|~~~|\|)')

failures, checked, allowed = [], 0, 0
for rel in targets:
    with open(os.path.join(root, rel), encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    # Assign each line to a block (paragraph / list item / heading / fence).
    block_of, blocks, cur = [], [], -1
    for line in lines:
        if not line.strip():
            block_of.append(None)
            cur = -1
            continue
        if cur == -1 or block_break.match(line):
            blocks.append([])
            cur = len(blocks) - 1
        blocks[cur].append(line)
        block_of.append(cur)
    block_text = ["\n".join(b) for b in blocks]
    for n, line in enumerate(lines, 1):
        for rx, label in ALWAYS:
            if rx.search(line):
                checked += 1
                failures.append(f"    ✗ {rel}:{n}: stale token {label}")
        for rx, label in UNLESS_HISTORICAL:
            if rx.search(line):
                checked += 1
                b = block_of[n - 1]
                if b is not None and MARKER.search(block_text[b]):
                    allowed += 1
                    continue
                failures.append(
                    f"    ✗ {rel}:{n}: stale token {label} -- say v0.2, or mark the "
                    f"paragraph historical with \"legacy\", \"v0.1-frozen\" or \"v0.1 line\""
                )

if failures:
    for f in failures:
        print(f)
    print(f"    ({len(failures)} stale token(s) in {len(targets)} file(s))")
    sys.exit(1)

print(
    f"    ✓ no stale v0.1-era tokens in {len(targets)} file(s) "
    f"({allowed} marked-historical mention(s) allowed)"
)
PYEOF
then
    FAIL=1
fi
echo

# ── 8. Sibling-link form (github.com/agentidentitytrustprotocol/<repo>/...) ─
echo "── Sibling-link form (blob/main URLs into sibling repositories) ──"

# Cross-repository citations are full
# `https://github.com/agentidentitytrustprotocol/<repo>/blob/main/<path>` URLs
# (docs/ecosystem.md states the convention; the website rewrites exactly that
# form to its rendered pages). Over every tracked markdown file:
#
#   FORM (always, offline) -- a `<repo>/blob/<ref>/...` URL must use
#     ref `main`; no URL into the organization may use `/tree/` (point at a
#     file, or at a directory via `blob/main/<dir>`); and no URL may name
#     `aitp-cp`, which is only a local symlink to `aitp-control-plane`.
#
#   EXISTENCE + ANCHOR (local-only) -- when `../<repo>` is a git checkout
#     with an `origin/main` ref, `git -C ../<repo> cat-file -e
#     origin/main:<path>` must succeed (git trees are case-exact, so this is
#     correct on case-insensitive filesystems too), and a `#anchor` on a
#     `.md` target must equal a GitHub heading slug of that file at
#     origin/main (same slugify() as stage 2). Anchors on non-markdown
#     targets (e.g. `#L42`) are not checked. Sibling working trees are often
#     on feature branches, so the working tree is never consulted -- only
#     origin/main as last fetched. Nothing here touches the network; a stale
#     origin/main is refreshed with `git -C ../<repo> fetch`. When the
#     checkout is absent (CI checks out this repository alone) the sub-check
#     prints "skipped (sibling checkout absent)" and passes. Links into this
#     repository itself are checked against the shared file set instead.
if ! python3 - "$ROOT" <<'PYEOF'
import os, re, subprocess, sys
from urllib.parse import unquote
import doccheck

root = sys.argv[1]
parent = os.path.dirname(os.path.realpath(root))
self_name = "agentidentitytrustprotocol"
known = doccheck.file_set(root)

url_re = re.compile(
    r'https?://github\.com/agentidentitytrustprotocol/([A-Za-z0-9._-]+)'
    r'((?:/[^\s)<>\]"\'`]*)?)'
)

def git(repo_dir, *args, capture=False):
    r = subprocess.run(["git", "-C", repo_dir, *args],
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return r.stdout if capture else r.returncode == 0

failures, refs = [], []
total_urls = 0
for rel in doccheck.files(root, suffix=".md"):
    with open(os.path.join(root, rel), encoding="utf-8") as fh:
        text = fh.read()
    for m in url_re.finditer(text):
        repo, rest = m.group(1), m.group(2).rstrip(".,;:!?*_")
        n = text.count("\n", 0, m.start()) + 1
        where = f"{rel}:{n}"
        total_urls += 1
        if repo.lower() == "aitp-cp":
            failures.append(f"    ✗ {where}: URL names `aitp-cp`, a local symlink -- use aitp-control-plane")
            continue
        parts = rest.split("/")
        if "tree" in parts:
            failures.append(f"    ✗ {where}: `/tree/` URL -- use blob/main/<path>")
            continue
        if len(parts) < 3 or parts[1] != "blob":
            continue  # repo root, issues, pulls, releases: no path to check
        if parts[2] != "main":
            failures.append(f"    ✗ {where}: blob/{parts[2]} -- sibling links must use blob/main")
            continue
        path = "/".join(parts[3:])
        anchor = ""
        if "#" in path:
            path, anchor = path.split("#", 1)
        path = unquote(path.split("?", 1)[0]).strip("/")
        refs.append((where, repo, path, unquote(anchor)))

# Existence + anchor sub-check.
checked_paths = checked_anchors = 0
skipped = {}          # repo -> (reason, count)
state = {}            # repo -> repo_dir or None
heads_cache = {}
for where, repo, path, anchor in refs:
    if repo == self_name:
        if path and path not in known and not any(k.startswith(path + "/") for k in known):
            failures.append(f"    ✗ {where}: {repo}/blob/main/{path} -- not a tracked file in this repository")
        else:
            checked_paths += 1
        if anchor and path.endswith(".md") and path in known:
            if anchor.lower() not in heads_cache.setdefault(
                    (repo, path),
                    doccheck.heading_slugs(open(os.path.join(root, path), encoding="utf-8").readlines())):
                failures.append(f"    ✗ {where}: #{anchor} does not resolve in {path}")
            else:
                checked_anchors += 1
        continue
    if repo not in state:
        d = os.path.join(parent, repo)
        if not os.path.isdir(d) or not git(d, "rev-parse", "--git-dir"):
            state[repo] = None
            skipped[repo] = ["sibling checkout absent", 0]
        elif not git(d, "rev-parse", "--verify", "-q", "origin/main^{commit}"):
            state[repo] = None
            skipped[repo] = ["no origin/main ref in the sibling checkout", 0]
        else:
            state[repo] = d
    d = state[repo]
    if d is None:
        skipped[repo][1] += 1
        continue
    if path and not git(d, "cat-file", "-e", f"origin/main:{path}"):
        failures.append(f"    ✗ {where}: {repo}/blob/main/{path} -- no such path on {repo}'s origin/main")
        continue
    checked_paths += 1
    if anchor and path.endswith(".md"):
        key = (repo, path)
        if key not in heads_cache:
            body = git(d, "show", f"origin/main:{path}", capture=True).decode("utf-8", "replace")
            heads_cache[key] = doccheck.heading_slugs(body.split("\n"))
        if anchor.lower() not in heads_cache[key]:
            failures.append(f"    ✗ {where}: #{anchor} does not resolve in {repo}/{path} at origin/main")
        else:
            checked_anchors += 1

if failures:
    for f in failures:
        print(f)
    print(f"    ({len(failures)} problem(s) in {total_urls} organization URL(s))")
    sys.exit(1)

print(f"    ✓ all {total_urls} organization URL(s) use the blob/main form (no /tree/, no aitp-cp)")
if checked_paths or not skipped:
    print(f"    ✓ {checked_paths} linked path(s) exist on origin/main; {checked_anchors} anchor(s) resolve")
for repo in sorted(skipped):
    reason, count = skipped[repo]
    print(f"    – {repo}: existence/anchor check skipped ({reason}); {count} link(s) form-checked only")
PYEOF
then
    FAIL=1
fi

echo "─────────────────────────────────────"
if [ "$FAIL" -ne 0 ]; then
    echo "✗ Documentation coherence checks failed"
    exit 1
fi
echo "✓ Documentation is coherent (versions, anchors, section citations, fixture error codes, mirrored schema definitions, the RFC status ladder, stale vocabulary, and sibling-link form)"
