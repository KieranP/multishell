# Tabs, columns and dragging

Where a tab lives, how it moves, how a strip runs out of room. Newest at the
bottom.

## Tabs own a pane tree, from day one

-> splits, added later, were a renderer change with no schema change. Same-axis
split adds a sibling and halves the focused pane, as tmux and iTerm do; another
axis nests.

## A tab dragged to a worktree moves, does not re-open

Shells keep running: nothing restarted, nothing `cd`'d. Where panes start and
which shell = the destination's to decide, else next launch opens one project's
shell in another's checkout. Live tab turned to on landing -> destination stays
warm. Own pasteboard type, TabTransfer, spelled both in that file and in the
`Info.plist` `make-app.sh` writes, since projects drag as text to reorder and
one type for both would offer each drag the other's targets. Costs: shell stays
in its old directory until the user cds -> a dropped file writes against the
tab's new worktree; a worktree left with no tabs loses what was on screen.

## A worktree's tabs sit in columns, a column only ever beside another

Two agents in one worktree watched at once without either becoming a pane of the
other: a column has its own strip, its own active tab, its own width. Never one
above another, a pane below being what a split already is, and a tree of columns
holding trees of panes would be two layouts doing one job -> `TabGroup` is a
flat record with a weight, renderer is one `WeightedSplit` on the horizontal
axis.

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

Only a band down each edge of a terminal area is drawn as a target; a drop on
one makes a column on that side. The area between takes a drop too, the tab
landing last in that column as it does on the strip clear of its tabs, but
lights nothing: a release that reaches no target of ours leaves a highlight on
screen with no drag behind it, so a target has to be there, and a lit one over
every terminal in the window would be a second way to do what the strip does. A
band refuses where halving the column would put either half under the minimum a
pane already has -> the drag springs back rather than making two columns nobody
can read.

`activeTab(in: worktree)` is the focused column's, which is what a keystroke, a
split and a rename act on; `shownTabs(in:)` is every column's, which is what
"the user can see this" means.

One pane in the window asks for the keyboard, not one per column: a surface
given focus reports it back, which focuses its column, so two panes asking would
leave the columns trading focus between renders.

Costs: `activeTabByWorktree` has left the state file, read now only as a legacy
key -> an older build reading a newer one forgets which tab each worktree had
active. A tab written before columns existed names no group ->
`adoptUngroupedTabs` gathers a worktree's ungrouped tabs into the one column
they were saved as, and a hand edit that loses a column is repaired the same way
rather than by dropping tabs. And everything meaning "the tab on screen" had to
become "the tab on screen in this column": `isShown`, and the notification not
raised because of it. The Done that clears when seen since narrowed further, to
the focused pane (terminals.md).

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
the room an arrow needs and buys a control that actually scrolls, finishing the
tab that end clips, else moving on to the first whole tab past it. Counting in
whole tabs left the arrow dead over a half-shown tab, since the arrow is drawn
from the same half point. It was a fade at first, on the argument that a fade
cannot be mistaken for a control, and the fade turned out too quiet to read as
anything at all.

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

Beside it, the two splits, in the same gutter and the same width apiece ->
`stripButtonsWidth`. On the strip rather than in the pane, where a button over a
terminal would take a click meant for the shell, and per column, because that is
what the strip already is: each button names its own column, splits the tab that
column shows, and focuses it, since the new pane takes the focus inside its tab
and the keyboard would otherwise stay where it was. The menu items name no
column and go on splitting the focused one.

A column can be dragged down to `SplitMetrics.minimumPane`, which is less than
the three buttons take, so a narrow strip keeps New Tab alone ->
`stripShowsSplits`. What it asks for is room for the buttons, both scroll
gutters and a whole tab besides: the gutters come off `available`, which the
buttons have already been taken out of, so a threshold counting only a tab buys
the splits by leaving a scrolling strip with no arrows, which is the one thing
arrows are there to prevent. 249pt at 13-point, 190 at 10 and 346 at 18. Asked
of the width unconditionally rather than of whether the strip scrolls: scrolling
is decided from `available`, which this decides, and the two would chase each
other. The strip reads its width once and both the buttons drawn and the room
taken off come from that answer, for the same reason the gutters are reserved
whether an arrow is drawn or not.

Costs: three buttons of gutter rather than one, so a strip shows a whole tab
later than it did; and a column under the threshold offers the splits on its
menu and keystrokes alone, including one wide enough to draw them that is not
scrolling and would not have wanted the gutters.

