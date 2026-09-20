# Worktrees and projects

Discovery, naming, ordering, removal. Newest at the bottom.

- **Watch where git records worktrees, poll everything else.** Never the `.git`
  root once the worktrees folder exists: `git status` rewrites the index, so
  every poll would be a refresh.
- **Status is polled frontmost only**, a few at a time, coalesced after terminal
  activity, a slow checkout asked less often, each tick comparing the records of
  the project whose directory fired before running git.
- **Timer git reads only**, and the status read forbids optional locks, or it
  takes the index lock and fails the user's own commit. Cost: a change git makes
  elsewhere waits for a tick.
- **A worktree's name is the user's, kept beside the worktrees.** Every refresh
  replaces a project's whole list, so a name written onto the worktree would be
  gone next tick. It is cleared wherever the store forgets a worktree.
- **The branch is never replaced, only demoted**: every git command in that
  directory acts on it, so a row that hid it would lie. The removal dialog names
  branch and path in its body, where what cannot be undone belongs.
- **The trunk row holds the top whatever the sort says.** Rows sort in bands
  first: git's main worktree, a linked worktree on the trunk, the busy ones if
  asked for, then the rest.
- **Two bands because a bare clone's trunk is a linked worktree.** The trunk is
  what every other row is read against.
- **The trunk is the default branch the badges use**, falling back to the usual
  names until the first scan resolves one. Cost: a project on another trunk can
  settle its rows once, seconds after launch.
- **git records no creation date**, so it is the directory's birth time, read
  where the list is made so the parser stays testable on fixture text.
- **Persisted, never re-derived**, or a volume that blinked would cost a save, a
  re-render and a row's place.
- **Last commit is runtime state instead**, the workspace not being rewritten
  because someone committed. The orders are named for the commit because that is
  what they measure.
- **It rides the ref scan the badges already run.** git fails a whole query on
  an unknown format atom, so the scan asks again without it, or an old git would
  cost every badge.
- **A worktree with no date sorts last in both directions**: "oldest first" is
  not a claim that an undated worktree is the oldest. Name breaks ties and is
  the default, being the only order that reads the same everywhere.
- **Active-at-the-top is off by default**: a worktree is active while it has a
  terminal or a reported state, so rows would move as agents report in.
- **Both order settings are shippable by a repo and run nothing**, and the
  override form seeds from what is in force, not the user's global.
- **The two globals are a menu behind a sort glyph in the sidebar header**, not
  a settings row: an order is changed while looking at the rows it moves, and
  the settings window was three clicks away.
- **A project's override stays in its settings**, the only place with room for
  the (i) text. Cost: the help naming the tie-break is only there.
- **The glyph is a mark rather than a control**, badge-sized and dimmer than the
  caption. It uses the strip's plain menu style, the bordered AppKit one drawing
  the image at its own size and tint whatever the label asked
  (tabs-and-columns.md).
- **A removed worktree goes to the Trash**, not `git worktree remove`, which
  refuses a dirty tree and whose force unlinks the files. The one time someone
  removes the wrong worktree is the time that matters.
- **A Trash that refuses falls back to deletion.** Cost: on such a volume the
  recovery the Trash promised is not there.
- **Trash and fallback run off the main actor**: a share with no trash folder
  walks a dependency tree for as long as it takes, and the window stood still
  for it.
- **The record is forgotten only after the Trash has the directory.** With it
  still there the forget would unlink it, so a Trash that returned with the
  directory in place is a failed removal.
- **A record git will neither remove nor prune is its own failure type.**
  Untyped it read as the Trash refusing, and the row came back over a directory
  that had gone.
- **The lock is never taken off before the trash**, so a Trash that refuses
  leaves the worktree as it was, reason and all.
- **Prune is the fallback for a path git cannot match**, no longer the first
  move: it forgets every record whose directory is away, an unmounted drive's
  included, and repair did not bring that one back.
- **Prune's exit is not the answer.** It exits zero whether or not this record
  was one it took, so the forget re-lists and fails if the path is still on
  record.
- **Without that, a failed remove reported a removal that never was**, and the
  caller went on to run the post-delete hook and delete the branch. Nothing else
  in the app deletes a ref on another command's exit code.
- **A list git will not answer, or answers with no worktree at all, counts as
  still on record** for the same reason.
- **Whether a removal asks at all is a global setting**, about the person and
  not the repo, but it always asks about the branch, the one part the sidebar
  cannot undo.
- **The branch goes last, after the post-delete hook**, so a hook that pushes it
  still finds it.
- **The main worktree and a bare repository are refused by the coordinator**,
  not only by the condition that hides the menu item: the call is public and the
  trash step would take `.git` with it.
