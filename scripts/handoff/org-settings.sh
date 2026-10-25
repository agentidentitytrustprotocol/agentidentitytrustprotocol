#!/usr/bin/env bash
#
# org-settings.sh: bring the agentidentitytrustprotocol GitHub org's public
# repositories to one reviewed set of settings, and undo it.
#
# Usage:
#   scripts/handoff/org-settings.sh [--dry-run]           print the diff; change nothing (default)
#   scripts/handoff/org-settings.sh --snapshot            write a snapshot of current settings; change nothing
#   scripts/handoff/org-settings.sh --apply               write a snapshot, then apply the diff
#   scripts/handoff/org-settings.sh --rollback FILE       restore the settings recorded in FILE
#   ... [--only REPO]                                     limit to one repository (skips org-level items)
#
# What it manages (and nothing else):
#   - description, homepage and topics on every public repository;
#   - Discussions on the spec repo, aitp-rs and aitp-verifier-py;
#   - private vulnerability reporting on every public repository;
#   - the labels `good first issue` and `help wanted` everywhere, plus
#     `spec-bug` and `rfc` on the spec repo (created if missing, never edited);
#   - the org Actions variable AITP_BOT_CLIENT_ID (the aitp-deps-bot App's
#     client ID, which is public; actions/create-github-app-token takes
#     `client-id`);
#   - the org `.github/SECURITY.md` supply-chain sentence, which claimed every
#     repository SHA-pins its Actions. The fix is opened as a pull request on
#     the `.github` repository, never pushed.
#
# Snapshots go to $AITP_SNAPSHOT_DIR (default ~/.local/state/aitp-handoff/) as
# org-settings-<UTC timestamp>.json. Topics are replaced, not merged, so the
# snapshot is what makes --apply reversible.
#
# Requires: gh (authenticated), python3. Bash 3.2 compatible (macOS /bin/bash).
# --apply and --rollback need a token with `repo` and `admin:org`; the dry-run
# reports missing scopes first and marks any setting it cannot read as `?`.
# Exit codes: 0 ok, 1 an API call failed, 2 usage or missing prerequisite.

set -euo pipefail

ORG="agentidentitytrustprotocol"
SPEC="agentidentitytrustprotocol"
PUBLIC_REPOS="agentidentitytrustprotocol aitp-rs aitp-verifier-py aitp-control-plane aitp-playground aitp-ui-console aitp-ci .github"
DISCUSSION_REPOS="agentidentitytrustprotocol aitp-rs aitp-verifier-py"
SITE="https://agentidentitytrustprotocol.io"

CLIENT_ID_VAR="AITP_BOT_CLIENT_ID"
CLIENT_ID_VALUE="Iv23li4Fl1Nz7LECF6xa"   # aitp-deps-bot; public (GET /apps/aitp-deps-bot)

SEC_REPO=".github"
SEC_PATH="SECURITY.md"
SEC_BRANCH="handoff/security-md-action-pinning"
SEC_OLD="Third-party GitHub Actions
are SHA-pinned across the org."
SEC_NEW="The spec repository pins
third-party GitHub Actions to commit SHAs; the other repositories reference
them by version tag."

# ── Desired state ────────────────────────────────────────────────────────────

desc_for() {
    case "$1" in
        agentidentitytrustprotocol) echo "Agent Identity & Trust Protocol (AITP) specification: RFCs, JSON Schemas, registries and conformance fixtures for agent-to-agent trust" ;;
        aitp-rs) echo "Rust reference implementation of the Agent Identity & Trust Protocol (AITP), with Python and Node bindings" ;;
        aitp-verifier-py) echo "Python AITP verifier written from the RFCs alone; cross-checks implementations against the spec's conformance fixtures" ;;
        aitp-control-plane) echo "Reference tooling, not multi-tenant: AITP agent registry, audit log, revocation relay and webhooks" ;;
        aitp-playground) echo "Demo service: AITP scenarios run end to end with LLM agents that handshake and exchange TCTs" ;;
        aitp-ui-console) echo "Demo console for the AITP playground and control plane" ;;
        aitp-ci) echo "Shared CI/CD reusable workflows + the AITP delivery standard" ;;
        .github) echo "AITP org profile, security policy, and workflow templates" ;;
    esac
}

