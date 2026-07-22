#!/usr/bin/env bash

##
## NOTE:
## Standard `.fn.sh` entry point, same shape as the rest of the
## Distro*Tools.fn.sh family (see myx.distro-system/CLAUDE.md's "Command
## layout & help conventions"). Run it directly (bare, via PATH, or full
## path) from inside or outside any console — this tool's whole job is to
## START a new console session, so it can't rely on one already being open.
##
## Automates the manual Keep-Alive Workspace Console Session recipe
## documented in magic-coordinator's routines/console-sessions.md:
## a FIFO + a backgrounded `exec 9>fifo; sleep TTL` holder process keep a
## `Distro*Console.sh --non-interactive` session's stdin open indefinitely,
## so multiple rounds of commands can be piped in without re-paying the
## console bootstrap cost each time.
##
## Channel dirs are session plumbing ONLY (fifo/log/pid/meta) — never a
## place to drop secrets material. If/when magic-coordinator's consolidated
## secrets file ever moves under this tool's management, it should be
## sourced directly into the console's own environment, not staged as a
## file inside a channel dir, so `--stop-console`'s `rm -rf` (scoped to one
## mktemp-generated channel dir, never a fixed/shared path) can never take
## credentials down with it.
##
## Deliberately NOT built here: a queue/working/finished file-drop protocol.
## The FIFO + sentinel-in-log flow already IS the queue (commands arrive in
## order, a sentinel marks completion) for the single-producer case this
## tool serves today. No precedent for a 3-stage directory queue exists
## anywhere in myx.distro-*/myx.common; revisit only if/when multiple
## independent producers need to submit into one shared console out of band.
##
## Convention note (2026-07-21 refactor): brought in line with the rest of
## the Distro*Tools/Distro*Command family (DistroLocalTools.fn.sh,
## DistroSourceCommand.fn.sh, DistroImageCommand.fn.sh) — exactly ONE
## top-level function matching this file's own name (`DistroAgentsTools`),
## dispatching every operation via a single `case "$1" in ... esac`. Prior
## shape had a separate `DistroAgentsTools<OpName>` function per operation,
## called with all args forwarded from the dispatcher — that's the pattern
## no sibling tool uses, and it's also what made the earlier bare
## `DistroAgentsTools --agent-config-option ...` self-call bug possible in
## the first place (a function calling back into a sibling function that
## only exists because the op was split out to begin with). Genuinely
## shared, non-op-specific utility helpers (channel/workspace resolution)
## stay as small separate functions, same category as this family's own
## portable library primitives (GitClonePull/Prefix/CatMarkdown in
## DistroLocalTools.fn.sh) — reused plumbing, not "one function per op".
## One op invoking another (e.g. --self-test calling --verify-permissions,
## --sweep-read-incoming-comms's no-target sweep calling itself once per
## watched target) does so via self-recursion into `DistroAgentsTools`
## itself, matching DistroLocalTools.fn.sh's own `--upgrade-installed-tools`
## precedent (`DistroLocalTools --install-distro-$ITEM`), not via a private
## helper function.
##
## Direct human-owner correction, 2026-07-21: "Stop doing tons of simple
## functions in DistroAgentsTools — convention is to inline, ESPECIALLY
## SINGLE-LINERS." If a piece of logic is only ever used by one op, it goes
## inline in that op's own `case` arm — it does NOT become a new top-level
## helper just because it's a few lines long or "could be reused someday."
## The existing helpers above this line are already-established, genuinely
## multi-op-shared plumbing (channel/workspace/target resolution, perm
## checks) — that list is not license to keep adding more.
##

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/.local" ] || ( echo "⛔ ERROR: expecting '.local' directory." >&2 && exit 1 )
fi

: "${MDLT_ORIGIN:=$MMDAPP/.local}"
export MDLT_ORIGIN

## Copied verbatim from DistroLocalTools.fn.sh's own bootstrap -- needed here
## for --agent-config-option (sources myx.distro-.local's shared
## LocalTools.Config.include) and --send-message (reuses myx.common's
## agentMcpJsonEscape.awk rather than inventing another JSON escaper).
if   [ -d "$MYXROOT" ] && [ -f "$MYXROOT/share/myx.common/bin/lib/catMarkdown.Common" ]; then
	export MYXROOT
elif   [ -f "$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common/bin/lib/catMarkdown.Common" ]; then
	export MYXROOT="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
elif [ -f "/usr/local/share/myx.common/bin/lib/catMarkdown.Common" ]; then
	export MYXROOT="/usr/local/share/myx.common"
elif command -v myx.common 2>/dev/null && myx.common which lib/catMarkdown 2>/dev/null ; then
	export MYXROOT="$( myx.common which lib/catMarkdown | sed -e 's|/bin/lib/catMarkdown.*$||' )"
else
	export MYXROOT=''
fi

## Channel dirs live at $TMPDIR (or /tmp)/$MDAT_CHANNEL_PREFIX.<workspace-slug>.<console> —
## a DETERMINISTIC id (workspace absolute path + console name, hashed with
## `cksum`), NOT a `mktemp -d` random suffix: the same (workspace, console)
## pair always resolves to the same channel dir/log path across restarts, so
## that path can be added once to an allowlist (e.g. Claude Code's
## settings.json) and stay valid forever — a random-per-invocation name can
## never be allowlisted. `--start-console` is idempotent: called again for a
## (workspace, console) pair that's already alive, it reuses the existing
## channel instead of minting a new one; if the channel dir exists but its
## processes are dead, it's wiped and recreated. One channel is naturally
## shared by all concurrent callers against the same workspace+console — safe
## since read/scan sessions are explicitly not ownership-gated (unchanged
## from the original design). Default workspace is the tool's own ($MMDAPP);
## `--override-workspace` (on --start-console and --list-consoles alike) is
## the only escape hatch to point at a different workspace.
MDAT_CHANNEL_PREFIX="myx.distro-agent-console"
MDAT_DEFAULT_TTL="3600"

##
## Shared utility helpers -- genuinely reused across multiple unrelated ops
## below, same category as DistroLocalTools.fn.sh's GitClonePull/Prefix/
## CatMarkdown: reusable plumbing, not a stand-in for a dispatch case.
##

DistroAgentsToolsResolveChannelDir(){
	local ref="$1"
	if [ -z "$ref" ] ; then
		echo "⛔ ERROR: DistroAgentsTools: channel id or path required" >&2
		return 1
	fi
	case "$ref" in
		/*)
			if [ -d "$ref" ] ; then echo "$ref" ; return 0 ; fi
		;;
	esac
	local candidate="${TMPDIR:-/tmp}/$ref"
	if [ -d "$candidate" ] ; then echo "$candidate" ; return 0 ; fi
	candidate="${TMPDIR:-/tmp}/${MDAT_CHANNEL_PREFIX}.$ref"
	if [ -d "$candidate" ] ; then echo "$candidate" ; return 0 ; fi
	echo "⛔ ERROR: DistroAgentsTools: channel not found: $ref" >&2
	return 1
}

## Deterministic workspace identity: same absolute path always yields the
## same short slug, so channel ids are stable across processes/restarts.
## `cksum` (POSIX, present on both macOS and Linux) needs no extra tooling.
DistroAgentsToolsResolveWorkspaceSlug(){
	printf '%s' "$1" | cksum | awk '{print $1}'
}

## Resolves a workspace argument (or $MMDAPP if empty) to an absolute path,
## erroring if it's not a directory. Used by both --start-console's
## --override-workspace and --list-consoles' --override-workspace so the two
## agree on what "own workspace" means.
DistroAgentsToolsResolveWorkspace(){
	local workspace="${1:-$MMDAPP}"
	if [ ! -d "$workspace" ] ; then
		echo "⛔ ERROR: DistroAgentsTools: workspace not found: $workspace" >&2
		return 1
	fi
	( cd "$workspace" && pwd )
}

DistroAgentsToolsResolveConsoleShortName(){
	case "$1" in
		DistroSourceConsole.sh) echo "source" ;;
		DistroDeployConsole.sh) echo "deploy" ;;
		*) echo "⛔ ERROR: DistroAgentsTools: unrecognized console: $1" >&2 ; return 1 ;;
	esac
}

## Portable single-path permission lookup (BSD stat, then GNU stat) -- no
## existing precedent for this in myx.distro-*/myx.common, so falls back
## across both flavors rather than assuming one.
DistroAgentsToolsPermOf(){
	stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null
}

## Resolves a --send-message/--sweep-read-incoming-comms/--send-email-message
## style target (magic-team|human-owner|<channel>:<ts>) to a channel id +
## optional thread ts. Shared resolution grammar across three ops -- kept as
## a utility helper (like the ones above) rather than duplicated three times.
DistroAgentsToolsResolveTarget(){
	local target="$1"
	local channel threadTs
	case "$target" in
		magic-team)
			channel="$( DistroAgentsTools --agent-config-option --select SLACK_CHANNEL_MAGIC_TEAM )"
		;;
		human-owner)
			channel="$( DistroAgentsTools --agent-config-option --select SLACK_CHANNEL_HUMAN_OWNER )"
		;;
		*:*)
			channel="${target%%:*}"
			threadTs="${target#*:}"
		;;
		*)
			return 2
		;;
	esac
	if [ -z "$channel" ] ; then
		return 1
	fi
	printf 'CHANNEL=%s\nTHREAD_TS=%s\n' "$channel" "$threadTs"
	return 0
}

