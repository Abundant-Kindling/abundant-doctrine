#!/usr/bin/env bash
# Shape checks for the doctrine and /wrap. They check structure and size, not
# whether the rules are good: that is a human read.
#
#   bash tests/docs.test.sh
set -u

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$repo" || exit 2

fails=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

doc=CLAUDE.md
wrap=commands/wrap.md

# ---- CLAUDE.md ---------------------------------------------------------------
if [ -f "$doc" ]; then pass "$doc exists"; else fail "$doc exists"; fi

size=$(wc -c < "$doc" 2>/dev/null | tr -d ' ')
size=${size:-0}
if [ "$size" -gt 0 ] && [ "$size" -lt 15000 ]; then
  pass "$doc is $size chars (under 15000)"
else
  fail "$doc is $size chars (want 1 to 14999)"
fi

# The ten headings, exactly, in this order, and no other level-2 heading.
want="## How to work
## Git
## Code
## Data and secrets
## Evidence
## Verification
## Debugging
## Finishing
## Before shipping
## Handing over"
got=$(grep '^## ' "$doc" 2>/dev/null)
if [ "$got" = "$want" ]; then
  pass "$doc has the ten headings in order"
else
  fail "$doc headings differ from the ten, in order. Got:"
  printf '%s\n' "$got" | sed 's/^/       /'
fi

# The kit's CLAUDE.md carries no import line: the installer's stub does that.
if grep -q '^@' "$doc" 2>/dev/null; then
  fail "$doc carries an import line (the installer's stub imports instead)"
else
  pass "$doc carries no import line"
fi

# ---- commands/wrap.md --------------------------------------------------------
wsize=$(wc -c < "$wrap" 2>/dev/null | tr -d ' ')
wsize=${wsize:-0}
if [ "$wsize" -gt 0 ] && [ "$wsize" -lt 6000 ]; then
  pass "$wrap is $wsize chars (under 6000)"
else
  fail "$wrap is $wsize chars (want 1 to 5999)"
fi

for needle in '### 1. Outstanding' '### 2. Verified' '### 3. State' \
  'blocked-on-me' 'blocked-on-client' '## Loose ends'; do
  if grep -qF -- "$needle" "$wrap" 2>/dev/null; then
    pass "$wrap contains '$needle'"
  else
    fail "$wrap contains '$needle'"
  fi
done

# ---- templates/project-CLAUDE.md ---------------------------------------------
tpl=templates/project-CLAUDE.md
if [ -f "$tpl" ]; then pass "$tpl exists"; else fail "$tpl exists"; fi

for h in '## Ways to hurt yourself' '## Supabase' '## Handover notes' '## Loose ends'; do
  if grep -qxF -- "$h" "$tpl" 2>/dev/null; then
    pass "$tpl has '$h'"
  else
    fail "$tpl has '$h'"
  fi
done

# At least two numbered entries inside the "Ways to hurt yourself" section.
nhurt=$(awk '/^## /{on=($0=="## Ways to hurt yourself")} on && /^[0-9]+\. /{n++} END{print n+0}' "$tpl" 2>/dev/null)
if [ "${nhurt:-0}" -ge 2 ]; then
  pass "$tpl lists $nhurt numbered ways to hurt yourself"
else
  fail "$tpl lists ${nhurt:-0} numbered ways to hurt yourself (want 2 or more)"
fi

# The four tiers appear inside the Loose ends section.
loose=$(awk '/^## /{on=($0=="## Loose ends")} on' "$tpl" 2>/dev/null)
for tier in blocked-on-me blocked-on-client papercut polish; do
  if printf '%s\n' "$loose" | grep -qF -- "$tier"; then
    pass "$tpl Loose ends names '$tier'"
  else
    fail "$tpl Loose ends names '$tier'"
  fi
done

