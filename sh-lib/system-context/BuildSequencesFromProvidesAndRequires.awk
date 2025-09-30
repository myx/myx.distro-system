#!/usr/bin/awk -f

# awk file.
# use `awk -f make-sequences.awk distro-requires.txt distro-provides.txt > distro-sequences.txt`

# input: distro-requires.txt, 2 columns, single space separated: <projectName> <requireValue>
# input: distro-provides.txt, 2 columns, single space separated: <projectName> <provideValue>

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
#	-- break is queue is empty.
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
#       --- in `requiresMap` replace array[requiredProjects] for out project with unrolled:
#         ---- in replaced array, all direct items of array[requiredProjects] replaced with array[requiredProjects] of that item from `requiredMap`
#       --- flush block of `<currentProject> <requiredProject>` lines to stdout from newly formed array[requiredProjects]


BEGIN { FS = " "; if (ARGC < 3) { print "Usage: awk -f make-sequences.awk REQ PROV" > "/dev/stderr"; exit 2 }
  REQ = ARGV[1]; PROV = ARGV[2]; delete ARGV[1]; delete ARGV[2]
}

END {
  # queue numeric: qh..qt (inclusive)
  qh = 1; qt = 0

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

  # --- load requiresMap (resolve requireValue -> provider projects); report missing once ---
  while ((getline < REQ) > 0) {
    if ($0 == "") continue
    p = $1; rv = $2
    if (!proj_seen[p]) proj_seen[p] = 1
    left[p] = 1
    if (provider_count[rv] > 0) {
      for (i = 1; i <= provider_count[rv]; i++) {
        t = provider[rv, i]
        if (t == p) { self[p] = 1; continue }
        requires_count[p]++
        requires[p, requires_count[p]] = t
        if (!(t in left)) left[t] = 0
      }
    } else {
      if (!missing_reported[rv]) { print "⛔ MISSING: no provider for " rv > "/dev/stderr"; missing_reported[rv] = 1 }
      if (rv == p) continue
      requires_count[p]++
      requires[p, requires_count[p]] = rv
      if (!(rv in left)) left[rv] = 0
    }
    # ensure left-column projects that appeared only in provides but not in requires are queued already
  }
  close(REQ)

  # flushedMap empty initially
  while (qh <= qt) {
    cur = queue[qh]
    if (cur in flushed) { qh++; continue }

    # per-project visitedMap
    delete visited
    visited[cur] = 1

    # build inline work list from cur's immediate requires
    work_n = 0
    rc = requires_count[cur] + 0
    for (i = 1; i <= rc; i++) work[++work_n] = requires[cur, i]

    # iterate work left-to-right, expanding any already-flushed entries inline
    idx = 1
    unflushed = 0
    while (idx <= work_n) {
      r = work[idx]
      # if r is a left-column project and already flushed -> replace r in-place with its requires
      if ((r in left) && left[r] == 1 && (r in flushed)) {
        rr = requires_count[r] + 0
        if (rr == 0) { idx++; continue }        # nothing to expand
        # shift tail right
        tail = work_n - idx
        for (s = tail; s >= 1; s--) work[idx + rr + s] = work[idx + s]
        # copy r's requires into place
        for (s = 1; s <= rr; s++) work[idx + s - 1] = requires[r, s]
        work_n += rr - 1
        # re-evaluate at same idx (new item)
        continue
      }
      # if r is a left-column project and not flushed -> unmet
      if ((r in left) && left[r] == 1 && !(r in flushed)) {
        unflushed++
        if (!(visited[r])) {
          # push-left r
          qh = qh - 1
          queue[qh] = r
          queued[r] = 1
          visited[r] = 1
        }
      }
      idx++
    }

    if (unflushed == 0) {
      # flush current project: print work[1..work_n] in order
      for (k = 1; k <= work_n; k++) {
        if (work[k] == "") continue
        print cur " " work[k]
      }
      flushed[cur] = 1
	  qh++;
      # clear work
      for (k = 1; k <= work_n; k++) delete work[k]
      continue
    }
  }
}
