📘 syntax: ListDistroKeywords.fn.sh --all-keywords
📘 syntax: ListDistroKeywords.fn.sh --all-keywords-merged
📘 syntax: ListDistroKeywords.fn.sh <project-selector> [--merge-sequence]
📘 syntax: ListDistroKeywords.fn.sh [--help]

##  Summary:

		Lists keywords data across all projects or selected projects, with optional derived
		columns and filter transforms.

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

		--all-keywords
			Prints full keywords index. Takes no other option.

		--all-keywords-merged
			Prints merged keywords index. Takes no other option.

		--add-own-keywords-column <match>
		--filter-own-keywords-column <match>
		--add-merged-keywords-column <match>
		--filter-merged-keywords-column <match>
			Adds own or merged keywords column with values matched, or filters by it. Multiple
			per-project values merged with '|' into a single new column. Can be repeated.

		--all-filter-and-cut <filter>
		--filter-and-cut <filter>
			Prints the keywords values that start with <filter> followed by ':', with that
			prefix cut. --all-filter-and-cut reads all projects, --filter-and-cut the
			selected ones.

		--merge-sequence
			Uses merged sequence keywords for selected projects. Takes no option after it.

		--select-from-env
			Uses MDSC_SELECT_PROJECTS.

		--explicit-noop
			No-op selector marker.

		--help
			Prints command help and exits.

##  Examples:

		# Select the projects of one namespace
		`ListDistroKeywords.fn.sh --select-projects myx/`
		# The same selection with merged sequence keywords
		`ListDistroKeywords.fn.sh --select-projects myx/ --merge-sequence`
		# Print every project with a matched keyword column, `-` where nothing matches
		`ListDistroKeywords.fn.sh --select-all --add-own-keywords-column mdci`
		# Print only the projects whose keyword value matches mdci whole
		`ListDistroKeywords.fn.sh --select-all --filter-own-keywords-column mdci`
