📘 syntax: DistroImageCommand.fn.sh [command-options...]
📘 syntax: DistroImageCommand.fn.sh [--help]

##  Summary:

		Runs Java ru.myx.distro.DistroImageCommand with workspace source/output/cached roots
		preconfigured.

##  Arguments:

		command-options
			All arguments are passed through to Java ru.myx.distro.DistroImageCommand.

##  Options:

		--help
			Prints command help and exits.

		--help-syntax
			Prints command syntax summary and exits.

##  Notes:

		Shell wrapper does not parse options by itself.

##  Examples:

		# Print syntax/help from shell wrapper
		`DistroImageCommand.fn.sh --help`

		# Pass through Java command options
		`DistroImageCommand.fn.sh --print-all-provides`