- **One predicate is read by the menu, the request and the coordinator**, so the
  two cannot part.
- **A missing directory is refused, not worked around.** A shell spawned in one
  silently lands in the home directory.
- **A project whose directory is gone stays dimmed rather than dropped**, an
  unmounted drive not being reason to delete someone's setup, and the failure is
  reported once.
- **Both ends of a refresh check the project is still listed** before dimming
  it: one removed while its git call was failing was dimmed under a stale id and
  alerted about after it had left.
- **A stage that ends with its worktree gone takes its entry with it.** Stages
  are keyed by path, so an entry outlives its row and a worktree made again at
  that path inherits it.
- **A failed stage had nowhere to say so and left the entry running**, which
  reads as busy: no shell opens there, removal is refused, and Cancel finds a
  stopper already cleared.
- **So a failure with the worktree gone ends its own entry and alerts instead**,
  there being no pane left to put the message on. A removal that has since taken
  the entry keeps it.
- **The store's discard drops the entry and stops the stage**, as the pane's
  Cancel would: a hook left running in a directory removed in a terminal ran to
  its timeout and then alerted about a worktree that was not there.
- **The worktree list is read NUL-terminated.** git's own documentation calls
  the plain form unsafe for a path holding a newline, and the second half of one
  read as another attribute, so the row carried a directory that does not exist.
- **The container directory is git's to make.** The add makes every leading
  directory and a refused add makes none; creating them first left an empty
  chain behind a taken branch name.
- **The add runs with no timeout**: a checkout takes as long as the repository
  is, and a bound sized for one would cut off another.
- **What ends one that hangs is the sheet's Cancel**, which reaches git through
  the same stopper the pre-create hook has. Nothing undoes what git had made by
  then; the next refresh lists it or not.
- **A tree still being built wears no badge.** The add writes the record
  directory before checking a file out, and that is what is watched, so a tick
  lands mid-checkout where status counts every file not there yet.
- **So status is skipped while under construction**: every path a running add
  was given, and any worktree with a stage running. A failed stage is not one,
  nothing writing there until the Dismiss.
- **A claimed path forgets its status and its merged badge**, the last checkout
  there being gone and paths being ids.
- **A stage on a listed worktree keeps both and is asked nothing new**, or a
  removal would blank the very count and landed-branch note its dialog asks
  about.
- **Both merge and status rechecks re-read after their await**, a stage being
  able to start under a git call. The end of the add and of each stage schedule
  the reads rather than waiting the poll out.
- **The claim is counted, not a set**: two creates can name one path, and the
  first to end must not let go of what the other is checking out into.
- **A path already listed is not claimed at all**, a doomed create otherwise
  blanking someone's row for the length of its pre-create hook.
- **The add takes its path from the one derivation**, so what the sheet shows,
  what is held back and what is made cannot part. The create handle is still a
  single slot, so the second create's Cancel is lost under that overlap
  (BUGS.md).
- **Cost: the planned path is compared, not git's answer**, so on a symlinked
  volume the row is badged mid-checkout as before. Reading git's own
  initializing mark would cover a terminal-run add too (BUGS.md).
- **A branch name git will reject is refused before anything runs.** Nothing
  between the sheet and the add used to judge it, so a bad name ran the
  pre-create hook before git refused at the end of it.
- **The rules are git's own, in Swift, less the ones about slashes** that apply
  only to a full refname, the sheet asking on every keystroke. A test holds it
  against real git over a table of names.
- **An existing branch is held to the same rules**: the check used to run only
  when creating one, so an API caller with an empty name ran the hook and was
  refused after. Cost: a detached checkout git would have allowed is refused
  too.
- **A bare repository is a project.** The work-tree question answers false for
  one, so the git-dir question is what is asked.
- **A repo hidden inside a folder takes that folder's name.** Cost: the default
  sibling worktree directory then lands inside it.
- **A project is the main worktree whatever was picked**, a linked one listing
  the same worktrees, so two rows would select together and share tabs. Cost:
  the sidebar shows the repo's name, not the folder picked.
- **Runtime state about a worktree is dropped in one place.** Statuses, merge
  verdicts, commit dates, a running operation, a rename field and the removal
  dialog are all keyed by path, and the store returns what it discarded.
- **A collection added later registers there.** It was pruned at whichever site
  last bit, and the dialog was the one missed: a worktree removed outside the
  app left its dialog up, and Confirm ran a removal on a path git no longer
  listed.
- **A watcher tick names its directories.** Every tick used to re-read every
  project's records and re-arm every watch, for a comparison that almost always
  came out equal.
- **Now the records check runs only for the project whose common `.git` holds a
  directory that fired.** An empty list, which a return to the foreground sends,
  is still every project.
