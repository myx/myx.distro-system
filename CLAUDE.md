# Shell command conventions (myx.distro-* subsystems)

Applies to: myx.distro-.local, myx.distro-deploy, myx.distro-source, myx.distro-system, myx.distro-remote.

## Layout

- `sh-scripts/<Name>.fn.sh` — entry point. Defines function `<Name>`, ends with
  `case "$0" in */sh-scripts/<Name>.fn.sh) ... esac` dispatch trailer.
- `sh-lib/help/Help.<Name>.help.md` — help content.
- `sh-lib/help/Help.<Name>.include` — sourced for `--help`/`--help-syntax`.

## Standard `Help.<Name>.include`

```
echo "📘 syntax: <Name>.fn.sh ..." >&2   # one line per calling form
if [ "$1" = "--help" ]; then
	myx.common lib/catMarkdown "$MDLT_ORIGIN/.../Help.<Name>.help.md" >&2
fi
```

## Standard `Help.<Name>.help.md`

```
📘 syntax: ...

##  Summary:
##  Arguments:
##  Options:
##  Examples:
```
Optional: `##  Notes:`, `##  Environment Variables:`.
Header format: `##` + two spaces + title + `:`. Body indented with a tab.
Examples: `# comment` line, then command in backticks.

## `Man.<Topic>.help.md`

Free-form reference doc (file formats, install guides). No fixed sections,
not paired with a `.include`/`.fn.sh`. Different genre from `Help.*`.

## Known inconsistencies — confirmed, not resolved

- Some `Help.<Name>.include` files (all `List*` in myx.distro-system;
  `ListSshTargets` in deploy; `DistroImageSync`, `ListProjectSequence`,
  `DistroSourceConsole` in source) duplicate Options/Examples as raw `echo`
  instead of calling `catMarkdown` on the paired `.help.md`. In
  `ListDistroDeclares` the duplicated text has already drifted from its own
  `.help.md` (different option names listed).
- `--help` vs `--help-syntax` wiring differs between commands: some source
  the `.include` inline inside the function body for both flags
  (`BuildCachedFromSource`); some only in the outer `case "$0"` dispatcher
  (`ShellTo`); `JumpTo` inlines raw echo for `--help-syntax` and only sources
  `.include` for full `--help`.
- `myx.distro-remote/sh-lib/Help.DistroRemoteTools.help.md` (sh-lib root) is
  a stale orphaned duplicate of `sh-lib/help/Help.DistroRemoteTools.help.md`.
  Content has diverged; only the `help/` copy is referenced by code.

## Rule

Follow the standard form for new/edited command help. If touching one of the
flagged exceptions, ask first — don't silently "fix" it to match the
standard, and don't copy a divergent pattern elsewhere.

## Architecture

Repo roles (from each `project.inf` `Title:`):

- `myx.distro-system` — "Common (distro-deploy & distro-source) tools": the
  shared kernel. Defines `Distro`, `Require`, `Action`, `DistroSystemContext`
  in `SystemContext.include`, sourced by nearly every `.fn.sh` here.
- `myx.distro-source` — "Distro builder package, prepare distro indices."
- `myx.distro-deploy` — "Basic distro package management tools." Requires
  `myx/myx.distro-source`.
- `myx.distro-remote` — "Tools for working with myx.distro on remote host."
- `myx.distro-.local` — "Common (distro-*) tools installer": bootstraps a
  fresh workspace and installs the other subsystems into it.

### Dispatchers (`SystemContext.include`)

- `Distro <CommandName> [args]` — resolves `<CommandName>` to a shell
  function; if not already loaded, sources `<CommandName>.fn.sh` from PATH,
  then calls it. Empty/`--*` first arg instead sources `SystemConsole.include`
  (interactive console). This is what `Distro ListSshTargets ...` etc. run.
- `Require <name>` — same lookup, but searches
  `myx.distro-{system,source,deploy,remote,.local}/sh-scripts/<name>.fn.sh`
  in that fixed priority order and only sources the definition (doesn't call
  it).
- `Action <name>` — unrelated third dispatcher: runs `$MMDAPP/actions/<name>`
  (`.sh` executed, `.url` opened). Separate from Distro commands.

### Requires/Provides/Declares dependency model

