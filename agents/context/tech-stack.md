# Tech Stack

Project-specific technology requirements. Edit this file per project to reflect
the actual stack. The defaults below match the author's standard template —
**replace or remove sections that don't apply**.

---

## Backend

- **Language:** Python with strict type annotations
- All functions must have complete type hints (parameters and return types)
- Do not use other languages for backend services

## Frontend

- **Package manager:** npm
- **Language:** TypeScript with strict mode enabled
- All frontend code must be type-safe
- `tsconfig.json` must include `"strict": true`
- Never use `eval()`, `Function()` constructor, or any dynamic code execution

## Infrastructure as Code

- **Tool:** AWS CDK only
- **Language:** TypeScript only for CDK
- Do not use other languages for CDK

---

## Dependencies policy

- No new runtime dependencies without approval.
- Prefer the standard library / framework-native features over third-party
  packages when the gap is small.
- Pin versions in lockfiles; do not rely on floating ranges in production.
- Declare dependencies in the file the build system expects — see
  `@agents/context/build-system.md`. Never install a package by hand.

## Tooling and commands

Build, format, lint, type-check, and test commands are **not** listed here.
This project uses a proprietary build system (Icarus Builder) rather than
standard Python tooling, and it owns the interpreter, the dependencies, and
the tool configuration.

Load `@agents/context/build-system.md` for every build, test, or
verification command.
