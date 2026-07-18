📘 syntax: DistroImageSync.fn.sh [<selector-options>] --print-all-tasks
📘 syntax: DistroImageSync.fn.sh [<selector-options>] <project-selector> <operation>
📘 syntax: DistroImageSync.fn.sh [<selector-options>] --all-tasks --{print|execute}-source-{prepare-pull|process-push}
📘 syntax: DistroImageSync.fn.sh [<selector-options>] --all-tasks --{print|execute}-image-{prepare-pull|process-push|install-pull}
📘 syntax: DistroImageSync.fn.sh --list-orphaned-projects
📘 syntax: DistroImageSync.fn.sh --script-prune-orphaned-projects
📘 syntax: DistroImageSync.fn.sh [--help]

##  Summary:

		Builds, prints, or executes repo sync task scripts for source/image stages.

##  Arguments:

		project-selector
			Optional selector when not using --all-tasks.

		operation
			Required operation token after selector/all-tasks mode. Must match parser families:
			--print-*, --script-*, or --execute-*.

##  Options:

		--all-tasks
			Builds task list from all supported sync declares.

		--select-from-env
			Filters task list by MDSC_SELECT_PROJECTS.

		--explicit-noop
			No-op selector marker in delegated selection flows.

		--print-all-tasks
			Prints expanded task list and exits.

		--print-tasks
			Prints current useJobList.

		--print-repo-list
			Prints repository triplets derived from task list.

		--list-orphaned-projects
			Prints projects present in the source tree (per ListDistroProjects --all-projects)
			that are covered by no repo:/list: distro-image-sync directive across any project.inf
			(any stage). Pure existence/coverage check, no git status involved. Needs no project
			selector.

		--script-prune-orphaned-projects
			Runs --list-orphaned-projects, then for each orphaned path prints an executable
			'rm -rf <path>' line if it's a clean git checkout, or a '# skip (dirty|no-git): <path>'
			comment line otherwise. Only prints — never deletes anything itself.

		--script-from-stdin-repo-list [syncMode]
			Reads stdin repo triplets and prints generated sync script.

		--execute-from-stdin-repo-list [syncMode]
			Reads stdin repo triplets and executes generated sync script.

		--print-<stage>
			Prints tasks for stage. Stage values: source-prepare-pull, source-process-push,
			image-prepare-pull, image-process-push, image-install-pull.

		--script-<stage> [<script-args>...]
			Prints executable script for selected stage.

		--execute-<stage> [<script-args>...]
			Executes script for selected stage.

		--help
			Prints command help and exits.