home_for() {
    case "$1" in
        aitp-rs) echo "https://docs.rs/aitp" ;;
        aitp-ui-console) echo "https://aitp-ui-console.vercel.app" ;;
        aitp-ci|.github) echo "" ;;
        *) echo "$SITE" ;;
    esac
}

topics_for() {   # space-separated, sorted
    case "$1" in
        agentidentitytrustprotocol) echo "a2a agent-identity ai-agents aitp conformance-testing json-schema jws protocol specification trust" ;;
        aitp-rs) echo "a2a agent-identity ai-agents aitp jws nodejs python rust trust" ;;
        aitp-verifier-py) echo "agent-identity ai-agents aitp conformance-testing python verifier" ;;
        aitp-control-plane) echo "ai-agents aitp audit-log control-plane reference-implementation revocation" ;;
        aitp-playground) echo "ai-agents aitp demo fastapi llm playground" ;;
        aitp-ui-console) echo "ai-agents aitp dashboard demo nextjs" ;;
        aitp-ci) echo "aitp ci github-actions reusable-workflows" ;;
        .github) echo "aitp community-health" ;;
    esac
}

wants_discussions() {
    case " $DISCUSSION_REPOS " in *" $1 "*) echo true ;; *) echo false ;; esac
}

labels_for() {   # one per line
    echo "good first issue"
    echo "help wanted"
    if [ "$1" = "$SPEC" ]; then
        echo "spec-bug"
        echo "rfc"
    fi
}

label_color() {
    case "$1" in
        "good first issue") echo "7057ff" ;;
        "help wanted") echo "008672" ;;
        spec-bug) echo "d73a4a" ;;
        rfc) echo "1d76db" ;;
    esac
}

label_desc() {
    case "$1" in
        "good first issue") echo "Good for newcomers" ;;
        "help wanted") echo "Extra attention is needed" ;;
        spec-bug) echo "Ambiguity, contradiction or error in the spec, schemas or fixtures" ;;
        rfc) echo "RFC proposal or substantive RFC change" ;;
    esac
}

# ── Plumbing ─────────────────────────────────────────────────────────────────

die() { echo "error: $*" >&2; exit 2; }
say() { printf '%s\n' "$*"; }

MODE="dry-run"
ROLLBACK_FILE=""
ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) MODE="dry-run" ;;
        --snapshot) MODE="snapshot" ;;
        --apply) MODE="apply" ;;
        --rollback) MODE="rollback"; shift; [ $# -gt 0 ] || die "--rollback needs a snapshot file"; ROLLBACK_FILE="$1" ;;
        --only) shift; [ $# -gt 0 ] || die "--only needs a repository name"; ONLY="$1" ;;
        -h|--help) sed -n '2,36p' "$0"; exit 0 ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
    shift
done

command -v gh >/dev/null 2>&1 || die "gh is not installed"
command -v python3 >/dev/null 2>&1 || die "python3 is not installed"

REPOS="$PUBLIC_REPOS"
if [ -n "$ONLY" ]; then
    case " $PUBLIC_REPOS " in *" $ONLY "*) REPOS="$ONLY" ;; *) die "--only: $ONLY is not a managed repository" ;; esac
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Scope preflight. A classic token reports its scopes in X-OAuth-Scopes; an
# App or fine-grained token reports none, and is then checked call by call.
check_scopes() {
    local hdr scopes missing=""
    hdr="$(gh api -i user 2>/dev/null | tr -d '\r' | grep -i '^x-oauth-scopes:' || true)"
    if [ -z "$hdr" ]; then
        say "scopes: not reported by this token (App or fine-grained); unreadable settings show as ?"
        return 0
    fi
    scopes=" $(echo "${hdr#*:}" | tr ',' ' ') "
    case "$scopes" in *" repo "*) ;; *) missing="$missing repo" ;; esac
    case "$scopes" in *" admin:org "*) ;; *) missing="$missing admin:org" ;; esac
    if [ -n "$missing" ]; then
        say "scopes: missing:$missing"
        if [ "$MODE" = "apply" ] || [ "$MODE" = "rollback" ]; then
            die "the gh token lacks:$missing (gh auth refresh -s${missing// / -s })"
        fi
    else
        say "scopes: repo, admin:org present"
    fi
}

