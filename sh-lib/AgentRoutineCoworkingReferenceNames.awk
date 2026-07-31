#!/usr/bin/awk -f
##
## AgentRoutineCoworkingReferenceNames.awk -- reads an --intern-op-board-scan
## document (## <state>/<item> blocks restricted to `references:`/`blocks:`/
## `blocked-by:` headers) on stdin, and prints one bare item-name per line for
## every value found across all three fields, every block -- including
## bracketed-list values (`[a, b, c]`, the encoding
## AgentsTools.InternOpBoardUpsertMoveEdit.include's own --header:append
## produces) and plain scalar values alike. Duplicates are expected and
## normal (dedupe with `sort -u`, not this script's job); the caller unions
## this against the originally-given item-name set to build
## --routine-coworking-session-input-scan's phase-2 --item list. See
## AgentsTools.RoutineCoworking.include's own header.
##
/^references: |^blocks: |^blocked-by: / {
	val = $0 ;
	sub(/^[a-z-]+: /, "", val) ;
	gsub(/^\[/, "", val) ;
	gsub(/\]$/, "", val) ;
	n = split(val, parts, ",") ;
	for (i = 1 ; i <= n ; i++) {
		item = parts[i] ;
		gsub(/^[ \t]+|[ \t]+$/, "", item) ;
		if (item != "") { print item ; }
	}
}
