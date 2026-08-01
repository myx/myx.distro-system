#!/usr/bin/env python3

# Sequential exact-literal-substring patch applier for
# DistroAgentsTools.fn.sh's --edit-patch-from-stdin body-input mode
# (myx.distro-system/sh-lib/AgentsTools.InternOpBoardUpsertMoveEdit.include),
# externalized per this package's own externalize-awk/py convention (see
# AgentBoardItemFrontmatterPrint.awk's own header comment for that name).
#
# argv[1]: path to a file holding the existing board-item body text (empty
#   file on --create). argv[2]: path to a file holding a JSON array of patch
#   objects: {"old": <text>, "new": <text>, "replace_all": <bool, default
#   false>}. Both are files, not stdin/a single combined argv, because a
#   large/arbitrary body or patch set as a bare argv string risks ARG_MAX
#   and shell-escaping problems -- this script takes the same two-temp-
#   file-plus-argv-paths shape the caller .include already uses for its own
#   headerOpsFile/bodyTmp/tmpFile plumbing.
#
# Applies each patch in order against the result of the previous one --
# same as running several literal-substring edits in sequence. Each `old`
# must match the current text exactly once unless `replace_all` is true, in
# which case every occurrence is replaced. Prints the final text to stdout
# on success -- nothing else on stdout, ever.
#
# On any failure (invalid JSON, wrong shape, `old` not found, `old`
# ambiguous without replace_all) prints exactly one "⛔ ERROR: ..." line to
# stderr, matching this tool family's own error-message shape, and exits 1
# with no stdout output at all -- so the caller's own `body="$( ... )"`
# assignment fails cleanly under `set -e` before any file on disk is
# touched; the original board-item is never partially written.

import json
import sys

PREFIX = "⛔ ERROR: DistroAgentsTools --intern-op-board-upsert-move-edit: --edit-patch-from-stdin:"


def fail(message):
	sys.stderr.write("{} {}\n".format(PREFIX, message))
	sys.exit(1)


def main():
	if len(sys.argv) != 3:
		fail("internal error: expected <content-file> <patch-file> as argv")

	content_path, patch_path = sys.argv[1], sys.argv[2]

	with open(content_path, "r", encoding="utf-8") as f:
		text = f.read()

	with open(patch_path, "r", encoding="utf-8") as f:
		raw = f.read()

	try:
		patches = json.loads(raw) if raw.strip() else []
	except Exception as e:
		fail("invalid JSON: {}".format(e))
		return

	if not isinstance(patches, list):
		fail("patch input must be a JSON array")

	for i, p in enumerate(patches):
		if not isinstance(p, dict) or "old" not in p or "new" not in p:
			fail('patch[{}] must be an object with "old" and "new"'.format(i))
		old, new = p["old"], p["new"]
		replace_all = bool(p.get("replace_all", False))
		if not isinstance(old, str) or not isinstance(new, str):
			fail('patch[{}]: "old"/"new" must be strings'.format(i))
		if old == "":
			fail('patch[{}]: "old" must not be empty'.format(i))
		count = text.count(old)
		if count == 0:
			fail("patch[{}]: old text not found: {!r}".format(i, old))
		if count > 1 and not replace_all:
			fail(
				'patch[{}]: old text matches {} times, not unique -- pass '
				'"replace_all": true or narrow the match: {!r}'.format(i, count, old)
			)
		text = text.replace(old, new) if replace_all else text.replace(old, new, 1)

	sys.stdout.write(text)


if __name__ == "__main__":
	main()