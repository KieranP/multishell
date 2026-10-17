# The Files panel and file tabs

What the panel lists, what a file tab shows and why each went the way it did.
Newest at the bottom.

- **A panel beside the tab area, not a cover over it nor a list beside a diff.**
  A 400 pt diff was too cramped, and a cover hid the agent being reviewed.
- **One tab per file, its changes drawn inside it.** The user reads a file and
  its change as one thing, so there is no diff tab and no Show Diff button.
  Opening a file already open turns to its tab; there is no preview tab.
- **Uncommitted changes only.** Cost: what a branch committed since the trunk
  does not show; a scope for it could sit beside this one.
- **Read-only.** Editing is the editor's job, a click away in each menu.
- **The panel lists every file, and git says how each looks.** Tracked files
  come from the index, new ones from the status read's list, and what git
  ignores lists greyed. A folder git ignores whole is one entry, so
  `node_modules` costs a row, and it is listed from disk one level at a time as
  it opens. Cost: an empty folder is not listed, git never naming one.
- **What git ignores is read one at a time, the next waiting ten times the last
  one's cost and the listing rebuild it set off**, a second at least: an install
  or a build writes there constantly, and rebuilding after every read held half
  a core for a whole build. Capped at 50,000 entries, with no footer saying so
  past it. An opened ignored folder and an expanded submodule are each paced the
  same way, and a listing too large for a render builds one at a time, since a
  started build cannot be stopped.
- **The index, not `ls-files --cached --others`.** The second walks the tree
  again, 198 ms on Linux's 96,000 files against 27 ms, and prints untracked
  paths first, so a cap would let `node_modules` push tracked files out. Capped
  at 200,000 tracked paths, the footer saying so past it.
- **New files are counted whole and drawn up to 50,000.** A cap on what is
  counted would make the panel disagree with the badge; drawing is the cost. The
  footer names the rest.
- **One per-file list feeds the badge, its tooltip, the removal dialog, the
  command line and the panel**, for every worktree, panel open or not, so no two
  can disagree; worktrees.md has the read.
- **All / Modified, not a lettered toggle**, "M 4" not saying what it was. No
  count on the switch, the footer carrying it, and no status letters anywhere:
  the counts and the dot carry the change.
- **All or Modified is one choice for every worktree, kept with the settings**,
  as Unified or Split is, so a relaunch or another worktree lists what the last
  panel did. A click on a row's git badge sets it to Modified.
- **A zero side of a file's count is left out**, `+21 −0` on a new file reading
  as noise. The sidebar badge and the footer keep both, a badge changing shape
  having read as broken.
- **Modified merges single-child folders**, `Tests/AppCoreTests/Detail` one row,
  and starts open where All starts shut.
- **The filter folds as the sidebar's does**, over the whole path, matched as
  UTF-8 over paths folded and composed once: `contains` took 181 to 263 ms over
  200,000 paths, a byte search 7 to 11.
- **The panel is one switch for the window, shut at each launch, and its width
  is per machine**, kept as the sidebar's is. A switch kept across launches
  opened the panel with the first worktree, which read as a bug. The model holds
  the switch, so a click on a row's badge can open it. Double-clicking either
  edge resets its width. No keyboard shortcut yet; a View menu item.
- **Both clamps leave the tabs one minimum**, so a wide sidebar beside a wide
  panel cannot squeeze the tabs to nothing.
- **A click on a row's git badge opens the panel on Modified**, with a named
  accessibility action on the row, whose children VoiceOver cannot reach.
- **A file opens in a tab by the clicked-link rule**: a regular file typed as
  text or whose start reads as text. A file gone from disk is judged on git's
  copy. A link inside the worktree opens the file it points at, git diffing a
  link as the path it holds; one leading out, and anything else, beeps.
- **Copy Path copies the absolute path**, as the worktree's own does.
- **No drag out of the panel**, the app's drags carrying its own pasteboard
  types; a file URL would let Finder move the file.
- **The panel's worktree is read in the background while its window shows**, so
  coming back never shows a stale list. Other rows keep the frontmost-only
  reads.
- **The tree's listing is built again only when paths move**, not for a count,
  as an agent's every save moves one: 200,000 paths took 1.2 s. Past 20,000 it
  builds off the main actor, the last listing drawn meanwhile. Each path is
  folded once for the filter, which folding them all per keystroke made 0.9 s. A
  modified file's first edit moves no path, the index holding it. The changed
  paths' half is kept while only counts move too: 50,000 new files took 0.3 s
  per status read.
