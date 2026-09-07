# MAGIC.md — myx.distro-system

Team-owned notes for the magic-* team. Durable facts this package's `README.md` and help files do not state. Read `README.md` for structure, and each tool's own `sh-lib/help/Help.<Tool>.help.md` for its call contract.

## Calling a tool

- `sh-scripts/*.fn.sh` are the tools. Every other script in the package is a wrapper over them.
- Call a tool by its full name, `.fn.sh` suffix included. Inside a console session the tool resolves on `PATH`.
- Three call forms:
  - `Distro <Tool>` — checks whether that function is already defined; only when it is not, resolves `<Tool>.fn.sh` on `PATH` and sources it; then calls the function. The name is written without the `.fn.sh` suffix. Heavier on the first call, cheaper on every call after it.
  - `<Tool>.fn.sh` — executes the file every time.
  - `<Tool>` — the bare function name, valid only where the environment already holds that definition. A script run through the `execute` operation is where that applies.
- After editing a tool's own source, call `<Tool>.fn.sh`. The `Distro <Tool>` form reuses the function already loaded into the session and reports nothing to say it ignored the edit.
- A `command not found` answers about the call, not about the tool: the form matched none of the three above. Check the form before concluding an operation is missing.
- `Require <name>` resolves against the package `sh-scripts/` directories in the fixed order `system source deploy remote agents .local`, and only sources; it does not call.
- `Action <name>` is an unrelated third dispatcher: it runs `$MMDAPP/actions/<name>`, executing a `.sh` and opening a `.url`.
- A bare name resolves exactly when the tool lives in an installed package's own `sh-scripts/`. A command kept in a project tree is called by full path.
- Internal calls use `type <FunctionName> >/dev/null 2>&1 || . "$( myx.common which lib/<name> )"` — skip re-sourcing when the function is already defined, else resolve and source. This stays OS-aware, unlike `myx.common`'s own internal convention, which hardcodes `.Common`.

## `Distro <name>` fails outside a console

- `Distro`'s lookup only tries `type`, then `command -v <name>.fn.sh` on `PATH`. Unlike `Require`, it does not search the package list itself.
- What makes such a call resolve is the console: each `console-*-bashrc.rc` puts its own package `sh-scripts/` directories on `PATH`. **The lists differ per console** — the deploy console puts `myx.distro-deploy` first, the source console puts `myx.distro-source` first. Read `PATH` rather than assuming what a console exposes.
- Outside a console — plain `bash sh-scripts/Foo.fn.sh` — any `Distro <name>` call to a command not already sourced fails with `unknown command: <name>`. A `.fn.sh` that calls `Distro <other>` internally is therefore not safe to run bare, even though the target file exists.

## Which layer to reach for

**Which layer to reach for is decided by the caller, not by which is better.** An action exists so a person, or a task-menu binding, can fire a prepared parameter set without assembling one; when that is the caller, running the existing action directly beats re-deriving the equivalent `sh-scripts` invocation. A member doing the work calls the building block instead, because the work requires knowing which tool ran and with which parameters, and an action hides both.

## Finding a tool's manual

- A tool's manual sits at a deterministic path beside it: `sh-lib/help/Help.<Tool>.help.md`.
- Read that file rather than running `--help`. The manual is already on disk.
- Read it before choosing a tool.
- The manual is paired with `sh-lib/help/Help.<Tool>.include`. Some `.include` files print their options directly instead of rendering the manual, and those copies can drift from it. The `.help.md` is the authority.
- `Man.<Topic>.help.md` is a free-form reference document — a file format, an install guide — not a tool's manual and not paired with a tool.

## Help-file inconsistencies — confirmed, not resolved

Follow the standard form for new or edited help. When touching one of these, ask first: do not silently "fix" it, and do not copy the divergent pattern elsewhere.

- Standard `.include` echoes `📘 syntax: ...` lines and, on `--help`, calls `myx.common lib/catMarkdown` on the `.help.md`. These echo Options and Examples as raw `echo` instead: every `Help.ListDistro*.include` in this package **except** `Help.ListDistroScripts.include`, which is standard.
- In `ListDistroDeclares` that duplicate is out of step with its own `.help.md`, listing different options.
- `--help` vs `--help-syntax` wiring differs per command — inline in the function body, or only in the outer `case "$0"` dispatcher, or `JumpTo`'s own split behaviour.

