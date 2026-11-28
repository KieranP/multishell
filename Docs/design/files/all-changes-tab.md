# The All changes tab

One scrolling diff of every change in a worktree, with review comments on its
lines (issue #42, owner's picks of 2026-11-14 from the mockups). Newest at the
bottom.

- **The exception to "no diff tab"** (files/file-tabs.md). Reviewing what an
  agent did across twenty files meant twenty tabs stepped through one by one.
  This tab is that review; the file tab stays as it was.
- **A third tab kind, not a file tab holding many paths.** A file tab's path,
  title, strike and dot each assume one file. A case on `WorkspaceTab` makes
  every switch on the kind a compile error until it says what the tab does.
- **At most one a worktree**, never leaving it, as a file tab does not.
- **Saved under a key of its own, read lossily**, so an older build drops it as
  it drops file tabs.
- **A click on a Changes row shows this tab at that file** (owner's ask),
  opening it if closed and expanding the file if collapsed, rather than the
  file's tab; the Files page, the quick switcher and `tabs open-file` still open
  the file's tab.
- **The row of the file at the top is lit in Changes.** A clicked row stays lit
  while the view stays where the click left it: a file near the end cannot reach
  the top, and the click otherwise seemed to do nothing (owner's report). The
  file at the top is the one whose box's top sits at or above the clip's top;
  mapped from the row there, a file with no rows of its own lit the next file
  (owner's report).
- **The files are the Changes list's, in its order.** A folder listed as a
  change, a submodule or a nested repository, is left out as the list leaves it,
  found by `lstat` since the index read that marks submodules is the panel's
  alone. A deleted file a folder of its name replaced stays, as the list has it.
- **A shown tab under Branch asks for its worktree's Branch read**, the one the
  panel makes, rather than a second way of reading git.
- **Each file is read by the file tab's reader, with its cap**, so a file reads
  the same in both. A read asks git once, not once a file, for the merge base,
  `HEAD`, the committed sizes, the ignored files and the index, and diffs files
  forty a run, several runs at once. A diff header git quotes, a name with a tab
  or quote, sends that run's files to their own runs. 300 modified files went
  from 3.3 s to 0.08 s, this repository's 222 branch files from 0.45 s to 0.19
  s.
- **One read log a tab, paced by the files the next read reads**: ten times a
  file's share of the last read's cost, times the files owed. Paced by the whole
  read, as a file tab is, a first read of 1,802 files held the next for minutes,
  so files the status listed since waited that long to show. A read reads only
  what moved, as each file tab would; the rest keep their rows.
- **A hidden tab lets go of its rows and is owed its read**, as a file tab is.
- **The tab holds at most 200,000 rows across its files**; past that a file
  shows its header and an Open File button. Measured with the debug build over a
  copy of this repository's sources, every one of 1,802 Swift files changed by a
  line and 191 more added: 191 MB in all against 78 MB with the tab shut, 13 MB
  of it the rows held (82,895 lines). The cap stays as a guard now that only
  files near the screen are read.
- **Only the files near the screen are read**, as the owner asked. A file read
  once keeps its rows: one a change outdates away from the screen keeps them
  stale until the list nears it (review round 3; dropped to Reading, a git
  commit emptied the tab).
- **Only the files near the clip are built**, each a view of its own, and let go
  of as they leave: hosting every header and fold of 1,802 files took the app to
  1.43 GB, a SwiftUI hosting view and its surface each costing a few hundred
  kilobytes. A few views of each kind are kept for the next file: building one a
  file scrolled to cost 150 MB while scrolling (owner's report).
- **A list of files, each its own view** (owner's pick, replacing one text for
  every file). One text had stacked headers into gaps, needed a separate layer
  for Split's full-width files and mapped the top row to a file, and each
  brought a bug. The document still joins the files' rows, as the address find,
  the step buttons, the saved scroll and comments use.
- **Each row's fragment reports its row and the gap under it as its height.**
  TextKit finds a scroll's top by summing fragment heights; with a gap every few
  rows, as the one text's headers were, its sum fell thousands of rows short of
  the forced geometry and the rows on screen were left blank. Card gaps are
  sparse enough that the file tab never showed it
  (`theRowsOnScreenAreInTextKitsViewportWithAGapEverySixRows`).
- **The gap above the first row starts TextKit's container**, not a row's
  height. A tall gap there is counted by no fragment, and TextKit left the first
  rows blank (owner's report;
  `theFirstRowsAreLaidOutUnderATallGapAboveTheFirstRow`).
- **Three lines of context around each change, as `git diff` keeps.** An
  unchanged run shorter than four lines shows whole, its fold row saving little.
- **A fold's click shows every line it held.** The mockup opened a few at the
  top of a large file and offered Open file for the rest; the simplest rule was
  taken and the owner kept it. Opened folds are kept for the run by the file on
  disk's line numbers, so a re-read keeps them.
- **A collapsed file is kept for the run only**, by tab and path; the owner did
  not need it kept across launches. The bar's chevron pair collapses or expands
  every file (owner's ask).
- **The change letter's square, and a lit button on a header or card, sit on the
  fill drawn again**, a shade up where the theme's fill is translucent. Eight of
  the twelve built-in themes have an opaque fill, which drawn twice reads as
  none, so those draw the selection colour instead (`ChipOnFill`).
- **The header of the file at the top is held over the text** once its own has
  scrolled past (owner's report). It takes no clicks while the next header
  pushes it up: it reaches under the bar, where `.clipped()` hides it but leaves
  it hit-testable, so one click on Split also opened the file (owner's report).
- **Each file is highlighted as its view is built**, parsed over its own rows, a
  folded slice parsing wrong. The parse is kept by path, so a fold opening or a
  scroll back parses nothing again; parsing every file of a large worktree on
  each read held a core for tens of seconds.
- **The bar's step buttons go across files**: every change of every file is a
  stop, ordered by where it starts in the list. A step counts from the boxed
  change while it is in view and from the clip's top otherwise, as a file tab
  counts from its caret: a box left behind by a scroll sent the next step back
  to it.
- **A switch between Unified and Split keeps the line at the top**, as a file
  tab does: the offset into the file it kept before landed later files at the
  top, a Split file being shorter.
- **A selection stays within one file**, each file being its own text. Copy
  across files was not wanted (owner).
- **Find searches the rows shown**: folded and collapsed lines are not searched,
  the file tab having them all. In Split it searches the right side, the file on
  disk, so a deleted file is not searched. A match running on into the next file
  is dropped: selecting it overran the first file's text view.
- **The scroll is saved by the file at the top and its line there**, so files
  coming or going above, or folds opening, return to the same line. It is put
  back by the built file's own row geometry, folds included; by row height alone
  each return crept up by the folds above (owner's report).
- **Review cards are the file tab's**, through one set of tables keyed by
  `ReviewTabID`, so a comment written in either view shows in both and one Send
  carries them all.
- **Cards are placed per file against that file's own rows**, then moved to the
  document's: placing over the document's rows put one file's card on another's
  line of the same number.
- **A drag or Comment on Lines stops at the file's last row and at a fold**, as
  the owner picked: a comment never spans two files or quotes lines it hid. To
  comment on them, open the fold first.
- **A comment holds its lines and two either side open inside a fold**, as the
  owner picked; a comment's lines are always on screen to place its card under.
  Lines past the file's end hold its last line, where the card sits; held as
  given, they held no row and the card was lost.
- **A comment picked in Review is revealed here where a group shows it**,
  following the mockup rather than an explicit pick. A comment on a file still
  unread scrolls to that file and shows once it is read; taken at once, the
  reveal found no card and was lost (owner's report).
- **`review add` quotes only through a file tab** (owner's pick), never this
  one.
- **In Split a file all added or all removed shows full width** (owner's pick).
  Its rows still lie row for row in the split's sides, padding opposite, so
  find, the step buttons and the saved scroll address it as any other file.
- **A step onto a file still to be read lands on its header** (owner's pick): it
  is then near the screen and read, and the next step goes into its changes.
  Steps over read files alone greyed the buttons out at the last one.
- **The look follows the owner's mockups**: each file a box with a margin either
  side, the 17 pt scroller in the right margin, a fold's label starting where
  the code does, folds flush with the box, the sticky header keeping the box's
  rounded top, and Split's divider running down each file's diff.
- **Cmd+Up and Cmd+Down reach the list's ends from any file**: a file view let
  go of with its text focused hands the focus to the list, or the keys beeped
  (owner's report).
- **A file's diff scrolls sideways on its own** (owner's ask), and a trackpad
  gesture keeps the axis its first moving frame chose, momentum included
  (`WheelAxisLock`): chosen a frame at a time, a sideways swipe leaning vertical
  for a frame went to the list mid-swipe (owner's report).
- **The step buttons' enabled state places the first and last change alone**,
  the list's order being the document's: placing every change on each scroll
  took two thirds of a scroll step over 2,000 files.
- **Debug Info counts the tab with the file tabs**: each file's rows and the
  document joined from them, not the layout.
- **`tabs step` and `tabs find` reach the tab** as they reach a file tab, the
  document being rows whatever its files hold.
- **With nothing to show, the tab says why as the mockup drew it**, bar the
  mockup's count of the branch's commits, which no read gives yet.
- **The file at the top is noted after every layout**, not only on a scroll: a
  restore or a first show reports no scroll, and left the sticky header and the
  lit row unset (UI review). The saved scroll is put back there too, a queued
  restore never running inside a test.
- **One Changes rotor walks every file's changed lines in list order**; a file's
  own text offers none, two rotors of one name reading as a bug.
- **Costs**: an image shows a notice with Open File, not both sides as the
  mockup drew; a mode-only change shows its unchanged rows folded with no mode
  note. Scrolling raises the footprint by about 300 MB of layer backing stores,
  released when it stops (debug build, 1,993 files, 2026-11-17); the owner once
  saw 1.5 GB, not reproduced, and put the work on hold.

## Reviewed and left as is

Review findings settled without a change, and why, are in
[all-changes-tab-reviewed.md](all-changes-tab-reviewed.md).
