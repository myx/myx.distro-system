📘 syntax: AllBuilders.fn.sh --default
📘 syntax: AllBuilders.fn.sh --scripts
📘 syntax: AllBuilders.fn.sh --full
📘 syntax: AllBuilders.fn.sh [--all-build-stages]
📘 syntax: AllBuilders.fn.sh [source-prepare|source-process|image-prepare|image-process|image-install]

##  Summary:

		Lists builder scripts discovered in source projects.

##  Arguments:

		stage
			Optional positional argument. Allowed values are source-prepare,
			source-process, image-prepare, image-process, image-install.

##  Options:

		--no-index
			Bypasses prebuilt index files and resolves builder list directly from source/context.

		--no-cache
			Bypasses cached scan/output data and forces fresh list generation.

		--all-builders
		--default
			Lists builders in two-column form: project and builder-stage path tail.

		--scripts
			Lists full builder script paths (from source root).

		--full
			Lists project and full builder path in two-column form.

		--executables
			Lists executable paths without path shortening.

		--no-formatting
			Disables table formatting and prints raw output rows.

		--all-build-stages
			Includes all build stages without filtering.

		source-prepare|source-process|image-prepare|image-process|image-install
			Positional stage selector. Accepts one value from this set and filters output to that stage.

##  Examples:

		# List builders in default two-column view
		`AllBuilders.fn.sh --default`
		# List project and full builder path in two columns
		`AllBuilders.fn.sh --full`
		# List builder script paths only
		`AllBuilders.fn.sh --scripts`
		# Include all build stages without stage filtering
		`AllBuilders.fn.sh --all-build-stages`
		# Filter builder list to image-prepare stage
		`AllBuilders.fn.sh image-prepare`
