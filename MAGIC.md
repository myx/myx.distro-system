# MAGIC.md — myx.distro-system

Team-owned notes for the magic-* team. Durable facts this package's `README.md`, `docs/` pages and help files do not state. Read `README.md` and `docs/` for structure, and each tool's own `sh-lib/help/Help.<Tool>.help.md` for its call contract.

## Goal and where things live

- The shared kernel of the family. Source, deploy and agents read its index; `.local` and remote do not (see "`*Context.include`" below). It carries no pipeline builders and no `Distro*Console.sh` of its own. `DistroLocalTools.fn.sh` installs it together with source or deploy.
- `sh-lib/SystemContext.include` defines `Require`, `Action`, `Distro` and `DistroSystemContext`. `sh-lib/SystemContext.SetInputSpec.include` picks the input tier.
- `sh-lib/system-context/` is the index engine: the `IndexCacheMiss*`, `IndexNoCache*` includes and the two awk builders.
- `sh-lib/DistroImage.SyncScriptMaker.include` builds the `DistroImageSync` scripts.
- `java/` and `bin/` hold the Java commands behind `DistroSourceCommand.fn.sh` and `DistroImageCommand.fn.sh`.
- `sh-lib/help/` holds the manuals. [Formats](docs/formats.md) says which file is the authority.

## Calling a tool

- The call forms, `Require` and `Action`, and the reasons for `command not found`: [Commands](docs/commands.md) and [Troubleshooting](docs/troubleshooting.md). How a tool file is built: [Extension](docs/extension.md).
- After editing a tool's own source, call `<Tool>.fn.sh`. The `Distro <Tool>` form reuses the function already loaded into the session and reports nothing to say it ignored the edit.
- Internal calls use `type <FunctionName> >/dev/null 2>&1 || . "$( myx.common which lib/<name> )"`. This stays OS-aware, unlike `myx.common`'s own internal convention, which hardcodes `.Common`.

## `Distro <name>` fails outside a console

- `Distro`'s lookup only tries `type`, then `command -v <name>.fn.sh` on `PATH`. Unlike `Require`, it does not search the package list itself. User-facing symptom: [Troubleshooting](docs/troubleshooting.md).
- `Distro()` is defined at `sh-lib/SystemContext.include:72-99`, and for a non-`--` first argument it checks `type` then sources `<cmd>.fn.sh` from `PATH`. It resolves through `PATH`, never through `MDLT_ORIGIN`.
- **A call site that must work outside a console takes the standard `*.fn.sh` bootstrap plus `Require <Tool> || :`.** That is the supported way to reach a tool without the console's own `PATH`.
- **`ListDistroDeclares()` runs `set -e` internally and leaves it on when it returns 0**, so a bare in-process call leaks `set -e` into the caller. `var="$( … )" || status=$?` contains it inside the substitution subshell, which still inherits the exported `MDSC_CACHED`, so caching is not affected by containing it.

## `JumpTo.fn.sh` writes `MDSC_INT_CD` into a channel that does not carry it

- `JumpTo` is the only writer of `MDSC_INT_CD` — three consecutive statements, a `declare -x`, a plain assignment and an `export`. Its only reader is the `--shell-prompt` arm of `SourceConsole.include`/`DeployConsole.include`, which runs two subshells below the interactive shell and cannot apply what it reads.
- **This is the writer's end of that defect and not the same claim as the consumer's end.** The two pointers in `myx.distro-source`/`myx.distro-deploy` describe a hook that cannot apply a value; this one describes a value written into a channel that does not carry it. A reader arriving from either side needs the other half.
- Run as a script, the tool changes its own process and exports into it, so neither the working directory nor the variable reaches the caller.
- **Open:** whether the `cd` at the end of the `JumpTo` function body moves a console that called it as a function. A bare harness cannot settle it — `JumpTo` calls `Distro ListDistroProjects` internally, which is the case "`Distro <name>` fails outside a console" above describes — so it takes a real console session.
- The consumer's end: `myx.distro-.local/MAGIC.md`, "The prompt hook announces a change it cannot apply".

## Which layer to reach for

**Which layer to reach for is decided by the caller, not by which is better.** An action exists so a person, or a task-menu binding, can fire a prepared parameter set without assembling one; when that is the caller, running the existing action directly beats re-deriving the equivalent `sh-scripts` invocation. A member doing the work calls the building block instead, because the work requires knowing which tool ran and with which parameters, and an action hides both.

