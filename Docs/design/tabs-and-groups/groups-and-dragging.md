# Groups and dragging

Where a tab lives and how it moves: pane trees, groups, drops and the drag
itself. Newest at the bottom.

- **Tabs own a pane tree from day one**, so splits were a renderer change with
  no schema change. A same-axis split adds a sibling and halves the focused
  pane, as tmux and iTerm do; another axis nests.
- **A tab dragged to a worktree moves, it does not re-open.** Shells keep
  running: nothing restarted, nothing changed directory.
- **Where panes start and which shell is the destination's to decide**, or the
  next launch opens one project's shell in another's checkout. The live tab is
  turned to on landing, so the destination stays warm.
- **Tabs carry their own pasteboard type**, spelled in the code and in the
  Info.plist, because projects drag as text to reorder and one type for both
  would offer each drag the other's targets.
- **Costs of the move**: the shell stays in its old directory until the user
  changes it, so a dropped file writes against the tab's new worktree, and a
  worktree left with no tabs loses what was on screen.
- **A worktree's tabs sit in groups, a group only ever beside another.** Two
  agents in one worktree can be watched at once without either becoming a pane
  of the other.
- **Never one above another**, a pane below being what a split already is, and a
  tree of groups holding trees of panes would be two layouts doing one job.
- **A group is a record of its own**, not a field on the tab, because it
  outlives the tabs passing through it: its width and which tab it shows survive
  a tab moving out.
- **It holds the tab it shows**, which was once a dictionary on the workspace:
  git hands back worktree records every refresh, and nothing rediscovers a
  group.
- **A group never stands empty.** Its last tab leaving takes it with it and
  hands focus to the group that slid into its place, as a strip does when the
  tab it shows closes.
- **Weights are relative**, so the rest come back in proportion with nothing to
  renormalise.
- **Only a band down each edge of a terminal area is a target**, and a drop
  there makes a group on that side.
- **The area between takes a drop but lights nothing.** A release that reaches
  no target leaves a highlight with no drag behind it, so a target has to be
  there; lighting every terminal would be a second way to do what the strip
  does.
- **A drag released over nothing ends with its drag session.** No drop runs for
  it, and without this every group kept a clear drop target over its terminal
  until the next drag began. AppKit ends the session after any drop has run, so
  a drop that did land reads the drag first. The session names no items for an
  `.onDrag` drag, so the tab comes from the drag's start.
- **A dragged tab closed mid-drag ends the drag with it.** One whose button is
  rebuilt, as when the strip starts or stops scrolling, keeps it: the session's
  end reaches only the button that began the drag, so this one ends once the
  mouse button is seen up, polled every 100 ms, plus 250 ms so a drop that
  landed reads it first.
- **A drag nothing takes, Escape included, puts the tab back**, as does a drop
  refusing it, at the drop or when the move runs a turn later: a sidebar row, a
  band, a tab that closed in between, or its own group's terminal area, which
  lights nothing. The shuffle has moved it by then, so the drag keeps the
  neighbours it started between.
- **Its own strip clear of the tabs keeps it** where the shuffle left it, the
  pointer having passed the last tab to get there.
- **Every drop reads the tab from the drag, not the payload**, which can load
  after the session has ended and put the tab back. The payload is empty; only
  its type is read.
- **No drag leaves the app.** Finder took a tab or a project and made a file of
  it, so both refuse every operation outside the app.
- **No band is drawn where halving the group would put either half under the
  pane minimum**, rather than make two groups nobody can read. A release there
  reaches the area beneath, where its own group's tab springs back and another
  group's joins it.
- **The active tab is the focused group's**, which is what a keystroke, a split
  and a rename act on. The shown tabs are every group's, which is what "the user
  can see this" means.
- **One pane in the window asks for the keyboard**, not one per group: a surface
  given focus reports it back, so two panes asking would leave the groups
  trading focus between renders.
- **Costs of groups**: the old active-tab key has left the state file, read now
  only as a legacy key, so an older build forgets which tab each worktree had
  active.
- **A tab written before groups names no group**, so the repair gathers a
  worktree's ungrouped tabs into the one group they were saved as, and a hand
  edit that loses a group is repaired the same way rather than by dropping tabs.
- **Everything meaning "the tab on screen" became "in this group"**, including
  the notification not raised because of it. The Done that clears when seen has
  since narrowed to the focused pane (terminals/sessions.md).
- **A dragged tab is its own preview.** AppKit draws the preview for a SwiftUI
  drag itself and holds it on screen for most of a second after the mouse comes
  up, wherever the tab landed, and nothing in the API reaches that disposal.
- **So the drag gets a clear one-point preview** and there is nothing to hold.
  Nothing is drawn from a flag set when the drag began, only from what the
  pointer is over.
- **What shows the drag is the tab.** Along its own strip it moves as the
  pointer passes each neighbour, as a tab strip does everywhere.
- **The arithmetic deciding that has to agree with the store's exactly**, or the
  tab moves on every mouse event and never settles. It is a tested value, held
  to the same index sum.
- **The tab that just slid under the pointer is not an anchor to move itself
  past**, which keeps it from oscillating.
- **Elsewhere the tab stays where it is and fades**, and the place it would land
  lights up: a line in another group's strip, a band over a terminal, a row in
  the sidebar.
- **Live reordering is within one group only.** A tab crossing into another
  waits for the drop, because a group emptied by the move closes, and closing
  one under the pointer takes the layout out from under a drag still going on.
- **A reorder is committed as the pointer passes**, so a drag some target takes
  keeps it, and only one nothing takes or that refuses springs back (above).
  Saves coalesce, so moves in quick succession share a write; a drag that pauses
  between neighbours writes once per pause.
- **Nothing follows the cursor outside a strip**, a departure from the Mac
  convention. Bringing a ghost back means owning the drag as an AppKit source,
  and the tab's click, double click and middle click with it.
- **A tab dropped in another group takes the keyboard with it.** The drop
  activates it there, so focus has to follow or the first responder is a surface
  nobody can see.
- **That was the one move that crossed groups without reconciling**, and the
  same pass withdraws the banner of the tab newly shown in the group the tab
  left. Its Done dot stays until that pane is focused.
- **A tab's own worktree row neither lights nor offers a move**, the drop there
  being refused. Lit, it promised a move the release would not make. Nor does
  any row while a create or remove runs, or has failed, on either worktree.
- **A drop with no tab in the air refuses**, so a drop the session's end beat to
  the tab reports that nothing moved rather than a move that never ran.
- **A project drag ends as a rebuilt tab button's does.** The sidebar's rows sit
  in a `LazyVStack`, which recycles a row scrolled away mid-drag, and the
  session's end reaches only a source still on screen, so the release ends it.
- **`tabs move` places a tab beside another of its worktree, in any group**, as
  a drop on that tab does. With no drag going on, a group it empties can close
  at once. Another worktree's tab is refused as the anchor;
  `tabs move --worktree` takes a terminal tab there, as a drop on that
  worktree's row does
  (`aTabMovesBesideAnotherOfItsWorktreeAndNotBesideAnotherWorktrees`).

## Reviewed and left as is

- **A tab may keep its hover after it is dragged** (round 15, unproven): a drag
  session holds the pointer, so the face hears no exit, and the next move over
  it corrects it.
- **The least a split gives a pane is `SplitMath.minimumPaneLength`, not
  `UIMetrics`'s.** The views' measurements live in `UIMetrics`, but a request's
  shares are checked against it in AppCore, which cannot reach the app's
  `UIMetrics`; it sits beside the drag arithmetic that already takes it.