# Read one repository's current state into $WORK/<repo>.state (JSON).
read_repo() {
    local r="$1" f="$WORK/$1"
    gh api "repos/$ORG/$r" > "$f.repo.json" 2>/dev/null || die "cannot read repos/$ORG/$r"
    if ! gh api "repos/$ORG/$r/private-vulnerability-reporting" > "$f.pvr.json" 2>/dev/null; then
        echo 'null' > "$f.pvr.json"
    fi
    if ! gh api --paginate "repos/$ORG/$r/labels?per_page=100" --jq '.[].name' > "$f.labels.txt" 2>/dev/null; then
        : > "$f.labels.txt"; echo unreadable > "$f.labels.err"
    fi
    python3 - "$f" <<'PY'
import json, os, sys
f = sys.argv[1]
repo = json.load(open(f + ".repo.json"))
pvr = json.load(open(f + ".pvr.json"))
labels = None if os.path.exists(f + ".labels.err") else [l for l in open(f + ".labels.txt").read().split("\n") if l]
state = {
    "description": repo.get("description") or "",
    "homepage": repo.get("homepage") or "",
    "topics": sorted(repo.get("topics") or []),
    "has_discussions": bool(repo.get("has_discussions")),
    "private_vulnerability_reporting": (pvr or {}).get("enabled") if pvr is not None else None,
    "labels": labels,
}
json.dump(state, open(f + ".state", "w"), indent=2, sort_keys=True)
PY
}

field() {   # field <repo> <key>  -> scalar; lists space-joined; null -> ?
    python3 - "$WORK/$1.state" "$2" <<'PY'
import json, sys
v = json.load(open(sys.argv[1]))[sys.argv[2]]
if v is None: print("?")
elif isinstance(v, bool): print("true" if v else "false")
elif isinstance(v, list): print(" ".join(v))
else: print(v)
PY
}

has_label() { grep -qxF "$2" "$WORK/$1.labels.txt"; }

# Org variable: present / absent / ? (unreadable).
read_org_var() {
    if ! gh api "orgs/$ORG/actions/variables?per_page=30" --jq '.variables[].name' > "$WORK/orgvars.txt" 2>/dev/null; then
        echo "?"; return
    fi
    if grep -qxF "$CLIENT_ID_VAR" "$WORK/orgvars.txt"; then
        gh api "orgs/$ORG/actions/variables/$CLIENT_ID_VAR" > "$WORK/orgvar.json"
        echo present
    else
        echo absent
    fi
}

# Org SECURITY.md: fixed / needs-fix / pr-open / ? .
read_security_md() {
    if ! gh api "repos/$ORG/$SEC_REPO/contents/$SEC_PATH" --jq .content > "$WORK/sec.b64" 2>/dev/null; then
        echo "?"; return
    fi
    python3 - "$WORK/sec.b64" "$WORK/sec.md" <<'PY'
import base64, sys
open(sys.argv[2], "wb").write(base64.b64decode(open(sys.argv[1]).read()))
PY
    if python3 - "$WORK/sec.md" "$SEC_OLD" <<'PY'
import sys
sys.exit(0 if sys.argv[2] in open(sys.argv[1]).read() else 1)
PY
    then
        if [ -n "$(gh pr list -R "$ORG/$SEC_REPO" --head "$SEC_BRANCH" --state open --json number --jq '.[0].number' 2>/dev/null)" ]; then
            echo pr-open
        else
            echo needs-fix
        fi
    else
        echo fixed
    fi
}

