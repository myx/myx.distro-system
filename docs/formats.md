# Formats

[Back to the README](../README.md)

## Where a tool's manual lives

A tool's manual is a plain file beside it: `sh-lib/help/Help.<Tool>.help.md`. A matching `Help.<Tool>.include` holds the syntax lines that `--help` prints.

- The `.help.md` file is the authority. Some `.include` files print their own copy of the options, and those copies can drift from it.
- `Man.<Topic>.help.md` is a free-form reference, such as a file format or an install guide. No tool owns it.

## project.inf

The index is built from each project's `project.inf` file. The [project.inf manual](https://github.com/myx/myx.distro-.local/blob/main/sh-lib/help/Man.Project.Inf.file.help.md) describes the file format.

## Index views

The index holds each property of each project. A view has two properties:

- Owned or merged. Owned is a project's own declared values. Merged adds everything inherited through the build sequence.
- Distro or project scope. Distro covers all projects at once. Project covers one named project.

A merged view is the build sequence joined with the raw per-project index. It is not a walk of the dependency graph on every call.

## Build sequence

The sequence lists each project with every project it requires, directly or not, with dependencies before the project. Cycles are handled.

`ListDistroSequence.fn.sh --all` prints it as lines of `<project> <transitively-required-project>`.

## Provides rows

`ListDistroProvides.fn.sh --all-provides` prints lines of `<project> <provide-name>`. A name that two projects carry appears on two lines.

## Selection

`MDSC_SELECT_PROJECTS` holds the current selection. The `--select-from-env` option reads it.
