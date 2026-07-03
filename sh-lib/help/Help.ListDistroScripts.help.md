📘 syntax: ListDistroScripts.fn.sh --all|--completion
📘 syntax: ListDistroScripts.fn.sh --type <source|deploy|system>
📘 syntax: ListDistroScripts.fn.sh [--help]

##  Summary:

		Lists available distro script entrypoints by scope/type.

##  Arguments:

		None. This command is option-driven.

##  Options:

		--all
			Lists scripts from source/deploy/system script directories.

		--completion
			Lists script names suitable for shell completion (without .fn.sh suffix).

		--type <source|deploy|system>
			Lists scripts for selected type. For source/deploy, system scripts are appended.

		--help
			Prints command help and exits.
