# myx.distro-* — AI assistant context

Applies to: myx.distro-.local, myx.distro-deploy, myx.distro-source, myx.distro-system, myx.distro-remote, myx.distro-agents.

Canonical human docs (don't restate here, read them instead):
- Each repo's `README.md` — pipeline stages, folders, variables, `project.inf` properties.
- `myx.distro-.local/sh-lib/help/Man.Project.Inf.file.help.md` — `project.inf` file-format grammar.

This file is reasoning aid + flagged issues, not a rewrite of those docs.

## Repo roles

- `myx.distro-system` — shared kernel (`Distro`/`Require`/`Action`/`DistroSystemContext` in `SystemContext.include`), used by nearly every `.fn.sh`.
- `myx.distro-source` — builds distro indices from source.
- `myx.distro-deploy` — package management/deploy tooling. Requires `myx/myx.distro-source`.
- `myx.distro-remote` — remote-host tooling.
- `myx.distro-agents` — starts a `claude`/`copilot` CLI console (`DistroAgentsConsole.sh`) instead of a bash session. No pipeline builders (console-launcher role, like `-remote`).
- `myx.distro-.local` — bootstraps a fresh workspace, installs the other subsystems. No pipeline builders (boot-only).

Only `myx.distro-source` and `myx.distro-deploy` have shell-side pipeline builders; `-system`/`-remote`/`-agents` don't (kernel/tooling roles).

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

Recurring internal calling convention: `type <FunctionName> >/dev/null 2>&1 || . "$( myx.common which lib/<name> )"` — skip re-sourcing if the function is already defined in this shell, else resolve and source it. Unlike `myx.common`'s own internal convention (which hardcodes `.Common` and skips OS dispatch — see `myx.common/os-myx.common` CLAUDE.md), this one still calls `myx.common which`, so it stays OS-aware (one subprocess to resolve the path, none to run it) rather than assuming no OS variance.

Bare-script invocation of a `.fn.sh` that itself calls `Distro <other-name> ...` can fail even though the target file exists:
- `Distro`'s own lookup only tries `type` then `command -v <name>.fn.sh` on `PATH` — unlike `Require`, it does **not** search the fixed `myx.distro-{system,source,deploy,remote,.local}/sh-scripts/` list itself.
- That search only happens because a console's bashrc (`console-*-bashrc.rc`) puts all five `sh-scripts/` dirs on `PATH` before handing off to `Deploy`/`Source`/etc. (e.g. `myx.distro-deploy/sh-scripts/ExecuteParallel.fn.sh`, whose `--select-*` handling calls `Distro ListDistroProjects ...`).
- Outside a console — plain `bash sh-scripts/Foo.fn.sh` — any `Distro <name>` call to a command not already sourced fails with `unknown command: <name>`.

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

## DistroAgentsTools — gotchas

These are confirmed real failure modes, not hypothetical risk — read before touching this tool.

- **Single-dispatcher convention, like every sibling `Distro*Tools`/`Distro*Command` script**: exactly one top-level function (`DistroAgentsTools`), one `case "$1" in ... esac`. New ops go inline in the dispatcher's `case` — never a separate `DistroAgentsTools<OpName>` function per operation: a per-op function can end up calling `DistroAgentsTools` assuming it exists as a sibling function, which only works if the file happens to define it, not because it's a sound pattern.
- **`--agents-config-option`'s config file has a real stale-mirror trap**: it resolves to `$MMDAPP/.local/.agents/MDAT.settings.env` in source, but the *deployed* `.local` mirror can silently lag behind after a source-side rename — every credential lookup then silently hits an empty/stale file, no error. If `--self-test`/`--select-all` ever comes back suspiciously empty, check `$MDLT_ORIGIN` resolution and whether `.local`'s copy of `myx.distro-.local/sh-lib/LocalTools.Config.include` actually matches `source`'s, before assuming credentials are missing. **The real fix, not a manual copy**: run `source/myx/myx.distro-.local/actions/distro/local-tools/apply-distro-.local-2-local.sh` (rsyncs `source/myx/myx.distro-.local/` → `.local/myx/myx.distro-.local/`) — the sanctioned sync action for this exact drift class. Prefer this over hand-copying the one file that happened to be stale — the action re-syncs the whole package, catching any other drift in the same mirror at once.
- **`--send-console` is command-only, not a data-transport.** It re-joins trailing words into one raw unquoted line and writes it to the console's FIFO — exactly like typing at an interactive shell prompt, caller's own responsibility to quote correctly. It is NOT safe for arbitrary free text (a message body, anything with parentheses/quotes/semicolons) — that class of content can crash a live console process. For free text, call `--member-slack-send-message`/`--send-email-message` as bare direct invocations instead; they never go through `--send-console`.
- **`--sweep-read-incoming-comms` defaults to `--pretty` output** (`ts | user | text` lines via `AgentSlackMessagesFormat.awk` in *this* package's own `sh-lib/`, not raw JSON) — raw JSON is never the default since every real caller ends up hand-parsing it anyway. `--raw` opts back into the full JSON response. The formatter lives here, not in `myx.common`, since it's `DistroAgentsTools`-specific output formatting, not a general-purpose `myx.common` utility. Stale `myx.common` copies still sit in `.cleanup/`, pending an `rm` permission fix — not deleted outright.
- **The no-target "sweep everything" mode is a dedicated macro-operation for `routine-main-loop`'s Comms step specifically**, not a generic convenience loop — it combines both watched Slack targets, `--check-email`, and `--check-trello` into one call. Keep that framing if extending it; don't casually add unrelated platforms without checking whether comms-sweep actually needs them there.
- **`--purge-cleanup` exists to route around a real Claude Code permission-engine limitation, not as a general `rm` wrapper — and takes NO arguments.** A blanket `Bash(rm *)` deny in `~/.claude/settings.json` cannot be carved into "except `.cleanup/*`" with a more specific `allow` entry — deny always wins over allow regardless of specificity. The deny rule is a literal prefix-match on the invoked Bash command text (`rm `), so wrapping the actual `rm` call inside this already-allowlisted script invocation sidesteps it entirely. It always purges exactly one fixed, predefined folder — `$MMDAPP/.local/.cleanup` (matches the general pattern of local-only, not-git-tracked scratch space living under `.local/`) — never a caller-supplied path: no path argument means no traversal/injection surface to guard against, so no canonicalization/prefix-check machinery is needed. **Don't add small extracted helper functions for this kind of thing** — inline logic directly in the op's own `case` arm, especially for single-liners. The few existing helpers (`DistroAgentsToolsResolveTarget`, `DistroAgentsToolsPermOf`, etc.) are established precedent, not license to keep adding more.
- **Console channels have no per-caller isolation**: the channel id is deterministic per (workspace, console) only, so two legitimate concurrent callers against the same workspace can silently tear down each other's session — this can cause real collisions. No fix has landed yet. If you hit `channel_not_found`, or a console dying mid-use with another session active, this is why.

## DistroImageSync — direction, not a spec

`DistroImageSync` lives here (not `myx.distro-source`) because it's the generic sync engine shared across stages — its case statement already spans all five: `source-prepare-pull`, `source-process-push`, `image-prepare-pull`, `image-process-push`, `image-install-pull`. `DistroImagePrepare` stays in `-source` instead, as stage-3-specific build orchestration.

Stated longer-term direction for this command — a goal to stay aligned with, not a committed design or flag spec, nothing here is literal: it may grow to represent *any* sync method a stage/subsystem needs, not just its current git clone/pull mechanism (`myx.common`'s `git/clonePull`, invoked from `DistroImage.SyncScriptMaker.include`); may take on bootstrapping the subsystems themselves (fetching/installing `myx.distro-system`/`myx.distro-deploy`/etc. as prebuilt bundles — distinct from what `-.local` does today at install time); and may handle other prebuilt/exported artifacts, the kind `DistroImagePublish`/`DistroImageDownload` are meant to produce/consume once built (both still unimplemented — see this repo's README `DistroImageDownload` entry and `-source`'s README `image-prepare` stage section). Don't treat this as scope to implement against or as license to expand the README Commands entry into a spec — it's direction, not a contract.
