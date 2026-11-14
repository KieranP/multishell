# Plan: the All changes tab (issue #42)

You are implementing GitHub issue #42 in `/Users/kieran/Work/multishell`. Read
the issue first (`gh issue view 42`): it records what the owner picked from the
mockups and what is still open. The mockups are attached to it as PNGs. The
interactive canvas behind them is option A at
https://claude.ai/artifact/3s6ZsAhBGjtQ2Rhjth8L4q (read it with the Artifact
tool if you have one; ignore option B there, it was not picked).

Before touching an area, read the design file the CLAUDE.md index points to. For
this work that is at least:

- `Docs/design/files/file-tabs.md`. Its first rule says there is no diff tab;
  this feature is the exception and must say why.
- `Docs/design/files/review-comments.md`, `Docs/design/files/panel.md` and
  `Docs/design/files/modified-and-branch.md`.
- `Docs/design/tabs-and-groups/tab-strip.md` and `groups-and-dragging.md`.
- `Docs/develop/adding/state-settings-and-command-line.md`,
  `Docs/develop/adding/interface.md`, `Docs/develop/layout.md`,
  `Docs/develop/tests/conventions.md` and `Docs/develop/memory.md`.

## What the owner picked

- A tab titled "All changes", at most one per worktree, closable like any tab.
  It opens from a button beside the filter on the Files panel's Changes page.
- The Changes list is its index. A click on a file row there shows the All
  changes tab, opening it if closed, and scrolls it to that file instead of
  opening the file's tab. The row of the file at the top of the tab's view stays
  highlighted as the tab scrolls. Each file's header in the tab has a button
  that opens the file's own tab.
- No file list or Viewed marks inside the tab.
- Each file is a box with a sticky header: collapse chevron, M/A/D letter,
  folder and name, `+n −n`, the count of comments waiting to be sent, and the
  open button. A collapsed file keeps its counts and badge.
- Unchanged runs fold to a "Show N unchanged lines" row, three lines of context
  kept around each change.
- Review comments are the file tab's: the same cards, composer, gutter + and
  drag, Comment on Lines, chips and Review rows. A comment written in either
  view shows in both, and one Send carries them all.
- A comment on an unchanged line keeps two lines either side of it open inside a
  fold.
- Modified/Branch and Unified/Split are the same single settings every file tab
  and the Changes list use.

## What exists today, and what assumes one file per tab

Two code maps were made for this plan. The parts that matter:

- `WorkspaceTab` (`Sources/MultishellCore/Model/Tabs/WorkspaceTab.swift`) has
  two cases, `.terminal` and `.file`. A group's `tabOrder` holds both kinds'
  ids. `Workspace` persists `tabs` and `fileTabs` as separate arrays.
- Many sites probe `workspace.tabIndex(id)` and then `fileTabIndex(id)` instead
  of switching on the kind, so a third kind falls through them silently:
  `Workspace+Lookup` (`workspaceTab(_:)`, `workspaceTabs(inGroup:)`,
  `workspaceTabsByWorktree`, `workspaceTabCount`), `WorkspaceStore` (`closeTab`,
  `retag`, `discardWorktree`), `Workspace+Repair` (`repairGroups`,
  `repairFileTabs`), `prunePendingClose`, `AppModel+Find`,
  `AppModel+ControlReach`, `AppModel+ControlPanes`, `shownFilePath`,
  `debugFileTabMemory`, and `pruneFileTabs` / `releaseHiddenFileTabs` /
  `readShownFileTabs`, which walk `workspace.fileTabs` only. The exhaustive
  switches the compiler will find for you.
- A file tab's read is `FileTabReader.read` (git `diff-index -p` with the whole
  file as context), giving `FileTabRows`: a `DiffDisplayText` of `DiffLine`
  rows, each with its own `oldNumber`/`newNumber`, and a `SplitDiff`. Reads are
  paced by `FileTabReadLog` and triggered from `AppModel+FileTabWatch`. A hidden
  tab releases its rows.
