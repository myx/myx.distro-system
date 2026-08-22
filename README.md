# myx.distro-system

Indexing and query tools shared by every myx.distro console. Use them to find
projects, read project metadata, resolve build order, and sync source
repositories.

## Getting started

These tools install together with the source, deploy and remote toolsets — there
is nothing to install separately. Open a workspace console and they are on
`PATH`:

	./DistroSourceConsole.sh

Inside a console, call a tool by its full name (`.fn.sh` included), or through the
`Distro` dispatcher:

	ListDistroProjects.fn.sh --all-projects
	Distro ListDistroProjects --all-projects

## Common tasks

List every project in the workspace:

	ListDistroProjects.fn.sh --all-projects

Show what one project provides:

	ListDistroProvides.fn.sh --select-projects <project-name-part>

Print the whole build order:

	ListDistroSequence.fn.sh --all-projects

Change directory to a project without typing its path:

	JumpTo.fn.sh <project-name-part>

Pull every configured source repository:

	DistroImageSync.fn.sh --all-tasks --execute-source-prepare-pull

Find source directories that no repository declaration covers:

	DistroImageSync.fn.sh --list-orphaned-projects

Update the installed copy of these tools:

	Action distro/system-tools/update-system-tools.sh

## Selecting projects

Most list commands take one or more selectors instead of a project name.

- Whole-set selectors:
	- `--select-all` — every project.
	- `--select-sequence` — every project, in build order.
	- `--select-changed` — projects changed in this build.
	- `--select-none` — clear the current selection.
	- `--select-from-env` — the projects selected in the current build context.
- Matching selectors:
	- `--select-projects <name-glob>` — match a substring of the project name.
	- `--select-one-project <name-glob>` — same, but fail unless exactly one matches.
	- `--select-provides <value-prefix>` — match a `Provides` value.
	- `--select-declares <value-prefix>` — match a `Declares` value.
	- `--select-keywords <keyword>` — match an exact keyword.
- Walking the dependency graph:
	- `--select-required` — add the projects the current selection requires.
	- `--select-all-affected` — add the projects derived from the current selection.

Swap `--select-` for `--filter-` to narrow the current selection, or `--remove-`
to subtract from it. `--merged-provides` and `--merged-keywords` variants match
inherited values as well as the project's own. Run any list command with `--help`
for the full list.

## Commands

- Query project metadata:
	- `ListDistroProjects.fn.sh` — select, filter, print and run commands against project sets.
	- `ListDistroProvides.fn.sh` — print `Provides` values for all or selected projects.
	- `ListDistroDeclares.fn.sh` — print `Declares` values for all or selected projects.
	- `ListDistroKeywords.fn.sh` — print `Keywords` values for all or selected projects.
	- `ListDistroSequence.fn.sh` — print build sequence, globally or for a selection.
- List what the workspace contains:
	- `AllProjects.fn.sh` — all projects found under registered namespace roots.
	- `AllNamespaces.fn.sh` — all namespaces (repository roots).
	- `AllActions.fn.sh` — all workspace actions.
	- `AllBuilders.fn.sh` — all builder scripts found in source projects.
	- `ListDistroScripts.fn.sh` — available distro script entry points, by type.
- Move around and sync:
	- `JumpTo.fn.sh` — print and change directory to one resolved project path.
	- `DistroImageSync.fn.sh` — build, print or execute repository sync tasks for a pipeline stage.
- Java entry points:
	- `DistroSourceCommand.fn.sh` — run the Java source command with workspace roots preconfigured.
	- `DistroImageCommand.fn.sh` — run the Java image command with workspace roots preconfigured.

Console dispatchers, available in every distro console:

- `Distro <command> [args...]` — run any distro command in the active context.
- `Action <action-path>.sh [args...]` — run a generated workspace action from `actions/`.
- `Require <command>` — load one tool into the current session.

## Getting help

- `<Tool>.fn.sh --help` — full syntax, options and examples for any command above.
- `Distro --help`, `Action --help`, `Require --help` — dispatcher syntax.
- Press TAB after a command name and a space for shell completion.

## Related packages

- [myx.distro](https://github.com/myx/myx.distro) — the distro system overview.
- [myx.distro-.local](https://github.com/myx/myx.distro-.local) — install and launch the toolsets.
- [myx.distro-source](https://github.com/myx/myx.distro-source) — build source into a distro image.
- [myx.distro-deploy](https://github.com/myx/myx.distro-deploy) — deploy a distro image to hosts.
- [myx.distro-remote](https://github.com/myx/myx.distro-remote) — drive a workspace on another machine.
- [myx.distro-agents](https://github.com/myx/myx.distro-agents) — the magic-team agents and their tooling.
