#!/usr/bin/env node
// careful.js: pre-tool-use guardrail for Bash commands.
// Reads {tool_name?, tool_input} as JSON on stdin. Exit 2 (reason on stderr)
// blocks the tool call; exit 0 lets it through. Bad input fails open.

const stdin = require('fs').readFileSync(0, 'utf-8');

let input;
try { input = JSON.parse(stdin); }
catch { process.exit(0); }   // unparseable input: fail open, never block work

const command = (input?.tool_input?.command || '').trim();

// Destructive SQL, kept apart from DANGEROUS so the same table can vet SQL
// arriving by other routes than a shell command. Each entry is [pattern, reason].
// Case-insensitive, and \s matches newlines, so a statement split across lines
// is still caught.
//
// A table name (SQL_NAME) is a run of word characters, dots and double-quoted
// parts, so `public.clients` and `"clients"` match as one name. After the name,
// DELETE and TRUNCATE need something that ends the statement: a semicolon, the
// end of the text, a closing shell quote, or a clause that is not a WHERE. That
// keeps `DELETE FROM "clients" WHERE ...` allowed and English such as
// "truncate the intro" out of it, while a two-word phrase ending in a closing
// quote ("delete from cart") errs toward asking.
const SQL_NAME = /(?:[\w.]|"[\w.]*")+/.source;
const SQL_PATTERNS = [
  [/\bDROP\s+(TABLE|DATABASE|SCHEMA)\b/i,                            'SQL DROP statement'],
  [new RegExp(String.raw`\bTRUNCATE\s+(TABLE\b|ONLY\b|${SQL_NAME}\s*(;|$|,|["'](?![\w.])|(CASCADE|RESTRICT|RESTART|CONTINUE)\b))`, 'i'),
                                                                     'SQL TRUNCATE statement'],
  [new RegExp(String.raw`\bDELETE\s+FROM\s+(ONLY\s+)?${SQL_NAME}\s*(;|$|["'](?![\w.])|RETURNING\b)`, 'i'),
                                                                     'DELETE without WHERE clause'],
  // DROP with or without the COLUMN keyword; ALTER COLUMN ... DROP DEFAULT,
  // NOT NULL, IDENTITY or EXPRESSION, and DROP CONSTRAINT, lose no data.
  [/\bALTER\s+TABLE\b[^;]*?\bDROP\s+(COLUMN\b|(?!(CONSTRAINT|DEFAULT|NOT|IDENTITY|EXPRESSION)\b)["\w])/i,
                                                                     'ALTER TABLE ... DROP COLUMN'],
  [/supabase\s+db\s+reset/i,                                         'Supabase database reset'],
];

// SQL sent through the Supabase MCP tools carries the statement in
// tool_input.query. Whitespace is collapsed first so a statement split across
// lines, or ending in a newline, matches the same patterns as the Bash path.
const toolName = String(input?.tool_name || '');
if (/supabase.*__(execute_sql|apply_migration)$/i.test(toolName)) {
  const query = String(input?.tool_input?.query || '').replace(/\s+/g, ' ').trim();
  for (const [pattern, reason] of SQL_PATTERNS) {
    if (pattern.test(query)) {
      process.stderr.write(
        `Guardrail: ${reason} via ${toolName}\n` +
        `Query:     ${query}\n` +
        `Use a safer alternative (add a WHERE clause, or run it on a branch), or confirm with the user.\n`
      );
      process.exit(2);
    }
  }
  process.exit(0);   // SQL tool, nothing destructive: the Bash checks do not apply
}

const DANGEROUS = [
  // Filesystem destruction
  [{ test: rmRecursiveForce },                                      'Recursive force-delete (rm -rf)'],
  [/Remove-Item.*(-Recurse.*-Force|-Force.*-Recurse)/i,              'PowerShell recursive force-delete'],

  // Git destruction
  // Fires on a bare force flag anywhere in a push command, in any order.
  // The lease exclusion is scoped to the flag itself, not the whole command,
  // so a compound line carrying both forms still blocks on the bare one.
  // The lookahead is bounded by a separator class rather than `.*` so it cannot
  // reach past the end of the push into a neighbouring command: a plain push
  // followed by a file delete is not a force-push.
  [/git\s+push\b(?=[^;&|\n]*(--force(?!-with-lease)\b|\s-f\b))/,      'Git force-push without lease'],
  [/git\s+reset\s+--hard\s+(origin|upstream)\//,                     'Git hard-reset to remote ref'],
  [/git\s+clean\b[^;&|\n]*(\s-[a-zA-Z]*[fd]|\s--force\b)/,          'Git clean with force/directories'],
  [{ test: (c) => gitPush(c) === 'force' },                         'Git force-push (a refspec starting with +)'],
  [{ test: (c) => gitPush(c) === 'deploy' },                        'Push to a deploy branch (main or master); push a feature branch and open a PR instead'],

  // Publish / production deploy
  [/\bnpm\s+publish\b/,                                              'npm publish'],
  [{ test: vercelProd },                                            'Vercel production deploy'],
  [/\bsupabase\s+db\s+push\b/,                                       'Supabase db push (applies migrations to the linked, usually production, database)'],
];

// An rm, anywhere in one segment of the command (between ; & | or newlines),
// carrying both a recursive flag and a force flag, in any form or order:
// -rf, -fr, -Rf, -r -f, --recursive --force, or the flags after the path.
// Quoted text is not masked, so a commit message quoting the command also asks.
function rmRecursiveForce(cmd) {
  for (const seg of cmd.split(/[;&|\n]+/)) {
    const m = seg.match(/\brm\s+(.*)/);
    if (!m) continue;
    const toks = m[1].split(/\s+/);
    const recursive = toks.some((t) => /^-[a-zA-Z]*[rR]/.test(t) || t === '--recursive');
    const force = toks.some((t) => /^-[a-zA-Z]*f/.test(t) || t === '--force');
    if (recursive && force) return true;
  }
  return false;
}

// Classifies each `git push` in the command: 'force' when a refspec starts
// with + (a force-push the flag check above cannot see), 'deploy' when a
// refspec's destination is main or master (`main`, `feature:main`,
// `HEAD:refs/heads/main`, `--delete main`), or when --all or --mirror pushes
// every branch. Read per segment of the quote-masked command, so a quoted
// mention is ignored. A bare `git push` (no refspec) pushes the current branch,
// which this cannot see; commits on main are refused by the commit guard.
const PUSH_VALUE_FLAGS = new Set(['-o', '--push-option', '--repo', '--receive-pack', '--exec']);
function gitPush(cmd) {
  const masked = maskQuoted(cmd);
  let verdict = null;
  const re = /[^;&|\n]+/g;
  let s;
  while ((s = re.exec(masked)) !== null) {
    const m = s[0].match(/\bgit\b[^;&|\n]*?\spush\b(.*)/);
    if (!m) continue;
    // Arguments read from the original command; masking keeps positions.
    const start = s.index + m.index + m[0].length - m[1].length;
    const toks = cmd.substr(start, m[1].length).trim().split(/\s+/).filter(Boolean);
    const positional = [];
    for (let i = 0; i < toks.length; i++) {
      const t = toks[i];
      if (t === '--all' || t === '--mirror') { verdict = verdict || 'deploy'; continue; }
      if (PUSH_VALUE_FLAGS.has(t)) { i++; continue; }
      if (t.startsWith('-')) continue;
      positional.push(t);
    }
    for (const ref of positional.slice(1)) {        // the first is the remote
      if (ref.startsWith('+')) return 'force';
      const dst = ref.includes(':') ? ref.slice(ref.lastIndexOf(':') + 1) : ref;
      if (/^(refs\/heads\/)?(main|master)$/.test(dst)) verdict = 'deploy';
    }
  }
  return verdict;
}

// A vercel invocation carrying --prod, unless its subcommand is read-only.
// An allowlist, not a deploy list: the CLI's default command is deploy, so a
// bare `vercel --prod` ships, and any subcommand not named here still blocks.
// promote and rollback change production with no flag at all, so they block
// outright, status forms included: erring toward asking.
// Checked per segment of the quote-masked command, so a quoted mention is
// ignored and `vercel ls --prod && vercel --prod` blocks on its second half.
// A heredoc body is not quoted text and still blocks: accepted, it errs
// toward asking.
const VERCEL_READ_ONLY = new Set(['ls', 'list', 'inspect', 'logs']);
const VERCEL_PROD_ALWAYS = new Set(['promote', 'rollback']);
function vercelProd(cmd) {
  for (const seg of maskQuoted(cmd).split(/[;&|\n]+/)) {
    const m = seg.match(/\bvercel\b(.*)/);
    if (!m) continue;
    const sub = m[1].trim().split(/\s+/).find((t) => t && !t.startsWith('-'));
    // Any bare word, not just the first: a flag value (--scope team) can sit
    // before the subcommand, and missing it here would fail open.
    if (m[1].split(/\s+/).some((t) => VERCEL_PROD_ALWAYS.has(t))) return true;
    if (!/(?:^|\s)--prod/.test(m[1])) continue;
    if (!VERCEL_READ_ONLY.has(sub)) return true;
  }
  return false;
}

for (const [pattern, reason] of [...DANGEROUS, ...SQL_PATTERNS]) {
  if (pattern.test(command)) {
    process.stderr.write(
      `Guardrail: ${reason}\n` +
      `Command:   ${command}\n` +
      `Use a safer alternative, or confirm with the user.\n`
    );
    process.exit(2);   // exit 2 makes Claude Code block the tool and show stderr
  }
}

// The directory a command will run in: the first `cd` argument, or the hook's
// own cwd when there is none. Shared by the commit and merge guards so the two
// cannot parse it differently. Reads a double- or single-quoted argument and
// backslash-escaped spaces, so a path containing a space is not cut at the
// first space (which would leave a missing cwd and a misleading spawn error).
function cdDir(cmd) {
  // Find the cd on the masked command, so `echo "cd /x"` is not read as a cd,
  // then parse its argument from the original, where the quoted path is
  // intact. maskQuoted keeps positions, so the index carries over.
  const at = maskQuoted(cmd).search(/\bcd\s/);
  if (at === -1) return process.cwd();
  const m = cmd.slice(at).match(/^cd\s+(?:"((?:[^"\\]|\\.)*)"|'([^']*)'|((?:[^\s;&|\\]|\\.)+))/);
  if (!m) return process.cwd();
  const dir = m[1] !== undefined ? m[1].replace(/\\(.)/g, '$1')
            : m[2] !== undefined ? m[2]
            : m[3].replace(/\\(.)/g, '$1');
  return dir.replace(/^~(?=\/|$)/, require('os').homedir());
}

// The command with every quoted span's contents replaced by underscores, same
// length, so a match position found here indexes the original string. Lets a
// command-position test ignore separators and subcommands inside quoted text:
// a grep pattern naming the merge subcommand, or an inline script with it on
// its own line, is not a real merge. Unbalanced quotes (an apostrophe in a
// heredoc body) return the command unmasked, so the failure is toward
// checking, never toward skipping.
function maskQuoted(cmd) {
  let out = '', quote = null;
  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i];
    if (quote === null) {
      if (c === '\\' && i + 1 < cmd.length) { out += c + cmd[++i]; continue; }
      if (c === '"' || c === "'") quote = c;
      out += c;
    } else if (c === quote) {
      quote = null; out += c;
    } else if (quote === '"' && c === '\\' && i + 1 < cmd.length) {
      out += '__'; i++;
    } else {
      out += '_';
    }
  }
  return quote === null ? out : cmd;
}

