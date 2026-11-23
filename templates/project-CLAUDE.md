# <project name>

<!--
Starting shape for an app's root CLAUDE.md. Replace every <placeholder>, delete
this comment, and drop any heading that does not apply. Keep ## Loose ends: it is
where deferred work is written down, and /wrap reads it. Keep the whole file
under 40,000 characters. It is an index of what is true now, not a diary: edit it
to stay true, never append a session to it.
-->

## Overview

<One paragraph: what this app is, which organisation it is for, who uses it, and what state it is in.>

## Ways to hurt yourself

The few things that cannot be undone here. Five at most. Each has the action, why it cannot be undone, and the safe alternative. Add your own below the two that every Supabase app has.

1. **Running a migration or any write against the production Supabase project.** Production holds the organisation's real records, and a migration or bulk write cannot be taken back once it has run. Develop and test against the development project or a branch, review the SQL, and run it against production only for a named reason, with a backup taken first and the user's go-ahead.
2. **Letting the service-role key reach the browser.** It bypasses row-level security, so anyone who sees it can read and change every row, and a key that has been published cannot be recalled without rotating it. Use it only in server code, never in a `NEXT_PUBLIC_` variable or a client component, and use the anon key with RLS in the browser.
3. **<Your action.>** <Why it cannot be undone here.> <What to do instead.>

## Stack

Next.js, TypeScript, Supabase and Vercel unless noted. Set `engines.node` in `package.json`, because CI and Vercel both read it. <Anything that differs: versions, UI library, extra services.>

## Structure

<The directories that matter and what lives in them. Not a full tree.>

## Commands

- Install: `npm ci`
- Develop: `npm run dev`
- Lint: `npm run lint`
- Type check: `npx tsc --noEmit`
- Build: `npm run build`
- <Test, migrate, deploy: the ones actually used.>

## Secrets and environment

- Where secrets live: <secret manager or Vercel environment variables. Never in the repo, never pasted into chat.>
- Variables the app needs, by name only: <`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (server only), ...>
- `.env*` files are gitignored. <Where a new developer gets the values.>

## Supabase

- Development project: <name and ref>
- Production project: <name and ref>
- Which one the Supabase plugin points at: <development, unless a named reason says otherwise. Production read-only where the connection offers it.>
- RLS status: <every table has RLS on from creation: yes or no. List any table that does not, and why.>
- Migrations: <where they live, and how they reach production.>

### Client data conditions

Claude Code may work near the client's real data only while all four hold. Record each one with the date you last checked it.

| Condition | Status | Checked |
|---|---|---|
| Your Anthropic plan's data terms are read: whether inputs train models, how long they are kept, and whether a commercial plan is needed | <yes or no, and which plan> | <date> |
| The client has agreed to AI-assisted development touching their data | <yes or no, and how they agreed> | <date> |
| The work uses the least data it can: development projects and seed data first, production only for a named reason | <yes or no> | <date> |
| The Supabase connection used near production is read-only wherever it offers that | <yes, no or not offered> | <date> |

## Conventions

Rules for this project that add to the doctrine. End each with the mechanism that enforces it, `[gate: <lint rule, hook or CI step>]`, or `[unenforced]`.

- <Rule.> [unenforced]

## Gotchas

Cross-cutting traps, the things that cost an hour the first time.

- <Gotcha.>

## Handover notes

For the client or the next developer. Systems handed over come with the reasoning, not only the code.

- What this app does and why it was built this way: <...>
- Decisions made and the alternatives turned down: <...>
- How to run, deploy and restore it, and who holds each login: <...>
- What the organisation must do to keep it healthy (renewals, reviews, backups): <...>

## Loose ends

Deferred work, written at the moment of deferral, never left for the end of the session. One line each, with a tier and a date. The `/wrap` report's Outstanding section reads this list, so an item that is not here cannot be reported.

Tiers:

- `blocked-on-me`: needs a decision, credential or action from you. Listed first.
- `blocked-on-client`: needs a decision, access or sign-off from the client. Listed second.
- `papercut`: works, but rough.
- `polish`: no correctness consequence.

A blocker is fixed, never listed here. A closed item leaves this list in the commit that closes it, with one line on how it closed in `docs/loose-ends-closed.md`. Never strike it and leave it in place.

Format: `- [papercut] 29 Jul - short description`

_None._

## Recent sessions

The last three sessions as one-line hooks, each linking its full record in `docs/sessions/`. Older hooks roll into a sessions index. `docs/sessions/` and `docs/loose-ends-closed.md` do not exist in a new app: create them the first time you need them.

- <date - one line - link>
