#!/usr/bin/env python3

# Upserts the "myx" stdio MCP server entry into a JSON config file, for
# DistroAgentsTools.fn.sh's --owner-install-vscode-integrations
# (myx.distro-system/sh-lib/AgentsTools.Owner.include), externalized per
# this package's own externalize-awk/py convention (see
# AgentBoardItemFrontmatterPrint.awk's own header comment for that name).
#
# argv[1]: path to the JSON config file to upsert into (created if it
#   doesn't exist yet). argv[2]: path to the myx MCP server script
#   (agentMcpServer.sh) to register as the "myx" entry's stdio command.
#   argv[3]: top-level object key the server entry lives under -- "servers"
#   for VS Code/Copilot-Chat's .vscode/mcp.json schema, "mcpServers" for
#   Claude Code's own .mcp.json project-scope schema. Same script,
#   parameterized by target path + key name via argv, since the caller
#   .include runs this once per target in its own mcpTarget loop.
#
# Non-destructive to unrelated entries: only the "myx" key under the given
# top-level key is set/overwritten -- every other existing server entry,
# and the rest of the file's top-level object, is preserved as-is. Writes
# via a temp file + atomic os.replace. Prints "OK" to stdout on success.

import json
import os
import sys

path = sys.argv[1]
server_script = sys.argv[2]
key = sys.argv[3]

data = {}
if os.path.exists(path):
	with open(path, "r", encoding="utf-8") as f:
		raw = f.read().strip()
	if raw:
		data = json.loads(raw)

if not isinstance(data, dict):
	raise SystemExit("%s top-level must be an object" % path)

servers = data.get(key)
if servers is None:
	servers = {}
if not isinstance(servers, dict):
	raise SystemExit("%s '%s' must be an object" % (path, key))

servers["myx"] = {
	"type": "stdio",
	"command": server_script,
}
data[key] = servers

tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
	json.dump(data, f, indent=2, ensure_ascii=True)
	f.write("\n")
os.replace(tmp, path)
print("OK")