// No direct commits onto a deploy branch. Feature-branch-and-PR is the workflow:
// main and master are deploy branches.
// Fails OPEN on any error (not a repo, detached HEAD, git missing): a hook
// glitch must never block a legitimate commit.
// The `git commit` match requires a command position (start of string, or
// after ; & | or a newline), so a commit message that mentions "git commit"
// does not trip it, while a real commit on the third line of a block does.
//
// Between `git` and `commit` any run of non-separator characters is allowed,
// because global flags legitimately sit there: `git -c user.name="A B" commit`
// is the form used whenever identity is set inline.
//
// The branch is evaluated AS OF THE COMMIT, not as of the hook: the last
// branch-changing `git checkout` / `git switch` that precedes the commit in the
// same command wins, and only if there is none does the live branch count.
// `git checkout -b x && git commit` passes although the live branch is still
// main when the hook runs; `git checkout main && git commit` on a feature
// branch blocks for the mirror reason. `checkout -- <path>` is a file restore,
// not a branch change, and is ignored.
//
// The live branch is read with `git symbolic-ref --short HEAD`, which answers
// on an unborn branch (a repo with no commits yet), so a first commit onto
// main is blocked like any other. Outside a git repo it errors, and the guard
// fails open.
//
// All widenings err toward blocking. `git log --grep commit` will trip this
// and ask: a stopped read is cheap; an unguarded commit onto a deploy branch
// is not. Behaviour is pinned by hooks/careful.git.test.sh; run it after any edit.
const commitAt = command.search(/(?:^|[;&|\n])\s*git\b[^;&|\n]*?\bcommit\b/);
if (commitAt !== -1) {
  let branch = null;
  const switchRe = /(?:^|[;&|\n])\s*git\b[^;&|\n]*?\b(?:checkout|switch)\b([^;&|\n]*)/g;
  let m;
  while ((m = switchRe.exec(command)) !== null && m.index < commitAt) {
    let target = null, takeNext = false;
    for (const tok of m[1].trim().split(/\s+/).filter(Boolean)) {
      if (tok === '--') break;                       // paths follow; not a branch change
      if (takeNext) { target = tok; break; }
      if (/^-[bBcC]$/.test(tok)) { takeNext = true; continue; }   // -b/-B/-c/-C <name>
      if (tok.startsWith('-')) continue;             // -q, --track, ...: skip the flag
      target = tok; break;                           // first bare word is the branch
    }
    if (target) branch = target;
  }
  try {
    const { execSync } = require('child_process');
    const cwd = cdDir(command);
    const run = (c) => execSync(c, { cwd, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    if (branch === null) branch = run('git symbolic-ref --short HEAD');
    if (branch === 'main' || branch === 'master') {
      process.stderr.write(
        `Guardrail: Commit onto deploy branch '${branch}'\n` +
        `Command:   ${command}\n` +
        `Feature-branch-and-PR is the workflow: create a branch first (git checkout -b <name>), or confirm with the user.\n`
      );
      process.exit(2);
    }
  } catch { /* fail open: never block a commit on a hook error */ }
}

// No merging a PR whose checks have not all passed. On many plans nothing
// makes CI required (branch protection is unavailable on private repos), so
// the merge button and `gh pr merge` work on a red or pending PR. This guard
// is the mechanism that asks.
//
// Fails CLOSED, unlike the commit guard above: the whole point is a check
// that can be red, so "gh could not answer" is a refusal with that reason,
// not a pass. An empty rollup is refused too, because a PR pushed seconds ago
// has no checks yet and that is exactly the race that merges on a pending check.
// Command position only (start, or after ; & | newline), same as the commit
// guard, so a commit message that mentions the subcommand does not trip it.
// Quoted text is masked first (maskQuoted), so a grep pattern or an inline
// script that mentions the subcommand is not a merge; the arguments are then
// read from the original command at the same position.
// Pinned by hooks/careful.git.test.sh.
const mergeRe = /(?:^|[;&|\n])\s*gh\s+pr\s+merge\b([^;&|\n]*)/;
const maskedMerge = maskQuoted(command).match(mergeRe);
const mergeMatch = maskedMerge
  ? [maskedMerge[0], command.substr(maskedMerge.index + maskedMerge[0].length - maskedMerge[1].length, maskedMerge[1].length)]
  : null;
if (mergeMatch) {
  const refuse = (why) => {
    process.stderr.write(
      `Guardrail: PR merge without every check passed\n` +
      `Command:   ${command}\n` +
      `${why}\n` +
      `Wait for the checks (gh pr checks <n> --watch), fix what is red, or confirm with the user.\n`
    );
    process.exit(2);
  };
  // First bare argument after `merge` is the selector: a number, a URL, or a
  // branch. None means the current branch, which gh resolves from cwd.
  // -R/--repo is read wherever it sits and passed on, or the lookup would
  // check the same-numbered PR in cwd's repo.
  let selector = null;
  let repo = null;
  const toks = mergeMatch[1].trim().split(/\s+/).filter(Boolean);
  for (let i = 0; i < toks.length; i++) {
    const t = toks[i];
    if (t.startsWith('--repo=')) { repo = t.slice('--repo='.length); continue; }
    if (t === '-R' || t === '--repo') { repo = toks[i + 1] ?? null; i++; continue; }
    if (t.startsWith('-')) {                       // flags that take a value consume the next token
      if (/^(-m|-b|-t|-A|--body|--subject|--author-email|--match-head-commit|--body-file|-F)$/.test(t) && !t.includes('=')) i++;
      continue;
    }
    if (selector === null) selector = t;
  }
  try {
    const { execFileSync } = require('child_process');
    const cwd = cdDir(command);
    const args = ['pr', 'view', ...(selector ? [selector] : []), ...(repo ? ['-R', repo] : []), '--json', 'number,state,statusCheckRollup'];
    const out = execFileSync('gh', args, { cwd, stdio: ['ignore', 'pipe', 'pipe'] }).toString();
    const pr = JSON.parse(out);
    const rollup = Array.isArray(pr.statusCheckRollup) ? pr.statusCheckRollup : [];
    // No checks at all is refused even when the repo has no CI: install CI
    // first, then merge.
    if (rollup.length === 0) refuse(`PR #${pr.number}: no checks reported yet. If this repo has no CI at all, add CI first: copy ${require('path').join(__dirname, '..', 'templates', 'ci.yml')} into .github/workflows/.`);
    const notPassed = rollup.filter((c) => {
      if (c.__typename === 'StatusContext') return c.state !== 'SUCCESS';
      return c.status !== 'COMPLETED' || !['SUCCESS', 'NEUTRAL', 'SKIPPED'].includes(c.conclusion);
    });
    if (notPassed.length > 0) {
      const lines = notPassed.map((c) => `  ${c.name || c.context}: ${c.__typename === 'StatusContext' ? c.state : `${c.status}/${c.conclusion || 'none'}`}`);
      refuse(`PR #${pr.number}: ${notPassed.length} of ${rollup.length} checks not passed:\n${lines.join('\n')}`);
    }
  } catch (err) {
    if (err && err.status === 2) throw err;         // our own refuse() already wrote and exited
    const msg = (err && err.stderr && err.stderr.toString().trim()) || (err && err.message) || String(err);
    refuse(`Could not read the PR's checks (gh failed): ${msg.split('\n')[0]}`);
  }
}

process.exit(0);   // safe: let it through
