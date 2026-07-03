📘 syntax: JumpTo.fn.sh [--cd-source|--cd-output|--cd-cached] <unique-project-name-part>|<projectName>
📘 syntax: JumpTo.fn.sh [--help|--help-syntax]

##  Summary:

		Prints and changes directory to one resolved project path in selected base tree.

##  Arguments:

		project-selector
			Required positional argument at position 1. Must resolve to exactly one project.

##  Options:

		--cd-source
			Uses source base directory.

		--cd-output
			Uses output base directory.

		--cd-cached
			Uses cached base directory.

		--help
			Prints command help and exits.

		--help-syntax
			Prints syntax summary and exits.

##  Notes:

		Without --cd-* option, base directory is selected from MDSC_INMODE.
