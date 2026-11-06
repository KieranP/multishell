# The OpenCode plugin

The plugin OpenCode 2 reports through, the service it runs under, a run's end
and how the plugin subscribes. Newest at the bottom.

- **OpenCode 2 alone is supported**, the user's call on 2026-10-27: 2 runs no
  plugin written for 1.x, and one file serving both kept a second adapter to
  test for a line about to go. The plugin is a default export of an `id` and a
  `setup`, still at `plugin/multishell.js`, which 2.1.4 scans beside `plugins/`,
  so an install from an older build reads as needing Update.
- **Under the service the helper is told of no tab**: the service keeps the
  environment of the tab that first started it, so every tab's sessions named
  that one. The plugin reads `--service` in its process's arguments and hands
  the helper an environment without the tab's session, worktree, socket and app,
  so the helper finds the app's socket itself and the report marks the worktree
  by its directory. A TUI started with `--standalone` runs the plugin in its own
  process and keeps the tab. Cost: two OpenCode tabs in one worktree share one
  dot.
- **A run's end is one of three events**: succeeded is Done, failed is Failed,
  and interrupted by the user is Idle, as Codex's `Interrupt` is, nothing having
  finished. A run superseded by a prompt sent mid-turn reports nothing, the next
  run carrying on. A failed run's error message is the report's. One ended for
  inactivity is Failed, never having finished. A shutdown is the service going,
  so it reports nothing and the pid poll clears the pane as the service's pid
  goes.
- **A cancelled child wakes its parent in 2**, which hears of it as a message,
  so no end the plugin sends says it wakes nobody.
- **No hook of the plugin's may throw**: a throw fails the user's prompt or tool
  call, so every hook and event body swallows its errors.
- **It subscribes before it registers its hooks**, the bus replaying nothing. A
  hook that fails to register aborts the subscription before `setup` throws:
  OpenCode counts that plugin as failed, and its loop read on with nothing to
  stop it (`aSetupThatFailsToRegisterAHookStopsReadingTheBus`).
- **Each session's last Working is its own**: two sessions in one directory
  shared one, and one's Done swallowed the other's (`eachSessionsDoneIsItsOwn`).
  A run's end arrives once in 2, so no second Done is dropped.

## Reviewed and left as is

- **A closed bus stream is not subscribed to again** (round 1): nothing shows
  2.1.4 ending the stream while the plugin runs, and a reload calls `setup`
  afresh. Unproven, so no retry loop.
- **A prompt sent mid-turn starts a turn, emptying the roster** (round 2): the
  prompt hook's `delivery` cannot tell it apart, the probe of 2.1.4 showing an
  idle session's first prompt as `steer` too, and whether a superseded run keeps
  its children is unread.
- **Events queued before a hook fails to register may still report** (round 21):
  the window is between the subscription and one registration rejecting, and
  nothing shows it reached.
- **`reportsWaiting` true for any plugin** (round 21): OpenCode's is the only
  plugin and reports Waiting; another would say so when it comes.
- **Under the service a move away's Idle settles the worktree's one entry**
  (round 25), another session's turn there with it: the cost recorded for two
  OpenCode tabs in one worktree sharing one dot. Two sessions in one standalone
  TUI share its tab's dot the same way (rounds 46 and 50): a child that reported
  as its own before its late answer, landing after its parent moved away, sends
  its own Idle over the other session's turn.
- **"child" and "worker" in the plugin** (round 12): a child is OpenCode's
  session relation, by `parentID`; a worker is the roster's entry the app
  counts. `isWorker(parentID)` asks whether the parent is on the roster.
- **The tracker's `report(…, worker, …)` parameter shadowing
  `worker(id, phase)`, and its `child` locals for a roster entry** (2026-11-04
  review). Renaming them changes the plugin text, so every installed plugin
  reads stale and offers Update; they go with the next plugin change that is
  needed anyway.

### Asked both ways

- **A standalone Done listing every session's children or only its own** (round
  52): two sessions in one standalone TUI share its pane, so its own list drops
  the other's running children until their next report. Kept its own
  (`aSessionsDoneListsOnlyItsOwnChildrenAsOut`): the cost is round 25's shared
  dot, and only the service, every tab's sessions in one plugin, lists all.
- **The plugin source test checking each state's report call**: round 6 loosened
  it to any quoted state, round 13 restored the calls so a state no call sends
  fails it, and round 21 asked to drop it as rename churn. Kept round 13's, the
  behaviour suite not checking each state is spelled as the helper takes it.
