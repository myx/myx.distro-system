# Commands

[Back to the README](../README.md)

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


## Call forms

A tool is a function in `sh-scripts/<Tool>.fn.sh`. Three forms call it:

- `Distro <Tool>` — defines the function from `<Tool>.fn.sh` only when it is not yet defined, then calls it. Write the name without `.fn.sh`.
- `<Tool>.fn.sh` — executes the file every time.
- `<Tool>` — the bare function name. It works only where the environment already holds the definition, such as a script run through the `execute` operation.

`Require <name>` only loads a tool. It looks in the package `sh-scripts/` directories in this order: `system`, `source`, `deploy`, `remote`, `agents`, `.local`. `Action <name>` is a different dispatcher. It runs `actions/<name>` from the workspace root, executing a `.sh` file and opening a `.url` file.

A bare name resolves when the tool is in an installed package's `sh-scripts/`. A command kept in a project tree is called by its full path.

## ListDistroProjects

`ListDistroProjects.fn.sh` is the selector engine behind the list commands. Beyond the selectors in [Use](use.md), it offers:

- `--all-projects` — print every project and exit.
- `--print-selected` — print the current selection.
- `--select-from-env` — start from `MDSC_SELECT_PROJECTS`.
- `--select-merged-provides`, `--select-merged-keywords` — match inherited values too. The `--filter-` and `--remove-` forms match them as well.
- `--project <filter>` and `--one-project <filter>` — resolve exactly one project, or fail.
- `--projects`, `--provides`, `--declares`, `--keywords`, `--merged-provides`, `--merged-keywords` — print the projects that match the filter.
- `--required`, `--affected` — print the required or affected set of the current selection. The `--select-` forms add them instead.
- `--select-execute-default <command>` — run a command with the remaining arguments and the current selection.

## Index options

The list commands accept these options:

- `--no-index` — use no index.
- `--no-cache` — use no cache.
- `--explicit-noop` — an argument that does nothing, safely.

`ListDistroProvides.fn.sh` also takes:

- `--merge-sequence` — include every inherited `Provides` value of each selected project.
- `--filter-and-cut <prefix>` — keep only the values with that prefix, and cut the prefix and the colon after it.
- `--add-own-provides-column <matcher>` and `--add-merged-provides-column <matcher>` — add a column of matching values. Several values for one project are joined with `|`.
- `--filter-own-provides-column <matcher>` and `--filter-merged-provides-column <matcher>` — filter by that column.
- `--distro-from-source`, `--distro-from-cached`, `--distro-source-only` — choose where the index data comes from.

## ListDistroSequence

- `--all` — print the joined sequence list.
- `--all-projects` — print every row of the sequence index.
- `--select-from-env` — print the sequence for `MDSC_SELECT_PROJECTS`.

## JumpTo

`JumpTo.fn.sh [--cd-source|--cd-output|--cd-cached] <project-name-part>` prints the path of one project and changes to it. The part must resolve to exactly one project. Without a `--cd-*` option, the tool picks the base directory from `MDSC_INMODE`.

## DistroImageSync

`DistroImageSync.fn.sh` builds, prints or runs the repository sync tasks of a stage.

- `--all-tasks` — build the task list from every supported sync declaration.
- `--print-all-tasks`, `--print-tasks`, `--print-repo-list` — print the task list, the current job list, or the repository triplets.
- `--print-<stage>`, `--script-<stage>`, `--execute-<stage>` — print the tasks, print a runnable script, or run it. The stages are `source-prepare-pull`, `source-process-push`, `image-prepare-pull`, `image-process-push` and `image-install-pull`.
- `--script-from-stdin-repo-list [syncMode]` and `--execute-from-stdin-repo-list [syncMode]` — read repository triplets from stdin, then print or run the generated script.
- `--list-orphaned-projects` — print the source projects that no `distro-image-sync` repository directive covers. It checks existence only, with no git status. It needs no selector.
- `--script-prune-orphaned-projects` — for each orphan, print an `rm -rf <path>` line when it is a clean git checkout, or a `# skip (dirty|no-git): <path>` line when it is not. It only prints. It never deletes.


## Manuals

Each tool has a manual with its full syntax, options and examples.

- [AllActions](../sh-lib/help/Help.AllActions.help.md)
- [AllBuilders](../sh-lib/help/Help.AllBuilders.help.md)
- [AllNamespaces](../sh-lib/help/Help.AllNamespaces.help.md)
- [AllProjects](../sh-lib/help/Help.AllProjects.help.md)
- [DistroImageCommand](../sh-lib/help/Help.DistroImageCommand.help.md)
- [DistroImageSync](../sh-lib/help/Help.DistroImageSync.help.md)
- [DistroSourceCommand](../sh-lib/help/Help.DistroSourceCommand.help.md)
- [JumpTo](../sh-lib/help/Help.JumpTo.help.md)
- [ListDistroDeclares](../sh-lib/help/Help.ListDistroDeclares.help.md)
- [ListDistroKeywords](../sh-lib/help/Help.ListDistroKeywords.help.md)
- [ListDistroProjects](../sh-lib/help/Help.ListDistroProjects.help.md)
- [ListDistroProvides](../sh-lib/help/Help.ListDistroProvides.help.md)
- [ListDistroScripts](../sh-lib/help/Help.ListDistroScripts.help.md)
- [ListDistroSequence](../sh-lib/help/Help.ListDistroSequence.help.md)