## How a tool file is built

- A `sh-scripts/<Name>.fn.sh` file defines a shell function `<Name>`, then ends with a `case "$0" in */sh-scripts/<Name>.fn.sh) ... esac` block that calls it when the file is executed directly.
- That is what makes both call forms work from one file: sourcing it defines the function, executing it runs the function.

## Dependency and index engine

- `sh-lib/system-context/BuildSequencesFromProvidesAndRequires.awk` topologically sorts the whole `Requires`/`Provides` graph **once** into a flattened sequence file — `<project> <transitively-required-project>` lines, dependencies before the project, cycle-safe via an unflushed counter.
- Every "merged" view is that sequence joined against a raw per-project index (`IndexNoCacheDistroMerged.include`). It is not a live graph walk per call.
- Two independent axes across `sh-lib/system-context/IndexNoCache*.include`:
  - **Owned vs Merged** — Owned is a project's own declared values only; Merged adds everything inherited transitively through the sequence join.
  - **Distro vs Project scope** — Distro covers all projects at once; Project covers one named project (`$MDSC_PRJ_NAME`).
- Raw index data falls back in three steps: the cached flat file `$MDSC_CACHED/distro-index.env.inf` (`PRJ-<KEY>-<project>=v1:v2`, rebuilt by `BuildSingleIndex.awk` only when stale), else the legacy Java path (`Distro DistroSourceCommand --import-from-source ...`), else an in-shell awk build cached in `$MDSC_MEMORY` for the session.
- **The Java path is legacy fallback only.** It may need a patch to stay in sync, but reason about design from the shell implementation, never from the Java.
- **`BuildSingleIndex.awk` accumulates every provider of a name and appends all of them to the requiring project's requires list.** No first-wins, no selection, no error. Its only stderr output is `⛔ MISSING`, in the `provider_count == 0` branch, so two providers of one name take the success path silently.
- **The resolver never warns, and the condition is still detectable ahead of time.** `ListDistroProvides.fn.sh --all-provides` emits `<project> <provide-name>` pairs, so a name carried by two projects appears on two lines. Run with `--no-cache --no-index` and it reads source directly, needing no ingest and working before a project has been indexed at all. `--distro-source-only` is the named spelling for that intent — its own case arm at `sh-lib/SystemContext.SetInputSpec.include:133` carries the comment `# --no-cache --no-index` — but the two are not established as interchangeable: `sh-lib/help/Help.ListDistroSequence.include:21` passes all three together, which equivalence would make redundant. Pass the pair explicitly unless you have read the arm.
- **A name with two providers is a question, not a defect.** `os.any` is provided by all three of `os-myx.common-freebsd`, `os-myx.common-macosx` and `os-myx.common-ubuntu` and required by no project — a deliberate any-OS selector. Ask what each repeated name is for; zero duplicates is not the correct state to assert. Measured on `ws-myx-devops` by `keeper-myx` with a positive control, and separately measured as none on `ws-myx.prv-farm`.
- The `--all-provides` recipe sits in `sh-lib/help/Help.ListDistroProvides.include` and not in `Help.ListDistroProvides.help.md`, which "Finding a tool's manual" above makes the authority — one of the drifted `.include` copies "Help-file inconsistencies" already names. A reader checking the authority alone does not find the flags.

## DistroImageSync is direction, not a spec

- `DistroImageSync` lives in this package, not `myx.distro-source`, because it is the generic sync engine shared across stages: its case already spans all five of `source-prepare-pull`, `source-process-push`, `image-prepare-pull`, `image-process-push`, `image-install-pull`. `DistroImagePrepare` stays in `-source` as stage-3-specific build orchestration.
- The stated longer-term direction is a goal to stay aligned with, **not a committed design and not a flag spec** — nothing in it is literal. It may grow to represent any sync method a stage or subsystem needs, beyond the current git clone/pull mechanism (`myx.common`'s `git/clonePull`, invoked from `DistroImage.SyncScriptMaker.include`); it may take on bootstrapping the subsystems themselves as prebuilt bundles, distinct from what `-.local` does at install time; and it may handle other prebuilt or exported artifacts of the kind `DistroImagePublish`/`DistroImageDownload` are meant to produce and consume. Both of those remain unimplemented — no file for either exists.
- Do not treat this as scope to implement against, or as licence to expand the README Commands entry into a spec.
