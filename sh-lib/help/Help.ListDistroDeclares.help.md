📘 syntax: ListDistroDeclares.fn.sh [<options>] --all-declares
📘 syntax: ListDistroDeclares.fn.sh [<options>] --all-declares-merged
📘 syntax: ListDistroDeclares.fn.sh [<options>] <project-selector> [--merge-sequence]
📘 syntax: ListDistroDeclares.fn.sh [--help]

##  Summary:

		Lists declares data across all projects or selected projects, with optional derived
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

		--all-declares
			Prints full declares index. Takes no other option.

		--all-declares-merged
			Prints merged declares index. Takes no other option.

		--add-own-declares-column <match>
		--filter-own-declares-column <match>
		--add-merged-declares-column <match>
		--filter-merged-declares-column <match>
			Adds own or merged declares column with values matched, or filters by it. Multiple
			per-project values merged with '|' into a single new column. Can be repeated.

		--all-filter-and-cut <filter>
		--filter-and-cut <filter>
			Prints the declares values that start with <filter> followed by ':', with that
			prefix cut. --all-filter-and-cut reads all projects, --filter-and-cut the
			selected ones.

		--all-unroll-filter-and-cut <filter> <command>
		--unroll-filter-and-cut <filter> <command>
		--unroll-filter-and-cut-merged <filter> <command>
			Unrolls filtered values into row-per-value output, passed to <command>, such as
			cat.

		--merge-sequence
			Uses merged sequence declares for selected projects. Takes no option after it.

		--select-from-env
			Uses MDSC_SELECT_PROJECTS.

		--explicit-noop
			No-op selector marker.

		--help
			Prints command help and exits.

##  Examples:

		# Select the projects of one namespace
		`ListDistroDeclares.fn.sh --select-projects myx/`
		# The same selection with merged sequence declares
		`ListDistroDeclares.fn.sh --select-projects myx/ --merge-sequence`
		# Keep the rows whose value begins distro-image-sync, with that prefix cut
		`ListDistroDeclares.fn.sh --all-filter-and-cut distro-image-sync`
		# Unroll those rows into one line per distinct value
		`ListDistroDeclares.fn.sh --all-unroll-filter-and-cut distro-image-sync cat`
		# Print the projects whose value is exactly custom-commands-path:sh-scripts
		`ListDistroDeclares.fn.sh --select-all --filter-own-declares-column custom-commands-path:sh-scripts`
