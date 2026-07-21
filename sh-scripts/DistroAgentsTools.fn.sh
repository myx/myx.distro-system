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
	local channel="" threadTs=""
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

DistroAgentsToolsHelp(){
	cat >&2 <<'HELPEOF'
📘 syntax: DistroAgentsTools.fn.sh --start-console [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]
📘 syntax: DistroAgentsTools.fn.sh --send-console <channel> [-- <command...>]   (reads stdin if no command given)
📘 syntax: DistroAgentsTools.fn.sh --stop-console <channel>
📘 syntax: DistroAgentsTools.fn.sh --list-consoles [--override-workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --agent-config-option <operation>
📘 syntax: DistroAgentsTools.fn.sh --send-message <magic-team|human-owner|<channel>:<ts>> [text...]
📘 syntax: DistroAgentsTools.fn.sh --send-message <target> --message-from-stdin [--format text|blocks]
📘 syntax: DistroAgentsTools.fn.sh --send-email-message <email@address>... -- <subject> -- <body...>
📘 syntax: DistroAgentsTools.fn.sh --sweep-read-incoming-comms [<target>] [--oldest <ts>]
📘 syntax: DistroAgentsTools.fn.sh --self-test
📘 syntax: DistroAgentsTools.fn.sh --verify-permissions
📘 syntax: DistroAgentsTools.fn.sh [--help]

Channel dirs/log paths are deterministic (workspace + console, hashed) not
random — safe to allowlist once, stays valid across restarts. Default
workspace is the tool's own; --override-workspace targets a different one.
--start-console is idempotent: an already-alive channel for the same
(workspace, console) is reused rather than duplicated.

--send-message retries a Slack post on transient network failures (up to 5x
with backoff) before falling back to --send-email-message automatically.
--send-email-message is also directly callable on its own.
HELPEOF
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

			local workspaceArg="" consoleOverride="" ttl="$MDAT_DEFAULT_TTL"
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
				local oldConsolePid="" oldHolderPid=""
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
			local pid=""
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
			local workspaceArg=""
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
			local textArgs=""
			while [ $# -gt 0 ] ; do
				case "$1" in
					--message-from-stdin)
						fromStdin="true" ; shift
					;;
					--format)
						format="$2" ; shift 2
					;;
					*)
						textArgs="$textArgs $1" ; shift
					;;
				esac
			done

			local rawText="" blocksJson=""
			if [ "$fromStdin" = "true" ] ; then
				local stdinContent ; stdinContent="$( cat )"
				if [ "$format" = "blocks" ] ; then
					blocksJson="$stdinContent"
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

			local response="" attempt=1 maxAttempts=5 backoff=2 sent="false"
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
			local recipients="" subject="" bodyLines="" state="recipients"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--)
						if [ "$state" = "recipients" ] ; then state="subject"
						elif [ "$state" = "subject" ] ; then state="body"
						fi
						shift
					;;
					*)
						case "$state" in
							recipients) recipients="$recipients $1" ;;
							subject) subject="$subject $1" ;;
							body) bodyLines="$bodyLines
$1" ;;
						esac
						shift
					;;
				esac
			done
			recipients="${recipients# }"
			subject="${subject# }"

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

		## Reads recent Slack activity for the routine comms-sweep's Check
		## step (magic-coordinator's routines/communication-sweep.md).
		## Deliberately does NOT parse the Slack JSON response -- same
		## rationale as --send-message's blocks-fallback note: this shell
		## layer has no real JSON parser, so the raw API body is passed
		## straight to stdout for the calling routine (an LLM) to read
		## directly. Target grammar mirrors --send-message's
		## (magic-team|human-owner|<channel>:<ts>) so a bare channel name
		## means "history" and a <channel>:<ts> pair means "replies in that
		## thread" -- no new addressing scheme invented. With no target at
		## all, sweeps every known watched target by calling itself once per
		## target (same self-recursion pattern as --self-test below and
		## DistroLocalTools.fn.sh's --upgrade-installed-tools), so the
		## comms-sweep routine's Check step doesn't need to know channel ids.
		--sweep-read-incoming-comms)
			shift
			local target="$1"
			shift || true

			local oldest=""
			while [ $# -gt 0 ] ; do
				case "$1" in
					--oldest)
						oldest="$2" ; shift 2
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --sweep-read-incoming-comms: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done

			local channel="" threadTs=""
			if [ -z "$target" ] ; then
				local name anyChecked=0
				for name in magic-team human-owner ; do
					local resolved
					resolved="$( DistroAgentsToolsResolveTarget "$name" )" || {
						echo "# $MDSC_CMD --sweep-read-incoming-comms: skipping '$name' -- no channel id configured" >&2
						continue
					}
					anyChecked=1
					channel="$( printf '%s\n' "$resolved" | sed -n 's/^CHANNEL=//p' )"
					echo "## target=$name channel=$channel"
					DistroAgentsTools --sweep-read-incoming-comms "$channel" ${oldest:+--oldest "$oldest"}
				done
				if [ "$anyChecked" = "0" ] ; then
					echo "⛔ ERROR: $MDSC_CMD --sweep-read-incoming-comms: no watched targets configured (SLACK_CHANNEL_MAGIC_TEAM/SLACK_CHANNEL_HUMAN_OWNER both empty)" >&2
					set +e ; return 1
				fi
				return 0
			fi

			local resolved
			resolved="$( DistroAgentsToolsResolveTarget "$target" )"
			case "$?" in
				0)
					channel="$( printf '%s\n' "$resolved" | sed -n 's/^CHANNEL=//p' )"
					threadTs="$( printf '%s\n' "$resolved" | sed -n 's/^THREAD_TS=//p' )"
				;;
				2)
					echo "⛔ ERROR: $MDSC_CMD --sweep-read-incoming-comms: unrecognized target: $target" >&2
					set +e ; return 1
				;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --sweep-read-incoming-comms: could not resolve a channel for target '$target' -- check SLACK_CHANNEL_MAGIC_TEAM/SLACK_CHANNEL_HUMAN_OWNER in .local/.agents" >&2
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

			echo "# $MDSC_CMD --sweep-read-incoming-comms: GET $endpoint channel=$channel${threadTs:+ ts=$threadTs}${oldest:+ oldest=$oldest}" >&2

			local token
			token="$( DistroAgentsTools --agent-config-option --select SLACK_BOT_TOKEN )"
			if [ -z "$token" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --sweep-read-incoming-comms: SLACK_BOT_TOKEN not set in .local/.agents (see --agent-config-option --upsert)" >&2
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
			curl "${curlArgs[@]}"

			rm -f "$headerFile"
			trap - EXIT
			echo
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

		--help|--help-syntax|'')
			DistroAgentsToolsHelp
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