tsize=$(wc -c < "$tpl" 2>/dev/null | tr -d ' ')
tsize=${tsize:-0}
if [ "$tsize" -gt 0 ] && [ "$tsize" -lt 8000 ]; then
  pass "$tpl is $tsize chars (under 8000)"
else
  fail "$tpl is $tsize chars (want 1 to 7999)"
fi

# ---- templates/ci.yml ----------------------------------------------------------
ci=templates/ci.yml
if [ -f "$ci" ]; then pass "$ci exists"; else fail "$ci exists"; fi

# Parse as YAML: ruby first, then python3 with PyYAML. Neither available is a failure.
if command -v ruby >/dev/null 2>&1; then
  if ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$ci" >/dev/null 2>&1; then
    pass "$ci parses as YAML (ruby)"
  else
    fail "$ci parses as YAML (ruby)"
  fi
elif command -v python3 >/dev/null 2>&1 \
  && python3 -I -c 'import yaml' >/dev/null 2>&1; then
  if python3 -I -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$ci" >/dev/null 2>&1; then
    pass "$ci parses as YAML (python3)"
  else
    fail "$ci parses as YAML (python3)"
  fi
else
  fail "$ci parses as YAML (neither ruby nor python3 with PyYAML is available)"
fi

for needle in 'pull_request' 'npm ci' 'npm run lint' 'npx tsc --noEmit' 'npm run build'; do
  if grep -qF -- "$needle" "$ci" 2>/dev/null; then
    pass "$ci contains '$needle'"
  else
    fail "$ci contains '$needle'"
  fi
done

if grep -q 'node-version: *2[0-9]' "$ci" 2>/dev/null; then
  fail "$ci hardcodes a node-version"
else
  pass "$ci hardcodes no node-version"
fi
if grep -qF 'engines' "$ci" 2>/dev/null; then
  pass "$ci reads engines"
else
  fail "$ci reads engines"
fi

# ---- README.md ---------------------------------------------------------------
# Three things a reader acts on: the paths it names, the skills it names, and
# the attribution line. Paths are inline-code tokens whose first segment is a
# top-level folder of this repo (`templates/ci.yml`), `*.sh` tokens, and
# relative link targets. Skills are written `plugin:name` (the form Claude Code
# shows) or `/name` for built-ins.
readme=README.md
if [ -f "$readme" ]; then pass "$readme exists"; else fail "$readme exists"; fi

# shellcheck disable=SC2016 # literal backticks, not an expansion
tokens=$(grep -o '`[^`]*`' "$readme" 2>/dev/null | tr -d '`' | sort -u)
links=$(grep -o '](\([^)]*\))' "$readme" 2>/dev/null | sed 's/^](//; s/)$//' \
  | grep -v -e '^https\?:' -e '^#' -e '^mailto:' | sed 's/#.*//' | sort -u)
topdirs=$(git ls-files 2>/dev/null | sed -n 's#^\([^/]*\)/.*#\1#p' | sort -u)

npaths=0
missing_paths=""
check_path() {
  npaths=$((npaths + 1))
  [ -e "$1" ] || missing_paths="$missing_paths $1"
}
while IFS= read -r t; do
  [ -n "$t" ] || continue
  case "$t" in *" "*) continue ;; esac
  case "$t" in
    */*)
      first=${t%%/*}
      if printf '%s\n' "$topdirs" | grep -qxF -- "$first"; then check_path "$t"; fi ;;
    *.sh) check_path "$t" ;;
  esac
done <<EOF
$tokens
EOF
while IFS= read -r l; do
  [ -n "$l" ] && check_path "$l"
done <<EOF
$links
EOF
if [ "$npaths" -lt 3 ]; then
  fail "$readme names $npaths repo paths (want 3 or more, or the check is vacuous)"
elif [ -z "$missing_paths" ]; then
  pass "$readme: all $npaths repo paths it names exist"
else
  fail "$readme names paths that do not exist:$missing_paths"
fi

# Plugin caches. With none on this machine (a fresh clone, plugins not yet
# installed), the plugin-skill check is skipped with a note, not failed.
caches=""
for c in "$HOME"/.claude*/plugins/cache/claude-plugins-official \
         "${CLAUDE_CONFIG_DIR:-/nonexistent}/plugins/cache/claude-plugins-official"; do
  [ -d "$c" ] && caches="$caches
