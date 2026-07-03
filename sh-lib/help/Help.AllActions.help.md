📘 syntax: AllActions.fn.sh --default
📘 syntax: AllActions.fn.sh --scripts

##  Summary:

		This command lists all actions and displays this list in various forms.

##  Arguments:

		None. This command is option-driven.

##  Options:

		--no-index
			Bypasses prebuilt index files and resolves action list directly from source/context.

		--no-cache
			Bypasses cached scan/output data and forces fresh list generation.

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
			Lists action names in a single column for shell completion use.

##  Examples:

		# List actions in default two-column view
		`AllActions.fn.sh --default`
		# List actions with project-relative full paths
		`AllActions.fn.sh --full`
		# List action script paths only
		`AllActions.fn.sh --scripts`
		# List executable action paths without shortening
		`AllActions.fn.sh --executables`
		# Print raw rows without table formatting
		`AllActions.fn.sh --no-formatting --default`
		# List action names for shell completion
		`AllActions.fn.sh --completion`
