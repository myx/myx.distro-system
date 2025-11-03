#!/usr/bin/env bash

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )
fi

AllBuilders(){

	local MDSC_CMD='AllBuilders'

	case "$1" in
		--no-formatting)
			shift
		;;
		*)
			[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $(printf '%q ' "$@")" >&2
			if [ -t 1 ] && command -v column >/dev/null 2>&1; then
				AllBuilders --no-formatting "$@" | column -t
				return 0
			fi
		;;
	esac

	local sedEx="sed -e 's:^$MMDAPP/source/::' -e 's:^$MDSC_SOURCE/::' -e 's:^$MDLT_ORIGIN/::' -e 's:/builders/: :'"
	local stageFilter=

	. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/SystemContext.UseStandardOptions.include"
	while [ $# -gt 0 ]; do
		case "$1" in
			--executables)
				sedEx="cat"
				shift
			;;
			--scripts)
				sedEx="sed -e 's:^$MMDAPP/source/::' -e 's:^$MDSC_SOURCE/::' -e 's:^$MDLT_ORIGIN/::'"
				shift
			;;
			--full)
				sedEx="sed -e 's:^$MMDAPP/source/::' -e 's:^$MDSC_SOURCE/::' -e 's:^$MDLT_ORIGIN/::' -e 's:^\(.*\)/builders/:\1 \1/builders/:'"
				shift
			;;
			--|--default|--all-builders)
				shift
			;;
			--all-build-stages)
				shift ;	break
			;;
			source-prepare|source-process|image-prepare|image-process|image-install)
				stageFilter="$1"
				sedEx="grep '/builders/$stageFilter/' | $sedEx"
				shift ;	break
			;;
			--help|--help-syntax)
				echo "📘 syntax: AllBuilders.fn.sh --default|--full|--scripts| [--all-build-stages]..." >&2
				echo "📘 syntax: AllBuilders.fn.sh [--help]" >&2
				if [ "$1" = "--help" ] ; then
					cat "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/help/Help.AllBuilders.text" >&2
				fi
				return 0
			;;
			*)
				echo "⛔ ERROR: $MDSC_CMD: invalid option: $1" >&2
				set +e ; return 1
			;;
		esac
	done

	if [ "$MDSC_NO_CACHE" != "--no-cache" ] && [ -d "$MDSC_CACHED" ] ; then

		local cacheFile="$MDSC_CACHED/distro-builders.txt"
		local buildDate="$MDSC_CACHED/build-time-stamp.txt"

		if [ -f "$cacheFile" ] && [ -f "$buildDate" ] && [ ! "$cacheFile" -ot "$buildDate" ] ; then
			[ -z "$MDSC_DETAIL" ] || echo "| $MDSC_CMD: using cached ($MDSC_OPTION)" >&2
			cat "$cacheFile" | eval "$sedEx" 
			return 0
		fi

		[ -z "$MDSC_DETAIL" ] || echo "$MDSC_CMD: caching all actions ($MDSC_OPTION)" >&2
		. "$MDLT_ORIGIN/myx/myx.distro-source/sh-lib/source-context/ScanSourceBuilders.include" \
		| tee "$cacheFile.$$.tmp" | eval "$sedEx"
		mv -f "$cacheFile.$$.tmp" "$cacheFile"
		return 0

	fi
	
	. "$MDLT_ORIGIN/myx/myx.distro-source/sh-lib/source-context/ScanSourceBuilders.include" | eval "$sedEx"
}

case "$0" in
	*/sh-scripts/AllBuilders.fn.sh) 

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-system/sh-lib/SystemContext.include"
			DistroSystemContext --distro-path-auto
		fi

		if [ -z "$1" ] || [ "$1" = "--help" ] ; then
			AllBuilders "${1:-"--help-syntax"}"
			exit 1
		fi

		AllBuilders "$@"
	;;
esac
