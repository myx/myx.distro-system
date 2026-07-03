📘 syntax: AllBuilders.fn.sh --default
📘 syntax: AllBuilders.fn.sh --scripts
📘 syntax: AllBuilders.fn.sh --full
📘 syntax: AllBuilders.fn.sh [--all-build-stages]
📘 syntax: AllBuilders.fn.sh [source-prepare|source-process|image-prepare|image-process|image-install]

	Summary:

		Lists builder scripts discovered in source projects.

	Options:

		--no-index
			Use no index.

		--no-cache
			Use no cache.

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
			Filters output to the selected build stage.

	Examples:

		AllBuilders.fn.sh --default
		AllBuilders.fn.sh --scripts
		AllBuilders.fn.sh image-prepare
