#!/usr/bin/env bash

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )
fi

ListDistroProjects(){
	
	local MDSC_CMD='ListDistroProjects'
	[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $@" >&2

	set -e

	local selectProjects=""

	local executeDefault=""
	
	case "$1" in
		''|--help|--help-syntax)
			echo "📘 syntax: ListDistroProjects.fn.sh --all-projects" >&2
			echo "📘 syntax: ListDistroProjects.fn.sh <project-selector> [<command-options>] [<execute-extra-args>]" >&2
			echo "📘 syntax: ListDistroProjects.fn.sh [--help]" >&2
			if [ "$1" = "--help" ] ; then
				. "$MDLT_ORIGIN/myx/myx.distro-source/sh-lib/help/HelpSelectProjects.include"
				. "$MDLT_ORIGIN/myx/myx.distro-source/sh-lib/help/Help.ListDistroProjects.include"
			fi
			return 0
		;;
	esac
	
	while true ; do
		. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/SystemContext.UseStandardOptions.include"
		case "$1" in
			--select-from-env)
				if [ -z "${MDSC_SELECT_PROJECTS:0:1}" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: $1: no projects selected!" >&2
					set +e ; return 1
				fi
				shift
				local selectProjects="${MDSC_SELECT_PROJECTS}"
				continue
			;;
			--all-projects)
				shift
				[ -z "$1" ] || {
					echo "⛔ ERROR: $MDSC_CMD: --all-projects, no extra options allowed" >&2
					set +e ; return 1
				}
				DistroSystemContext --index-projects cat
				return 0

			;;
			--print-selected)
				shift
				printf '%s\n' "$selectProjects"
				continue
			;;
			--select-all)
				##
				## Replaces selection with 'all projects'
				##
				shift
				local selectProjects
				selectProjects="$( 
					DistroSystemContext --index-projects cat
				)"
				continue
			;;
			--select-sequence)
				##
				## Replaces selection with 'all projects sequence'
				##
				shift
				local selectProjects
				selectProjects="$( 
					DistroSystemContext --index-sequence cat
				)"
				continue
			;;
			--select-none)
				##
				## Replaces selection with 'no projects selected'
				##
				shift
				local selectProjects=
				continue
			;;
			--select-changed)
				##
				## Unions selection with 'changed projects'
				##
				shift
				local selectProjects
				Require ListChangedSourceProjects
				selectProjects="$( 
					awk '$0 && !x[$0]++' \
					<( echo "$selectProjects" ) \
					<( ListChangedSourceProjects $MDSC_NO_CACHE $MDSC_NO_INDEX --all ) 
				)"
				continue
			;;

			#--select-{projects|provides|merged-provides|declares|keywords|merged-keywords|one-project})
			--select-projects|--select-provides|--select-merged-provides|--select-declares|--select-keywords|--select-merged-keywords|--select-one-project)
				## Unions with selection
				local selectVariant="$1" ; shift
				if [ -z "$1" ] ; then
					echo "⛔ ERROR: ListDistroProjects: $selectVariant selectArgument is expected!" >&2
					set +e ; return 1
				fi
				local selectArgument="$1" ; shift

				local matchingProjects # local hides exit-code handling #
				matchingProjects="$( 
					ListDistroProjects $MDSC_NO_CACHE $MDSC_NO_INDEX "-${selectVariant#--select}" "$selectArgument" 
				)"

				if [ -z "$matchingProjects" ] ; then
					echo "ListDistroProjects: 🙋 WARNING: No matching projects found (search: $selectVariant $selectArgument)." >&2
					continue
				fi

				local selectProjects
				selectProjects="$(
					printf "%s\n%s" "$selectProjects" "$matchingProjects" \
					| awk '$0 && !x[$0]++'
				)"
				continue
			;;
			--filter-projects|--filter-provides|--filter-merged-provides|--filter-declares|--filter-keywords|--filter-merged-keywords|--filter-one-project)
				## Intersects with selection
				local selectVariant="$1" ; shift
				if [ -z "$1" ] ; then
					echo "⛔ ERROR: ListDistroProjects: $selectVariant selectArgument is expected!" >&2
					set +e ; return 1
				fi
				local selectArgument="$1" ; shift
				local matchingProjects # local hides exit-code handling #
				matchingProjects="$( 
					ListDistroProjects $MDSC_NO_CACHE $MDSC_NO_INDEX "-${selectVariant#--filter}" "$selectArgument" 
				)"

				if [ -z "$matchingProjects" ] ; then
					echo "ListDistroProjects: 🙋 WARNING: No matching projects found (search: $selectVariant $selectArgument)." >&2
					local selectProjects=
					continue
				fi

				local selectProjects
				selectProjects="$(
					grep -Fx -f \
						<( echo "$matchingProjects" ) \
						<( echo "$selectProjects" ) \
					| awk '$0 && !x[$0]++' 
					#awk 'NR==FNR{ seen[$0]=1; next; } $0 && seen[$0] && !printed[$0]++ { print; }' \
					#	<(printf '%s\n' "$matchingProjects") \
					#	<(printf '%s\n' "$selectProjects")
				)"
				continue
			;;
			--remove-projects|--remove-provides|--remove-merged-provides|--remove-provides|--remove-keywords|--remove-merged-keywords|--remove-one-project)
				## Subtracts from selection
				local selectVariant="$1" ; shift
				if [ -z "$1" ] ; then
					echo "⛔ ERROR: ListDistroProjects: $selectVariant selectArgument is expected!" >&2
					set +e ; return 1
				fi
				local selectArgument="$1" ; shift
				local matchingProjects # local hides exit-code handling #
				matchingProjects="$( 
					ListDistroProjects $MDSC_NO_CACHE $MDSC_NO_INDEX "-${selectVariant#--remove}" "$selectArgument" 
				)"
				
				if [ -z "$matchingProjects" ] ; then
					echo "ListDistroProjects: 🙋 WARNING: No matching projects found (search: $selectVariant $selectArgument)." >&2
					continue
				fi

				local selectProjects
				selectProjects="$(
					grep -Fvx -f \
						<( echo "$matchingProjects" ) \
						<( echo "$selectProjects" ) \
					| awk '$0 && !x[$0]++'

					#awk 'NR==FNR{ seen[$0]=1; next; } $0 && !seen[$0] && !printed[$0]++ { print; }' \
					#	<(printf '%s\n' "$matchingProjects") \
					#	<(printf '%s\n' "$selectProjects")
				)"
				continue
			;;

			--one-project|--project)
				##
				## Prints exactly one project (or fails) whose name matches the glob
				##
				if [ -z "$2" ] ; then
					echo "⛔ ERROR: ListDistroProjects: $1 projectName filter is expected!" >&2
					set +e ; return 1
				fi
				if [ -n "$3" ] ; then
					echo "⛔ ERROR: ListDistroProjects: no options allowed after $1 option ($MDSC_OPTION)" >&2
					set +e ; return 1
				fi

				if [ -f "$MDSC_SOURCE/$2/project.inf" ] ; then # exact match, beats all
					echo "$2"
					return 0
				fi

				local projectFilter="$2" matchedProjects=; shift 2
				
				case "$projectFilter" in
				'.')
					matchedProjects=$(
						DistroSystemContext --index-projects \
						awk -v PWD="$(pwd)" -v BASE="$MDSC_SOURCE" '
						BEGIN {
							rel = PWD
							if (BASE != "" && index(rel, BASE) == 1) rel = substr(rel, length(BASE) + 1)
							if (substr(rel,1,1) == "/") rel = substr(rel,2)
						}
						{
							proj = $0
							if (proj == "") next
							if (rel == proj || index(rel, proj "/") == 1) print proj
						}
					')
					if [ -f "$MDSC_SOURCE/$matchedProjects/project.inf" ] ; then # match, beats all
						echo "$matchedProjects"
						return 0
					fi
				;;
				*)
					matchedProjects="$(
						DistroSystemContext --index-projects \
						awk -v f="$projectFilter" 'index($0,f) && $0 && !seen[$0]++ { print; }'
					)"
				;;
				esac

				if [ -z "$matchedProjects" ] ; then
					echo "ListDistroProjects: ⛔ ERROR: No matching projects found (exactly one requested, --one-project $projectFilter)." >&2
					set +e ; return 1
				fi
				
				if case "$matchedProjects" in *$'\n'*) true;; *) false;; esac; then
				#if [ "$matchedProjects" != "$( echo "$matchedProjects" | head -n 1 )" ] ; then
					echo "ListDistroProjects: ✋ STOP: More than one match (exactly one requested, --one-project $projectFilter): $@" >&2
					echo "$matchedProjects" | sed -e "s|^|        👉 |g" >&2
					set +e ; return 2
				fi

				echo "$matchedProjects"				
				return 0
			;;
			--projects)
				##
				## Prints projects whose name matches the glob
				##
				shift
				if [ -z "$1" ] ; then
					echo "⛔ ERROR: ListDistroProjects: --projects projectName filter is expected!" >&2
					set +e ; return 1
				fi
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: ListDistroProjects: no options allowed after --projects option ($MDSC_OPTION)" >&2
					set +e ; return 1
				fi
				local projectFilter="$1" ; shift

				DistroSystemContext --index-projects \
				awk -v f="$projectFilter" 'index($0,f) && $0 && !seen[$0]++ { print; }'

				return 0
			;;
			--provides)
				##
				## Prints projects whose provides match glob
				##
				shift
				if [ -z "$1" ] ; then
					echo "⛔ ERROR: ListDistroProjects: --provides projectName filter is expected!" >&2
					set +e ; return 1
				fi
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: ListDistroProjects: no options allowed after --provides option ($MDSC_OPTION)" >&2
					set +e ; return 1
				fi
				local providesFilter="$1" ; shift

				case "$providesFilter" in
					*:)
						DistroSystemContext --index-provides \
						awk -v f="$providesFilter" 'index($2,f)==1 && $1 && !seen[$1]++ { print $1 }'
						return 0
					;;
					*)
						DistroSystemContext --index-provides \
						awk -v f="$providesFilter" '$2 == f && $1 && !seen[$1]++ { print $1 }'
						return 0
					;;
				esac
			;;
			--merged-provides)
				##
				## Prints projects whose provides match glob
				##
				##
				## Prints projects whose name matches the glob
				##
				shift
				if [ -z "$1" ] ; then
					echo "⛔ ERROR: ListDistroProjects: --merged-provides projectName filter is expected!" >&2
					set +e ; return 1
				fi
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: ListDistroProjects: no options allowed after --merged-provides option ($MDSC_OPTION)" >&2
					set +e ; return 1
				fi
				local providesFilter="$1" ; shift

				case "$providesFilter" in
					*:)
						DistroSystemContext --index-provides-merged \
						awk -v f="$providesFilter" 'index($3,f)==1 && $1 && !seen[$1]++ { print $1 }'
						return 0
					;;
					*)
						DistroSystemContext --index-provides-merged \
						awk -v f="$providesFilter" '$3 == f && $1 && !seen[$1]++ { print $1 }'
						return 0
					;;
				esac
			;;
			--declares)
				##
				## Prints projects whose declares match glob
				##
				shift
				if [ -z "$1" ] ; then
					echo "⛔ ERROR: ListDistroProjects: --declares projectName filter is expected!" >&2
					set +e ; return 1
				fi
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: ListDistroProjects: no options allowed after --declares option ($MDSC_OPTION)" >&2
					set +e ; return 1
				fi
				local declaresFilter="$1" ; shift

				case "$declaresFilter" in
					*:)
						DistroSystemContext --index-declares \
						awk -v f="$declaresFilter" 'index($2,f)==1 && $1 && !seen[$1]++ { print $1 }'
						return 0
					;;
					*)
						DistroSystemContext --index-declares \
						awk -v f="$declaresFilter" '$2 == f && $1 && !seen[$1]++ { print $1 }'
						return 0
					;;
				esac
			;;
			--keywords)
				##
				## Prints projects whose keywords match glob
				##
				shift
				if [ -z "$1" ] ; then
					echo "⛔ ERROR: ListDistroProjects: --keywords projectName filter is expected!" >&2
					set +e ; return 1
				fi
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: ListDistroProjects: no options allowed after --keywords option ($MDSC_OPTION)" >&2
					set +e ; return 1
				fi
				local keywordsFilter="$1" ; shift

				case "$keywordsFilter" in
					*:)
						DistroSystemContext --index-keywords \
						awk -v f="$keywordsFilter" 'index($2,f)==1 && $1 && !seen[$1]++ { print $1 }'
						return 0
					;;
					*)
						DistroSystemContext --index-keywords \
						awk -v f="$keywordsFilter" '$2 == f && $1 && !seen[$1]++ { print $1 }'
						return 0
					;;
				esac
			;;
			--merged-keywords)
				##
				## Prints projects whose keywords match glob
				##
				shift
				if [ -z "$1" ] ; then
					echo "⛔ ERROR: ListDistroProjects: --keywords projectName filter is expected!" >&2
					set +e ; return 1
				fi
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: ListDistroProjects: no options allowed after --keywords option ($MDSC_OPTION)" >&2
					set +e ; return 1
				fi
				local keywordsFilter="$1" ; shift

				case "$keywordsFilter" in
					*:)
						DistroSystemContext --index-keywords-merged \
						awk -v f="$keywordsFilter" 'index($3,f)==1 && $1 && !seen[$1]++ { print $1 }'
						return 0
					;;
					*)
						DistroSystemContext --index-keywords-merged \
						awk -v f="$keywordsFilter" '$3 == f && $1 && !seen[$1]++ { print $1 }'
						return 0
					;;
				esac
			;;

			--select-required|--select-affected|--select-required-projects|--select-affected-projects)
				## Adds projects required or affected by current selection
				[ full != "$MDSC_DETAIL" ] || echo "* ListDistroProjects: $1, selected: $( echo $selectProjects )" >&2

				local selectVariant="--${1#--select-}" ; shift

				selectProjects="$( 
					MDSC_SELECT_PROJECTS="$selectProjects" ListDistroProjects --select-from-env $selectVariant 
				)"
				continue
			;;
			--required|--required-projects)
				shift
				DistroSystemContext --index-sequence-merged awk -v list="$( printf '%s ' $selectProjects )" '
					BEGIN {
						n = split(list, arr, " ")
						for (i = n; i > 0; i--) keys[arr[i]] = 1
					}
					($1 in keys) && !seen[$2]++ { print $2 }
				'
				return 0
			;;
			--affected|--affected-projects)
				shift
				DistroSystemContext --index-sequence-merged awk -v list="$( printf '%s ' $selectProjects )" '
					BEGIN {
						n = split(list, arr, " ")
						for (i = n; i > 0; i--) keys[arr[i]] = 1
					}
					($2 in keys) && !seen[$1]++ { print $1 }
				'
				return 0
			;;

			--select-execute-default)
				shift
				if [ -z "$1" ] ; then
					echo "⛔ ERROR: ListDistroProjects: --select-execute-default command is expected!" >&2
					set +e ; return 1
				fi
				local executeDefault="$1" ; shift
				continue
			;;
			--select-execute-command)
				shift
				if [ -z "$1" ] ; then
					echo "⛔ ERROR: ListDistroProjects: --select-execute-command command is expected!" >&2
					set +e ; return 1
				fi
				local executeCommand="$1" ; shift

				export MDSC_SELECT_PROJECTS="$selectProjects"
				$executeCommand --select-from-env $MDSC_NO_CACHE $MDSC_NO_INDEX "$@"
				return 0
			;;
			*)
				if [ -z "$executeDefault" ] ; then
					if [ -z "$1" ] ; then
						echo "$selectProjects"
						return 0
					fi

					echo "⛔ ERROR: ListDistroProjects: invalid option ($1), expecting <command name> <args...>: $1" >&2
					set +e ; return 1
				fi
				export MDSC_SELECT_PROJECTS="$selectProjects"
				[ -z "$MDSC_DETAIL" ] || echo "* ListDistroProjects:" $executeDefault --select-from-env $MDSC_NO_CACHE $MDSC_NO_INDEX "$@" >&2
				$executeDefault --select-from-env $MDSC_NO_CACHE $MDSC_NO_INDEX "$@"
				return 0
			;;
		esac
	done
}

case "$0" in
	*/sh-scripts/ListDistroProjects.fn.sh) 
		set -e 

		if [ -z "$1" ] || [ "$1" = "--help" ] ; then
			ListDistroProjects "${1:-"--help-syntax"}"
			exit 1
		fi
		
		if [ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-system/sh-lib/SystemContext.include"
			DistroSystemContext --distro-path-auto
		fi
		
		ListDistroProjects "$@"
	;;
esac
