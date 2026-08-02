📘 syntax: DistroAgentsTools.fn.sh --start-console [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]
📘 syntax: DistroAgentsTools.fn.sh --send-console <channel> [-- <command...>]
📘 syntax: DistroAgentsTools.fn.sh --stop-console <channel>
📘 syntax: DistroAgentsTools.fn.sh --list-consoles [--override-workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --agent-config-option <operation>
📘 syntax: DistroAgentsTools.fn.sh --members --backend <member-name> <operation>
📘 syntax: DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]
📘 syntax: DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <target> --from-stdin [--format text|blocks]
📘 syntax: DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <target> --file <path> [--format text|blocks]
📘 syntax: DistroAgentsTools.fn.sh --send-email-message <email@address>... -- <subject> -- <body...>
📘 syntax: DistroAgentsTools.fn.sh --send-email-message <email@address>... -- <subject> -- --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --send-email-message <email@address>... -- <subject> -- --file <path>
📘 syntax: DistroAgentsTools.fn.sh --check-slack <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [--oldest <ts>] [--raw]
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
📘 syntax: DistroAgentsTools.fn.sh --librarian-list-team-files [<path>...]
📘 syntax: DistroAgentsTools.fn.sh --librarian-list-team-files-dates [<path>...]
📘 syntax: DistroAgentsTools.fn.sh --write-slib <member-name> [--file <path>]
📘 syntax: DistroAgentsTools.fn.sh --write-board-item <state> <item-filename>
📘 syntax: DistroAgentsTools.fn.sh --member-upsert-inbox-note <member> <item-filename> [--file <path>]
📘 syntax: DistroAgentsTools.fn.sh --member-upsert-member-inquiry <member> <item-filename> [--file <path>]
📘 syntax: DistroAgentsTools.fn.sh --member-upsert-inbox-reflection <member> <item-filename> [--file <path>]
📘 syntax: DistroAgentsTools.fn.sh --member-append-session-transcript <team-member> --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <verbatim-text>|--message-from-stdin|--from-stdin|--message-file <path>) --transcript-name <transcript-file-name> --workspace-root <path> [--create]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-backlog <team-member> <item-filename> --from-state:<state> --owner <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-pending <team-member> <item-filename> --from-state:<state> --owner <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-processed <team-member> <item-filename> --from-state:<state> --owner <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-sweep-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --member-work-session-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --routine-coworking-session-input-scan <team-member> <item-name>...
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-lock-acquire <team-member> <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-lock-heartbeat <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-lock-release <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-lock-status <team-member>
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
			real. For free text, call --member-slack-send-message/--send-email-message as
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

		--members --backend <member-name> <operation>
			Per-member config-scope selector — mirrors
			myx.distro-remote's RemoteConsole.fn.sh `--remotes --backend
			<remote-name>` mechanism exactly, remote→member renamed
			mechanically. Re-shapes the call into `--member-config-option
			<member-name> <operation> [args...]` and reads/writes one
			settings file per named team member,
			$MMDAPP/agents/static/<member-name>.agent.env — NOT the same
			store as --agent-config-option's global scope above (this
			tool's own credential keys are globally unique; per-member
			keys are not, hence the per-entity split, same reasoning as
			myx.distro-.local's --remote-config-option). No chmod
			hardening on creation — matches --remote-config-option's own
			unhardened remote.env files; this scope holds ordinary
			per-member settings, not credentials, unlike
			--agent-config-option. <operation> is the same set
			--agent-config-option accepts: --select-all, --select
			<key>|--all, --select-default <key> <default>, --upsert <key>
			<val>, --upsert-if <key> <val> <ifval>, --delete <key>,
			--delete-if <key> <ifval> — see LocalTools.Config.include
			itself for the authoritative behavior of each. Only --backend
			is mirrored from Remote's own `--remotes` op group —
			RemoteConsole.fn.sh's friendlier --upsert/--upsert-if/
			--select/--delete wrappers (which self-recurse into
			--backend) are not mirrored here; call --members --backend
			directly for every operation.

		--member-slack-send-message <team-member> <target> [text...]
		--member-slack-send-message <team-member> <target> --from-stdin [--format text|blocks]
		--member-slack-send-message <team-member> <target> --file <path> [--format text|blocks]
			Posts a message to Slack via chat.postMessage, attributed to
			<team-member>. The only Slack-post op -- there is no separate
			anonymous/unattributed variant. <team-member> is a required first
			argument, validated as an existing skill directory under
			~/.claude/skills/<team-member> (bare name, no path characters); the
			outgoing text is prefixed with a "*<team-member>:*" attribution
			line ahead of the message (also used as the --format blocks case's
			own static text-fallback content). <target> is
			`magic-team` or `human-owner` (channel id resolved from
			SLACK_CHANNEL_MAGIC_TEAM/SLACK_CHANNEL_HUMAN_OWNER in
			--agent-config-option), `event-track` or `event-alert` (fixed
			channels `#bot-messages`/`#cloud-alert`, not resolved via
			--agent-config-option), or a literal `<channel>:<ts>` string
			(posted as a threaded reply via thread_ts — the caller supplies
			this directly; nothing is looked up by name). Plain trailing
			arguments (or plain stdin) become the `text` field.
			`--from-stdin` is the standardized name for "read content from
			stdin instead of argv" (see the team-wide convention in
			`magic-team/CONSOLE-SESSIONS.md`'s "Heredoc for stdin" section --
			call this op with its absolute path leading and a heredoc, never a
			separate command piping into it); `--message-from-stdin` is the
			original name and still works identically, unchanged, for
			anything already written against it. `--file <path>` reads
			content from a file instead — lets a caller
			write content with a plain `Write` tool call first (no Bash
			permission prompt for the write itself) and still invoke
			--member-slack-send-message as a single-line command, since a multi-line
			heredoc body means the invoked command no longer matches a
			single-line settings.json allowlist glob the same way. Giving
			both `--from-stdin`/`--message-from-stdin` and `--file` together
			is not a supported combination (whichever is parsed first wins
			silently) — use exactly one.
			--from-stdin/--file --format blocks treats the content as a raw
			JSON array assigned directly to the `blocks` field (caller-supplied
			Block Kit). That content is validated before it's
			spliced into the payload: it must pass this command's own
			--validate-json (real JSON-syntax check, via self-recursion), must
			be a bare JSON array (starts with `[`, ends with `]`), and every
			top-level array element must be a JSON object whose own `type` is
			one of Slack's real top-level block types (`section`, `divider`,
			`header`, `context`, `image`, `actions`, `input`, `video`,
			`rich_text`, `file`) — otherwise `--member-slack-send-message` fails immediately
			with a `⛔ ERROR: ... --format blocks stdin failed --validate-json`,
			`... is valid JSON but not a bare array`, or `... has an
			invalid/missing top-level 'type' at block index(es) ...` message
			and never reaches curl. That last check exists because a
			text-object type (`mrkdwn`/`plain_text`, only valid nested inside a
			block's own `text` field) mistakenly used as a block's own `type`
			would otherwise trigger Slack's
			`invalid_blocks: unsupported type "mrkdwn"` rejection — it is a cheap,
			non-recursive structural check, not a full Block Kit schema
			validator; it does not look inside each block's own nested fields.
			Beyond these three checks, content is not otherwise escaped (Block
			Kit content is caller-owned structured JSON, not free text). `text`
			is set to a static fallback string in the blocks case, not derived
			from the blocks' own content. Any trailing argv token starting with
			`--` that isn't a recognized option is rejected immediately with a
			`⛔ ERROR: ... unrecognized option: ...` message rather than being
			silently absorbed into the plain-text `text` field — an
			unrecognized/mis-parsed flag-shaped token would otherwise silently
			become the entire posted message text (e.g. a stray "--from-stdin"
			posted as-is with `ok:true` and no visible failure); this guard
			prevents that. Genuine literal text starting with `--` must
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
			not just an internal fallback -- --member-slack-send-message's exhausted-retry
			path calls this same op via self-recursion. Multiple recipients
			accepted before the first `--`; subject is everything between the
			two `--` separators; everything after the second `--` becomes the
			body, one line per remaining argument -- OR
			`--from-stdin` in place of trailing body argv reads the whole body
			from stdin instead (call with the tool's absolute path leading and
			a heredoc, per the team-wide convention above), avoiding
			multi-line/shell-metacharacter argv fragility. `--file <path>`
			reads the body from a file instead — same motivation
			as --member-slack-send-message's own --file (write the body with a plain Write
			tool call first, then invoke this op as one single-line command).
			Giving more than one of `--from-stdin`/`--file`/trailing body argv
			together is an error (`⛔ ERROR: ... given alongside ... -- use one
			or the other, not both`), not silently resolved one way or the
			other -- exactly one body source is required.

		--check-slack <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [--oldest <ts>] [--raw]
			Reads Slack activity for ONE specific, caller-chosen target --
			target is required, this is a general-purpose single-target
			reader, not the comms-sweep macro-op (see --sweep-read-incoming-comms
			below; conflating the two into one op that accepted an optional
			target would be a real design bug). Target grammar mirrors --member-slack-send-message's:
			`magic-team`/`human-owner`/`event-track`/`event-alert` reads that
			watched target's conversations.history; `<channel>:<ts>` fetches
			conversations.replies for that specific thread instead (same
			addressing --member-slack-send-message already uses for threaded replies).
			`--oldest <ts>` is passed through to the Slack API call as-is,
			letting the caller pass its own last-check marker for an
			incremental read. Channel ids are resolved the same way as
			--member-slack-send-message's (SLACK_CHANNEL_MAGIC_TEAM/SLACK_CHANNEL_HUMAN_OWNER
			via --agent-config-option). SLACK_BOT_TOKEN handling is identical
			to --member-slack-send-message's (resolved on demand, never echoed, private
			temp header file).

			**No retry logic** -- applies to the whole --check-* family.
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
			`:white_check_mark:`). The per-message Slack-reaction-tracking
			design (`routine-communication-sweep`,
			`routine-board-actualisation`'s pending-reaction lookup) calls
			this op to actually post. SLACK_BOT_TOKEN handling identical to
			--member-slack-send-message/--read-slack (resolved on demand, never echoed,
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
			--read-email takes) as \Seen via IMAP UID STORE -- otherwise every
			comms-sweep pass keeps re-seeing the same UIDs as unseen.
			Same EMAIL_* config as --check-email/
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
			its own. `--format blocks` self-recurses through this same op
			before it splices anything into the request payload (see
			--member-slack-send-message above), guarding against unvalidated stdin causing
			Slack's `invalid_json`/`missing_charset` rejection. Uses
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
			`--member-slack-send-message --format blocks`) already self-recurses through
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
			Replaces the hand-rolled `for f in ...; do wc -l "$f"; done`-style
			Bash loop agents kept reaching for before editing a batch of
			markdown/doc files -- each such loop is a fresh, non-matching
			command string that costs its own permission-prompt grant.
			Read-only, no credentials, no
			network. Despite the flag name, not restricted to `.md` files --
			any path works; at least one path argument is required.

		--librarian-list-team-files [<path>...]
			find-based (not a hand-rolled directory walk) read-only path
			listing of skill-folder files -- no per-file stat call, so this
			stays fast even across the whole skill-root (measured: the
			-dates variant below took ~3s over 678 files; this one is the
			no-stat fast path, sub-second). Zero or more optional scope
			arguments, each either a bare path relative to the skill-root
			(`$HOME/.claude/skills/`) or an absolute path that must resolve
			inside it (anything outside is rejected and skipped, not
			silently ignored, same per-argument error handling as
			--list-md); a bare file scopes to just that file, a directory
			scopes recursively. No arguments means the whole skill-root.
			Prints one skill-root-relative path per matched file (never
			absolute), sorted alphabetically.

		--librarian-list-team-files-dates [<path>...]
			Same as --librarian-list-team-files above (identical scope-
			argument grammar and error handling), but with a per-file
			modification date printed alongside each path -- its own separate
			op since the per-file stat call this needs is real overhead
			(~3s over the full 678-file
			skill-root vs. sub-second for the plain listing), so a caller
			who only needs paths isn't forced to pay for dates. Prints one
			line per matched file: mtime (`YYYY-MM-DD HH:MM:SS`) then two
			spaces then the path relative to the skill-root (never
			absolute), sorted newest-first.

		--write-slib <member-name> [--file <path>]
			Regenerates one member's own <member-name>.SLIB.md -- content
			comes from stdin by default, or from a plain file via --file <path>
			(same shape as --member-slack-send-message/--send-email-message's own --file:
			lets a caller write the regenerated content to a plain temp file
			first, an ordinary Write tool call, and still invoke this op as
			one single-line command, since a heredoc body spans multiple lines
			and stops matching a single-line settings.json allowlist glob).
			<member-name> is a bare directory name only (no `/`, not `.`/`..`)
			that must already exist under $HOME/.claude/skills/ -- same
			fixed-target-per-identifier shape as --purge-cleanup, never a
			free-form path. Writes
			$HOME/.claude/skills/<member-name>/<member-name>.SLIB.md, refusing
			empty content (whether from stdin or --file) rather than truncating
			the file to nothing. SLIB files are generated content, so this op
			exists to avoid needing per-write approval the way real source
			edits do. No caller-identity
			enforcement -- convention-based trust only, same model as every other
			op here; intended caller is magic-librarian. --write-board-item and
			--write-inbox-note also carry the same --file option.

		--write-board-item <state> <item-filename>
			**magic-coordinator-only op by design** — BOARD.md states plainly
			that write authority over the board (creating/moving/scoring an
			Item) is exclusive to magic-coordinator; this op is the tool-
			mediated mechanism magic-coordinator itself uses to do that, not
			a general-purpose board-writing op for any member. No caller-
			identity enforcement exists (same convention-based-trust model as
			every other op here) — this is documented, not code-enforced.
			<state> must be one of the board's real state-folder names
			(backlog/pending/running/blocked/parked/processed/
			archived/retained/cleanup); <item-filename> must be a bare filename (no
			`/`, not `.`/`..`). Content via stdin only. Writes (creates or
			overwrites) `$HOME/.claude/skills/magic-team/board/<state>/
			<item-filename>`. Moving an Item between states is two calls
			(write into the new state, then remove the old file separately) —
			this op has no built-in move/rename primitive.

		--member-upsert-inbox-note <member> <item-filename> [--file <path>]
			Writes (creates or overwrites) a note into any member's own
			personal inbox (`~/.claude/skills/<member>/inbox/`) — unlike
			the board, inbox write access is not exclusive to one member;
			any member may post into any other member's inbox (the
			standard cross-member handoff mechanism, see
			routine-process-inbox). <member> must already exist as a real
			skill directory; <item-filename> must be a bare filename. The
			inbox/ directory is created lazily if it doesn't exist yet (a
			missing inbox/ is not an error, unlike a missing board-state
			directory, since board states are a fixed known set and a
			member's inbox may simply not have been created yet). Content
			via stdin by default, or via --file <path>. Renamed
			from --write-inbox-note (verb-suffixed to match the existing
			--owner-workspace-upsert/-forget/-list/-current convention,
			first op under the --member-* prefix category) —
			--write-inbox-note still works, unchanged, as a thin
			backward-compatible shim calling this op, but is no longer
			documented separately here.

		--member-upsert-member-inquiry <member> <item-filename> [--file <path>]
			Passes an inquiry along to a specific named member's own
			inbox — same argument shape and file-writing mechanics as
			--member-upsert-inbox-note (in fact self-recurses directly
			into it), kept as its own distinctly-named op because the two
			represent semantically distinct fallback cases ("note it for
			later" vs. "pass it to another member," per
			magic-team.armed.md's Process/dynamics rule formulation) even
			though they currently resolve to the identical mechanism.

		--member-append-session-transcript <team-member> --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <verbatim-text>|--message-from-stdin|--from-stdin|--message-file <path>) --transcript-name <transcript-file-name> --workspace-root <path> [--create]
			Appends exactly one canonical transcript-entry block into
			$HOME/.claude/audit/<YYYY-MM>/<transcript-file-name>:
			<speaker-name> (<timestamp>): followed by quoted message lines.
			Per magic-team.shared.md's transcript-* location predicate,
			transcripts save under the shared audit tree -- not a
			board/<state>/ folder; see --write-board-item above for the real
			board state-folder names. <YYYY-MM> is derived from the date
			embedded in <transcript-file-name> (transcript-YYYY-MM-DD-*),
			falling back to the current UTC year-month otherwise.
			<team-member> is an enforced first positional argument, not a
			--member flag. Its skill directory must already exist (sanity check
			that the member is real); audit/ and its <YYYY-MM>/ subfolder are
			created on demand if missing (same laziness as
			--member-upsert-inbox-note's inbox/ handling). --workspace-root is
			still required and validated (absolute, existing directory) but
			does not determine the target path. Does not rewrite prior content.
			Missing target transcript is an error unless --create is passed.
			Payload must be provided by exactly one source: --message,
			--message-from-stdin/--from-stdin, or --message-file <path>.
			Returns append audit details: target path plus added line and byte
			counts.

		--owner-workspace-upsert <path>
			Adds one filesystem path to the human-owner's tracked workspace
			list at $HOME/.claude/skills/human-owner/human-owner.workspaces.md
			-- a bare, one-absolute-path-per-line file that is the ONLY
			authoritative source of truth for the workspace paths the
			magic-* team tracks (see magic-team.armed.md's "Workspace" term
			entry for the model this backs -- that file never states a
			literal path itself). <path> must be absolute (starts with `/`);
			a single trailing slash is stripped before comparing/storing, so
			`/foo/bar` and `/foo/bar/` collapse to the same entry. Idempotent
			-- upserting an already-tracked path is a harmless no-op, not an
			error. Existence of <path> on disk is not checked (a tracked
			workspace may live on a currently-unmounted volume). The
			human-owner skill directory itself must already exist (it does,
			as a standing skill folder) -- this op does not create that
			directory, only the workspaces.md file inside it on first use.

		--owner-workspace-forget <path>
			Removes one filesystem path from the same tracked workspace list.
			Same trailing-slash normalization as --owner-workspace-upsert.
			Forgetting a path that isn't tracked, or when the file doesn't
			exist yet at all, is a harmless no-op, not an error.

		--owner-workspace-list
			Prints every currently-tracked workspace path, one per line, in
			file order -- reads only lines that look like an absolute path
			(start with `/`), so any stray non-data content in
			human-owner.workspaces.md is never treated as data. Takes no
			arguments. Prints nothing (and does not error) if the file
			doesn't exist yet or has no tracked paths.

		--owner-workspace-current
			Registers this tool's own workspace root ($MMDAPP) into the
			tracked workspace list (delegates to --owner-workspace-upsert
			internally, so the same idempotent/no-error-on-already-tracked
			behavior applies), then prints that path to stdout. Takes no
			arguments. Convenience op for a caller that wants "track my
			current workspace and tell me its path" in one call instead of
			spelling out $MMDAPP itself for --owner-workspace-upsert.

		--owner-install-vscode-integrations [--workspace <path>]
			Installs/updates baseline VS Code + Claude Code integrations
			(GitHub.copilot, GitHub.copilot-chat, anthropic.claude-code),
			verifies they are listed by `code --list-extensions`, and
			upserts MCP wiring for both clients: workspace `.vscode/mcp.json`
			with a `servers.myx` stdio entry (VS Code/Copilot-Chat's own
			schema) and workspace-root `.mcp.json` with a `mcpServers.myx`
			stdio entry (Claude Code's own project-scope schema -- Claude
			Code does not read `.vscode/mcp.json`), both pointing at the
			resolved myx.common `agentMcpServer.sh` path.
			Default target workspace is the current shell directory; optional
			`--workspace <path>` overrides it. Fails fast if the target isn't
			already a set-up myx.distro workspace (checks for
			`.local/myx/myx.distro-.local/sh-lib/LocalContext.include`) or if
			VS Code CLI (`code`) is not present in PATH. Prints a compact
			OK/FAIL checklist, plus Command Palette trust/restart guidance
			for MCP visibility.

		--magic-grooming-to-backlog <team-member> <item-filename> --from-state:<state> --owner <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves a board item to board/backlog/ and/or patches its
			frontmatter, one call -- no full-content rewrite required
			(--upsert-from-stdin/--edit-script-from-stdin/
			--edit-patch-from-stdin remain available for one).
			--edit-patch-from-stdin takes a JSON array of
			`{"old": <text>, "new": <text>, "replace_all": <bool, default
			false>}` patch objects on stdin and applies each, in order, as an
			exact literal (non-regex) substring match-and-replace against the
			body -- a small localized body edit without supplying the whole
			new body verbatim or writing a full script. --from-state:<state>
			and --owner are both required; groomed-at/groomed-from/track are
			always auto-stamped, never caller-supplied. --header:*/
			--upsert-from-stdin/--edit-script-from-stdin/
			--edit-patch-from-stdin pass straight through for whatever else
			the move also needs. Own dedicated case arm, not shared with
			--magic-grooming-to-pending/-processed (room for its own future
			backlog-specific validation).

		--magic-grooming-to-pending <team-member> <item-filename> --from-state:<state> --owner <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as --magic-grooming-to-backlog, target fixed to
			board/pending/ -- the Advancement-review case (backlog->pending,
			e.g. --header:upsert:approved-by:"<team-member> (<session-id>,
			<date-time>)" --header:upsert:approved-at:<date>). approved-by's
			value is validated: must match <team-member> (<session-id>,
			<date-time>) with an ISO UTC date-time (suffix Z). Own dedicated
			case arm.

		--magic-grooming-to-processed <team-member> <item-filename> --from-state:<state> --owner <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as --magic-grooming-to-backlog, target fixed to
			board/processed/. Own dedicated case arm.

		--magic-grooming-input-scan <team-member>
			Read-only: lists board items as <state>/<item-filename>, one per
			line, with every frontmatter field. Always scans backlog/
			pending/running/blocked/parked, --all-types. Use this to find an
			item's actual current state before calling --magic-grooming-to-*.
			Thin wrapper over the internal --intern-op-board-scan primitive
			(no --help entry of its own) -- fixed, hardcoded state-list/
			header-list, no caller-facing --state/--header override
			(dedicated wrappers are fixed, not flexible; call
			--intern-op-board-scan directly for a different scan shape).
			Default scan output unchanged from this op's own pre-primitive
			implementation; the override-flag capability that
			implementation had is not.

		--magic-sweep-input-scan <team-member>
			Read-only: routine-communication-sweep's own first-stage board
			scan. Thin wrapper over --intern-op-board-scan. Always scans
			backlog/pending/running/blocked -- deliberately not parked, per
			that routine's own "Enumeration mechanism for every open
			thread" text (the tracked set is board-items "currently open").
			Always --all-types, always full frontmatter -- no caller-facing
			--state override. Two-call pattern internally: discovers which
			items have both source_slack_channel/source_slack_ts set (only
			those track a live, reply-pending Slack thread), then re-scans
			restricted to exactly those survivors for the real display
			output. Empty result (no live-tracked thread) is a normal,
			clean outcome, not an error.

		--member-work-session-input-scan <team-member>
			Read-only: one member's own current work-session input --
			personal, not routine-dictated (every armed member runs this
			against its own name as it becomes armed, regardless of which
			routine triggered the arming). Thin wrapper over
			--intern-op-board-scan, fixed --owner <member> and --all-types.
			Always scans backlog/pending/running/blocked/parked, always
			every frontmatter field -- <member> is this op's only argument,
			no --state/--header override. Appends that same member's own
			inbox/ contents as a second, identically shaped section
			(`## inbox/<item-filename>` + frontmatter) -- a not-yet-created
			inbox/ prints an empty section, not an error.

		--routine-coworking-session-input-scan <team-member> <item-name>...
			Read-only: routine-coworking's own step-1 board scan once the
			session's shared goal names specific board-item(s). Thin
			wrapper over --intern-op-board-scan. At least one <item-name>
			required -- this is the op's real defining input, no --state/
			--header override alongside it. Always scans every real board
			state (a named item may live in any of them) and is never
			--owner-filtered (contrast with --member-work-session-input-scan:
			this is about specific named items regardless of who owns
			them). Two-call pattern internally: discovers every item named
			in the given items' own references/blocks/blocked-by fields,
			then re-scans restricted to the union of the originally-given
			names plus every discovered related name, for the real display
			output (always every frontmatter field).

		--magic-heartbeat-input-scan <team-member>
			Read-only: routine-heartbeat's own board scan (name
			deliberately does not echo that routine's own name -- confirmed
			intentional). Thin wrapper over --intern-op-board-scan, always
			--all-types. Always scans backlog/pending/running/blocked/
			parked, always every frontmatter field -- no caller-facing
			--state/--header override -- an interim default (a broad
			"pulse of the whole active board" reading), not yet tied to one
			specific consuming step's own verified text the way sibling
			ops' defaults are; see AgentsTools.MagicHeartbeat.include's own
			header for the full finding.

		--purge-cleanup
			Empties $MMDAPP/.local/.cleanup/ (the folder itself stays) --
			exists because Claude Code's own permission engine has no
			negative-glob syntax, so a blanket `Bash(rm *)` deny can never
			be carved into "except .cleanup/*" at the settings.json layer
			(deny always wins over allow regardless of specificity). This op
			is the sanctioned way to
			actually empty it: the real `rm` call happens inside this
			already-allowlisted script invocation, never as a raw top-level
			`rm` command, so the deny rule's literal prefix-match on `rm `
			never sees it. **Takes no arguments** -- the target is a fixed,
			code-determined path, never caller input: this op cleans exactly
			one predefined folder, nothing else, so there's nothing to
			parameterize. That fixed
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
		`DistroAgentsTools.fn.sh --member-slack-send-message keeper-myx magic-team Build finished OK.`

		# Send a threaded reply with rich Block Kit formatting from stdin -- heredoc,
		# not a piping command in front; --from-stdin is the standardized name
		# (--message-from-stdin still works too, same flag)
		```
		DistroAgentsTools.fn.sh --member-slack-send-message keeper-myx C0123ABCD:1700000000.000100 --from-stdin --format blocks <<'EOF'
		[{"type":"section","text":{"type":"mrkdwn","text":"*done*"}}]
		EOF
		```

		# Send the same via --file instead -- write content with a plain Write tool
		# call first, then this stays a single-line command
		`DistroAgentsTools.fn.sh --member-slack-send-message keeper-myx magic-team --file /path/to/message.txt`

		# Mark an email UID as read after processing it
		`DistroAgentsTools.fn.sh --mark-email-seen 48`

		# Write/update a board Item -- magic-coordinator-only op, see --write-board-item above
		```
		DistroAgentsTools.fn.sh --write-board-item backlog task-example.md <<'EOF'
		... board item content ...
		EOF
		```

		# Post a note into another member's own personal inbox
		```
		DistroAgentsTools.fn.sh --member-upsert-inbox-note keeper-myx 2026-07-22-note-example.md <<'EOF'
		... note content ...
		EOF
		```

		# Same, via --file instead -- write content with a plain Write tool call
		# first, then this stays a single-line command
		`DistroAgentsTools.fn.sh --member-upsert-inbox-note keeper-myx 2026-07-22-note-example.md --file /path/to/note.md`

		# Pass an inquiry along to another member's own inbox
		```
		DistroAgentsTools.fn.sh --member-upsert-member-inquiry keeper-ae3 2026-07-24-inquiry-example.md <<'EOF'
		... inquiry content ...
		EOF
		```

		# Append one session transcript entry (one call = one entry block)
		`DistroAgentsTools.fn.sh --member-append-session-transcript magic-coordinator --speaker human-owner --timestamp 2026-07-26T12:34:56Z --message "Approved. Proceed." --transcript-name transcript-2026-07-26-example.md --workspace-root /Users/myx/.claude/skills/magic-team --create`

		# Track a workspace path for the human-owner
		`DistroAgentsTools.fn.sh --owner-workspace-upsert /Volumes/ws-2017/myx-work`

		# Stop tracking it
		`DistroAgentsTools.fn.sh --owner-workspace-forget /Volumes/ws-2017/myx-work`

		# List every currently-tracked workspace path
		`DistroAgentsTools.fn.sh --owner-workspace-list`

		# Track this tool's own workspace root and print its path
		`DistroAgentsTools.fn.sh --owner-workspace-current`

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
		# NOT a required pre-step before --member-slack-send-message --format blocks (that op
		# already validates its own stdin internally, see --member-slack-send-message above)
		`DistroAgentsTools.fn.sh --validate-json /path/to/payload.json`

		# Ad hoc: check JSON from stdin the same way -- heredoc, not a piping command in front
		```
		DistroAgentsTools.fn.sh --validate-json <<'EOF'
		[{"type":"section","text":{"type":"mrkdwn","text":"*ok*"}}]
		EOF
		```

		# Regenerate a member's own assembled SLIB file -- heredoc, not a piping command in front
		```
		DistroAgentsTools.fn.sh --write-slib routine-grooming <<'EOF'
		... full routine-grooming.SLIB.md content ...
		EOF
		```

		# Same, via --file instead -- write content with a plain Write tool call
		# first, then this stays a single-line command
		`DistroAgentsTools.fn.sh --write-slib keeper-acm --file /path/to/keeper-acm.SLIB.md`

		# Existence + line count for a batch of files in one call, instead of a hand-rolled `for`/`wc -l` loop
		`DistroAgentsTools.fn.sh --list-md /path/to/one.md /path/to/two.md /path/to/missing.md`
		# -> /path/to/one.md: 67 lines
		# -> /path/to/two.md: 43 lines
		# -> /path/to/missing.md: MISSING
		# (returns 1 since one path was missing)