- The view is `DiffDocumentView` (gutter plus a TextKit 2 `DiffTextView` with
  every row's frame forced by `DiffRowGeometry`). `RowGaps` opens space under a
  row; review cards are hosted views placed in those gaps. Split is two
  `DiffDocumentView`s locked by offset.
- Review state: comments and their file are keyed by worktree and path, which is
  fine. Everything that writes comments goes through a `FileTab.ID`:
  `reviewComposers`, `reviewDrafts`, `reviewCardRevealRequests`,
  `reviewComposerKeyboardRequests`, `reviewQuote(of:on:in:)`,
  `tabHasLines(on:in:)`, `holdsRemovedLines`, `ReviewComposer` (it has no path),
  `ReviewLineSelection` (no path), `ReviewCardPlacement.placements` (maps line
  numbers to rows over one file's lines; numbers would collide across files),
  `reviewCardPlacements(of:in:side:)` (filters by `tab.path`), `ReviewCard` (one
  `tabID`), `pendingReviewCommentCount(of:)`, `selectReviewComment` (finds "the"
  tab for a path), `review add` (needs a shown file tab for the path), and
  re-anchoring, which runs only inside `readFileTab`.
- Per-file assumptions in the view: the scroll is saved by one file's line
  (`FileTabScroll`), the boxed change (`ChangeAnchor`) hashes one committed
  side, highlighting takes one path, and the gutter width comes from the largest
  line number.

## Design decisions for you to follow

These are my recommendations. Follow them unless the code shows a concrete
reason not to; if you deviate, say why in the design doc.

1. **A third tab kind, not a file tab with many paths.** Add `AllChangesTab`
   (Core, `Model/Tabs/`) with `id`, `worktreeID`, `groupID` and an optional
   saved scroll, and a `WorkspaceTab.allChanges` case. Persist it in its own
   `Workspace` array under a new key, decoded lossily, so an older build drops
   it as it drops `fileTabs`. One per worktree: the store's open turns to the
   existing one. Repair drops duplicates per worktree and ids another tab holds,
   and counts the array in `repairGroups`.
2. **Replace the probe pairs you touch with one lookup that returns a
   `WorkspaceTab`,** so the next kind is a compile error instead of a silent
   fall-through. Extend each probe site above and give each a test.
3. **The tab reads every changed path with `FileTabReader`,** the same reader
   and the same cap per file, so a file reads the same in both views. The path
   list is the one the Changes list draws (`FileTreeSources.markedChanges`), in
   the Changes list's order, with submodule rows left out as the list leaves
   them out. Keep each file's full rows in the model; folding is a display step,
   because anchoring needs the whole file.
4. **Check before building:** whether the Branch list is read when the Files
   panel is hidden. `panel.md` says only the panel's worktree is read. The tab
   needs its path list with the panel shut; if the read does not run, make the
   tab ask for it rather than reading git a second way.
5. **Reads are paced and released as a file tab's are.** One read log per All
   changes tab, triggered by a git change in the project or an event in any
   listed path's folder; a hidden tab releases its rows and owes its read. Read
   only files whose content or status moved, not all of them, on each event.
6. **One document, not a stack of file views.** Concatenate the files' shown
   rows into one `DiffDisplayText`, with a row map from document row to (file,
   row in file). File headers, fold rows and collapsed files are gaps in
   `RowGaps` with hosted views, as review cards are, so find, copy, the Changes
   rotor and the drift tests still see rows only. A stack of `DiffDocumentView`s
   would nest scrollers and lose the offset lock in Split.
7. **The sticky header is an overlay** showing the header of the file under the
   top of the viewport, worked out from the geometry, not a view inside the
   scroller.
8. **Highlighting runs per file slice** with that file's path, its spans shifted
   by the slice's offset. Check the cost against the file tab's: the read log
   counts the highlight.
9. **Change steps span files.** `changeStarts` works over the concatenated rows
   as is. Hold the boxed change by (path, that file's `ChangeAnchor`).
10. **Copy across files** prints each file's part as `git diff` would, with its
    `diff --git` header. A selection within one file copies as a file tab's
    does.
11. **Split** concatenates each file's `SplitDiff` sides. A file with only added
    or only removed lines shows on its one side with padding opposite. The
    mockup drew it full width with an "Added, shown Unified" note; that needs a
    full-width overlay across two offset-locked views, so build the padded form
    first and ask the owner before building the overlay.
12. **Review in the tab.**
    - Give `ReviewComposer` a `path` (runtime only).
    - Keep one composer per tab, keyed by the tab's id. The All changes tab id
      shares the UUID space, so the dictionaries can stay as they are once their
      guards accept the new kind. Name the key type for what it is, a tab that
      hosts review cards, rather than `FileTab.ID`.
    - `ReviewLineSelection`, `reviewQuote`, `tabHasLines` and
      `holdsRemovedLines` take (tab, path) and read that file's rows.
    - Place cards per file against that file's rows, then offset them to
      document rows. Write the cross-file placement test first: two files with
      the same line numbers must not trade cards.
    - After each file's read in the tab, call
      `reanchorReviewComments(onFile:in:to:readUnder:)` with that file's full
      rows, and re-anchor the composer when its path is that file.
    - A comment's lines plus two either side are shown even inside a fold.
    - The tab's badge counts every pending comment in its worktree.
    - Closing the tab asks first when its composer holds text, as a file tab's
      does; `pruneFileTabs` (or its successor) prunes the new kind's entries.
    - `selectReviewComment`: when the worktree's All changes tab is the shown
      tab of a group, reveal the card there; otherwise keep today's behaviour.
      This follows the mockup, not an explicit pick; note it in the doc.
13. **The Changes row click** becomes a model method the row calls on the
    Changes page only. The Files page, the quick switcher and `tabs open-file`
    keep opening the file tab. The view reports the file at the top of its
    viewport to the model through `setIfChanged`; `isShownFile` uses it while
    the All changes tab is the active tab.
14. **Folds.** Keep three lines of context. A click on a fold shows its lines.
    How far a fold at the top of a large file opens is still open (the mockup
    opens a few lines and offers Open file for the rest); pick the simplest rule
    and write it down as the owner's to revisit.
15. **Collapse state** lives on the model, keyed by tab and path, and is not
    persisted. Say so in the doc; whether to persist it is an open item on the
    issue.
16. **Memory.** A file tab's layout reaches 186 MB at 1 MiB. Measure the tab
    over a large worktree with `debug memory` and `footprint` as `memory.md`
    describes, then set a cap on the total rows held, past which files show
    their header and an Open file button, as the mockup's over-cap file does.
    Record the measurement and the cap in the design doc.
17. **Command line.** `tabs open` grows a way to open the All changes tab, and
    `tabs list` reports the new kind (`TabKind`). `review add` accepts the All
    changes tab as the host when no file tab shows the path. Follow
    `state-settings-and-command-line.md` for each request and refusal.

## Phases

Each phase leaves the app working, tests and lint green. Commit only when the
owner asks (CLAUDE.md); subjects start with a tag such as `[Feature]`.

1. **Tab model and persistence.** `AllChangesTab`, the `WorkspaceTab` case, the
   `Workspace` array and coding key, store open, close, move and repair, the
   probe sites, the tab face (glyph, "All changes", comment count, close
   button), `TabGroupView` mounting a placeholder body, the Changes page button,
   and strings in the catalogue. Tests: decoding with and without the key,
   repair cases, the store's one-per-worktree rule, close and reorder.
2. **Reading.** The path list, per-file reads, pacing, release when hidden, and
   a reading type holding every file's rows. Tests against `RepositoryFixture`:
   Modified and Branch, an added, a deleted and a binary file, a file over the
   cap, a submodule left out, an event re-reading only the file it touched.
3. **Unified document.** Concatenated rows and the row map, header and fold
   gaps, collapse, the sticky header, highlighting per slice, find, change steps
   across files, copy across files, saved scroll. Extend the drift tests to run
   with header and fold gaps open.
4. **Changes list as index.** The row click, scroll to file, the in-view
   highlight, and the header's open button.
5. **Review comments.** Everything in decision 12. Write each failing test
   before the change it covers: placement across files, composer path,
   re-anchoring per file, prune and close, the Review page reveal, counts.
6. **Split.** Per-file `SplitDiff` sides, padding for one-sided files, cards in
   the column holding their lines.
7. **Command line, memory cap and docs.**

## Docs to write as you go

- A new `Docs/design/files/all-changes-tab.md`, newest at the bottom, with a
  "Reviewed and left as is" section, listed in the `Docs/DESIGN.md` table. Under
  300 lines.
- In `file-tabs.md`, amend the "One tab per file" rule to point at the new file
  for the exception.
- In `review-comments.md`, the rules that change: cards in two views, the
  composer's path, where re-anchoring runs.
- Code comments only say why and are at most two lines; longer reasons go in the
  design doc.

## Checks before you call a phase done

- `swift-format`, SwiftLint, `make test` and both builds, all passing with no
  warnings (`Docs/develop/build/verifying-a-change.md`).
- Read your own diff as a reviewer and look for call sites of anything you
  changed that you did not open, especially the probe sites above.
- Drive a debug build only through the `multishell` helper against a scratch
  home, never typing into panes and never the installed app's state. Say what
  you could not verify on screen and leave the looking to the owner.

## Still open on the issue

Say which you decided and how, and leave the rest for the owner:

- How far a fold at the top of a large file opens.
- Whether a collapsed file is remembered across relaunches.
- One-sided files in Split: padded or a full-width overlay.
- The memory cap's number.
- Whether `review add` should prefer a shown file tab or the All changes tab
  when both show the path.
