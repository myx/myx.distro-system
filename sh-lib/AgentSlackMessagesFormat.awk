#!/usr/bin/env awk

# Parses one single-line Slack conversations.history/conversations.replies
# JSON response (fed on stdin, run under LC_ALL=C for byte safety) and
# prints one clean "ts | user | text" line per message to stdout, instead
# of the caller needing to hand-roll a `python3 -c "import json..."`
# one-liner every single time -- that pattern kept recurring across main,
# main-loop, and every dispatched member tonight; this is the actual fix,
# not another one-off script.
#
# Lives here (myx.distro-system/sh-lib, not myx.common) because it's
# 100% Slack/DistroAgentsTools-specific with no general devops-CLI use --
# the only real consumer is DistroAgentsTools.fn.sh --sweep-read-incoming-comms
# in this same repo. Only the reusable parsing engine below was copied from
# myx.common (see the comment on it) -- the file itself belongs with its
# one caller, not in a general-purpose cross-platform tool that explicitly
# says not to carry over distro-* conventions into it.
#
# Parsing engine (skipws/hex2dec/utf8enc/parseString/parseValue/
# parseObject/parseArray) is copied verbatim from myx.common's
# agentMcpJsonParseRequest.awk (os-myx.common/host/tarball/share/myx.common/
# include/data/) -- same general-purpose recursive-descent JSON parser,
# only the leaf-emission logic differs (Slack message fields instead of
# MCP JSON-RPC fields). Not a general-purpose formatter: only understands
# the flat messages[] array shape Slack's own API actually returns.

BEGIN { msgCount = 0; }

function skipws(   c) {
	while (p <= n) {
		c = substr(s, p, 1)
		if (c == " " || c == "\t" || c == "\n" || c == "\r") p++
		else break
	}
}

function hex2dec(h,   i, c, v, r) {
	r = 0
	for (i = 1; i <= length(h); i++) {
		c = tolower(substr(h, i, 1))
		v = index("0123456789abcdef", c) - 1
		r = r * 16 + v
	}
	return r
}

function utf8enc(cp,   c1, c2, c3, c4) {
	if (cp < 128) {
		return sprintf("%c", cp)
	} else if (cp < 2048) {
		c1 = 192 + int(cp / 64)
		c2 = 128 + (cp % 64)
		return sprintf("%c%c", c1, c2)
	} else if (cp < 65536) {
		c1 = 224 + int(cp / 4096)
		c2 = 128 + int(cp / 64) % 64
		c3 = 128 + (cp % 64)
		return sprintf("%c%c%c", c1, c2, c3)
	} else {
		c1 = 240 + int(cp / 262144)
		c2 = 128 + int(cp / 4096) % 64
		c3 = 128 + int(cp / 64) % 64
		c4 = 128 + (cp % 64)
		return sprintf("%c%c%c%c", c1, c2, c3, c4)
	}
}

function parseString(   c, out, hex, code, hex2, code2, cp) {
	p++ # skip opening quote
	out = ""
	while (p <= n) {
		c = substr(s, p, 1)
		if (c == "\"") { p++; break; }
		if (c == "\\") {
			p++
			c = substr(s, p, 1)
			if (c == "\"") out = out "\""
			else if (c == "\\") out = out "\\"
			else if (c == "/") out = out "/"
			else if (c == "b") out = out "\b"
			else if (c == "f") out = out "\f"
			else if (c == "n") out = out "\n"
			else if (c == "r") out = out "\r"
			else if (c == "t") out = out "\t"
			else if (c == "u") {
				hex = substr(s, p + 1, 4)
				code = hex2dec(hex)
				p += 4
				if (code >= 55296 && code <= 56319 && substr(s, p + 1, 2) == "\\u") {
					hex2 = substr(s, p + 3, 4)
					code2 = hex2dec(hex2)
					if (code2 >= 56320 && code2 <= 57343) {
						cp = 65536 + (code - 55296) * 1024 + (code2 - 56320)
						out = out utf8enc(cp)
						p += 6
					} else {
						out = out utf8enc(code)
					}
				} else {
					out = out utf8enc(code)
				}
			}
			else out = out c
			p++
		} else {
			out = out c
			p++
		}
	}
	return out
}

## Slack-specific: track ts/user/bot_id/text per message index, print in
## END once every field for that index has been seen -- field order in
## Slack's real API responses isn't something to depend on.
function emitLeaf(path, raw, val,   idx, rest) {
	if (index(path, "messages.") != 1) return
	rest = substr(path, length("messages.") + 1)
	idx = rest
	sub(/\..*/, "", idx)
	if (idx !~ /^[0-9]+$/) return
	if (idx + 1 > msgCount) msgCount = idx + 1

	if (rest == idx ".ts") tsOf[idx] = val
	else if (rest == idx ".user") userOf[idx] = val
	else if (rest == idx ".bot_id" && !(idx in userOf)) userOf[idx] = val
	else if (rest == idx ".text") textOf[idx] = val
}

function parseValue(path,   c, startp, val, raw) {
	skipws()
	c = substr(s, p, 1)
	if (c == "\"") {
		startp = p
		val = parseString()
		raw = substr(s, startp, p - startp)
		emitLeaf(path, raw, val)
	} else if (c == "{") {
		parseObject(path)
	} else if (c == "[") {
		parseArray(path)
	} else if (c == "t") {
		p += 4
		emitLeaf(path, "true", "true")
	} else if (c == "f") {
		p += 5
		emitLeaf(path, "false", "false")
	} else if (c == "n") {
		p += 4
		emitLeaf(path, "null", "")
	} else {
		startp = p
		while (p <= n) {
			c = substr(s, p, 1)
			if (c == "-" || c == "+" || c == "." || c == "e" || c == "E" || (c >= "0" && c <= "9")) p++
			else break
		}
		raw = substr(s, startp, p - startp)
		emitLeaf(path, raw, raw)
	}
}

function parseObject(path,   key, keypath, c) {
	p++ # skip {
	skipws()
	if (substr(s, p, 1) == "}") { p++; return; }
	while (1) {
		skipws()
		key = parseString()
		skipws()
		p++ # skip :
		keypath = (path == "") ? key : path "." key
		parseValue(keypath)
		skipws()
		c = substr(s, p, 1)
		if (c == ",") { p++; continue; }
		else if (c == "}") { p++; break; }
		else break
	}
}

function parseArray(path,   idx, c) {
	p++ # skip [
	skipws()
	idx = 0
	if (substr(s, p, 1) == "]") { p++; return; }
	while (1) {
		parseValue(path "." idx)
		idx++
		skipws()
		c = substr(s, p, 1)
		if (c == ",") { p++; continue; }
		else if (c == "]") { p++; break; }
		else break
	}
}

{ s = $0; n = length(s); p = 1; parseValue(""); }

## Slack returns messages newest-first; print oldest-first (chronological,
## matching how every hand-rolled python reader tonight already reversed
## it) since that's what's actually useful to read.
END {
	for (i = msgCount - 1; i >= 0; i--) {
		printf "%s | %s | %s\n", tsOf[i], (i in userOf ? userOf[i] : "?"), textOf[i]
	}
}
