#!/usr/bin/env bash
#
# create-ietf-draft-repo.sh: create the PRIVATE repository
# agentidentitytrustprotocol/aitp-ietf-draft from the i-d-template project's
# GitHub template, seed it for draft-koti-aitp-mutual-trust with the submit
# job disabled, and undo it. Plan phase ID1.0 (cross-repo plan
# aitp-ietf-draft-v1-rc); outreach rule D2: sessions build the draft, the
# owner submits it (ID-H).
#
# Usage:
#   scripts/handoff/create-ietf-draft-repo.sh [--dry-run]   print every API call; change nothing (default)
#   scripts/handoff/create-ietf-draft-repo.sh --apply       perform the calls the dry-run prints
#   scripts/handoff/create-ietf-draft-repo.sh --rollback    archive the repository (never deletes it)
#   scripts/handoff/create-ietf-draft-repo.sh --emit DIR    write the seed files to DIR and stop (no API calls)
#
# What it manages (and nothing else):
#   - the repository itself, generated PRIVATE from
#     martinthomson/internet-draft-template (the GitHub template repository
#     of martinthomson/i-d-template; i-d-template itself is not a template
#     repository). Visibility is set in the create call, so the repository is
#     never public. Wiki and projects off, branch deleted on merge;
#   - the repository variable SUBMIT_ENABLED, created as "false" if absent and
#     never changed afterwards: only the owner flips it, in ID-H;
#   - one seed commit on main, written only while the placeholder draft is
#     absent. It adds draft-koti-aitp-mutual-trust.md (kramdown-rfc,
#     Informational, ipr trust200902, bcp14-tagged boilerplate) and CLAUDE.md,
#     rewrites the template workflows so every i-d-template step runs the
#     action image pinned by digest (IMAGE below) and every other action by
#     commit SHA, disables the datatracker submit job with `if: false`, adds
#     the Submit Guard workflow, and removes the template's placeholder draft
#     and the scheduled archive workflow. The template's setup workflow then
#     runs once on that push (with the pinned image) and generates Makefile,
#     README.md and .gitignore;
#   - a best-effort cancel of the workflow runs GitHub starts on the
#     template's own first commit (they use the unpinned image).
#
# The outreach guard (D2). In i-d-template, pushing a draft-* tag makes CI
# upload the draft to datatracker. The submit job therefore carries
# `if: false`, and the Submit Guard workflow fails any push or pull request
# that removes it while the repository variable SUBMIT_ENABLED is not "true".
# On the free plan private repositories get no tag rulesets or required
# checks, and sessions sign in as the owner's accounts, so the disabled job is
# the only real guard; CLAUDE.md states the session rule.
#
# Every step reads current state first and does nothing when it already
# matches, so a second --apply is a no-op. Mutating calls are printed as
# `+ gh api ...` in every mode; --dry-run stops there.
#
# Requires: gh (authenticated; `repo` and `workflow` scopes for --apply),
# python3. Bash 3.2 compatible (macOS /bin/bash).
# Exit codes: 0 ok, 1 an API call failed, 2 usage or missing prerequisite.

set -euo pipefail

ORG="agentidentitytrustprotocol"
REPO="aitp-ietf-draft"
FULL="$ORG/$REPO"
TEMPLATE="martinthomson/internet-draft-template"
DRAFT="draft-koti-aitp-mutual-trust"
DESC="Internet-Draft $DRAFT: the AITP core (envelope, identity, handshake, TCT, delegation) for the IETF. Private until the owner submits."
SESSION_TRAILER="Claude-Session: https://claude.ai/code/session_01H8iVMfeYr9yAn3Qbvs2gY1"

# i-d-template action image, pinned by digest. This is the multi-arch index
# that ghcr.io/martinthomson/i-d-template-action:latest pointed to on
# 2026-10-30 (pushed 2026-10-18). To move it: resolve the new digest with
#   gh api /users/martinthomson/packages/container/i-d-template-action/versions --jq '.[0]'
# and change it here and in the repository's workflows in one PR.
IMAGE="ghcr.io/martinthomson/i-d-template-action@sha256:596081fb5c92065f08e0230b36e41f8e510928246340291ea946a55737587e5c"
CHECKOUT="actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1"
CACHE="actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0"
UPLOAD_ARTIFACT="actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2"

