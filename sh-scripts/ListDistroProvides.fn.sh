#!/usr/bin/env bash

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )
fi

ListDistroProvides(){
	local MDSC_CMD='ListDistroProvides'
	[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $(printf '%q ' "$@")" >&2

	. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/SystemContext.UseStandardOptions.include"

	set -e

	while [ $# -gt 0 ]; do
		case "$1" in
			--all-*|--add-*-column)
				break
			;;
			--explicit-noop)
				shift; break
			;;
			--select-from-env)
				if [ -z "${MDSC_SELECT_PROJECTS:0:1}" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1: no projects selected!" >&2
					set +e ; return 1
				fi
				shift; break
			;;
			--*)
				Distro ListDistroProjects --select-execute-default ListDistroProvides "$@"
				return 0
			;;
			*)
				break
			;;
		esac
	done

	local indexColumns=""

	while [ $# -gt 0 ]; do
		. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/SystemContext.UseStandardOptions.include"
		case "$1" in
			--all-provides)
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1: no extra options allowed ($MDSC_OPTION, $@)" >&2
					set +e ; return 1
				fi
				shift

				DistroSystemContext --index-provides cat
				return 0
			;;
			--all-provides-merged)
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1: no extra options allowed ($MDSC_OPTION, $@)" >&2
					set +e ; return 1
				fi
				shift

				DistroSystemContext --index-provides-merged cat
				return 0
			;;
			--add-own-provides-column|--filter-own-provides-column|--add-merged-provides-column|--filter-merged-provides-column)
				if [ -z "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1 project provides filter is expected!" >&2
					set +e ; return 1
				fi
				local columnOp=${1%"-provides-column"} columnMatch="$2"; shift 2
				
				local indexCurrent indexFiltered indexColumns

				# currently selected projects, 1 column, or iterative ++ columns
				indexCurrent="$(
					[ -z "${indexColumns:0:1}" ] || { echo "$indexColumns"; return 0; }
					[ -z "${MDSC_SELECT_PROJECTS:0:1}" ] || { echo "$MDSC_SELECT_PROJECTS"; return 0; }
					DistroSystemContext --index-projects cat
				)"

				case "${columnMatch}:${columnOp}" in
					*::--add-own|*::--filter-own)
						indexFiltered="$(
							DistroSystemContext --index-provides \
							awk -v m="$columnMatch" '
								index($2,m)==1 {
									ro=$1 " " substr($2,length(m)+1)
									if (!x[ro]++) print ro
								}
							'
						)"
					;;
					*::--add-merged|*::--filter-merged)
						indexFiltered="$(
							DistroSystemContext --index-provides-merged \
							awk -v m="$columnMatch" '
								index($3,m)==1 {
									rm=$1 " " substr($3,length(m)+1)
									if (!x[rm]++) print rm
								}
							'
						)"
					;;
					*:--add-own|*:--filter-own)
						indexFiltered="$(
							DistroSystemContext --index-provides \
							awk -v m="$columnMatch" '
								$2==m && !x[$0]++ { print; }
							'
						)"
					;;
					*:--add-merged|*:--filter-merged)
						indexFiltered="$(
							DistroSystemContext --index-provides-merged \
							awk -v m="$columnMatch" '
								$3==m { r= $1 " " $3; if (!x[r]++) print r; }
							'
						)"
					;;
				esac

				case "$columnOp" in
					--add-own|--add-merged)
						indexFiltered="$(
							awk '
								NR==FNR {
									{ print $1, $2; map[$1]=1 }
									next
								}
								!($1 in map) && !seen[$1]++ { print $1 " -" }
							' \
							<(printf "%s\n" "$indexFiltered") \
							<(printf "%s\n" "$indexCurrent")
						)"
					;;
				esac

				indexColumns="$(
					awk '
						NR==FNR { key[$1]= (key[$1] ? key[$1] "|" $2 : $2); next }
						$1 in key {
							out = $0 " " key[$1]
							if (!seen[out]++) print out
						}
					' \
						<(printf "%s\n" "$indexFiltered") \
						<(printf "%s\n" "$indexCurrent")
				)"
				
				if [ -z "$indexColumns" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: ${columnOp}-provides-column $columnMatch no projects selected!" >&2
					set +e ; return 1
				fi

				continue
			;;
			--all-filter-and-cut)
				if [ -z "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1 project provides filter is expected!" >&2
					set +e ; return 1
				fi
				local filter="$2"; shift 2
				# DistroSystemContext --filter-index-provides "${filter}" cat
				DistroSystemContext --index-provides awk -v f="${filter%':'}:" '
				{
					if (index($2, f) == 1) {
						out = $1 " " substr($2, length(f) + 1)
						if (!seen[out]++) print out
					}
				}
				'
				return 0
			;;
			--filter-and-cut)
				if [ -z "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1 project provides filter is expected!" >&2
					set +e ; return 1
				fi
				local filter="$2"; shift 2
				# DistroSystemContext --intersect-filter-index-provides MDSC_SELECT_PROJECTS "${filter}" cat
				DistroSystemContext --intersect-index-provides MDSC_SELECT_PROJECTS awk -v f="${filter%':'}:" '
				{
					if (index($2, f) == 1) {
						out = $1 " " substr($2, length(f) + 1)
						if (!seen[out]++) print out
					}
				}
				'
				return 0
			;;
			--all-unroll-filter-and-cut)
				if [ -z "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1 project provides filter is expected!" >&2
					set +e ; return 1
				fi
				local filter="$2"; shift 2
				DistroSystemContext --unroll-filter-index-provides "${filter}" "$@"
				return 0
			;;
			--unroll-filter-and-cut)
				if [ -z "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1 project provides filter is expected!" >&2
					set +e ; return 1
				fi
				local filter="$2"; shift 2
				DistroSystemContext --intersect-unroll-filter-index-provides MDSC_SELECT_PROJECTS "${filter%':'}:" "$@"
				return 0
			;;
			--unroll-filter-and-cut-merged)
				if [ -z "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1 project provides filter is expected!" >&2
					set +e ; return 1
				fi
				local filter="$2"; shift 2
				DistroSystemContext --intersect-unroll-filter-index-provides-merged MDSC_SELECT_PROJECTS "${filter%':'}:" "$@"
				return 0
			;;
			--merge-sequence)
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1: no extra options allowed ($MDSC_OPTION, $@)" >&2
					set +e ; return 1
				fi
				if [ -z "${MDSC_SELECT_PROJECTS:0:1}" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1, no projects selected!" >&2
					set +e ; return 1
				fi
				shift

				DistroSystemContext --intersect-index-provides-merged MDSC_SELECT_PROJECTS awk '
					!x[$3]++ { print $0; }
				'
				return 0
			;;
			*)
				echo "⛔ ERROR: $MDSC_CMD: invalid option: $1" >&2
				set +e ; return 1
			;;
		esac
	done

	if [ -n "$indexColumns" ] ; then
		echo "$indexColumns"
		return 0
	fi
	if [ -z "${MDSC_SELECT_PROJECTS:0:1}" ] ; then
		echo "⛔ ERROR: $MDSC_CMD: no projects selected!" >&2
		set +e ; return 1
	fi

	DistroSystemContext --intersect-index-provides MDSC_SELECT_PROJECTS cat
	return 0
}

case "$0" in
	*/sh-scripts/ListDistroProvides.fn.sh)

		if [ -z "$1" ] || [ "$1" = "--help" ] ; then
			echo "📘 syntax: ListDistroProvides.fn.sh --all-provides" >&2
			echo "📘 syntax: ListDistroProvides.fn.sh --all-provides-merged" >&2
			echo "📘 syntax: ListDistroProvides.fn.sh <project-selector> [--merge-sequence] [<options>]" >&2
			echo "📘 syntax: ListDistroProvides.fn.sh [--help]" >&2
			if [ "$1" = "--help" ] ; then
				. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/help/HelpSelectProjects.include"
				. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/help/Help.ListDistroProvides.include"
			fi
			exit 1
		fi

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-system/sh-lib/SystemContext.include"
			DistroSystemContext --distro-path-auto
		fi

		ListDistroProvides "$@"
	;;
esac
