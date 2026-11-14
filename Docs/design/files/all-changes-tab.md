# The All changes tab

One scrolling diff of every change in a worktree, with review comments on its
lines (issue #42, owner's picks of 2026-11-14 from the mockups). Newest at the
bottom.

- **The exception to "no diff tab"** (files/file-tabs.md). A file and its change
  read as one thing, but reviewing what an agent did across twenty files meant
  twenty tabs stepped through one by one. This tab is that review; the file tab
  stays as it was.
- **A third tab kind, not a file tab holding many paths.** A file tab's path,
  title, strike and dot each assume one file. `WorkspaceTab` gains a case, so
  every switch on the kind is a compile error until it says what the tab does;
  the sites that probed one array then another now ask `workspaceTab(_:)` once
  and switch.
- **At most one a worktree, closable like any tab.** Opening it again turns to
  it. It never leaves its worktree, as a file tab does not.
- **Saved under a key of its own, read lossily**, so an older build drops it as
  it drops file tabs. The repair drops one whose worktree went or whose id
  another tab holds, and a second in its worktree, the first kept.
- **Opened from a button beside the Changes page's filter**, or
  `tabs open-all-changes`. A click on a Changes row shows the tab at that file,
  opening it if closed and expanding the file if collapsed (owner's ask), rather
  than the file's tab; the Files page, the quick switcher and `tabs open-file`
  still open the file's tab. Each file's header has a button that does.
- **The row of the file at the top of the tab is lit in Changes** while the tab
  is in front, the view reporting the file at its clip's top as it scrolls. A
  clicked row lights at once and stays lit while the view stays where the click
  left it: a file near the end cannot reach the top, and the click otherwise
  seemed to do nothing (owner's report). The file at the top is the one whose
  box's top sits at or above the clip's top; mapped from the row there, a file
  with no rows of its own lit the next file with rows (owner's report).
- **The files are the Changes list's, in its order**: the status read's under
  Modified, the Branch read's under Branch, folders before files and names as
  Finder sorts them. A folder listed as a change, a submodule or a nested
  repository, is left out as the list leaves it, found by `lstat` since the
  index read that marks submodules is the panel's alone.
- **The Branch read was the panel's only**, made for its worktree while it
  showed Changes. A shown All changes tab under Branch now asks for its
  worktree's, and forgetting the panel's listings keeps it; there is no second
  way of reading git for the tab.
- **Each file is read by the file tab's reader, with its cap**, so a file reads
  the same in both. A read asks git once, not once a file, for the merge base,
  `HEAD`, the committed sizes (`ls-tree`), the ignored files and the files the
  index holds, and diffs files forty a run, several runs at once; a file in no
  commit and not in the index is read as new with no diff run. A diff header git
  quotes, a name with a tab or quote, sends that run's files to their own runs.
  300 modified files went from 3.3 s to 0.08 s, this repository's 222 branch
  files from 0.45 s to 0.19 s.
- **One read log a tab, paced by the files the next read reads**: ten times a
  file's share of the last read's cost, times the files owed. Paced by the whole
  read, as a file tab is, a first read of 1,802 files held the next for minutes,
  so files the status listed since waited that long to show. A read reads only
  what moved: a git change in the project reads every file, and one in an
  embedded repository the files inside it, as each file tab would; an event in a
  listed file's folder reads the files whose `lstat` moved; a status or Branch
  read reads the files it lists new or counted otherwise. The rest keep their
  rows.
- **A hidden tab lets go of its rows and is owed its read**, as a file tab is;
  shown again it reads every file at once. A shown tab's worktree has its status
  read in the background too, as the panel's has.
- **The tab holds at most 200,000 rows across its files**; past that a file
  shows its header and an Open File button, as the mockup's over-cap file did. A
  file past the file tab's 1 MiB cap says so in its place. Measured with the
  debug build over a copy of this repository's sources, every one of 1,802 Swift
  files changed by a line and 191 more added: 191 MB in all against 78 MB with
  the tab shut, 13 MB of it the rows held (82,895 lines). The cap stays as a
  guard now that only files near the screen are read.
- **Only the files near the screen are read**, as the owner asked: the list
  names the files it builds, and a read leaves the rest unread behind a Reading
  notice, read as the list nears them. A file read once keeps its rows: one a
  change outdates away from the screen keeps them stale, read again as the list
  nears it (review round 3; dropped to Reading, a git commit emptied the tab).
- **Only the files near the clip are built**, each a view of its own, and let go
  of as they leave: hosting every header and fold of 1,802 files took the app to
  1.43 GB, a SwiftUI hosting view and its surface each costing a few hundred
  kilobytes. A file not built takes its height from its rows, folds and notices;
  a built one its own, cards and all, and a height moving holds the file at the
  top where it was. A view let go of is kept, a few of each kind, for the next
  file: building one a file scrolled to cost 150 MB while scrolling (owner's
  report). It starts the next file at its left edge.
- **A list of files, each its own view** (owner's pick, replacing one text for
  every file): a header over the file's own diff, Unified or Split, in one
  vertical scroller. One text had stacked headers into gaps, needed a separate
  layer for Split's full-width files and mapped the top row to a file, and each
  brought a bug. The document still joins the files' rows, as the address find,
  the step buttons, the saved scroll and comments use; each file's view shows
  its own slice of it (`AllChangesFileSlice`), folds and notices renumbered to
  its rows.
- **Each row's fragment reports its row and the gap under it as its height.**
  TextKit finds a scroll's top by summing fragment heights; with a gap every few
  rows, as the one text's headers were, its sum fell thousands of rows short of
  the forced geometry and the rows on screen were left blank. Card gaps are
  sparse enough that the file tab never showed it
  (`theRowsOnScreenAreInTextKitsViewportWithAGapEverySixRows`).
- **The gap above the first row starts TextKit's container**, not a row's
  height. A tall gap there, the one text's collapsed files then a file's fold,
  is counted by no fragment, and TextKit left the first rows blank (owner's
  report; `theFirstRowsAreLaidOutUnderATallGapAboveTheFirstRow`).
- **Each file is a box with a margin either side, as the mockups drew it**: its
  view's own border. The vertical scroller sits in the right margin, outside the
  boxes, as wide as it grows under the pointer, 17 pt.
- **Three lines of context around each change, as `git diff` keeps.** An
  unchanged run shorter than four lines shows whole, its fold row saving little.
- **A fold's click shows every line it held.** The mockup opened a few at the
  top of a large file and offered Open file for the rest; the simplest rule was
  taken and the owner kept it. Opened folds are kept for the run by the file on
  disk's line numbers, so a re-read keeps them.
- **A collapsed file keeps its header, counts and comment badge**, and is kept
  for the run only, by tab and path; the owner did not need it kept across
  launches. Near the screen it is not read until expanded: it shows no rows.
- **The bar's chevron pair, right of Unified/Split, collapses every file**, or
  expands every one once all are (owner's ask, as the mockups drew it). It
  writes the same per-run set a header's chevron does.
- **The change letter's square, and a lit button on a header or card, sit on the
  fill drawn again**, a shade up where the theme's fill is translucent. Eight of
  the twelve built-in themes have an opaque fill, which drawn twice reads as
  none, so those draw the selection colour instead (`ChipOnFill`).
- **The header of the file at the top is held over the text** once its own has
  scrolled past: the one overlay, from the list's file tops. The next file's
  header pushes it up and out as it arrives (owner's report).
- **Each file is highlighted as its view is built**, parsed over its own rows, a
  folded slice parsing wrong, and the spans mapped onto the rows shown. The
  parse is kept by path, so a fold opening or a scroll back parses nothing
  again; parsing every file of a large worktree on each read held a core for
  tens of seconds.
- **The bar's step buttons go across files**: every change of every file is a
  stop, ordered by where it starts in the list (`AllChangesSteps`); a step
  scrolls the list to it and boxes it in its file's view. A file shown whole in
  Split is one change like any other.
- **A selection stays within one file**, each file being its own text; it copies
  as that file's tab copies it. Copy across files was not wanted (owner).
- **Find searches the rows shown**, the document's, and paints each file's share
  in its view; the selected match scrolls the list to it. Folded and collapsed
  lines are not searched; the file tab has them all. In Split it searches the
  right side, the file on disk, so a deleted file is not searched.
- **The scroll is saved by the file at the top and its line there**, so files
  coming or going above, or folds opening, return to the same line. It is put
  back by the built file's own row geometry, folds included; by row height alone
  each return crept up by the folds above (owner's report).
- **Review cards are the file tab's**: the same cards, composer, gutter + and
  drag, Comment on Lines, chips and Review rows, through one set of tables keyed
  by `ReviewTabID`, the id of a tab hosting cards. A comment written in either
  view shows in both, and one Send carries them all.
- **Cards are placed per file against that file's own rows**, then moved to the
  document's: placing over the document's rows put one file's card on another's
  line of the same number.
- **The composer carries its file's path**; a drag or Comment on Lines reads the
  rows as the file of the row it started on, stopping at that file's last row.
- **A drag or Comment on Lines stops at a fold**, as the owner picked: it never
  quotes lines it hid. To comment on them, open the fold first.
- **Each read re-anchors the comments of every file whose rows moved**, and the
  composer where it is on that file, as a file tab's read does.
- **A comment holds its lines and two either side open inside a fold**, as the
  owner picked; a comment's lines are always on screen to place its card under.
- **The tab's badge counts every comment to send in its worktree.**
- **Closing the tab asks first while its composer holds text**, as a file tab's
  close does.
- **A comment picked in Review is revealed in the All changes tab where a group
  shows it**, its file expanded if collapsed, and otherwise in its file's tab as
  before. This follows the mockup, not an explicit pick. A comment on a file
  still unread scrolls to that file and shows once it is read; taken at once,
  the reveal found no card and was lost (owner's report).
- **`review add` quotes only through a file tab** (owner's pick): a command line
  comment goes through the file's own tab, never this one.
- **Modified/Branch and Unified/Split are the one choice every file tab and
  Changes follow.** Where the project has no base branch the tab counts from
  `HEAD` and offers no scope switch, as a file tab does.
- **Split lays each file's two sides row for row**, as its file tab's split
  does, and folds only rows unchanged on both.
- **In Split a file all added or all removed shows full width** (owner's pick):
  its view is Unified, across the box. Its rows still lie row for row in the
  split's sides, padding opposite, so find, the step buttons and the saved
  scroll address it as any other file.
- **In Split the columns' divider runs down each file's diff**, its folds and
  notices laid over it across both columns.
- **Each file's folds and notices sit in its own diff's gaps**, laid across its
  gutter and text or both columns, flush with the box as the mockups drew them:
  no inset above the first row or below the last. A file's diff scrolls sideways
  on its own (owner's ask) and hands a vertical wheel to the list.
- **A step onto a file still to be read lands on its header** (owner's pick): it
  is then near the screen and read, and the next step goes into its changes.
  Steps over read files alone greyed the buttons out at the last one.
- **A fold's label starts where its file's code does**, its glyph centred in the
  gutter, as the mockup lines them up; the gutter widens with its digits.
- **The sticky header keeps the box's rounded top corners** (mockup).
- **Cmd+Up and Cmd+Down reach the list's ends from any file**, and from the list
  itself: a file view let go of with its text focused hands the focus to the
  list, or the keys beeped (owner's report).
- **A trackpad gesture keeps the axis its first moving frame chose**, momentum
  included (`WheelAxisLock`): chosen a frame at a time, a sideways swipe leaning
  vertical for a frame went to the list mid-swipe (owner's report). A file never
  bounces vertically.
- **The step buttons' enabled state places the first and last change alone**,
  the list's order being the document's: placing every change on each scroll
  took two thirds of a scroll step over 2,000 files.
- **Debug Info counts the tab with the file tabs**: each file's rows and the
  document joined from them, not the layout.
- **`tabs step` and `tabs find` reach the tab** as they reach a file tab, the
  document being rows whatever its files hold.
- **A notice offers what the file's tab offers**: Open in Editor for a file too
  large, binary or unreadable, as the mockup's file past the cap did; Open File
  for an image or a file past the row cap, which its tab shows.
- **With nothing to show, the tab says why as the mockup drew it**: under
  Modified it names the worktree and offers Show Branch where the project has a
  base; under Branch it names the base. The mockup also counted the branch's
  commits, which no read gives yet.
- **The file at the top is noted after every layout**, not only on a scroll: a
  restore or a first show reports no scroll, and left the sticky header and the
  lit row unset (UI review). The saved scroll is put back there too, a queued
  restore never running inside a test.
- **One Changes rotor walks every file's changed lines in list order**, the list
  scrolling to each so its file's view is built to read it; a file's own text
  offers none, two rotors of one name reading as a bug. In Split it walks the
  right side, as find does.
- **The sticky header takes no clicks while the next header pushes it up**: it
  reaches under the bar, where `.clipped()` hides it but leaves it hit-testable,
  so one click on Split also opened the file (owner's report).
- **Costs**: an image shows a notice with Open File, not both sides as the
  mockup drew; a mode-only change shows its unchanged rows folded with no mode
  note. Scrolling raises the footprint by about 300 MB of layer backing stores,
  released when it stops (debug build, 1,993 files, 2026-11-17); the owner once
  saw 1.5 GB, not reproduced, and put the work on hold.

## Reviewed and left as is

Review findings settled without a change, and why, are in
[all-changes-tab-reviewed.md](all-changes-tab-reviewed.md).
