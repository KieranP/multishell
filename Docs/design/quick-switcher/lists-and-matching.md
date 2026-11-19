# Lists and matching

What the quick switcher lists empty and typed, how places and files match and
rank, the files it reads and drops, the menu commands it offers, and what a
choice opens. Newest at the bottom, above "Reviewed and left as is".

- **Empty, All lists who is waiting, longest first, then the worktrees turned to
  lately**, so Return on an open box answers the agent that has waited longest.
  With neither, it lists every worktree, so a first launch never opens on
  nothing.
- **Typed, a waiting agent, and only the agent, is lifted by a fixed amount.**
  It rises over a slightly better match, never over a row the text names far
  better.
- **A place reads as its path from its project down**,
  `billing › main › Claude Code`: the user's own words, asked for over a title
  with its place beside it.
- **A place matches by letters in order through its path**, a run of letters
  keeping the bonus of where it starts, as fzf scores, and the best of the
  alignments from each place the first letter is. Scoring each letter alone put
  `pricing-order-test` above `fix-port-block` for `port`; the first alignment
  alone matched `main` scattered through the project's name. A word may instead
  match the start of a word after the path, so `api` finds an agent by its
  pane's title; scattered letters there matched nearly everything.
- **A file matches by every word inside its path**, the Files panel's byte
  search, not the letters in order. A repository of 200,000 paths is searched on
  every key, and the ordered match is too slow for that. An ignored file git
  names, listed while Show Hidden Files is on, scores one point under a tracked
  one, so `main.cpp` beats the `main.o` beside it; it is read with the tracked
  files so the listing is built once.
- **Only the best hundred paths are kept as the listing is walked**, never all
  the matches sorted, since one letter names nearly every path. Files and All
  share them, so Tab between the two reuses the search. The last search is
  reused until the text or the listing moves, an agent's report redrawing the
  box, and dropped as it closes, since it holds the listing.
- **Files come from the panel's own listing, read only once Files or text in All
  needs them**, as a large repository's read is not worth paying for Commands or
  an empty box. Nothing re-reads them on a checkout while it is up, the panel's
  watch reading only for a shown panel.
- **One rule says which listings are kept**: a shown panel's worktree's, and the
  selected worktree's while the switcher is up. Shutting the panel under the
  switcher keeps the listing it still searches, and closing the switcher drops
  one the panel does not show; both apply the rule, so neither checks for the
  other.
- **A read of the files is asked once an opening.** One that failed, a broken
  index or a folder git refuses, would otherwise run again on every key.
- **Commands are the menu bar's enabled items, walked once as it opens**, so the
  list never drifts from the menus. Each menu's delegate is asked to update
  first: SwiftUI sets a Toggle's tick only as its menu opens, so the View menu's
  switches read stale without it. Show Hidden Files is listed as "Toggle Hidden
  Files": a title naming a state reads wrong in a row with no unticked box.
- **A command chosen is the user's own click**, not the command line's, so Paste
  saves an image and words files as a Cmd+V does. It runs on a timer, which
  fires only once the run loop has waited and SwiftUI has taken the field down;
  until then the field has the keyboard, and Copy would copy it. A queued block
  ran before that redraw.
- **Commands are the app's own, and only those that can act now.** Left out: the
  Services, Window and Help menus macOS fills, matched by title too since
  SwiftUI's rebuilt bar can hold a copy of the menu registered; any submenu of
  the app menu; and the items macOS adds to the others (Hide, AutoFill,
  Dictation, Emoji & Symbols, Enter Full Screen, the tab bar items), known by
  their actions since their titles are the user's language. So are the app's own
  editing items, Find, the theme picker's choices and the switcher's own two,
  known by their titles, as SwiftUI's buttons all share one action.
- **A command that cannot act is left out by asking the model per title**, not
  by disabling its menu item: a disabled item gives its key to the pane, and
  Ctrl+Tab with one tab typed a Tab into the shell. `ui menu` still lists
  everything, as the command line drives the whole bar.
- **Two menu items whose titles differ only by a "…" are one command**, as
  AppKit's lookup matches them; only the first can ever be chosen.
- **A place chosen opens its project in the sidebar**, so the row it went to
  shows.
- **Recent is runtime state**, the worktrees selected this run. A project chosen
  opens the worktree of it turned to last, else its main one.
- **A tie goes to the shorter path, then the row's kind.** The shorter path is
  the more general place, so a project's own name lists the project above
  everything under it; the kind added to the score outweighed a better match.
- **Rows list in the sidebar's order**, so a tie in the score falls as the user
  sees it.
- **A file chosen takes down a cover over its worktree once it has opened**, the
  Agents board or Debug Info, as a Files panel row would, without a select: that
  opens a first tab in a worktree with none and can ask the trust question.
- **Empty, Files lists what changed, a hundred at most**, kept in one pass as a
  search keeps them. A fresh build output of 50,000 untracked files sorted in
  full took 72 ms a render in a debug build; the pass takes 15.
- **The kept search goes when its worktree's tree takes another listing**, and
  as the switcher closes. A read whose listing still builds keeps it, as does a
  move of scope, or Tab from All round to Files would search every path again.
