# File tabs

What a file tab shows and why each went the way it did. Newest at the bottom.

- **One tab per file, its changes drawn inside it.** The user reads a file and
  its change as one thing, so there is no diff tab and no Show Diff button, bar
  the All changes tab, a whole worktree's review (files/all-changes-tab.md).
  There is no preview tab.
- **Read-only.** Editing is the editor's job, a click away in each menu.
- **A file opens in a tab by the clicked-link rule**, or as an image
  (files/image-tabs.md). A file gone from disk is judged on git's copy. A link
  inside the worktree opens the file it points at, git diffing a link as the
  path it holds; one leading out beeps.
- **File tabs are a type of their own beside terminal tabs**, one order per
  group covering every kind. A tab holding a file would promise a pane tree it
  has not got.
- **The order is written into each group, and `tabs` kept in step**, so an older
  build reads its terminal tabs in the order this one drew them. It drops file
  tabs, saved under a key it ignores.
- **A file tab persists, its scroll saved at quit; its contents do not.**
- **A file tab never leaves its worktree**, a file belonging to the worktree it
  was opened in, so a drop on another row is refused.
- **The split buttons disable on a file or All changes tab rather than hide**:
  hiding them changed the strip's button width, and every tab resized on a
  switch.
- **A deleted file's tab stays, struck through, with the last text it read**,
  until the user closes it, as Zed does; a hidden tab whose file is gone keeps
  its rows for this.
- **A rename is a file gone and a file added**, renames being off everywhere. A
  case-only rename too, though the disk ignores case and opens the new spelling
  for the old: where git calls the path deleted and the disk spells it
  otherwise, it is gone. A rename git never saw, Finder's, still tracks the old
  spelling, and shows the file.
- **The tab shows the file on disk against `HEAD` under Modified, whatever the
  indicator says**, staged changes drawn hollow in the gutter and unstaged
  filled, as Zed does. Neither Zed nor VS Code has a staged-only view. Cost:
  under Staged Only a tab's counts can differ from its row.
- **Staged lines are found by diffing the index too, with the same algorithm**,
  or one edit splits into different hunks and no line matches.
- **The tab's diff uses the badge's algorithm**, so the two count an edit alike.
- **A tab re-reads on its folder's events where its `lstat` moved, and on its
  project's git changes**, ahead of the frontmost and ignored-folder guards: the
  window is often beside the editor making the change, and a tracked file can
  sit forced in under an ignored folder. By directory, FSEvents' file flags
  lingering for seconds; a folder above the tab counts too, as a folder moved or
  trashed is heard only at its parent. A folder in the file's place is gone.
- **A tab in an embedded repository re-reads on that repository's git**, a
  vendored clone or a submodule never absorbed: its `.git` is no project's, and
  a commit there left the tab's lines marked uncommitted until the file moved.
- **A hidden tab lets go of its rows and is owed its read**, keeping its dot and
  strike, so content nobody sees holds no memory: a 1 MiB file's rows are
  several copies of its text. A covered or minimized window's shown tabs are
  owed theirs too. Shown again it is read at once, not at its pace. Cost: its
  body and bar's counts are blank until that read lands, and a file deleted
  after its tab was hidden shows `HEAD`'s text removed, as after a relaunch.
- **A 75 ms settle and a pace of ten times the last re-read's cost**, so a save
  shows in about a quarter second and an agent rewriting a file in bursts costs
  at most a tenth of a core. A change during a read reads once after it.
- **A read running as the scope, algorithm or base changes is thrown away**, and
  the next runs at once: it landed the old diff under the new switch and paced
  the right read out by ten times its own cost.
- **A file tab is capped at 1 MiB, on disk and on its committed side.** git
  diffs 1 MiB in under 40 ms, but the forced view takes up to 186 MB laid out at
  that size. That side's size is asked first, so a small file whose last commit
  is huge never diffs into memory. A line is cut at 10,000 characters, a 1 MiB
  file being able to be one line. Copy takes it whole: the cut text and its mark
  went on the pasteboard. So does the highlighter: a comment or string open at
  the cut coloured every row below it.
- **Text is UTF-8, else the encoding a text editor would guess**, the open rule
  admitting any text-typed file; git copies the file's bytes into the diff, so
  it is decoded the same way.
- **The view is TextKit 2 with every row's frame forced**, the user preferring
  Apple's current engine. Plain TextKit 2 estimates the height of rows it has
  not laid out: split sides drifted 787 to 3,435 rows apart and
  `scrollRangeToVisible` missed 10 of 10 targets. One override of
  `layoutFragmentFrame` made it exact.