- **Only the panel's own worktree keeps its listing**, a Linux-sized one and its
  tree holding about 80 MB; coming back reads it again, with each open folder
  git does not list. A folder git stops ignoring drops what was read of it.
- **File tabs are a type of their own beside terminal tabs**, one order per
  group covering both. A tab holding a file would promise a pane tree it has not
  got.
- **The order is written into each group, and `tabs` kept in step**, so an older
  build reads its terminal tabs in the order this one drew them. It drops file
  tabs, under a key it ignores.
- **A file tab persists, its scroll saved at quit; its contents do not.** After
  a relaunch a deleted file's tab shows `HEAD`'s text removed, as opening it
  from the panel does, and the missing notice only where git never had the file.
- **A file tab never leaves its worktree**, a file belonging to the worktree it
  was opened in, so a drop on another row is refused and the row lights nothing.
- **A worktree holding only file tabs gets no automatic shell**, at launch or
  after.
- **The split buttons disable on a file tab rather than hide**: hiding them
  changed the strip's button width, and every tab resized on a switch.
- **No rename, and the tab is titled by the shortest trailing path that tells it
  from another open file of its name**: `models/user.rb` beside `lib/user.rb`.
- **A deleted file's tab stays, struck through, with the last text it read**,
  until the user closes it, as Zed does; a hidden tab whose file is gone keeps
  its rows for this.
- **A rename is a file gone and a file added**, renames being off everywhere, so
  the old path's tab becomes a deleted file's.
- **The tab shows the file on disk against `HEAD` whatever the indicator says**,
  staged changes drawn hollow in the gutter and unstaged filled, as Zed does.
  Neither Zed nor VS Code has a staged-only view. Cost: under Staged Only a
  tab's counts can differ from its row.
- **Staged lines are found by diffing the index too, with the same algorithm**,
  or one edit splits into different hunks and no line matches.
- **The tab's diff uses the badge's algorithm**, so the two count an edit alike.
- **A tab re-reads on its folder's events where its `lstat` moved, and on its
  project's git changes**, ahead of the frontmost and ignored-folder guards: the
  window is often beside the editor making the change, and a tracked file can
  sit forced in under an ignored folder. By directory, FSEvents' file flags
  lingering for seconds.
- **A hidden tab is owed its read until shown**, but a deletion strikes its
  title at once, the strip showing it.
- **A hidden tab lets go of its rows**, keeping its corner dot and strike, so
  content nobody sees holds no memory: a 1 MiB file's rows are several copies of
  its text. A read waiting for it is owed instead, the reads it would cost being
  for nothing. Shown again it is read at once, not at its pace. Cost: its body
  and bar's counts are blank until that read lands, and a file deleted after its
  tab was hidden shows `HEAD`'s text removed, or the missing notice where git
  never had it, as after a relaunch.
- **A 75 ms settle and a pace of ten times the last re-read's cost**, so a save
  shows in about a quarter second and an agent rewriting a file in bursts costs
  at most a tenth of a core. A change during a read reads once after it.
- **A file tab is capped at 1 MiB, on disk and in `HEAD`.** git diffs 1 MiB in
  under 40 ms, but the forced view takes up to 186 MB laid out at that size.
  `HEAD`'s size is asked first, so a small file whose last commit is huge never
  diffs into memory. A line is cut at 10,000 characters, a 1 MiB file being able
  to be one line.
- **Text is UTF-8, else the encoding a text editor would guess**, the open rule
  admitting any text-typed file; the diff is decoded the same way, git copying
  the file's bytes into it.
- **The view is TextKit 2 with every row's frame forced**, the user preferring
  Apple's current engine. Plain TextKit 2 estimates the height of rows it has
  not laid out: split sides drifted 787 to 3,435 rows apart and
  `scrollRangeToVisible` missed 10 of 10 targets. One override of
  `layoutFragmentFrame` made it exact.
- **That override is not a documented point**, so the drift tests lay out about
  10,750 rows and jump to the end first, then check the rows on screen at nine
  jumps, and the split's two offsets; they fail at once with it removed. TextKit
  1 with contiguous layout, exact too, is the fallback. Cost: up to 186 MB fully
  laid out at 1 MiB against TextKit 1's 30, which is why a hidden tab drops its
  layout. Its scroll is kept in the model by the file's line at the top, Unified
  and Split putting one line on different rows, taken back once the new view has
  a size, and saved with the tab at quit: written on each scroll, the workspace
  would save and redraw dozens of times a second. A crash loses what moved since
  the last quit.
