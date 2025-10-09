#!/usr/bin/env bash

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )
fi

ListDistroDeclares(){
	local MDSC_CMD='ListDistroDeclares'
	[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $@" >&2

	. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/SystemContext.UseStandardOptions.include"

	set -e
	
	while true ; do
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
			--set-env)
				shift
				if [ -z "$1" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: --set-env env variable argument expected!" >&2
					set +e ; return 1
				fi
				local envName="$1" ; shift
				eval "$envName='` $MDSC_CMD --explicit-noop "$@" `'"
				return 0
			;;
			--*)
				Distro ListDistroProjects --select-execute-default ListDistroDeclares "$@"
				return 0
			;;
			*)
				break
			;;
		esac
	done

	local indexColumns=""

	while true ; do
		. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/SystemContext.UseStandardOptions.include"
		case "$1" in
			--all-declares)
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1: no extra options allowed ($MDSC_OPTION, $@)" >&2
					set +e ; return 1
				fi
				shift

				DistroSystemContext --index-declares cat
				return 0
			;;
			--all-declares-merged)
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1: no extra options allowed ($MDSC_OPTION, $@)" >&2
					set +e ; return 1
				fi
				shift

				DistroSystemContext --index-declares-merged cat
				return 0
			;;
			--add-own-declares-column|--filter-own-declares-column|--add-merged-declares-column|--filter-merged-declares-column)
				if [ -z "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1 project declares filter is expected!" >&2
					set +e ; return 1
				fi
				local columnOp=${1%"-declares-column"} columnMatch="$2"; shift 2

				local indexCurrent indexFiltered indexColumns

				# currently selected projects, 1 column, or iterative ++ columns
				indexCurrent="$(
					[ -z "${indexColumns:0:1}" ] || { echo "$indexColumns"; return 0; }
					[ -z "${MDSC_SELECT_PROJECTS:0:1}" ] || { echo "$MDSC_SELECT_PROJECTS"; return 0; }
					DistroSystemContext --index-projects cat
				)"

				indexFiltered="`
					case "${columnMatch}:${columnOp}" in
						*::--add-own|*::--filter-own)
							DistroSystemContext --index-declares \
							awk -v m="$columnMatch" 'index($2,m)==1 { ro=$1 " " substr($2,length(m)+1); if (!x[ro]++) print ro; }'
						;;
						*::--add-merged|*::--filter-merged)
							DistroSystemContext --index-declares-merged \
							awk -v m="$columnMatch" 'index($3,m)==1 { rm=$1 " " substr($3,length(m)+1); if (!x[rm]++) print rm; }'
						;;
						*:--add-own|*:--filter-own)
							DistroSystemContext --index-declares \
							awk -v m="$columnMatch" '$2==m && !x[$0]++ { print; }'
						;;
						*:--add-merged|*:--filter-merged)
							DistroSystemContext --index-declares-merged \
							awk -v m="$columnMatch" '$3==m { r= $1 " " $3; if (!x[r]++) print r; }'
						;;
					esac
				`"

				case "$columnOp" in
					--add-own|--add-merged)
						indexFiltered="$(
							awk '
								NR==FNR {
									{ print $1, $2; map[$1]=1 }
									next
								}
								!($1 in map) && !map[$1]++ { print $1, "-" }
							' \
							<(printf "%s\n" "$indexFiltered") \
							<(printf "%s\n" "$indexCurrent")
						)"
					;;
				esac

				indexColumns="`
					awk '
						NR==FNR { key[$1]=$2; next }
						$1 in key {
							out = $0 " " key[$1]
							if (!seen[out]++) print out
						}
					' \
						<(printf "%s\n" "$indexFiltered") \
						<(printf "%s\n" "$indexCurrent")
				`"
				
				if [ -z "$indexColumns" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: ${columnOp}-declares-column $columnMatch no projects selected!" >&2
					set +e ; return 1
				fi

				continue
			;;
			--all-filter-and-cut)
				if [ -z "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1 project declares filter is expected!" >&2
					set +e ; return 1
				fi
				local filter="$2"; shift 2
				DistroSystemContext --index-declares awk -v f="${filter}:" '
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
					echo "⛔ ERROR: $MDSC_CMD: $1 project declares filter is expected!" >&2
					set +e ; return 1
				fi
				local filter="$2"; shift 2
				DistroSystemContext --intersect-index-declares MDSC_SELECT_PROJECTS awk -v f="${filter}:" '
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
					echo "⛔ ERROR: $MDSC_CMD: $1 project declares filter is expected!" >&2
					set +e ; return 1
				fi
				local filter="$2"; shift 2
				DistroSystemContext --unroll-filter-index-declares "${filter}" "$@"
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
				
				DistroSystemContext --select-intersect-index-declares-merged awk '
					!x[$3]++ { print $0; }
				'
				return 0
			;;
			'')
				if [ -n "$indexColumns" ] ; then
					echo "$indexColumns"
					return 0
				fi
				if [ -z "${MDSC_SELECT_PROJECTS:0:1}" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: no projects selected!" >&2
					set +e ; return 1
				fi

				DistroSystemContext --select-intersect-index-declares cat
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
	*/sh-scripts/ListDistroDeclares.fn.sh)
		if [ -z "$1" ] || [ "$1" = "--help" ] ; then
			echo "📘 syntax: ListDistroDeclares.fn.sh [<options>] --all-declares" >&2
			# echo "📘 syntax: ListDistroDeclares.fn.sh [<options>] --all-declares-merged" >&2
			echo "📘 syntax: ListDistroDeclares.fn.sh [<options>] <project-selector> [--merge-sequence]" >&2
			echo "📘 syntax: ListDistroDeclares.fn.sh [--help]" >&2
			if [ "$1" = "--help" ] ; then
				. "$MDLT_ORIGIN/myx/myx.distro-source/sh-lib/help/HelpSelectProjects.include"
				. "$MDLT_ORIGIN/myx/myx.distro-source/sh-lib/help/Help.ListDistroDeclares.include"
			fi
			exit 1
		fi
		
		if [ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-system/sh-lib/SystemContext.include"
			DistroSystemContext --distro-path-auto
		fi

		ListDistroDeclares "$@"
	;;
esac
