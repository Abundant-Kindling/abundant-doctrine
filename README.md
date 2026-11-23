# Abundant Doctrine

> **Work in progress.** v0.1.0 is under test and the rules may change. Issues welcome; don't build on it yet.

A starter kit for Claude Code, for building internal apps (dashboards, project tools, case and volunteer trackers) for for-purpose and not-for-profit organisations on Next.js, Supabase and Vercel.

It gives you three things: a short set of working rules Claude reads at the start of every session, a guardrail that stops the moves you cannot take back, and `/wrap`, a command that closes a session with an honest report of what is finished and what is not.

## 1. What this is

- **The doctrine** ([CLAUDE.md](CLAUDE.md)): how to plan, branch, verify, handle client data, and hand an app over. About 15,000 characters, so Claude actually follows it. Read it once yourself; it is the contract.
- **The guardrail** ([hooks/careful.js](hooks/careful.js)): runs before every shell command and every Supabase SQL call, and refuses the destructive ones. Section 7 says exactly what it catches and what it misses.
- **`/wrap`** ([commands/wrap.md](commands/wrap.md)), two templates for each new app ([templates/project-CLAUDE.md](templates/project-CLAUDE.md) and [templates/ci.yml](templates/ci.yml)), and three plugins: superpowers, supabase and vercel.

It is built for macOS. Linux works too. Windows is not supported.

## 2. Install

You need `claude`, `git`, `node`, `jq` and a logged-in `gh`. The installer checks and tells you what is missing; on a Mac:

```bash
brew install --cask claude-code
brew install git node jq gh
gh auth login
```

Then clone the kit anywhere you like (a path with spaces is fine) and run the installer:

```bash
git clone <this repo's URL> abundant-doctrine
cd abundant-doctrine
bash install.sh
```

**What it writes**, all inside your Claude config folder (`~/.claude`, called `<config>` below):

- `<config>/abundant-doctrine`: a link to the folder you cloned.
- `<config>/CLAUDE.md`: a three-line generated file that imports the kit's doctrine and your `personal.md`. Do not edit it; the installer owns it.
- `<config>/personal.md`: your own rules. The kit never changes this file. If you already had a `CLAUDE.md`, its content moves in here, so nothing you relied on stops loading.
- `<config>/commands/wrap.md`: a link to `/wrap`.
- `<config>/settings.json`: the guardrail hooks and the three plugins are merged in. Your own settings and hooks stay as they were.

It then installs the plugins with `claude plugin install` and runs the guardrail's tests. The supabase and vercel plugins ask you to log in through the browser the first time Claude uses them.

**Leave the clone where it is.** `<config>/abundant-doctrine` is a link to the folder you cloned, so moving or deleting that folder breaks the doctrine, `/wrap` and the guardrail at once. If you do move it, run `bash install.sh` again from the new place.

**Backups.** Before changing any file, the installer copies it to `<config>/backup-<timestamp>/`. A second run that changes nothing makes no backup. Re-running is safe at any time.

**Things worth knowing:**

- If you had turned one of the three plugins off (`false` in `enabledPlugins`), the installer turns it back on. Turn it off again in `/plugin` if you meant it.
- The installer refuses a config folder whose path contains a space, `"`, `$` or a backtick. The kit itself can live anywhere.
- A `settings.json` that is not valid JSON stops the installer before it writes anything.

**A custom config folder.** If you set `CLAUDE_CONFIG_DIR`, the installer uses that folder instead, and the generated `CLAUDE.md` imports by absolute path. Wherever the doctrine mentions `~/.claude/abundant-doctrine/`, read it as `<config>/abundant-doctrine/`.

### First-run checks

These are the checks that matter, and only a real session can run them. Do them once, after installing:

