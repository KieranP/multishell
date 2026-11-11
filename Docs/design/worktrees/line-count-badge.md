# Line-count badge

The badge's line and file counts, its arrows, the per-file list and the diff
algorithm. Newest at the bottom, above "Reviewed and left as is".

- **The badge counts lines, and only for a dirty worktree.** A dot and a file
  count said something had changed and nothing about how much.
- **A badge out of room drops its file count, then its arrows**, the tooltip
  naming both. The name truncates first: `+12345 −6789 ~12 ↑3 ↓2` needed 229.5
  pt of a 164 pt row at the narrowest sidebar and overflowed it.
- **A branch with no upstream counts ↑ against the project's default branch.**
  git counts only against an upstream, so a branch never pushed showed no arrow
  however many commits it held. A commit any remote-tracking ref holds is left
  out, or a branch pushed without `-u` showed every pushed commit as unpushed.
  Cost: one `rev-list` a read for such a branch, before the diffs, and none for
  a checkout of a local base or a branch with no commit yet. A local `main` with
  no upstream beside `origin/main` is counted: its commits are unpushed.
- **A failed count fails the read**, which keeps the last badge, rather than
  reading as nothing ahead.
- **Those branches are read again when the default branch resolves or changes
  name.** Launch reads statuses before the first branch scan, so waiting for the
  next poll left the arrow missing. A row not yet read is read too, as a read
  under way began without the base. Only rows a poll reads are read, each when
  its pace allows. A tip moving needs nothing: the ref write reads the rows.
- **Staged and unstaged come from one diff**, with the cached-only form as the
  fallback wherever that call fails. Before the first commit it counts from the
  empty tree, whose id `hash-object` gives without writing it: the cached form
  there counted a staged file's staged lines and none added since. Only an
  unborn HEAD gets the empty tree, or a failed read would badge the whole
  checkout as added. Status's own header says HEAD is unborn, so no read asks
  git again first.
- **An untracked file has no diff at all**, so they are listed and their lines
  counted by reading the files: without that a deleted file's lines counted and
  a new file's did not, which is the shape of most branches early on.
- **A file too big, not regular, or binary in its first bytes is counted as a
  file with no lines**, as is whatever no longer fits in the budget.
- **A symlink is one of those**: its own bytes are not its target's while the
  read follows the link, so a short link into a huge file passed the per-file
  cap and took the whole budget.
- **The budget is checked against the file's size before the read**, so it
  cannot be overshot, and a small file after one that would not fit is still
  counted.
- **The read is unmapped.** Mapped, a file another process truncates under it
  faults past the end, which is a signal and not an error a `try?` can catch.
- **The reads are synchronous, so they run through `runOnDispatch`**, as the
  list's stats of each worktree do. `Task.detached` runs on the cooperative
  pool, which is as wide as the cores: a probe of 64 blocking detached tasks
  peaked at 12 on 12 cores, and an unrelated task waited 5.15 s for a thread.
  Cost: a dead mount holds a GCD thread per read rather than queueing them.
- **Past 50,000 new files the paths are not kept as strings**, though every one
  is still counted.
- **Every count comes from one list of changed files**, for every worktree read,
  shown or not: the badge, its tooltip, the removal dialog, `worktrees show` and
  the Files panel. Counted in two reads, a new folder was one entry in the
  tooltip and every file in the removal dialog.
- **Status collapses a new folder to one entry**, and the `ls-files --others`
  list the line count already ran names every file inside it, so its entries are
  what is counted, in full; only the first 500 are read for lines, so the lines
  stay a floor and a folder nobody gitignored shows the first files' worth.
- **The list, not `status --untracked-files=all`**: that mode loses git's
  untracked cache, 294 ms on a large clean tree where the default mode reads in
  115 ms, and the list holds the same files at no new cost. A real-git test
  holds the two to the same files, a nested repository as `dir/` in both.
- **The file list runs only where status counted an untracked file**, under
  either indicator, and the runner's forced untracked-files setting keeps a
  repository's own config from talking it out of counting one. Where it fails
  the folder stays one entry, so the tree never reads as clean.
- **A file's count is kept by its path, size and date**, so an unchanged tree is
  stat'ed rather than read: 500 files of 16 KB took 51 ms a poll, every poll. A
  file that could not be read is not kept, since fixing its permission later
  leaves its date alone.