##
## The one real dispatcher -- every operation lives in its own case branch,
## inline or via self-recursion into DistroAgentsTools itself, never a
## separate DistroAgentsTools<OpName> function.
##
DistroAgentsTools(){
	local MDSC_CMD='DistroAgentsTools'
	[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $@" >&2
	set -e

	case "$1" in
		--start-console)
			shift

			local workspaceArg consoleOverride ttl="$MDAT_DEFAULT_TTL"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--override-workspace)
						workspaceArg="$2" ; shift 2
					;;
					--console)
						consoleOverride="$2" ; shift 2
					;;
					--ttl)
						ttl="$2" ; shift 2
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --start-console: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done

			local workspace
			workspace="$( DistroAgentsToolsResolveWorkspace "$workspaceArg" )" || { set +e ; return 1 ; }

			local consoleName
			if [ -n "$consoleOverride" ] ; then
				case "$consoleOverride" in
					DistroSourceConsole.sh|DistroDeployConsole.sh) ;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --start-console: --console must be DistroSourceConsole.sh or DistroDeployConsole.sh (Local/Remote not supported)" >&2
						set +e ; return 1
					;;
				esac
				if [ ! -x "$workspace/$consoleOverride" ] ; then
					echo "⛔ ERROR: $MDSC_CMD --start-console: $consoleOverride not found/executable in $workspace" >&2
					set +e ; return 1
				fi
				consoleName="$consoleOverride"
			elif [ -x "$workspace/DistroSourceConsole.sh" ] ; then
				consoleName="DistroSourceConsole.sh"
			elif [ -x "$workspace/DistroDeployConsole.sh" ] ; then
				consoleName="DistroDeployConsole.sh"
			else
				echo "⛔ ERROR: $MDSC_CMD --start-console: neither DistroSourceConsole.sh nor DistroDeployConsole.sh found in $workspace" >&2
				set +e ; return 1
			fi

			local consoleShortName
			consoleShortName="$( DistroAgentsToolsResolveConsoleShortName "$consoleName" )" || { set +e ; return 1 ; }

			local slug ; slug="$( DistroAgentsToolsResolveWorkspaceSlug "$workspace" )"
			local channelId="${MDAT_CHANNEL_PREFIX}.${slug}.${consoleShortName}"
			local channelDir="${TMPDIR:-/tmp}/$channelId"
			local fifo="$channelDir/fifo"
			local log="$channelDir/console.log"

			## Idempotent reuse: if this workspace+console already has a live
			## channel, hand back its details instead of minting a duplicate.
			## If the dir exists but its processes are dead, wipe and recreate —
			## never silently leave a half-dead channel behind.
			if [ -d "$channelDir" ] ; then
				local oldConsolePid oldHolderPid
				if [ -f "$channelDir/console.pid" ] ; then oldConsolePid="$( cat "$channelDir/console.pid" 2>/dev/null )" ; fi
				if [ -f "$channelDir/holder.pid" ] ; then oldHolderPid="$( cat "$channelDir/holder.pid" 2>/dev/null )" ; fi
				if [ -n "$oldConsolePid" ] && kill -0 "$oldConsolePid" 2>/dev/null \
					&& [ -n "$oldHolderPid" ] && kill -0 "$oldHolderPid" 2>/dev/null ; then
					echo "# $MDSC_CMD --start-console: reusing already-active channel for $workspace ($consoleName)" >&2
					echo "CHANNEL=$channelId"
					echo "CHANNEL_DIR=$channelDir"
					echo "FIFO=$fifo"
					echo "LOG=$log"
					echo "CONSOLE=$consoleName"
					echo "WORKSPACE=$workspace"
					echo "HOLDER_PID=$oldHolderPid"
					echo "CONSOLE_PID=$oldConsolePid"
					echo "# send a command:  DistroAgentsTools.fn.sh --send-console $channelId -- your command here"
					echo "# tail output:     tail -f \"$log\""
					echo "# stop session:    DistroAgentsTools.fn.sh --stop-console $channelId"
					return 0
				fi
				echo "# $MDSC_CMD --start-console: stale channel found (no live processes), recreating: $channelDir" >&2
				## NOTE: under `set -e` (active for this whole function), a bare
				## `kill` on an already-dead pid returns non-zero and would
				## silently abort here mid-recreate — hence the explicit
				## `|| true` guards, not just a redirected stderr.
				if [ -n "$oldConsolePid" ] ; then kill -9 "$oldConsolePid" 2>/dev/null || true ; fi
				if [ -n "$oldHolderPid" ] ; then kill -9 "$oldHolderPid" 2>/dev/null || true ; fi
				rm -rf "$channelDir"
			fi

			mkdir -p "$channelDir" || {
				echo "⛔ ERROR: $MDSC_CMD --start-console: can't create channel directory: $channelDir" >&2
				set +e ; return 1
			}

			mkfifo "$fifo" || {
				echo "⛔ ERROR: $MDSC_CMD --start-console: mkfifo failed" >&2
				rm -rf "$channelDir"
				set +e ; return 1
			}
			: > "$log"

			## Keep-alive FIFO-holder: opens the write end and sleeps, so the
			## console's read end never sees EOF between rounds. Same mechanism as
			## console-sessions.md's documented manual recipe.
			nohup bash -c "exec 9>\"$fifo\"; sleep \"$ttl\"" >/dev/null 2>&1 &
			local holderPid=$!
			disown 2>/dev/null || true
			echo "$holderPid" > "$channelDir/holder.pid"

			## Console self-locates its own workspace root from $0 (see
			## DistroSourceConsole.sh's own MMDAPP bootstrap), so an absolute path
			## here doesn't require changing this shell's cwd.
			nohup "$workspace/$consoleName" --non-interactive < "$fifo" >> "$log" 2>&1 &
			local consolePid=$!
			disown 2>/dev/null || true
			echo "$consolePid" > "$channelDir/console.pid"

			{
				echo "MDAT_WORKSPACE=$workspace"
				echo "MDAT_CONSOLE=$consoleName"
				echo "MDAT_TTL=$ttl"
				echo "MDAT_CREATED=$( date -u +%Y-%m-%dT%H:%M:%SZ )"
			} > "$channelDir/meta.env"

			echo "CHANNEL=$channelId"
			echo "CHANNEL_DIR=$channelDir"
			echo "FIFO=$fifo"
			echo "LOG=$log"
			echo "CONSOLE=$consoleName"
			echo "WORKSPACE=$workspace"
			echo "HOLDER_PID=$holderPid"
			echo "CONSOLE_PID=$consolePid"
			echo "# send a command:  printf '%s\n' 'your command' > \"$fifo\""
			echo "# or:              DistroAgentsTools.fn.sh --send-console $channelId -- your command here"
			echo "# tail output:     tail -f \"$log\""
			echo "# stop session:    DistroAgentsTools.fn.sh --stop-console $channelId"
			return 0
		;;

		--send-console)
			shift
			local ref="$1"
			shift || true
			local channelDir
			channelDir="$( DistroAgentsToolsResolveChannelDir "$ref" )" || { set +e ; return 1 ; }
			local fifo="$channelDir/fifo"
			if [ ! -p "$fifo" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --send-console: fifo not found: $fifo" >&2
				set +e ; return 1
			fi
			if [ "$1" = "--" ] ; then shift ; fi
			if [ $# -gt 0 ] ; then
				printf '%s\n' "$*" > "$fifo"
			else
				cat > "$fifo"
			fi
			return 0
		;;

		--stop-console)
			shift
			local ref="$1"
			local channelDir
			channelDir="$( DistroAgentsToolsResolveChannelDir "$ref" )" || { set +e ; return 1 ; }

			## NOTE: under `set -e`, a bare `[ test ] && command` used as a plain
			## statement aborts this whole branch the moment the test (or the
			## command) fails — e.g. no fifo, or the process already exited on
			## its own. Every check below is an `if`/`|| true`, never a bare
			## `&&`, so a partial/already-dead session still reaches the final
			## `rm -rf` instead of leaving a half-cleaned channel dir behind.
			## Confirmed live (2026-07-20, against a real stale channel):
			## opening a FIFO for writing blocks indefinitely if there's no
			## reader on the other end (POSIX FIFO semantics, not a bash
			## quirk). A channel whose console process already died still
			## leaves the FIFO special file behind, so an unconditional write
			## here can hang --stop-console forever. Only attempt the graceful
			## "exit" nudge while the console process is confirmed alive -- if
			## it's already dead there's no reader to nudge, and the hard-kill
			## path below still runs either way.
			local pid
			if [ -f "$channelDir/console.pid" ] ; then
				pid="$( cat "$channelDir/console.pid" 2>/dev/null )"
			fi

			local fifo="$channelDir/fifo"
			if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ -p "$fifo" ] ; then
				printf 'exit\n' > "$fifo" 2>/dev/null || true
				sleep 1
			fi

			if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null ; then
				kill "$pid" 2>/dev/null || true
				sleep 1
				if kill -0 "$pid" 2>/dev/null ; then kill -9 "$pid" 2>/dev/null || true ; fi
			fi
			if [ -f "$channelDir/holder.pid" ] ; then
				pid="$( cat "$channelDir/holder.pid" )"
				if kill -0 "$pid" 2>/dev/null ; then
					kill "$pid" 2>/dev/null || true
					sleep 1
					if kill -0 "$pid" 2>/dev/null ; then kill -9 "$pid" 2>/dev/null || true ; fi
				fi
			fi

			local channelId ; channelId="$( basename "$channelDir" )"
			rm -rf "$channelDir"
			echo "STOPPED=$channelId"
			return 0
		;;

		--list-consoles)
			shift
			local workspaceArg
			while [ $# -gt 0 ] ; do
				case "$1" in
					--override-workspace)
						workspaceArg="$2" ; shift 2
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --list-consoles: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done

			## Default scope is the tool's own workspace — per design direction,
			## --list-consoles must not surface every workspace's channels by
			## default, only this one's (or an explicitly overridden one).
			local workspace
			workspace="$( DistroAgentsToolsResolveWorkspace "$workspaceArg" )" || { set +e ; return 1 ; }

			local base="${TMPDIR:-/tmp}"
			local dir found
			found=0
			for dir in "$base/${MDAT_CHANNEL_PREFIX}."* ; do
				[ -d "$dir" ] || continue
				local ws cons consoleAlive holderAlive
				ws="$( sed -n 's/^MDAT_WORKSPACE=//p' "$dir/meta.env" 2>/dev/null )"
				[ "$ws" = "$workspace" ] || continue
				found=1
				local id ; id="$( basename "$dir" )"
				cons="$( sed -n 's/^MDAT_CONSOLE=//p' "$dir/meta.env" 2>/dev/null )"
				consoleAlive="dead"
				holderAlive="dead"
				[ -f "$dir/console.pid" ] && kill -0 "$( cat "$dir/console.pid" )" 2>/dev/null && consoleAlive="alive"
				[ -f "$dir/holder.pid" ] && kill -0 "$( cat "$dir/holder.pid" )" 2>/dev/null && holderAlive="alive"
				echo "$id  console=$consoleAlive holder=$holderAlive workspace=${ws:-?} console-script=${cons:-?}"
			done
			[ "$found" = "1" ] || echo "(no active channels for workspace: $workspace)"
			return 0
		;;

		--agent-config-option)
			. "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include"
			return 0
		;;

		## Posts to Slack via chat.postMessage. Secret handling: SLACK_BOT_TOKEN
		## is resolved on demand (one --agent-config-option --select call, right
		## before use), then written to a private (chmod 600) mktemp header
		## file and passed to curl via `-H @file` (trap-cleaned on exit) rather
		## than as an inline argv string -- keeps the token out of
		## `ps`/`/proc/<pid>/cmdline` for the curl invocation's lifetime. Never
		## echoed/printed anywhere in this branch. The visible-command line
		## printed before sending mirrors DistroLocalTools.fn.sh:316's
		## convention, with the token redacted.
		##
		## Resilience (2026-07-21, per direct human-owner instruction after a
		## transient DNS blip on slack.com silently dropped a send): "do not
		## quit - assume it is working - backoff to email if see no response."
		## Retries a handful of times with increasing backoff before treating
		## the send as failed (covers exactly the class of transient network
		## hiccup already documented for imap.gmail.com/smtp.gmail.com in this
		## same environment, not a persistent block) -- only falls back to
		## email once genuinely exhausted, never on the first blip. Success is
		## detected by grepping for `"ok":true` in the raw response body --
		## this shell layer has no real JSON parser, and a literal `"ok":true`
		## substring match is reliable enough for Slack's actual response
		## shape without inventing one. The fallback itself is a real,
		## separately-callable op (--send-email-message) invoked here via
		## self-recursion, not a private-only helper.
		--send-message)
			shift
			local target="$1"
			shift || true

			if [ -z "$target" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --send-message: target required (magic-team|human-owner|<channel>:<ts>)" >&2
				set +e ; return 1
			fi

			local resolved channel="" threadTs=""
			resolved="$( DistroAgentsToolsResolveTarget "$target" )"
			case "$?" in
				0)
					channel="$( printf '%s\n' "$resolved" | sed -n 's/^CHANNEL=//p' )"
					threadTs="$( printf '%s\n' "$resolved" | sed -n 's/^THREAD_TS=//p' )"
				;;
				2)
					echo "⛔ ERROR: $MDSC_CMD --send-message: unrecognized target: $target" >&2
					set +e ; return 1
				;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --send-message: could not resolve a channel for target '$target' -- check SLACK_CHANNEL_MAGIC_TEAM/SLACK_CHANNEL_HUMAN_OWNER in .local/.agents" >&2
					set +e ; return 1
				;;
			esac

			local format="text" fromStdin="false"
			local textArgs stdinContent
			while [ $# -gt 0 ] ; do
				case "$1" in
					--message-from-stdin|--from-stdin)
						## Added 2026-07-22: `--from-stdin` is the standardized,
						## uniform name for "read content from stdin instead of argv"
						## across every DistroAgentsTools op that accepts free-text
						## content (see also --send-email-message's body below,
						## --validate-json's bare-stdin mode) -- `--message-from-stdin`
						## stays recognized too, unchanged, since it's already
						## documented/used across several skill files; this is an
						## additive alias, not a rename.
						fromStdin="true" ; shift
					;;
					--file)
						## Added 2026-07-22 -- lets a caller write content to a plain
						## temp file first (an ordinary Write tool call, no Bash
						## prompt) and still invoke --send-message as one single-line
						## command, since a heredoc body makes the invoked command
						## span multiple lines and no longer match a single-line
						## settings.json allowlist glob. Validated and consumed
						## directly here, at point of use, into the SAME stdinContent
						## variable --from-stdin's own downstream handling already
						## reads -- no separate fromFile="" sentinel held across
						## branches (that shape was rejected live, 2026-07-22, for
						## exactly this op -- see keeper-myx/KEEPER-LOG.md's dated
						## entry for the corrected shape this follows).
						if [ -z "$2" ] || [ ! -f "$2" ] ; then
							echo "⛔ ERROR: $MDSC_CMD --send-message: --file: file not found: $2" >&2
							set +e ; return 1
						fi
						stdinContent="$( cat "$2" )"
						fromStdin="true"
						shift 2
					;;
					--format)
						format="$2" ; shift 2
					;;
					--*)
						## Bug fix, 2026-07-22 (real live incident): an
						## unrecognized flag-shaped token silently fell through to
						## the catch-all below and got posted to #magic-team as
						## literal message text -- a stray "--from-stdin" ended up
						## as the entire "text" field, with ok:true coming back,
						## so it wasn't even a visible failure. Any token starting
						## with "--" that didn't match a known option above is
						## almost always a typo/wrong-order/mis-recognized flag,
						## not intended literal content -- fail loud here instead
						## of silently absorbing it as text. Genuine literal text
						## starting with "--" should go through --from-stdin/--file
						## instead.
						echo "⛔ ERROR: $MDSC_CMD --send-message: unrecognized option: $1 (if you need literal text starting with '--', use --from-stdin/--file instead of trailing argv)" >&2
						set +e ; return 1
					;;
					*)
						textArgs="$textArgs $1" ; shift
					;;
				esac
			done

			local rawText blocksJson
			if [ "$fromStdin" = "true" ] ; then
				## stdinContent may already be populated by --file above; only
				## read real stdin here if it wasn't (--from-stdin, not --file,
				## is what set fromStdin=true in that case).
				[ -n "$stdinContent" ] || stdinContent="$( cat )"
				if [ "$format" = "blocks" ] ; then
					blocksJson="$stdinContent"

					## `blocksJson` gets spliced straight into the payload below
					## (`"blocks":$blocksJson`) with no escaping, unlike `rawText`
					## (which goes through agentMcpJsonEscape.awk) -- this command's
					## own contract for --format blocks always expects a bare JSON
					## array here, so validate that before it ever reaches curl.
					## Bug reproduced live 2026-07-22: a caller's stdin content
					## carried a stray leading ":" (leftover from a "blocks: [...]"
					## -style paste, i.e. not actually a bare array), which spliced
					## into a literal `"blocks"::[...]` in the payload -- Slack's
					## chat.postMessage bounced that as invalid_json on all 5
					## retries, with nothing in the error pointing at the actual
					## cause. Reuses this same file's own --validate-json op via
					## self-recursion (same convention as --send-email-message's
					## fallback call below) for full JSON-syntax validation, per
					## the human-owner's own "always use it" instruction for
					## --validate-json, rather than hand-rolling a second, weaker
					## JSON check here. --validate-json accepts any syntactically
					## valid top-level JSON value though (object, string, number,
					## ...), so a cheap bare `[` ... `]` shape check is layered on
					## top of it to enforce the array-specifically requirement
					## Slack's `blocks` field actually has.
					if ! printf '%s' "$blocksJson" | DistroAgentsTools --validate-json ; then
						echo "⛔ ERROR: $MDSC_CMD --send-message: --format blocks stdin failed --validate-json (see above)" >&2
						set +e ; return 1
					fi
					local blocksTrimmed
					blocksTrimmed="$( printf '%s' "$blocksJson" | LC_ALL=C awk 'BEGIN{RS="\0"} { gsub(/^[ \t\r\n]+/, ""); gsub(/[ \t\r\n]+$/, ""); printf "%s", $0 }' )"
					case "$blocksTrimmed" in
						'['*']')
						;;
						*)
							echo "⛔ ERROR: $MDSC_CMD --send-message: --format blocks stdin is valid JSON but not a bare array (must start with '[' and end with ']')" >&2
							set +e ; return 1
						;;
					esac

					## Added 2026-07-22, real live incident: Slack rejected a
					## chat.postMessage call with `invalid_blocks: unsupported type
					## "mrkdwn" [json-pointer:/blocks/3/type]` -- a caller had nested
					## a text-object type (`mrkdwn`, only valid inside a block's own
					## `text` field) directly as a top-level block's own `type`, which
					## Slack's Block Kit does not accept as a block type. Neither the
					## --validate-json check above (syntax only) nor the bare-array
					## check above (shape only) catches this -- both are satisfied by
					## a syntactically-valid array of objects regardless of what each
					## object's own "type" value actually is. This is a cheap,
					## non-recursive structural check (does every top-level element
					## have a "type" key whose value is one of Slack's known top-level
					## block types) layered on top of the syntax/shape checks, same
					## spirit as those -- NOT a full Block Kit schema validator (this
					## shell layer has no real JSON parser beyond what python3/awk give
					## it here), so it deliberately does not recurse into each block's
					## own nested fields (text objects, elements, accessory, ...).
					local blocksBadTypes
					blocksBadTypes="$( printf '%s' "$blocksJson" | python3 -c '
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
' 2>/dev/null )"
					if [ -n "$blocksBadTypes" ] ; then
						echo "⛔ ERROR: $MDSC_CMD --send-message: --format blocks stdin has an invalid/missing top-level 'type' at block index(es) $blocksBadTypes -- mrkdwn/plain_text/etc. are TEXT-OBJECT types, valid only nested inside a block's own \"text\" field, never as a block's own \"type\" (valid top-level types: section, divider, header, context, image, actions, input, video, rich_text, file)" >&2
						set +e ; return 1
					fi

					## NOTE: not auto-deriving a text fallback from the blocks' own
					## text.text fields yet (that needs real JSON parsing this shell
					## layer doesn't have) -- using a static fallback instead. Revisit
					## with a real parser (e.g. agentMcpJsonParseRequest.awk's
					## approach) if Slack's own notification quality demands better.
					rawText="(formatted message -- see blocks)"
				else
					rawText="$stdinContent"
				fi
			else
				rawText="${textArgs# }"
			fi

			if [ -z "$rawText" ] && [ -z "$blocksJson" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --send-message: no text/blocks content given" >&2
				set +e ; return 1
			fi

			## Reuse myx.common's existing JSON-string escaper (agentMcpJsonEscape.awk,
			## already shipped for agentMcpServer.sh) rather than inventing another one.
			local escapedText
			escapedText="$( printf '%s' "$rawText" | LC_ALL=C awk -f "$MYXROOT/include/data/agentMcpJsonEscape.awk" )"

			local payload="{\"channel\":\"$channel\",\"text\":\"$escapedText\""
			[ -z "$threadTs" ] || payload="$payload,\"thread_ts\":\"$threadTs\""
			[ -z "$blocksJson" ] || payload="$payload,\"blocks\":$blocksJson"
			payload="$payload}"

			echo "# $MDSC_CMD --send-message: POST https://slack.com/api/chat.postMessage -H 'Authorization: Bearer \$SLACK_BOT_TOKEN' -H 'Content-type: application/json' -d '$payload'" >&2

			local token
			token="$( DistroAgentsTools --agent-config-option --select SLACK_BOT_TOKEN )"
			if [ -z "$token" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --send-message: SLACK_BOT_TOKEN not set in .local/.agents (see --agent-config-option --upsert)" >&2
				set +e ; return 1
			fi

			## Token goes into a private (chmod 600) temp file, read by curl via
			## `-H @file` (curl >= 7.55.0) rather than as an inline argv string --
			## avoids the token being visible in `ps`/`/proc/<pid>/cmdline` for
			## the curl invocation's lifetime.
			local headerFile
			headerFile="$( mktemp )" || { set +e ; return 1 ; }
			chmod 600 "$headerFile"
			trap 'rm -f "$headerFile"' EXIT
			printf 'Authorization: Bearer %s\n' "$token" > "$headerFile"

			local response attempt=1 maxAttempts=5 backoff=2 sent="false"
			while [ "$attempt" -le "$maxAttempts" ] ; do
				response="$( curl -sS -X POST "https://slack.com/api/chat.postMessage" \
					-H @"$headerFile" \
					-H "Content-type: application/json" \
					-d "$payload" 2>&1 )"
				if printf '%s' "$response" | grep -q '"ok":true' ; then
					sent="true"
					break
				fi
				echo "# $MDSC_CMD --send-message: attempt $attempt/$maxAttempts did not confirm ok:true, retrying in ${backoff}s -- $response" >&2
				sleep "$backoff"
				attempt=$(( attempt + 1 ))
				backoff=$(( backoff * 2 ))
			done

			rm -f "$headerFile"
			trap - EXIT

			if [ "$sent" = "true" ] ; then
				printf '%s\n' "$response"
				return 0
			fi

			## NOT a channel switch -- email here is a notification that Slack
			## itself is stuck, not a substitute delivery path for the message.
			## The message stays queued for Slack; the email's job is only to
			## say so and describe what's waiting, per direct human-owner
			## instruction: "do not switch from Slack to email just use email
			## to inform that comms stuck (in Slack)."
			echo "⛔ $MDSC_CMD --send-message: Slack did not confirm after $maxAttempts attempts -- notifying by email that Slack comms are stuck" >&2
			local fallbackUser
			fallbackUser="$( DistroAgentsTools --agent-config-option --select EMAIL_USER )"
			if [ -z "$fallbackUser" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --send-message: no EMAIL_USER configured, cannot notify" >&2
				set +e ; return 1
			fi
			DistroAgentsTools --send-email-message "$fallbackUser" -- \
				"Slack comms stuck -- message queued for target $target" -- \
				"Slack did not confirm this send after $maxAttempts retries -- comms to Slack appear stuck." "" \
				"Nothing was rerouted to email -- this is a notification only. The" \
				"message below stays queued for Slack and should go out once it" \
				"recovers; retry --send-message manually if it doesn't." "" \
				"Target: $target" "" \
				"Queued message:" "$rawText" "" \
				"Last Slack error response:" "$response"
			return $?
		;;

		## Real, standalone op -- not just an internal-only fallback. Direct
		## curl SMTP send (matches the curl --url smtp://... --ssl-reqd pattern
		## already verified working in this environment for outbound mail, not
		## a new untested mechanism), reusing the same EMAIL_* keys the comms
		## sweep already reads for IMAP. --send-message's exhausted-retry
		## fallback calls this same branch via self-recursion.
		--send-email-message)
			shift
			local recipients subject bodyLines state="recipients" bodyFromStdin="false" bodyFromFile="false"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--)
						if [ "$state" = "recipients" ] ; then state="subject"
						elif [ "$state" = "subject" ] ; then state="body"
						fi
						shift
					;;
					--from-stdin)
						## Added 2026-07-22: standardized stdin-content flag (same
						## name as --send-message's), only meaningful in the body
						## state -- reads the whole body from stdin instead of
						## trailing argv lines, avoiding the exact
						## shell-escaping/quoting fragility (multi-line free text as
						## separate argv words) that caused the --format blocks
						## bug this same day. Outside the body state it's treated
						## as ordinary literal content (matches this loop's
						## existing catch-all behavior for any other unrecognized
						## token) since recipients/subject aren't meant to come
						## from stdin.
						if [ "$state" = "body" ] ; then
							if [ "$bodyFromFile" = "true" ] ; then
								echo "⛔ ERROR: $MDSC_CMD --send-email-message: --from-stdin given alongside --file -- use one or the other, not both" >&2
								set +e ; return 1
							fi
							bodyFromStdin="true" ; shift
						else
							case "$state" in
								recipients) recipients="$recipients $1" ;;
								subject) subject="$subject $1" ;;
							esac
							shift
						fi
					;;
					--file)
						## Added 2026-07-22 -- same motivation as --send-message's own
						## --file (lets a caller write the body to a plain temp file
						## first, a normal Write tool call, and still invoke this op
						## as one single-line command). Validated and consumed
						## directly here, at point of use, into the existing
						## bodyLines variable -- a separate bodyFromFile flag (not a
						## bodyFromFile="" sentinel checked later) records the source
						## only to gate the conflict checks against --from-stdin/
						## trailing argv above/below; bodyLines itself is never held
						## as an empty-default placeholder.
						if [ "$state" = "body" ] ; then
							if [ "$bodyFromStdin" = "true" ] ; then
								echo "⛔ ERROR: $MDSC_CMD --send-email-message: --file given alongside --from-stdin -- use one or the other, not both" >&2
								set +e ; return 1
							fi
							if [ -z "$2" ] || [ ! -f "$2" ] ; then
								echo "⛔ ERROR: $MDSC_CMD --send-email-message: --file: file not found: $2" >&2
								set +e ; return 1
							fi
							bodyLines="$( cat "$2" )"
							bodyFromFile="true"
							shift 2
						else
							case "$state" in
								recipients) recipients="$recipients $1" ;;
								subject) subject="$subject $1" ;;
							esac
							shift
						fi
					;;
					*)
						case "$state" in
							recipients) recipients="$recipients $1" ;;
							subject) subject="$subject $1" ;;
							body)
								if [ "$bodyFromFile" = "true" ] ; then
									echo "⛔ ERROR: $MDSC_CMD --send-email-message: --file given alongside trailing body argv -- use one or the other, not both" >&2
									set +e ; return 1
								fi
								bodyLines="$bodyLines
