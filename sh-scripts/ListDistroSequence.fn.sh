#!/usr/bin/env bash

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )
fi

ListDistroSequence(){
	local MDSC_CMD='ListDistroSequence'
	[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $(printf '%q ' "$@")" >&2

	. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/SystemContext.UseStandardOptions.include"

	local filterProjects=""

	set -e

	while true ; do
		case "$1" in
			--all)
				shift
				if [ -n "$1" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: --all. no extra options allowed" >&2
					set +e ; return 1
				fi

				DistroSystemContext --index-sequence cat
				return 0
				;;

			--all-projects)
				shift
				if [ -n "$1" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: --all-projects. no extra options allowed" >&2
					set +e ; return 1
				fi

				DistroSystemContext --index-sequence-merged cat
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
	*/sh-scripts/ListDistroSequence.fn.sh) 
		if [ -z "$1" ] || [ "$1" = "--help" ] ; then
			echo "📘 syntax: ListDistroSequence.fn.sh [<options>] --all" >&2
			echo "📘 syntax: ListDistroSequence.fn.sh [<options>] --all-projects" >&2
			echo "📘 syntax: ListDistroSequence.fn.sh --help" >&2
			if [ "$1" = "--help" ] ; then
				. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/help/Help.ListDistroSequence.include"
			fi
			exit 1
		fi
		
		if [ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-system/sh-lib/SystemContext.include"
			DistroSystemContext --distro-path-auto
		fi

		ListDistroSequence "$@"
	;;
esac