# ── Diff ─────────────────────────────────────────────────────────────────────

CHANGES=0
change() { CHANGES=$((CHANGES + 1)); say "  ~ $*"; }

diff_repo() {
    local r="$1" cur want
    say "$r"
    cur="$(field "$r" description)"; want="$(desc_for "$r")"
    [ "$cur" = "$want" ] || change "description: \"$cur\" -> \"$want\""
    cur="$(field "$r" homepage)"; want="$(home_for "$r")"
    [ "$cur" = "$want" ] || change "homepage: \"$cur\" -> \"$want\""
    cur="$(field "$r" topics)"; want="$(topics_for "$r")"
    [ "$cur" = "$want" ] || change "topics: [$cur] -> [$want]"
    cur="$(field "$r" has_discussions)"; want="$(wants_discussions "$r")"
    [ "$cur" = "$want" ] || change "has_discussions: $cur -> $want"
    cur="$(field "$r" private_vulnerability_reporting)"
    [ "$cur" = "true" ] || change "private_vulnerability_reporting: $cur -> true"
    if [ -f "$WORK/$r.labels.err" ]; then
        change "labels: ? (unreadable)"
    else
        labels_for "$r" > "$WORK/want-labels.txt"
        while IFS= read -r l; do
            has_label "$r" "$l" || change "label \"$l\": missing -> create"
        done < "$WORK/want-labels.txt"
    fi
}

ORGVAR_STATE=""
SEC_STATE=""
diff_org() {
    say "org"
    ORGVAR_STATE="$(read_org_var)"
    case "$ORGVAR_STATE" in
        absent) change "variable $CLIENT_ID_VAR: absent -> $CLIENT_ID_VALUE (visibility all)" ;;
        "?") change "variable $CLIENT_ID_VAR: ? (unreadable; needs admin:org)" ;;
        present)
            if [ "$(python3 -c 'import json,sys; v=json.load(open(sys.argv[1])); print(v["value"]+" "+v["visibility"])' "$WORK/orgvar.json")" != "$CLIENT_ID_VALUE all" ]; then
                change "variable $CLIENT_ID_VAR: differs -> $CLIENT_ID_VALUE (visibility all)"
            fi ;;
    esac
    SEC_STATE="$(read_security_md)"
    case "$SEC_STATE" in
        needs-fix) change "$SEC_REPO/$SEC_PATH: SHA-pin sentence -> open PR from $SEC_BRANCH" ;;
        pr-open) say "  = $SEC_REPO/$SEC_PATH: fix PR already open" ;;
        "?") change "$SEC_REPO/$SEC_PATH: ? (unreadable)" ;;
    esac
}

# ── Snapshot ─────────────────────────────────────────────────────────────────

write_snapshot() {
    local dir="${AITP_SNAPSHOT_DIR:-$HOME/.local/state/aitp-handoff}" out
    mkdir -p "$dir"
    out="$dir/org-settings-$(date -u +%Y%m%dT%H%M%SZ).json"
    python3 - "$WORK" "$out" "$ORG" "$ORGVAR_STATE" "$CLIENT_ID_VAR" "$SEC_STATE" "$REPOS" <<'PY'
import json, os, sys, datetime
work, out, org, varstate, varname, secstate = sys.argv[1:7]
repos = sys.argv[7].split()
snap = {
    "taken_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "org": org,
    "repos": {r: json.load(open(os.path.join(work, r + ".state"))) for r in repos},
}
if varstate == "present":
    v = json.load(open(os.path.join(work, "orgvar.json")))
    snap["org_variables"] = {varname: {"value": v["value"], "visibility": v["visibility"]}}
elif varstate == "absent":
    snap["org_variables"] = {varname: None}
if secstate in ("needs-fix", "pr-open", "fixed"):
    snap["org_security_md"] = secstate
json.dump(snap, open(out, "w"), indent=2, sort_keys=True)
print(out)
PY
}

# ── Apply ────────────────────────────────────────────────────────────────────

