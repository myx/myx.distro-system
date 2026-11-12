📘 syntax: ListDistroProjects.fn.sh --all-projects
📘 syntax: ListDistroProjects.fn.sh <project-selector> [<command-options>] [<execute-extra-args>]
📘 syntax: ListDistroProjects.fn.sh [--help]

##  Summary:

		Core project selector engine: builds, filters, prints, stores, and executes commands
		against selected project sets.

##  Arguments:

		project-selector
			One or more project selector options, given first:
			--select-{all|sequence|changed|none|from-env}
			--{select|filter|remove}-{projects|declares|[merged-]provides|[merged-]keywords|one-project} <filter>
			--help lists each of them.

		command-options
			The print, save and execute options, given after the selector options.

		execute-extra-args
			Optional tail forwarded to command selected by --select-execute-default or
			--select-execute-command.

##  Options:

		--all-projects
			Prints all projects and exits.

		--select-from-env
			Initializes selection from MDSC_SELECT_PROJECTS.

		--print-selected
			Prints current selected project set.

		--select-all
		--select-sequence
		--select-none
		--select-changed
			Selection mutators (replace/initialize selection state).

		--select-projects <filter>
		--select-provides <filter>
		--select-merged-provides <filter>
		--select-declares <filter>
		--select-keywords <filter>
		--select-merged-keywords <filter>
		--select-one-project <filter>
			Adds matching projects to current selection. Can be repeated.

		--filter-projects <filter>
		--filter-provides <filter>
		--filter-merged-provides <filter>
		--filter-declares <filter>
		--filter-keywords <filter>
		--filter-merged-keywords <filter>
		--filter-one-project <filter>
			Intersects current selection with filter result. Can be repeated.

		--remove-projects <filter>
		--remove-provides <filter>
		--remove-merged-provides <filter>
		--remove-keywords <filter>
		--remove-merged-keywords <filter>
		--remove-one-project <filter>
			Removes matches from current selection. Can be repeated.

		--project <filter>
		--one-project <filter>
			Resolves exactly one project or fails.

		--projects <filter>
			Prints matching project names.

		--provides <filter>
		--merged-provides <filter>
		--declares <filter>
		--keywords <filter>
		--merged-keywords <filter>
			Prints projects matching index values.

		--select-required
		--select-affected
		--select-required-projects
		--select-affected-projects
			Adds required/affected sets for current selection.

		--required
		--required-projects
		--affected
		--affected-projects
			Prints required/affected sets for current selection.

		--select-execute-default <command> [<args>...]
			Sets downstream command used with remaining args and current selection env.

		--select-execute-command <command> [<args>...]
			Executes command immediately with selection env.

		--save-to-env
		--save-to-env-and-continue
			Saves current selection to MDSC_SELECT_PROJECTS.

		--save-to-var <var>
		--save-to-var-and-continue <var>
			Saves current selection into shell variable.

		--help
			Prints command help and exits.

##  Examples:

		# Print every project in the index
		`ListDistroProjects.fn.sh --all-projects`
		# Select one namespace and print the selection
		`ListDistroProjects.fn.sh --select-projects myx/`
		# Select, then run a command over the selected projects
		`ListDistroProjects.fn.sh --select-projects myx/ --select-execute-default /bin/echo MARK`