1. Start a new `claude` session (one opened before the install will not have the changes) and run `/context`. Under memory files you should see the kit's `CLAUDE.md` and your `personal.md`.
2. Run `/hooks`: the guardrail should be listed under PreToolUse, once for Bash and once for the Supabase SQL tools. Run `/plugin`: superpowers, supabase and vercel should be enabled. Run `/mcp` to see which servers the plugins connected.
3. In a scratch repo on `main`, ask Claude to commit a change. It should be refused with a message telling it to branch first.
4. In a scratch folder, ask Claude to delete a directory with `rm -rf`. It should be refused.
5. Run `bash install.sh` again. It should finish without asking anything, and without creating a new `backup-` folder.

If any of these fails, the kit is not protecting you yet. Look at `<config>/settings.json` and `/context` before carrying on.

### Updating

`git pull` in the kit folder updates the doctrine, `/wrap` and the guardrail, because your config links to it rather than copying it. Read [CHANGELOG.md](CHANGELOG.md) before pulling to see what changes. Re-run `bash install.sh` after a pull when the changelog says settings changed; it is safe to run any time.

### Uninstalling

```bash
bash uninstall.sh
```

It removes the generated `CLAUDE.md` (only if it still carries the installer's marker line), the two links, the kit's hooks, and the three plugin entries in `settings.json`. It keeps `personal.md`, your own settings and hooks, and every backup. The plugins themselves stay installed; it prints the command to remove them.

It restores nothing automatically. Two things to do by hand:

- To keep your own rules loading, rename `personal.md` back to `CLAUDE.md`.
- It removes the three plugin entries even if you had them before installing. Your pre-install files are in the oldest `backup-` folder, the one your first install made. To put a file back, list the folders (oldest first) and copy from that one:

```bash
ls -d <config>/backup-*
cp <config>/backup-<timestamp>/settings.json <config>/settings.json
```

`<config>` is `~/.claude` by default, or your `CLAUDE_CONFIG_DIR` if you set one. Restoring an old `settings.json` throws away every settings change made since that backup, including your own.

Uninstall also backs up, into a new `backup-` folder, what it changes that is not exactly what the installer wrote: `settings.json`, and a generated `CLAUDE.md` you had edited. An unedited generated `CLAUDE.md` is removed without a backup, since the installer can write it again.

## 3. The loop

Lovable trains you to prompt and watch. Claude Code works best when you plan, build, check, and write down what is left. Each step has a skill that does it well; ask for it by name ("use brainstorming") or let Claude pick it up.

1. **Describe the idea:** `superpowers:brainstorming`. Claude asks questions until the intent is clear and writes it down.
2. **Plan:** `superpowers:writing-plans`. Turns the agreed idea into small steps, each with a way to check it.
3. **Build:** `superpowers:executing-plans` for one session working through the plan, or `superpowers:subagent-driven-development` to hand each step to a fresh agent and review it.
4. **Check:** `superpowers:verification-before-completion` makes Claude run the checks before claiming anything works. Then `/code-review` on the diff.
5. **Close:** `/wrap`. It updates the project's `CLAUDE.md`, commits, checks for stray branches, and reports Outstanding, Verified and State, in that order.

**When stuck:** `superpowers:systematic-debugging`. Evidence first, then one hypothesis at a time.

## 4. Coming from Lovable

| In Lovable | In Claude Code |
|---|---|
| Typing a prompt and watching it build | `superpowers:brainstorming`, then a plan. Agree the plan before code. |
| The live preview | `npm run dev` and look at it in the browser. Claude cannot see your screen; tell it what you see, or paste a screenshot. |
| GitHub sync | A branch per change and a pull request into `main`. The guardrail refuses commits on `main`. |
| The Supabase integration | The supabase plugin, which can run SQL against every project in your Supabase organisation. Work against development; in any project near production, turn the plugin off there and use a read-only connection (section 6). |
| Publish | Vercel deploys from `main`. Preview deploys come from pull requests. A production deploy from the command line asks first. |
| Lovable remembering the project | The project's own `CLAUDE.md`. Claude reads it at the start of every session, so keep it true. |

## 5. The skills worth knowing

In rough order of how often you will want them:

1. `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:executing-plans`: the loop above. Use them for anything bigger than a small fix.
2. `superpowers:verification-before-completion`: before any "it works".
3. `superpowers:systematic-debugging`: when something is broken and the first fix did not work.
4. `supabase:supabase-postgres-best-practices`: load before any schema, policy or migration change. The doctrine requires it.
5. `supabase:supabase`: anything else Supabase, from auth to RLS surprises to reading logs.
6. `/code-review`: a review of the current diff before you open or merge a PR. `/security-review` for anything touching auth, RLS or secrets. `/simplify` when the code works but has grown awkward.
7. `vercel:env` and `vercel:env-vars`: environment variables, and pulling them into a local env file.
8. `vercel:deploy`: a preview deploy. A production deploy is refused by the guardrail until you say so.
9. `superpowers:test-driven-development`: when a project has tests, for any bug fix.
10. `superpowers:finishing-a-development-branch`: when a branch is ready to merge.

The superpowers plugin has more; ask Claude to list them.

## 6. Supabase MCP safety

The supabase plugin connects Claude to Supabase through Supabase's MCP server. As the plugin ships, the connection is to `https://mcp.supabase.com/mcp` with no options: it can see every project in the organisation you log in to, and it can write.

Supabase's own guidance ([Supabase MCP Server](https://supabase.com/docs/guides/ai-tools/mcp), read 23 Nov 2026) is blunt: "Use the MCP server with a development project, not production." The same page lists these connection options:

- `read_only=true`: "Execute all queries as a read-only Postgres user."
- `project_ref=<id>`: "Scope to a specific project (disables account tools)."
- `features=<groups>`: "Enable only specific tool groups (comma-separated)", for example `database,docs`.

They combine: `https://mcp.supabase.com/mcp?project_ref=<ref>&read_only=true`.

What to do:

- **Work against a development project or a branch** with made-up data. This is the default the doctrine sets.
- **If a project works near production**, a read-only connection is not enough on its own: the plugin's read-write, account-wide connection stays live beside it. In that project's folder, turn the plugin off for this project only, then add a read-only connection scoped to the production project:

  ```bash
  claude plugin disable supabase@claude-plugins-official --scope local
  claude mcp add --transport http supabase-prod-readonly "https://mcp.supabase.com/mcp?project_ref=<production ref>&read_only=true"
  ```

  Both apply to you, in this project only. Keep `supabase` in the server's name: the guardrail recognises Supabase SQL tools by it. Then start a new session and check `/mcp`: the only Supabase server connected should be `supabase-prod-readonly`. These steps come from the Claude Code CLI's help and Supabase's docs but have not yet been run in a live session, so do the `/mcp` check every time.
- **Tell Claude which project is which.** Record the development and production refs in the app's `CLAUDE.md` (the template has a place for them), so Claude does not pick a project from the account-wide list.
- **Read tool calls before approving them**, especially SQL. Supabase's page explains why: data in your tables can carry instructions aimed at the model (prompt injection).

Check `/mcp` to see which connections a session has. The doctrine's data section sets four conditions that must all hold before Claude works near real client data; a read-only production connection is one of them.

## 7. What the guardrail stops

It runs before every Bash command and every Supabase `execute_sql` or `apply_migration` call. When it refuses, Claude sees why and what to do instead, and should stop and ask you.

**In Bash, it refuses:**

- recursive force-deletes in any flag form: `rm -rf`, `rm -Rf`, `rm -r -f`, `rm --recursive --force`, with the flags before or after the path
- force-pushes with `--force` or `-f` (not `--force-with-lease`) or a refspec starting with `+` (`git push origin +main`), a hard reset to a remote branch, and `git clean` with `-f`, `-d` or `--force`
- a push to `main` or `master`: `git push origin main`, `git push origin feature:main`, `git push origin HEAD:main`, deleting either branch, and `--all` or `--mirror`. Push your feature branch and open a pull request instead
- a commit on `main` or `master`, including the first commit in a new repo
- `gh pr merge` unless every check on the PR has passed (and when it cannot tell, it refuses)
- `vercel --prod`, `vercel promote` and `vercel rollback`, and `npm publish`
- `supabase db reset` and `supabase db push` (which applies migrations to the linked project, usually production)
- destructive SQL anywhere in the command: see below

**In SQL (Bash or the Supabase tools), it refuses:** `DROP TABLE`, `DROP DATABASE`, `DROP SCHEMA`, `TRUNCATE` (with or without the word `TABLE`), `ALTER TABLE ... DROP COLUMN`, and a `DELETE FROM` with no `WHERE`, including on a schema-qualified or quoted table name (`DELETE FROM public.clients;`) and inside shell quotes with no semicolon. Upper or lower case, on one line or several.

**Getting past it on purpose.** Claude should not try to get round it. If you have read the command and want it run, run it yourself in your own terminal. That is the design: the moves you cannot take back are made by a person.

**What it does NOT catch.** It is a seatbelt, not a substitute for the doctrine's rule that nothing writes to production without your go-ahead. It misses:

- a recursive delete without force (`rm -r build`), and other ways to delete files, such as `find -delete`
- a `git push` that names no branch, or names `HEAD`, while you are on `main` (the commit guard stops new commits there, which is the usual way in)
- other Supabase CLI commands that change the linked project
- `UPDATE` and `INSERT`, however many rows they touch
- a `DELETE` with a `WHERE` clause, even `WHERE true`
- a `DELETE` or `TRUNCATE` whose table name is followed by something it does not recognise, such as an alias (`DELETE FROM clients c;`)
- `DROP FUNCTION`, `DROP POLICY`, `DROP VIEW`, `DROP INDEX`, `ALTER TABLE ... DROP CONSTRAINT` and other drops it does not list
- the Supabase branch tools (merging, resetting or deleting a branch), and every other non-SQL MCP tool, including the Vercel plugin's
- anything done in a web dashboard: GitHub's merge button, Supabase's SQL editor, Vercel's promote button
- file edits Claude makes directly, which are not shell commands

It errs toward asking, so it sometimes refuses a harmless line, such as a commit message that quotes one of the commands above.

If it refuses something often that is fine for you, say so in your `personal.md` rather than removing it. A guardrail you turn off protects nothing.

## 8. Your first project

1. In the app's repo, make a branch: `git checkout -b <your name>/setup`.
2. Copy `templates/project-CLAUDE.md` to the repo root as `CLAUDE.md`. Fill in the placeholders, and above all the **Ways to hurt yourself** list: the few things in this app that cannot be undone, why, and the safe alternative. Two are already there for every Supabase app.
3. Copy `templates/ci.yml` to `.github/workflows/ci.yml`. It runs lint, a type check and a build on every pull request. It reads the Node version from `engines.node` in `package.json`, or uses Node 24 if that is not set, so set `engines.node` to match Vercel.
4. Push the branch and open a pull request. After CI has run once, make the `check` job a required status check if your GitHub plan offers branch protection on this repo; otherwise the guardrail's merge check is the backstop.
5. Record the Supabase projects (development and production) and the data conditions in the new `CLAUDE.md`, then start with `superpowers:brainstorming`.

End each session with `/wrap`.

## Maintaining the kit

Before publishing a change to the kit itself, run the leak gate: `bash scripts/leak-check.sh --self-test`, then `LEAK_TERMS=/path/to/terms.txt bash scripts/leak-check.sh`. It scans every file and the commit history (author and committer names and emails, and messages) for the terms you list. The terms file is not shipped, because the terms would leak: maintainers supply their own private one, kept outside the repo. Without it the scan refuses to run.

## Licence

MIT. See [LICENSE](LICENSE).

Made by Abundant Kindling.
