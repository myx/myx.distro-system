📘 syntax: ListDistroSequence.fn.sh [<selector-options>] --all
📘 syntax: ListDistroSequence.fn.sh [<selector-options>] --all-projects
📘 syntax: ListDistroSequence.fn.sh [<selector-options>] --select-from-env
📘 syntax: ListDistroSequence.fn.sh [--help]

##  Summary:

		Prints distro build sequence globally or for selected projects.

##  Arguments:

		None. This command is option-driven.

##  Options:

		--all
			Prints joined sequence list.

		--all-projects
			Prints full sequence index rows.

		--select-from-env
			Uses MDSC_SELECT_PROJECTS and prints sequence intersection.

		--help
			Prints command help and exits.

##  Notes:

		Unknown leading selector options are delegated through ListDistroProjects
		--select-execute-default ListDistroSequence.
