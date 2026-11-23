#!/usr/bin/env bash
# Fails when a term from a private terms file appears in any tracked or
# untracked-but-not-ignored file, or in any commit's author, committer or
# message. Run from anywhere; it works on the repo that contains this script.
#
#   LEAK_TERMS=/path/to/terms.txt bash scripts/leak-check.sh   scan the repo
#   bash scripts/leak-check.sh --scan /path/to/terms.txt         the same
#   bash scripts/leak-check.sh --self-test   prove the scan can fail, then pass
#
# The terms file is private: one term per line, matched case-insensitively. It
# is not shipped with the kit, because the terms themselves would leak. Keep it
# outside the repo; supply it with LEAK_TERMS (which wins) or as the second
# argument. With neither, the scan refuses to run.
#
# LEAK_SKIP_HISTORY=1 skips only the commit-history scan, with a warning. Use it
# while history is known to carry a term and has not yet been rewritten; a pass
# with it set covers the files only.
#
# Exit 0: clean. Exit 1: hits, listed as file:line:term or
# history:commit:term. Exit 2: could not scan (no terms file, unreadable terms,
# not a git repo, no files). Fails closed.
set -u

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# The one term that is allowed in two places (the licence, and the README
# attribution line). Built from two pieces so this file does not contain it.
restricted_lc=$(printf '%s %s' "abundant" "kindling")

