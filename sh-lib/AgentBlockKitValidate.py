#!/usr/bin/env python3

# Block Kit top-level type validator for DistroAgentsTools.fn.sh's --member-slack-send-message
# --format blocks path (myx.distro-system/sh-scripts/DistroAgentsTools.fn.sh).
# Reads a JSON array on stdin -- already confirmed syntactically valid JSON and
# array-shaped by the caller -- and prints a comma-joined list of array indices
# whose element is not a dict, or whose "type" is not one of Slack's real
# top-level block types, to stdout. Prints nothing on success. Always exits 0;
# the caller inspects stdout content, not the exit code, to detect a failure.

import json, sys
VALID = {"section","divider","header","context","image","actions","input","video","rich_text","file"}
try:
	blocks = json.load(sys.stdin)
except Exception:
	sys.exit(0)  # syntax already confirmed valid above; nothing to add here
if not isinstance(blocks, list):
	sys.exit(0)  # array shape already confirmed above
bad = [str(i) for i, b in enumerate(blocks) if not isinstance(b, dict) or b.get("type") not in VALID]
if bad:
	print(",".join(bad))
