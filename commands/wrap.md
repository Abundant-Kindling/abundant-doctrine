---
description: Close the session. Review pass, acceptance checks, project doc update, commit, branch audit, then report Outstanding first, Verified second, State last.
argument-hint: "[skip-review]"
---

Close out this session. If `$ARGUMENTS` contains `skip-review`, leave out step 1 (only when the session changed no code).

The report shape is the point of this command. The usual habit buries loose ends in prose under a claim of success, with the item that needs the user at the bottom. The output contract below is the deliverable, not a suggestion about emphasis.

## Procedure: do all of this before writing any output

1. **Review pass** (unless `skip-review`). Scan the code this session changed for: race conditions and async ordering; error paths that pass in development and fail in production (network errors, null returns, timeouts); missing validation on data crossing a trust boundary; secrets, tokens or the Supabase service-role key anywhere committed or browser-reachable; a build that succeeds but breaks at runtime (env vars missing in Vercel, migrations not run, RLS that passes locally and blocks or leaks in production); deletions the task did not call for. Fix findings and review again before committing, or record them as loose ends with a tier. Finding nothing is a result: say what you scanned.

2. **Run the acceptance checks.** Every piece of work closed this session has an observable condition. Run it and keep the real output for section 2. Reading the diff is not verification. A check that cannot be run makes that work **unverified**, which goes in Outstanding.

3. **Keep the project's `CLAUDE.md` true: edit it, never append the session to it.** Change it only where a rule, convention, gotcha or status actually changed, and rewrite a changed rule in place. Every deferral from this session goes under `## Loose ends` with its tier, the date and one line of context; add the heading if it is missing. Then run `wc -c CLAUDE.md`: over 40,000 characters means moving detail out into linked files before committing.

4. **Reconcile `## Loose ends` before writing the report.**
   - Against your head: any outstanding item you are about to report that is not in the list gets written there now, committed, and tagged `(late capture)` in the report. Section 1 is a read-out of the list, never a recollection.
   - Against the world: for each item that depends on something outside the repo (a PR awaiting merge, a client's answer, a deploy), check whether it still holds. `gh pr list --state open` and `gh pr view <n> --json state` settle PR claims. Remove resolved items in the same commit; do not strike them through.

5. **Commit and push.** On a feature branch, never `main` or `master`. Run the test suite first and report any failure rather than working around it. Open a draft PR if the branch has none. If this branch's PR already merged, stop: branch fresh from `main` and cherry-pick.

6. **Audit branches.** Run `git fetch --prune` then `git branch -r --no-merged origin/main`. Delete merged strays. List each unmerged branch with its age and last commit for a keep, salvage or delete decision, and record its tip SHA before deleting any unmerged branch.

7. **Close what the session left running.** Look for dev servers, watchers and waiting loops this session started (`ps`, `lsof -iTCP -sTCP:LISTEN`), and stop them by PID. Leave the user's own editor, terminal and services alone. Anything still running goes in Outstanding with its age.

## Output contract

Emit exactly three sections in this order, and **nothing before section 1**: no preamble, no summary sentence, no restating of the request.

### 1. Outstanding

A list, never prose. Every loose end, each with its tier: the items quoted from `## Loose ends`, plus unverified work and anything still running:

- **`[blocked-on-me]`**: needs the user's decision, credential, access or action. **Always first.**
- **`[blocked-on-client]`**: waiting on the client for an answer, access, data or sign-off. Second.
- **`[papercut]`**: works but rough.
- **`[polish]`**: no effect on correctness.

One line each, dated, with enough context to act on it cold next session. Blockers never appear here: a blocker is fixed, or it is named in section 3, which then reads **Incomplete**. If there is nothing, write `Outstanding: none.`, those exact words.

### 2. Verified

What was built and how each acceptance line was checked: the command and its actual output, the passing test line, the observed behaviour. "Tests pass" is not evidence. Anything that could not be checked is named **unverified** here and also appears in section 1. Name any servers or waiters that were stopped.

### 3. State

Exactly one of:

- **Complete**: only when section 1 reads none and every acceptance line was verified.
- **Shipped with loose ends**: working, no blockers, the rest listed. A good outcome; say it without apology.
- **Incomplete**: a blocker remains, or an acceptance line failed or could not be run.

## Banned in this output

- "Done", "complete", "finished", "all set" or "we're good" anywhere, unless section 1 reads none.
- Claiming completion, then adding an exception. If there is an exception, the headline was wrong.
- "One more thing", "just" or "quick" to introduce outstanding work.
- Any line before the Outstanding heading.
- Prose where a list is specified.

If wrap is the first time an outstanding item appears, that is a slip in the session's process, not a tidy-up. Say so in section 1.