- **A binary file and a mode change have no line for either column**, and a zero
  badge on a plainly changed worktree read as broken. They are counted as files
  instead, in the theme's `ui.git` `changed` colour.
- **An unmerged path is not one of them**: it prints zeroes from the cached
  diff, so a conflict read as a file with no lines, and the filter drops it. The
  tooltip already says it is conflicted.
- **Nor is a row whose two counts are neither numbers nor both dashes**, which
  is not output git produces; read as zeroes it put a yellow count on the badge
  for a line nobody could parse.
- **Settings offers Staged Only**, which counts the index alone and no untracked
  file: what a reviewer is about to see rather than what the tree holds.
- **Staged and unstaged is the default**, since an index empty through most of a
  change gives a badge that reads zero.
- **Both counts are drawn whenever the worktree is dirty**, zeroes included: a
  badge changing shape as the index fills was read as the indicator being
  broken.
- **Cost: two or three git calls a dirty worktree where there was one**, and the
  yellow dot is gone, so which kind of change a worktree holds lives only in the
  tooltip; for one file, a file tab's dot and gutter say it.
- **Changing the setting invalidates the read log**, and a read already in
  flight lands on nothing: it counted what the badge no longer means, and its
  cost would pace out the read that does.
- **The counts pin renames and the diff algorithm**, so two people with the same
  app settings see the same numbers: a personal `diff.algorithm=histogram` read
  an edit Myers counts +1 −6 as +8 −13 in `diff --cached`, which follows it
  where the plumbing `diff-index` does not, and `status.renames` decided whether
  a `git mv` was one file or two. A move is a file gone and a file added.
- **The algorithm is a global setting, Histogram by default**, the user's choice
  over git's own Myers. It is about the person reading the badge, not the
  repository, so no project overrides it, and a change re-reads every badge as
  the indicator's does.

## Reviewed and left as is

Raised by reviews and settled; a review need not raise these again.

- **A `[gone]` upstream counts no ↑ past the base** (2026-11-06). After a squash
  merge every commit on the branch is past the base and on no remote, so each
  landed branch would wear ↑N for work that was pushed and merged.
- **A branch tracking a local branch counts ↑ against it, as git does**
  (2026-11-06). `git status` names a local upstream as it names a remote one;
  telling them apart costs a config read on every status read.
- **A repository with no remote shows ↑ past its local trunk** (2026-11-06). The
  user's rule is commits beyond the base that were never pushed, and with no
  remote none were.
- **A merged badge on a branch with no upstream stays up through a new commit
  until the verdict is asked again** (2026-11-06). It was so before ↑ counted
  for such a branch; the commit moves a ref, whose scan re-asks on its own
  budget.
- **A branch pushed without `-u` whose remote branch was deleted after a squash
  merge shows ↑N** (2026-11-06). With no upstream and no remote ref left, git
  holds nothing that tells it from a branch never pushed.
- **The control reply's `ahead` carries the badge's count, with no upstream
  field** (2026-11-06). The record is what the row's badge and tooltip read.
- **The launch-order test waits on `pendingBranchScans`, which clears before the
  scan ends** (2026-11-06). It failed without the re-read and passes with it; a
  stray scan landing late would fail its first check rather than pass.
- **The unpushed count on every status read, not cached on the refs**
  (2026-11-06). `rev-list --count HEAD --not <base> --remotes` took 10 ms with
  5,100 packed remote refs, beside a read that already runs `status` and a diff.
- **The count in the status read rather than the branch scan** (2026-11-06).
  `ahead` stays one field that the badge, tooltip, merged badge and control
  reply all read; counting in the scan would split it across two reads.
- **Launch reads a never-pushed row twice**, before and after its base resolves
  (2026-11-06). Scanning branches before the first status reads would hold every
  badge back behind a `for-each-ref` per project.

### Asked both ways

Reviews have asked for each of these and for its opposite. The side below is the
one kept; a review that would argue the other side need not raise it.

- **The unpushed count beside the diffs, or before them.** Round 1 of the ↑
  review (2026-11-06) asked to run it beside them, round 2 to keep each read to
  one git at a time under `maximumConcurrentReads`. It runs before them: the
  width bounds processes, and the count takes about 10 ms.