# ── Plumbing ─────────────────────────────────────────────────────────────────

die() { echo "error: $*" >&2; exit 2; }
say() { printf '%s\n' "$*"; }

MODE="dry-run"
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) MODE="dry-run" ;;
        --apply) MODE="apply" ;;
        --rollback) MODE="rollback" ;;
        --emit) shift; [ $# -gt 0 ] || die "--emit needs a directory"; MODE="emit"; EMIT_DIR="$1" ;;
        -h|--help) sed -n '2,53p' "$0"; exit 0 ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
    shift
done

command -v gh >/dev/null 2>&1 || die "gh is not installed"
command -v python3 >/dev/null 2>&1 || die "python3 is not installed"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

CHANGES=0

# mut METHOD PATH [JSON]: one mutating API call. Printed always (file content
# elided); performed only under --apply / --rollback. Prints the response on
# stdout of the call's caller only through `mut_out`.
mut() {
    local method="$1" path="$2" body="${3:-}"
    CHANGES=$((CHANGES + 1))
    if [ -n "$body" ]; then
        say "  + gh api -X $method $path --input - <<< $(printf '%s' "$body" | python3 -c 'import json,sys; d=json.load(sys.stdin); "content" in d and d.update(content="<content elided>"); print(json.dumps(d))')"
    else
        say "  + gh api -X $method $path"
    fi
    [ "$MODE" = "dry-run" ] && return 0
    if [ -n "$body" ]; then
        printf '%s' "$body" | gh api -X "$method" "$path" --input - > "$WORK/last.json" || { echo "error: $method $path failed" >&2; exit 1; }
    else
        gh api -X "$method" "$path" > "$WORK/last.json" || { echo "error: $method $path failed" >&2; exit 1; }
    fi
}

last() {   # last KEY -> field from the previous mut response
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$WORK/last.json" "$1"
}

REPO_EXISTS=false
read_repo() {
    if gh api "repos/$FULL" > "$WORK/repo.json" 2>/dev/null; then
        REPO_EXISTS=true
    fi
}

rfield() {   # rfield KEY -> value from repo.json
    python3 - "$WORK/repo.json" "$1" <<'PY'
import json, sys
v = json.load(open(sys.argv[1])).get(sys.argv[2])
if isinstance(v, bool): print("true" if v else "false")
elif v is None: print("")
else: print(v)
PY
}

# ── Seed content ─────────────────────────────────────────────────────────────
# Workflow bodies use @IMAGE@, @CHECKOUT@, @CACHE@ and @UPLOAD_ARTIFACT@,
# substituted by render().

render() {   # render < template > file
    sed -e "s|@IMAGE@|docker://$IMAGE|g" \
        -e "s|@CHECKOUT@|$CHECKOUT|g" \
        -e "s|@CACHE@|$CACHE|g" \
        -e "s|@UPLOAD_ARTIFACT@|$UPLOAD_ARTIFACT|g"
}

seed_draft() {
    cat <<'EOF'
---
title: "Agent Identity and Trust Protocol (AITP): Mutual Trust Between AI Agents"
abbrev: "AITP Mutual Trust"
category: info

docname: draft-koti-aitp-mutual-trust-latest
submissiontype: IETF
number:
date:
consensus: false
v: 3
ipr: trust200902
keyword:
 - agent identity
 - mutual authentication
 - AI agents
venue:
  github: "agentidentitytrustprotocol/aitp-ietf-draft"

author:
 -
    fullname: Ajit Koti
    email: ajitkoti@gmail.com

normative:

informative:

...

--- abstract

This document describes the Agent Identity and Trust Protocol (AITP),
which lets two software agents establish mutual trust before they
exchange work: each proves its identity, presents a signed manifest of
its capabilities, and obtains a short-lived trust token bound to its key.
This revision is a placeholder; the protocol text follows in a later
revision.


--- middle

# Introduction {#intro}

This revision is a placeholder that establishes the document name and
build. The protocol text will follow in a later revision.


# Conventions and Definitions

{::boilerplate bcp14-tagged}


# Security Considerations {#security}

This placeholder defines no protocol and so raises no security
considerations of its own.


# IANA Considerations {#iana}

This document has no IANA actions.


--- back

# Acknowledgments
{:numbered="false"}

None yet.
EOF
}

