# The Files panel

What the panel lists and why each went the way it did. Newest at the bottom.

- **A panel beside the tab area, not a cover over it nor a list beside a diff.**
  A 400 pt diff was too cramped, and a cover hid the agent being reviewed.
- **Uncommitted changes, and since the base branch**: see
  files/modified-and-branch.md.
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
  can disagree; worktrees/line-count-badge.md has the read.
- **Glyph tabs named in a tooltip, Files, Changes, PR and CI**, not a lettered
  toggle, "M 4" not saying what it was. Changes is a document with a diff: a
  branch glyph beside the pull request's arrow read as two of the same. The
  tooltip is drawn in the theme, `.help`'s being the system's grey. No count on
  the switch, the footer carrying it, and no status letters anywhere: the counts
  and the dot carry the change.
- **Files or Changes is one choice for every worktree, kept with the settings**
  under the `all` and `modified` earlier builds wrote, so an older build still
  reads it; the command line says `files` and `git`, `modified` being a scope,
  as Unified or Split is, so a relaunch or another worktree lists what the last
  panel did.
- **A zero side of a file's count is left out**, `+21 −0` on a new file reading
  as noise. The sidebar badge and the footer keep both, a badge changing shape
  having read as broken.
- **The filter folds as the sidebar's does**, over the whole path, matched as
  UTF-8 over paths folded and composed once: `contains` took 181 to 263 ms over
  200,000 paths, a byte search 7 to 11.
- **The panel is one switch for the window, kept across launches, and its width
  is per machine**, kept as the sidebar's is. It was once shut at each launch,
  then opening with the first worktree having read as a bug; a launch now
  selects nothing, so the panel shows with the worktree picked, and a panel
  closed at every launch read as forgotten. The model holds the switch, so a
  click on a row's badge can open it. No keyboard shortcut yet; a View menu
  item.
- **Double-clicking either edge fits its column to its rows**, laid out off
  screen at their ideal widths, since a lazy list holds only those on screen:
  every sidebar row, and the panel's 64 longest by characters, every row of a
  10,000-row list having taken 3 s; 15,000 rows fit in 50 ms. A services' page
  wraps rather than truncates, so there it goes back to the first width.
- **Each side takes at most half the room it shares with the tabs**, by drag,
  fit or a narrower window, and never less than its minimum. A fixed 560 pt cap
  cut a deep path's fit; with none, a fit to a 1000 pt path and then a narrower
  window left the tabs 50 pt. Both drawn widths are solved together from the
  kept ones, so the layout and `multishell window` agree: where both are past
  half their room the window splits in thirds.
- **A click on a row's git badge opens the panel on Changes under Modified**,
  what the badge counts, with a named accessibility action on the row, whose
  children VoiceOver cannot reach.
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
  per status read. Past 20,000 changed paths it builds off the main actor as
  well, as a tracked file changing moves the set without moving the listing. The
  listing's bound counts every path it lists, a read submodule's and a staged
  deletion's included. What a status read still costs the main actor, the tree's
  kinds and counts and the shown rows, stays there by choice: 110 ms at 100,000
  changed paths and 300 ms at 250,000. It is paid as often as the status read's
  own pace allows, once a second for 100,000 new files, which git read in 95 ms,
  and about once in two minutes for 100,000 edited ones, which took it 11 s.
- **Only the panel's own worktree keeps its listing**, and the selected one's
  while the quick switcher is up, a Linux-sized one and its tree holding about
  80 MB; coming back reads it again, with each open folder git does not list. A
  folder git stops ignoring drops what was read of it.
- **A submodule's folder opens as a repository of its own**, listed and read
  apart, since the worktree's git lists the folder and nothing in it. Its rows
  carry their own counts but stay out of the worktree's Changes list, which is
  what the worktree would commit, and a file tab inside it diffs against the
  submodule's `HEAD`. One nobody has initialised lists empty: `git -C` there
  runs against the parent, so `rev-parse --show-toplevel` must name the folder.
- **The pages are glyphs on the panel's header, which reaches the window's
  top**, as Orca draws them: the worktree's header ends at the panel's edge, its
  actions menu beside it, and the panel's header carries the glyph that shuts
  it, where the worktree's header carries it while the panel is shut.
- **The worktree's header ends where the panel begins**, so at the narrowest it
  is clipped from its leading side sooner, its names going before the actions
  menu does.
- **A file taken out of the index but left on disk counts both its entries** in
  the list, as the badge does, while its tab draws it as the new file it is: the
  row says `+2 −2` where the tab says `+2`.
- **PR and CI are the panel's third and fourth pages**, kept in the same saved
  choice as Files and Changes; services/reads.md has what they read and when.

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
