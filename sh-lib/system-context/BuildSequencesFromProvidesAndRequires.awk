#!/usr/bin/awk -f

# awk file.
# use `awk -f make-sequences.awk distro-requires.txt distro-provides.txt > distro-sequence-merged.txt`
#
# input: distro-requires.txt, 2 columns, single space separated: <projectName> <requireValue>
# input: distro-provides.txt, 2 columns, single space separated: <projectName> <provideValue>
#
# Steps:
# - create queue/fifo/array whatever for `queue`, should work as stack
# - load map `providesMap` (provideValue -> array[projectName]) from distro-provides.txt, while doing so:
#   -- load `queue` adding new unique projectNames to the right side. 
# - reverse queue (makes stack with pop/push/peek on the right side)
# - load map `requiresMap` (projectName -> array[requiredProjects] from distro-requires.txt, while doing so:
#   -- populate array with projects matching each requireValue using `providesMap`.
#   -- provide error message if no projectNames matched given requiredValue, and continue
# - create `flushedMap` (projectName -> true), empty
# - loop through `queue` peeking (peek from right side) next projectName on left side:
#   -- break if queue is empty.
#   -- if project in `flushedMap`
#     --- remove project from `queue` (pop/delete from the right side)
#     --- continue loop
#   -- create `visitedMap` (projectName -> true), empty
#   -- put `projectName -> true` to `visitedMap`
#   -- define `unflushed` = 0
#   -- iterate through project's array[requiredProjects]:
#       --- if requiredProject is in `flushedMap`, continue loop
#       --- increment `unflushed`
#       --- if requiredProject is in `visitedMap`, continue loop
#       --- push required project to the right of the queue
#   -- if `unflushed` == 0, flush current project:
#       --- put `projectName -> true` to `flushedMap`
#       --- remove project from queue (pop/delete on the right side)
#       --- in `requiresMap` replace array[requiredProjects] for current project only with new unrolled:
#         ---- in replaced array, all direct items of array[requiredProjects] replaced with array[requiredProjects] of that item from `requiredMap`
#       --- flush block of `<currentProject> <requiredProject>` lines to stdout from newly formed array[requiredProjects]
#         ---- printing current project last

BEGIN {
  FS = " "
  if (ARGC < 3) { print "Usage: awk -f make-sequences.awk distro-requires.txt distro-provides.txt" > "/dev/stderr"; exit 2 }
  REQ = ARGV[1]; PROV = ARGV[2]; delete ARGV[1]; delete ARGV[2]
}

END {
  # stack pointer only (right side is stack top)
  qt = 0

  # --- load providesMap and populate queue (unique projects appended to right) ---
  while ((getline < PROV) > 0) {
    if ($0 == "") continue
    p = $1; val = $2
    if (val == "") continue
    provider_count[val]++
    provider[val, provider_count[val]] = p
    if (!queued[p]) { queue[++qt] = p; queued[p] = 1 }
  }
  close(PROV)

  # --- reverse queue so right side becomes stack top (in-place) ---
  if (qt > 1) {
    half = int(qt/2)
    for (i = 1; i <= half; i++) {
      tmp = queue[i]
      queue[i] = queue[qt - i + 1]
      queue[qt - i + 1] = tmp
    }
  }

  # --- load requiresMap (resolve requireValue -> provider projects); report missing once per requireValue ---
  while ((getline < REQ) > 0) {
    if ($0 == "") continue
    p = $1; rv = $2; sub(/:.*/, "", rv)
    if (!proj_seen[p]) proj_seen[p] = 1
    left[p] = 1
    if (provider_count[rv] > 0) {
      for (i = 1; i <= provider_count[rv]; i++) {
        t = provider[rv, i]
        requires_count[p]++
        requires[p, requires_count[p]] = t
        if (!(t in left)) left[t] = 0
      }
    } else {
      if (!missing_reported[rv]) { print "⛔ MISSING: no provider for " rv > "/dev/stderr"; missing_reported[rv] = 1 }
    }
  }
  close(REQ)

  # --- main loop: operate on right side as stack top (qt) ---
  while (qt > 0) {
    cur = queue[qt]                       # peek from right (do not pop yet)

    if (cur in flushed) { qt--; continue }    # pop/delete on the right if already flushed

    # per-iteration visitedMap
    delete visited
    visited[cur] = 1

    # seed work list with cur's immediate requires (preserve order)
    work_n = 0
    rc = requires_count[cur] + 0
    for (i = 1; i <= rc; i++) work[++work_n] = requires[cur, i]

    # scan work left-to-right, expanding flushed entries inline, pushing unmet to right
    idx = 1
    unflushed = 0
    while (idx <= work_n) {
      r = work[idx++]
		# treat r as a project if it exists in providesMap (provider_count[r] present)
		if (provider_count[r]) {
		if (r in flushed) { continue }    # flushed -> satisfied, skip
		if (visited[r]) { continue }      # visited -> skip, do not increment unflushed
		unflushed++
		queue[++qt] = r
		visited[r] = 1
		}
    }
      # clear work array slots
      for (k = 1; k <= work_n; k++) delete work[k]

    if (unflushed == 0) {
		qt--    # remove project from queue (pop from right)
		flushed[cur] = 1

		new_n=0; delete seen_new
		for (j=1; j<=requires_count[cur]; j++) { 
			x = requires[cur,j]
			if (x == cur) { 
				if (!seen_new[x]) new[++new_n]=x
				continue 
			}
			if (requires_count[x]) {
				for (t=1; t<=requires_count[x]; t++) { 
					v=requires[x,t]; 
					if (!seen_new[v]) new[++new_n]=v; 
				}
			} else {
				if (!seen_new[x]) new[++new_n]=x
			}
  		}
		requires_count[cur]=new_n
		for (j=1; j<=new_n; j++) requires[cur,j]=new[j]

		for (j=new_n; j>=1; j--) {
			out = cur " " requires[cur,j]
			if(!seen[out]++) print out
		}
		for (j=1; j<=new_n; j++) delete new[j]

      continue
    }

    # if unflushed > 0: do not pop cur; leave it on right (newly pushed items are on right and will be processed next)
  }
}
