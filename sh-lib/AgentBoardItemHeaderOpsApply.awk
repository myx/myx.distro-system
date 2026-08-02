#!/usr/bin/awk -f
##
## AgentBoardItemHeaderOpsApply.awk -- applies a set of upsert/append/remove
## header operations to a board-item body's frontmatter, for
## DistroAgentsTools.fn.sh's --intern-op-board-upsert-move-edit op
## (myx.distro-system/sh-lib/AgentsTools.InternOpBoardUpsertMoveEdit.include),
## externalized per this package's own externalize-awk/py convention (see
## AgentBoardItemFrontmatterPrint.awk's own header comment for that name).
##
## Sole ARGV argument: the body file (frontmatter delimited by two literal
## `---` lines, same shape AgentBoardItemFrontmatterPrint.awk reads).
## `-v opsFile=<path>`: a tab-separated `opType<TAB>opName<TAB>opValue` file,
## one header operation per line, in application order -- opType is one of
## upsert/append/remove. Repeat upserts/removes on the same field: last
## wins. Repeat appends on the same field: cumulative, joined into one
## `[a, b, c]`-shaped list value, in order. A field with no operations
## targeting it, and every non-frontmatter body line, passes through
## unchanged. Prints the resulting body to stdout.
##
## Every closing `}` below is preceded by a `;` (magic-developer's
## reference/shell.md axiom: some AWK builds reject the missing-semicolon
## form as a hard parse error).
##
BEGIN {
	n = 0 ;
	while ( (getline line < opsFile) > 0 ) {
		split(line, parts, "\t") ;
		n++ ;
		opType[n] = parts[1] ; opName[n] = parts[2] ; opValue[n] = parts[3] ;
	} ;
	close(opsFile) ;
	for (i = 1 ; i <= n ; i++) {
		nm = opName[i] ;
		if (opType[i] == "remove") {
			finalAction[nm] = "remove" ; listCount[nm] = 0 ;
		} else if (opType[i] == "upsert") {
			finalAction[nm] = "set" ; finalValue[nm] = opValue[i] ; listCount[nm] = 0 ;
		} else if (opType[i] == "append") {
			finalAction[nm] = "set" ;
			listCount[nm]++ ;
			pendingList[nm SUBSEP listCount[nm]] = opValue[i] ;
		} ;
	} ;
	for (nm in finalAction) {
		if (finalAction[nm] == "set" && listCount[nm] > 0) {
			v = "" ;
			for (k = 1 ; k <= listCount[nm] ; k++) { v = (v == "" ? pendingList[nm SUBSEP k] : v ", " pendingList[nm SUBSEP k]) ; } ;
			finalValue[nm] = "[" v "]" ;
		} ;
	} ;
	infm = 0 ; closed = 0 ;
} ;
$0 == "---" && closed == 0 {
	if (infm == 0) { infm = 1 ; print ; next ; } ;
	for (nm in finalAction) {
		if (!seen[nm] && finalAction[nm] == "set") { print nm ": " finalValue[nm] ; seen[nm] = 1 ; } ;
	} ;
	infm = 0 ; closed = 1 ; print ; next ;
} ;
infm == 1 {
	for (nm in finalAction) {
		if ($0 ~ "^" nm ": ") {
			seen[nm] = 1 ;
			if (finalAction[nm] == "set") { print nm ": " finalValue[nm] ; } ;
			next ;
		} ;
	} ;
	print ; next ;
} ;
{ print ; }