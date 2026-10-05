# Troubleshooting

[Back to the README](../README.md)

## command not found

`command not found` is about the call, not about the tool. The form you used matched none of the three call forms. [Commands](commands.md) lists them. Check the form before you decide an operation is missing.

## unknown command outside a console

`Distro <name>` finds a tool through `PATH`, after checking whether the function exists. It does not search the package list.

Each console adds its own package `sh-scripts/` directories to `PATH`. The lists differ per console. Read `PATH` rather than assume what a console exposes.

Run as a plain script, such as `bash sh-scripts/Foo.fn.sh`, any `Distro <name>` call for a tool that is not yet loaded fails with `unknown command: <name>`. This happens even when the file exists.

## An edited tool still behaves as before

`Distro <Tool>` reuses the function that is already loaded and says nothing about it. After you edit a tool, call `<Tool>.fn.sh`. Executing the file redefines the function.

## JumpTo prints a directory change and nothing moves

`JumpTo.fn.sh` announces `Changing directory: <path>`. The console does not change directory.

Run as a script, `JumpTo` changes only its own process. The prompt hook that should apply the change runs two subshells below your shell, so it cannot. Change directory yourself, with the path `JumpTo` prints.

## An index answers empty or stale

The default path serves a published index. To bypass the cached index, pass both `--no-cache` and `--no-index`. One option alone bypasses only one cache.

To measure what the index tools do, set `MDSC_DETAIL=full`. Any other value hides some of the messages and gives a result that looks like success.

## Two projects carry one provide name

The resolver never warns about this. It adds every provider of a name to the requiring project.

To find them, list the pairs without the index, so no ingest is needed:

	ListDistroProvides.fn.sh --all-provides --no-cache --no-index | sort

A name on two lines has two providers. That is not always a defect. `os.any` is carried by every `os-myx.common-<os>` package on purpose. Ask what each repeated name is for.

## A source directory belongs to no repository

`DistroImageSync.fn.sh --list-orphaned-projects` lists source projects that no repository directive covers. `--script-prune-orphaned-projects` prints the clean-up commands for them. It prints only. Read each line before you run it.

## The index shows another workspace's projects

The index variables survive a switch to another workspace. A process can then serve the previous workspace's index. Launch the tool in or from the workspace you mean.
