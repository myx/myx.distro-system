📘 syntax: ListDistroKeywords.fn.sh --all-keywords
📘 syntax: ListDistroKeywords.fn.sh --all-keywords-merged
📘 syntax: ListDistroKeywords.fn.sh <project-selector> [--merge-sequence]
📘 syntax: ListDistroKeywords.fn.sh [--help]

##  Summary:

		Lists keywords data across all projects or selected projects, with optional derived
		columns and filter transforms.

##  Arguments:

		project-selector
			Optional selector when not using --all-keywords modes.

##  Options:

		--all-keywords
			Prints full keywords index.

		--all-keywords-merged
			Prints merged keywords index.

		--add-own-keywords-column <match>
		--filter-own-keywords-column <match>
		--add-merged-keywords-column <match>
		--filter-merged-keywords-column <match>
			Adds/filters derived keywords columns. Can be repeated.

		--all-filter-and-cut <filter>
		--filter-and-cut <filter>
			Filters rows by prefix and cuts prefix from output.

		--merge-sequence
			Uses merged sequence keywords for selected projects.

		--select-from-env
			Uses MDSC_SELECT_PROJECTS.

		--explicit-noop
			No-op selector marker.

		--help
			Prints command help and exits.
