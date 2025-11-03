#!/usr/bin/env bash

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )
fi

AllActions(){

	local MDSC_CMD='AllActions'

	case "$1" in
		--completion)
			if [ full = "$MDSC_DETAIL" ]; then
				echo "> $MDSC_CMD $@" >&2
				local MDSC_DETAIL=true
			else
				[ -z "$MDSC_DETAIL" ] || local MDSC_DETAIL=
			fi
		;;
		--no-formatting)
			shift
		;;
		*)
			[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $(printf '%q ' "$@")" >&2
			if [ -t 1 ] && command -v column >/dev/null 2>&1; then
				AllActions --no-formatting "$@" | column -t
				return 0
			fi
		;;
	esac

	local sedEx=

	. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/SystemContext.UseStandardOptions.include"
	while [ $# -gt 0 ]; do
		case "$1" in
			--completion)
				sedEx="-e 's:^$MMDAPP/source/::' -e 's:^$MDSC_SOURCE/::' -e 's:^.*/actions/::'"
				shift ; break
			;;
			--scripts)
				sedEx="-e \"s:^$MMDAPP/source/::\" -e \"s:^$MDSC_SOURCE/::\""
				shift ;	break
			;;
			--full)
				sedEx="-e 's:^$MMDAPP/source/::' -e 's:^$MDSC_SOURCE/::' -e 's:^\(.*\)/actions/:\1 \1/actions/:'"
				shift ; break
			;;
			--default|--all-actions)
				sedEx="-e 's:^$MMDAPP/source/::' -e 's:^$MDSC_SOURCE/::' -e 's:/actions/: :'"
				break
			;;
			--help|--help-syntax)
				echo "📘 syntax: AllActions.fn.sh --default|--full|--scripts|..." >&2
				echo "📘 syntax: AllActions.fn.sh [--help]" >&2
				if [ "$1" = "--help" ] ; then
					cat "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/help/Help.AllActions.text" >&2
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

		local cacheFile="$MDSC_CACHED/distro-actions.txt"
		local buildDate="$MDSC_CACHED/build-time-stamp.txt"

		if [ -f "$cacheFile" ] && [ -f "$buildDate" ] && [ ! "$cacheFile" -ot "$buildDate" ] ; then
			[ -z "$MDSC_DETAIL" ] || echo "| $MDSC_CMD: using cached ($MDSC_OPTION)" >&2
			eval sed "$sedEx" "$cacheFile"
			return 0
		fi

		[ -z "$MDSC_DETAIL" ] || echo "$MDSC_CMD: caching all actions ($MDSC_OPTION)" >&2
		. "$MDLT_ORIGIN/myx/myx.distro-source/sh-lib/source-context/ScanSourceActions.include" \
		| tee "$cacheFile.$$.tmp" | eval sed "$sedEx"
		mv -f "$cacheFile.$$.tmp" "$cacheFile"
		return 0

	fi
	
	. "$MDLT_ORIGIN/myx/myx.distro-source/sh-lib/source-context/ScanSourceActions.include" | eval sed "$sedEx"
}

case "$0" in
	*/sh-scripts/AllActions.fn.sh) 

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-system/sh-lib/SystemContext.include"
			DistroSystemContext --distro-path-auto
		fi

		if [ -z "$1" ] || [ "$1" = "--help" ] ; then
			AllActions "${1:-"--help-syntax"}"
			exit 1
		fi

		AllActions "$@"
	;;
esac
