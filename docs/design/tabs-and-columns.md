# Tabs, columns and dragging

Where a tab lives, how it moves, how a strip runs out of room.
Newest at the bottom.

## Tabs own a pane tree, from day one

-> splits, added later, were a renderer change with no schema change. Same-axis
split adds a sibling and halves the focused pane, as tmux and iTerm do.

## A tab dragged to a worktree moves, does not re-open

Shells keep running: nothing restarted, nothing `cd`'d. Where panes start and
which shell = the destination's to decide, else next launch opens one project's
shell in another's checkout. Live tab turned to on landing -> destination stays
warm. Own pasteboard type, TabTransfer, spelled both in that file and in the
`Info.plist` `make-app.sh` writes, since projects drag as text to reorder and
one type for both would offer each drag the other's targets. Costs: shell stays in its
old directory until the user cds -> a dropped file writes against the tab's new
worktree; a worktree left with no tabs loses what was on screen.

## A worktree's tabs sit in columns, a column only ever beside another

Two agents in one worktree watched at once without either becoming a pane of
the other: a column has its own strip, its own active tab, its own width. Never
one above another, a pane below being what a split already is, and a tree of
columns holding trees of panes would be two layouts doing one job -> `TabGroup`
is a flat record with a weight, renderer is one `WeightedSplit` on the
horizontal axis.

A column is a record of its own rather than a field on the tab because it
outlives the tabs passing through it: its width and which tab it shows have to
survive the last tab moving out and a new one moving in. It holds its own
`activeTabID`, where the worktree's active tab was a dictionary on the
workspace: git hands back worktree records every refresh, and nothing
rediscovers a column.

A column never stands empty. Its last tab leaving takes it with it and hands
focus to the column that slid into its place, which is what a strip does when
the active tab closes. Weights are relative -> the rest come back in proportion,
nothing to renormalise.

Only the edges of a terminal area take a tab. A band down each side makes a
column on that side; the space between offers nothing, the strip above being
where a tab goes to join a column, and a target over every terminal in the
window would be a second way to do that, drawn over everything. A band refuses
where halving the column would put either half under the minimum a pane already
has -> the drag springs back rather than making two columns nobody can read.

`activeTab(in: worktree)` is the focused column's, which is what a keystroke,
a split and a rename act on; `shownTabs(in:)` is every column's, which is what
"the user can see this" means.

One pane in the window asks for the keyboard, not one per column: a surface
given focus reports it back, which focuses its column, so two panes asking
would leave the columns trading focus between renders.

Costs: `activeTabByWorktree` has left the state file -> an older build reading a
newer one forgets which tab each worktree had active. A tab written before
columns existed names no group -> `repairReferences` gathers a worktree's
ungrouped tabs into the one column they were saved as, and a hand edit that
loses a column is repaired the same way rather than by dropping tabs. And
everything meaning "the tab on screen" had to become "the tab on screen in this
column": `isShown`, the Done state that clears when seen, the notification
not raised because it was.

## A dragged tab is its own preview

AppKit draws the preview for a SwiftUI `.onDrag` itself, as an elevated card,
and holds it on screen for the best part of a second after the mouse comes up,
wherever the tab landed. Nothing in SwiftUI's drag API reaches that disposal:
answering the drop before moving the tab, so the drag ends against the view tree
it began in, made no difference, and neither would any return value, the image
being AppKit's. So `.onDrag` gets a one-point clear preview and there is nothing
to hold. Nothing is drawn from a flag set when the drag began, only from what
the pointer is over: `TabDragState.isEngaged`, `showsBands`.

What shows the drag instead is the tab. Along its own strip it moves as the
pointer passes each neighbour, which is what a tab strip does everywhere, and
the arithmetic deciding has to agree with the store's exactly or the tab moves
on every mouse event and never settles -> TabShuffle, tested against the same
index sum. The tab that just slid under the pointer is not an anchor to move
itself past, which is what keeps it from oscillating. Elsewhere the tab stays
where it is and fades, and the place it would land lights up: a line in another
column's strip, a band over a terminal, a row in the sidebar.

Only within one column. A tab crossing into another column waits for the drop,
because a column emptied by the move closes, and closing one under the pointer
takes the layout out from under a drag still going on.

Costs: a reorder is committed as the pointer passes -> a drag abandoned half-way
leaves the tabs where it dragged them rather than springing back; saves
coalesced at 300 ms, so a drag's worth of moves is one write. Nothing follows
the cursor outside a strip, a departure from the Mac convention of carrying a
ghost, and bringing one back means owning the drag as an AppKit source, where
the image and the session's `animatesToStartingPositionsOnCancelOrFail` are
settable, and owning the tab's click, double click and middle click with it.

## A strip out of room scrolls, and says which way there is more

Every tab drawn at one width, from the room and the count. They share the strip
up to a cap, shrink together as more arrive, and stop at a floor: below it the
icon, the title and the close button run into each other and into the next tab,
which is what a strip with no overflow behaviour looks like. Past the floor it
scrolls and clips. A column's own minimum width is not the answer, which is
where this started: a minimum would have to grow with the number of tabs, and a
worktree with eight of them would stop being something you can put beside
another. The floor belongs to the tab.

The end with tabs past it carries an arrow, in a gutter of its own outside the
scroller. An arrow over the tabs would either take the click meant for the tab
under it or sit there looking like a button and doing nothing; a gutter costs
the room an arrow needs and buys a control that actually scrolls, moving on by
the first whole tab past that end, a tab counting as seen if any of it is. It
was a fade at first, on the argument that a fade cannot be mistaken for a
control, and the fade turned out too quiet to read as anything at all.

Both gutters keep their room whether an arrow is drawn or not -> tabs do not
shift under the pointer as one end runs out, and that reserved room is what the
viewport is measured as, so which arrow shows and how wide the view is cannot
chase each other. A strip with no room for both gutters and a tab besides has
neither, else two arrows and nothing to scroll would be drawn over the column
beside it.

New Tab button sits outside the scroller too, so a full strip cannot push it out
of reach, and the tab turned to is scrolled into view, since Cmd+T in a full
strip would otherwise open a tab nobody can see. Neither is laid out beside a
spacer: a scroller and a spacer are both infinitely flexible, and the stack
would divide the strip between the two.

Costs: no auto-scroll while a tab is dragged near an end -> a reorder reaches
only the tabs on screen; and a strip whose tabs differ widely in width is the
one shape where the shuffle could in principle cross a boundary twice.