Costs: no auto-scroll while a tab is dragged near an end -> a reorder reaches
only the tabs on screen; and a strip whose tabs differ widely in width is the
one shape where the shuffle could in principle cross a boundary twice.

## A wheel over the strip scrolls it sideways

A horizontal scroll already reaches the scroller, so a trackpad moved the strip
from the start and a mouse, which turns one way, did nothing: a horizontal
scroller is handed nothing by a vertical event, measured at 0 points against the
30 the same event moves it once turned on its side.

So the turn is turned rather than counted. A catcher answers `hitTest` only for
a scroll whose vertical beats its horizontal, the pattern `MiddleClick` uses,
then copies the event, adds its vertical deltas to the horizontal ones and hands
it to the strip's scroller -> clicks, drags and a sideways scroll reach the tabs
and the arrows untouched, and the pixels, the momentum and the rubber band are
AppKit's, which is what the trackpad already felt like. Copied rather than
built, so the phase, the momentum and the precision it arrived with are kept. A
turn that goes sideways partway through is passed on unchanged, a scroll being
routed to the view its first event hit.

The swap writes each of an axis's three delta fields once, from the vertical
alone, lines first. Measured: the fields are coupled, so writing the line delta
makes CGEvent derive the fixed-point one, and a copy that read each horizontal
field and added the vertical to it counted a plain wheel's notch twice, 6 lines
for 3, while a trackpad's points survived only because the line write had wiped
them first. A diagonal turn therefore moves the strip by its vertical alone; the
horizontal, the smaller of the two on that branch, is dropped rather than mixed
in.

Two halves, because neither placement can do the job alone. The catcher is
outside the scroller: inside, it is hit-tested and then never called, a scroller
taking every scroll over its own content before a view in there is offered one.
Watched in the running app, which is the only place it shows. But outside it
cannot find the scroller either, SwiftUI flattening the tree so that the catcher
lands beside the whole hosting view with nothing of the strip above it; looking
for the nearest scroller from there climbed to the window and took the
sidebar's, so the wheel scrolled the sidebar and the tabs never moved. So a
marker inside the content, which is the one place `enclosingScrollView` is
exact, hands the scroller over in a `ScrollerHandle` the catcher holds.

Stepping whole tabs came first, one per notch, sharing `stepTarget` with the
arrows. It read as jumpy: an arrow is a click and can move a tab at a time, a
wheel is a continuous thing and cannot.

## A tab dropped in another column takes the keyboard with it

The drop activates the moved tab in the column it lands in, so whatever that
column was showing goes behind it. Focus has to follow, or the first responder
is a surface nobody can see and every keystroke after the drop goes into it.
This was the one move that crossed columns without reconciling afterwards; the
same pass is what withdraws the banner of the newly shown tab in the column the
tab left, which otherwise keeps one over a tab that is now on screen; its Done
dot stays until that pane is focused.

## The strip's + is a menu

A click on it opens New Shell Tab and a New Tab item per agent found on the
login shell's PATH, named after the agent, the custom command among them once
one is typed. Every item says what it starts, which the plain + could not: it
ran Cmd+T, whose answer turns on the project's auto-start setting, so the same
click started a shell in one project and an agent in the next. Cmd+T itself is
unchanged, and is the only way left to the auto-start answer.

The items open in the column the menu sits in, as the split buttons do, so a
click never acts in the column the keyboard happens to be in.

The list is held on the model and rebuilt when detection answers or the custom
command is edited, not worked out in the strip's body: a menu's content is built
with the view around it, and every column has one. Before the login shell has
answered, the menu offers the shell alone rather than a catalogue of agents the
machine may not have; it fills in when the scan lands.

The + draws its own chevron, at six tenths of the icon size so it reads as a
mark on the plus rather than a second glyph, and is wider than the split buttons
beside it by the chevron less one gap (`newTabMenuWidth`, in the strip's budget
in place of a third `newTabWidth`). The plus sits at a split glyph's inset from
the left; the right inset is shorter by two gaps. Equal insets looked unequal: a
chevron's ink is narrower than its box and a split symbol's is wider, so the gap
to the first split read as larger than the gap between the splits. AppKit's own
indicator is hidden: it sits where this one's spacing cannot reach it. The
glyphs sit on a painted `chromeColor` frame, a menu being hit-tested by what its
label draws.

The menu is the `.button` style under `.buttonStyle(.plain)`, not the
`.borderlessButton` the header's ellipsis menu uses. That one is an AppKit
button, which takes a single image from its label and draws it at the leading
edge: the chevron vanished and the + sat in the corner of a wide blank. The
plain button draws the label view as written.
