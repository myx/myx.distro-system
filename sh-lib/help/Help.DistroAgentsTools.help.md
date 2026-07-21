📘 syntax: DistroAgentsTools.fn.sh --start-console [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]
📘 syntax: DistroAgentsTools.fn.sh --send-console <channel> [-- <command...>]
📘 syntax: DistroAgentsTools.fn.sh --stop-console <channel>
📘 syntax: DistroAgentsTools.fn.sh --list-consoles [--override-workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --agent-config-option <operation>
📘 syntax: DistroAgentsTools.fn.sh --send-message <magic-team|human-owner|<channel>:<ts>> [text...]
📘 syntax: DistroAgentsTools.fn.sh --send-message <target> --message-from-stdin [--format text|blocks]
📘 syntax: DistroAgentsTools.fn.sh --sweep-read-incoming-comms [<magic-team|human-owner|<channel>:<ts>>] [--oldest <ts>]
📘 syntax: DistroAgentsTools.fn.sh --self-test
📘 syntax: DistroAgentsTools.fn.sh --verify-permissions
📘 syntax: DistroAgentsTools.fn.sh [--help]

##  Summary:

		Automates the Keep-Alive Workspace Console Session recipe (see
		magic-coordinator's routines/console-sessions.md): a FIFO plus a
		backgrounded `exec 9>fifo; sleep TTL` holder process keep a
		`DistroSourceConsole.sh`/`DistroDeployConsole.sh --non-interactive`
		session's stdin open indefinitely, so multiple rounds of commands can
		be piped into one console without re-paying the bootstrap cost each
		time. Channel dirs/log paths are deterministic (workspace absolute
		path + console name, hashed with `cksum`) rather than a `mktemp -d`
		random suffix, so the same (workspace, console) pair always resolves
		to the same path across restarts — safe to add once to an allowlist
		(e.g. Claude Code's settings.json) and never invalidated by a new run.

##  Arguments:

		channel
			Channel id (e.g. `myx.distro-agent-console.<slug>.<source|deploy>`)
			as printed by --start-console, or an absolute path to its channel
			directory. Accepted by --send-console and --stop-console.

##  Options:

		--start-console
			Starts (or, for an already-alive channel on the same workspace +
			console, reuses) a Keep-Alive console session. Prints
			CHANNEL/CHANNEL_DIR/FIFO/LOG/CONSOLE/WORKSPACE/HOLDER_PID/CONSOLE_PID
			to stdout. A channel dir that exists but has no live processes is
			wiped and recreated rather than reused.

		--override-workspace <path>
			Target a workspace other than this tool's own ($MMDAPP). Accepted
			by both --start-console and --list-consoles; the two must agree on
			what "own workspace" means, so pass it identically to both.

		--console DistroSourceConsole.sh|DistroDeployConsole.sh
			Pick which console script to start. Default: whichever of
			DistroSourceConsole.sh / DistroDeployConsole.sh exists (executable)
			in the workspace root, tried in that order. DistroLocalConsole.sh
			and DistroRemoteConsole.sh are not supported.

		--ttl <seconds>
			Lifetime of the FIFO-holder process, i.e. how long the channel
			stays open with no traffic before its holder exits and the console
			sees EOF. Default: 3600.

		--send-console <channel> [-- <command...>]
			Sends one command line into an open channel's FIFO. With a
			trailing `-- <command...>`, that argument list (joined with
			spaces) is sent. With no command given, stdin is read and piped
			through as-is (so multi-line input/heredocs work).

		--stop-console <channel>
			Sends `exit` into the channel, then kills the console and
			FIFO-holder processes (TERM, then KILL after a 1s grace period if
			still alive), and removes the channel directory. Safe to call on a
			channel with already-dead processes — cleanup still runs through
			to completion.

		--list-consoles [--override-workspace <path>]
			Lists channels belonging to one workspace (default: this tool's
			own; see --override-workspace) with their console/holder
			liveness. Never lists another workspace's channels unless
			explicitly overridden — this command's scope is intentionally
			per-workspace, not global.

		--agent-config-option <operation>
			Reads/writes this tool's own credential-bearing settings file,
			$MMDAPP/.local/.agents/MDAT.settings.env — one flat
			KEY=VALUE file, no per-consumer split (unlike myx.distro-.local's
			--remote-config-option, which does split per entity: remotes are
			genuinely multiple instances that can share key names; this
			tool's keys, e.g. SLACK_BOT_TOKEN/TRELLO_KEY, are already
			globally unique). Backed by the same shared
			myx.distro-.local/sh-lib/LocalTools.Config.include used by
			DistroLocalTools/DistroSourceTools's --system-config-option, with
			added chmod 700 (dir) / 600 (file) hardening on creation since
			this scope holds real credentials. <operation> is one of:
			--select-all, --select <key>|--all, --select-default <key>
			<default>, --upsert <key> <val>, --upsert-if <key> <val>
			<ifval>, --delete <key>, --delete-if <key> <ifval> — see
			LocalTools.Config.include itself for the authoritative behavior
			of each.

		--send-message <target> [text...]
		--send-message <target> --message-from-stdin [--format text|blocks]
			Posts a message to Slack via chat.postMessage. <target> is
			`magic-team` or `human-owner` (channel id resolved from
			SLACK_CHANNEL_MAGIC_TEAM/SLACK_CHANNEL_HUMAN_OWNER in
			--agent-config-option) or a literal `<channel>:<ts>` string
			(posted as a threaded reply via thread_ts — the caller supplies
			this directly; nothing is looked up by name). Plain trailing
			arguments (or plain stdin) become the `text` field.
			--message-from-stdin --format blocks treats stdin as a raw JSON
			array assigned directly to the `blocks` field (caller-supplied
			Block Kit, not validated/escaped by this command); `text` is set
			to a static fallback string in that case, not derived from the
			blocks' own content. SLACK_BOT_TOKEN is resolved on demand from
			--agent-config-option immediately before the request and is
			never echoed; the constructed request (endpoint, channel,
			payload) is printed to stderr before sending with the token
			itself redacted.

		--sweep-read-incoming-comms [<magic-team|human-owner|<channel>:<ts>>] [--oldest <ts>]
			Reads recent Slack activity for magic-coordinator's
			communication-sweep.md Check step. Target grammar mirrors
			--send-message's: no target sweeps both known watched targets
			(magic-team, human-owner) via conversations.history in one call
			each; `magic-team`/`human-owner` alone sweeps just that one;
			`<channel>:<ts>` fetches conversations.replies for that specific
			thread instead (same addressing --send-message already uses for
			threaded replies). `--oldest <ts>` is passed through to the Slack
			API call as-is, letting the caller pass its own last-check marker
			for an incremental sweep. Channel ids are resolved the same way as
			--send-message's (SLACK_CHANNEL_MAGIC_TEAM/SLACK_CHANNEL_HUMAN_OWNER
			via --agent-config-option). Deliberately does not parse the Slack
			JSON response -- this shell layer has no real JSON parser (same
			reasoning as --send-message's blocks-fallback note) -- the raw API
			body is printed to stdout as-is for the calling routine to read
			directly. SLACK_BOT_TOKEN handling is identical to --send-message's
			(resolved on demand, never echoed, private temp header file).
			Only Slack is covered -- the only platform this tool has any
			API-calling code for today.

		--self-test
			Exercises the --agent-config-option permission-hardening chain
			(chmod 700 dir / 600 file) under a deliberately permissive
			`umask 022`, not whatever the caller's ambient umask happens to
			be -- regression guard for a real bug where the chmod-600 fix
			escaped hand testing because that testing happened to run under a
			restrictive umask by coincidence. Runs a real --upsert of a
			disposable probe key (`DAT_SELFTEST_PROBE`) against the live
			settings file inside a subshell with umask forced to 022, checks
			the resulting permissions via --verify-permissions, confirms the
			value round-trips, then always deletes the probe key (pass or
			fail) so no test residue is left in the real credentials file.

		--verify-permissions
			Walks $MMDAPP/.local/.agents/* and flags anything not chmod 700
			(the directory) / 600 (each file) -- a standing defensive layer
			against the same class of bug --self-test regression-tests.
			Prints one `OK`/`BAD` line per path to stdout and returns
			non-zero if anything is out of hardening, without modifying
			anything.

		--help
			Prints this syntax + summary and exits.

##  Notes:

		Channel dirs are session plumbing ONLY (fifo/log/pid/meta) — never a
		place to stage secrets material; if a credential ever needs to reach a
		console session, it must be sourced directly into the console's own
		environment, never dropped as a file inside a channel dir, so
		--stop-console's `rm -rf` (scoped to one deterministic channel dir,
		never a fixed/shared path) can never take it down with it.

		Must be run from inside or outside any console — --start-console's
		whole job is to create a new console session, so it can't assume one
		is already open. Bare invocation (`bash sh-scripts/DistroAgentsTools.fn.sh ...`
		with no leading path component) does not match this script's own
		`case "$0"` dispatcher and silently no-ops; invoke it via `./sh-scripts/...`,
		a full path, or with `sh-scripts/` on PATH.

##  Examples:

		# Start a console session against this tool's own workspace (source console)
		`DistroAgentsTools.fn.sh --start-console`

		# Start (or reuse) a deploy console against a different workspace
		`DistroAgentsTools.fn.sh --start-console --override-workspace /path/to/other/workspace --console DistroDeployConsole.sh`

		# Send one command into an open channel
		`DistroAgentsTools.fn.sh --send-console myx.distro-agent-console.<slug>.source -- echo hello`

		# Send multiple lines via stdin
		`printf 'echo one\necho two\n' | DistroAgentsTools.fn.sh --send-console myx.distro-agent-console.<slug>.source`

		# List this workspace's channels
		`DistroAgentsTools.fn.sh --list-consoles`

		# Stop a channel and clean up its processes/directory
		`DistroAgentsTools.fn.sh --stop-console myx.distro-agent-console.<slug>.source`

		# Set/read a credential-bearing setting
		`DistroAgentsTools.fn.sh --agent-config-option --upsert SLACK_BOT_TOKEN xoxb-...`
		`DistroAgentsTools.fn.sh --agent-config-option --select SLACK_BOT_TOKEN`

		# Send a plain-text message to a fixed target
		`DistroAgentsTools.fn.sh --send-message magic-team Build finished OK.`

		# Send a threaded reply with rich Block Kit formatting from stdin
		`echo '[{"type":"section","text":{"type":"mrkdwn","text":"*done*"}}]' | DistroAgentsTools.fn.sh --send-message C0123ABCD:1700000000.000100 --message-from-stdin --format blocks`

		# Sweep both known watched targets (magic-team + human-owner) for new activity
		`DistroAgentsTools.fn.sh --sweep-read-incoming-comms`

		# Sweep just one target, incrementally since a prior check marker
		`DistroAgentsTools.fn.sh --sweep-read-incoming-comms magic-team --oldest 1700000000.000000`

		# Read replies in one specific thread
		`DistroAgentsTools.fn.sh --sweep-read-incoming-comms C0123ABCD:1700000000.000100`

		# Regression-test permission hardening under a deliberately permissive umask
		`DistroAgentsTools.fn.sh --self-test`

		# Audit .local/.agents for anything not chmod 700/600
		`DistroAgentsTools.fn.sh --verify-permissions`
