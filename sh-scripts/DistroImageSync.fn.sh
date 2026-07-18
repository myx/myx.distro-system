#!/usr/bin/env bash

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/.local" ] || ( echo "⛔ ERROR: expecting '.local' directory." >&2 && exit 1 )
fi


DistroImageSync(){
	local MDSC_CMD='DistroImageSync'
	set -e

	case "$1" in
		--intern-print-all-tasks)
			[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $MDSC_NO_CACHE $MDSC_NO_INDEX $@" >&2

			local projectName buildStage syncOperation targetSpec sourceSpec extra
			Distro ListDistroDeclares --all-filter-and-cut "distro-image-sync" \
			| sed -e 's/:/ /' -e 's/:/ /' -e 's/:/ /' \
			| while read -r projectName buildStage syncOperation targetSpec sourceSpec extra ; do
				echo "$buildStage" "$projectName" "$syncOperation" "$targetSpec" "$sourceSpec" "$extra"
			done
			return 0
		;;
		--intern-print-unroll-tasks-from-stdin)
			[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $MDSC_NO_CACHE $MDSC_NO_INDEX $@" >&2

			local projectName buildStage syncOperation targetSpec sourceSpec extra
			while read -r buildStage projectName syncOperation targetSpec sourceSpec extra ; do
				if [ "." = "$targetSpec" ] ; then
					targetSpec="$projectName"
				fi
				case "$syncOperation" in
					repo)
						echo "$buildStage" "$projectName" "$syncOperation" "${targetSpec%%/}" "$sourceSpec" "$extra"
					;;
					list)
						local listFile="$MDSC_SOURCE/$targetSpec/$sourceSpec"
						if [ ! -f "$listFile" ] ; then
							echo "🙋 WARNING: $MDSC_CMD: no repo list ($listFile) found for $projectName $buildStage:repo directive (ignoring)!" >&2
							continue
						fi

						local targetSpec sourceUrl sourceBranch
						cat "$listFile" \
						| while read -r targetSpec sourceUrl sourceBranch ; do
							if [ "${targetSpec:0:1}" == "#" ] || [ -z "$targetSpec" ] || [ -z "$sourceUrl" ] ; then
								continue
							fi
							echo "$buildStage" "$projectName" "repo" "${targetSpec%%/}" "$sourceBranch:$sourceUrl" "$extra"
						done
					;;
					*)
						# echo "$MDSC_CMD: unknown sync operation: $syncOperation" >&2
					;;
				esac
			done | awk '$0 && !x[$0]++'
			return 0
		;;
		--intern-print-tasks-from-stdin-repo-list)
			[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $MDSC_NO_CACHE $MDSC_NO_INDEX $@" >&2

			local useStage="${useStage:-source-prepare-pull}"
			local targetSpec sourceSpec sourceBranch
			while read -r targetSpec sourceSpec sourceBranch ; do
				echo "$useStage $targetSpec repo $targetSpec $sourceBranch:$sourceSpec"
			done 
			return 0
		;;
		--intern-print-repo-list-from-stdin)
			[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $MDSC_NO_CACHE $MDSC_NO_INDEX $@" >&2

			local projectName buildStage syncOperation targetSpec sourceSpec extra
			while read -r buildStage projectName syncOperation targetSpec sourceSpec extra ; do
				case "$syncOperation" in
					repo)
						if [ "." = "$targetSpec" ] ; then
							targetSpec="$projectName"
						fi
						local sourceBranch sourceUrl
						echo "*$sourceSpec" | sed 's/:/ /' | if read -r sourceBranch sourceUrl ; then
							if [ -z "$sourceUrl" ] ; then
								echo "🙋 WARNING: $MDSC_CMD: no repo url spec in $projectName $buildStage:repo directive (ignoring)!" >&2
								continue
							fi
							echo "${targetSpec%%/}" "$sourceUrl" "${sourceBranch:1}"
						fi
					;;
					*)
						# echo "$MDSC_CMD: unknown sync operation: $syncOperation" >&2
					;;
				esac
			done | awk '$0 && !x[$0]++'
			return 0
		;;
		--intern-check-build-stage)
			[ "$MDSC_DETAIL" == "full" ] || echo "> $MDSC_CMD $MDSC_NO_CACHE $MDSC_NO_INDEX $@" >&2

			shift
			case "$1" in
				source-prepare-pull|source-process-push|image-prepare-pull|image-process-push|image-install-pull)
					useStage="$1"
					return 0
				;;
			esac
			echo "⛔ ERROR: $MDSC_CMD: invalid build-stage: $1" >&2
			set +e ; return 1
		;;
		--intern-print-script-from-stdin-task-list)
			[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $MDSC_NO_CACHE $MDSC_NO_INDEX $@" >&2

			shift
			. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/DistroImage.SyncScriptMaker.include"
			return 0
		;;
		--intern-execute-script-from-stdin)
			[ "$MDSC_DETAIL" == "full" ] || echo "> $MDSC_CMD $MDSC_NO_CACHE $MDSC_NO_INDEX $@" >&2
			( eval "$( cat )" )
			return 0
		;;
	esac

	[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $(printf '%q ' "$@")" >&2

	. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/SystemContext.UseStandardOptions.include"
	case "$1" in
			''|--help|--help-syntax)
				echo "📘 syntax: DistroImageSync.fn.sh [<options>] --print-all-tasks" >&2
				echo "📘 syntax: DistroImageSync.fn.sh [<options>] <project-selector> <operation>" >&2
				echo "📘 syntax: DistroImageSync.fn.sh [<options>] --all-tasks --{print|execute}-source-{prepare-pull|process-push}" >&2
				echo "📘 syntax: DistroImageSync.fn.sh [<options>] --all-tasks --{print|execute}-image-{prepare-pull|process-push}" >&2
				echo "📘 syntax: DistroImageSync.fn.sh [<options>] --all-tasks <operation>" >&2
				echo "📘 syntax: DistroImageSync.fn.sh [--help]" >&2
				if [ "$1" = "--help" ] ; then
					. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/help/HelpSelectProjects.include"
					. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/help/Help.DistroImageSync.include"
				fi
				return 1
			;;
	esac

	local useJobList=""
	local useStage=""

	while true ; do
		. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/SystemContext.UseStandardOptions.include"
		case "$1" in
			--all-tasks)
				shift
				useJobList="$( \
					DistroImageSync --intern-print-all-tasks \
					| DistroImageSync --intern-print-unroll-tasks-from-stdin
				)"
				break
			;;
			--explicit-noop)
				shift
				break
			;;
			--select-from-env)
				shift
				if [ -z "${MDSC_SELECT_PROJECTS:0:1}" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: --select-from-env no projects selected!" >&2
					set +e ; return 1
				fi

				[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD selected projects: $( echo $MDSC_SELECT_PROJECTS )" >&2

				useJobList="$( \
					DistroImageSync --intern-print-all-tasks \
					| DistroImageSync --intern-print-unroll-tasks-from-stdin \
					| awk -v filter="$( echo $MDSC_SELECT_PROJECTS )" '
						BEGIN {
							split(filter, keep, " ")
						}
						{
							for (i in keep) {
								if (index(keep[i] "/", $4 "/") == 1) {
									print
									break
								}
							}
						}
					' \
				)"

				break
			;;
			--print-all-tasks)
				shift
				if [ -n "$1" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: no options allowed after --all-declares option ($MDSC_OPTION, $@)" >&2
					set +e ; return 1
				fi

				DistroImageSync --intern-print-all-tasks \
				| DistroImageSync --intern-print-unroll-tasks-from-stdin \
				| sort -k4

				return 0
			;;
			--list-orphaned-projects)
				shift
				if [ -n "$1" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: no options allowed after --list-orphaned-projects option ($MDSC_OPTION, $@)" >&2
					set +e ; return 1
				fi

				local knownProjects

				knownProjects="$( \
					DistroImageSync --intern-print-all-tasks \
					| DistroImageSync --intern-print-unroll-tasks-from-stdin \
					| DistroImageSync --intern-print-repo-list-from-stdin \
					| awk '{ print $1 }' \
					| sort -u \
				)"

				awk '
					NR==FNR { if ($0 != "") covered[$0]=1; next }
					{
						proj = $0
						for (t in covered) {
							if (proj == t || index(proj, t "/") == 1) next
						}
						print proj
					}
				' \
					<( printf '%s\n' "$knownProjects" ) \
					<( Distro ListDistroProjects --all-projects | sort -u )

				return 0
			;;
			--script-prune-orphaned-projects)
				shift
				if [ -n "$1" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: no options allowed after --script-prune-orphaned-projects option ($MDSC_OPTION, $@)" >&2
					set +e ; return 1
				fi

				local orphanPath

				DistroImageSync --list-orphaned-projects \
				| while read -r orphanPath ; do
					if [ ! -d "$MDSC_SOURCE/$orphanPath/.git" ] ; then
						printf '# skip (no-git): %q\n' "$MDSC_SOURCE/$orphanPath"
					elif [ -z "$( git -C "$MDSC_SOURCE/$orphanPath" status --porcelain 2>/dev/null )" ] ; then
						printf 'rm -rf %q\n' "$MDSC_SOURCE/$orphanPath"
					else
						printf '# skip (dirty): %q\n' "$MDSC_SOURCE/$orphanPath"
					fi
				done

				return 0
			;;
			--script-from-stdin-repo-list)
				shift
				(
					export useStage="stdin-repo-list-pull"
					export syncMode="${1:---parallel}"
					DistroImageSync --intern-print-tasks-from-stdin-repo-list \
					| DistroImageSync --intern-print-script-from-stdin-task-list "$@"
				)
				return 0
			;;
			--execute-from-stdin-repo-list)
				shift
				( 
					export useStage="stdin-repo-list-pull"
					export syncMode="${1:---parallel}"
					eval "$( DistroImageSync --script-from-stdin-repo-list )" 
				)
				return 0
			;;
			--print-*|--script-*|--execute-*)
				break
			;;
			--*)
				Distro ListDistroProjects --select-execute-default DistroImageSync "$@"
				return 0
			;;
			*)
				break;
			;;
		esac
	done

	while true ; do
		case "$1" in
			--print-tasks)
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: no options allowed after $1 ($MDSC_OPTION, $@)" >&2
					set +e ; return 1
				fi

				shift
			
				echo "$useJobList"
				
				return 0
			;;
			--print-repo-list)
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: no options allowed after $1 ($MDSC_OPTION, $@)" >&2
					set +e ; return 1
				fi

				shift
				
				echo "$useJobList" \
				| DistroImageSync --intern-print-repo-list-from-stdin \
				| sort -k4
				
				return 0
			;;
			--print-*)
				if [ -n "$2" ] ; then
					echo "⛔ ERROR: $MDSC_CMD: no options allowed after $1 option ($MDSC_OPTION, $@)" >&2
					set +e ; return 1
				fi

				local selectVariant="${1#--print-}"
				DistroImageSync --intern-check-build-stage "$selectVariant"
				shift
				
				
				echo "$useJobList" \
				| grep -e "^${selectVariant}"
				
				return 0
			;;
			--script-*)
				local selectVariant="${1#--script-}"
				DistroImageSync --intern-check-build-stage "$selectVariant"
				shift
				
				echo "$useJobList" \
				| grep -e "^${selectVariant}" \
				| DistroImageSync --intern-print-script-from-stdin-task-list "$@"
				
				return 0
			;;
			--execute-*)
				local selectVariant="${1#--execute-}"
				DistroImageSync --intern-check-build-stage "$selectVariant"
				shift
				
				echo "$useJobList" \
				| grep -e "^${selectVariant}" \
				| DistroImageSync --intern-print-script-from-stdin-task-list "$@" \
				| DistroImageSync --intern-execute-script-from-stdin
				
				return 0
			;;
			'')
				echo "⛔ ERROR: $MDSC_CMD: one of --print-* or --execute-* commands is required" >&2
				set +e ; return 1
			;;
			*)
				echo "⛔ ERROR: $MDSC_CMD: invalid option: ${useCommand:-$1}" >&2
				set +e ; return 1
			;;
		esac
	done
	return 0
}

case "$0" in
	*/sh-scripts/DistroImageSync.fn.sh)
		if [ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-system/sh-lib/SystemContext.include"
			DistroSystemContext --distro-path-auto
		fi

		if [ -z "$1" ] || [ "$1" = "--help" ] ; then
			DistroImageSync ${1:-"--help-syntax"}
			exit 1
		fi
		
		DistroImageSync "$@"
	;;
esac
