# Extension

[Back to the README](../README.md)

## Add a tool

A tool is `sh-scripts/<Name>.fn.sh`. It defines a shell function `<Name>`. It ends with a `case "$0" in */sh-scripts/<Name>.fn.sh) ... esac` block that calls the function when the file is executed directly.

This is what lets one file work both ways. Sourcing it defines the function, and executing it runs the function.

Give every tool a manual and a syntax file: `Help.<Name>.help.md` and `Help.<Name>.include`, under `sh-lib/help/`. Follow the standard form of an existing pair.

## Call another tool

- Inside a tool, source the other tool only when its function is not yet defined: `type <FunctionName> >/dev/null 2>&1 || . "$( myx.common which lib/<name> )"`.
- To read the project index, call `DistroSystemContext --index-*` in the same process. Do not run `ListDistroProjects.fn.sh` or `ListDistroDeclares.fn.sh` as a child process, which starts with no index and rebuilds it.
- A tool that must work outside a console takes the standard `*.fn.sh` bootstrap, plus `Require <Tool> || :`.

## Write an include

An include reports failure with `set +e ; return 1`, never `exit`. An `exit` in a sourced file ends the caller's process. Every place that sources the include must pass the failure on.
