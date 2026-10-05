# Use

[Back to the README](../README.md)

## Getting started

Open the console first. [Installation](installation.md) shows how.

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
