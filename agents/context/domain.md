# Domain

Domain glossary and business rules. Loaded on demand when a task requires
understanding of product/business concepts.

Keep this file terse. Agents use it to disambiguate terms and respect
invariants — it is not a product spec.

---

## Glossary

<!-- Define the non-obvious terms used in the codebase. One line per term. -->

- **<Term>** — <definition>. <Also known as:> <synonyms>.
- **<Term>** — <definition>.

## Business rules / invariants

<!-- Rules that MUST hold. Violations are bugs. -->

- <Rule>. (Enforced in: `<file/function>`)
- <Rule>.

## Workflows

<!-- High-level user or system workflows, if relevant. -->

- **<Workflow name>** — <steps / states>.

## Known edge cases

<!-- Edge cases that have bitten the team and should be preserved. -->

- <Edge case> — handled in `<location>` because <reason>.

## External systems

<!-- Third-party services, APIs, or teams this project depends on. -->

- **<Service>** — purpose: <...>. Contract: <...>. Owner: <...>.