seed_claude_md() {
    cat <<'EOF'
# CLAUDE.md: aitp-ietf-draft

Guidance for agent sessions working in this repository. It holds the
Internet-Draft `draft-koti-aitp-mutual-trust`, built with
[i-d-template](https://github.com/martinthomson/i-d-template) and
kramdown-rfc. The repository is private until the owner submits.

## Never submit (outreach rule D2, plan phase ID-H)

- **Never push a `draft-*` tag.** In i-d-template a `draft-*` tag makes CI
  upload the draft to datatracker, which is an external submission.
- **Never submit to datatracker or the IETF** by any other route either: no
  `make upload`, no manual upload, no email to the IETF or a working group.
- **The owner does that, in ID-H.** The submit job in
  `.github/workflows/publish.yml` carries `if: false`. Do not remove it, and
  do not set the repository variable `SUBMIT_ENABLED`. The Submit Guard
  workflow fails any change that removes `if: false` while `SUBMIT_ENABLED`
  is not `true`; only the owner changes that variable. A session may draft
  the ID-H re-enable PR, but the owner merges it.
- Do not change the repository's visibility. The owner makes it public at
  submission.

## Draft content

- Every requirement (MUST, SHOULD, ...) traces to an RFC-AITP section at the
  spec commit pinned in `SPEC_VERSION` once it exists. The draft never
  contradicts the spec.
- No statements about how the text was produced.

## Build

`make` builds the txt and html output and lints; `make idnits` runs idnits.
CI runs the i-d-template action image pinned by `@sha256:` digest. Keep it
pinned; move the digest in its own PR.

## Git

Branch, open a PR, merge on green CI. No force-push to main. Every commit
ends with the session trailer the session was given.
EOF
}

wf_build() {
    render <<'EOF'
name: "Build Draft"

on:
  push:
    paths-ignore:
    - README.md
    - CONTRIBUTING.md
    - LICENSE.md
    - CLAUDE.md
    - .gitignore
  pull_request:
    paths-ignore:
    - README.md
    - CONTRIBUTING.md
    - LICENSE.md
    - CLAUDE.md
    - .gitignore
  workflow_dispatch:

permissions:
  contents: read

jobs:
  build:
    name: "Build Draft"
    runs-on: ubuntu-latest
    steps:
    - name: "Checkout"
      uses: @CHECKOUT@

    - name: "Setup"
      id: setup
      run: date -u "+date=%FT%T" >>"$GITHUB_OUTPUT"

    - name: "Caching"
      uses: @CACHE@
      with:
        path: |
          .refcache
          .venv
          .gems
          node_modules
          .targets.mk
        key: i-d-${{ steps.setup.outputs.date }}
        restore-keys: i-d-

    # txt and html output plus i-d-template's lint.
    - name: "Build Drafts"
      uses: @IMAGE@
      with:
        args: all
      env:
        GITHUB_TOKEN: ${{ github.token }}

    - name: "idnits"
      uses: @IMAGE@
      with:
        args: idnits
      env:
        GITHUB_TOKEN: ${{ github.token }}

    - name: "Archive Built Drafts"
      uses: @UPLOAD_ARTIFACT@
      with:
        name: drafts
        path: |
          draft-*.html
          draft-*.txt
EOF
}

wf_publish() {
    render <<'EOF'
name: "Publish New Draft Version"

on:
  push:
    tags:
      - "draft-*"
  workflow_dispatch:
    inputs:
      email:
        description: "Submitter email"
        default: ""
        type: string

permissions:
  contents: read

jobs:
  build:
    name: "Publish New Draft Version"
    # DISABLED UNTIL ID-H (plan aitp-ietf-draft-v1-rc, outreach rule D2).
    # This job uploads the draft to datatracker. Only the owner submits: the
    # owner-merged ID-H PR removes the line below, and the owner sets the
    # repository variable SUBMIT_ENABLED=true. The Submit Guard workflow fails
    # while this line is missing and SUBMIT_ENABLED is not "true".
    if: false
    runs-on: ubuntu-latest
    steps:
    - name: "Checkout"
      uses: @CHECKOUT@
      with:
        # Needed for tracing file history for replacement status
        fetch-depth: 0
        fetch-tags: true

    # See https://github.com/actions/checkout/issues/290
    - name: "Get Tag Annotations"
      run: git fetch -f origin ${{ github.ref }}:${{ github.ref }}

    - name: "Setup"
      id: setup
      run: date -u "+date=%FT%T" >>"$GITHUB_OUTPUT"

    - name: "Caching"
      uses: @CACHE@
      with:
        path: |
          .refcache
          .venv
          .gems
          node_modules
          .targets.mk
        key: i-d-${{ steps.setup.outputs.date }}
        restore-keys: i-d-

    - name: "Build Drafts"
      id: build
      uses: @IMAGE@
      with:
        args: releases
      env:
        GITHUB_TOKEN: ${{ github.token }}

    - name: "Upload to Datatracker"
      uses: @IMAGE@
      with:
        args: upload
      env:
        UPLOAD_EMAIL: ${{ inputs.email }}
        GITHUB_STEP: upload

    - name: "Archive Submitted Drafts"
      uses: @UPLOAD_ARTIFACT@
      if: always() && steps.build.outcome == 'success'
      with:
        name: published
        path: "versioned/draft-*-[0-9][0-9].*"
EOF
}

wf_guard() {
    render <<'EOF'
name: "Submit Guard"

# Outreach guard (plan aitp-ietf-draft-v1-rc ID1.0, rule D2). Fails when the
# datatracker submit path is enabled before the owner has set the repository
# variable SUBMIT_ENABLED=true in ID-H.

on:
  push:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  guard:
    name: "Submit Guard"
    runs-on: ubuntu-latest
    steps:
    - name: "Checkout"
      uses: @CHECKOUT@

    - name: "Submit job stays disabled until ID-H"
      env:
        SUBMIT_ENABLED: ${{ vars.SUBMIT_ENABLED }}
      run: |
        if [ "$SUBMIT_ENABLED" = "true" ]; then
          echo "SUBMIT_ENABLED=true: the owner lifted the guard (ID-H)."
          exit 0
        fi
        fail=0
        f=.github/workflows/publish.yml
        if [ -f "$f" ]; then
          # Every job in the submit workflow must carry the literal `if: false`.
          enabled="$(yq -r '.jobs | to_entries | .[] | select(.value.if != false) | .key' "$f")"
          if [ -n "$enabled" ]; then
            echo "::error file=$f::submit job(s) not disabled: $enabled. Keep 'if: false' until ID-H sets SUBMIT_ENABLED=true."
            fail=1
          fi
        fi
        # No other workflow may upload or trigger on draft-* tags (this file
        # is skipped: it names the patterns it looks for).
        self=.github/workflows/submit-guard.yml
        for w in .github/workflows/*.yml .github/workflows/*.yaml; do
          [ -f "$w" ] && [ "$w" != "$f" ] && [ "$w" != "$self" ] || continue
          if grep -nE '(make|args):[[:space:]]*["'\'']?upload([[:space:]"'\'']|$)|^[[:space:]]*-[[:space:]]*["'\'']?draft-|datatracker' "$w"; then
            echo "::error file=$w::only publish.yml may hold the datatracker submit path."
            fail=1
          fi
        done
        if [ "$fail" -ne 0 ]; then
          echo "SUBMIT_ENABLED is '${SUBMIT_ENABLED:-unset}'; only the owner sets it to true, in ID-H."
          exit 1
        fi
        echo "Submit path disabled: ok."
EOF
}

wf_setup() {
    # The template's one-time setup workflow, with the image pinned. It runs
    # once on the seed push, generates Makefile/README/.gitignore and deletes
    # itself.
    render <<'EOF'
name: "Perform Initial Repository Setup"

on:
  push:
    branches: [main]

jobs:
  pre:
    name: "Setup Repository"
    runs-on: ubuntu-latest
    outputs:
      skip: ${{ steps.pre.outputs.skip }}
    steps:
    - name: "Checkout"
      uses: @CHECKOUT@

    - name: "Precondition Check"
      id: pre
      run: |
        if ! ls draft-* rfc* 2>/dev/null | grep -qv draft-todo-yourname-protocol.md; then
          echo "skip=true" >>"$GITHUB_OUTPUT"
        elif [ ! -f draft-todo-yourname-protocol.md -a -f Makefile ]; then
          echo "skip=true" >>"$GITHUB_OUTPUT"
        else
          echo "skip=false" >>"$GITHUB_OUTPUT"
        fi

  setup:
    name: "Setup Repository"
    runs-on: ubuntu-latest
    needs: pre
    if: ${{ needs.pre.outputs.skip != 'true' }}
    permissions:
      contents: write
    steps:
    - name: "Checkout"
      uses: @CHECKOUT@

    - name: "Git Config"
      run: |
        git config user.email "idbot@example.com"
        git config user.name "I-D Bot"

    - name: "Update Draft Name"
      run: |
        for i in draft-*; do
          sed -i -e "s/draft-todo-yourname-protocol-latest/${i%.md}-latest/g" "$i"
          git add "$i"
        done
        if [ -n "$(git status --porcelain draft-*)" ]; then
          git commit -m "Update draft labels" draft-*
        fi

    - name: "Cleanup"
      run: |
        git rm -rf .github/workflows/setup.yml README.md
        git commit -m "Remove setup files"

    - name: "Clone the i-d-template Repo"
      run: |
        git clone --depth=1 https://github.com/martinthomson/i-d-template lib

    - name: "Run i-d-template Setup"
      uses: @IMAGE@
      with:
        args: setup

    - name: "Fix Lint"
      uses: @IMAGE@
      with:
        args: fix-lint

    - name: "Update Venue Information"
      uses: @IMAGE@
      with:
        args: update-venue

    - name: "Push Changes"
      run: |
        git push
EOF
}

wf_update() {
    render <<'EOF'
name: "Update Generated Files"
# Run by hand to regenerate the template's files (README.md,
# CONTRIBUTING.md, .note.xml, .github/CODEOWNERS, Makefile). It drops any
# customisation of those files.
on: workflow_dispatch

jobs:
  build:
    name: "Update Files"
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
    - name: "Checkout"
      uses: @CHECKOUT@

    - name: "Update Generated Files"
      uses: @IMAGE@
      with:
        args: update-files
      env:
        GITHUB_TOKEN: ${{ github.token }}

    - name: "Push Update"
      run: git push
EOF
}

# Files the seed commit writes, and the ones it removes.
SEED_ADD="$DRAFT.md CLAUDE.md .github/workflows/ghpages.yml .github/workflows/publish.yml .github/workflows/submit-guard.yml .github/workflows/setup.yml .github/workflows/update.yml"
SEED_DEL="draft-todo-yourname-protocol.md .github/workflows/archive.yml"

build_seed() {
    mkdir -p "$WORK/seed/.github/workflows"
    seed_draft > "$WORK/seed/$DRAFT.md"
    seed_claude_md > "$WORK/seed/CLAUDE.md"
    wf_build > "$WORK/seed/.github/workflows/ghpages.yml"
    wf_publish > "$WORK/seed/.github/workflows/publish.yml"
    wf_guard > "$WORK/seed/.github/workflows/submit-guard.yml"
    wf_setup > "$WORK/seed/.github/workflows/setup.yml"
    wf_update > "$WORK/seed/.github/workflows/update.yml"
    # Self-check: no unpinned i-d-template reference, image pinned by digest,
    # submit job disabled.
    ! grep -rn "i-d-template@\|i-d-template-action:" "$WORK/seed/.github" || die "seed has an unpinned i-d-template reference"
    grep -q "@sha256:" "$WORK/seed/.github/workflows/ghpages.yml" || die "seed image not pinned by digest"
    grep -q "^    if: false$" "$WORK/seed/.github/workflows/publish.yml" || die "seed submit job not disabled"
}

# ── Steps ────────────────────────────────────────────────────────────────────

step_repo() {
    say "repository $FULL"
    if [ "$REPO_EXISTS" = false ]; then
        mut POST "repos/$TEMPLATE/generate" "$(python3 -c '
import json, sys
print(json.dumps({"owner": sys.argv[1], "name": sys.argv[2], "description": sys.argv[3],
  "private": True, "include_all_branches": False}))' "$ORG" "$REPO" "$DESC")"
        return
    fi
    [ "$(rfield archived)" = "false" ] || die "$FULL is archived; unarchive it by hand before --apply"
    if [ "$(rfield visibility)" = "private" ]; then
        say "  = private"
    else
        say "  ! visibility is $(rfield visibility), want private; not changed by this script (the owner flips it at ID-H)"
    fi
}

step_settings() {
    say "settings"
    if [ "$REPO_EXISTS" = true ] && [ "$(rfield has_wiki)" = "false" ] && [ "$(rfield has_projects)" = "false" ] \
        && [ "$(rfield delete_branch_on_merge)" = "true" ] && [ "$(rfield description)" = "$DESC" ]; then
        say "  = settings match"
        return
    fi
    mut PATCH "repos/$FULL" "$(python3 -c '
import json, sys
print(json.dumps({"description": sys.argv[1], "has_wiki": False, "has_projects": False,
  "delete_branch_on_merge": True}))' "$DESC")"
}

step_cancel_template_runs() {
    # Runs on the template's own first commit use the unpinned image. Cancel
    # whatever is still queued or running there (best effort).
    say "workflow runs on the template commit"
    if [ "$MODE" = "dry-run" ]; then
        say "  + cancel queued/in-progress runs on the first commit (best effort)"
        return
    fi
    local ids id
    ids="$(gh api "repos/$FULL/actions/runs?per_page=20" --jq '.workflow_runs[] | select(.status != "completed") | .id' 2>/dev/null || true)"
    if [ -z "$ids" ]; then
        say "  = none running"
        return
    fi
    for id in $ids; do
        say "  + gh api -X POST repos/$FULL/actions/runs/$id/cancel"
        gh api -X POST "repos/$FULL/actions/runs/$id/cancel" > /dev/null 2>&1 || say "  ! could not cancel run $id (it may have finished)"
    done
}

step_variable() {
    say "repository variable SUBMIT_ENABLED"
    if [ "$REPO_EXISTS" = true ] && gh api "repos/$FULL/actions/variables/SUBMIT_ENABLED" > "$WORK/var.json" 2>/dev/null; then
        say "  = present, value '$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["value"])' "$WORK/var.json")' (owner-only; never changed here)"
        return
    fi
    mut POST "repos/$FULL/actions/variables" '{"name":"SUBMIT_ENABLED","value":"false"}'
}

step_seed() {
    say "seed commit on main"
    build_seed
    if [ "$REPO_EXISTS" = true ] && gh api "repos/$FULL/contents/$DRAFT.md" > /dev/null 2>&1; then
        say "  = $DRAFT.md present; seed already applied"
        local f
        for f in .github/workflows/ghpages.yml .github/workflows/publish.yml .github/workflows/submit-guard.yml; do
            if gh api "repos/$FULL/contents/$f" --jq .content 2>/dev/null | python3 -c 'import base64,sys; print(base64.b64decode(sys.stdin.read()).decode())' > "$WORK/cur"; then
                case "$f" in
                    *publish.yml)
                        if grep -q "^    if: false$" "$WORK/cur"; then say "  = $f: submit job disabled"; else say "  ! $f: submit job NOT disabled"; fi ;;
                    *ghpages.yml)
                        if grep -q "@sha256:" "$WORK/cur"; then say "  = $f: image pinned by digest"; else say "  ! $f: image not pinned by digest"; fi ;;
                    *) say "  = $f present" ;;
                esac
            else
                say "  ! $f missing"
            fi
        done
        return
    fi
    local f
    for f in $SEED_ADD; do say "  add    $f"; done
    for f in $SEED_DEL; do say "  remove $f"; done
    local msg="Seed $DRAFT: placeholder draft, pinned CI, submit job disabled

Adds the kramdown-rfc placeholder and CLAUDE.md, pins the i-d-template
action image by digest and other actions by commit SHA, disables the
datatracker submit job until ID-H, adds the Submit Guard workflow, and
drops the template's placeholder draft and scheduled archive workflow.

$SESSION_TRAILER"
    local base_tree head
    if [ "$MODE" = "dry-run" ]; then
        head="<main>"
        base_tree="<main tree>"
    else
        head="$(gh api "repos/$FULL/commits/main" --jq .sha)" || { echo "error: cannot read main" >&2; exit 1; }
        base_tree="$(gh api "repos/$FULL/commits/$head" --jq .commit.tree.sha)" || { echo "error: cannot read main's tree" >&2; exit 1; }
    fi
    : > "$WORK/entries"
    for f in $SEED_ADD; do
        mut POST "repos/$FULL/git/blobs" "$(python3 -c 'import base64,json,sys; print(json.dumps({"content": base64.b64encode(open(sys.argv[1],"rb").read()).decode(), "encoding": "base64"}))' "$WORK/seed/$f")"
        local blob="<blob>"
        [ "$MODE" = "dry-run" ] || blob="$(last sha)"
        printf '%s %s\n' "$f" "$blob" >> "$WORK/entries"
    done
    for f in $SEED_DEL; do printf '%s -\n' "$f" >> "$WORK/entries"; done
    mut POST "repos/$FULL/git/trees" "$(python3 - "$WORK/entries" "$base_tree" <<'PY'
import json, sys
tree = []
for line in open(sys.argv[1]):
    path, sha = line.split()
    tree.append({"path": path, "mode": "100644", "type": "blob", "sha": None if sha == "-" else sha})
print(json.dumps({"base_tree": sys.argv[2], "tree": tree}))
PY
)"
    local tree="<tree>"
    [ "$MODE" = "dry-run" ] || tree="$(last sha)"
    mut POST "repos/$FULL/git/commits" "$(python3 -c 'import json,sys; print(json.dumps({"message": sys.argv[1], "tree": sys.argv[2], "parents": [sys.argv[3]]}))' "$msg" "$tree" "$head")"
    local commit="<commit>"
    [ "$MODE" = "dry-run" ] || commit="$(last sha)"
    mut PATCH "repos/$FULL/git/refs/heads/main" "$(python3 -c 'import json,sys; print(json.dumps({"sha": sys.argv[1], "force": False}))' "$commit")"
}

rollback() {
    say "rollback: archive $FULL (never deleted)"
    read_repo
    if [ "$REPO_EXISTS" = false ]; then
        say "  = repository does not exist; nothing to do"
        return
    fi
    if [ "$(rfield archived)" = "true" ]; then
        say "  = already archived"
        return
    fi
    mut PATCH "repos/$FULL" '{"archived":true}'
}

# ── Main ─────────────────────────────────────────────────────────────────────

if [ "$MODE" = "emit" ]; then
    build_seed
    mkdir -p "$EMIT_DIR"
    cp -R "$WORK/seed/." "$EMIT_DIR/"
    say "seed files written to $EMIT_DIR"
    exit 0
fi

say "create-ietf-draft-repo: mode=$MODE repo=$FULL"

if [ "$MODE" = "rollback" ]; then
    rollback
    say "$CHANGES change(s)"
    exit 0
fi

read_repo
step_repo
if [ "$MODE" = "apply" ] && [ "$REPO_EXISTS" = false ]; then
    # The repository was just created; wait until it and its first commit
    # are readable.
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        read_repo
        [ "$REPO_EXISTS" = true ] && gh api "repos/$FULL/commits/main" > /dev/null 2>&1 && break
        sleep 3
    done
    [ "$REPO_EXISTS" = true ] || { echo "error: $FULL not readable after create" >&2; exit 1; }
    [ "$(rfield visibility)" = "private" ] || { echo "error: $FULL was created $(rfield visibility), not private; archive it with --rollback" >&2; exit 1; }
    step_cancel_template_runs
fi
step_settings
step_variable
step_seed
say "$CHANGES change(s)"

case "$MODE" in
    dry-run) say "dry-run: nothing changed (--apply to apply)" ;;
    apply) say "applied; verify with: gh repo view $FULL --json visibility; undo with --rollback (archives)" ;;
esac