api_json() {   # api_json METHOD PATH JSON
    printf '%s' "$3" | gh api -X "$1" "$2" --input - > /dev/null
}

set_repo_fields() {   # set_repo_fields REPO DESC HOME DISCUSSIONS(true|false) "TOPICS"
    local body topics
    body="$(python3 -c 'import json,sys; print(json.dumps({"description":sys.argv[1],"homepage":sys.argv[2],"has_discussions":sys.argv[3]=="true"}))' "$2" "$3" "$4")"
    api_json PATCH "repos/$ORG/$1" "$body"
    topics="$(python3 -c 'import json,sys; print(json.dumps({"names":sys.argv[1].split()}))' "$5")"
    api_json PUT "repos/$ORG/$1/topics" "$topics"
}

set_pvr() {   # set_pvr REPO true|false
    if [ "$2" = "true" ]; then
        gh api -X PUT "repos/$ORG/$1/private-vulnerability-reporting" > /dev/null
    else
        gh api -X DELETE "repos/$ORG/$1/private-vulnerability-reporting" > /dev/null
    fi
}

apply_repo() {
    local r="$1"
    set_repo_fields "$r" "$(desc_for "$r")" "$(home_for "$r")" "$(wants_discussions "$r")" "$(topics_for "$r")"
    set_pvr "$r" true
    labels_for "$r" | while IFS= read -r l; do
        if ! has_label "$r" "$l"; then
            gh api -X POST "repos/$ORG/$r/labels" -f name="$l" -f color="$(label_color "$l")" -f description="$(label_desc "$l")" > /dev/null
        fi
    done
    say "  applied $r"
}

apply_org_var() {
    local body
    body="$(python3 -c 'import json,sys; print(json.dumps({"name":sys.argv[1],"value":sys.argv[2],"visibility":"all"}))' "$CLIENT_ID_VAR" "$CLIENT_ID_VALUE")"
    case "$ORGVAR_STATE" in
        absent) api_json POST "orgs/$ORG/actions/variables" "$body" ;;
        present) api_json PATCH "orgs/$ORG/actions/variables/$CLIENT_ID_VAR" "$body" ;;
        *) return 0 ;;
    esac
    say "  applied variable $CLIENT_ID_VAR"
}

apply_security_md() {
    [ "$SEC_STATE" = "needs-fix" ] || return 0
    local base sha content
    base="$(gh api "repos/$ORG/$SEC_REPO/git/ref/heads/main" --jq .object.sha)"
    if ! gh api "repos/$ORG/$SEC_REPO/git/ref/heads/$SEC_BRANCH" > /dev/null 2>&1; then
        gh api -X POST "repos/$ORG/$SEC_REPO/git/refs" -f ref="refs/heads/$SEC_BRANCH" -f sha="$base" > /dev/null
    fi
    sha="$(gh api "repos/$ORG/$SEC_REPO/contents/$SEC_PATH?ref=$SEC_BRANCH" --jq .sha)"
    content="$(python3 - "$WORK/sec.md" "$SEC_OLD" "$SEC_NEW" <<'PY'
import base64, sys
text = open(sys.argv[1]).read().replace(sys.argv[2], sys.argv[3], 1)
print(base64.b64encode(text.encode()).decode())
PY
)"
    gh api -X PUT "repos/$ORG/$SEC_REPO/contents/$SEC_PATH" \
        -f message="docs: SECURITY.md states which repositories SHA-pin Actions" \
        -f content="$content" -f sha="$sha" -f branch="$SEC_BRANCH" > /dev/null
    gh pr create -R "$ORG/$SEC_REPO" --head "$SEC_BRANCH" --base main \
        --title "docs: SECURITY.md states which repositories SHA-pin Actions" \
        --body "Only the spec repository pins third-party Actions to commit SHAs; the other repositories reference them by version tag. The previous sentence claimed SHA pinning across the org. Opened by agentidentitytrustprotocol/scripts/handoff/org-settings.sh." > /dev/null
    say "  opened PR on $SEC_REPO from $SEC_BRANCH"
}

