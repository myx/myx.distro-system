📘 syntax: ListDistroProvides.fn.sh --all-provides
📘 syntax: ListDistroProvides.fn.sh --all-provides-merged
📘 syntax: ListDistroProvides.fn.sh <project-selector> [--merge-sequence] [<options>]
📘 syntax: ListDistroProvides.fn.sh [--help]

##  Summary:

		Lists provides data across all projects or selected projects, with optional derived
		columns and filter/unroll transforms.

##  Arguments:

		project-selector
			Optional selector when not using --all-provides modes.

##  Options:

		--all-provides
			Prints full provides index.

		--all-provides-merged
			Prints merged provides index.

		--add-own-provides-column <match>
		--filter-own-provides-column <match>
		--add-merged-provides-column <match>
		--filter-merged-provides-column <match>
			Adds/filters derived provides columns. Can be repeated.

		--all-filter-and-cut <filter>
		--filter-and-cut <filter>
			Filters rows by prefix and cuts prefix from output.

		--all-unroll-filter-and-cut <filter>
		--unroll-filter-and-cut <filter>
		--unroll-filter-and-cut-merged <filter>
			Unrolls filtered values into row-per-value output.

		--merge-sequence
			Uses merged sequence provides for selected projects.

		--select-from-env
			Uses MDSC_SELECT_PROJECTS.

		--explicit-noop
			No-op selector marker.

		--help
			Prints command help and exits.