$1"
							;;
						esac
						shift
					;;
				esac
			done
			recipients="${recipients# }"
			subject="${subject# }"

			if [ "$bodyFromStdin" = "true" ] ; then
				if [ -n "$bodyLines" ] ; then
					echo "⛔ ERROR: $MDSC_CMD --send-email-message: --from-stdin given alongside trailing body argv -- use one or the other, not both" >&2
					set +e ; return 1
				fi
				bodyLines="$( cat )"
			fi

			if [ -z "$recipients" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --send-email-message: at least one <email@address> required" >&2
				set +e ; return 1
			fi
			if [ -z "$subject" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --send-email-message: syntax is <email@address>... -- <subject> -- <body...>" >&2
				set +e ; return 1
			fi

			local emailUser emailPass smtpHost smtpPort
			emailUser="$( DistroAgentsTools --agent-config-option --select EMAIL_USER )"
			emailPass="$( DistroAgentsTools --agent-config-option --select EMAIL_APP_PASSWORD )"
			smtpHost="$( DistroAgentsTools --agent-config-option --select EMAIL_SMTP_HOST )"
			smtpPort="$( DistroAgentsTools --agent-config-option --select EMAIL_SMTP_PORT )"

			if [ -z "$emailUser" ] || [ -z "$emailPass" ] || [ -z "$smtpHost" ] || [ -z "$smtpPort" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --send-email-message: EMAIL_USER/EMAIL_APP_PASSWORD/EMAIL_SMTP_HOST/EMAIL_SMTP_PORT not fully set in .local/.agents" >&2
				set +e ; return 1
			fi

			local msgFile
			msgFile="$( mktemp )" || { set +e ; return 1 ; }
			{
				printf 'From: %s\n' "$emailUser"
				printf 'To: %s\n' "$( printf '%s' "$recipients" | tr ' ' ',' )"
				printf 'Subject: %s\n' "$subject"
				printf '\n'
				printf '%s\n' "$bodyLines"
			} > "$msgFile"

			local netrcFile
			netrcFile="$( mktemp )" || { rm -f "$msgFile" ; set +e ; return 1 ; }
			chmod 600 "$netrcFile"
			printf 'machine %s login %s password %s\n' "$smtpHost" "$emailUser" "$emailPass" > "$netrcFile"

			local rcptArgs=() addr
			for addr in $recipients ; do
				rcptArgs+=( --mail-rcpt "$addr" )
			done

			echo "# $MDSC_CMD --send-email-message: sending via smtp://${smtpHost}:${smtpPort} to: $recipients" >&2
			curl -sS --url "smtp://${smtpHost}:${smtpPort}" --ssl-reqd \
				--netrc-file "$netrcFile" \
				--mail-from "$emailUser" "${rcptArgs[@]}" \
				--upload-file "$msgFile"
			local rc=$?

			rm -f "$msgFile" "$netrcFile"

			if [ "$rc" -eq 0 ] ; then
				echo "# $MDSC_CMD --send-email-message: sent to $recipients" >&2
			else
				echo "⛔ $MDSC_CMD --send-email-message: FAILED (curl exit $rc)" >&2
			fi
			return "$rc"
		;;

		## Real gap this closes (2026-07-21, per direct human-owner
		## complaint): --sweep-read-incoming-comms already precodes Slack
		## reads, but email/Trello checks had no equivalent op, so every
		## comms sweep kept hand-rolling raw curl in Bash for those two --
		## exactly the "why is this not in tooling" friction that keeps
		## triggering fresh permission prompts a precoded op would avoid.
		## IMAP STATUS check (unseen count) plus a UID SEARCH UNSEEN (which
		## UIDs those are) -- not a full fetch, matches what the comms-sweep
		## routine's Check step needs, but also closes a real follow-on gap
		## found live the same session: STATUS alone gives a count with no
		## way to discover which UID(s) to hand to --read-email. UID SEARCH
		## returns a clean single-line response through curl --request
		## (unlike UID FETCH's literal-string body, which does not come
		## through this way -- confirmed live, that's why --read-email uses
		## curl's URL-based ;UID= addressing instead, not --request).
		--check-email)
			shift
			local imapHost imapUser imapPass
			imapHost="$( DistroAgentsTools --agent-config-option --select EMAIL_IMAP_HOST )"
			imapUser="$( DistroAgentsTools --agent-config-option --select EMAIL_USER )"
			imapPass="$( DistroAgentsTools --agent-config-option --select EMAIL_APP_PASSWORD )"
			if [ -z "$imapHost" ] || [ -z "$imapUser" ] || [ -z "$imapPass" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --check-email: EMAIL_IMAP_HOST/EMAIL_USER/EMAIL_APP_PASSWORD not fully set in .local/.agents" >&2
				set +e ; return 1
			fi
			curl -s --url "imaps://${imapHost}/INBOX" --user "${imapUser}:${imapPass}" \
				--request "STATUS INBOX (UNSEEN)"
			curl -s --url "imaps://${imapHost}/INBOX" --user "${imapUser}:${imapPass}" \
				--request "UID SEARCH UNSEEN"
			return $?
		;;

		## Same rationale as --check-email above -- Trello's own read side of
		## the same precoded-tooling gap. Unread notifications only (matches
		## the comms-sweep routine's Check step), not a full board read.
		--check-trello)
			shift
			local trelloKey trelloToken
			trelloKey="$( DistroAgentsTools --agent-config-option --select TRELLO_KEY )"
			trelloToken="$( DistroAgentsTools --agent-config-option --select TRELLO_TOKEN )"
			if [ -z "$trelloKey" ] || [ -z "$trelloToken" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --check-trello: TRELLO_KEY/TRELLO_TOKEN not fully set in .local/.agents" >&2
				set +e ; return 1
			fi
			curl -s "https://api.trello.com/1/members/me/notifications?read_filter=unread&key=${trelloKey}&token=${trelloToken}"
			return $?
		;;

		## Added 2026-07-21, per direct human-owner instruction: --check-*/
		## --sweep-read-incoming-comms are deliberately lightweight scanning
		## tools (short/pretty descriptions) -- they will legitimately
		## truncate/summarize. --read-* is the different, complementary
		## concern: given one specific message/thread's own id/address,
		## retrieve its FULL content (all meta-info, reactions, formatting,
		## images/attachments) for actually processing that one item in
		## detail, not scanning for what's new. Always returns the full raw
		## API response (never pretty-formatted) -- "full" is the entire
		## point of this op, there is no lossy default here.
		--read-slack)
			shift
			local target="$1"
			shift || true
			if [ -z "$target" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --read-slack: target required (magic-team|human-owner|<channel>:<ts>)" >&2
				set +e ; return 1
			fi

			local wantThread="false"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--thread)
						wantThread="true" ; shift
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --read-slack: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done

			local resolved channel threadTs
			resolved="$( DistroAgentsToolsResolveTarget "$target" )"
			case "$?" in
				0)
					channel="$( printf '%s\n' "$resolved" | sed -n 's/^CHANNEL=//p' )"
					threadTs="$( printf '%s\n' "$resolved" | sed -n 's/^THREAD_TS=//p' )"
				;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --read-slack: could not resolve target '$target' -- pass <channel>:<ts> for a specific message" >&2
					set +e ; return 1
				;;
			esac
			if [ -z "$threadTs" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --read-slack: a specific <ts> is required (magic-team/human-owner alone identify a channel, not one message) -- use <channel>:<ts>" >&2
				set +e ; return 1
			fi

			local token
			token="$( DistroAgentsTools --agent-config-option --select SLACK_BOT_TOKEN )"
			if [ -z "$token" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --read-slack: SLACK_BOT_TOKEN not set in .local/.agents" >&2
				set +e ; return 1
			fi

			local headerFile
			headerFile="$( mktemp )" || { set +e ; return 1 ; }
			chmod 600 "$headerFile"
			trap 'rm -f "$headerFile"' EXIT
			printf 'Authorization: Bearer %s\n' "$token" > "$headerFile"

			if [ "$wantThread" = "true" ] ; then
				## Full thread -- every reply, full detail (reactions/files/
				## blocks all come through untouched since this is raw, not
				## piped through the pretty formatter).
				echo "# $MDSC_CMD --read-slack: GET conversations.replies channel=$channel ts=$threadTs (full thread)" >&2
				curl -sS -G "https://slack.com/api/conversations.replies" -H "@$headerFile" \
					--data-urlencode "channel=$channel" --data-urlencode "ts=$threadTs"
			else
				## Exactly one message -- latest=oldest=ts with inclusive+limit=1
				## pins conversations.history to that single message, not a
				## history window.
				echo "# $MDSC_CMD --read-slack: GET conversations.history channel=$channel ts=$threadTs (single message)" >&2
				curl -sS -G "https://slack.com/api/conversations.history" -H "@$headerFile" \
					--data-urlencode "channel=$channel" --data-urlencode "latest=$threadTs" \
					--data-urlencode "oldest=$threadTs" --data-urlencode "inclusive=true" \
					--data-urlencode "limit=1"
			fi
			echo

			rm -f "$headerFile"
			trap - EXIT
			return 0
		;;

		## Full IMAP fetch (complete RFC822 message: headers + body + MIME
		## multipart, attachments included as their raw MIME parts) for one
		## specific message by UID -- contrast with --check-email's
		## STATUS-only unread count. Uses curl's URL-based
		## ;UID=<uid> addressing (no ;SECTION= means the whole message, per
		## curl's own IMAP URL support) -- the same working mechanism found
		## live this session after --request "UID FETCH..." turned out not
		## to return literal-string FETCH bodies through stdout at all.
		--read-email)
			shift
			local uid="$1"
			shift || true
			if [ -z "$uid" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --read-email: UID required" >&2
				set +e ; return 1
			fi

			local imapHost imapUser imapPass
			imapHost="$( DistroAgentsTools --agent-config-option --select EMAIL_IMAP_HOST )"
			imapUser="$( DistroAgentsTools --agent-config-option --select EMAIL_USER )"
			imapPass="$( DistroAgentsTools --agent-config-option --select EMAIL_APP_PASSWORD )"
			if [ -z "$imapHost" ] || [ -z "$imapUser" ] || [ -z "$imapPass" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --read-email: EMAIL_IMAP_HOST/EMAIL_USER/EMAIL_APP_PASSWORD not fully set in .local/.agents" >&2
				set +e ; return 1
			fi

			echo "# $MDSC_CMD --read-email: fetching full message UID=$uid" >&2
			curl -sS --url "imaps://${imapHost}/INBOX;UID=${uid}" --user "${imapUser}:${imapPass}"
			return $?
		;;

		## Full detail for one specific Trello notification by id -- the
		## comms-sweep's own unit of "a message" for Trello (per
		## --check-trello's own read_filter=unread notifications list).
		## Contrast with --check-trello's unread-list-only scan.
		--read-trello)
			shift
			local notificationId="$1"
			shift || true
			if [ -z "$notificationId" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --read-trello: notification id required" >&2
				set +e ; return 1
			fi

			local trelloKey trelloToken
			trelloKey="$( DistroAgentsTools --agent-config-option --select TRELLO_KEY )"
			trelloToken="$( DistroAgentsTools --agent-config-option --select TRELLO_TOKEN )"
			if [ -z "$trelloKey" ] || [ -z "$trelloToken" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --read-trello: TRELLO_KEY/TRELLO_TOKEN not fully set in .local/.agents" >&2
				set +e ; return 1
			fi

			echo "# $MDSC_CMD --read-trello: fetching full notification id=$notificationId" >&2
			curl -sS "https://api.trello.com/1/notifications/${notificationId}?fields=all&member=true&memberCreator=true&card=true&card_fields=all&board=true&board_fields=all&key=${trelloKey}&token=${trelloToken}"
			return $?
		;;

		## Reads Slack activity for ONE specific target -- a required
		## <magic-team|human-owner|<channel>:<ts>>, no "check everything"
		## mode (that's --sweep-read-incoming-comms's job specifically, see
		## its own comment below; conflating the two is a real design bug
		## found and fixed 2026-07-21). Deliberately does NOT parse the
		## Slack JSON response internally -- see the --pretty/--raw handling
		## near the bottom of this branch. Target grammar mirrors
		## --send-message's (magic-team|human-owner|<channel>:<ts>) so a
		## bare channel name means "history" and a <channel>:<ts> pair means
		## "replies in that thread" -- no new addressing scheme invented.
		--check-slack)
			shift
			local target="$1"
			shift || true

			if [ -z "$target" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --check-slack: target required (magic-team|human-owner|<channel>:<ts>)" >&2
				set +e ; return 1
			fi

			## Pretty (formatted "ts | user | text" lines) is the default, not
			## an opt-in -- per direct human-owner correction: "at least pretty
			## by default, I don't imagine you calling non-pretty." --raw is
			## the escape hatch for the rare case the full raw JSON is
			## actually needed (e.g. inspecting reply_count/thread metadata
			## fields the pretty formatter doesn't surface).
			local oldest pretty="true"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--oldest)
						oldest="$2" ; shift 2
					;;
					--raw)
						pretty="false" ; shift
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --check-slack: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done

			local resolved channel threadTs
			resolved="$( DistroAgentsToolsResolveTarget "$target" )"
			case "$?" in
				0)
					channel="$( printf '%s\n' "$resolved" | sed -n 's/^CHANNEL=//p' )"
					threadTs="$( printf '%s\n' "$resolved" | sed -n 's/^THREAD_TS=//p' )"
				;;
				2)
					echo "⛔ ERROR: $MDSC_CMD --check-slack: unrecognized target: $target" >&2
					set +e ; return 1
				;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --check-slack: could not resolve a channel for target '$target' -- check SLACK_CHANNEL_MAGIC_TEAM/SLACK_CHANNEL_HUMAN_OWNER in .local/.agents" >&2
					set +e ; return 1
				;;
			esac

			echo "## target=$target channel=$channel"

			local endpoint
			if [ -n "$threadTs" ] ; then
				endpoint="https://slack.com/api/conversations.replies"
			else
				endpoint="https://slack.com/api/conversations.history"
			fi

			echo "# $MDSC_CMD --check-slack: GET $endpoint channel=$channel${threadTs:+ ts=$threadTs}${oldest:+ oldest=$oldest}" >&2

			local token
			token="$( DistroAgentsTools --agent-config-option --select SLACK_BOT_TOKEN )"
			if [ -z "$token" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --check-slack: SLACK_BOT_TOKEN not set in .local/.agents (see --agent-config-option --upsert)" >&2
				set +e ; return 1
			fi

			## Same private-header-file mechanism as --send-message -- token never
			## touches argv/ps, header file is chmod 600 and trap-cleaned on exit.
			local headerFile
			headerFile="$( mktemp )" || { set +e ; return 1 ; }
			chmod 600 "$headerFile"
			trap 'rm -f "$headerFile"' EXIT
			printf 'Authorization: Bearer %s\n' "$token" > "$headerFile"

			local curlArgs=( -sS -G "$endpoint" -H "@$headerFile" --data-urlencode "channel=$channel" )
			[ -z "$threadTs" ] || curlArgs+=( --data-urlencode "ts=$threadTs" )
			[ -z "$oldest" ] || curlArgs+=( --data-urlencode "oldest=$oldest" )

			## No retry logic here, by design -- human-owner correction,
			## 2026-07-21: "check slack DO NOT NEED RETRY LOGIC - if they
			## fail - they fail - all. --check" (applies to the whole
			## --check-* family, not just this op). A brief retry-loop
			## version existed for a few minutes the same day and was
			## reverted; don't reintroduce it here.
			##
			## --pretty pipes the response through this repo's own
			## sh-lib/AgentSlackMessagesFormat.awk (reuses myx.common's
			## agentMcpJsonParseRequest.awk parsing engine verbatim, just a
			## different leaf-emission target -- lives here, not in
			## myx.common, since it's 100% specific to this tool's own
			## Slack-reading need) to print clean "ts | user | text" lines
			## directly -- this is the actual fix for the "why does every
			## caller keep hand-rolling a python3 -c 'import json...'
			## one-liner just to read a Slack reply" pattern, not another
			## one-off workaround.
			if [ "$pretty" = "true" ] ; then
				curl "${curlArgs[@]}" | LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/AgentSlackMessagesFormat.awk"
			else
				curl "${curlArgs[@]}"
				echo
			fi

			rm -f "$headerFile"
			trap - EXIT
			return 0
		;;

		## Added 2026-07-22: closes a real gap found live -- until now this
		## tool had no `reactions.add` wrapper at all, so the per-message
		## Slack-reaction-tracking design (`routine-communication-sweep`,
		## `routine-board-actualisation`'s pending-reaction lookup) had no
		## sanctioned way to actually post a reaction. Same target grammar as
		## --read-slack/--check-slack (<channel>:<ts>, via
		## DistroAgentsToolsResolveTarget) plus a required emoji name (no
		## colons, matches Slack's own reactions.add `name` field exactly).
		--react-slack)
			shift
			local target="$1"
			shift || true
			local emoji="$1"
			shift || true

			if [ -z "$target" ] || [ -z "$emoji" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --react-slack: syntax is <channel>:<ts> <emoji-name>" >&2
				set +e ; return 1
			fi

			local resolved channel threadTs
			resolved="$( DistroAgentsToolsResolveTarget "$target" )"
			case "$?" in
				0)
					channel="$( printf '%s\n' "$resolved" | sed -n 's/^CHANNEL=//p' )"
					threadTs="$( printf '%s\n' "$resolved" | sed -n 's/^THREAD_TS=//p' )"
				;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --react-slack: could not resolve target '$target' -- pass <channel>:<ts>" >&2
					set +e ; return 1
				;;
			esac
			if [ -z "$threadTs" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --react-slack: a specific <ts> is required -- use <channel>:<ts>" >&2
				set +e ; return 1
			fi

			local token
			token="$( DistroAgentsTools --agent-config-option --select SLACK_BOT_TOKEN )"
			if [ -z "$token" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --react-slack: SLACK_BOT_TOKEN not set in .local/.agents" >&2
				set +e ; return 1
			fi

			local headerFile
			headerFile="$( mktemp )" || { set +e ; return 1 ; }
			chmod 600 "$headerFile"
			trap 'rm -f "$headerFile"' EXIT
			printf 'Authorization: Bearer %s\n' "$token" > "$headerFile"

			echo "# $MDSC_CMD --react-slack: POST reactions.add channel=$channel timestamp=$threadTs name=$emoji" >&2
			local response
			response="$( curl -sS -X POST "https://slack.com/api/reactions.add" -H @"$headerFile" \
				--data-urlencode "channel=$channel" --data-urlencode "timestamp=$threadTs" \
				--data-urlencode "name=$emoji" )"

			rm -f "$headerFile"
			trap - EXIT

			printf '%s\n' "$response"
			if printf '%s' "$response" | grep -q '"ok":true' ; then
				return 0
			fi
			## already_reacted is a harmless no-op per Slack's own API and per
			## this feature's own design doc, not a real failure to retry.
			if printf '%s' "$response" | grep -q '"error":"already_reacted"' ; then
				echo "# $MDSC_CMD --react-slack: already reacted (no-op, not an error)" >&2
				return 0
			fi
			echo "⛔ $MDSC_CMD --react-slack: FAILED -- $response" >&2
			set +e ; return 1
		;;

		## NOT a general-purpose "check any Slack target" op -- that's
		## --check-slack, above (real design bug fixed 2026-07-21: this used
		## to accept an arbitrary <target> argument too, conflating "the
		## comms-sweep routine's own fixed macro-op" with "read one specific
		## thread," which they are not). This op takes no target at all --
		## it always reads the exact same predefined, pre-configured set of
		## watched sources (both Slack targets, email, Trello) in one
		## optimized combined pass, producing one specific mixed output
		## meant as the initial text source for comms processing. It exists
		## for exactly one caller: magic-coordinator's communication-sweep
		## Check step. If you need to read one specific arbitrary Slack
		## target/thread, call --check-slack directly instead.
		--sweep-read-incoming-comms)
			shift

			local oldest pretty="true"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--oldest)
						oldest="$2" ; shift 2
					;;
					--raw)
						pretty="false" ; shift
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --sweep-read-incoming-comms: invalid option: $1 (this op takes no target -- did you mean --check-slack?)" >&2
						set +e ; return 1
					;;
				esac
			done

			local recurseArgs=()
			[ -z "$oldest" ] || recurseArgs+=( --oldest "$oldest" )
			[ "$pretty" = "false" ] && recurseArgs+=( --raw )

			local name anyChecked=0 resolved channel
			for name in magic-team human-owner ; do
				resolved="$( DistroAgentsToolsResolveTarget "$name" )" || {
					echo "# $MDSC_CMD --sweep-read-incoming-comms: skipping '$name' -- no channel id configured" >&2
					continue
				}
				anyChecked=1
				channel="$( printf '%s\n' "$resolved" | sed -n 's/^CHANNEL=//p' )"
				echo "## target=$name channel=$channel"
				## Trailing colon forces the *:* (channel:ts) grammar branch
				## with an empty thread ts -- a bare channel id alone isn't
				## valid target grammar (matches neither a known name nor
				## channel:ts).
				DistroAgentsTools --check-slack "$channel:" "${recurseArgs[@]}"
			done

			echo "## target=email"
			if ! DistroAgentsTools --check-email ; then
				echo "# $MDSC_CMD --sweep-read-incoming-comms: --check-email failed, see error above" >&2
			else
				anyChecked=1
			fi

			echo "## target=trello"
			if ! DistroAgentsTools --check-trello ; then
				echo "# $MDSC_CMD --sweep-read-incoming-comms: --check-trello failed, see error above" >&2
			else
				anyChecked=1
			fi

			if [ "$anyChecked" = "0" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --sweep-read-incoming-comms: no watched targets configured at all (Slack/email/Trello)" >&2
				set +e ; return 1
			fi
			return 0
		;;

		## Walks .local/.agents/* and flags anything not chmod 700 (dirs) /
		## 600 (files) -- standing defensive layer against the exact class of
		## bug found during today's secrets-migration session (file landed
		## 644 after a real --upsert, because the old code chmod'd the
		## touched file instead of the temp file that actually replaces it
		## via mv). That root cause is already fixed in
		## LocalTools.Config.include's --upsert; this is the regression
		## guard, not a re-fix.
		--verify-permissions)
			shift
			local dir="$MMDAPP/.local/.agents"
			if [ ! -d "$dir" ] ; then
				echo "# $MDSC_CMD --verify-permissions: $dir does not exist yet (nothing to verify)" >&2
				return 0
			fi

			local failed=0
			local perm
			perm="$( DistroAgentsToolsPermOf "$dir" )"
			if [ "$perm" = "700" ] ; then
				echo "OK   700  $dir"
			else
				echo "BAD  ${perm:-?}  $dir  (expected 700)"
				failed=1
			fi

			local f
			for f in "$dir"/* ; do
				[ -e "$f" ] || continue
				perm="$( DistroAgentsToolsPermOf "$f" )"
				if [ "$perm" = "600" ] ; then
					echo "OK   600  $f"
				else
					echo "BAD  ${perm:-?}  $f  (expected 600)"
					failed=1
				fi
			done

			if [ "$failed" = "1" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --verify-permissions: one or more paths under $dir are not hardened to 600/700" >&2
				set +e ; return 1
			fi
			echo "# $MDSC_CMD --verify-permissions: all paths under $dir are correctly hardened (700 dir / 600 files)" >&2
			return 0
		;;

		## Exercises the --agent-config-option permission-hardening chain
		## under a DELIBERATELY permissive `umask 022`, not whatever the
		## caller's ambient umask happens to be. Real motivating bug (an
		## earlier session): the chmod-600 regression escaped hand testing
		## because that testing happened to run under a restrictive umask by
		## coincidence, and only showed up against the real secrets migration
		## under a different umask. Uses a disposable probe key (never
		## touches any real credential key) so it's safe to run against the
		## live settings file, and cleans the probe up unconditionally. Calls
		## --verify-permissions via self-recursion, not a private helper.
		--self-test)
			shift
			echo "# $MDSC_CMD --self-test: exercising --agent-config-option permission-hardening under umask 022 (ignoring caller's ambient umask)" >&2

			local probeKey="DAT_SELFTEST_PROBE"
			local probeVal="selftest-$$-$( date +%s )"
			local failed=0

			if ! ( umask 022 ; DistroAgentsTools --agent-config-option --upsert "$probeKey" "$probeVal" >/dev/null ) ; then
				echo "⛔ ERROR: $MDSC_CMD --self-test: --upsert under umask 022 failed" >&2
				set +e ; return 1
			fi

			DistroAgentsTools --verify-permissions || failed=1

			local readBack
			readBack="$( DistroAgentsTools --agent-config-option --select "$probeKey" )"
			if [ "$readBack" != "$probeVal" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --self-test: probe key round-trip mismatch" >&2
				failed=1
			fi

			## Always clean up the probe, pass or fail -- never leave test residue
			## in the real credentials file.
			DistroAgentsTools --agent-config-option --delete "$probeKey" >/dev/null

			if [ "$failed" = "1" ] ; then
				echo "⛔ $MDSC_CMD --self-test: FAILED" >&2
				set +e ; return 1
			fi
			echo "# $MDSC_CMD --self-test: PASSED -- permission hardening holds under umask 022" >&2
			return 0
		;;

		--purge-cleanup)
			shift
			## No path argument by design (human-owner correction, 2026-07-21:
			## "should NOT have a path argument. It cleans predefined
			## .local/.cleanup folder"). Always operates on exactly
			## $MMDAPP/.local/.cleanup -- a fixed, code-determined path, never
			## caller input, which is what makes this safe to route around the
			## `Bash(rm *)` deny in the first place (see CLAUDE.md's
			## DistroAgentsTools gotchas section for why that deny can't be
			## carved into "except .cleanup/*" at the settings.json layer).
			if [ $# -gt 0 ] ; then
				echo "⛔ ERROR: $MDSC_CMD --purge-cleanup: takes no arguments -- always purges $MMDAPP/.local/.cleanup" >&2
				set +e ; return 1
			fi
			local cleanupDir="$MMDAPP/.local/.cleanup"
			if [ ! -d "$cleanupDir" ] ; then
				echo "# $MDSC_CMD --purge-cleanup: $cleanupDir does not exist -- nothing to purge" >&2
				return 0
			fi
			echo "# $MDSC_CMD --purge-cleanup: purging all contents of $cleanupDir (folder itself stays)" >&2
			local entry
			for entry in "$cleanupDir"/* "$cleanupDir"/.[!.]* ; do
				[ -e "$entry" ] || [ -L "$entry" ] || continue
				echo "  rm -rf $entry" >&2
				rm -rf -- "$entry"
			done
			echo "# $MDSC_CMD --purge-cleanup: done" >&2
			return 0
		;;

		--validate-json)
			## Added 2026-07-22, human-owner-requested directly during a live
			## routine-coworking session, after a `chat.postMessage --data @file`
			## call failed with Slack's `invalid_json` and the JSON wasn't checked
			## first. Validates a JSON file (path arg) or stdin (no arg) is
			## syntactically valid, before it's ever handed to curl/an API call.
			## Uses python3 (present on every supported OS here) rather than jq,
			## matching this tool family's existing jq-avoidance convention.
			shift
			local jsonPath="$1"
			if [ -n "$jsonPath" ] ; then
				if [ ! -f "$jsonPath" ] ; then
					echo "⛔ ERROR: $MDSC_CMD --validate-json: file not found: $jsonPath" >&2
					set +e ; return 1
				fi
				if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$jsonPath" >/dev/null 2>&1 ; then
					echo "# $MDSC_CMD --validate-json: valid JSON: $jsonPath" >&2
					return 0
				else
					echo "⛔ ERROR: $MDSC_CMD --validate-json: invalid JSON: $jsonPath" >&2
					set +e ; return 1
				fi
			else
				if python3 -c "import json,sys; json.load(sys.stdin)" >/dev/null 2>&1 ; then
					echo "# $MDSC_CMD --validate-json: valid JSON (stdin)" >&2
					return 0
				else
					echo "⛔ ERROR: $MDSC_CMD --validate-json: invalid JSON (stdin)" >&2
					set +e ; return 1
				fi
			fi
		;;

		--list-md)
			## Added 2026-07-22, human-owner-requested directly (folded into a
			## routine-coworking session touching unrelated reaction-design
			## work). Replaces the hand-rolled `for f in ...; do wc -l "$f";
			## done`-style Bash loop agents kept reaching for before editing a
			## batch of markdown/doc files -- each such loop is a fresh,
			## non-matching command string that costs its own permission
			## prompt, same friction class as the --validate-json/--from-stdin
			## additions above. Read-only, no credentials, no network -- just
			## existence + line count for a caller-supplied list of paths (not
			## restricted to .md, despite the flag name -- any path works).
			shift
			if [ $# -eq 0 ] ; then
				echo "⛔ ERROR: $MDSC_CMD --list-md: at least one file path required" >&2
				set +e ; return 1
			fi
			local mdPath mdLines mdMissing
			mdMissing=0
			while [ $# -gt 0 ] ; do
				mdPath="$1"
				shift
				if [ -f "$mdPath" ] ; then
					mdLines="$( wc -l < "$mdPath" | tr -d '[:space:]' )"
					echo "$mdPath: $mdLines lines"
				else
					echo "$mdPath: MISSING"
					mdMissing=1
				fi
			done
			if [ "$mdMissing" -eq 1 ] ; then
				set +e ; return 1
			fi
			return 0
		;;

		## Added 2026-07-22 (routine-grooming pass, first live duplicate-check-and-merge
		## exercise): regenerates one routine's own routine-contract.SLIB.md without going
		## through this session's own Edit/Write tool call -- closes the human-owner's own
		## SLIB-approval-friction question ("Should be special tooling for SLIB updates be
		## added? --save-slib? - these are generated files - I don't want to approve each",
		## magic-coordinator/inbox/2026-07-22-note-save-slib-tooling-question.md) merged
		## with keeper-myx's own broader tool-agnostic-update-mechanism proposal (same
		## underlying ask -- keeper-myx/inbox/2026-07-22-proposal-tool-agnostic-skill-doc-
		## update-mechanism.md already named --write-slib as the concrete recommended op).
		##
		## Same fixed-target-per-identifier shape as --purge-cleanup: <routine-name> is
		## never a free-form path -- it's validated as a bare directory name (no '/', not
		## '.'/'..') and must already exist as a real skill directory under
		## $HOME/.claude/skills/, so this op can only ever touch that one directory's own
		## routine-contract.SLIB.md, never an arbitrary path. Content comes from stdin by
		## default, or from a plain file via --file <path> (added 2026-07-22, same
		## motivation/shape as --send-message/--send-email-message's own --file: lets a
		## caller write the regenerated content to a plain temp file first, an ordinary
		## Write tool call, and still invoke this op as one single-line command, since a
		## heredoc body spans multiple lines and stops matching a single-line
		## settings.json allowlist glob). Call with this tool's absolute path leading and
		## either a heredoc supplying stdin content (per magic-team/CONSOLE-SESSIONS.md's
		## "Heredoc for stdin" convention) or --file <path>.
		##
		## Caller-identity gap, stated plainly rather than silently ignored (per the
		## proposal's own finding): this tool has no privilege separation -- nothing stops
		## any caller from regenerating any routine's SLIB file. Convention-based trust
		## only, same model as every other op here (see magic-coordinator/SKILL.md's
		## DistroAgentsTools trust-policy entry). Intended caller is magic-librarian,
		## regenerating a routine's own merged contract file after a source SKILL.md/
		## ACCESS.md change -- not enforced, just documented.
		##
		## --write-board-item/--write-inbox-note (this proposal's other two illustrative
		## cases) built 2026-07-22, same routine-coworking batch that resolved the
		## board-exclusivity gap flagged above: --write-board-item is documented (its own
		## comment block below), not code-enforced, as magic-coordinator-only -- exposing
		## it as a general callable op does not create a bypass of BOARD.md's "write
		## authority is exclusive over the board," since nothing about calling this op
		## grants a caller any authority BOARD.md itself doesn't already recognize; it is
		## simply the sanctioned mechanism magic-coordinator itself now uses to write,
		## same convention-based-trust model as every other op here.
		--write-slib)
			shift
			local routineName="$1"
			shift || true
			if [ -z "$routineName" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --write-slib: routine name required (e.g. routine-grooming) -- content via stdin or --file <path>" >&2
				set +e ; return 1
			fi
			case "$routineName" in
				*/*|.|..)
					echo "⛔ ERROR: $MDSC_CMD --write-slib: routine name must be a bare directory name, not a path: $routineName" >&2
					set +e ; return 1
				;;
			esac
			local skillDir="$HOME/.claude/skills/$routineName"
			if [ ! -d "$skillDir" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --write-slib: no such skill directory: $skillDir" >&2
				set +e ; return 1
			fi
			local target="$skillDir/routine-contract.SLIB.md"
			local content contentFromFile="false"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--file)
						## Added 2026-07-22 -- same shape as --send-email-message's own
						## --file (an explicit contentFromFile flag gates the later
						## stdin-read, rather than inferring source from whether
						## $content is non-empty, which would wrongly fall through to
						## reading stdin if the given file happened to be empty).
						if [ -z "$2" ] || [ ! -f "$2" ] ; then
							echo "⛔ ERROR: $MDSC_CMD --write-slib: --file: file not found: $2" >&2
							set +e ; return 1
						fi
						content="$( cat "$2" )"
						contentFromFile="true"
						shift 2
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --write-slib: unrecognized argument: $1" >&2
						set +e ; return 1
					;;
				esac
			done
			[ "$contentFromFile" = "true" ] || content="$( cat )"
			if [ -z "$content" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --write-slib: empty content -- refusing to write an empty routine-contract.SLIB.md" >&2
				set +e ; return 1
			fi
			printf '%s\n' "$content" > "$target"
			echo "# $MDSC_CMD --write-slib: wrote $target ($( printf '%s\n' "$content" | wc -l | tr -d '[:space:]' ) lines)" >&2
			return 0
		;;

		## Added 2026-07-22, same batch that resolved this op's own board-exclusivity
		## gap (see the comment above --write-slib). **magic-coordinator-only by
		## design** -- BOARD.md states plainly "magic-coordinator's write authority is
		## exclusive over the board -- full stop... creating an Item, moving one
		## between these states, or scoring it -- is magic-coordinator-only." This op
		## is the sanctioned mechanism magic-coordinator itself uses to do that
		## writing/moving without going through a separate Edit/Write tool call --
		## it is NOT a general-purpose board-writing op for any member to call. Same
		## convention-based-trust model as every other op here (no caller-identity
		## enforcement exists in this tool at all, see --write-slib's own comment) --
		## this is documented, not code-enforced, exactly like every other trust
		## boundary in this file.
		##
		## Same fixed-target-per-identifier shape as --write-slib/--purge-cleanup:
		## <state> must be one of the board's own real state-folder names (never a
		## free-form path), <item-filename> must be a bare filename (no '/', not
		## '.'/'..'). Content via stdin only (a board Item is a multi-paragraph
		## markdown document, same reasoning as --write-slib). Writing to an
		## already-existing <state>/<item-filename> overwrites it in place (an
		## update to an existing Item's content) -- moving an Item between states is
		## two calls (write into the new state, then a separate cleanup of the old
		## file), not a single move op, since this tool has no existing "move/rename"
		## primitive anywhere else to mirror.
		--write-board-item)
			shift
			local boardState="$1"
			shift || true
			local itemName="$1"
			shift || true
			if [ -z "$boardState" ] || [ -z "$itemName" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --write-board-item: syntax is <state> <item-filename> -- content via stdin (magic-coordinator-only op)" >&2
				set +e ; return 1
			fi
			case "$boardState" in
				planned|approved|running|testing|blocked|parked|processed|archived|cleanup)
				;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --write-board-item: unrecognized board state: $boardState (must be one of planned/approved/running/testing/blocked/parked/processed/archived/cleanup)" >&2
					set +e ; return 1
				;;
			esac
			case "$itemName" in
				*/*|.|..)
					echo "⛔ ERROR: $MDSC_CMD --write-board-item: item filename must be a bare filename, not a path: $itemName" >&2
					set +e ; return 1
				;;
			esac
			local boardDir="$HOME/.claude/skills/magic-team/board/$boardState"
			if [ ! -d "$boardDir" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --write-board-item: no such board state directory: $boardDir" >&2
				set +e ; return 1
			fi
			local target="$boardDir/$itemName"
			local content ; content="$( cat )"
			if [ -z "$content" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --write-board-item: empty stdin -- refusing to write an empty board item" >&2
				set +e ; return 1
			fi
			printf '%s\n' "$content" > "$target"
			echo "# $MDSC_CMD --write-board-item: wrote $target ($( printf '%s\n' "$content" | wc -l | tr -d '[:space:]' ) lines)" >&2
			return 0
		;;

		## Added 2026-07-22, same batch as --write-board-item above. Any member's own
		## personal inbox (~/.claude/skills/<member>/inbox/, see routine-process-inbox)
		## -- unlike the board, inbox write access is NOT exclusive to one member; any
		## member may post a note into any other member's inbox (that's the whole
		## cross-member handoff mechanism). This op is simply the tool-mediated way to
		## do that write. <member> must already exist as a real skill directory;
		## <item-filename> must be a bare filename. The inbox/ directory itself is
		## created lazily if it doesn't exist yet (matches the established
		## lazily-created-inbox convention, see BOARD.md/routine-process-inbox), not
		## treated as an error the way a missing board-state directory is (board
		## states are a fixed, known set; a member's inbox may simply not have been
		## created yet).
		--write-inbox-note)
			shift
			local memberName="$1"
			shift || true
			local itemName="$1"
			shift || true
			if [ -z "$memberName" ] || [ -z "$itemName" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --write-inbox-note: syntax is <member> <item-filename> -- content via stdin or --file <path>" >&2
				set +e ; return 1
			fi
			case "$memberName" in
				*/*|.|..)
					echo "⛔ ERROR: $MDSC_CMD --write-inbox-note: member name must be a bare directory name, not a path: $memberName" >&2
					set +e ; return 1
				;;
			esac
			case "$itemName" in
				*/*|.|..)
					echo "⛔ ERROR: $MDSC_CMD --write-inbox-note: item filename must be a bare filename, not a path: $itemName" >&2
					set +e ; return 1
				;;
			esac
			local memberDir="$HOME/.claude/skills/$memberName"
			if [ ! -d "$memberDir" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --write-inbox-note: no such member skill directory: $memberDir" >&2
				set +e ; return 1
			fi
			local inboxDir="$memberDir/inbox"
			mkdir -p "$inboxDir" || {
				echo "⛔ ERROR: $MDSC_CMD --write-inbox-note: can't create inbox directory: $inboxDir" >&2
				set +e ; return 1
			}
			local target="$inboxDir/$itemName"
			local content contentFromFile="false"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--file)
						## Added 2026-07-22 -- same --file shape as --write-slib/
						## --send-message/--send-email-message: lets a caller write the
						## note content to a plain temp file first (an ordinary Write
						## tool call) and still invoke this op as one single-line
						## command. Explicit contentFromFile flag gates the stdin-read
						## below, same reasoning as --write-slib's own --file (don't
						## infer source from non-emptiness of $content).
						if [ -z "$2" ] || [ ! -f "$2" ] ; then
							echo "⛔ ERROR: $MDSC_CMD --write-inbox-note: --file: file not found: $2" >&2
							set +e ; return 1
						fi
						content="$( cat "$2" )"
						contentFromFile="true"
						shift 2
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --write-inbox-note: unrecognized argument: $1" >&2
						set +e ; return 1
					;;
				esac
			done
			[ "$contentFromFile" = "true" ] || content="$( cat )"
			if [ -z "$content" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --write-inbox-note: empty content -- refusing to write an empty inbox note" >&2
				set +e ; return 1
			fi
			printf '%s\n' "$content" > "$target"
			echo "# $MDSC_CMD --write-inbox-note: wrote $target ($( printf '%s\n' "$content" | wc -l | tr -d '[:space:]' ) lines)" >&2
			return 0
		;;

		## Added 2026-07-22 -- closes a real gap: --check-email/--read-email can scan
		## and fetch, but nothing marks a message read after it's actually been
		## processed, so every comms-sweep pass kept re-seeing the same UIDs as
		## unseen. IMAP UID STORE with the \Seen flag, same curl --request pattern
		## --check-email already uses for STATUS/SEARCH (not the URL-based ;UID=
		## addressing --read-email uses, since this is a STORE command, not a
		## fetch).
		--mark-email-seen)
			shift
			local uid="$1"
			shift || true
			if [ -z "$uid" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --mark-email-seen: UID required" >&2
				set +e ; return 1
			fi

			local imapHost imapUser imapPass
			imapHost="$( DistroAgentsTools --agent-config-option --select EMAIL_IMAP_HOST )"
			imapUser="$( DistroAgentsTools --agent-config-option --select EMAIL_USER )"
			imapPass="$( DistroAgentsTools --agent-config-option --select EMAIL_APP_PASSWORD )"
			if [ -z "$imapHost" ] || [ -z "$imapUser" ] || [ -z "$imapPass" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --mark-email-seen: EMAIL_IMAP_HOST/EMAIL_USER/EMAIL_APP_PASSWORD not fully set in .local/.agents" >&2
				set +e ; return 1
			fi

			echo "# $MDSC_CMD --mark-email-seen: marking UID=$uid as \\Seen" >&2
			curl -sS --url "imaps://${imapHost}/INBOX" --user "${imapUser}:${imapPass}" \
				--request "UID STORE ${uid} +FLAGS (\Seen)"
			return $?
		;;

		--help|--help-syntax|'')
			. "$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/help/Help.DistroAgentsTools.include"
			return 0
		;;

		*)
			echo "⛔ ERROR: $MDSC_CMD: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/sh-scripts/DistroAgentsTools.fn.sh)

		if [ -z "$1" ] || [ "$1" = "--help" ] || [ "$1" = "--help-syntax" ] ; then
			DistroAgentsTools "${1:-"--help"}"
			exit 1
		fi

		set -e
		DistroAgentsTools "$@"
	;;
esac
