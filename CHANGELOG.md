# Changelog

What each tagged release changes. Read the entry before you `git pull`, so you know what your setup is about to do differently.

## Unreleased

- **Guardrail** now also refuses `rm` with recursive and force flags in any form (`-Rf`, `-r -f`, `--recursive --force`), `git clean --force`, a push refspec starting with `+`, a push to `main` or `master` (`git push origin main`, `feature:main`, `HEAD:main`, `--all`), `supabase db push`, `TRUNCATE` without `TABLE`, `ALTER TABLE ... DROP COLUMN`, and a `DELETE` with no `WHERE` on a schema-qualified or quoted table or inside shell quotes. The README's list of what it does not catch is updated to match.
- **Uninstaller** points at the oldest backup, which holds your files from before the kit, and names its own backup separately. Backups keep file permissions.
- **Doctrine and templates**: making the CI check required now depends on your GitHub plan offering branch protection, with the guardrail's merge check as the backstop; the read-only data condition is about whichever Supabase connection is used near production; the CI template says what it assumes.
- **Leak gate** (`scripts/leak-check.sh`, for maintainers): the terms file is no longer shipped. Supply your own with `LEAK_TERMS` or `--scan FILE`; without one the scan refuses to run. It now also scans commit history, and `LEAK_SKIP_HISTORY=1` skips that part with a warning.

## v0.1.0 (2026-11-23)

First release.

- **Doctrine** (`CLAUDE.md`): working rules for Next.js, Supabase and Vercel apps built for for-purpose and not-for-profit organisations, including the data tiers and the four conditions for working near real client data.
- **`/wrap`** (`commands/wrap.md`): closes a session with an Outstanding, Verified and State report.
- **Guardrail** (`hooks/careful.js`): refuses `rm -rf`, force-pushes, hard resets to a remote, `git clean`, commits on `main`, merging a PR without passing checks, production deploys from the Vercel CLI, `npm publish`, `supabase db reset`, and destructive SQL in Bash and in the Supabase SQL tools. Its known gaps are listed in the README.
- **Templates**: a project `CLAUDE.md` and a GitHub Actions CI workflow that reads the Node version from `engines.node`.
- **Installer and uninstaller**: idempotent, back up whatever they change, keep your own rules in `personal.md`, and merge rather than replace `settings.json`. Installs the superpowers, supabase and vercel plugins.
