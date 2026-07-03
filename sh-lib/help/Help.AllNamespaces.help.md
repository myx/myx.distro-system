📘 syntax: AllNamespaces.fn.sh --all-namespaces
📘 syntax: AllNamespaces.fn.sh --source-namespaces
📘 syntax: AllNamespaces.fn.sh [--help]

##  Summary:

		This command lists all namespaces (repository roots) and displays this list in various forms.

##  Arguments:

		None. This command is option-driven.

##  Options:

		--no-index
			Bypasses prebuilt index files and resolves data directly from source/context.

		--no-cache
			Bypasses cached scan/output data and forces fresh data resolution.

		--all-namespaces
			Lists all system-registered namespaces.

		--source-namespaces
			Lists (scans) all source-declared namespaces.

		--help
			Prints command help and exits.

##  Examples:

		# List all registered namespaces
		`AllNamespaces.fn.sh --all-namespaces`
		# Scan and list namespaces directly from source roots
		`AllNamespaces.fn.sh --source-namespaces`
