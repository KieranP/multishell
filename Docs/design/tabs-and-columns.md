# Tabs, columns and dragging

Where a tab lives, how it moves, how a strip runs out of room. Newest at the
bottom.

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
- **A worktree's tabs sit in columns, a column only ever beside another.** Two
  agents in one worktree can be watched at once without either becoming a pane
  of the other.
- **Never one above another**, a pane below being what a split already is, and a
  tree of columns holding trees of panes would be two layouts doing one job.
- **A column is a record of its own**, not a field on the tab, because it
  outlives the tabs passing through it: its width and which tab it shows survive
  the last tab moving out.
- **It holds its own active tab**, where that was once a dictionary on the
  workspace: git hands back worktree records every refresh, and nothing
  rediscovers a column.
- **A column never stands empty.** Its last tab leaving takes it with it and
  hands focus to the column that slid into its place, as a strip does when the
  active tab closes.
- **Weights are relative**, so the rest come back in proportion with nothing to
  renormalise.
- **Only a band down each edge of a terminal area is a target**, and a drop
  there makes a column on that side.
- **The area between takes a drop but lights nothing.** A release that reaches
  no target leaves a highlight with no drag behind it, so a target has to be
  there; lighting every terminal would be a second way to do what the strip
  does.
- **A drag released over nothing ends with its drag session.** No drop runs for
  it, and without this every column kept a clear drop target over its terminal
  until the next drag began. AppKit ends the session after any drop has run, so
  a drop that did land reads the drag first. The session names no items for an
  `.onDrag` drag, so the tab comes from the drag's start.
- **A dragged tab closed mid-drag ends the drag with it.** One whose button is
  rebuilt, as when the strip starts or stops scrolling, keeps it: the session's
  end reaches only the button that began the drag, so this one ends once the
  mouse button is seen up, polled every 100 ms, and 250 ms after that so a drop
  that landed reads it first.
- **A drag nothing takes, Escape included, puts the tab back**, as does a drop
  refusing it, at the drop or when the move runs a turn later: a sidebar row, a
  band, a tab that closed in between, or its own column's terminal area, which
  lights nothing. The shuffle has moved it by then, so the drag keeps the
  neighbours it started between.
- **Its own strip clear of the tabs keeps it** where the shuffle left it, the
  pointer having passed the last tab to get there.
- **Every drop reads the tab from the drag, not the payload**, which can load
  after the session has ended and put the tab back. The payload is empty; only
  its type is read.
- **No drag leaves the app.** Finder took a tab or a project and made a file of
  it, so both refuse every operation outside the app.
- **No band is drawn where halving the column would put either half under the
  pane minimum**, rather than make two columns nobody can read. A release there
  reaches the area beneath, where its own column's tab springs back and another
  column's joins it.
- **The active tab is the focused column's**, which is what a keystroke, a split
  and a rename act on. The shown tabs are every column's, which is what "the
  user can see this" means.
- **One pane in the window asks for the keyboard**, not one per column: a
  surface given focus reports it back, so two panes asking would leave the
  columns trading focus between renders.
- **Costs of columns**: the old active-tab key has left the state file, read now
  only as a legacy key, so an older build forgets which tab each worktree had
  active.
- **A tab written before columns names no group**, so the repair gathers a
  worktree's ungrouped tabs into the one column they were saved as, and a hand
  edit that loses a column is repaired the same way rather than by dropping
  tabs.
- **Everything meaning "the tab on screen" became "in this column"**, including
  the notification not raised because of it. The Done that clears when seen has
  since narrowed to the focused pane (terminals.md).
- **A dragged tab is its own preview.** AppKit draws the preview for a SwiftUI
  drag itself and holds it on screen for most of a second after the mouse comes
  up, wherever the tab landed, and nothing in the API reaches that disposal.
- **So the drag gets a clear one-point preview** and there is nothing to hold.
  Nothing is drawn from a flag set when the drag began, only from what the
  pointer is over.