- **That override is not a documented point**, so the drift tests fail at once
  with it removed. TextKit 1 with contiguous layout, exact too, is the fallback.
  Cost: up to 186 MB fully laid out at 1 MiB against TextKit 1's 30, which is
  why a hidden tab drops its layout. Its scroll is kept in the model by the
  file's line at the top, Unified and Split putting one line on different rows,
  and saved with the tab at quit: written on each scroll, the workspace would
  save and redraw dozens of times a second. A crash loses what moved since the
  last quit.
- **A file tab has its own font and size**, in Settings > Appearance, not the UI
  size less one: code read at the UI's size was too small for some and too large
  for others.
- **The rows the geometry puts in view are laid out before TextKit looks for its
  top row.** It finds that row by its own estimate and lays out every row
  between there and the forced one: a jump to the middle of a 1 MiB file took
  170 ms, against 24 ms for stock TextKit 2, and takes 24 ms with this.
- **No soft wrap**, split rows holding one height only where neither side wraps.
- **The tints are painted behind the text, edge to edge.** The base themes take
  Claude Code's diff colours, so a diff reads the same in a file tab as in the
  agent beside it: its dark terminal theme's, and the light ones sampled from
  its diff view. Cost: on the dark base, green strings on the added green lose
  contrast, which lighter tints once avoided.
- **The words a changed line differs in are painted darker over its tint.** A
  run of removed lines and the added run after it are diffed by word as one
  text, whitespace runs one token, so a rewrap's moved words and breaks still
  match; pairing line with line marked a rewrapped paragraph nowhere. A run
  sharing under half of its shorter side is a rewrite and marked nowhere, judged
  on the shorter so a line edited with new lines after it is still an edit. A
  run too costly to diff whole, a few hundred rewritten lines, is paired line
  with line instead.
- **The gutter is a plain view, not `NSRulerView`**, which on macOS 26 drew into
  a view as tall as the document and went stale across programmatic scrolls.
- **The file view clips to its frame.** Views no longer clip by default, and
  TextKit 2 asks for a background over more than the view shows: unclipped, it
  painted over the header, the tab strip and the bar.
- **A selection holding removed and added lines copies as `git diff` prints
  it**, whole lines with their marks (owner, 2026-11-20). Any other selection,
  one changed line or one side with its context, copies as selected, as does a
  split side.
- **Find is the app's own floating bar**, appearance/window-chrome.md having
  ruled out a find strip; a file tab is searched in the model, the engine
  searching only panes.
- **Find compares bytes where the find text and the file are both ASCII**, and
  asks `NSString` only otherwise, for case and composed forms past ASCII. One
  `NSString` search per match took 24 to 30 ms in release for a first letter or
  a space in a 1 MiB file, on every keystroke; the byte pass takes 2 ms.
- **That pass is one walk of the folded bytes** (Knuth-Morris-Pratt), matches
  kept leftmost and apart as `NSString` returns them. Comparing the find text at
  each start was text times find text: 10,000 `=` and an `x` over 1 MiB of `=`
  ran past a minute in debug per keystroke.
- **Find's matches are painted under the text with the line tints**, not as
  TextKit 2 rendering attributes, which marked none of its line views for
  drawing: a search typed into the bar showed its matches only at the next
  scroll.
- **Only a new find text or a step moves the selection**: a re-read keeps the
  nearest match. A layout switch carries the selected match by the file's line,
  not its text, Unified's removed rows shifting where repeated lines sit. A
  rebuilt view returns to its saved scroll, which the user may have moved off
  the match, unless a search or step came since it was last drawn.
- **A Changes rotor walks the changed lines**, the text's attributes carrying no
  sign of an addition.
- **A file tab's memory is labelled in Debug Info**, estimated from the text and
  image bytes it keeps (debug-tools.md).
