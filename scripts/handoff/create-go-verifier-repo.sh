#!/usr/bin/env bash
#
# create-go-verifier-repo.sh: create the public repository
# agentidentitytrustprotocol/aitp-verifier-go with its reviewed settings and
# seed files, and undo it.
#
# Usage:
#   scripts/handoff/create-go-verifier-repo.sh [--dry-run]   print every API call; change nothing (default)
#   scripts/handoff/create-go-verifier-repo.sh --apply       perform the calls the dry-run prints
#   scripts/handoff/create-go-verifier-repo.sh --rollback    archive the repository (never deletes it)
#   ... [--plan FILE]   phase plan to file issues from
#                       (default plans/cross-repo/aitp-verifier-go-v1-rc.md;
#                       plans/ is gitignored, so it exists only in a working copy)
#
# What it manages (and nothing else):
#   - the repository itself: public, Apache-2.0 LICENSE (GitHub license
#     template), description, homepage, topics, Discussions on, wiki off,
#     squash/merge/rebase allowed, auto-merge on, branch deleted on merge;
#   - private vulnerability reporting on;
#   - protection on main against force-push and deletion. Required status
#     checks are added later (plan phase GO4.3), once the CI jobs exist;
#   - the label `adoption` beside GitHub's defaults (created if missing,
#     never edited);
#   - the seed files README.md (skeleton with the independence statement),
#     CLAUDE.md and SPEC_VERSION (the spec repo's main SHA when first
#     written), each written only if absent;
#   - one issue per plan phase GO4.1-GO4.5 with the phase block inline,
#     created only if no issue with the same title exists;
#   - a check, read-only, that the aitp-deps-bot App installation covers the
#     repository. It does not change the installation.
#
# Every step reads current state first and does nothing when it already
# matches, so a second --apply is a no-op. Mutating calls are printed as
# `+ gh api ...` in every mode; --dry-run stops there.
#
# Requires: gh (authenticated, `repo` and `admin:org` for --apply), python3.
# Bash 3.2 compatible (macOS /bin/bash).
# Exit codes: 0 ok, 1 an API call failed, 2 usage or missing prerequisite.

set -euo pipefail

ORG="agentidentitytrustprotocol"
REPO="aitp-verifier-go"
SPEC="agentidentitytrustprotocol"
FULL="$ORG/$REPO"
DESC="Go AITP verifier written from the RFCs alone; zero dependencies, standard library only; cross-checks implementations against the spec's conformance fixtures"
HOME_URL="https://agentidentitytrustprotocol.io"
TOPICS="agent-identity ai-agents aitp conformance-testing go golang verifier"
BOT_APP="aitp-deps-bot"
SESSION_TRAILER="Claude-Session: https://claude.ai/code/session_01H8iVMfeYr9yAn3Qbvs2gY1"

LABEL_NAME="adoption"
LABEL_COLOR="0e8a16"
LABEL_DESC="Adoption of AITP by an implementation or integrator"

PHASES="GO4.1 GO4.2 GO4.3 GO4.4 GO4.5"

# ── Plumbing ─────────────────────────────────────────────────────────────────

