#!/usr/bin/awk -f
##
## AgentBoardItemFrontmatterPrint.awk -- prints every `key: value` frontmatter
## line of one file (given as the sole ARGV argument), verbatim, in order.
## Shared by AgentsTools.InternOpBoardScan.include's own all-headers case and
## AgentsTools.Member.include's --member-work-session-input-scan (identical
## need, applied to a member's own inbox/ files instead of board/<state>/
## files) -- one shared script rather than duplicating the same logic in both
## callers, per this package's own externalize-awk/py convention.
##
## Frontmatter is delimited by two literal `---` lines; everything strictly
## between them is printed as-is. A file with no closing `---` (malformed)
## simply prints everything from the first `---` to EOF -- not this script's
## job to validate frontmatter shape.
##
$0 == "---" { infm++ ; next ; }
infm == 1 { print ; }
infm >= 2 { exit ; }
