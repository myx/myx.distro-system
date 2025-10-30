#!/usr/bin/env bash

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )
fi

AllNamespaces(){

	local MDSC_CMD='AllNamespaces'
	[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $(printf '%q ' "$@")" >&2


	while [ $# -gt 0 ]; do
		. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/SystemContext.UseStandardOptions.include"
		case "$1" in
			--|--all-repositories|--all-namespaces)
				shift ; break
			;;
			--source-namespaces)
				. "$MDLT_ORIGIN/myx/myx.distro-source/sh-lib/source-prepare/ScanSourceNamespaces.include"
				return 0
			;;
			--help|--help-syntax)
				echo "📘 syntax: AllNamespaces.fn.sh --all-namespaces" >&2
				echo "📘 syntax: AllNamespaces.fn.sh [--help]" >&2
				if [ "$1" = "--help" ] ; then
					cat "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/help/Help.AllNamespaces.text" >&2
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

		local cacheFile="$MDSC_CACHED/distro-namespaces.txt"
		local buildDate="$MDSC_CACHED/build-time-stamp.txt"

		if [ -f "$cacheFile" ] && [ -f "$buildDate" ] && [ ! "$cacheFile" -ot "$buildDate" ] ; then
			[ -z "$MDSC_DETAIL" ] || echo "| $MDSC_CMD: using cached ($MDSC_OPTION)" >&2
			cat "$cacheFile"
			return 0
		fi

		echo "$MDSC_CMD: caching repositories ($MDSC_OPTION)" >&2
		. "$MDLT_ORIGIN/myx/myx.distro-source/sh-lib/source-prepare/ScanSourceNamespaces.include" \
		| tee "$cacheFile.$$.tmp"
		mv -f "$cacheFile.$$.tmp" "$cacheFile"
		return 0

	fi
	
	. "$MDLT_ORIGIN/myx/myx.distro-source/sh-lib/source-prepare/ScanSourceNamespaces.include"
}

case "$0" in
	*/sh-scripts/AllNamespaces.fn.sh) 

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-system/sh-lib/SystemContext.include"
			DistroSystemContext --distro-path-auto
		fi

		if [ -z "$1" ] || [ "$1" = "--help" ] ; then
			AllNamespaces "${1:-"--help-syntax"}"
			exit 1
		fi

		AllNamespaces "$@"
	;;
esac