- **Unified and Split are one scroller over a canvas**, so all of it scrolls
  natively and nothing is kept in step. Split's two columns had two scrollers
  locked by offset: the lock pulled one back where the other clamped, a wheel
  over the left had to be forwarded, and every view laid over both was moved on
  each scroll. Both columns scroll sideways together (owner's pick).
  `NSTextView` scrolls nothing on a canvas, not being the scroller's document,
  so the column brings a range into view itself.
- **Unified or Split is one choice for every tab, kept with the settings**, so
  the next file opens as the last was read. A file only added to or only removed
  from stays Unified and offers no switch: one side would be blank.
- **A new file git ignores shows as it is**, not every line added: the badge and
  the panel count it as no change.
- **Find in a split searches its right side**, the file on disk, the left being
  what the file was.
- **A saved file tab whose path leaves its worktree is dropped on load**, as is
  one whose id another tab holds or whose path another tab shows: a hand edit
  could otherwise point a tab anywhere.
- **Arrows in a file tab's bar step from change to change.** A change is a run
  of rows other than context, a split side's padding included, so a removal is a
  stop in either layout. A step counts from the selection where it is in view
  and from the first row in view otherwise, as an editor counts from its cursor:
  a scroll by hand then a step lands below what was read, not back at the top. A
  split steps from the side holding the keyboard, a step from the right having
  ignored a click on the left.
- **A bar too narrow for its switches puts them in one menu**, the name, counts
  and arrows staying. The folder crumb is left out of the fit, so a deep path
  never moves the switches into the menu. Picked over glyph-only switches, whose
  Split drew as the strip's Split Right, and over a second row costing the file
  30 pt (mockups, 2026-11-05).
- **The bar is never wider than its group.** Its switches could not shrink, so
  two groups in an 1100 pt window drew it 60 pt wider than its group and the
  whole file view spilled left over the next group's terminal (FileTabBarTests).
  A bar too narrow even with its switches in the menu is cut at its right edge,
  the actions menu going first.
- **Steps stop at either end and the arrow with nowhere to go greys out**, the
  user's choice over wrapping as find does. The change starts are kept with the
  rows, so telling which ways are open is a halving per scroll, not a walk of
  the file.
- **The change a step lands on is boxed** until the caret leaves it, so with
  several in view the box shows which one the next step counts from. Rows differ
  between Unified and Split and a hidden tab lets its rows go, so it is held by
  the `HEAD` lines it replaces, or for a change only adding lines the gap it
  fills, `HEAD`'s numbering moving with no edit. A change still sharing one of
  those lines or spanning that gap is the same change, the one sharing most
  where several do. Only a commit or checkout moves `HEAD`'s numbering, told by
  `HEAD`'s text, hashed whole, no longer matching: the line above alone read the
  same after a renumbering wherever it was blank or `}`. Only then, never on a
  plain miss, is it the change under the same unchanged line holding a letter or
  digit, nearest its place: `}` or a blank line repeats across a file and sent
  the box hundreds of lines away. Where neither finds it the box is let go, a
  lost box costing one press and a wrong one moving the caret off screen. A
  rebuilt view keeps the box over a find match outside it, the box being the
  newer. It is the file's text colour softened, not a theme key, every theme's
  text reading against both tints.
- **The caret a file opens with counts as no selection**, so a step down from
  there lands on a change on the first row: a new or deleted file is one change
  from row 0, and counting from that caret left both arrows grey.
- **A row's fragment counts the gap under it in its height**, so TextKit's sum
  of heights, which it finds a scroll's top by, agrees with the geometry; the
  All changes tab's dense gaps left it laying out rows far from the clip
  (files/all-changes-tab.md).
- **The step buttons are chevrons**, as the All changes mockup drew them, in a
  file tab's bar and the All changes bar alike (owner's pick, 2026-11-17).
- **A link leading out is judged on every link along the path, not only the
  last**: a file under a folder link in an ignored folder opened in a tab from
  outside the worktree. Foundation resolves nothing in a path that is not there,
  so a gone file is resolved through the deepest part still on disk.
- **Every read of a worktree file passes the same link check, not only the
  open**: a folder swapped for a link out after a tab opened, or before a
  restore, rendered the outside file as context rows, git listing the tracked
  file deleted and its patch headers only. A path leading out reads as gone, as
  git sees it. The check and the read are two steps; a swap between them still
  reads once.
- **Each part of the path is checked as a link, a dangling one included**
  (lstat, then `realpath`): a test for existence follows links, so a folder link
  to nothing was climbed over unresolved and accepted. Paths compare as
  `realpath` gives them, standardizing dropping `/private` only from a path on
  disk.

## Reviewed and left as is

- **`Asker` is threaded down to the beep and the keyboard**, rather than a
  click's wrapper beeping on a `nil`: the file opens a turn later, past the
  wrapper, and one name for who asked reads plainer than a beep flag beside a
  focus flag.
- **A file open's listing is dropped by its callers**, not inside
  `openFileAsTab`: the switcher's open drops it only once the cover it was
  chosen over has come down, so the panel that cover hid keeps the one it shows.
- **A tab read through a git change records no signature** (2026-11-12), so the
  next change in its folder reads it once more. Recording one after the read
  could hide an edit made between the read and the stat.
