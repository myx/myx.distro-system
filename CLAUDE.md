# myx.distro-* — AI assistant context

Applies to: myx.distro-.local, myx.distro-deploy, myx.distro-source, myx.distro-system, myx.distro-remote.

Canonical human docs (don't restate here, read them instead):
- Each repo's `README.md` — pipeline stages, folders, variables, `project.inf` properties.
- `myx.distro-.local/sh-lib/help/Man.Project.Inf.file.help.md` — `project.inf` file-format grammar.

This file is reasoning aid + flagged issues, not a rewrite of those docs.

## Repo roles

- `myx.distro-system` — shared kernel (`Distro`/`Require`/`Action`/`DistroSystemContext` in `SystemContext.include`), used by nearly every `.fn.sh`.
- `myx.distro-source` — builds distro indices from source.
- `myx.distro-deploy` — package management/deploy tooling. Requires `myx/myx.distro-source`.
- `myx.distro-remote` — remote-host tooling.
- `myx.distro-.local` — bootstraps a fresh workspace, installs the other subsystems. No pipeline builders (boot-only).

Only `myx.distro-source` and `myx.distro-deploy` have shell-side pipeline builders; `-system`/`-remote` don't (kernel/tooling roles).

## Command layout & help conventions

- `sh-scripts/<Name>.fn.sh` — entry point. Defines function `<Name>`, ends with `case "$0" in */sh-scripts/<Name>.fn.sh) ... esac`.
- `sh-lib/help/Help.<Name>.help.md` + `sh-lib/help/Help.<Name>.include` — help pair. Standard `.include` echoes `📘 syntax: ...` lines and, on `--help`, calls `myx.common lib/catMarkdown` on the `.help.md`. Standard `.help.md` sections: `##  Summary:`, `##  Arguments:`, `##  Options:`, `##  Examples:` (optionally `Notes:`/`Environment Variables:`), tab-indented body, examples as `# comment` + backtick command.
- `Man.<Topic>.help.md` — free-form reference doc (file formats, install guides), not paired with `.include`/`.fn.sh`. Different genre from `Help.*`.

Known inconsistencies — confirmed, not resolved, ask before touching:
- Some `Help.<Name>.include` (all `List*` in myx.distro-system; `ListSshTargets` in deploy; `DistroImageSync`/`ListProjectSequence`/`DistroSourceConsole` in source) duplicate Options/Examples as raw `echo` instead of calling `catMarkdown`. In `ListDistroDeclares` this duplicate has already drifted from its own `.help.md` (different options listed).
- `--help` vs `--help-syntax` wiring differs per command (inline in function body vs. only in the outer `case "$0"` dispatcher vs. `JumpTo`'s split behavior).
- `myx.distro-remote/sh-lib/Help.DistroRemoteTools.help.md` (sh-lib root) is a stale orphaned duplicate of `sh-lib/help/Help.DistroRemoteTools.help.md`; only the `help/` copy is referenced by code.

Rule: follow the standard form for new/edited help. If touching a flagged exception, ask first — don't silently "fix" it or copy the divergent pattern elsewhere.

## Dispatchers (`SystemContext.include`)

- `Distro <CommandName> [args]` — resolves to a shell function, sourcing `<CommandName>.fn.sh` from PATH if needed, then calls it. Empty/`--*` first arg sources `SystemConsole.include` instead (interactive console).
- `Require <name>` — same lookup, searches `myx.distro-{system,source,deploy,remote,.local}/sh-scripts/<name>.fn.sh` in that fixed order, only sources (doesn't call).
- `Action <name>` — unrelated third dispatcher: runs `$MMDAPP/actions/<name>` (`.sh` executed, `.url` opened).

## Dependency/index engine

`BuildSequencesFromProvidesAndRequires.awk` topologically sorts the whole `Requires`/`Provides` project graph once into a flattened **sequence** file (`<project> <transitively-required-project>` lines, deps before the project; cycle-safe via an "unflushed" counter). Every "merged" view is that sequence joined against a raw per-project index (`IndexNoCacheDistroMerged.include`) — not a live graph walk per call.

Two independent axes in `system-context/IndexNoCache*.include`:
- **Owned vs Merged**: Owned = a project's own declared values only. Merged = owned + everything inherited transitively via the sequence join.
- **Distro vs Project scope**: Distro = all projects at once. Project = one named project (`$MDSC_PRJ_NAME`).

Raw index data fallback ladder: (1) cached flat file `$MDSC_CACHED/distro-index.env.inf` (`PRJ-<KEY>-<project>=v1:v2`, rebuilt via `BuildSingleIndex.awk` only when stale), else (2) legacy Java path (`Distro DistroSourceCommand --import-from-source ...`), else (3) in-shell awk build cached in `$MDSC_MEMORY` for the session. **The Java path is fallback/legacy only** — may need a patch to stay in sync, but reason about design from the shell (awk/bash) implementation, not from Java.

## Pipeline implementation notes

(Stage table, folders, and variable meanings are in each repo's README.md — this is what the README doesn't say.)

`MDSC_SOURCE`/`MDSC_CACHED`/`MDSC_OUTPUT` are **stage-scoped**, reassigned by each stage script to its own input/output dirs — not fixed constants:
- Stage 1 (`BuildCachedFromSource`): `MDSC_CACHED=.local/source-cache/prepare`
- Stage 2 (`BuildOutputFromCached`): `MDSC_CACHED=.local/output-cache/prepared`, `MDSC_OUTPUT=.local/output-cache`
- Outside an active stage (ad-hoc commands): `MDSC_CACHED` defaults to `.local/system-index`, the published steady-state index — what most day-to-day commands see.

Builder discovery (`ScanSourceBuilders.include`) isn't limited to the core repos — any project in the distro index may declare its own `builders/<stage>/<NNNN>-*.sh` and it's picked up automatically.

`source-publish` (reserved stage-3 alt name, see README) is matched by the discovery glob but not wired to any runner yet: stage 3 always runs via `BuildDistroFromSource.fn.sh → AllBuilders --executables image-prepare`, and `AllBuilders.fn.sh`'s own stage filter doesn't accept `source-publish` as a value either. Don't remove or repurpose it.