# ── Rollback ─────────────────────────────────────────────────────────────────

rollback() {
    [ -f "$ROLLBACK_FILE" ] || die "no such snapshot: $ROLLBACK_FILE"
    local r
    for r in $REPOS; do
        python3 - "$ROLLBACK_FILE" "$r" > "$WORK/rb.tsv" <<'PY' || { say "$r: not in snapshot, skipped"; continue; }
import json, sys
s = json.load(open(sys.argv[1]))["repos"].get(sys.argv[2])
if s is None: sys.exit(3)
pvr = s["private_vulnerability_reporting"]
print("\x1f".join([s["description"], s["homepage"], "true" if s["has_discussions"] else "false",
                 " ".join(s["topics"]), "?" if pvr is None else ("true" if pvr else "false"),
                 "?" if s["labels"] is None else "|".join(s["labels"])]))
PY
        local d h disc topics pvr labels
        IFS="$(printf '\037')" read -r d h disc topics pvr labels < "$WORK/rb.tsv"
        set_repo_fields "$r" "$d" "$h" "$disc" "$topics"
        [ "$pvr" = "?" ] || set_pvr "$r" "$pvr"
        if [ "$labels" != "?" ]; then
            labels_for "$r" | while IFS= read -r l; do
                case "|$labels|" in *"|$l|"*) ;; *)
                    gh api -X DELETE "repos/$ORG/$r/labels/$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$l")" > /dev/null 2>&1 || true ;;
                esac
            done
        fi
        say "  restored $r"
    done
    [ -z "$ONLY" ] || return 0
    local var
    var="$(python3 -c 'import json,sys; s=json.load(open(sys.argv[1])).get("org_variables",{}); print("skip" if sys.argv[2] not in s else ("absent" if s[sys.argv[2]] is None else json.dumps(s[sys.argv[2]])))' "$ROLLBACK_FILE" "$CLIENT_ID_VAR")"
    case "$var" in
        skip) ;;
        absent) gh api -X DELETE "orgs/$ORG/actions/variables/$CLIENT_ID_VAR" > /dev/null 2>&1 || true; say "  removed variable $CLIENT_ID_VAR" ;;
        *) api_json PATCH "orgs/$ORG/actions/variables/$CLIENT_ID_VAR" "$(python3 -c 'import json,sys; v=json.loads(sys.argv[1]); v["name"]=sys.argv[2]; print(json.dumps(v))' "$var" "$CLIENT_ID_VAR")"; say "  restored variable $CLIENT_ID_VAR" ;;
    esac
    local pr
    pr="$(gh pr list -R "$ORG/$SEC_REPO" --head "$SEC_BRANCH" --state open --json number --jq '.[0].number' 2>/dev/null || true)"
    if [ -n "$pr" ]; then
        gh pr close "$pr" -R "$ORG/$SEC_REPO" --delete-branch > /dev/null
        say "  closed $SEC_REPO PR #$pr"
    elif [ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("org_security_md",""))' "$ROLLBACK_FILE")" = "needs-fix" ]; then
        say "  note: the $SEC_REPO SECURITY.md fix is merged; revert it with a PR if it must go"
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

say "org-settings: mode=$MODE org=$ORG${ONLY:+ only=$ONLY}"
check_scopes

if [ "$MODE" = "rollback" ]; then
    rollback
    exit 0
fi

for r in $REPOS; do read_repo "$r"; done
for r in $REPOS; do diff_repo "$r"; done
if [ -z "$ONLY" ]; then diff_org; fi
say "$CHANGES change(s)"

case "$MODE" in
    dry-run) say "dry-run: nothing changed (--apply to apply)" ;;
    snapshot) say "snapshot: $(write_snapshot)" ;;
    apply)
        say "snapshot: $(write_snapshot)"
        for r in $REPOS; do apply_repo "$r"; done
        if [ -z "$ONLY" ]; then apply_org_var; apply_security_md; fi
        say "applied; undo with --rollback <snapshot>" ;;
esac