die() { echo "error: $*" >&2; exit 2; }
say() { printf '%s\n' "$*"; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="dry-run"
PLAN="$ROOT/plans/cross-repo/aitp-verifier-go-v1-rc.md"
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) MODE="dry-run" ;;
        --apply) MODE="apply" ;;
        --rollback) MODE="rollback" ;;
        --plan) shift; [ $# -gt 0 ] || die "--plan needs a file"; PLAN="$1" ;;
        -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
    shift
done

command -v gh >/dev/null 2>&1 || die "gh is not installed"
command -v python3 >/dev/null 2>&1 || die "python3 is not installed"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

CHANGES=0

# mut METHOD PATH [JSON]: one mutating API call. Printed always; performed
# only under --apply / --rollback.
mut() {
    local method="$1" path="$2" body="${3:-}"
    CHANGES=$((CHANGES + 1))
    if [ -n "$body" ]; then
        say "  + gh api -X $method $path --input - <<< $(printf '%s' "$body" | python3 -c 'import json,sys; d=json.load(sys.stdin); d.pop("content",None) and d.setdefault("content","<base64 elided>"); d.pop("body",None) and d.setdefault("body","<phase block elided>"); print(json.dumps(d))')"
    else
        say "  + gh api -X $method $path"
    fi
    [ "$MODE" = "dry-run" ] && return 0
    if [ -n "$body" ]; then
        printf '%s' "$body" | gh api -X "$method" "$path" --input - > /dev/null || { echo "error: $method $path failed" >&2; exit 1; }
    else
        gh api -X "$method" "$path" > /dev/null || { echo "error: $method $path failed" >&2; exit 1; }
    fi
}

json() { python3 -c 'import json,sys; print(json.dumps(json.loads(sys.argv[1])))' "$1"; }

REPO_EXISTS=false
read_repo() {
    if gh api "repos/$FULL" > "$WORK/repo.json" 2>/dev/null; then
        REPO_EXISTS=true
    fi
}

rfield() {   # rfield KEY -> value from repo.json (lists space-joined)
    python3 - "$WORK/repo.json" "$1" <<'PY'
import json, sys
v = json.load(open(sys.argv[1])).get(sys.argv[2])
if isinstance(v, bool): print("true" if v else "false")
elif isinstance(v, list): print(" ".join(sorted(v)))
elif isinstance(v, dict): print(v.get("spdx_id", ""))
elif v is None: print("")
else: print(v)
PY
}

# ── Steps ────────────────────────────────────────────────────────────────────

step_repo() {
    say "repository $FULL"
    if [ "$REPO_EXISTS" = false ]; then
        mut POST "orgs/$ORG/repos" "$(python3 -c '
import json, sys
print(json.dumps({"name": sys.argv[1], "description": sys.argv[2], "homepage": sys.argv[3],
  "visibility": "public", "has_issues": True, "has_wiki": False, "has_projects": True,
  "has_discussions": True, "auto_init": True, "license_template": "apache-2.0",
  "allow_squash_merge": True, "allow_merge_commit": True, "allow_rebase_merge": True,
  "allow_auto_merge": True, "delete_branch_on_merge": True}))' "$REPO" "$DESC" "$HOME_URL")"
        mut PUT "repos/$FULL/topics" "$(python3 -c 'import json,sys; print(json.dumps({"names": sys.argv[1].split()}))' "$TOPICS")"
        return
    fi
    [ "$(rfield archived)" = "false" ] || die "$FULL is archived; unarchive it by hand before --apply"
    [ "$(rfield visibility)" = "public" ] || say "  ! visibility is $(rfield visibility), want public (not changed by this script)"
    [ "$(rfield license)" = "Apache-2.0" ] || say "  ! license is '$(rfield license)', want Apache-2.0 (not changed by this script)"
    local patch_needed=false
    [ "$(rfield description)" = "$DESC" ] || patch_needed=true
    [ "$(rfield homepage)" = "$HOME_URL" ] || patch_needed=true
    [ "$(rfield has_discussions)" = "true" ] || patch_needed=true
    [ "$(rfield has_wiki)" = "false" ] || patch_needed=true
    [ "$(rfield allow_auto_merge)" = "true" ] || patch_needed=true
    [ "$(rfield delete_branch_on_merge)" = "true" ] || patch_needed=true
    if [ "$patch_needed" = true ]; then
        mut PATCH "repos/$FULL" "$(python3 -c '
import json, sys
print(json.dumps({"description": sys.argv[1], "homepage": sys.argv[2], "has_discussions": True,
  "has_wiki": False, "allow_auto_merge": True, "delete_branch_on_merge": True}))' "$DESC" "$HOME_URL")"
    else
        say "  = settings match"
    fi
    if [ "$(rfield topics)" = "$(echo "$TOPICS" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')" ]; then
        say "  = topics match"
    else
        mut PUT "repos/$FULL/topics" "$(python3 -c 'import json,sys; print(json.dumps({"names": sys.argv[1].split()}))' "$TOPICS")"
    fi
}

step_pvr() {
    say "private vulnerability reporting"
    if [ "$REPO_EXISTS" = true ] && [ "$(gh api "repos/$FULL/private-vulnerability-reporting" --jq .enabled 2>/dev/null || echo unknown)" = "true" ]; then
        say "  = enabled"
    else
        mut PUT "repos/$FULL/private-vulnerability-reporting"
    fi
}

step_protection() {
    say "branch protection on main"
    if [ "$REPO_EXISTS" = true ] && gh api "repos/$FULL/branches/main/protection" > "$WORK/prot.json" 2>/dev/null; then
        if [ "$(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); print(p["allow_force_pushes"]["enabled"], p["allow_deletions"]["enabled"])' "$WORK/prot.json")" = "False False" ]; then
            say "  = force-push and deletion blocked"
            return
        fi
        # Protection exists (perhaps with required checks from GO4.3): change
        # only the two flags, keep everything else.
        mut PUT "repos/$FULL/branches/main/protection" "$(python3 - "$WORK/prot.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
rsc = p.get("required_status_checks")
body = {
    "required_status_checks": None if not rsc else {"strict": rsc.get("strict", False), "contexts": rsc.get("contexts", [])},
    "enforce_admins": bool(p.get("enforce_admins", {}).get("enabled")),
    "required_pull_request_reviews": None,
    "restrictions": None,
    "allow_force_pushes": False,
    "allow_deletions": False,
}
print(json.dumps(body))
PY
)"
        return
    fi
    mut PUT "repos/$FULL/branches/main/protection" "$(json '{"required_status_checks":null,"enforce_admins":false,"required_pull_request_reviews":null,"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}')"
}

