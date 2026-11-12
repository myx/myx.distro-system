📘 syntax: ListDistroProvides.fn.sh --all-provides
📘 syntax: ListDistroProvides.fn.sh --all-provides-merged
📘 syntax: ListDistroProvides.fn.sh <project-selector> [--merge-sequence] [<options>]
📘 syntax: ListDistroProvides.fn.sh [--help]

##  Summary:

		Lists provides data across all projects or selected projects, with optional derived
		columns and filter/unroll transforms.

##  Arguments:

		project-selector
			One or more project selector options, given first:
			--select-{all|sequence|changed|none|from-env}
			--{select|filter|remove}-{projects|declares|[merged-]provides|[merged-]keywords|one-project} <filter>
			--help lists each of them. --merge-sequence is not one of them: it follows them.

##  Options:

		--no-index
			Use no index.

		--no-cache
			Use no cache.

		--all-provides
			Prints full provides index. Takes no other option.

		--all-provides-merged
			Prints merged provides index. Takes no other option.

		--add-own-provides-column <match>
		--filter-own-provides-column <match>
		--add-merged-provides-column <match>
		--filter-merged-provides-column <match>
			Adds own or merged provides column with values matched, or filters by it. Multiple
			per-project values merged with '|' into a single new column. Can be repeated.

		--all-filter-and-cut <filter>
		--filter-and-cut <filter>
			Prints the provides values that start with <filter> followed by ':', with that
			prefix cut. --all-filter-and-cut reads all projects, --filter-and-cut the
			selected ones.

		--all-unroll-filter-and-cut <filter> <command>
		--unroll-filter-and-cut <filter> <command>
		--unroll-filter-and-cut-merged <filter> <command>
			Unrolls filtered values into row-per-value output, passed to <command>, such as
			cat.

		--merge-sequence
			Uses merged sequence provides for selected projects. Takes no option after it.

		--select-from-env
			Uses MDSC_SELECT_PROJECTS.

		--explicit-noop
			No-op selector marker.

		--help
			Prints command help and exits.

##  Examples:

		# Print the whole provides index
		`ListDistroProvides.fn.sh --all-provides`
		# Select one namespace and print the selection
		`ListDistroProvides.fn.sh --select-projects myx/`
		# Keep the rows whose provides value begins build-tool
		`ListDistroProvides.fn.sh --all-filter-and-cut build-tool`
		# Unroll the image-install values into one line per distinct value
		`ListDistroProvides.fn.sh --all-unroll-filter-and-cut image-install cat`
