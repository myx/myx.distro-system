📘 syntax: AllNamespaces.fn.sh --all-namespaces
📘 syntax: AllNamespaces.fn.sh --source-namespaces
📘 syntax: AllNamespaces.fn.sh [--help]

##  Summary:

		This command lists all namespaces (repository roots) and displays this list in various forms.

##  Options:

		--no-index
			Use no index.

		--no-cache
			Use no cache.

		--all-namespaces
			Lists all system-registered namespaces.

		--source-namespaces
			Lists (scans) all source-declared namespaces.

##  Examples:

		# List all registered namespaces
		`AllNamespaces.fn.sh --all-namespaces`
		# Scan and list namespaces directly from source roots
		`AllNamespaces.fn.sh --source-namespaces`
