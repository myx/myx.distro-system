#!/bin/sh

[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )
[ -d "$MMDAPP/.local" ] || ( echo "⛔ ERROR: expecting '.local' directory." >&2 && exit 1 )

for PROJECT in \
	"myx/myx.distro-system" \
; do

	if [ ! -d "$MMDAPP/source/$PROJECT" ] ; then
		echo "🙋 WARNING: expecting 'source' directory ($MMDAPP/source/$PROJECT) is not available." >&2
		continue
	fi

	if [ ! -d "$MMDAPP/.local/$PROJECT" ] ; then
		echo "🙋 WARNING: expecting '.local' directory ($MMDAPP/.local/$PROJECT) is not available." >&2
		continue
	fi

	echo "SYNC: 'source/$PROJECT/' --> '.local/$PROJECT'" >&2
	rsync -rltOoDi "$MMDAPP/source/$PROJECT/" "$MMDAPP/.local/$PROJECT"
	# rsync -rltOoDi --delete "$MMDAPP/source/$PROJECT/" "$MMDAPP/.local/$PROJECT"

done

echo "DONE: $0 all done, .local packages updated." >&2
