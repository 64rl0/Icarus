# agents/

Working folder for AI coding agents on this project.

## Purpose

Everything related to how AI agents operate here lives in this folder:
instructions, project-specific context, and persistent memory across
sessions.

`agents/AGENTS.md` is the **sole source of truth** for this project. It does
not rely on any global or user-level agent configuration.

## Structure

```
agents/
├── README.md              # this file (for humans)
├── AGENTS.md              # agent instructions — the source of truth
├── context/               # lazy-loaded, project-specific references
│   ├── build-system.md    # Icarus Builder — how to build/test/run
│   ├── tech-stack.md      # languages, frameworks, conventions
│   ├── architecture.md    # system shape, components, data flow
│   └── domain.md          # glossary, business rules, invariants
├── notes/                 # task-scoped TODO lists / work notes
│   └── YYYY-MM-DD-<title>.md
└── memory/                # session continuity, appended by agents
    └── YYYY-MM-DD.md
```

## How agents use this folder

1. Read `AGENTS.md` at session start.
2. Follow the core rules and memory protocol it defines.
3. Lazy-load `context/*.md` via `@agents/context/<file>.md` references only
   when the current task needs that information. Do not preemptively load
   everything.
4. Create / update task notes in `notes/YYYY-MM-DD-<title>.md` for any
   non-trivial work (see the TODO protocol in `AGENTS.md`).
5. Append to `memory/YYYY-MM-DD.md` on significant events or explicit dump
   requests.

## How humans use this folder

- **Edit `AGENTS.md`** to adjust agent behavior for this project. Keep the
  core rules stable; project-specific stuff belongs in `context/`.
- **Edit `context/tech-stack.md`** to match the actual stack of this
  project — the default template matches a Python + TypeScript + AWS CDK
  setup; change or trim as needed.
- **Leave `context/build-system.md` alone** unless Icarus Builder itself
  changes. It documents the build system, not this project, so it carries
  over to every project cloned from the template unchanged.
- **Fill in `context/architecture.md` and `context/domain.md`** as the
  project grows. They start as placeholders.
- **Browse `notes/`** to see task-scoped TODO lists and work-in-progress
  notes. These are the agent's "scratchpad" for a given task — they document
  what was planned, what's blocked, and what was verified.
- **Browse `memory/`** to see what an agent did, decided, or learned on a
  given day. Treat it as read-only history; only edit to redact secrets or
  tidy up. Memory files are committed to git on purpose — they travel with
  the repo.
- **Never paste secrets, tokens, or `.env` contents** into any file here.

## Using this as a template

When starting a new project from this template:

1. Copy the entire `agents/` folder.
2. Edit `context/tech-stack.md` to match the new project's stack.
3. Leave `context/architecture.md` and `context/domain.md` as stubs; fill in
   as the project takes shape. `context/build-system.md` needs no edits.
4. Clear out old `memory/*.md` and `notes/*.md` files (keep `.gitkeep`).
5. `AGENTS.md` itself should rarely need per-project edits — it encodes
   principles, not project details.
