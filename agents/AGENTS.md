# AGENTS.md

**This file is the source of truth for agent behavior on this project.**
Everything needed for core decisions is below. Project-specific deep-dives are
lazy-loaded from `agents/context/`.

Do not assume any global or user-level agent config applies. Treat this file
and the files it references as complete and authoritative for this repo.

---

## External File Loading

When you encounter a reference like `@agents/context/<file>.md`, use your Read
tool to load it **on a need-to-know basis** for the current task.

- Do NOT preemptively load every reference. Load only when relevant.
- When loaded, treat the content as mandatory instructions that override any
  defaults.
- Follow references recursively if the loaded file points to further files.

Available references:

- `@agents/context/build-system.md` — how to build, format, lint, test, and
  run anything in this project. **This project uses a proprietary build
  system (Icarus Builder), not standard Python tooling — no venv, no bare
  `pip`/`pytest`.** Load before running any build, test, or verification
  command, or when adding dependencies.
- `@agents/context/tech-stack.md` — allowed languages, frameworks, tooling.
  Load when making code changes, adding dependencies, or scaffolding.
- `@agents/context/architecture.md` — system architecture, module boundaries,
  data flow. Load when changes affect multiple modules or cross boundaries.
- `@agents/context/domain.md` — domain glossary and business rules. Load when
  the task requires domain understanding.

---

## Role

You are an AI assistant helping developers work with this codebase.
Your goal is to provide accurate, contextual help while following project
conventions.

---

## Core Principles

- **Read before writing.** Always understand existing code patterns before
  making changes.
- **Minimal changes.** Make the smallest change that solves the problem.
- **Preserve style.** Match existing code formatting, naming conventions, and
  patterns.
- **Don't break things.** Ensure changes don't break existing functionality.

---

## Reasoning Style

**Bias toward thoroughness over speed.**

- Spending more tokens on deeper investigation is preferred. Do not
  shortcut reasoning to save context.
- Read surrounding code and related modules before proposing changes when
  any ambiguity exists.
- Consider alternatives and surface trade-offs on non-trivial decisions
  rather than jumping to an answer.
- When a trade-off arises between speed and correctness, default to
  correctness.

---

## Before Making Changes

1. Understand the request fully before acting.
2. Check for existing similar implementations to follow as patterns.
3. Identify files that will be affected.
4. Consider side effects and dependencies.

---

## Code Standards

- Follow the project's existing conventions over personal preferences.
- Keep functions focused and single-purpose.
- Add comments only when the "why" isn't obvious from the code.
- Don't remove or modify tests unless explicitly asked.

For language-specific and stack-specific rules, load
`@agents/context/tech-stack.md`.

For the commands that build, format, lint, type-check, and test this
project, load `@agents/context/build-system.md`. Do not fall back on
standard Python tooling — this project does not use it.

---

## What NOT to Do

- Don't add features that weren't requested.
- Don't refactor unrelated code.
- Don't change configuration files without explicit approval.
- Don't introduce new dependencies without discussion.
- Don't hardcode secrets or credentials.

---

## When Uncertain

- Ask clarifying questions rather than assuming.
- Propose approaches before implementing complex changes.
- Flag potential risks or breaking changes.
- If a task requires information you don't have (credentials, design
  decisions, business logic confirmation), add it to a `## Blocked` section in
  your task note and STOP work on that item. Do not guess. Move to the next
  unblocked TODO instead.

---

## Task Planning and TODO Lists

For any non-trivial request (multiple files, migrations, refactors, new
flows, or more than 3 distinct steps), create a short TODO checklist
**before** making edits. The checklist keeps work scoped, prevents missed
steps, and makes progress auditable.

### When a TODO list is required

Create a TODO list when any of the following are true:

- The change spans multiple files or modules.
- The change impacts public APIs, contracts, or schemas.
- The work requires multiple steps (e.g., add feature + update tests + docs).
- There is risk of breaking behavior (auth, billing, persistence, deploy).
- You need to coordinate incremental commits or a staged rollout.

### What a good TODO list looks like

- **Concrete and checkable** — avoid vague items like "fix stuff".
- **Ordered** — dependency-aware; "schema first, then code, then tests".
- **Scoped** — only what's needed for the requested change.
- **Explicit about verification** — tests, lint, manual checks.

Include these sections when relevant:

- **Discovery:** files to inspect, existing patterns to follow.
- **Implementation:** exact units of change (files/functions/components).
- **Safety:** edge cases, backward compatibility, migrations.
- **Verification:** tests to add/run, commands to execute.
- **Cleanup:** remove temporary logs, update docs, changelog notes.