- **What shows the drag is the tab.** Along its own strip it moves as the
  pointer passes each neighbour, which is what a tab strip does everywhere.
- **The arithmetic deciding that has to agree with the store's exactly**, or the
  tab moves on every mouse event and never settles. It is a tested value, held
  to the same index sum.
- **The tab that just slid under the pointer is not an anchor to move itself
  past**, which is what keeps it from oscillating.
- **Elsewhere the tab stays where it is and fades**, and the place it would land
  lights up: a line in another column's strip, a band over a terminal, a row in
  the sidebar.
- **Live reordering is within one column only.** A tab crossing into another
  waits for the drop, because a column emptied by the move closes, and closing
  one under the pointer takes the layout out from under a drag still going on.
- **A reorder is committed as the pointer passes**, so a drag some target takes
  keeps it, and only one nothing takes or that refuses springs back (above).
  Saves coalesce, so moves in quick succession share a write; a drag that pauses
  between neighbours writes once per pause.
- **Nothing follows the cursor outside a strip**, a departure from the Mac
  convention. Bringing a ghost back means owning the drag as an AppKit source,
  and the tab's click, double click and middle click with it.
- **A strip out of room scrolls and says which way there is more.** Every tab is
  drawn at one width from the room and the count, sharing the strip up to a cap
  and shrinking together as more arrive.
- **They stop at a floor**, below which the icon, the title and the close button
  run into each other and into the next tab. Past the floor the strip scrolls
  and clips.
- **A column minimum is not the answer**, which is where this started: it would
  have to grow with the number of tabs, and a worktree with eight would stop
  being something you can put beside another. The floor belongs to the tab.
- **The end with tabs past it carries an arrow, in a gutter outside the
  scroller.** Over the tabs it would take the click meant for the tab under it,
  or sit there looking like a button and doing nothing.
- **The arrow finishes the tab that end clips**, else moves on to the first
  whole tab past it. Counting in whole tabs left it dead over a half-shown tab,
  the arrow being drawn from the same half point.
- **It was a fade first**, on the argument that a fade cannot be mistaken for a
  control, and the fade turned out too quiet to read as anything at all.
- **Both gutters keep their room whether an arrow is drawn or not**, so tabs do
  not shift under the pointer as one end runs out, and the reserved room is what
  the viewport is measured as.
- **A strip with no room for both gutters and a tab has neither**, or two arrows
  and nothing to scroll would be drawn over the column beside it.
- **New Tab sits outside the scroller too**, so a full strip cannot push it out
  of reach, and the tab turned to is scrolled into view.
- **Neither is laid out beside a spacer**: a scroller and a spacer are both
  infinitely flexible, and the stack would divide the strip between the two.
- **The two splits sit in the same gutter**, on the strip rather than in the
  pane, where a button over a terminal would take a click meant for the shell.
- **Each names its own column**, splits the tab that column shows and focuses
  it, the new pane taking focus inside its tab. The menu items name no column
  and split the focused one.
- **A narrow strip keeps New Tab alone.** A column can be dragged below what the
  three buttons take, so the splits are shown only above a threshold.
- **That threshold asks for the buttons, both gutters and a whole tab besides.**
  Counting only a tab buys the splits by leaving a scrolling strip with no
  arrows, which is the one thing arrows are there to prevent. `UIMetricsTests`
  writes the widths out.
- **Asked of the width unconditionally**, not of whether the strip scrolls,
  which is decided from the room this leaves: the two would chase each other.
- **Costs**: three buttons of gutter rather than one, so a strip shows a whole
  tab later; and a column under the threshold offers the splits on its menu and
  keystrokes alone.
- **More costs**: no auto-scroll while a tab is dragged near an end, so a
  reorder reaches only the tabs on screen; and a strip whose tabs differ widely
  in width is the one shape where the shuffle could cross a boundary twice.
- **A wheel over the strip scrolls it sideways.** A horizontal scroll already
  reached the scroller, so a trackpad worked from the start and a mouse, which
  turns one way, did nothing.
