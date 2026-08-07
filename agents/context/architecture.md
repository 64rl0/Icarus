# Architecture

High-level system architecture. Fill this in per project. Keep it concise —
this doc is loaded on demand by agents when a change crosses module
boundaries or affects system shape.

---

## Overview

<!-- One paragraph: what this system does and how its pieces fit together. -->

## Components

<!-- List the main components/modules/services and their responsibilities. -->

- **`<name>`** — <responsibility>
- **`<name>`** — <responsibility>

## Data flow

<!-- How data moves through the system. A simple text diagram is fine. -->

```
<client> → <api> → <service> → <datastore>
```

## Boundaries and contracts

<!-- Public APIs, schemas, event contracts that MUST NOT break silently. -->

- `<endpoint / schema>` — consumed by: `<who>`

## Directory layout

<!-- Map of the repo. Keep shallow — one or two levels deep. -->

```
src/
  ...
test/
  ...
```

## Key design decisions

<!-- ADR-style: decision, context, consequences. One bullet per decision. -->

- **<decision>** — <why> / <trade-offs>

## Non-goals / out of scope

<!-- What this system explicitly does NOT do. Prevents scope creep. -->

- ...