- **Watches are re-armed only after a project was actually refreshed**: a tick
  whose records compared equal added no directory worth watching.
- **A slow `git status` is asked for less often.** On a monorepo one read every
  few seconds kept the disk busy for as long as the app was in front.
- **The pace is a multiple of how long the last read took**, so the disk spends
  a small fraction of its time on a badge and a quick read is unaffected. The
  badge is shown stale for that long rather than hidden.
- **A prompt in the worktree reads at once where the pace has nothing against
  it**, which is every quick repository; the same rule holds a slow one back,
  terminal output arriving in bursts having otherwise armed that read
  constantly.
- **Only a read that badged a row is remembered.** One thrown away because its
  worktree went would otherwise pace the next read out, which is the stale badge
  the pace exists to avoid.
- **Adaptive rather than a per-project toggle**, so a small repository beside a
  large one loses nothing and nobody has to find a setting. Tests that read
  right after a change opt out.
- **A project whose directory is gone is not polled either**, as its sibling
  polls already did not.
- **The badge counts lines, and only for a dirty worktree.** A dot and a file
  count said something had changed and nothing about how much.
- **Staged and unstaged come from one diff**, with the cached-only form as the
  fallback wherever that call fails, which an unborn HEAD does.
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
- **All of it runs only where status already said the worktree is dirty**, paced
  by the same rule as the status read it follows.
- **The reads are synchronous, so they run detached**: several worktrees are
  read at once, and a dead mount would otherwise hold that many cooperative
  threads.
- **Past a cap the files are not counted at all**, and only those paths become
  strings.
- **The two numbers come from different git calls**: status collapses an
  untracked directory to one entry where the file list names every file inside
  it, so counting the overflow put a huge count on a worktree whose tooltip said
  one entry.
- **Making them agree would mean listing every untracked file on every poll**,
  which costs several times the pipe and the time per worktree, and puts the
  same list into the removal dialog's count.
- **So the entries stay git's and the lines stay a floor**: a new directory of
  source shows its lines, and one nobody gitignored shows the first files' worth
  and no yellow count.
- **The file list runs only where status counted an untracked file**, and the
  runner's forced untracked-files setting keeps a repository's own config from
  talking it out of counting one.
- **A binary file, a mode change and a pure rename have no line for either
  column**, and a zero badge on a plainly changed worktree read as broken. They
  are counted as files instead, shown in the theme's yellow.
- **An untracked file skipped for being binary, empty, too big or gone joins
  them.**
- **An unmerged path is not one of them**: it prints zeroes from the cached
  diff, so a conflict read as a file with no lines, and the filter drops it. The
  tooltip already says it is conflicted.
- **Nor is a row whose two counts are neither numbers nor both dashes**, which
  is not output git produces; read as zeroes it put a yellow count on the badge
  for a line nobody could parse.
- **Settings offers Staged Only**, which counts the index alone and no untracked
  file: what a reviewer is about to see rather than what the tree holds.
- **Staged and unstaged is the default**, an index empty through most of a
  change being a badge that reads zero.
- **Both counts are drawn whenever the worktree is dirty**, zeroes included: a
  badge changing shape as the index fills was read as the indicator being
  broken.
- **Cost: two or three git calls a dirty worktree where there was one**, and the
  yellow dot is gone, so which kind of change a file holds lives only in the
  tooltip.
- **Changing the setting invalidates the read log**, and a read already in
  flight lands on nothing: it counted what the badge no longer means, and its
  cost would pace the read that does out.
- **One actions menu serves the detail header, the sidebar and a board card**,
  the last under a heading naming the worktree, since the card carries a Clear
  Status of its own and two unlabelled ones would read alike.
- **New Worktree always opens, even with nothing selected**, and its decisions
  are a tested value because a cancelled branch load once re-enabled Create
  against the wrong project. Its picker offers local branches only.
- **The sidebar filter is folded behind a glass in the header.** Standing open
  it cost a row of height in every session to a control reached in few of them.
- **Closing it clears the text**, so rows are never missing with nothing on
  screen saying why, and Escape closes rather than empties.
- **Closing hands the keyboard to the active pane**, or first responder drops to
  the window and typing reaches nothing. Cost: the filter is a click further
  away, with no keyboard route to it (BUGS.md).
- **A worktree's dot is the most urgent state among its tabs**, a project's
  among its worktrees: failed, waiting, working, done, idle.
- **Failed above waiting**, where it was below: a question answered still leaves
  the failure. Done needs one finished tab, not all of them. Idle only when
  every tab is.
- **A report naming only a directory**, from a terminal outside the app, is one
  more state in the worktree's set.
