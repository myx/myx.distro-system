📘 syntax: AllActions.fn.sh --default
📘 syntax: AllActions.fn.sh --scripts

##  Summary:

		This command lists all actions and displays this list in various forms.

##  Options:

		--no-index
			Use no index.

		--no-cache
			Use no cache.

		--all-actions
		--default
			Lists all actions in two column form. Declaring projects in first column, action
			names in second column.

		--full
			Lists all actions in two column form. Declaring projects in first column, action
			full paths (from source root) in second column.

		--scripts
			Lists all actions full paths (from source root) in one column.

		--executables
			Lists executable action paths without path shortening.

		--no-formatting
			Disables table formatting and prints raw output rows.

		--completion
			Lists all actions names in one column.

##  Examples:

		# List actions in default two-column view
		`AllActions.fn.sh --default`
		# List actions with project-relative full paths
		`AllActions.fn.sh --full`
		# List action script paths only
		`AllActions.fn.sh --scripts`
		# List action names for shell completion
		`AllActions.fn.sh --completion`
