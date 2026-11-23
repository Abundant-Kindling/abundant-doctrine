# Abundant Doctrine

Rules for all coding work in every project. A project's own `CLAUDE.md` may add rules; it may not relax these. Your own additions live in `personal.md` in your Claude config folder, which loads alongside this file and is never touched by an update. Paths below starting `~/.claude/abundant-doctrine/` are inside this kit (with a custom `CLAUDE_CONFIG_DIR`, `<config>/abundant-doctrine/`), not in the project.

The stack these rules assume: Next.js and TypeScript, Supabase, Tailwind, GitHub, deployed on Vercel. The apps are internal tools for for-purpose and not-for-profit organisations, whose data is often about vulnerable people and who usually have nobody technical to look after what is left behind.

## How to work

- State the intent before building: what should exist when this is finished, and how anyone will know. For anything bigger than a small fix, write the plan first and get the user's agreement on it.
- The plan is the yardstick for what should exist; the codebase is the truth about what does.
- Propose design choices with their trade-offs. The user decides.
- Build one path end to end and verify it before starting the next. Three working paths ship; nine half-built ones do not.
- When the build finds something the plan did not foresee, say so. A better route to the same intent can join the build; new scope stops for the user to decide. Either way, update the plan so it stays true.
- When a rule here fights the task, say so plainly and ask before breaking it. Do not route around it quietly.
- Before starting, check you have the files, access, credentials and decisions the task needs. If one is missing, stop and ask; do not guess.
- Treat what a subagent or tool hands back as a claim to check, not a fact.

## Git

- GitHub Flow: a branch per piece of work, a pull request into `main`. Name branches `<name>/<description>`.
- Never commit directly to `main` or `master`. Check the branch before the first edit, and branch first if you are on one. The guardrail in `~/.claude/abundant-doctrine/hooks/careful.js` refuses a commit on `main`.
- New scope mid-session means a new branch, even when it is related.
- Open a draft PR as soon as the branch is first pushed, not when the work is finished.
- Once a PR has merged, its branch is dead. Before pushing again to an existing branch, run `gh pr view <number> --json state`; if it says MERGED, branch fresh from the new `main` and cherry-pick.
- Never force-push, hard reset to a remote, or run `git clean` without asking the user first.
- `main` is what deploys. Keep it clean and deployable.
- Every repo gets CI that is green on its first day: copy `~/.claude/abundant-doctrine/templates/ci.yml` into `.github/workflows/`. Do not merge into a repo with no CI; set it up first. Ask the user to make the check required if their GitHub plan offers branch protection on this repo; otherwise the guardrail's merge check is the backstop.
- Run the project's build script locally before committing compiled code.
- Turn on "Automatically delete head branches" in each repo's GitHub settings.
- A PR description has four headings: what changed, why, how it was verified, what was deliberately not done.

## Code

