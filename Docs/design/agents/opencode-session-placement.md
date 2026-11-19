# Where an OpenCode session belongs

How the OpenCode plugin decides which sessions on the bus are this directory's,
and which are another session's children. Newest at the bottom.

- **The bus carries every directory's sessions**, the background service running
  them all, and each directory loads the plugin once. An event's envelope may
  name its directory, and a run's events did not in the probe, so the plugin
  keeps the sessions its hooks named and those created here, and asks about any
  other, remembering the answer. Read from the 2.1.4 binary and a probe on
  2026-10-27, not seen for a global plugin across two directories.
- **An envelope naming another directory settles it unasked**; one naming this
  one still asks, as only the answer says whether the session is a child. A
  location naming no directory says nothing and leaves the record's source as it
  was, or an answer naming no directory outranked the envelope that asked for
  it.
- **Only the events the plugin reads are queued**: a streamed part names its
  session too, and one whose lookup failed was asked about again for each part.
- **A session the TUI moves to another worktree is placed by its new location**,
  as `session.moved` says: kept here, the old worktree's dot showed the new
  one's turns. Moved away, it ends here with its children and goes Idle, or the
  old worktree kept work now running elsewhere. Those leaving are dropped
  outright, taking no place among the 64 ended, or another session's oldest
  ended child was forgotten. A child whose parent moved away is elsewhere's
  whatever an older answer says, unless a hook named it here after the move, and
  a lookup answered after the move cannot bring it back.
- **A session a hook named stays here whatever a late answer or its creation
  says**: hooks fire only for this directory's sessions, and where it ended up
  turned on whether the answer beat the bound.
- **A child's record keeps its parent**, so one a hook named first is still a
  child once the roster forgets it, and an answer or creation naming a parent
  makes a child even where the parent is unknown after a reload or forgotten.
- **A child of a session here is here whatever its own location says**: read by
  its location alone, a resumed child's answer naming no directory made it a
  parent. A parent unknown here is asked about once its child is placed, so a
  move of the top-level session takes the whole line.
- **A child the roster forgot rejoins it from its record** when it is resumed;
  kept as a plain session here, its resumption read as the parent's turn and
  announced Done.
- **Each session's events wait only for that session's lookup**, which has no
  bound. One queue for the whole bus held a parent's Done behind another
  directory's lookup, landing after the next prompt's Working. A hook's lookup
  keeps its one-second bound, and an answer landing after it still counts.
- **A session's hooks take their place in the same queue**, so an event during a
  hook's lookup is reported after the hook's Working, not dropped or
  overwritten. An event waits up to a second for a hook's lookup still out, as
  its answer may make a child: read before it, a resumed child's end was the
  parent's Done and the late answer started a worker that never ended.
- **An answer past that second, after the child's run ended, joins it to the
  roster ended**: kept started, it was out in every later Done, and joined
  silently, the worktree stayed on its Done mid-turn. After the parent's own
  Done it joins ended and silent, or its end over that Done left the worktree
  Working with no Stop to come. A prompt it raised as its own is raised again as
  the worker's, or the reply left the agent's prompt standing; one any session
  is raising stays up, as all share the agent's prompt.
- **Each session has one placement record**, its place, the source that said so
  and when. A hook or a move outranks a creation or an answer, and those outrank
  an envelope; between equals the newer wins. The precedence spread over four
  maps read worse and drifted between them.
- **A parent moved away takes a child placed before, a hook's word too**, as the
  answer naming that parent can land after the move. A hook counts from when it
  fired, not when its turn in the queue came: one fired before the move but run
  after it kept a moved child here.
- **A session leaves here one way, whatever filed it elsewhere**: a move, an
  answer or an envelope re-files every session under it and drops them from the
  roster. An answer that left the children's records here put them back on the
  roster in the old worktree, and a child filed away by an envelope stayed out
  in its parent's Done for good. Only a change of place moves them: another
  directory's session moving to a third left its child here dropped.
- **A session joining the roster forgets its own reports**, or one that reported
  as its own before its parent was known sent a stray Idle long after its parent
  moved away.
- **A top-level session is walked up the parents at each use**, never stored: a
  parent learned after its child, from a late answer, left the grandchild out of
  the Done and behind on a move away. A move re-files every record under the
  session rather than dropping them, or a grandchild seen before its parent was
  filed by its own location.
- **The records are bounded at 1024 for each place**, the service running for
  days, so other directories' sessions never push out this one's. One forgotten
  costs a lookup. The sessions' last own reports are bounded at 512.

## Reviewed and left as is

- **A lookup that never settles holds its session's queue for good** (round 4):
  an unbounded lookup was round 1's fix for a slow one dropping a session, and a
  `session.get` that never settles is a wedged service.
