📘 syntax: DistroSourceCommand.fn.sh [command-options...]
📘 syntax: DistroSourceCommand.fn.sh [--help]

##  Summary:

		Runs Java ru.myx.distro.DistroSourceCommand with workspace source/output/cached roots
		preconfigured.

##  Arguments:

		command-options
			All arguments are passed through to Java ru.myx.distro.DistroSourceCommand.

##  Options:

		--help
			Prints command help and exits.

		--help-syntax
			Prints command syntax summary and exits.

##  Notes:

		Shell wrapper does not parse options by itself.

##  Examples:

		# Print syntax/help from shell wrapper
		`DistroSourceCommand.fn.sh --help`

		# Print provides from source scan
		`DistroSourceCommand.fn.sh --import-from-source --print-all-provides`

		# Print provides from cached scan
		`DistroSourceCommand.fn.sh --import-from-cached --print-all-provides`