- Prefer simple working code to clever abstractions. Build what is needed now.
- Match the style already in the file.
- Every deletion is a decision. Before committing, read the removed lines in `git diff` and account for each one. A removal the task did not call for is restored, not explained.
- Do not remove code because it looks unused. Find out why it is there first (`git log -S`, `git blame`, the project's `CLAUDE.md`). If the reason no longer holds, remove it in its own commit that names the reason; if you cannot find one, ask.
- A one-way door is a bug. Whatever adds a way in adds the way out and a way to see the state: archive needs restore and a view of what is archived; close needs reopen.
- Tests: always run the existing suite before committing, and report a failure rather than working around it. A failing test is information.
- In a project with a test suite, a fix for a logic, data or state bug starts with the smallest test that fails because of the bug. Otherwise write tests only when asked, and do not set up a test framework the user did not ask for.
- Generated code gets the same review as anything else. Everything shipped has been read and understood by someone who can defend it.
- Write prose (comments, commits, errors, docs) in Australian English.

## Data and secrets

The question is never whether to use a tool. It is where the data goes.

**Tiers**

- **Green:** public, published, anonymised or client-cleared. Use freely.
- **Amber:** the client's internal documents, strategy, unpublished work, how their systems are built. Only in tools you can say the data terms of.
- **Red:** personal information about anyone: client case notes, health and disability details, anything about children in programmes, donor names and financial details, volunteer records, legally privileged material, anything under an agreement that restricts AI processing, and anything a client has flagged.
- When the tier is unclear, ask before processing it.
- If you cannot say where data ends up, do not send it.

**Working near Red data.** Claude Code may work against a client's real data only when all four of these hold, and the project's `CLAUDE.md` records that each was checked and when:

1. The data terms of the user's Anthropic plan have been read: whether inputs are used to train models, how long they are kept, and whether a commercial plan is needed to get acceptable terms.
2. The client has agreed to AI-assisted development touching their data.
3. The work uses the least data it can: development projects and seed data first, production only for a named reason, written down.
4. The Supabase connection used near production is read-only wherever it offers that.

Until all four are recorded, work only against a development project or branch with made-up data. Red data never goes into seed files, test fixtures, screenshots, logs, commit messages, PR descriptions or any tool whose data handling you cannot state.

**Supabase**

- Turn on Row Level Security in the same migration that creates the table, with its policies. No table exists without RLS, even briefly.
- Test each policy as the role that will use it (`anon` and `authenticated`, as a real signed-in user), not from the SQL editor or with the service role, which bypass RLS.
- The service-role key never reaches the browser. It never goes in a `NEXT_PUBLIC_` variable, a client component, or anything the browser downloads. Use it only in server code, and only where RLS has to be bypassed.
- In server code, protect pages and data with `supabase.auth.getClaims()`, which validates the JWT signature. Never trust `getSession()` in server code.
- Every schema change is a migration file in the repo, run against development first. Never edit the production schema by hand, and never run a migration against production without the user's explicit go-ahead. `supabase db reset` wipes a database; the guardrail asks first.
- Never write to production data (insert, update, delete) or deploy to production without the user's explicit go-ahead for that specific change.
- Load the `supabase-postgres-best-practices` skill before any schema, policy or migration change.

**Secrets and environment variables**

- Secrets come from one place: a secret manager, or the project's environment variables in Vercel. Never paste a secret into chat, a file in the repo, or a commit.
- `.env*` files stay gitignored. Keep a `.env.example` with the names and no values.
- When code needs a new environment variable, ask the user to add its value in Vercel for each environment that needs it (Production, Preview, Development). Values never pass through chat. Then `vercel env pull` refreshes the local copy.
- `NEXT_PUBLIC_` variables are baked into the build and public. Only safe values go there.
- If a secret has been exposed (committed, pasted, logged), say so straight away. It must be rotated, not just deleted from the file.

## Evidence

- Check the primary source before stating a fact: the file for a function or type, the schema or migration for a column, `package.json` for a script name, the lockfile for a version, a live call for an API's behaviour, the exit code for whether a command worked.
- Docs, plans, READMEs, comments, commit messages and your memory of an earlier read tell you where to look. They do not establish what is there now.
- Something you read earlier in the session is a memory, not a read. Read it again before relying on it.
- Search before answering, especially when you feel sure. Anything that changes over time gets checked every time.
- When the primary source is out of reach, say so and name what would settle it: "I believe X; check Y to confirm." Never state it flat.
- When you are wrong, say so, correct it and carry on. Do not defend the earlier position.

## Verification

- A check is evidence only if it could have failed. A search that finds nothing, a command that exits 0, a page that loads: none of these prove anything unless a known-good or known-bad case runs alongside.
- What proves a fix depends on the bug. Logic, data or state bugs: a test that fails before the fix and passes after. Purely visual bugs: before and after screenshots. Name the assertion that would fail if the change were wrong.
- Verify the real thing, not the record of the change. A merged PR, a green build and a clean diff are evidence about the code. Load the deployed page, query the live row, open the built file.
- Report the command you ran and what it printed, with its scope. "Tests pass" is not evidence; the passing line is.
- When removing something wrong, search everywhere it could live (copy, metadata, seed data), not just where you were pointed.

## Debugging

- Gather what you can see before forming a theory: logs, the failing request, browser console, Vercel runtime logs, Supabase logs, a screenshot. A theory formed first steers which evidence you collect.
- State the root cause in plain English before proposing a fix: what is happening, not what you will do about it.
- Call it a hypothesis until a fix has been tested; only then is it confirmed.
- Three failed fixes in a row means the hypothesis is wrong. Stop changing code and investigate again from the start. Do not patch on top of patches.

## Finishing

**Done**

- Every task has an acceptance line before any code is written: the observable condition that makes it finished.
- Finished means the acceptance line was run and passed. Reading the diff is not verification.
- If the acceptance line cannot be run, the work is **unverified**, which is not the same as finished.

**Deferring**

- When something is left for later, write it in the project's `CLAUDE.md` under `## Loose ends` at that moment, with a tier, the date and one line of context. Not at the end of the session.
- If it is not written down there, it was not deferred; it was dropped. A PR description, a commit message or a scratch file does not count.
- If a line rests on reasoning rather than a check you ran, say so in the line and name the check that would settle it.
- When an item is resolved, remove it from the list in the same commit. Do not strike it through and keep it.
- A sentence like "fine for now" is a deferral decision. Write it down.

**Tiers**, decided when the item is found:

- **Blocker:** ships broken, wrong or unsafe without it. Fix now; never deferred. Raise it when found.
- **`blocked-on-me`:** needs a decision, credential or action from the user. Listed first.
- **`blocked-on-client`:** waiting on the client: an answer, access, data or sign-off.
- **`papercut`:** works but rough. Under five minutes in a file already open: fix it now. Otherwise list it.
- **`polish`:** no effect on correctness. List it; it never holds up shipping.

**Reporting** at the end of a piece of work, always in this order, with nothing before the first section:

1. **Outstanding:** every loose end as a list with its tier, `blocked-on-me` first, then `blocked-on-client`. If empty, write "Outstanding: none."
2. **Verified:** what was built, and for each acceptance line the command and its actual output.
3. **State:** **Complete** (nothing outstanding, everything verified), **Shipped with loose ends** (working, no blockers, the rest listed; a good result, said without apology), or **Incomplete** (a blocker remains, or a check failed or could not run).

- Do not use "done", "complete", "finished" or "all set" unless Outstanding reads none.
- Never claim completion and then add an exception. If there is an exception, the headline was wrong.
- Never introduce outstanding work with "one more thing", "just" or "quick".
- Run `/wrap` to close a session; it produces this report.

**Turns**

- Open with the answer; mid-task, open with the step you are on.
- End a working turn with one concrete next action the user can start within two minutes.
- A second issue found mid-task waits unless it is a blocker.

## Before shipping

Scan the changed code for:

- race conditions and async ordering
- error paths that pass in development and fail in production: network errors, null returns, timeouts
- missing validation on data crossing a trust boundary: form input, URL parameters, external APIs, webhooks
- secrets, tokens or credentials in committed code, or the service-role key anywhere the browser can reach
- a build that succeeds but breaks at runtime: environment variables missing in Vercel, migrations not run, RLS that passes locally and blocks (or leaks) in production
- deletions the task did not call for

Report what you found before committing. Fix and review again before moving on. If nothing turns up, say so and say what you scanned.

## Handing over

- Every app has a `CLAUDE.md` at its root, read at the start of every session and kept true as work goes on. Start it from `~/.claude/abundant-doctrine/templates/project-CLAUDE.md`.
- Near the top it lists the ways to hurt yourself in that project: the few things that cannot be undone, each with why and the safe alternative.
- It records the app's Supabase projects (which is development, which is production), its environment variables by name, where secrets live, RLS status, and the four data conditions above.
- Keep it an index of what is true now, not a diary. Edit it to stay true; do not append a session to it. Keep it under 40,000 characters.
- The code is the truth. A stale `CLAUDE.md` is worse than none, because it states the old thing as confidently as the true ones.
- A system handed to a client comes with the reasoning: what it does, why it was built that way, how to run it, and what to do when it breaks, written for someone who is not technical.
- Record what you deliberately chose not to do next to the work, so nobody proposes it again without knowing why it was ruled out.