Each `project.inf` declares `Requires`/`Provides`/`Declares`/`Keywords`.
`myx.distro-system/sh-lib/system-context/BuildSequencesFromProvidesAndRequires.awk`
topologically sorts the whole project graph once into a flattened
**sequence** file (`<project> <transitively-required-project>` lines, deps
before the project itself; cycle-safe via an "unflushed" counter). Every
"merged" view (e.g. `ListDistroDeclares --merge-sequence`) is then just that
sequence file joined against a raw per-project index
(`IndexNoCacheDistroMerged.include`) — not a live graph walk per call.

Two independent axes for index includes (`system-context/IndexNoCache*.include`):

- **Owned vs Merged**: Owned = a project's own declared values only, no
  inheritance. Merged = owned values plus everything inherited transitively
  through `Requires`, via the sequence-file join above.
- **Distro vs Project scope**: Distro = across all projects at once (bulk).
  Project = scoped to one named project (`$MDSC_PRJ_NAME`).

Raw index data has a fallback ladder: (1) cached flat file
`$MDSC_CACHED/distro-index.env.inf` (`PRJ-<KEY>-<project>=v1:v2`, rebuilt via
`BuildSingleIndex.awk` only when stale), else (2) a **legacy Java** path
(`Distro DistroSourceCommand --import-from-source ...`), else (3) an in-shell
awk build cached in `$MDSC_MEMORY` for the session. The Java path is a
fallback only — sometimes needs a patch to stay in sync, but the canonical
design is the pure-shell (awk/bash) implementation; reason from that, not
from the Java side.

### Pipeline (from `myx.distro-deploy/README.md`)

Numbered stages, source stages 1-2 then image stages 3-5:

```
1xxx  source-prepare  source -> cached   (mode: source, stage: prepare)
2xxx  source-process  cached -> output   (mode: source, stage: process)
3xxx  image-prepare   output -> distro   (mode: image, prepare | util)
4xxx  image-process   distro -> deploy   (mode: image, process | util)
5xxx  image-install   distro -> deploy   (mode: image, install | util)
```

Builders live at `<repo>/builders/<stage-name>/<NNNN>-<name>.sh` (e.g.
`myx.distro-source/builders/source-prepare/1000-env-from-source.sh`).

`MDSC_SOURCE`/`MDSC_CACHED`/`MDSC_OUTPUT` are **stage-scoped**, not fixed
constants — each stage script reassigns them to point at that stage's own
input/output dirs:

- Stage 1 (`BuildCachedFromSource`): `MDSC_CACHED=.local/source-cache/prepare`
- Stage 2 (`BuildOutputFromCached`): `MDSC_CACHED=.local/output-cache/prepared`,
  `MDSC_OUTPUT=.local/output-cache`
- Outside an active build stage (ad-hoc commands, e.g. `ListDistroDeclares`,
  or `DistroSourceCommand`'s default): `MDSC_CACHED` defaults to
  `.local/system-index` — the "published" steady-state index that
  `DistroSourcePrepare`/`DistroSourceProcess`/`DistroImagePrepare` write to
  when they finish. This is the value most day-to-day commands see.

Exactly three generated roots under `.local/` (confirmed by
`CleanAllOutputs.fn.sh`): `source-cache`, `output-cache`, `system-index`.

Builder discovery (`ScanSourceBuilders.include`, used by `AllBuilders.fn.sh`)
is not limited to the 4 core repos with builders — **any project** in the
distro index may declare its own `builders/<stage>/<NNNN>-*.sh` and it will
be picked up automatically. `myx.distro-.local` intentionally has no
`builders/` dir — it's boot/install tooling only, not part of the pipeline.
Only `myx.distro-source` and `myx.distro-deploy` currently have shell-side
builders; `myx.distro-system`/`myx.distro-remote` don't (kernel/tooling
roles, not pipeline stages).

**Reserved:** `source-publish` (`*/source-publish/3???-*.sh`) is a reserved,
not-yet-implemented stage name at the same numeric position as
`image-prepare` — it belongs to the end of the -source pipeline: publishing
built artifacts so -deploy can consume them. `ScanSourceBuilders.include`'s
discovery glob already matches it, but no stage runner invokes it yet (stage
3 always runs via `BuildDistroFromSource.fn.sh → AllBuilders --executables
image-prepare`, and `AllBuilders.fn.sh`'s stage filter doesn't accept
`source-publish` as a value either). Don't remove or repurpose it.
