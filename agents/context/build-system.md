# Build System

This project is built with **Icarus Builder**, a proprietary build system.
It is not a wrapper around the usual Python workflow — it replaces it.

**Load this file whenever you need to build, format, lint, type-check,
test, run, or install anything.** You cannot verify your work on this
project without it.

---

## The one rule that matters

**Never use standard Python environment tooling.** This project does not
use `venv`, `virtualenv`, `poetry`, `pipenv`, `uv`, `conda`, or a
system/`pyenv` interpreter. Icarus Builder owns the interpreter, the
dependency installation, and every environment variable that makes them
work.

Do NOT run any of these:

```
python -m venv .venv          source .venv/bin/activate
pip install <anything>        pip install -e .
python -m pytest              pytest
black . / isort . / mypy . / flake8 .
```

There is nothing to activate and nothing to install. A bare `pytest` or
`mypy` invocation either fails or silently runs against the wrong
interpreter with none of the project's dependencies importable.

Everything goes through `icarus builder`. To reach the environment
directly, use the `exec-*` commands described below.

---

## The four everyday commands

Run these from the project root or any subdirectory of it — Icarus walks
up the tree looking for `icarus.cfg` to find the project root.

| Command | What it does |
|---|---|
| `icarus builder build` | Creates/re-creates the runtime environment: installs the interpreter, resolves and installs dependencies, builds and installs the package artifacts. |
| `icarus builder format` | Rewrites files in place with the formatters. |
| `icarus builder test` | Runs the test suite (pytest) **against the last built package, not `src/`** — see below. |
| `icarus builder release` | The full pipeline: build + format + lint + type-check + secret scan + tests + docs. |

### You must build before you test

**`icarus builder test` does not see your `src/` edits until you rebuild.**

Tests import the package by name (`import project_name_here`), and that
name resolves to the *built and installed* copy inside the runtimefarm —
not to the working tree. Editing a file under `src/` changes nothing about
what the tests import, so a stale build means you are testing the previous
version of the code. The tests will happily pass or fail for the wrong
reason, which is worse than an error.

So after any change under `src/`:

```bash
icarus builder build && icarus builder test
```

or, equivalently, in one run:

```bash
icarus builder hook --build --pytest
```

`icarus builder release` already builds first, so it is always consistent.

Test-only edits (files under `test/`) do not need a rebuild — pytest reads
those from the working tree.

If a test result contradicts the code you are reading, assume a stale build
before you assume a bug.

### What each one actually runs

`build` — resolves the build-tool dependency graph, downloads and unpacks
the CPython runtime if not cached, builds the symlink farms, builds the
package (`sdist` + `wheel`), checks package health with `twine check`, and
installs the result into the package farm.

`format` — `isort`, `black`, `shfmt`, plus the whitespace hygiene passes:
line-ending normalization to LF, non-breaking-space replacement, trailing
whitespace removal, and end-of-file newline fixing. **This command writes
to your files.**

`test` — `pytest`, against the installed package. Configuration lives in
`[tool.pytest.ini_options]` in `pyproject.toml`. Rebuild first if `src/`
changed.

`release` — `build`, then `isort`, `black`, `flake8`, `mypy`, `shfmt`,
`eolnorm`, `whitespaces`, `trailing`, `eofnewline`, `pytest`, `gitleaks`,
and `sphinx`. This is the gate that must pass before a change is
considered done. Note that it *includes* the formatters, so it will
modify files.

Two more you will occasionally need:

- `icarus builder docs` — generates the Sphinx documentation into
  `docs/html/`. Requires a `docs/` directory.
- `icarus builder clean` — removes the whole build root plus
  `*.egg-info`, `__pycache__`, `.mypy_cache`, `.pytest_cache`, and
  `.DS_Store`. Reach for this only when the environment is genuinely
  broken; the next build has to redo all the dependency installation.

---

## Running commands inside the environment

To run an arbitrary command with the project's interpreter and
dependencies available, pick the farm that matches what you need on the
import path:

```bash
icarus builder exec-dev  <cmd>    # runtime deps + dev deps + this package
icarus builder exec-run  <cmd>    # runtime deps + this package
icarus builder exec-tool <cmd>    # build-tool deps only
```

`exec-dev` is almost always the right choice for development work.

```bash
icarus builder exec-dev "python3 -c 'import project_name_here'"
icarus builder exec-dev "pytest test/test_application.py -k my_case"
icarus builder exec-dev "mypy src/project_name_here/main.py"
```

Two things to get right, both of which produce confusing failures:

**Use `python3`, never `python`.** The interpreter Icarus ships provides
`python3` and `python3.<minor>` (e.g. `python3.14`) only. A bare `python`
either fails or silently hits a system interpreter that has none of this
project's dependencies.

**Quote the whole command as one string whenever it contains a flag.**
Otherwise `-c`, `-k`, `-m` or `--foo` is claimed by Icarus's own parser and
the run fails with `unrecognized arguments`.