step_labels() {
    say "labels"
    if [ "$REPO_EXISTS" = true ] && gh api --paginate "repos/$FULL/labels?per_page=100" --jq '.[].name' 2>/dev/null | grep -qxF "$LABEL_NAME"; then
        say "  = $LABEL_NAME present"
    else
        mut POST "repos/$FULL/labels" "$(python3 -c 'import json,sys; print(json.dumps({"name":sys.argv[1],"color":sys.argv[2],"description":sys.argv[3]}))' "$LABEL_NAME" "$LABEL_COLOR" "$LABEL_DESC")"
    fi
}

seed_readme() {
    cat <<'EOF'
# aitp-verifier-go

A Go verifier for the [Agent Identity & Trust Protocol (AITP)](https://github.com/agentidentitytrustprotocol/agentidentitytrustprotocol), written from the RFCs alone. It depends on nothing outside the Go standard library and checks itself against the spec's known-answer vectors and conformance fixtures.

> **Status: pre-release.** The primitives come first; the verifiers and the conformance adapter follow. Nothing is tagged yet.

## Install

Not yet released. The module path will be `github.com/agentidentitytrustprotocol/aitp-verifier-go`.

## Verifiers

To come.

## Conformance adapter

To come: `cmd/aitp-verifier-adapter`, driven by `aitp-conformance`.

## CI

To come.

## Primitives

To come.

## Non-goals

- Signing production artifacts. Test-only signing with the published known-answer keys lives in the conformance adapter alone.
- Network fetches. Verifiers take an injected transport and never read the wall clock.

## Independence

Written from the RFCs, schemas and conformance expectations only. Shares no code with aitp-rs, aitp-verifier-py or aitp-verifier-ts and meets them only at the known-answer vectors. **Same author** as the other implementations: independent in code, not in authorship. It does not satisfy the v1.0 different-authorship criterion.

## Development

Go 1.26 or newer. `gofmt -l .`, `go vet ./...` and `go test ./...` must be clean. The pinned spec commit is in `SPEC_VERSION`.

## License

Apache-2.0. See [LICENSE](LICENSE).
EOF
}

seed_claude_md() {
    cat <<'EOF'
# CLAUDE.md: aitp-verifier-go

Guidance for agent sessions working in this repository.

## Independence rule (load-bearing)

This verifier is written from the AITP RFCs, JSON Schemas, registries and
conformance fixtures **only**. Do not open, read, search or paste source code
from `aitp-rs`, `aitp-verifier-ts` or `aitp-verifier-py`. Their READMEs and
published conformance reports are fine; their code is not. The README's
Independence section states this as a provenance claim, and breaking it
makes the claim false.

When the spec is ambiguous, cite the RFC section (`RFC-AITP-NNNN §x.y`) and
open a `spec-bug` issue on the spec repository rather than copying what
another implementation does.

## Hard constraints

- **Zero dependencies.** `go list -m all` prints only this module. JCS, the
  strict JSON tokenizer, JWS, base64url and the curve checks are written
  here on top of the standard library.
- **Go 1.26 floor** (`go.mod`), CI on 1.26 and 1.27.
- **No network, no wall clock** in verifiers. Time comes from the caller.
- Module path `github.com/agentidentitytrustprotocol/aitp-verifier-go`; the
  library is the root package `aitpverifier`, binaries live under `cmd/`.

## Spec pin

`SPEC_VERSION` holds the spec commit this code is tested against. Test data
(known-answer vectors, fixtures, schemas, the error-code registry) is
vendored from that commit under `vendor/spec/`; never edit it by hand.

## Before every commit

```sh
gofmt -l .        # must print nothing
go vet ./...
go test ./...
```

## Git

Branch, open a PR, merge on green CI. No force-push to main.
EOF
}

step_seed_file() {   # step_seed_file PATH MESSAGE CONTENT-FILE
    local path="$1" msg="$2" src="$3"
    if [ "$REPO_EXISTS" = true ] && gh api "repos/$FULL/contents/$path" > /dev/null 2>&1; then
        say "  = $path present"
        return
    fi
    mut PUT "repos/$FULL/contents/$path" "$(python3 - "$src" "$msg" <<'PY'
import base64, json, sys
print(json.dumps({"message": sys.argv[2], "content": base64.b64encode(open(sys.argv[1], "rb").read()).decode(), "branch": "main"}))
PY
)"
}

