📘 syntax: DistroAgentsTools.fn.sh --start-console [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]
📘 syntax: DistroAgentsTools.fn.sh --send-console <channel> [-- <command...>]
📘 syntax: DistroAgentsTools.fn.sh --stop-console <channel>
📘 syntax: DistroAgentsTools.fn.sh --list-consoles [--override-workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --agent-config-option <operation>
📘 syntax: DistroAgentsTools.fn.sh --send-message <magic-team|human-owner|<channel>:<ts>> [text...]
📘 syntax: DistroAgentsTools.fn.sh --send-message <target> --from-stdin [--format text|blocks]
📘 syntax: DistroAgentsTools.fn.sh --send-email-message <email@address>... -- <subject> -- <body...>
📘 syntax: DistroAgentsTools.fn.sh --send-email-message <email@address>... -- <subject> -- --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --check-slack <magic-team|human-owner|<channel>:<ts>> [--oldest <ts>] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --check-email
📘 syntax: DistroAgentsTools.fn.sh --check-trello
📘 syntax: DistroAgentsTools.fn.sh --sweep-read-incoming-comms [--oldest <ts>] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --read-slack <channel>:<ts> [--thread]
📘 syntax: DistroAgentsTools.fn.sh --read-email <uid>
📘 syntax: DistroAgentsTools.fn.sh --read-trello <notification-id>
📘 syntax: DistroAgentsTools.fn.sh --self-test
📘 syntax: DistroAgentsTools.fn.sh --verify-permissions
📘 syntax: DistroAgentsTools.fn.sh --validate-json [<path>]
📘 syntax: DistroAgentsTools.fn.sh --purge-cleanup
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

			**Command-only, not a data-transport.** The joined command is
			written raw and unquoted, exactly like typing at an interactive
			shell prompt -- caller is responsible for their own quoting. Do
			NOT pass arbitrary free text (a message body, anything with
			shell metacharacters like parentheses/quotes/semicolons) as the
			trailing argument -- that has crashed a live console process for
			real. For free text, call --send-message/--send-email-message as
			bare direct invocations instead; neither goes through
			--send-console.

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
		--send-message <target> --from-stdin [--format text|blocks]
			Posts a message to Slack via chat.postMessage. <target> is
			`magic-team` or `human-owner` (channel id resolved from
			SLACK_CHANNEL_MAGIC_TEAM/SLACK_CHANNEL_HUMAN_OWNER in
			--agent-config-option) or a literal `<channel>:<ts>` string
			(posted as a threaded reply via thread_ts — the caller supplies
			this directly; nothing is looked up by name). Plain trailing
			arguments (or plain stdin) become the `text` field.
			`--from-stdin` is the standardized name for "read content from
			stdin instead of argv" (see the team-wide convention in
			`magic-team/CONSOLE-SESSIONS.md`'s "Heredoc for stdin" section --
			call this op with its absolute path leading and a heredoc, never a
			separate command piping into it); `--message-from-stdin` is the
			original name and still works identically, unchanged, for
			anything already written against it.
			--from-stdin --format blocks treats stdin as a raw JSON
			array assigned directly to the `blocks` field (caller-supplied
			Block Kit). Since 2026-07-22, stdin is validated before it's
			spliced into the payload: it must pass this command's own
			--validate-json (real JSON-syntax check, via self-recursion) and
			must be a bare JSON array (starts with `[`, ends with `]`) --
			otherwise `--send-message` fails immediately with a `⛔ ERROR:
			... --format blocks stdin failed --validate-json` or `... is
			valid JSON but not a bare array` message and never reaches curl.
			Not escaped beyond that (Block Kit content is caller-owned
			structured JSON, not free text -- only its JSON-validity and
			array-shape are checked, not its contents). `text` is set to a
			static fallback string in the blocks case, not derived from the
			blocks' own content. SLACK_BOT_TOKEN is resolved on demand from
			--agent-config-option immediately before the request and is
			never echoed; the constructed request (endpoint, channel,
			payload) is printed to stderr before sending with the token
			itself redacted.

		--send-email-message <email@address>... -- <subject> -- <body...>
		--send-email-message <email@address>... -- <subject> -- --from-stdin
			Real, standalone SMTP send via curl (EMAIL_USER/EMAIL_APP_PASSWORD/
			EMAIL_SMTP_HOST/EMAIL_SMTP_PORT from --agent-config-option),
			not just an internal fallback -- --send-message's exhausted-retry
			path calls this same op via self-recursion. Multiple recipients
			accepted before the first `--`; subject is everything between the
			two `--` separators; everything after the second `--` becomes the
			body, one line per remaining argument -- OR, since 2026-07-22,
			`--from-stdin` in place of trailing body argv reads the whole body
			from stdin instead (call with the tool's absolute path leading and
			a heredoc, per the team-wide convention above), avoiding the
			exact multi-line/shell-metacharacter argv fragility that caused
			the `--format blocks` bug this same day. Giving both `--from-stdin`
			and trailing body argv together is an error (`⛔ ERROR: ...
			--from-stdin given alongside trailing body argv`), not silently
			resolved one way or the other.

		--check-slack <magic-team|human-owner|<channel>:<ts>> [--oldest <ts>] [--raw]
			Reads Slack activity for ONE specific, caller-chosen target --
			target is required, this is a general-purpose single-target
			reader, not the comms-sweep macro-op (see --sweep-read-incoming-comms
			below; these two used to be conflated into one op that
			accepted an optional target, which was a real design bug, fixed
			2026-07-21). Target grammar mirrors --send-message's:
			`magic-team`/`human-owner` reads that watched target's
			conversations.history; `<channel>:<ts>` fetches
			conversations.replies for that specific thread instead (same
			addressing --send-message already uses for threaded replies).
			`--oldest <ts>` is passed through to the Slack API call as-is,
			letting the caller pass its own last-check marker for an
			incremental read. Channel ids are resolved the same way as
			--send-message's (SLACK_CHANNEL_MAGIC_TEAM/SLACK_CHANNEL_HUMAN_OWNER
			via --agent-config-option). SLACK_BOT_TOKEN handling is identical
			to --send-message's (resolved on demand, never echoed, private
			temp header file).

			**No retry logic** -- human-owner correction, 2026-07-21: "if
			they fail - they fail," applies to the whole --check-* family.
			One attempt, fails clean if it fails.

			**Output is pretty-formatted by default** ("ts | user | text"
			one line per message, via myx.distro-system's own
			`sh-lib/AgentSlackMessagesFormat.awk` -- reuses the same
			recursive-descent JSON-parsing engine as myx.common's
			`agentMcpJsonParseRequest.awk`, copied verbatim, only the
			leaf-emission logic differs) instead of raw JSON -- every real
			caller ended up hand-parsing the JSON anyway, so raw is no longer
			the default. `--raw` opts back into the full API response
			(needed for fields the pretty formatter doesn't surface, e.g.
			`reply_count`/`thread_ts` metadata).

		--check-email
			IMAP STATUS INBOX (UNSEEN) check only -- unread count, not a full
			fetch. Same EMAIL_* config as --send-email-message.

		--check-trello
			Unread Trello notifications only (`read_filter=unread`), not a
			full board read. TRELLO_KEY/TRELLO_TOKEN from --agent-config-option.

		--sweep-read-incoming-comms [--oldest <ts>] [--raw]
			**Not a general-purpose Slack reader -- takes no target at all.**
			This is the dedicated macro-operation for exactly one caller,
			magic-coordinator's communication-sweep.md Check step: it always
			reads the exact same predefined, pre-configured set of watched
			sources (both Slack targets via --check-slack, plus --check-email
			and --check-trello) in one combined pass, producing one specific
			mixed output meant as the initial text source for comms
			processing. If you need to read one specific arbitrary Slack
			target/thread, call --check-slack directly instead --
			--sweep-read-incoming-comms will reject a positional target
			argument. `--oldest`/`--raw` are passed through to each
			--check-slack call it makes internally.

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

		--validate-json [<path>]
			Checks that a JSON file (<path>) or stdin (no argument) is
			syntactically valid JSON -- nothing more, no schema/shape check of
			its own. Added 2026-07-22 after a real `--send-message ... --format
			blocks` failure (Slack's `invalid_json`/`missing_charset`) traced
			back to unvalidated stdin being spliced straight into the request
			payload; `--format blocks` now self-recurses through this same op
			before it splices anything (see --send-message above). Uses
			python3 (present on every supported OS here), not jq, matching
			this tool family's existing jq-avoidance convention. Prints `#
			... --validate-json: valid JSON: <path|(stdin)>` and returns 0 on
			success, or `⛔ ERROR: ... --validate-json: invalid JSON:
			<path|(stdin)>` and returns 1 on failure -- a missing <path>
			argument is stdin, not an error; a <path> that doesn't exist is a
			separate, explicit "file not found" error, not silently treated
			as stdin.

		--purge-cleanup
			Empties $MMDAPP/.local/.cleanup/ (the folder itself stays) --
			exists because Claude Code's own permission engine has no
			negative-glob syntax, so a blanket `Bash(rm *)` deny can never
			be carved into "except .cleanup/*" at the settings.json layer
			(deny always wins over allow regardless of specificity,
			confirmed live 2026-07-21). This op is the sanctioned way to
			actually empty it: the real `rm` call happens inside this
			already-allowlisted script invocation, never as a raw top-level
			`rm` command, so the deny rule's literal prefix-match on `rm `
			never sees it. **Takes no arguments** -- the target is a fixed,
			code-determined path, never caller input (human-owner correction,
			2026-07-21: an earlier version took an optional `<path>`/`--all`,
			which was wrong -- this op cleans exactly one predefined folder,
			nothing else, so there's nothing to parameterize). That fixed
			path is also what makes the whole thing safe: no traversal/
			injection surface exists because there's no path input to
			validate in the first place.

		--read-slack <channel>:<ts> [--thread]
			Full detail for one specific message (default) or its whole
			thread (--thread) -- all meta-info, reactions, formatting,
			files/attachments, exactly as Slack's own API returns them.
			Complement to --check-slack: that one is a lightweight,
			pretty-formatted scan; this one is the deep read for actually
			processing one specific item. Always returns full raw JSON,
			never pretty-formatted -- "full" is the entire point.

		--read-email <uid>
			Full RFC822 message (headers + body + MIME multipart,
			attachments included as their raw MIME parts) for one specific
			email by IMAP UID. Uses curl's `;UID=<uid>` URL addressing (no
			`;SECTION=` means the whole message) -- contrast with
			--check-email's STATUS-only unread count.

		--read-trello <notification-id>
			Full detail for one specific Trello notification (the unit
			--check-trello's unread list returns), including its related
			card/board summary. Contrast with --check-trello's unread-list
			scan.

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

		# Send multiple lines via stdin -- absolute path leading, heredoc for content,
		# never a separate piping command in front (that breaks the permission
		# allowlist match; see magic-team/CONSOLE-SESSIONS.md's "Heredoc for stdin"
		# section)
		```
		DistroAgentsTools.fn.sh --send-console myx.distro-agent-console.<slug>.source <<'EOF'
		echo one
		echo two
		EOF
		```

		# List this workspace's channels
		`DistroAgentsTools.fn.sh --list-consoles`

		# Stop a channel and clean up its processes/directory
		`DistroAgentsTools.fn.sh --stop-console myx.distro-agent-console.<slug>.source`

		# Set/read a credential-bearing setting
		`DistroAgentsTools.fn.sh --agent-config-option --upsert SLACK_BOT_TOKEN xoxb-...`
		`DistroAgentsTools.fn.sh --agent-config-option --select SLACK_BOT_TOKEN`

		# Send a plain-text message to a fixed target
		`DistroAgentsTools.fn.sh --send-message magic-team Build finished OK.`

		# Send a threaded reply with rich Block Kit formatting from stdin -- heredoc,
		# not a piping command in front; --from-stdin is the standardized name
		# (--message-from-stdin still works too, same flag)
		```
		DistroAgentsTools.fn.sh --send-message C0123ABCD:1700000000.000100 --from-stdin --format blocks <<'EOF'
		[{"type":"section","text":{"type":"mrkdwn","text":"*done*"}}]
		EOF
		```

		# Send an email with a multi-line body from stdin instead of fragile trailing argv
		```
		DistroAgentsTools.fn.sh --send-email-message myx@meloscope.com -- "Status update" -- --from-stdin <<'EOF'
		Line one of the body.
		Line two, with 'quotes' and (parens) that would have been fragile as argv.
		EOF
		```

		# Sweep all watched targets (magic-team, human-owner, email, Trello) for new activity --
		# takes no target, this is the fixed comms-sweep macro-op, not a single-target reader
		`DistroAgentsTools.fn.sh --sweep-read-incoming-comms`

		# Sweep all watched targets, incrementally since a prior check marker
		`DistroAgentsTools.fn.sh --sweep-read-incoming-comms --oldest 1700000000.000000`

		# Read one specific target/thread instead -- use --check-slack, not --sweep-read-incoming-comms
		`DistroAgentsTools.fn.sh --check-slack magic-team --oldest 1700000000.000000`
		`DistroAgentsTools.fn.sh --check-slack C0123ABCD:1700000000.000100`

		# Regression-test permission hardening under a deliberately permissive umask
		`DistroAgentsTools.fn.sh --self-test`

		# Audit .local/.agents for anything not chmod 700/600
		`DistroAgentsTools.fn.sh --verify-permissions`

		# Validate a JSON file before handing it to an API call
		`DistroAgentsTools.fn.sh --validate-json /path/to/payload.json`

		# Validate JSON from stdin -- heredoc, not a piping command in front
		```
		DistroAgentsTools.fn.sh --validate-json <<'EOF'
		[{"type":"section","text":{"type":"mrkdwn","text":"*ok*"}}]
		EOF
		```