- **A prompt reports a new turn once its lookup's one-second bound runs out**
  (round 6), even where the late answer would show a resumed child: the bound
  keeps OpenCode's hooks from waiting, and the answer still puts the child back.
  Until then the child reports as its own session and shares the agent's one
  prompt on the dot, so its Working can answer the session's or a sibling's
  prompt (round 48); a prompt per session is a redesign of the app's prompt
  raisers, not a fix. A hook whose own wait runs out with its lookup's returns
  before its report, which can then land after another session's event (round
  49).
- **The plugin compares directories as OpenCode spells them** (round 8): the
  plugin's location and a session's come from the same server, and the probe saw
  one spelling; resolving links on every event costs a call each.
- **A late event for a child forgotten past the 64 ended starts it again**
  (round 11): its lookup names a parent, as a resumed child's does, and only its
  own next run would end it; the 1.x plugin did the same, and it takes 64 ended
  children and then a stray event. A move away and back reaches it too, its
  ended children having been dropped at the move (round 56).
- **A child located here whose parent is another directory's joins this roster**
  (round 15): a session located here is this directory's by the plugin's own
  rule, and nothing shows OpenCode placing a child apart from its parent.
- **A child created under an ended child is placed here** (round 18): unread
  whether OpenCode creates one, the app draws a worker whose parent is no longer
  out at the top, and the ended child's next run puts it back on the roster.
- **A session no answer can place is asked about at each event** (round 21):
  every session the probe saw carried a location, and a failed lookup asked
  again was round 1's fix for one that would otherwise be dropped for good.
- **A grandchild whose parent was forgotten counts under that parent** (round
  24): outside the service a Done then leaves it out, but it takes 64 ended
  children and a late event or resume of the grandchild.
- **Two walks for the sessions under one** (round 31): the tracker walks the
  roster and placement walks the records, each its own store, through one
  `ancestorsOf`. A roster child's parent passed up when its ended parent is
  forgotten has the same top-level session either way.
- **A child the TUI moves by itself** (round 32) is ignored by `onMoved`, and a
  later move of it can send a stale Idle: nothing shows OpenCode moving a child
  apart from its parent.
- **A move here re-asks every envelope-filed session elsewhere** (round 32), one
  lookup each on its next event: an envelope names no parent, so any of them may
  have come with the move, and moves are rare.
- **A running child left out of a Done after a move here mid-turn** (rounds 33
  and 42), until the child's next event rejoins it, and a grandchild's rejoin
  leaves it out still while its parent stays off the roster (round 52):
  rejoining every re-filed session at the move would mark ones that ended long
  ago as started. A forgotten session filed back here by a hook also leaves its
  moved children elsewhere, which needs OpenCode to change a session's place
  without `session.moved`.
- **A child's run end read from `reported`** (round 43): past 512 other sessions
  reporting while its lookup is still out, or a permission reply after an
  interrupt, its late answer starts a worker that never ends. The first is the
  wedged service of round 4; nothing shows the second.
- **`recordedDescendants` beside the roster walk** (round 43): the roster passes
  a forgotten ended parent's children up, and the records forget too at 1024, so
  neither store alone names every session leaving; the move merges both.
- **`relocate` scans every record** (round 33), up to 2048, to find one
  session's children. Moves are rare, and an index kept on every write costs
  more than the scan.
- **A child leaving after its parent's Done listed a grandchild sends no Idle**
  (round 41): the grandchild's end report then waits on a parent turn that may
  not come here. It needs an envelope naming another directory for a child here
  and an unread answer to whether the child's woken run wakes its parent.
- **The 65 ended children in
  `aChildTheRosterForgotSendsNoIdleWhenItLeavesWithAWorkerUnderIt`** (round 41)
  change no report under the parent-fact guard; they are the path on which the
  roster-based guard round 39 replaced sent the Idle.
- **A session a hook named is asked about once** (round 55), however that lookup
  ends: a resumed child whose one lookup fails reports as its own session for
  good. Asking again on each hook costs a lookup per tool call, for a
  `session.get` failing once, which nothing shows.

### Asked both ways

- **An unseen parent's move away, with its child here** (rounds 34 and 35): the
  plugin cannot tell a parent of another directory moving between two others
  from one of this directory it never saw, after a reload or forgotten. The
  child leaves with it: OpenCode runs a child in its parent's worktree, and a
  child here under another directory's parent is round 15's unseen premise.
- **An envelope naming another directory, against a resumed child placed
  there**: round 1 had the envelope settle another directory's sessions unasked,
  sparing every directory's copy of the plugin a lookup per foreign session;
  round 14 asked for a lookup so a resumed child located elsewhere, its creation
  unseen, joins its parent here. Kept round 1's: a child whose creation is seen
  is placed by its parent, and the other case needs a resume with no creation.
- **A lookup's answer against an envelope naming this directory**: round 2 had a
  lookup naming another directory outweigh the envelope; round 14 asked for the
  envelope to win where the answer names a subdirectory. Kept round 2's: the
  answer is the session's own location, and a session in a subdirectory has its
  own copy of the plugin there.