step_seed() {
    say "seed files"
    seed_readme > "$WORK/README.md"
    seed_claude_md > "$WORK/CLAUDE.md"
    local spec_sha
    spec_sha="$(gh api "repos/$ORG/$SPEC/commits/main" --jq .sha)" || die "cannot read the spec repo's main SHA"
    printf '%s\n' "$spec_sha" > "$WORK/SPEC_VERSION"
    step_seed_file README.md "docs: README skeleton with the independence statement

$SESSION_TRAILER" "$WORK/README.md"
    step_seed_file CLAUDE.md "docs: CLAUDE.md with the independence rule and constraints

$SESSION_TRAILER" "$WORK/CLAUDE.md"
    step_seed_file SPEC_VERSION "chore: pin the spec at $spec_sha

$SESSION_TRAILER" "$WORK/SPEC_VERSION"
}

step_issues() {
    say "phase issues"
    if [ ! -f "$PLAN" ]; then
        say "  ! plan not found at $PLAN; issues skipped (pass --plan FILE)"
        return
    fi
    if [ "$REPO_EXISTS" = true ]; then
        gh issue list -R "$FULL" --state all --limit 200 --json title --jq '.[].title' > "$WORK/issues.txt" 2>/dev/null || : > "$WORK/issues.txt"
    else
        : > "$WORK/issues.txt"
    fi
    local p
    for p in $PHASES; do
        python3 - "$PLAN" "$p" "$WORK/issue.json" <<'PY' || die "phase $p not found in $PLAN"
import json, re, sys
plan, phase, out = sys.argv[1:4]
text = open(plan).read()
m = re.search(r"^## (" + re.escape(phase) + r":[^\n]*)\n(.*?)(?=^## |\Z)", text, re.S | re.M)
if not m:
    sys.exit(3)
title = m.group(1).strip()
body = (m.group(2).strip() + "\n\n---\nFiled from the cross-repo plan `aitp-verifier-go-v1-rc` (spec repository, "
        "kept out of git). The phase block above is the full content.\n")
json.dump({"title": title, "body": body}, open(out, "w"))
PY
        local title
        title="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["title"])' "$WORK/issue.json")"
        if grep -qxF "$title" "$WORK/issues.txt"; then
            say "  = issue \"$title\" exists"
        else
            mut POST "repos/$FULL/issues" "$(cat "$WORK/issue.json")"
        fi
    done
}

step_bot() {
    say "$BOT_APP installation"
    local sel
    sel="$(gh api "orgs/$ORG/installations" --jq ".installations[] | select(.app_slug==\"$BOT_APP\") | .repository_selection" 2>/dev/null || true)"
    case "$sel" in
        all) say "  = covers all repositories, including $REPO" ;;
        selected) say "  ! installed on selected repositories: add $REPO in the App's installation settings (owner step)" ;;
        "") say "  ! installation not readable or not present (needs admin:org)" ;;
    esac
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
    mut PATCH "repos/$FULL" "$(json '{"archived":true}')"
}

# ── Main ─────────────────────────────────────────────────────────────────────

say "create-go-verifier-repo: mode=$MODE repo=$FULL"

if [ "$MODE" = "rollback" ]; then
    rollback
    say "$CHANGES change(s)"
    exit 0
fi

read_repo
step_repo
if [ "$MODE" = "apply" ] && [ "$REPO_EXISTS" = false ]; then
    # The repository was just created; read it back so later steps see it.
    for _ in 1 2 3 4 5; do read_repo; [ "$REPO_EXISTS" = true ] && break; sleep 2; done
    [ "$REPO_EXISTS" = true ] || { echo "error: $FULL not readable after create" >&2; exit 1; }
fi
step_pvr
step_seed
step_protection
step_labels
step_issues
step_bot
say "$CHANGES change(s)"

case "$MODE" in
    dry-run) say "dry-run: nothing changed (--apply to apply)" ;;
    apply) say "applied; verify with: gh api repos/$FULL; undo with --rollback (archives)" ;;
esac
