#!/usr/bin/env bash

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )
fi

ListDistroScripts(){
set -x
	case "$1" in
		--completion)
			shift
			( \
				ListDistroScripts "$@" ; \
			) | sort -u | sed 's:\.fn\.sh$::' 
			return 0
		;;
		--all)
			shift
			local FILTER="$MMDAPP/source/"
			case "$MDSC_OPTION" in
				--distro-from-distro)
					local MDPATH="$MDLT_ORIGIN/myx/myx.distro-deploy/sh-scripts $MDLT_ORIGIN/myx/myx.distro-source/sh-scripts $MDLT_ORIGIN/myx/myx.distro-system/sh-scripts"
				;;
				--distro-from-output)
					local MDPATH="$MDLT_ORIGIN/myx/myx.distro-deploy/sh-scripts $MDLT_ORIGIN/myx/myx.distro-source/sh-scripts $MDLT_ORIGIN/myx/myx.distro-system/sh-scripts"
				;;
				*)
					local MDPATH="$MDLT_ORIGIN/myx/myx.distro-system/sh-scripts $MDLT_ORIGIN/myx/myx.distro-source/sh-scripts $MDLT_ORIGIN/myx/myx.distro-deploy/sh-scripts"
				;;
			esac
		;;
		--type)
			shift
			local MDTYPE="$1" ; shift
			local MDPATH="$MDLT_ORIGIN/myx/myx.distro-$MDTYPE/sh-scripts"
			if [ ! -d "$MDPATH" ] ; then
				echo "⛔ ERROR: ListDistroScripts: invalid type: $MDTYPE" >&2
				set +e ; return 1
			fi
			[ system="$MDTYPE" ] || MDPATH="$MDPATH $MDLT_ORIGIN/myx/myx.distro-system/sh-scripts"
			local FILTER="$MDPATH/"
		;;
		*)
			echo "⛔ ERROR: $MDSC_CMD: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
	find \
			$MDPATH \
			 -type 'f' -name '*.sh' \
		| sed "s:^$FILTER::g" | sort
}

case "$0" in
	*/sh-scripts/ListDistroScripts.fn.sh) 
		if [ "${1:-'--help'}" = "--help" ] ; then
			echo "📘 syntax: ListDistroScripts.fn.sh --all/--completion" >&2
			echo "📘 syntax: ListDistroScripts.fn.sh --type <source/deploy>" >&2
			echo "📘 syntax: ListDistroScripts.fn.sh [--help]" >&2
			exit 1
		fi
		
		ListDistroScripts "$@"
	;;
esac