## Finding a tool's manual

- Where a manual lives, and why the `.help.md` is the authority: [Formats](docs/formats.md).
- Read the manual file rather than running `--help`, and read it before choosing a tool.

## Help-file inconsistencies — confirmed, not resolved

Follow the standard form for new or edited help. When touching one of these, ask first: do not silently "fix" it, and do not copy the divergent pattern elsewhere.

- Standard `.include` echoes `📘 syntax: ...` lines and, on `--help`, calls `myx.common lib/catMarkdown` on the `.help.md`. These echo Options and Examples as raw `echo` instead: every `Help.ListDistro*.include` in this package **except** `Help.ListDistroScripts.include`, which is standard.
- In `ListDistroDeclares` that duplicate is out of step with its own `.help.md`, listing different options.
- `--help` vs `--help-syntax` wiring differs per command — inline in the function body, or only in the outer `case "$0"` dispatcher, or `JumpTo`'s own split behaviour.

## `*Context.include`: index consumers and non-consumers

- **The distinction that holds is index consumption.** Consumers — source, deploy, agents — need this package's context and a tier. Non-consumers — `.local` and remote — make zero index reads each and need neither.
- **`myx.distro-system` is the parent; source, deploy, agents, `.local` and remote are siblings.** A child using the parent is not a package reaching sideways. What is forbidden is duplicating a parent capability — **two `Require` implementations in one process** — and putting a per-entry-point decision inside a shared tool.
- **`AgentsContext.SetInputSpec.include` is this package's own file with the tier half removed**: its arms `return 0` where this one falls through into `--distro-path-auto` and the five tier cases. It therefore sets no `MDSC_*` at all, which is why an origin-only call resolves no tier.
- **The two `SetInputSpec` files apply different validity tests to the same origin decision**: the agents one probes for `myx.distro-agents`, this one for `myx.distro-.local` and `myx.distro-system`. Delegating the origin axis answers a different question, not the same one more generally.
- **A guard at the call site tests a proxy for a file's contents and breaks when those contents change.** The house form is the opposite: source unconditionally, and let the file self-guard with a top-of-file quick-exit. An in-file quick-exit can only skip re-definition in a process that already holds the function; it can never prevent the file being reached.
- **A console rc defines its package's command wrappers as shell functions** — `Distro`, `Deploy`, `Source`, `Agents`. A console relying on `PATH` additions for them instead fails wherever that `PATH` is absent, the MCP surface included, which carries no `sh-scripts` on `PATH`.

## `exit` in a sourced include, and where a context failure actually surfaces

- **An include reports failure with `set +e ; return 1`, never `exit`.** `exit` in a sourced file kills the caller's process, so a cold workspace becomes unprobeable: any caller resolving a spec there dies rather than degrading.
- **Converting `exit` to `return` is half a change.** A call site that follows the source with an unconditional `return 0` or `shift` swallows the new failure. Convert the sites and add propagation at each sourcer in the same change, or a fatal failure becomes a silent one.
- **This package's top-level `case "$1"` reaches `SetInputSpec` only when `$1` matches `--distro-*|--run-from-*|--init-*`.** A tail guard sources the file with the *tool's* own first argument, which does not match, so the `.` returns 0 even on a cold workspace and the context failure appears later at the separate `DistroSystemContext` call. Testing the `.` status at those sites catches nothing.
- **Tools source this file without testing what follows.** The uniform pattern is source, call context, proceed into an index read, index read fails, tool returns non-zero — the consumer catches it, not the context call. A known property, not a defect to normalise.
- **What an audit of that pattern looks for**: a tool reading `$MDSC_SOURCE` or `$MDSC_CACHED` directly, without going through an index call, would build a path from an empty variable and could act on it.
- **A named tier overwrites a caller; an auto-detect does not.** `--distro-*` takes the arm setting `adpcChangeSpec="true"` and reassigns unconditionally; `--distro-path-auto` early-returns on both guards and never sets it. The distinction is naming a tier versus resolving one when none was named.
- **A tier belongs at an entry point that knows its situation** — a console bashrc, or named at the call by a surface with no console above it. Never inside a shared tool, which cannot know.

## Dependency and index engine

