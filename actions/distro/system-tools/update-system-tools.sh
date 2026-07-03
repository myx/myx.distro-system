#!/bin/sh

[ -d "$MMDAPP/source" ] || ( echo "⛔ ERROR: expecting 'source' directory." >&2 && exit 1 )

cd "$MMDAPP"
export MMDAPP

sh "$MMDAPP/source/myx/myx.distro-system/actions/distro/local-tools/apply-distro-system-2-local.sh"
