# The Files panel

What the panel lists and why each went the way it did. Newest at the bottom.

- **A panel beside the tab area, not a cover over it nor a list beside a diff.**
  A 400 pt diff was too cramped, and a cover hid the agent being reviewed.
- **Uncommitted changes, and since the base branch**: see
  files/modified-and-branch.md.
- **The panel lists every file, and git says how each looks**, what it ignores
  greyed, in Files alone. A folder git ignores whole is one entry, so
  `node_modules` costs a row, listed from disk one level at a time as it opens.
  Cost: an empty folder is not listed, git never naming one.
- **What git ignores is read one at a time, the next waiting ten times the last
  one's cost and the listing rebuild it set off**, a second at least: an install
  or a build writes there constantly, and rebuilding after every read held half
  a core for a whole build. Capped at 50,000 entries, with no footer saying so
  past it. A listing too large for a render builds one at a time, since a
  started build cannot be stopped.
- **The index, not `ls-files --cached --others`.** The second walks the tree
  again, 198 ms on Linux's 96,000 files against 27 ms, and prints untracked
  paths first, so a cap would let `node_modules` push tracked files out. Capped
  at 200,000 tracked paths, the footer saying so past it.
- **A file replaced by a folder of its name lists both rows** until the change
  is committed. One node took both, the file's row and its diff went, and its
  change marked the folder.
- **New files are counted whole and drawn up to 50,000.** A cap on what is
  counted would make the panel disagree with the badge; drawing is the cost.
- **One per-file list feeds the badge, its tooltip, the removal dialog, the
  command line and the panel**, for every worktree, so no two can disagree;
  worktrees/line-count-badge.md has the read.
- **Glyph tabs named in a tooltip, not a lettered toggle**, "M 4" not saying
  what it was. Changes is a document with a diff: a branch glyph beside the pull
  request's arrow read as two of the same. The tooltip is drawn in the theme,
  `.help`'s being the system's grey. No count on the switch, the footer carrying
  it, and no status letters anywhere: the counts and the dot carry the change.
- **Files or Changes is one choice for every worktree, kept with the settings**
  under the `all` and `modified` keys earlier builds wrote, so an older build
  still reads it. The command line says `files` and `git`, `modified` being a
  scope.
- **A zero side of a file's count is left out**, `+21 −0` on a new file reading
  as noise. The sidebar badge and the footer keep both, a badge changing shape
  having read as broken.
- **The filter folds as the sidebar's does**, matched as UTF-8 over paths folded
  and composed once: `contains` took 181 to 263 ms over 200,000 paths, a byte
  search 7 to 11.
- **The panel is one switch for the window, kept across launches, and its width
  is per machine.** It was once shut at each launch, then opening with the first
  worktree read as a bug; a launch now selects nothing, and a panel closed at
  every launch read as forgotten. Close Find moved to Cmd+Option+F to free
  Cmd+Shift+F for Files Pane.
- **Double-clicking either edge fits its column to its rows**, laid out off
  screen at their ideal widths, since a lazy list holds only those on screen:
  every sidebar row, and the panel's 64 longest by characters, every row of a
  10,000-row list having taken 3 s; 15,000 rows fit in 50 ms. A services' page
  wraps rather than truncates, so there it goes back to the first width.
- **Each side takes at most half the room it shares with the tabs**, never less
  than its minimum. A fixed 560 pt cap cut a deep path's fit; with none, a fit
  to a 1000 pt path and then a narrower window left the tabs 50 pt. Both widths
  are solved together so the layout and `multishell window` agree.
- **A click on a row's git badge opens the panel on Changes under Modified**,
  what the badge counts, with a named accessibility action on the row, whose
  children VoiceOver cannot reach.
- **Copy Path copies the absolute path**, as the worktree's own does.
- **No drag out of the panel**, the app's drags carrying its own pasteboard
  types; a file URL would let Finder move the file.
- **The panel's worktree is read in the background while its window shows** and
  it lists Files or Changes, so coming back never shows a stale list, as is one
  whose All changes tab is shown (files/all-changes-tab.md). Other rows keep the
  frontmost-only reads.
- **The tree's listing is built again only when paths move**, not for a count,
  as an agent's every save moves one: 200,000 paths took 1.2 s. Past 20,000
  paths it builds off the main actor, the last listing drawn meanwhile. Each
  path is folded once for the filter, which folding them all per keystroke made
  0.9 s. The changed paths' half is kept while only counts move too: 50,000 new
  files took 0.3 s per status read. What a status read still costs the main
  actor stays there by choice: 110 ms at 100,000 changed paths and 300 ms at
  250,000, paid as often as the status read's own pace allows, once a second for
  100,000 new files, which git read in 95 ms, and about once in two minutes for
  100,000 edited ones, which took it 11 s.
- **Only the panel's own worktree keeps its listing**, and the selected one's
  while the quick switcher is up, a Linux-sized one and its tree holding about
  80 MB; coming back reads it again.
- **A submodule's folder opens as a repository of its own**, since the
  worktree's git lists the folder and nothing in it. Its rows stay out of the
  worktree's Changes list, which is what the worktree would commit. One nobody
  has initialised lists empty: `git -C` there runs against the parent, so
  `rev-parse --show-toplevel` must name the folder.
- **The pages are glyphs on the panel's header, which reaches the window's
  top**, as Orca draws them, so the worktree's header ends at the panel's edge
  and at the narrowest loses its names before its actions menu.
- **A file taken out of the index but left on disk counts both its entries** in
  the list, as the badge does, while its tab draws it as the new file it is: the
  row says `+2 −2` where the tab says `+2`.
- **Review's glyph carries a dot while a comment waits, not a count**, as the
  switch carries none (files/review-comments.md). services/reads.md has when the
  PR and CI pages read.
- **Show Hidden Files is one global switch, on by default**, because the panel
  listed ignored files before the switch existed. Hidden means what git ignores,
  and the quick switcher finds none of it either. What was read stays in memory
  while hidden, so turning it on finds the open folders again.
- **The tree builds without recursion**, a trie of the paths turned into nodes
  bottom up. A large listing builds on a Dispatch thread, whose 512 KiB stack a
  recursion per path part overflowed at about 1,400 parts, and Linux allows a
  path that deep.
- **In an ignored folder, a link is a folder only where it leads to one inside
  the worktree**, and a folder reached through one leading out lists nothing:
  listed as a folder, a link out showed another directory's names. A link inside
  stays one, as pnpm's `node_modules` is made of them.

## Reviewed and left as is

Raised by reviews and settled; a review need not raise these again.

- **`files expand`, `collapse` and `filter` build the rows twice**, once to find
  the folder or under the old filter, once to answer. The two are of different
  panel states, the second the one the reply lists, and each is the one the
  panel would build on its next draw.
- **The panel's page named "mode" in code** (2026-11-04 review): the type is
  `FilesPanelMode`, the UI and these docs say page. AppModel says mode for the
  value throughout (`setFilesPanelMode`, `showFilesPanel(_ mode:of:)`,
  `lastReadFilesPanelMode`); renaming the type would touch the persisted
  `filesPanelMode` key, the command line's setting name and about 140 sites.
- `FilesPanelRow.activate()` picks between `toggleFolder` and `activateFileRow`
  in the view (review of 2026-11-27). It dispatches on the row's kind and
  decides nothing; one async model method would put each folder toggle behind a
  Task.
