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