# scan ROOT TERMS_FILE
scan() {
  local root=$1 terms=$2 hits=0 file term line text term_lc files out grc top
  local terms_abs hist hash
  if [ ! -f "$terms" ] || [ ! -r "$terms" ] \
    || [ "$(grep -c '[^[:space:]]' "$terms" 2>/dev/null)" -lt 1 ]; then
    echo "leak-check: terms file missing, unreadable or has no terms: $terms" >&2
    return 2
  fi
  terms_abs="$(cd "$(dirname "$terms")" && pwd -P)/$(basename "$terms")"
  cd "$root" || return 2
  root=$(pwd -P)
  # The root itself must be a repo's top level, not a folder inside one.
  top=$(git rev-parse --show-toplevel 2>/dev/null) && top=$(cd "$top" && pwd -P)
  if [ -z "$top" ] || [ "$top" != "$root" ]; then
    echo "leak-check: not the top of a git repository: $root" >&2
    return 2
  fi
  files=$(git ls-files -co --exclude-standard) || return 2
  if [ -z "$files" ]; then
    echo "leak-check: no files to scan in $root" >&2
    return 2
  fi
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    # A terms file kept inside the tree would match itself.
    [ "$root/$file" = "$terms_abs" ] && continue
    while IFS= read -r term; do
      [ -n "$term" ] || continue
      term_lc=$(printf '%s' "$term" | tr '[:upper:]' '[:lower:]')
      out=$(grep -n -i -F -- "$term" "$file" 2>/dev/null)
      grc=$?
      if [ "$grc" -ge 2 ]; then
        echo "leak-check: could not read $file" >&2
        return 2
      fi
      [ -n "$out" ] || continue
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        if [ "$term_lc" = "$restricted_lc" ]; then
          [ "$file" = "LICENSE" ] && continue
          if [ "$file" = "README.md" ]; then
            text=${line#*:}
            case "$text" in "Made by"*) continue ;; esac
          fi
        fi
        printf '%s:%s:%s\n' "$file" "${line%%:*}" "$term"
        hits=$((hits + 1))
      done <<< "$out"
    done < "$terms"
  done <<EOF
$files
EOF

  # Commit history: author and committer names and emails, and every message,
  # on every ref. A term here ships with the first push even when no file
  # carries it. No exceptions apply: the licence allowance is for files.
  if [ "${LEAK_SKIP_HISTORY:-}" = 1 ]; then
    {
      echo "leak-check: WARNING: LEAK_SKIP_HISTORY=1. Commit authors, emails and messages were NOT scanned."
      echo "leak-check: WARNING: a pass now covers files only. History must be scanned before anything is published."
    } >&2
  else
    # Each line is prefixed with its commit, so a hit names where it is.
    hist=$(git log --all --format='@@%h%n@A%an%n@A%ae%n@A%cn%n@A%ce%n%B' 2>/dev/null) || {
      echo "leak-check: could not read commit history" >&2
      return 2
    }
    # The publisher identity may author commits: the attribution name and its
    # public mailbox, on author and committer lines only, never in messages.
    # Built from pieces so this file does not contain them.
    pub_email=$(printf 'hello@%s%s.com.au' "abundant" "kindling")
    hist=$(printf '%s\n' "$hist" | awk -v n="$restricted_lc" -v e="$pub_email" '
      /^@@/ { h = substr($0, 3); next }
      /^@A/ { v = tolower(substr($0, 3)); if (v == n || v == e) next; print h "\t" substr($0, 3); next }
      { print h "\t" $0 }')
    if [ -n "$hist" ]; then
      while IFS= read -r term; do
        [ -n "$term" ] || continue
        out=$(printf '%s\n' "$hist" | grep -i -F -- "$term" | cut -f1 | uniq)
        [ -n "$out" ] || continue
        while IFS= read -r hash; do
          [ -n "$hash" ] || continue
          printf 'history:%s:%s\n' "$hash" "$term"
          hits=$((hits + 1))
        done <<< "$out"
      done < "$terms"
    fi
  fi
  [ "$hits" -eq 0 ]
}

self_test() {
  local rc first src f planted terms out
  unset LEAK_SKIP_HISTORY
  base=$(mktemp -d) || return 2 # global on purpose: the EXIT trap reads it
  trap 'chmod -R u+rwx "$base" 2>/dev/null; find "$base" -delete 2>/dev/null' EXIT INT TERM
  d="$base/repo"
  mkdir "$d" || return 2
  src="$script_dir/.."
  # The self-test plants its own terms, outside the scanned tree, so it needs
  # no private terms file. Built from pieces so this script does not hit.
  planted=$(printf '%s%s' "zqx" "plantedterm")
  terms="$base/terms.txt"
  printf '%s\nzqx-%s\n' "$planted" "second" > "$terms"
  first=$planted

  # Copy only the files the scan would see, into a throwaway git repo.
  while IFS= read -r f; do
    [ -f "$src/$f" ] || continue
    if ! { mkdir -p "$d/$(dirname "$f")" && cp "$src/$f" "$d/$f"; }; then
      echo "self-test: copy of $f failed" >&2
      return 2
    fi
  done < <(git -C "$src" ls-files -co --exclude-standard)
  git -C "$d" init -q || return 2
  gitc() { git -C "$d" -c user.name=selftest -c user.email=selftest@example.com \
    -c commit.gpgsign=false "$@"; }
  { gitc add -A && gitc commit -q --no-verify -m "self-test copy"; } || {
    echo "self-test: could not commit the copy" >&2
    return 2
  }

  expect() { # expect WANT LABEL -- command...
    local want=$1 label=$2
    shift 3
    out=$( ( "$@" ) 2>&1 )
    rc=$?
    if [ "$rc" -ne "$want" ]; then
      echo "self-test FAILED: $label gave exit $rc, expected $want" >&2
      printf '%s\n' "$out" | sed 's/^/  /' >&2
      return 1
    fi
  }
  # shellcheck disable=SC2317 # called indirectly, through expect
  scan_skip_history() { LEAK_SKIP_HISTORY=1 scan "$@"; }

  expect 0 "clean copy" -- scan "$d" "$terms" || return 1

  printf 'planted %s here\n' "$first" > "$d/planted.txt"
  expect 1 "planted hit" -- scan "$d" "$terms" || return 1
  find "$d/planted.txt" -delete

  expect 2 "missing terms file" -- scan "$d" "$base/no-such-terms.txt" || return 1

  : > "$base/empty-terms.txt"
  expect 2 "empty terms file" -- scan "$d" "$base/empty-terms.txt" || return 1

  printf '\n\n  \n' > "$base/blank-terms.txt"
  expect 2 "blank-lines-only terms file" -- scan "$d" "$base/blank-terms.txt" || return 1

  # A terms file inside the tree is not reported against itself.
  cp "$terms" "$d/terms-inside.txt"
  expect 0 "terms file inside the tree" -- scan "$d" "$d/terms-inside.txt" || return 1
  find "$d/terms-inside.txt" -delete

  mkdir "$d/nested" && cp -R "$d/scripts" "$d/nested/scripts"
  expect 2 "folder inside another repo" -- scan "$d/nested" "$terms" || return 1
  find "$d/nested" -delete

  if [ "$(id -u)" -ne 0 ]; then
    cp "$terms" "$base/locked-terms.txt"
    chmod 000 "$base/locked-terms.txt"
    expect 2 "unreadable terms file" -- scan "$d" "$base/locked-terms.txt" || return 1
    find "$base/locked-terms.txt" -delete

    printf 'harmless\n' > "$d/locked.txt"
    chmod 000 "$d/locked.txt"
    expect 2 "unreadable file" -- scan "$d" "$terms" || return 1
    find "$d/locked.txt" -delete
  fi

  # History: a term in a commit message fails the scan though no file has it.
  gitc commit -q --no-verify --allow-empty -m "mentions $first in history" || return 2
  expect 1 "term in a commit message" -- scan "$d" "$terms" || return 1
  case "$out" in
    *"history:"*) ;;
    *) echo "self-test FAILED: history hit not reported as history:<commit>:<term>" >&2; return 1 ;;
  esac
  expect 0 "history skipped with LEAK_SKIP_HISTORY=1" -- scan_skip_history "$d" "$terms" || return 1
  case "$out" in
    *"WARNING: LEAK_SKIP_HISTORY=1"*) ;;
    *) echo "self-test FAILED: LEAK_SKIP_HISTORY=1 ran without its warning" >&2; return 1 ;;
  esac
  printf 'planted %s here\n' "$first" > "$d/planted.txt"
  expect 1 "file hit still caught with LEAK_SKIP_HISTORY=1" -- scan_skip_history "$d" "$terms" || return 1
  find "$d/planted.txt" -delete

  find "$d/.git" -delete
  expect 2 "not a git repo" -- scan "$d" "$terms" || return 1

  echo "self-test: planted file hit and commit-message hit caught (exit 1); clean tree passes (exit 0); LEAK_SKIP_HISTORY=1 warns and still catches file hits; missing/empty/blank/unreadable terms, nested folder, unreadable file and non-repo fail closed (exit 2)"
}

case "${1:-}" in
  --self-test)
    self_test
    exit $?
    ;;
  "" | --scan) ;;
  *)
    echo "leak-check: unknown argument: $1 (use --scan TERMS_FILE or --self-test)" >&2
    exit 2
    ;;
esac

terms_file=${LEAK_TERMS:-${2:-}}
if [ -z "$terms_file" ]; then
  echo "leak-check: no terms file. The terms file is private and is not shipped with the kit." >&2
  echo "leak-check: supply it with LEAK_TERMS=/path/to/terms.txt, or: bash scripts/leak-check.sh --scan /path/to/terms.txt" >&2
  exit 2
fi
scan "$script_dir/.." "$terms_file"