Use `exec-dev` for targeted, iterative checks (one test, one file). Use
the top-level `test` / `release` commands for final verification, because
they run the whole configured matrix and produce the pass/fail summary.

---

## Dependencies

Declare dependencies in the right file, then run `icarus builder build`
to reconcile the environment. Never install a package by hand.

| Kind | Where it goes |
|---|---|
| Runtime ("library" / direct) | `[project].dependencies` in `pyproject.toml` |
| Development (tests, formatters, type checker, docs) | `requirements/dev-requirements.txt` |
| Build-time tools | `requirements/tool-requirements.txt` |

`requirements/run-requirements.txt` still exists and is still read, but
it is legacy — new runtime dependencies belong in `pyproject.toml`.

The builder caches a resolved dependency graph per farm and compares it
on each run. When a requirements file changes it reports "Requirements
changed" and reinstalls; when nothing changed it reports "Sync complete".
That means `build` is cheap to re-run and is the correct response to a
dependency edit.

Per `AGENTS.md`, adding a dependency needs discussion first — this
section is about *how*, not *whether*.

---

## Configuration: `icarus.cfg`

`icarus.cfg` at the project root is the build system's manifest, and its
presence is what marks the project root. It defines:

- **package** — name (PascalCase), language, and version (SemVer). The
  version here is the single source of truth; `setup.py` reads it from
  the `ICARUS_PACKAGE_VERSION` environment variable that the builder
  injects at build time. Do not hand-edit a version anywhere else, and
  use `icarus builder hook --bumpver` to change it.
- **build-system** — which system (`icarus-python3`) and the build root
  directory (`build`).
- **icarus-python3** — the list of Python interpreters to build against
  and which one is `python-default` (see below), plus the paths to the
  three requirements files and the Read the Docs output path.
- **ignore** — paths the builder skips when walking the workspace.
  Formatters and linters never see ignored paths.

Treat this file as configuration: per `AGENTS.md`, do not change it
without explicit approval.

### Interpreter versions

Both `python` (the list) and `python-default` accept two forms:

```yaml
icarus-python3:
  - python:
    - '3.14'        # MAJOR.MINOR  → resolves to the latest patch of 3.14
    - '3.13.2'      # MAJOR.MINOR.PATCH → pinned exactly to 3.13.2
  - python-default: '3.14'
```

`MAJOR.MINOR` is resolved by querying python.org for the newest published
patch release of that minor line, so `'3.14'` floats forward as new patches
ship. `MAJOR.MINOR.PATCH` pins. Both must be **quoted strings** — bare
`3.14` is parsed as a float and rejected.

`python-default` must appear verbatim in the `python` list — the strings are
compared as written, so pairing `python-default: '3.14'` with a list entry
of `'3.14.6'` is rejected even though they resolve to the same interpreter.

Two practical notes on the floating form:

- Resolution is a **live network call on every builder invocation**, not
  cached. Offline or with python.org unreachable, a `MAJOR.MINOR` spec
  fails; a fully pinned `MAJOR.MINOR.PATCH` does not need the lookup.
- Because it floats, a new upstream patch release silently changes which
  interpreter the project builds against. Pin the patch when you need
  reproducibility.

`icarus builder path workspace.python-interpreters` prints what the specs
actually resolved to (`python-default` first), e.g. `3.14:3.14.6`.

### Multiple interpreters

When `icarus.cfg` lists more than one Python version, the tool pipeline
runs once per version. The formatters and the whitespace passes, plus
Sphinx, only run for `python-default` — you will see the other versions
explicitly skipped, which is expected, not an error. `flake8`, `mypy`,
`gitleaks`, and `pytest` run for every configured version.

---

## Reading the output

Every builder run ends with a summary table: one row per hook with
`PASS`, `FAIL`, or `WARN`, plus timings and a total. Read that table
first — it tells you exactly which stage failed without scrolling.

The exit code is non-zero if any hook failed.

Artifacts and diagnostics, all under paths that are gitignored:

- **Failed run log** — `.icarus/log/<run_id>.log`. Written for every run
  and **deleted on success**, so a log file existing means that run
  failed. The path is printed in the failure output.
- **HTML report** — `.icarus/report/index.html`, regenerated after every
  run.
- **Build output** — `build/<platform>/`, containing the interpreter
  runtime, the symlink farms, and the `dist/` artifacts.

### Verbose mode

`--verbose` is a top-level flag and must come **before** the command:

```bash
icarus --verbose builder release      # correct
icarus builder --verbose release      # rejected by the parser
```

Failures print a "HELP!" block with the exact verbose re-run command.

### "Icarus builder is already running"

Only one builder can run per project at a time, enforced with a lock at
`.icarus/lock/builder.lock`. If you hit this, another build is genuinely
in flight — wait for it. Do not delete the lock file to get around it.

---

## How it works underneath

Background for the shape of `build/` and why the no-venv rule exists. The
two subsections that follow — writing shebangs and installing a binary
into user space — are practical, so read on if either applies.

