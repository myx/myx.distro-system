# Examples

[Back to the README](../README.md)

## List what a project provides

	ListDistroProvides.fn.sh --select-projects macosx

Include the inherited values:

	ListDistroProvides.fn.sh --select-projects macosx --merge-sequence

## Select projects by value

	ListDistroProvides.fn.sh --select-keywords <keyword>
	ListDistroProvides.fn.sh --select-provides deploy-ssh-target:

## Narrow a selection

	ListDistroDeclares.fn.sh --select-projects myx --filter-projects <host-name-part> --no-cache --no-index | sort

## Find a provide name that two projects carry

	ListDistroProvides.fn.sh --all-provides --no-cache --no-index | sort

## Print, then run, a repository sync

	DistroImageSync.fn.sh --all-tasks --print-source-prepare-pull
	DistroImageSync.fn.sh --all-tasks --execute-source-prepare-pull
