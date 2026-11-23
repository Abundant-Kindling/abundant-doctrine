#!/usr/bin/env bash
# careful.git.test.sh: behavioural tests for the git-aware guards in careful.js
# (commit onto a deploy branch, PR merge with unfinished checks).
#
# Feeds a command to the hook on stdin exactly as Claude Code does and asserts
# the exit code: 2 = blocked, 0 = allowed. Nothing is executed. Everything runs
# in throwaway directories; `gh` is a stub placed first on PATH, so no network
# and no real repository is touched.
#
# Run from anywhere:  bash hooks/careful.git.test.sh
# Needs: bash, git, node.

set -u
HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/careful.js"

WORK="$(mktemp -d)"
# find -delete rather than a recursive remove: the same cleanup works from a
# session whose own guardrail blocks the recursive-force form.
trap 'find "$WORK" -delete' EXIT

# Repo on main with one commit.
MAIN_REPO="$WORK/main-repo"
mkdir "$MAIN_REPO"
git -C "$MAIN_REPO" init -q
git -C "$MAIN_REPO" symbolic-ref HEAD refs/heads/main
git -C "$MAIN_REPO" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init

# Repo on a feature branch.
FEATURE_REPO="$WORK/feature-repo"
mkdir "$FEATURE_REPO"
git -C "$FEATURE_REPO" init -q
git -C "$FEATURE_REPO" symbolic-ref HEAD refs/heads/feature

# Repo whose main branch has no commits yet.
UNBORN_REPO="$WORK/unborn-repo"
mkdir "$UNBORN_REPO"
git -C "$UNBORN_REPO" init -q
git -C "$UNBORN_REPO" symbolic-ref HEAD refs/heads/main

# A folder that is not a repository.
PLAIN_DIR="$WORK/plain"
mkdir "$PLAIN_DIR"

# Stub gh. Answers `gh pr view ... --json number,state,statusCheckRollup` the
# way the real CLI does: one JSON object with a statusCheckRollup array whose
# entries are CheckRun (status, conclusion) or StatusContext (state) records.
# STUB_MODE picks the answer.
STUB_DIR="$WORK/bin"
mkdir "$STUB_DIR"
cat > "$STUB_DIR/gh" <<'STUB'
#!/usr/bin/env bash
case "${STUB_MODE:-}" in
  success)
    echo '{"number":1,"state":"OPEN","statusCheckRollup":[{"__typename":"CheckRun","name":"build","status":"COMPLETED","conclusion":"SUCCESS"},{"__typename":"StatusContext","context":"ci/other","state":"SUCCESS"}]}' ;;
  failure)
    echo '{"number":1,"state":"OPEN","statusCheckRollup":[{"__typename":"CheckRun","name":"build","status":"COMPLETED","conclusion":"SUCCESS"},{"__typename":"CheckRun","name":"test","status":"COMPLETED","conclusion":"FAILURE"}]}' ;;
  empty)
    echo '{"number":1,"state":"OPEN","statusCheckRollup":[]}' ;;
  *)
    echo "gh: simulated failure" >&2
    exit 1 ;;
esac
STUB
chmod +x "$STUB_DIR/gh"

pass=0; fail=0
STDERR_FILE="$WORK/stderr.txt"

# check <expected-exit> <cwd> <stub-mode> <description> <command>
check() {
  local want="$1" cwd="$2" mode="$3" desc="$4" cmd="$5" got
  CMD="$cmd" node -e 'process.stdout.write(JSON.stringify({tool_input:{command:process.env.CMD}}))' \
    | (cd "$cwd" && PATH="$STUB_DIR:$PATH" STUB_MODE="$mode" node "$HOOK" >/dev/null 2>"$STDERR_FILE")
  got=$?
  if [ "$got" = "$want" ]; then
    pass=$((pass+1)); printf '  ok    %-62s (exit %s)\n' "$desc" "$got"
  else
    fail=$((fail+1)); printf '  FAIL  %-62s want %s got %s\n' "$desc" "$want" "$got"
  fi
}

# stderr_has <description> <text>: the last check's stderr must mention text.
stderr_has() {
  if grep -qF -- "$2" "$STDERR_FILE"; then
    pass=$((pass+1)); printf '  ok    %s\n' "$1"
  else
    fail=$((fail+1)); printf '  FAIL  %s (stderr lacked: %s)\n' "$1" "$2"
  fi
}

echo "=== commit guard ==="
check 2 "$MAIN_REPO"    ""  "commit on main"                                   'git commit -m x'
check 0 "$MAIN_REPO"    ""  "checkout -b feature, then commit, on main"        'git checkout -b feature && git commit -m x'
check 0 "$FEATURE_REPO" ""  "commit on a feature branch"                       'git commit -m x'
check 0 "$PLAIN_DIR"    ""  "commit in a folder that is not a repo (fail open)" 'git commit -m x'
check 2 "$UNBORN_REPO"  ""  "commit in a repo with no commits on main"         'git commit -m x'
check 2 "$FEATURE_REPO" ""  "checkout main, then commit, from a feature branch" 'git checkout main && git commit -m x'

echo "=== merge guard ==="
check 0 "$FEATURE_REPO" success "merge with every check passing"               'gh pr merge 1'
check 2 "$FEATURE_REPO" failure "merge with one check failing"                 'gh pr merge 1'
check 2 "$FEATURE_REPO" empty   "merge with no checks reported"                'gh pr merge 1'
stderr_has "empty-rollup refusal points at templates/ci.yml" "templates/ci.yml"
check 2 "$FEATURE_REPO" ""      "merge when gh itself fails"                   'gh pr merge 1'
stderr_has "gh failure is named in the refusal" "gh failed"
check 0 "$FEATURE_REPO" empty   "prose that mentions a merge is not a merge"   'echo "then gh pr merge 1 once green"'

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
