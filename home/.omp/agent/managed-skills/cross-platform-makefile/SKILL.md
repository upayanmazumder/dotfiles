---
name: cross-platform-makefile
description: "Write or debug a GNU Makefile that has to run on Linux, macOS and Windows (cmd.exe/PowerShell/MSYS) without a second build script"
---

# Cross-platform Makefile (Linux, macOS, Windows)

Applies when a repo needs one `Makefile` that runs unchanged under `sh`, `cmd.exe`, PowerShell and MSYS `make`.

## Platform block

```make
ifeq ($(OS),Windows_NT)
  PLATFORM    := windows
  PYTHON      ?= python
  ECHO_BLANK  := echo.
  VENV_BIN     = $(VENV)/Scripts
  VENV_PY      = $(VENV_BIN)/python.exe
else
  PLATFORM    := posix
  PYTHON      ?= $(shell command -v python3 2>/dev/null || command -v python 2>/dev/null || echo python3)
  ECHO_BLANK  := echo
  VENV_BIN     = $(VENV)/bin
  VENV_PY      = $(VENV_BIN)/python
endif
```

`VENV_BIN`/`VENV_PY` must be **recursive (`=`)** if `VENV ?= .venv` is defined further down: a `:=` there expands before `VENV` is set and yields `/bin/python`.

## Recipe rules

- No shell builtins: no `rm`, `mkdir`, `touch`, `cp`, no `ls` globbing. Use `$(PYTHON) -c "import pathlib, shutil; ..."` on the *system* interpreter for file work (the venv may not exist yet).
- No `%` anywhere in a recipe: cmd.exe expands `%name%` and silently eats unmatched pairs, corrupting things like `'%d' % n`. Use `'{}'.format(n)`.
- Safe inside a double-quoted `python -c "..."` argument on both shells: `<`, `>`, `[]`, `()`.
- One shell per recipe line; chain with `&&` (works in cmd and sh) instead of `\` continuations.
- Quote-free `@echo` lines get executed by make without a shell, which **collapses runs of whitespace** — never align help output with echo. Use `define HELP_TEXT` + `@$(info $(HELP_TEXT))`, and add a final `@$(ECHO_BLANK)` so make does not report "Nothing to be done".
- Stamp file targets (`$(VENV)/pyvenv.cfg`, `$(VENV)/.deps-installed`) make venv/dependency steps idempotent; touch them through python so no shell builtin is needed.
- Expose `PYTHON=`, `VENV=`, scenario/test argument overrides; command-line variables beat `?=`, so `make setup PYTHON="py -3.12"` just works.
- Validate the interpreter in a phony target that always runs, and fail with a message naming the override.
- Add a `.PHONY` entry per target and `.DEFAULT_GOAL := help`.

## Windows-side notes

- GNU Make on Windows is `winget install GnuWin32.Make` or `choco install make`; make always shells out there, so cmd semantics apply even when the user is in PowerShell.
- Forward slashes in `.venv/Scripts/python.exe` work fine as a command on Windows.

## Verify before claiming it works

- `make help`, `make -n <target>` per target to inspect the expanded commands.
- Grep recipe lines for forbidden characters: a python one-liner over lines starting with a tab, testing for `%&|<>^`.
- Dry-run the Windows branch by forcing `make OS=Windows_NT -n doctor` and confirming every path is `Scripts/python.exe`.
- Actually execute the bootstrap (venv + install) with a real interpreter at least once; on a too-new Python the pinned deps may not resolve, which is itself worth surfacing as a warning.