Icarus downloads a prebuilt CPython tarball, unpacks it under
`build/<platform>/runtime/CPython/<version>/`, and then constructs
**runtimefarms** under `build/<platform>/env/path/` — trees of symlinks
that compose an interpreter with exactly one dependency set. There is a
farm per dependency graph (`tool`, `run`, `devrun`, `pkg`, and
`*_excluderoot` variants). Running a command "in" a farm means the
builder points `PATH`, `PYTHONHOME`, `PYTHONPATH`, and `PYTHONBIN` at it.

This is why activating a virtualenv or calling a bare `pytest` does not
work: the environment is not a directory you enter, it is a set of
variables the builder computes per farm per interpreter version.

Scripts that need one of these locations should ask for it rather than
hardcoding a path — `icarus builder path workspace.root`,
`icarus builder path pkg.version`, and so on.

### Shebangs: making a script run against the active environment

A script cannot hardcode a path to the interpreter, because which
interpreter it should use depends on the farm the script ends up in. The
build system solves this with `envroot`, and you use it through the
shebang line.

When you need a script or `.py` file to run against the environment it
lives in, address the interpreter relative to `$ENVROOT`:

```python
#!/icarus/bin/envroot "$ENVROOT/bin/python3"
```

`envroot` walks up from the script's own location until it finds the
`.envroot` marker at a farm root, sets `ENVROOT` to that directory, expands
the template, and executes the resolved interpreter with your script. So
the script finds its own environment from its own location — which is why
it keeps working when the farm is rebuilt or moves.

`$ENVROOT/bin/python3` is the one to reach for by default: it is always
present and tracks whatever `python-default` is set to, so nothing needs
updating when the version changes. Pin a specific interpreter only when you
actually need one:

```python
#!/icarus/bin/envroot "$ENVROOT/bin/python3.14"
```

The same works for anything else in the farm, including a binary you put in
user space:

```bash
#!/icarus/bin/envroot "$ENVROOT/bin/some-tool"
```

Three rules that will bite you otherwise:

- **One argument only.** A shebang passes a single argument, so the whole
  template must be one quoted string. `envroot` strips the quotes and does
  the expansion itself — the kernel does not.
- **The path is absolute and literal:** `/icarus/bin/envroot`. Not a
  relative path, not a different prefix.
- **Only hand-write this for scripts the builder does not install.** Every
  pip-installed entry point gets its shebang rewritten automatically. You
  write it yourself for things you dropped into user space.

To run a one-off command in a given environment without writing a shebang
at all, use `icarus builder exec-dev` / `exec-run` / `exec-tool`.

### Installing a binary into user space

Farms are assembled from two sources: the Python runtime and a **user
space** prefix at `build/<platform>/runtime/local/`, which holds
non-Python tools that pip cannot provide (`shfmt` and `gitleaks` are the
common cases). User space is laid out like a normal Unix prefix —
`bin/`, `lib/`, `include/`, `share/`.

To add such a tool, install it into that prefix and then merge:

```bash
# ask where user space lives
icarus builder path workspace.user-space-root

# place the binary under its bin/ (build from source, unpack a release
# tarball, or copy an existing binary)

# link it into the existing farms
icarus builder merge
```

**The `merge` is not optional.** A newly dropped binary is invisible until
you merge — rebuilding does not pick it up. If a tool you just installed is
not found, `merge` is the answer.

`merge` must run alone; it cannot be combined with other hooks.

(`icarus builder clean` followed by a build would also work, since that
recreates the farms from scratch, but it throws away the whole environment
to achieve what `merge` does in seconds.)

---

## Rarely needed

One-liners, for recognition rather than routine use:

- `icarus builder hook --<flag>` — run individual tools directly
  (`--mypy`, `--black`, `--pytest`, `--gitleaks`, …) instead of a
  bundled target. Useful for narrowing down a `release` failure. A few
  flags must be used alone: `--clean`, `--merge`, `--bumpver`, `--pypi`,
  and the `--exec-*` flags.
- `icarus builder hook --bumpver` — interactively bump major/minor/patch
  in `icarus.cfg`.
- `icarus builder hook --pypi` — publishes to TestPyPI and PyPI. This is
  a real publish to a public index. **Never run it unless explicitly
  asked to.**
- `icarus builder hook --readthedocs` — regenerates the Read the Docs
  requirements file.
- `icarus builder cache root|size|clean` — inspect or clear the shared
  on-disk cache of downloaded interpreters.
- `icarus builder merge` — re-links user space into existing farms; see
  "Installing a binary into user space" above.

---

## Looking something up

This file covers what you need for day-to-day work. When you hit a command
or option that is not documented here, get the answer from the tool rather
than guessing:

```bash
icarus builder --help              # every subcommand
icarus builder hook --help         # every individual tool flag
icarus builder path --list         # every path name
```

---

## Definition of done

A change is not verified until `icarus builder release` passes. If you
cannot run it, say so explicitly rather than implying the change was
tested.