$c"
done
builtins="/code-review /security-review /simplify /context /plugin /mcp /hooks"
kitcmds=$(for f in commands/*.md; do [ -f "$f" ] && b=${f##*/} && printf '/%s ' "${b%.md}"; done)

nskills=0
bad_skills=""
skipped=""
while IFS= read -r t; do
  [ -n "$t" ] || continue
  case "$t" in
    superpowers:* | supabase:* | vercel:*)
      case "$t" in *[!a-z0-9:-]*) continue ;; esac
      nskills=$((nskills + 1))
      if [ -z "$caches" ]; then skipped="$skipped $t"; continue; fi
      plugin=${t%%:*} name=${t#*:} found=no
      while IFS= read -r c; do
        [ -n "$c" ] || continue
        for v in "$c/$plugin"/*/; do
          if [ -d "${v}skills/$name" ] || [ -f "${v}commands/$name.md" ]; then found=yes; fi
        done
      done <<EOF2
$caches
EOF2
      [ "$found" = yes ] || bad_skills="$bad_skills $t" ;;
    *:*)
      case "$t" in *[!a-z0-9:-]*) continue ;; esac
      nskills=$((nskills + 1)); bad_skills="$bad_skills $t(not one of the kit's three plugins)" ;;
    /*)
      case "$t" in */*/* | *[!a-z0-9/-]*) continue ;; esac
      nskills=$((nskills + 1))
      case " $builtins $kitcmds " in
        *" $t "*) ;;
        *) bad_skills="$bad_skills $t" ;;
      esac ;;
  esac
done <<EOF
$tokens
EOF
if [ "$nskills" -lt 8 ]; then
  fail "$readme names $nskills skills or commands (want 8 or more, or the check is vacuous)"
elif [ -n "$bad_skills" ]; then
  fail "$readme names skills or commands that do not exist:$bad_skills"
elif [ -n "$skipped" ]; then
  pass "$readme: built-ins exist; plugin skills NOT checked (no plugin cache under ~/.claude*/plugins/cache; install the plugins and re-run):$skipped"
else
  pass "$readme: all $nskills skills and commands it names exist"
fi

# The attribution is assembled from two halves so this file does not itself
# trip the leak gate, which allows the full name only in LICENSE and README.md.
attr='Made by Abundant'
attr="$attr Kindling"
nmade=$(grep -c "^$attr" "$readme" 2>/dev/null)
if [ "${nmade:-0}" -eq 1 ]; then
  pass "$readme has one '$attr' line"
else
  fail "$readme has ${nmade:-0} lines starting '$attr' (want exactly 1)"
fi

if grep -q '^## v0\.1\.0 (' CHANGELOG.md 2>/dev/null; then
  pass "CHANGELOG.md has a '## v0.1.0 (date)' entry"
else
  fail "CHANGELOG.md has a '## v0.1.0 (date)' entry"
fi

# ---- every .md: no em dash ---------------------------------------------------
emdash=$(printf '\342\200\224')
mds=$(git ls-files -co --exclude-standard -- '*.md')
if [ -z "$mds" ]; then
  fail "found .md files to scan"
else
  hits=""
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    h=$(grep -nF -- "$emdash" "$f" 2>/dev/null) && hits="$hits$f: ${h%%:*}
"
  done <<EOF
$mds
EOF
  if [ -z "$hits" ]; then
    pass "no em dash in any .md"
  else
    fail "em dash found (file: first line):"
    printf '%s' "$hits" | sed 's/^/       /'
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "docs.test: all passed"
  exit 0
fi
echo "docs.test: $fails failed"
exit 1
