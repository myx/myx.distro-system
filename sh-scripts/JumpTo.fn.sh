#!/usr/bin/env bash

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )
fi

JumpTo(){

	local MDSC_CMD='JumpTo'
	[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $(printf '%q ' "$@")" >&2

	set -e

	local baseDirectory=

	while true ; do
		case "$1" in
			--cd-source) baseDirectory="$MDSC_SOURCE"; shift; ;;
			--cd-output) baseDirectory="$MDSC_OUTPUT"; shift; ;;
			--cd-cached) baseDirectory="$MDSC_CACHED"; shift; ;;
			--cd-*)
				echo "$MDSC_CMD: ⛔ ERROR: invalid --cd-XXXX option: $1" >&2
				set +e ; return 1
			;;
			--help|--help-syntax)
				echo "📘 syntax: JumpTo.fn.sh <unique-project-name-part>|<projectName>" >&2
				echo "📘 syntax: JumpTo.fn.sh [--help]" >&2
				if [ "$1" = "--help" ] ; then
					. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/help/Help.JumpTo.include" >&2
				fi
				return 0
			;;
			*)
				break
			;;
		esac
	done

	if [ -z "${baseDirectory:0:1}" ]; then
		case "$MDSC_INMODE" in
			source) baseDirectory="$MDSC_SOURCE"; ;;
			deploy) baseDirectory="$MDSC_OUTPUT"; ;;
			*)
				echo "$MDSC_CMD: ⛔ ERROR: can't decide jump target, invalid console mode: $MDSC_INMODE" >&2
				set +e ; return 1
			;;
		esac
	fi

	if [ -z "$1" ] ; then
		echo -e "$MDSC_CMD: ⛔ ERROR: 'filterProject' argument (name or keyword or substring) is required!" >&2
		set +e ; return 1
	fi
	local targetProject="$1"; shift
	targetProject="$( 
		Distro ListDistroProjects --one-project "$targetProject" 
	)"

	printf "Target: \n    %s\n" "$targetProject" >&2
	
	declare -x MDSC_INT_CD="$baseDirectory/$targetProject"
	MDSC_INT_CD="$baseDirectory/$targetProject"
	export MDSC_INT_CD
	PWD="$baseDirectory/$targetProject"
	export PWD
	cd "$baseDirectory/$targetProject"
}

case "$0" in
	*/sh-scripts/JumpTo.fn.sh)
		if [ -z "$1" ] || [ "$1" = "--help" ] ; then
			JumpTo ${1:-"--help-syntax"}
			exit 1
		fi

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-system/sh-lib/SystemContext.include"
			DistroSystemContext --distro-path-auto
		fi

		JumpTo "$@"
	;;
esac
