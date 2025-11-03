#!/usr/bin/env bash

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )
fi

AllProjects(){

	local MDSC_CMD='AllProjects'
	[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $(printf '%q ' "$@")" >&2

	while [ $# -gt 0 ]; do
		. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/SystemContext.UseStandardOptions.include"
		case "$1" in
			--projects|--all-projects)
				DistroSystemContext --index-projects "${2:-sort}" "${@:3}"
				return 0
			;;
			--|--default|--sequence)
				DistroSystemContext --index-sequence "${2:-cat}" "${@:3}"
				return 0
			;;
			--requires)
				DistroSystemContext --index-requires "${2:-cat}" "${@:3}"
				return 0
			;;
			--source-projects|--scan-source-projects|--rescan-source-projects)
				. "$MDLT_ORIGIN/myx/myx.distro-source/sh-lib/source-prepare/ScanSourceProjects.include"
				return 0
			;;
			--deploy-projects|--scan-deploy-projects|--rescan-deploy-projects)
				. "$MDLT_ORIGIN/myx/myx.distro-deploy/sh-lib/deploy-context/ScanDeployProjects.include"
				return 0
			;;
			--help|--help-syntax)
				echo "📘 syntax: AllProjects.fn.sh --default" >&2
				echo "📘 syntax: AllProjects.fn.sh --sequence" >&2
				echo "📘 syntax: AllProjects.fn.sh [--help]" >&2
				if [ "$1" = "--help" ] ; then
					cat "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/help/Help.AllProjects.text" >&2
				fi
				return 0
			;;
			*)
				echo "⛔ ERROR: $MDSC_CMD: invalid option: $1" >&2
				set +e ; return 1
			;;
		esac
	done
}

case "$0" in
	*/sh-scripts/AllProjects.fn.sh) 

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-system/sh-lib/SystemContext.include"
			DistroSystemContext --distro-path-auto
		fi

		if [ -z "$1" ] || [ "$1" = "--help" ] ; then
			AllProjects "${1:-"--help-syntax"}"
			exit 1
		fi

		AllProjects "$@"
	;;
esac
