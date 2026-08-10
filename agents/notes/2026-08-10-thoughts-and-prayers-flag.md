# Task: `--with-thoughts-and-prayers` flag on the release target

## Context
- Why this change is needed: requested joke/easter-egg flag. Registers as a
  hook that can never fail (earning a `PASS` row in the summary table) and, on
  a failed run, prints a condolence block after the table.
- Links (PR/issue/ticket): none — conversational request.
- Status: **complete**, verified, uncommitted.

## TODO
- [x] Discovery: map `builder.sh` hook cascade, `path.sh` recipes, argparse chain
- [x] Implement: `cli.py` — shared parent parser, flag hidden via `argparse.SUPPRESS`
- [x] Implement: `model.py` — `prayers` in `all_hooks` + `Literal` + field
- [x] Implement: `builder_helper.py` — read flag, add `--release`-only guard
- [x] Implement: `builder_base.sh` — `declare -r -g prayers`, add `echo_prayers`
- [x] Implement: `builder.sh` — both `set_constants` initialisers, `run_prayers`,
      dispatch block, failure count + `echo_prayers` call in `echo_summary`
- [x] Implement: `site-functions/_icarus` — `hook)` and `release)` blocks
- [x] Implement: permanent toggle test in `test/test_application.py`
- [x] Verification: rejection matrix, both verbatim forms, pass + fail paths
- [x] Cleanup: temp test injections reverted; `/tmp` scratch files removed

## Blocked
- None.

## Decisions / Notes
- **Hook, not modifier** — chosen so it earns a summary-table row, which is the
  joke. Costs a larger diff (both `set_constants` initialisers are mandatory).
- **Validation is verbatim-only**, per explicit user instruction: tied to the
  literal `--release` token, not the resulting hook set. The hand-spelled
  release set (`--build --isort --mypy …`) is rejected.
- **`echo_prayers` is a sibling of `echo_help_verbose`, not part of it.**
  `echo_help_verbose` has 13 call sites, none of which is a hook failure, and
  11 of them abort before `echo_summary` — it would miss the common case and
  print without a table. See `agents/memory/2026-08-10.md` for the full reasoning.
- **Failure count lives inside `echo_summary`'s existing table loop.** Counting
  elsewhere (my first attempt) used `running_hooks_name`, which omits the
  `index`/`path` rows — and `path` can fail without aborting, so the count
  could contradict the visible table.
- Risks: none to build correctness. `run_prayers` never touches `exit_code`,
  and the block is gated on `prayers == Y && exit_code != 0`.
- Rollback plan: `git checkout` the 10 touched files; no migrations, no state.

## Verification Results
- Commands run:
  - `icarus builder release --with-thoughts-and-prayers` → green, `prayers PASS`
  - `icarus builder hook --release --with-thoughts-and-prayers` → green
  - same with toggle `SHOULD_PASS = False` → `pytest FAIL`, block, `1 hook(s)`
  - `hook --with-thoughts-and-prayers`, `hook --release --mypy --with-…`,
    `hook --build --isort --mypy --with-…` → all rejected
  - `builder format|test|build|docs --with-…` → rejected by argparse
  - `icarus builder release` (no flag) → green, no `prayers` row
  - `bash -n` on both edited shell scripts; `zsh -n site-functions/_icarus`
- Output/notes:
  - Full release green; `prayers | PASS | 0.032s` present, header reads
    `14 hook(s)`.
  - Randomness: 300 draws → 92/110/98 across the three messages.
  - Confirmed the failure mode of omitting `prayers_execution_time`
    (`printf: invalid number`, exit 1 under `errexit`).
  - First e2e run failed until `pip install .` refreshed `runtime/env` —
    stale-build trap applies to CLI parser changes too.