- **A consumer reads an index in-process, through `DistroSystemContext --index-*`. It does not spawn `ListDistroProjects.fn.sh` or `ListDistroDeclares.fn.sh` by path.** The index is held in environment variables — `MDSC_IDAPRJ`, `MDSC_IDODCL` and their siblings, named at `sh-lib/SystemContext.include:144-148` — so a spawned process starts cold and rebuilds every index it touches, reporting `--index-* no caching` from `sh-lib/system-context/IndexCacheMissDistro.include:88`. Filter by passing the caller's own awk to the same call (`myx.distro-source/sh-scripts/ListProjectSequence.fn.sh:47`, `ListProjectDependants.fn.sh:59`); intersect a selection with `--intersect-index-*` and the variable name. Cross-tool, the in-process form is `Distro <Tool>`: `sh-scripts/ListDistroDeclares.fn.sh:34` calls `Distro ListDistroProjects --select-execute-default ListDistroDeclares "$@"`, with `Distro()` at `sh-lib/SystemContext.include:72`. Both tools define shell functions (`ListDistroDeclares.fn.sh:10`, `ListDistroProjects.fn.sh:10`), and `ListDistroDeclares` reads the index in-process at its own lines 55 and 65.
- **`--index-*` takes no workspace argument and cannot be pointed at another workspace.** It gates purely on the calling process's own `${!env}` and `$MDSC_CACHED` (`sh-lib/SystemContext.include:137-176`). To read another workspace, launch in or from that workspace, where the index is native.
- **A spawned child loses the context whenever the workspace does not vendor its own `myx.distro-*` copy.** `sh-lib/SystemContext.include:6-17` resets `MDSC_CACHED`, `MDSC_SOURCE` and `MDSC_OUTPUT` in any child whose `MDLT_ORIGIN` is not under its own `$MMDAPP/`. This holds whatever `MMDAPP` is set to, which is why spawning loses caching and no environment fiddling recovers it.
- **The index environment does not survive a workspace switch on its own.** `MDSC_ID*` and `MDSC_MEMORY` cross an `exec`, and the short-circuit below matches `[ -f "${!env}" ]` before any `MDSC_CACHED` test, so a switched process can serve the previous workspace's index silently. Clear them as variables at the switch: `${!MDSC_ID*}` prefix expansion covers future variables without duplicating the canonical list, and the five spec variables are named explicitly because a prefix wide enough for them would also catch `MDSC_DETAIL`, `MDSC_CMD` and `MDSC_SELECT_PROJECTS`.
- **`--no-cache` and `--no-index` gate different caches**, and only both together reach the shell build. A control using one alone does not discriminate.
- **Index environment variables**, by index name: `projects`→`MDSC_IDAPRJ`, `declares`→`MDSC_IDODCL`, `declares-merged`→`MDSC_IDMDCL`, `keywords`→`MDSC_IDOKWD`, `keywords-merged`→`MDSC_IDMKWD`, `provides`→`MDSC_IDOPRV`, `provides-merged`→`MDSC_IDMPRV`, `requires`→`MDSC_IDOREQ`, `sequence`→`MDSC_IDASEQ`, `sequence-joined`→`MDSC_IDBSEQ`. `sh-lib/SystemContext.include:155-159` short-circuits on `[ -f "${!env}" ]` before any `MDSC_CACHED` test, and `IndexCacheMissDistro.include` sets them with an unconditional `eval export` into the shared process environment.
- **A spec is the read context for a stage's ingest; a stage runner then exports the build environment for its own builders.** Two mechanisms, not one — a builder asserting a cache root the spec enum does not supply is not a gap in the enum.
- **The no-cache / no-index path is builder-only.** It exists so the cache builder does not recurse into itself. A non-builder caller reaching it is a bug to fix, never a configuration to choose.
- **`--distro-path-auto` can select a spec whose `MDSC_CACHED` directory does not exist** — `--distro-from-cached` resolves to `.local/output-cache/prepared` and `--distro-from-output` to `.local/output-cache/distro`, neither necessarily present, while the populated `.local/system-index` is reachable only from `--distro-from-source`. Residual cache misses are then a property of input-spec detection rather than of the call form. Open for the human-owner to settle; do not design around it.
- **A cache entry is published only when its generator reported success, and the generator's own status is what is read.** Three ways lose that status, and each reports a clean read of an empty index: the generator sourced plainly, where its own `set +e ; return 1` disarms the caller so execution runs straight on to the `mv` that installs the empty output; the generator on the left of a `| tee`, where the status read belongs to `tee`; and a sourcing site that follows the `.` with an unconditional `return 0`. An empty entry, once published, keeps answering on the default path after its cause is gone, while `--no-cache` answers correctly. The generator therefore runs as a **tested subshell** — `if ! ( . "$gen" ) >"$tmp"`, which its own first-line `set -e` re-arms — the temp is removed on failure so any existing entry survives, and every layer propagates.
- **`IndexNoCache*Owned.include`'s index build is tested for the same reason**, one layer below: an unavailable project list makes `BuildSingleIndex.awk` emit an index over no projects, which installs clean and empty and then answers every later query.
- **The freshness test that then serves such a file is a separate, still-open matter** — `sh-lib/SystemContext.include:163-165` and `:346-348` join three conditions with OR, so the weakest satisfied one decides. Open for the human-owner; do not fold it into an unrelated change.
- **Only `MDSC_DETAIL=full` is a valid measurement run.** The gating is asymmetric: `no caching` (`sh-lib/system-context/IndexCacheMissDistro.include:88`) fires on any non-empty value, while `using env-cached file` (`sh-lib/SystemContext.include:156`) and `using cached` (`:167`) fire only on the literal `full`. At any other value the misses drop to zero while both positive controls silently read zero too, which is indistinguishable from success.
- `sh-lib/system-context/BuildSequencesFromProvidesAndRequires.awk` topologically sorts the whole `Requires`/`Provides` graph **once** into a flattened sequence file. The view axes and the merged-view join are in [Formats](docs/formats.md).
- Raw index data falls back in three steps: the cached flat file `$MDSC_CACHED/distro-index.env.inf` (`PRJ-<KEY>-<project>=v1:v2`, rebuilt by `BuildSingleIndex.awk` only when stale), else the legacy Java path (`Distro DistroSourceCommand --import-from-source ...`), else an in-shell awk build cached in `$MDSC_MEMORY` for the session.
- **The Java path is legacy fallback only.** It may need a patch to stay in sync, but reason about design from the shell implementation, never from the Java.
- **`BuildSingleIndex.awk` accumulates every provider of a name and appends all of them to the requiring project's requires list.** No first-wins, no selection, no error. Its only stderr output is `⛔ MISSING`, in the `provider_count == 0` branch, so two providers of one name take the success path silently.
- **The resolver never warns; the user-side check is in [Troubleshooting](docs/troubleshooting.md).** `--distro-source-only` is the named spelling for the `--no-cache --no-index` intent — its own case arm at `sh-lib/SystemContext.SetInputSpec.include:133` carries the comment `# --no-cache --no-index` — but the two are not established as interchangeable: `sh-lib/help/Help.ListDistroSequence.include:21` passes all three together, which equivalence would make redundant. Pass the pair explicitly unless you have read the arm.
- **A name with two providers is a question, not a defect.** `os.any` is provided by all three of `os-myx.common-freebsd`, `os-myx.common-macosx` and `os-myx.common-ubuntu` and required by no project — a deliberate any-OS selector. Ask what each repeated name is for; zero duplicates is not the correct state to assert.
- The source-only `--all-provides` recipes sit in `sh-lib/help/Help.ListDistroProvides.include` and not in `Help.ListDistroProvides.help.md`, which is the authority — one of the drifted `.include` copies "Help-file inconsistencies" already names. A reader checking the authority alone does not find the flags.

## DistroImageSync is direction, not a spec

- `DistroImageSync` lives in this package, not `myx.distro-source`, because it is the generic sync engine shared across stages: its case already spans all five of `source-prepare-pull`, `source-process-push`, `image-prepare-pull`, `image-process-push`, `image-install-pull`. `DistroImagePrepare` stays in `-source` as stage-3-specific build orchestration.
- The stated longer-term direction is a goal to stay aligned with, **not a committed design and not a flag spec** — nothing in it is literal. It may grow to represent any sync method a stage or subsystem needs, beyond the current git clone/pull mechanism (`myx.common`'s `git/clonePull`, invoked from `DistroImage.SyncScriptMaker.include`); it may take on bootstrapping the subsystems themselves as prebuilt bundles, distinct from what `-.local` does at install time; and it may handle other prebuilt or exported artifacts of the kind `DistroImagePublish`/`DistroImageDownload` are meant to produce and consume. Both of those remain unimplemented — no file for either exists.
- Do not treat this as scope to implement against, or as licence to expand the `docs/commands.md` entry into a spec.
