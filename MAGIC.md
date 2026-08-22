# MAGIC.md — myx.distro-system

Team-owned notes for the magic-* team. Durable facts this package's `README.md` and help files do not state. Read `README.md` for structure, and each tool's own `sh-lib/help/Help.<Tool>.help.md` for its call contract.

## Calling a tool

- `sh-scripts/*.fn.sh` are the tools. Every other script in the package is a wrapper over them.
- Call a tool by its full name, `.fn.sh` suffix included. Inside a console session the tool resolves on `PATH`.
- Two call forms:
  - `Distro <Tool>` — checks whether that function is already defined; only when it is not, resolves `<Tool>.fn.sh` on `PATH` and sources it; then calls the function. Heavier on the first call, cheaper on every call after it.
  - `<Tool>.fn.sh` — executes the file every time.
- After editing a tool's own source, call `<Tool>.fn.sh`. The `Distro <Tool>` form reuses the function already loaded into the session and reports nothing to say it ignored the edit.
- `Require <name>` searches the package `sh-scripts/` directories in a fixed order and only sources; it does not call.
- A bare name resolves exactly when the tool lives in an installed package's own `sh-scripts/`. A command kept in a project tree is called by full path.

## Which layer to reach for

**Which layer to reach for is decided by the caller, not by which is better.** An action exists so a person, or a task-menu binding, can fire a prepared parameter set without assembling one; when that is the caller, running the existing action directly beats re-deriving the equivalent `sh-scripts` invocation. A member doing the work calls the building block instead, because the work requires knowing which tool ran and with which parameters, and an action hides both.

## Finding a tool's manual

- A tool's manual sits at a deterministic path beside it: `sh-lib/help/Help.<Tool>.help.md`.
- Read that file rather than running `--help`. The manual is already on disk.
- Read it before choosing a tool.
