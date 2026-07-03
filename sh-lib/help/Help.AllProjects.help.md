📘 syntax: AllProjects.fn.sh --all-projects
📘 syntax: AllProjects.fn.sh --sequence
📘 syntax: AllProjects.fn.sh [--help]

##  Summary:

		This command lists all projects (located within namespace roots, non-nested and having 'project.inf' 
		file).

##  Options:

		--no-index
			Use no index.

		--no-cache
			Use no cache.

		--projects
		--all-projects
			Lists all system-registered projects, from indices suitable in current context. No
			particular order guaranteed, however sorted

		--sequence
		--default
		--
			Lists all system-registered projects, from indices suitable in current context. In
			order of global distro build sequence (calculated by reqiures-provides pairs).

		--source-projects
		--scan-source-projects
		--rescan-source-projects
			Lists (scans) all source-declared projects (within 'source' subsystem).

		--requires
			Lists requires index entries.

		--deploy-projects
		--scan-deploy-projects
		--rescan-deploy-projects
			Lists (scans) all source-declared projects (within 'deploy' subsystem).

##  Examples:

		# Print build-sequence projects filtered by myx namespace
		`AllProjects.fn.sh --sequence grep -e '^myx/'`
		# List all projects and filter names containing .distro-
		`AllProjects.fn.sh --projects fgrep '.distro-'`