- **A file tab has its own font and size**, in Settings > Appearance beside the
  terminal's, not the UI size less one: code read at the UI's size was too small
  for some and too large for others. A change rebuilds the view, the rows'
  geometry being built from the font.
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
  text, every run of spaces and newlines one token, so a rewrap's moved words
  and breaks still match; pairing line with line marked a rewrapped paragraph
  nowhere. A run sharing under half of its shorter side is a rewrite and marked
  nowhere, judged on the shorter so a line edited with new lines after it is
  still an edit. A line changed whole keeps only its tint. A run too costly to
  diff whole, a few hundred rewritten lines, is paired line with line instead.
- **The gutter is a plain view, not `NSRulerView`**, which on macOS 26 drew into
  a view as tall as the document and went stale across programmatic scrolls.
- **The file view clips to its frame.** Views no longer clip by default, and
  TextKit 2 asks for a background over more than the view shows: unclipped, it
  painted over the header, the tab strip and the bar.
- **A selection touching a change copies as `git diff` prints it**; a split side
  copies plain text. Copy, a drag and Services share one override.
- **Find is the app's own floating bar**, appearance.md having ruled out a find
  strip; a file tab is searched in the model, the engine searching only panes.
- **Find's matches are painted under the text with the line tints**, not as
  TextKit 2 rendering attributes, which marked none of its line views for
  drawing: a search typed into the bar showed its matches only at the next
  scroll.
- **Only a new find text or a step moves the selection**, counted in the model:
  a re-read keeps the nearest match, but matches found above it shift its index.
  A layout switch carries the selected match by the file's line, not its text:
  Unified's removed rows shift where repeated lines sit. A rebuilt view selects
  the match but returns to its saved scroll, which the user may have moved off
  the match, unless a search or step came since it was last drawn.
- **A Changes rotor walks the changed lines**, the text's attributes carrying no
  sign of an addition.
- **A file tab's memory is labelled in Debug Info**, estimated from the text it
  keeps, rather than left in the app's row.
- **Split is offset-locked**, the same offset being the same row on both sides
  under the forced geometry; a lock by row left the scrollers thousands of
  points apart.
- **Unified or Split is one choice for every tab, kept with the settings**, so
  the next file opens as the last was read. A file only added to or only removed
  from stays Unified and offers no switch: one side would be blank.
- **Highlighting is tree-sitter through SwiftTreeSitter, with a small runner of
  our own, not Neon**: the view is read-only, so a whole-file parse and one
  query is all it needs. Two parses, the file on disk and `HEAD`'s text, each
  side's ranges mapped onto its rows. About 54 ms for 5,000 lines of Swift, off
  the main thread. The spans become runs in text order there too: applied in
  pattern order, 202,607 of a 1 MiB file took 1.2 s on the main thread, the runs
  70 ms.
- **Roles, not colours**: each capture is a role, each role a `file` key, so a
  theme recolours highlighting without knowing the grammars. `spell` is a spell
  checker's mark and colours nothing, and `constructor` is Swift's `init` but a
  class name elsewhere.
- **The later pattern wins where one range carries several captures**, which is
  how every query in the set is written.
- **Each grammar is its own Swift package, pinned exactly; its query ships in
  that package's resource bundle.** JavaScript's, Python's and YAML's packages
  build without their scanners, so those three scanners, with what they include,
  are copied under `ThirdParty/tree-sitter/`.
- **The maintained repository over the most-starred one**, for YAML, TOML, Zig
  and Make, whose originals are archived or years stale.
- **A language is picked by extension, then by name where the extension says
  nothing, then by shebang.** `Rakefile` and `Gemfile` are Ruby by name, and
  `Cargo.lock` TOML, `Package.resolved`, `.prettierrc` and `.swift-format` JSON.
  The shebang is the file on disk's, which a unified diff lists after `HEAD`'s
  first line.
- **A submodule's folder opens as a repository of its own**, listed and read
  apart, since the worktree's git lists the folder and nothing in it. Its rows
  carry their own counts but stay out of the worktree's Modified, which is what
  the worktree would commit, and a file tab inside it diffs against the
  submodule's `HEAD`. One nobody has initialised lists empty: `git -C` there
  runs against the parent, so `rev-parse --show-toplevel` must name the folder.
- **A new file git ignores shows as it is**, not every line added: the badge and
  the panel count it as no change.
- **Find in a split searches its right side**, the file on disk, the left being
  what the file was.
- **A saved file tab whose path leaves its worktree is dropped on load**, as is
  one whose id another tab holds or whose path another tab shows: a hand edit
  could otherwise point a tab anywhere.
