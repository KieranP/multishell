# The All changes tab: reviewed and left as is

Findings from the review rounds on [all-changes-tab.md](all-changes-tab.md) that
were settled without a change, each with why. A review reads this first.

- **An opened fold is not moved when lines are added above it** (review round
  2): it is kept by the file on disk's line numbers, as the bullet on folds
  says, so an edit above shifts which lines show open. Re-anchoring folds as
  comments are would cost a quote per fold for a run-only convenience.
- **Find carried twice when a read moves comments** (review round 3, unproven):
  setting the comments searches again from the old text, and the read carries
  the result once more. The selection also moved with no comment involved, which
  round 17 traced to the carry going by line number across files. Round 18 tried
  a read moving a comment with one row and five above the match, and the
  selection held (`aReadMovingCommentsKeepsTheFindSelectionOnItsMatch`).
- **The document's staging marks taken from its first file with rows** (review
  round 3, unproven): under Branch a file in an embedded repository counts from
  `HEAD` and marks staging while the worktree's own do not. No case has been
  shown; each file's own rows carry its marks.
- **A file deleted after the tab read it keeps its last text** (review round 4):
  its file tab does the same
  (`aFileDeletedUnderAnOpenTabKeepsItsLastTextUnmarked`), and each file reads as
  its tab would; read afresh it shows its lines removed.
- **A step's box dropped once the unread file it sat on is read** (review round
  5, unproven): the next step counts from the top of the clip, which can step
  back into a short file above. Not shown in a test.
- **"Fold" for unchanged lines hidden in a file** (review round 5): the design,
  the mockups and `git` itself say fold; the Files panel's "folded" is case
  folding, an adjective in another area, and renaming either is churn for no
  reader's gain.
- **A file shown whole keeps its gap items at document rows in its slice**
  (review round 6): no such file gets a fold or notice, being all one kind of
  line, and rebasing by the document's rows would be wrong for a removed file,
  whose Split rows do not count as its Unified ones do.
- **Each update regroups the worktree's comments once per built file** (review
  round 7): about ten files and a few hundred comments make it a few thousand
  cheap steps; caching the groups would need every comment write to keep them
  fresh.
- **A scroll to a row can land short of it where files it builds grow by their
  cards** (review round 9, unproven): heights measured a turn later move the
  files below. Not shown in a test; the next scroll or step corrects it.
- **Spans shifted into document offsets and back when a file is coloured**
  (review round 9): it runs once a parse, the parse kept by path; not measured.
- **Every update lays the list out again, estimating each unbuilt file** (review
  round 9, not measured): an estimate is a lookup and a sum, and a layout
  already runs on every scroll that builds a file.
- **Unproven in review round 11, each tried or traced and not shown**: a bare
  caret scrolling a long line back to its left edge (a test kept the sideways
  scroll); a file's wheel axis lock met mid-gesture keeping an old axis (rests
  on AppKit sending one gesture to two scroll views); a pending caret rect
  scrolling the list during a file's layout (none is pending once laid out).
- **Cmd+Up or Cmd+Down in a focused file scrolling the list twice** (review
  round 12, unproven): the caret's move and the list's jump to its end were
  counted in a test, and the list reported one scroll.
- **Every read lstats every listed file** (review round 13, not measured): the
  signature also drops a submodule's folder from the list, and a few thousand
  lstats run off the main thread.
- **A path listed twice merged both here and in `FileTree`** (review round 13):
  the two differ on purpose, the tree keeping a nested repository's row that
  this list leaves out, and each merge is two lines.
- **A row cap of zero or less makes the reader spin** (review round 16): only
  tests pass a cap, and each passes a positive one.
- **The canvas's gutter and gap layers framed at the document's height** (review
  round 17, unproven, not measured): a scroll redraws only what shows.
- **File-tab names on code the All changes tab shares** (review round 17):
  `rerunFileFind(in: FileTab.ID)`, `FileTabReadLog` and the like take its ids
  too; renaming every shared call touches dozens of files for no change in
  behaviour, and one per-kind seam for them is a larger refactor than the tab.
- **Each read rebuilds the whole document and resolves its git bases again**
  (review round 18, not measured): a scroll that brings unread files near reads
  them in one batch, which 2 or more files make cheaper than reading alone.
- **Two git diffs a chunk, twice `runsAtOnce` processes** (review round 18):
  measured on 6,000 changed files and 12 cores, 8 chunks took 0.307 s and 4 took
  0.334 s, so the pair stays.
- **A `git check-ignore` refusal on a path inside a submodule drops the batch**
  (review round 19, unproven): a scratch repository in round 16 showed the
  reader leaves the submodule's folder out, so its paths never reach it.
- **Two bounded task pools, the reader's and the batched patches'** (review
  round 19): the reader's also lands files in order against the row cap, so one
  shared pool would need both shapes.
- **Find kept in step by each change to the layout** (review round 19): a rerun
  inside `allChangesDocument(of:)` would search from a getter; the four callers
  share `relayingOutAllChanges` or pass the old layout themselves.
- **A click off the boxed change keeps the box** (bug hunt, 2026-11-20): a test
  clicking below it found the box let go, the column's own selection handling
  clearing it.