- **A row build reads the model's observed values once a list**, not once a row.
  `AppModel` is generic over its surface, so each read of an observed property
  builds its key path again: 900 reads took 1.66 ms against 0.055 ms on a plain
  class. Reading per row cost the switcher 13 to 16 ms a keystroke at 900
  worktrees and 300 tabs in release; the sort's key closures read the same way.

## Reviewed and left as is

Raised by reviews and settled; a review need not raise these again.

- **A worktree selected at launch missing from Recent.** Launch selects nothing
  (`AppModel.init` calls `store.selectWorktree(nil)`), so every selection goes
  through `select` and is noted.
- **A choice of a menu item on a timer rather than on the field leaving.** The
  timer's ordering is the reason above; tying it to the field would make the
  model wait on a view's event.
- **A failed read of the files bumping `fileTreeBuildLandings`.** A read ending,
  failed or not, is a landing for whatever waited on it.
- **A project row carrying its whole `ProjectSettings`.** The copy is
  copy-on-write and nothing compares the results.
- **Places rebuilt and ranked on each render.** A few hundred rows, each title
  folded once, take well under a millisecond; only the file search, over up to
  200,000 paths, is kept between renders. The tab rows look groups and tabs up
  once a build: a filter per worktree grew with the square of the worktrees, 1.7
  ms at 300 and 10.7 ms at 1,000 in a release build.
- **A lone combining mark before a ligature shifting the bold letters.** Tried
  with `\u{301}ﬁt`; the letters bolded were the ones matched.
- **A project whose last worktree's folder has gone not falling back to its main
  one.** The missing-directory alert says why, and the main worktree is a row of
  its own; probing each recent folder first could block on a mount that hangs.
- **A file choice letting the listing go a second time once it opens.** The
  open's check needs an opened submodule's not-checked-out paths, which only the
  listing gathers, so it reads the tree the dismiss let go.
- **The board closed and opened again while a chosen file opens being taken
  down.** A cover has no identity to tell the two apart, and it is two key
  presses inside the open's few milliseconds; the cost is one more.
- **A second submenu of an earlier one's title listing items nobody can
  choose.** AppKit's lookup by title reaches only the first, as `ui menu` does,
  and no menu here has the shape.
- **A search building the Files panel's change tree with its listing.** One
  cache holds both halves, and the change tree is built off the main actor past
  20,000 changed paths; splitting the cache for that case would change the
  panel's.
- **The changed list and the search judging an openable path by different
  rules.** The changed list vets on the tracked list so it never builds a large
  repository's listing; the search has the listing already. Where they differ,
  an opened submodule's sparse paths, the open itself checks and beeps.
- **Closing the switcher over a cover letting go of the Files panel's listing.**
  Under a cover nothing keeps a listing fresh, so the one rule for kept listings
  drops it; the cost is one read as the cover comes down.
- **A project row matching by a parent folder of its path.** Typing `work` lists
  the projects under `~/Work`, as a project's name lists its worktrees; places
  stop at eight, and a title match outweighs a location's.
- **A pane's row not found by its worktree's own name.** Agents and tabs read
  `project › branch › name`, as asked, so `port fix` finds the worktree named
  Port fix and not the panes in it.
- **A run starting at a later word missed after an earlier word start.** Each
  letter takes the first word start that has it; finding the best of every such
  choice is a search per title on every key.
- **Command availability kept in a table by title, a missing title counting as
  able to act.** SwiftUI's buttons share one action and carry no identifier, so
  the title is the only key; a command left out is listed and does nothing,
  where one wrongly hidden could not be found at all.
- **`isMenuCommandAvailable` an `AppModel` method in MultishellAppUI.** It maps
  the UI's localized titles to the `can…` properties, which are the decisions,
  and those live and are tested in MultishellAppCore.
- **Each Cmd+P walking the whole menu bar, even for an empty All.** Walking on
  first need moves the same cost onto the first letter typed, Shift+Cmd+P needs
  it at once, and a second walk point would be a second place the list is read.
- **Each arrow press building the rows again.** It is the same build as a
  render, above, well under a millisecond.
- **The View menu's panes listed under a cover while the panel is on.** Choosing
  one turns the panel off, as the menu item does there; leaving them out hid a
  command that acts.
- **`ui switcher` waiting on file-tree builds with no bound.** Unproven: a
  listing starts its change set and both end; a build that never settles under
  steady status changes was not reproduced.
- **`ui switcher --choose` on a command row checking the menu with the
  switcher's field focused.** Unproven: no menu item found enables only with a
  pane focused.
- **The switcher's worktree order asking the sort cache with every worktree,
  where the sidebar asks with the rows it shows.** Under a filter or with hidden
  rows the two key lists differ, so each re-sorts the project when both draw: 85
  µs at 40 rows.
- **`FoldedCharacters` maps offsets one to one where the fold kept the count**
  (2026-11-12). A lone combining mark survives folding, so no title was found
  whose fold drops one character and doubles another.

## Checked by hand

What tests cannot reach, to check in `make run` before a release:

- Commands lists no Services, Window, Help, editing or theme item, and drops New
  Tab at first launch and over the Agents board.
