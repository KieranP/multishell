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
  opening it if closed, rather than the file's tab; the Files page, the quick
  switcher and `tabs open-file` still open the file's tab. Each file's header
  has a button that does.
- **The row of the file at the top of the tab is lit in Changes** while the tab
  is in front, the view reporting the file at its clip's top as it scrolls. A
  clicked row lights at once and stays lit while the view stays where the click
  left it: a file near the end cannot reach the top, and the click otherwise
  seemed to do nothing (owner's report).
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
  the same in both. Four at a time, each read being its own git run.
- **One read log a tab, paced by the files the next read reads**: ten times a
  file's share of the last read's cost, the highlight's included, times the
  files owed. Paced by the whole read, as a file tab is, a first read of 1,802
  files held the next for minutes, so files the status listed since waited that
  long to show. A read reads only what moved: a git change in the project or an
  embedded repository reads every file, as each file tab would; an event in a
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
  the tab shut, 13 MB of it the rows held (82,895 lines). The layout is the
  viewport's alone, so the cap bounds the rows held, not the layout. The owner's
  goal is memory that tracks the screen, rows read as they near it; until then
  the cap stays as a guard.
- **Only the headers, folds and notices near the clip are hosted**, and moved as
  it scrolls: hosting all 3,600 of those 1,802 files took the app to 1.43 GB, a
  SwiftUI hosting view and its surface each costing a few hundred kilobytes.
- **One document, not a stack of file views.** The files' shown rows are one
  text with a map from each row to its file and that file's own row; headers,
  folds and notices are hosted views in row gaps, as review cards are, so find,
  copy, the Changes rotor and the drift tests still see rows only. A stack of
  file views would nest scrollers and lose Split's offset lock. The first file's
  header is a gap under row -1, which the gaps' sums take as they are.
- **Each row's fragment reports its row and the gap under it as its height.**
  TextKit finds a scroll's top by summing fragment heights; with a header every
  few rows its sum fell thousands of rows short of the forced geometry, and it
  laid out rows far below the clip, leaving the rows on screen blank. Card gaps
  are sparse enough that the file tab never showed it
  (`theRowsOnScreenAreInTextKitsViewportWithAGapEverySixRows`).
- **The gap above the first row starts TextKit's container**, not a row's
  height. Files collapsed above the first expanded one stack their headers
  there, which no fragment counted, and TextKit left the first rows blank
  (owner's report; `theFirstRowsAreLaidOutUnderATallGapAboveTheFirstRow`).
- **Each file is a box with a margin either side, as the mockups drew it**: a
  border-only layer from under its header to the next, which has no backing
  store and so may be as tall as the file. The vertical scroller sits in the
  right margin, outside the boxes: a hosted header lies over a scroller under
  it, whatever their order (owner's report).
- **Three lines of context around each change, as `git diff` keeps.** An
  unchanged run shorter than four lines shows whole, its fold row saving little.
- **A fold's click shows every line it held.** The mockup opened a few at the
  top of a large file and offered Open file for the rest; the simplest rule was
  taken and the owner kept it. Opened folds are
  kept for the run by the file on disk's line numbers, so a re-read keeps them.
- **A collapsed file keeps its header, counts and comment badge**, and is kept
  for the run only, by tab and path; the owner did not need it kept across
  launches.
- **The header of the file at the top is held over the text** once its own has
  scrolled past: an overlay worked out from the clip's offset, not a view inside
  the scroller.
- **Highlighting parses each file over its own rows**, a folded slice parsing
  wrong, and maps the spans onto the rows shown. Spans are kept by path, so a
  fold opening or a file collapsing parses nothing again.
- **Only the files a clip either side of the view reaches are highlighted**, as
  the owner asked, more as it scrolls; parsing every file of a large worktree on
  each read held a core for tens of seconds.
- **The bar's arrows step across files.** Each file's first row starts a change
  whatever is above it, so a file ending on a change and the next starting on
  one are two steps. The boxed change is held by its file's path and that file's
  own anchor, so folds opening or files above going keep the box on it.
- **A selection in one file copies as its file tab copies it**; one across files
  prints each file's part under `git diff`'s `diff --git`, `---` and `+++`
  lines, without `@@` lines, the file tab's copy having none.
- **Find searches the rows shown.** Folded and collapsed lines are not searched;
  the file tab has them all.
- **The scroll is saved by the file at the top and its line there**, so files
  coming or going above, or folds opening, return to the same line.
- **Review cards are the file tab's**: the same cards, composer, gutter + and
  drag, Comment on Lines, chips and Review rows, through one set of tables keyed
  by `ReviewTabID`, the id of a tab hosting cards. A comment written in either
  view shows in both, and one Send carries them all.
- **Cards are placed per file against that file's own rows**, then moved to the
  document's: placing over the document's rows put one file's card on another's
  line of the same number.
- **The composer carries its file's path**; a drag or Comment on Lines reads the
  rows as the file of the row it started on, stopping at that file's last row.
- **Each read re-anchors the comments of every file whose rows moved**, and the
  composer where it is on that file, as a file tab's read does.
- **A comment holds its lines and two either side open inside a fold**, as the
  owner picked; a comment's lines are always on screen to place its card under.
- **The tab's badge counts every comment to send in its worktree.**
- **Closing the tab asks first while its composer holds text**, as a file tab's
  close does.
- **A comment picked in Review is revealed in the All changes tab where a group
  shows it**, its file expanded if collapsed, and otherwise in its file's tab as
  before. This follows the mockup, not an explicit pick.
- **`review add` quotes through a file tab showing the path, else the shown All
  changes tab.** Which it should prefer where both show the path is open.
- **Modified/Branch and Unified/Split are the one choice every file tab and
  Changes follow.** Where the project has no base branch the tab counts from
  `HEAD` and offers no scope switch, as a file tab does.
- **Split lays each file's two sides row for row**, as its file tab's split
  does, and folds only rows unchanged on both.
- **In Split a file all added or all removed shows full width** (owner's pick):
  no rows in either column, but a Unified view of the file in a gap across both,
  as tall as its rows and its cards, its gutter as wide as the left column's
  and its first row under its header, as in Unified. It is hosted only while near the clip, as
  tall as the part on screen and scrolled within to follow the columns, so a
  long new file lays out what shows. Find, the arrows and the Changes rotor do
  not reach its rows, which are in neither column's text.
- **In Split the columns' divider runs only over the files**, from the first
  file's box to the last's end.
- **In Split the headers, folds and notices sit in a layer over both columns**,
  their gaps opened in each, laid out as the lock scrolls them, and stop short
  of the right column's scroller. A wheel over one turns the right column, which
  the lock follows.
- **Debug Info counts the tab with the file tabs**: each file's rows and the
  document joined from them, not the layout.
- **`tabs step` and `tabs find` reach the tab** as they reach a file tab, the
  document being rows whatever its files hold.
- **Costs**: an image shows a notice with Open File, not both sides as the
  mockup drew; a mode-only change shows its unchanged rows folded with no mode
  note.

## Reviewed and left as is