- **The turn is turned rather than counted.** A catcher answers hit-testing only
  for a scroll whose vertical beats its horizontal, copies the event, moves its
  vertical deltas into the horizontal fields and hands it to the strip's
  scroller.
- **So clicks, drags and a sideways scroll reach the tabs untouched**, and the
  pixels, the momentum and the rubber band stay AppKit's.
- **Copied rather than built**, so the phase, momentum and precision it arrived
  with are kept. A turn that goes sideways partway through is passed on
  unchanged, a scroll being routed by its first event.
- **The swap writes each delta field once, from the vertical alone, lines
  first.** The fields are coupled, so reading each and adding counted a wheel's
  notch twice, while a trackpad's points survived only because the line write
  had wiped them.
- **A diagonal turn moves the strip by its vertical alone**, the horizontal
  being the smaller on that branch and dropped rather than mixed in.
- **Two halves, because neither placement can do the job alone.** Inside the
  scroller the catcher is hit-tested and never called, a scroller taking every
  scroll over its own content first.
- **Outside it cannot find the scroller either**, SwiftUI flattening the tree,
  and climbing from there took the sidebar's, so the wheel scrolled the sidebar.
- **So a marker inside the content hands the scroller over**, that being the one
  place the enclosing-scroller lookup is exact.
- **Stepping whole tabs came first** and read as jumpy: an arrow is a click and
  can move a tab at a time, a wheel is continuous and cannot.
- **A tab dropped in another column takes the keyboard with it.** The drop
  activates it there, so focus has to follow or the first responder is a surface
  nobody can see.
- **That was the one move that crossed columns without reconciling**, and the
  same pass withdraws the banner of the tab newly shown in the column the tab
  left. Its Done dot stays until that pane is focused.
- **The strip's plus is a menu**: New Shell Tab and a New Tab item per agent
  found on the login shell's PATH, the custom command among them once one is
  typed.
- **Every item says what it starts**, which the plain plus could not: it ran the
  new-tab shortcut, whose answer turns on the project's auto-start setting, so
  the same click started a shell in one project and an agent in the next.
- **The shortcut itself is unchanged**, and is the only way left to the
  auto-start answer.
- **The items open in the column the menu sits in**, as the split buttons do, so
  a click never acts in the column the keyboard happens to be in.
- **The list is held on the model**, rebuilt when detection answers or the
  custom command is edited: a menu's content is built with the view around it,
  and every column has one.
- **Before the login shell has answered it offers the shell alone**, rather than
  a catalogue of agents the machine may not have, and fills in when the scan
  lands. A typed custom command is the exception, listed from launch: it has no
  scan to wait for.
- **The plus draws its own chevron**, small enough to read as a mark on it
  rather than a second glyph, which makes the button wider than the splits
  beside it.
- **Its insets are deliberately unequal.** Equal ones looked unequal: a
  chevron's ink is narrower than its box and a split symbol's is wider, so the
  gap to the first split read as larger than the gap between the splits.
- **AppKit's own indicator is hidden**, sitting where this one's spacing cannot
  reach it, and the glyphs sit on a painted frame, a menu being hit-tested by
  what its label draws.
- **It is the plain button style, not the borderless one** the header's menu
  uses: that is an AppKit button, which takes a single image from its label and
  draws it at the leading edge, so the chevron vanished and the plus sat in the
  corner of a wide blank.
- **A tab's own worktree row neither lights nor offers a move**, the drop there
  being refused. Lit, it promised a move the release would not make. Nor does
  any row while a create or remove runs, or has failed, on either worktree.
- **A drop with no tab in the air refuses**, so a drop the session's end beat to
  the tab reports that nothing moved rather than a move that never ran.
- **A project drag ends as a rebuilt tab button's does.** The sidebar's rows sit
  in a `LazyVStack`, which recycles a row scrolled away mid-drag, and the
  session's end reaches only a source still on screen, so the release ends it.
