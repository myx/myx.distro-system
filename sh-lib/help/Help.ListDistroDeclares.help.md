📘 syntax: ListDistroDeclares.fn.sh [<options>] --all-declares
📘 syntax: ListDistroDeclares.fn.sh [<options>] <project-selector> [--merge-sequence]
📘 syntax: ListDistroDeclares.fn.sh [--help]

##  Summary:

		Lists declares data across all projects or selected projects, with optional derived
		columns and filter/unroll transforms.

##  Arguments:

		project-selector
			Optional selector when not using --all-declares modes.

##  Options:

		--all-declares
			Prints full declares index.

		--all-declares-merged
			Prints merged declares index.

		--add-own-declares-column <match>
		--filter-own-declares-column <match>
		--add-merged-declares-column <match>
		--filter-merged-declares-column <match>
			Adds/filters derived declares columns. Can be repeated.

		--all-filter-and-cut <filter>
		--filter-and-cut <filter>
			Filters rows by prefix and cuts prefix from output.

		--all-unroll-filter-and-cut <filter>
		--unroll-filter-and-cut <filter>
		--unroll-filter-and-cut-merged <filter>
			Unrolls filtered values into row-per-value output.

		--merge-sequence
			Uses merged sequence declares for selected projects.

		--select-from-env
			Uses MDSC_SELECT_PROJECTS.

		--explicit-noop
			No-op selector marker.

		--help
			Prints command help and exits.
