📘 syntax: DistroAgentsTools.fn.sh --start-console [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]
📘 syntax: DistroAgentsTools.fn.sh --send-console <channel> [-- <command...>]
📘 syntax: DistroAgentsTools.fn.sh --stop-console <channel>
📘 syntax: DistroAgentsTools.fn.sh --list-consoles [--override-workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --agent-config-option <operation>
📘 syntax: DistroAgentsTools.fn.sh --send-message <magic-team|human-owner|<channel>:<ts>> [text...]
📘 syntax: DistroAgentsTools.fn.sh --send-message <target> --from-stdin [--format text|blocks]
📘 syntax: DistroAgentsTools.fn.sh --send-message <target> --file <path> [--format text|blocks]
📘 syntax: DistroAgentsTools.fn.sh --send-email-message <email@address>... -- <subject> -- <body...>
📘 syntax: DistroAgentsTools.fn.sh --send-email-message <email@address>... -- <subject> -- --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --send-email-message <email@address>... -- <subject> -- --file <path>
📘 syntax: DistroAgentsTools.fn.sh --check-slack <magic-team|human-owner|<channel>:<ts>> [--oldest <ts>] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --check-email
📘 syntax: DistroAgentsTools.fn.sh --mark-email-seen <uid>
📘 syntax: DistroAgentsTools.fn.sh --check-trello
📘 syntax: DistroAgentsTools.fn.sh --sweep-read-incoming-comms [--oldest <ts>] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --read-slack <channel>:<ts> [--thread]
📘 syntax: DistroAgentsTools.fn.sh --read-email <uid>
📘 syntax: DistroAgentsTools.fn.sh --read-trello <notification-id>
📘 syntax: DistroAgentsTools.fn.sh --self-test
📘 syntax: DistroAgentsTools.fn.sh --verify-permissions
📘 syntax: DistroAgentsTools.fn.sh --validate-json [<path>]
📘 syntax: DistroAgentsTools.fn.sh --list-md <path>...
📘 syntax: DistroAgentsTools.fn.sh --write-slib <routine-name> [--file <path>]
📘 syntax: DistroAgentsTools.fn.sh --write-board-item <state> <item-filename>
📘 syntax: DistroAgentsTools.fn.sh --write-inbox-note <member> <item-filename> [--file <path>]
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
		--send-message <target> --file <path> [--format text|blocks]
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
			anything already written against it. `--file <path>` (added
			2026-07-22) reads content from a file instead — lets a caller
			write content with a plain `Write` tool call first (no Bash
			permission prompt for the write itself) and still invoke
			--send-message as a single-line command, since a multi-line
			heredoc body means the invoked command no longer matches a
			single-line settings.json allowlist glob the same way. Giving
			both `--from-stdin`/`--message-from-stdin` and `--file` together
			is not a supported combination (whichever is parsed first wins
			silently) — use exactly one.
			--from-stdin/--file --format blocks treats the content as a raw
			JSON array assigned directly to the `blocks` field (caller-supplied
			Block Kit). Since 2026-07-22, that content is validated before it's
			spliced into the payload: it must pass this command's own
			--validate-json (real JSON-syntax check, via self-recursion), must
			be a bare JSON array (starts with `[`, ends with `]`), and every
			top-level array element must be a JSON object whose own `type` is
			one of Slack's real top-level block types (`section`, `divider`,
			`header`, `context`, `image`, `actions`, `input`, `video`,
			`rich_text`, `file`) — otherwise `--send-message` fails immediately
			with a `⛔ ERROR: ... --format blocks stdin failed --validate-json`,
			`... is valid JSON but not a bare array`, or `... has an
			invalid/missing top-level 'type' at block index(es) ...` message
			and never reaches curl. That last check exists because a
			text-object type (`mrkdwn`/`plain_text`, only valid nested inside a
			block's own `text` field) mistakenly used as a block's own `type`
			is exactly the shape of a real live incident (Slack's
			`invalid_blocks: unsupported type "mrkdwn"`) — it is a cheap,
			non-recursive structural check, not a full Block Kit schema
			validator; it does not look inside each block's own nested fields.
			Beyond these three checks, content is not otherwise escaped (Block
			Kit content is caller-owned structured JSON, not free text). `text`
			is set to a static fallback string in the blocks case, not derived
			from the blocks' own content. Any trailing argv token starting with
			`--` that isn't a recognized option is rejected immediately with a
			`⛔ ERROR: ... unrecognized option: ...` message rather than being
			silently absorbed into the plain-text `text` field — a real live
			incident (an unrecognized/mis-parsed flag-shaped token silently
			became the entire posted message text, e.g. a stray "--from-stdin"
			posted as-is with `ok:true` and no visible failure) is exactly what
			this guard prevents; genuine literal text starting with `--` must
			go through `--from-stdin`/`--file` instead. SLACK_BOT_TOKEN is
			resolved on demand from --agent-config-option immediately before
			the request and is never echoed; the constructed request
			(endpoint, channel, payload) is printed to stderr before sending
			with the token itself redacted.

		--send-email-message <email@address>... -- <subject> -- <body...>
		--send-email-message <email@address>... -- <subject> -- --from-stdin
		--send-email-message <email@address>... -- <subject> -- --file <path>
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
			the `--format blocks` bug this same day. `--file <path>` (added
			2026-07-22) reads the body from a file instead — same motivation
			as --send-message's own --file (write the body with a plain Write
			tool call first, then invoke this op as one single-line command).
			Giving more than one of `--from-stdin`/`--file`/trailing body argv
			together is an error (`⛔ ERROR: ... given alongside ... -- use one
			or the other, not both`), not silently resolved one way or the
			other -- exactly one body source is required.

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

		--react-slack <channel>:<ts> <emoji-name>
			Posts one Slack reaction (`reactions.add`) to a specific message --
			<channel>:<ts> only, same target grammar as --read-slack (no
			magic-team/human-owner shortcut, since a reaction always targets one
			exact message, not a channel). <emoji-name> has no colons (matches
			Slack's own `name` field, e.g. `white_check_mark`, not
			`:white_check_mark:`). Added 2026-07-22 -- closes a real gap: this
			tool had no reaction-posting op at all until now, so the per-message
			Slack-reaction-tracking design (`routine-communication-sweep`,
			`routine-board-actualisation`'s pending-reaction lookup) had nothing
			to actually call. SLACK_BOT_TOKEN handling identical to
			--send-message/--read-slack (resolved on demand, never echoed,
			private temp header file). Prints the raw API response and returns
			0 on `ok:true` -- an `already_reacted` error is treated as a
			harmless no-op (also returns 0, with a `#` note, not an error),
			since Slack itself returns that for a reaction that's already
			present and this tool family's design already expects that as
			success, not a retry/investigate case. Any other error returns 1.

		--check-email
			IMAP STATUS INBOX (UNSEEN) check only -- unread count, not a full
			fetch. Same EMAIL_* config as --send-email-message.

		--mark-email-seen <uid>
			Marks one specific email (by IMAP UID, same identifier
			--read-email takes) as \Seen via IMAP UID STORE. Added
			2026-07-22 -- closes a real gap: --check-email/--read-email can
			scan and fetch, but nothing marked a message read after it was
			actually processed, so every comms-sweep pass kept re-seeing the
			same UIDs as unseen. Same EMAIL_* config as --check-email/
			--send-email-message.

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

			**Not a required pre-step for other ops.** Every op that actually
			consumes JSON content as part of its own normal operation (today:
			`--send-message --format blocks`) already self-recurses through
			this same check internally and fails loud with a clear message at
			the point of use -- callers never need to run `--validate-json`
			first as a manual gate before calling the real op. This op's own
			standalone purpose is ad hoc testing/debugging: checking a JSON
			blob you or someone else produced (a file on disk, a payload
			pasted into a heredoc), independent of any specific op, when you
			just want to know "is this syntactically valid JSON" on its own.

		--list-md <path>...
			Existence + line count for one or more caller-supplied file paths,
			one line of output per path: `<path>: <N> lines` if found, `<path>:
			MISSING` if not -- returns 1 if any path was missing, 0 otherwise.
			Added 2026-07-22, human-owner-requested directly, to replace the
			hand-rolled `for f in ...; do wc -l "$f"; done`-style Bash loop
			agents kept reaching for before editing a batch of markdown/doc
			files -- each such loop is a fresh, non-matching command string
			that costs its own permission-prompt grant, same friction class as
			--validate-json/--from-stdin above. Read-only, no credentials, no
			network. Despite the flag name, not restricted to `.md` files --
			any path works; at least one path argument is required.

		--write-slib <routine-name> [--file <path>]
			Regenerates one routine's own routine-contract.SLIB.md -- content
			comes from stdin by default, or from a plain file via --file <path>
			(added 2026-07-22, same shape as --send-message/--send-email-message's
			own --file: lets a caller write the regenerated content to a plain
			temp file first, an ordinary Write tool call, and still invoke this op
			as one single-line command, since a heredoc body spans multiple lines
			and stops matching a single-line settings.json allowlist glob).
			<routine-name> is a bare directory name only (no `/`, not `.`/`..`)
			that must already exist under $HOME/.claude/skills/ -- same
			fixed-target-per-identifier shape as --purge-cleanup, never a
			free-form path. Writes
			$HOME/.claude/skills/<routine-name>/routine-contract.SLIB.md, refusing
			empty content (whether from stdin or --file) rather than truncating
			the file to nothing. Added 2026-07-22 -- closes the human-owner's own
			SLIB-approval-friction question ("I don't want to approve each" [SLIB
			regeneration]) merged with keeper-myx's broader
			tool-agnostic-update-mechanism proposal. No caller-identity
			enforcement -- convention-based trust only, same model as every other
			op here; intended caller is magic-librarian. --write-board-item/
			--write-inbox-note (the same proposal's other illustrative cases) are
			**resolved and built 2026-07-22, see below** -- --write-inbox-note also
			carries the same --file option as of this round.

		--write-board-item <state> <item-filename>
			**magic-coordinator-only op by design** — BOARD.md states plainly
			that write authority over the board (creating/moving/scoring an
			Item) is exclusive to magic-coordinator; this op is the tool-
			mediated mechanism magic-coordinator itself uses to do that, not
			a general-purpose board-writing op for any member. No caller-
			identity enforcement exists (same convention-based-trust model as
			every other op here) — this is documented, not code-enforced.
			<state> must be one of the board's real state-folder names
			(planned/approved/running/testing/blocked/parked/processed/
			archived/cleanup); <item-filename> must be a bare filename (no
			`/`, not `.`/`..`). Content via stdin only. Writes (creates or
			overwrites) `$HOME/.claude/skills/magic-team/board/<state>/
			<item-filename>`. Moving an Item between states is two calls
			(write into the new state, then remove the old file separately) —
			this op has no built-in move/rename primitive.

		--write-inbox-note <member> <item-filename> [--file <path>]
			Writes a note into any member's own personal inbox
			(`~/.claude/skills/<member>/inbox/`) — unlike the board, inbox
			write access is not exclusive to one member; any member may post
			into any other member's inbox (the standard cross-member handoff
			mechanism, see routine-process-inbox). <member> must already
			exist as a real skill directory; <item-filename> must be a bare
			filename. The inbox/ directory is created lazily if it doesn't
			exist yet (a missing inbox/ is not an error, unlike a missing
			board-state directory, since board states are a fixed known set
			and a member's inbox may simply not have been created yet).
			Content via stdin by default, or via --file <path> (added
			2026-07-22, same shape as --write-slib's own --file above).

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

		# Send the same via --file instead -- write content with a plain Write tool
		# call first, then this stays a single-line command
		`DistroAgentsTools.fn.sh --send-message magic-team --file /path/to/message.txt`

		# Mark an email UID as read after processing it
		`DistroAgentsTools.fn.sh --mark-email-seen 48`

		# Write/update a board Item -- magic-coordinator-only op, see --write-board-item above
		```
		DistroAgentsTools.fn.sh --write-board-item planned task-example.md <<'EOF'
		... board item content ...
		EOF
		```

		# Post a note into another member's own personal inbox
		```
		DistroAgentsTools.fn.sh --write-inbox-note keeper-myx 2026-07-22-note-example.md <<'EOF'
		... note content ...
		EOF
		```

		# Same, via --file instead -- write content with a plain Write tool call
		# first, then this stays a single-line command
		`DistroAgentsTools.fn.sh --write-inbox-note keeper-myx 2026-07-22-note-example.md --file /path/to/note.md`

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

		# Ad hoc: check a JSON file someone produced, independent of any op --
		# NOT a required pre-step before --send-message --format blocks (that op
		# already validates its own stdin internally, see --send-message above)
		`DistroAgentsTools.fn.sh --validate-json /path/to/payload.json`

		# Ad hoc: check JSON from stdin the same way -- heredoc, not a piping command in front
		```
		DistroAgentsTools.fn.sh --validate-json <<'EOF'
		[{"type":"section","text":{"type":"mrkdwn","text":"*ok*"}}]
		EOF
		```

		# Regenerate a routine's own merged contract file -- heredoc, not a piping command in front
		```
		DistroAgentsTools.fn.sh --write-slib routine-grooming <<'EOF'
		... full routine-contract.SLIB.md content ...
		EOF
		```

		# Same, via --file instead -- write content with a plain Write tool call
		# first, then this stays a single-line command
		`DistroAgentsTools.fn.sh --write-slib routine-grooming --file /path/to/routine-contract.SLIB.md`

		# Existence + line count for a batch of files in one call, instead of a hand-rolled `for`/`wc -l` loop
		`DistroAgentsTools.fn.sh --list-md /path/to/one.md /path/to/two.md /path/to/missing.md`
		# -> /path/to/one.md: 67 lines
		# -> /path/to/two.md: 43 lines
		# -> /path/to/missing.md: MISSING
		# (returns 1 since one path was missing)