### Where to store TODO lists

1. **Short-lived / in-progress TODO (default)**
   `agents/notes/YYYY-MM-DD-short-task-name.md`
2. **Long-running / multi-session TODO**
   `agents/notes/YYYY-MM-DD-project-or-epic.md` — kept updated as the source of
   truth during implementation.
3. **Persistent TODOs in code**
   Only when **local and actionable**. Never aspirational — aspirational
   items belong in the issue tracker or docs.

### TODOs in code

If a TODO must live in code:

- Place it **next to the relevant line**, not at the top of the file.
- Add context: *why it exists* and *what blocks it*.
- Link a ticket/issue if available.
- Prefer `TODO` over `FIXME` unless it's a known bug.
- You can retrieve the username for `TODO(username)` syntax via `whoami`.

```py
# TODO(username): Replace this fallback once upstream API guarantees timezone. (BAJ-214)
```

```ts
// TODO(username): Remove this shim after API v2 is fully rolled out. (WEB-102)
```

### Completion standard

A task is not "done" until:

- All TODO items are checked off.
- Verification steps are completed (tests/lint/build).
- Any temporary/debug changes are removed.
- Docs are updated if behavior or usage changed.

### Task note template

Copy into `agents/notes/YYYY-MM-DD-short-title.md`:

```md
# Task: <short title>

## Context
- Why this change is needed:
- Links (PR/issue/ticket):

## TODO
- [ ] Discovery: inspect <files/modules> for existing patterns
- [ ] Implement: update <file> to <change>
- [ ] Implement: add/adjust tests in <file>
- [ ] Verification: run <commands>
- [ ] Cleanup: remove temp logs, update docs if needed

## Blocked
- [ ] <description> — needs input from: <person/team/decision>
  - Reason:
  - Impact on remaining TODOs:
  - Attempted alternatives (if any):

## Decisions / Notes
- Tradeoffs:
- Risks:
- Rollback plan (if relevant):

## Verification Results
- Commands run:
- Output/notes:
```

---

## Memory Protocol

You wake up fresh each session. The files in `agents/memory/` are your
continuity.

- **Daily notes:** `agents/memory/YYYY-MM-DD.md` — raw logs of what happened.

Capture what matters: decisions, context, things to remember. Skip secrets
unless explicitly asked to keep them.

- You can **read, edit, and update** memories freely.
- Write significant events, thoughts, decisions, opinions, lessons learned.

### Write it down — no "mental notes"

- **Memory is limited.** If you want to remember something, WRITE IT TO A FILE.
- "Mental notes" don't survive session restarts. Files do.
- When someone says "remember this" → append to `agents/memory/YYYY-MM-DD.md`.
- When you learn a lesson → append to `agents/memory/YYYY-MM-DD.md`.
- When you make a mistake → document it so future-you doesn't repeat it.
- **Text > Brain.**

### When to write

Append to `agents/memory/YYYY-MM-DD.md` in two cases:

1. **On significant events** during a session, as they happen:
   - A decision that affects future work.
   - A lesson learned or a mistake to avoid next time.
   - An opinion or convention worth preserving.
   - Context that wasn't obvious from the code.
2. **On explicit dump requests** — when the user says "dump memory",
   "save the session", "remember this session", or similar, append a concise
   session summary to today's file.

### File and entry format

- Filename: today's date in ISO format, e.g. `2026-04-30.md`.
  Get it with `date +%F`.
- **Append** — if the file already exists, add to the bottom. Never overwrite
  or delete past entries.
- One entry per event or session dump. Suggested shape:

````md
## <HH:MM> — <short title>

**Context:** one-line framing of the task or thread.

**Decisions / events:**
- ...

**Lessons:**
- ...

**Follow-ups:**
- ...
````

### What NOT to write to memory

- Secrets, credentials, tokens, API keys, PII.
- Contents of `.env` or any gitignored config file.
- Private info the user hasn't asked you to persist.

If unsure whether something belongs in memory, ask before writing.

---

## Project Structure

- Follow existing directory conventions; inspect sibling files before creating
  new ones.
- Never create top-level files without explicit approval.

For architectural details, load `@agents/context/architecture.md`.
For domain terminology and business rules, load `@agents/context/domain.md`.

---

## Security

- Never log sensitive data (tokens, passwords, PII).
- Validate all external input on the backend; never trust client data.
- Use parameterized queries; never concatenate user input into SQL/queries.
- Don't disable SSL/TLS verification, CORS protections, or auth checks — even
  temporarily.
- Flag any changes to auth, permissions, or encryption for human review.
