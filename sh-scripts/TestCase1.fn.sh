#!/usr/bin/env bash

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )
fi

if [ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext >/dev/null 2>&1 ; then
	. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-system/sh-lib/SystemContext.include"
	DistroSystemContext --distro-path-auto
fi

echo "Test >>"
DistroSystemContext --unroll-filter-index-provides ndci-common-hook: column -t
DistroSystemContext --unroll-filter-index-provides image-prepare:sync-source-files: column -t

ListDistroProvides.fn.sh --all-unroll-filter-and-cut ndci-common-hook: column -t
ListDistroProvides.fn.sh --all-unroll-filter-and-cut image-prepare:sync-source-files: column -t

echo "Test >>"
DistroSystemContext --unroll-filter-index-declares ndci-common-hook: column -t
DistroSystemContext --unroll-filter-index-declares image-prepare:sync-source-files: column -t

#DistroSystemContext --unroll-filter-index-provides-merged ndci-common-hook: cat
#DistroSystemContext --unroll-filter-index-declares-merged distro-image-sync:source-prepare-pull:list: cat

#DistroSystemContext --unroll-filter-index-declares-merged distro-image-sync:source-prepare-pull:list: cat
