# Worktrees and projects

Discovery, naming, ordering, removal. Newest at the bottom, above "Reviewed and
left as is".

- **Watch every worktree and the common `.git`, and poll only as a backstop.**
  Changes show in about half a second rather than at the next five-second tick.
  The details are at the bottom.
- **Status is polled frontmost only, and for rows in view**: a collapsed
  project's worktrees wait until it opens, bar the main one, whose branch
  catches a checkout, the selected one, any the sidebar filter shows and any on
  the board. While the filter has text it decides alone, so an open project's
  hidden rows wait too, which is why the model holds the filter's text. Opening
  a project reads its rows alone; reading every project's let a few clicks run
  full rounds beside the poll's. A change to the filter's text reads a quarter
  second after typing stops, or the rows it brings back showed what they had
  when hidden until the next tick.
- **A removal reads its worktree first, slow checkout or not, on screen or
  not.** A row's status could be as old as the pace allowed, ten times a slow
  read, and a dialog built on it warned of nothing while Remove deleted the
  edits. A removal that will not ask reads nothing, there being no dialog to
  warn in.
- **A read landing after another removal was asked for, or under a dialog
  already up, opens nothing**: it replaced that dialog, so the click meant for
  one confirmed the other. A click repeated while its read runs starts none.
- **A removal waits three seconds for its read, then asks anyway**, saying the
  changes could not be read rather than showing a count from before the click,
  as it does for a read git refused. `git status` has no timeout, and on a dead
  mount the dialog never came up. The read runs on; a removal asked again waits
  it out rather than start another git on that mount, then reads afresh in the
  time left, the old read having begun before this click. Cost: on a large
  repository a status slower than that opens the dialog without its count.
- **The filter reads only the rows it brings back**, those not polled through
  every keystroke since the pause before: it ran a full round at each pause.
- **A row being read is not read again beside it.** Opening a project or
  filtering re-read rows the poll was already reading. A removal's read and
  `worktrees show` are the exceptions, each having to start after what asked for
  it, and changing the indicator frees every row, the read in flight no longer
  counting. Cost: `worktrees show` runs git every call, past the pace, so a
  script polling it on a slow repository reads as often as it asks.
- **A change seen during that read is read again once it lands**, when the pace
  allows. Dropped, a command finishing mid-read left the badge on what git saw
  before it until the next read due, ten times a slow read.
- **Polled a few at a time.**
- **The app's git reads write nothing**, and the status read forbids optional
  locks, or it takes the index lock and fails the user's own commit. A read that
  wrote under a watched folder would fire the watcher into reading again.
- **A worktree's name is the user's, kept beside the worktrees.** Every refresh
  replaces a project's whole list, so a name written onto the worktree would be
  gone next tick. It is cleared wherever the store forgets a worktree.
- **The branch is never replaced, only demoted**: every git command in that
  directory acts on it, so a row that hid it would lie. The removal dialog names
  the worktree as its row does, and the branch in its body, where what cannot be
  undone belongs.
- **Auto Rename writes the same name Rename does**, from what an agent makes of
  the branch's commits; the branch stays (agents.md).
- **The trunk row holds the top whatever the sort says.** Rows sort in tiers
  first: git's main worktree, a linked worktree on the trunk, the active ones if
  asked for, then the rest. The trunk gets a tier of its own because a bare
  clone's trunk is a linked worktree, and it is what every other row is read
  against.
- **The trunk is the default branch the badges use**, falling back to the usual
  names until the first scan resolves one. Cost: a project on another trunk can
  settle its rows once, seconds after launch.
- **git records no creation date**, so it is the directory's birth time, read
  where the list is made so the parser stays testable on fixture text.
- **Persisted, and kept over a stat that cannot answer**, or a volume that
  blinked would cost a save, a re-render and a row's place.
- **Last commit is runtime state instead**, so a commit does not rewrite the
  workspace. The orders are named for the commit, which is what they measure.
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
- **The two globals are a menu behind a sort glyph beside the sidebar's Projects
  caption**, not a settings row: an order is changed while looking at the rows
  it moves, and the settings window was three clicks away.
- **A project's override stays in its settings**, the only place with room for
  the (i) text. Cost: the help saying the main and trunk rows hold the top is
  only there.
- **The glyph is a mark rather than a control**, badge-sized and dimmer than the
  caption. It uses the strip's plain menu style, since the borderless AppKit one
  draws the image at its own size and tint whatever the label asks
  (tabs-and-groups.md).
- **A removed worktree goes to the Trash**, not `git worktree remove`, which
  refuses a dirty tree and whose force unlinks the files. The one time someone
  removes the wrong worktree is the time that matters.
- **A Trash that refuses falls back to deletion.** Cost: on such a volume the
  recovery the Trash promised is not there.
- **A global setting deletes outright instead**; the Trash stays the default. A
  tree with a large `node_modules` or build output fills the Trash, and emptying
  it takes as long as the move saved. It is about the machine, not the repo, so
  no project overrides it. The dialog and the pane say which it does.
- **Trash and fallback run off the main actor**: a share with no trash folder
  walks a dependency tree for as long as it takes, and the window stood still
  for it.
- **The record is forgotten only after the Trash has the directory.** With it
  still there the record's removal would unlink it, so a Trash that returned
  with the directory in place is a failed removal.
- **A directory that is not the record's checkout is never trashed**: a stale
  record's path may since hold anything, a folder of notes or a clone. git is
  asked for the checkout's top level and common directory; where either differs
  only the record is forgotten, and neither delete hook runs, each being handed
  that path. A record git keeps over such a directory is its own failure, saying
  the directory was left.
- **git failing inside the directory is not proof it is someone else's.** A
  `safe.directory` refusal or a timeout sent a real checkout down the stale
  path, skipping its pre-delete hook. The `.git` file git wrote there decides
  instead, pointing under the project's common directory or not.
- **A stale record is forgotten by deleting its directory under the common
  `.git`**, the one whose `gitdir` names the path, as prune would. The lock goes
  with the directory.
- **A path now holding a `.git` keeps its record**, as prune would: that is
  another repository, and the removal fails saying the directory was left.
- **A record git will neither remove nor prune is its own failure type.**
  Untyped it read as the Trash refusing, and the row came back over a directory
  that had gone.
- **The lock is never taken off before the trash**, so a Trash that refuses
  leaves the worktree as it was, reason and all.
- **Prune is the fallback for a path git cannot match**, no longer the first
  move: it forgets every record whose directory is away, an unmounted drive's
  included, and repair did not bring that one back.
- **Prune's exit is not the answer.** It exits zero whether or not it took this
  record, so the record's removal re-lists and fails if the path is still on
  record.
- **Without that, a failed remove reported a removal that never was**, and the
  caller went on to run the post-delete hook and delete the branch. Nothing else
  in the app deletes a ref on another command's exit code.
- **A list git will not answer, or answers with no worktree at all, counts as
  still on record** for the same reason.
- **Whether a removal asks at all is a global setting**, about the person and
  not the repo, but it still asks about the branch unless a second global
  setting always deletes it, the branch being the one part the sidebar cannot
  undo.
- **The branch goes last, after the post-delete hook**, so a hook that pushes it
  still finds it.
- **The main worktree and a bare repository are refused by the coordinator**,
  not only by the condition that hides the menu item: the call is public and the
  trash step would take `.git` with it.
- **One predicate is read by the menu, the removal request, the command line's
  `worktrees remove` and the coordinator**, so none can part from the others.
- **A missing directory is refused, not worked around.** A shell spawned in one
  silently lands in the home directory.
- **That check waits a second at most**, the stat running off the main actor: a
  click on a dead mount froze the window until the mount timed out. A stat still
  stuck is not joined by another, and the click is refused as not answering.
  Cost: a volume that takes longer to wake is refused once.
- **A project whose directory is gone stays dimmed rather than dropped**, an
  unmounted drive not being reason to delete someone's setup. Its tooltip says
  why; a project that is there but git fails on is reported once.
- **Both ends of a refresh check the project is still listed** before dimming
  it: one removed while its git call was failing was dimmed under a stale id and
  alerted about after it had left.
- **A stage that ends with its worktree gone takes its entry with it.** Stages
  are keyed by path, so an entry outlives its row and a worktree made again at
  that path inherits it.
- **A failure with the worktree gone ends its own entry and says nothing**
  (hooks.md); one with no pane left alerts instead. It once left the entry
  running, which reads as busy: no shell opens there, removal is refused, and
  Cancel finds a stopper already cleared. A removal that has since taken the
  entry keeps it.
- **Forgetting a worktree drops the entry and stops the stage**, as the pane's
  Cancel would: a hook left running in a directory removed in a terminal ran to
  its timeout and then alerted about a worktree that was not there.
- **The worktree list is read NUL-terminated.** git's own documentation calls
  the plain form unsafe for a path holding a newline, whose second half read as
  another attribute, so the row carried a directory that does not exist. A git
  under 2.36 refuses `-z` and is asked for the plain form instead.
- **The container directory is git's to make.** The add makes every leading
  directory and a refused add makes none; creating them first left an empty
  chain behind a taken branch name.
- **The add runs with no timeout**: a checkout takes as long as the repository
  is, and a bound sized for one would cut off another.
- **A new worktree's index is refreshed once, a second after its checkout**,
  while its path is still held and no terminal is open: git trusts no stat data
  from the second an index was written in, and a status that takes no locks
  never writes it back, so every poll re-read the tree, four times slower. It is
  the one write git does outside a user's command. Cost: up to a second on the
  sheet.
- **A Cancel during that wait takes the worktree back**, git having finished:
  the unforced remove, its new branch and the directories it made. Kept, it was
  selected and ran the file lists and the post-create hook of a create the user
  had cancelled. The same goes for a stop that lands as git is exiting.
- **Only where git listed nothing at that path before the add.** An unforced
  remove still forgets a registered worktree whose directory is away, so a stop
  landing on git's refusal of such a path took the user's record with it. An
  existing path is asked about too, git filling an empty directory. Cost: an
  empty directory the user made there goes with the worktree.
- **Listed paths are compared by their real path through the part that exists.**
  Foundation leaves a missing path's `/var` unresolved where git lists
  `/private/var`, so a registered path read as unlisted.
- **What ends one that hangs is the sheet's Cancel**, which reaches git through
  the same stopper the pre-create hook has. git takes back the directory and the
  record but not a new branch, so a stopped add deletes the branch it made where
  no worktree lists it, and the empty directories it made, or the same name
  could not be tried again.
- **A tree still being built wears no badge.** The add writes the record
  directory before checking a file out, and that is what is watched, so a tick
  lands mid-checkout where status counts every file not there yet.
- **So status is skipped while a tree is being written**: every path a running
  add was given, and any worktree with a create's or a removal's stage running.
  A failed stage is not one, nothing writing there until the Dismiss.
- **A claimed path forgets its status and its merged badge**, the last checkout
  there being gone and paths being ids.
- **A stage on a listed worktree keeps both and is asked nothing new**, or a
  removal would blank the very count and landed-branch note its dialog asks
  about.
- **Both merge and status rechecks re-read after their await**, since a stage
  can start under a git call. The end of the add and of each stage schedule the
  reads rather than waiting the poll out.
- **The claim is counted, not a set**: two creates can name one path, and the
  first to end must not let go of what the other is checking out into.
- **A path already listed is not claimed at all**, or a doomed create would
  blank someone's row for the length of its pre-create hook.
- **The add takes its path from the one derivation**, so what the sheet shows,
  what is held back and what is made cannot part. The create handle is one slot,
  the sheet showing one create, and the first of two to end lets go only of its
  own, so the other keeps its Cancel and its steps. A create from the command
  line takes no slot, or the sheet's Cancel would stop that one instead.
- **git's own mark is read too**: the list prints `locked initializing` while an
  add is checking out, which covers an add run in a terminal and a symlinked
  volume, where git lists a path other than the planned one. The claim stays for
  the pre-create hook, before git has written a record. git writes that reason
  in the user's language, so a lock over a checkout whose index is not yet
  written also counts, the index coming last, where the lock is no newer than
  the record's `gitdir`. The add writes the lock first; a user's `worktree lock`
  on a worktree added with `--no-checkout` comes after, and has no index either.
  `add --lock --no-checkout` writes its lock first but nothing beside `.git`, so
  a checkout holding nothing else is not counted. Cost: a user's lock whose
  reason is exactly `initializing` holds the badge back, and an add is counted
  finished for the moment before its first file lands.
- **A lock over ten minutes old is an add that died**: git clears it only on a
  signal it can catch, so a SIGKILL or a power cut left the row badgeless for
  good. Cost: a checkout slower than that is counted mid-way.
- **A project wearing git's mark is listed again every round**: time passing
  changes nothing in the records a watcher tick compares, so the age would
  otherwise be judged only at the next launch. Cost: one `git worktree list` a
  minute while an add runs.
- **A branch name git will reject is refused before anything runs.** Nothing
  between the sheet and the add judged it, so a bad name ran the pre-create hook
  and git refused after.
- **The rules are git's own, in Swift, less the ones about slashes** that apply
  only to a full refname, the sheet asking on every keystroke.
  `GitBranchNameTests` holds it against real git over a table of names.
- **The sheet's field turns unusual characters into dashes as they arrive**, a
  pasted `Admin::UsersController#index` reading `Admin-UsersController-index`.
  Anything but a letter, digit, `.`, `_`, `/` or `-` counts, wider than git's
  list so a `#` goes too; a run of them with the dashes beside it is one dash,
  and a run leading the name is dropped. Dashes typed alone stay. The structural
  rules, `..` or a trailing `.`, are left to the warning, since a name half
  typed breaks them. Trailing spaces stay until a word follows, since a paste
  often ends in one and the trim already drops it. Only the field does this: an
  API caller's name is refused, not rewritten.
- **That field is an AppKit `NSTextField`.** SwiftUI's `TextField` on macOS
  never writes a binding change back into a field being edited, so the fix
  reached the draft while the field still showed `Admin::Users`.
  `NewWorktreeBranchNameFieldTests` types into the real field to hold this. The
  field waits while an input method is composing, and makes the fix through the
  editor's change calls, so one undo takes back a pasted name whole.
- **The field follows its editor's storage while editing.** Undo and redo change
  the text without `controlTextDidChange`, so the draft kept a name the field
  had stopped showing, and Create would have made it. The old SwiftUI field did
  the same.
- **An existing branch is held to the same rules**: the check ran only when
  creating one, so an API caller with an empty name ran the hook and was refused
  after. Cost: a detached checkout git would have allowed is refused too.
- **A bare repository is a project.** The work-tree question answers false for
  one, so the git-dir question is what is asked.
- **A repo hidden inside a folder takes that folder's name.** Cost: the default
  sibling worktree directory then lands inside it.
- **A project is the main worktree whatever was picked**, a linked one listing
  the same worktrees, so two rows would select together and share tabs. Cost:
  the sidebar shows the repo's name, not the folder picked.
- **Runtime state about a worktree is dropped in one place**, all of it keyed by
  path, and the store returns what it discarded. The session states' worktree
  entries go in the reconcile both callers run next, against the live shells.
- **A collection added later registers there.** Each was pruned at whichever
  site last bit, and the dialog was the one missed: a worktree removed outside
  the app left its dialog up, and Confirm ran a removal on a path git no longer
  listed.
- **A watcher tick names its directories**, and the records check runs only for
  the project whose common `.git` holds one that fired. Launch, a return to the
  front and the round still check every project. Every tick used to re-read
  every project's records and re-arm every watch, for a comparison that almost
  always came out equal.
- **Watches are re-armed wherever a list changes what is watched**, whichever
  read listed it, and when a project that was missing comes back: re-armed only
  after a records check, a worktree the branch check listed first was never
  watched.
- **The watcher resolves its directories off the main actor**: a repository on a
  stalled mount would hold the window until the mount timed out. A stream
  started for an earlier call is stopped and arms nothing.
- **A slow `git status` is asked for less often.** On a monorepo one read every
  few seconds kept the disk busy for as long as the app was in front.
- **The pace is a multiple of how long the last read took**, so the disk spends
  a small fraction of its time on a badge and a quick read is unaffected. The
  badge is shown stale for that long rather than hidden.
- **A change in the worktree reads at once where the pace has nothing against
  it**; the same rule holds a slow one back, where bursts of changes would
  otherwise arm that read constantly.
- **Only a read that badged a row is remembered.** One thrown away because its
  worktree went would pace the next read out, which is the stale badge the pace
  exists to avoid.
- **Adaptive rather than a per-project toggle**, so a small repository beside a
  large one loses nothing and nobody has to find a setting. Tests that read
  right after a change opt out.
- **A project whose directory is gone is not polled either**, as its sibling
  polls already were not.
- **The badge counts lines, and only for a dirty worktree.** A dot and a file
  count said something had changed and nothing about how much.
- **A badge out of room drops its file count, then its arrows**, the tooltip
  naming both. The name truncates first: `+12345 −6789 ~12 ↑3 ↓2` needed 229.5
  pt of a 164 pt row at the narrowest sidebar and overflowed it.
- **Staged and unstaged come from one diff**, with the cached-only form as the
  fallback wherever that call fails. Before the first commit it counts from the
  empty tree, whose id `hash-object` gives without writing it: the cached form
  there counted a staged file's staged lines and none added since. Only an
  unborn HEAD gets the empty tree, or a failed read would badge the whole
  checkout as added.
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
- **One actions menu serves the detail header, the sidebar and a board card**,
  the last under a heading naming the worktree, since the card carries a Clear
  Status of its own and two unlabelled ones would read alike. Its pull request
  and CI items come and go with what the services say (services.md).
- **New Worktree always opens, even with nothing selected**, and its decisions
  are a tested value because a cancelled branch load once re-enabled Create
  against the wrong project. Its existing-branch picker offers local branches
  only.
- **The sidebar filter is tucked behind a glass in the header.** Standing open
  it cost a row of height in every session to a control reached in few of them.
- **Names are folded per keystroke, not kept folded**: a folded copy searched
  with `contains` parts from a folded `range(of:)` on some letters, ß for one,
  and the whole filter measured 0.05 ms at 40 rows.
- **Closing it clears the text**, so rows are never missing with nothing on
  screen saying why, and Escape closes rather than empties.
- **Closing hands the keyboard to the active pane**, or first responder drops to
  the window and typing reaches nothing. Cost: the filter is a click further
  away, with no keyboard route to it.
- **While the filter has text it holds every project it shows open**, and the
  chevron says so. A click collapses the project for that text alone, as Xcode's
  navigator does, and leaves the stored flag for after the filter. Reading the
  flag, the chevron pointed right over open rows and its click moved nothing.
- **A collapse lasts until the text changes**, being about the rows that text
  found. Rows a text change brings back out of a collapse are read, as those it
  brings back out of hiding are.
- **Whether the field is up is the model's, as its text is**, and only closing
  takes it down. Held by the view, a reopened window showed the field for the
  text left in the model, and emptying that text removed the field with the
  keyboard in it.
- **A worktree's dot is the most urgent state among its tabs**, a project's
  among its worktrees: failed, waiting, working, done, idle.
- **Failed above waiting**, where it was below: a question answered still leaves
  the failure. Done needs one finished tab, not all of them. Idle only when
  every tab is.
- **A report naming only a directory**, from a terminal outside the app, is one
  more state in the worktree's set.
- **The New Worktree sheet asks whether the first tab starts an agent.** The
  switch starts where auto-start on creation stands for that project, its file
  and the global counted; off hides the agent and the task.
- **The sheet's answer stands over the create settings**: on, the agent opens
  even where no terminal opens on create, the switch having asked for one; off,
  a shell opens only where that setting says.
- **The answer waits with the held-back tab**, through the file lists and the
  post-create hook, or a failed stage's Dismiss, and is dropped with the
  worktree's other runtime state.
- **With no agent to offer the sheet gives no answer**, and the create settings
  decide as they did before it asked. Answering "shell" there turned auto-start
  off for every worktree created before the PATH scan had answered.
- **A stand-in agent gives way to the project's own when the PATH scan offers
  it**; a pick the user made stays while offered. Before the scan only a typed
  custom command is offered, so the sheet started it in place of Claude.
- **A single row's status read checks the branch as the round does.** It dropped
  the branch it had just read, so a checkout in the main worktree kept the old
  name until the next round.
- **FSEvents watches every worktree folder and each project's common `.git`,
  recursively**, replacing a kqueue watch of git's worktree records and a
  five-second status poll. Edits, a checkout, a commit, a stash and a fetch show
  in about half a second: 150 ms for FSEvents to gather a burst, 250 ms for the
  burst to settle, then git.
- **One stream for everything, so no folder needs a descriptor.** kqueue fires
  only for a directory's direct children, and a descriptor per folder of a
  source tree would run out of the 256 a GUI app is given.
- **A change is reported as the directory holding it**, or as the entry itself
  at the top of a watched directory, within the deepest watched directory, so a
  change in `.git` belongs to the git directory and not the worktree around it.
  Deep enough to ask git whether the directory is ignored; files within one
  directory fold into one report.
- **A change in `.git` reads every row of that project and its branch scan**: a
  ref, the index, `HEAD` or `packed-refs` can move any row's branch, arrows or
  landed badge.
- **Only `HEAD`, `index`, `refs`, `packed-refs`, `reftable`, `config`, `info`,
  `worktrees`, `modules` and `config.worktree` count**, and no `.lock` anywhere
  under `.git`. The rest is a command's scratch: `objects` and `logs` change
  beside a ref that says the same, `FETCH_HEAD` is all a fetch that finds
  nothing writes, and an editor's auto-fetch re-read every row every few minutes
  for it. A fetch that brings a commit moves a ref and still reads.
- **The stream reports files, not directories**, since `FETCH_HEAD` and `HEAD`
  share one. A `.lock` keeps its whole path where every other change is folded
  to its directory: a fetch that finds nothing locks each remote ref and lets
  go, which folded into `refs/remotes` read as the ref moving. Lock files in a
  worktree, `Cargo.lock` and `yarn.lock`, are files like any other there. A
  `.gitignore` keeps its whole path too, so a nested one changing is seen.
- **Routing standardizes each path once.** Comparing URLs restandardized both
  sides of every pair: 5,000 directories against 10 projects of 3 worktrees took
  0.71 s of the main actor in a debug build, 0.18 s once each was kept. The
  themes check and the worktree records' check read the same match, built once a
  batch and again only where the awaits between changed the rows.
- **A change in a worktree's files reads that worktree alone**, the deepest one
  holding it, since linked worktrees can sit inside the main one.
- **No status read is closer than a second to the last**, and a slow one sets
  its own longer gap as before.
- **A burst is never pushed back by the next change**: the read runs a quarter
  second after the first, or a build writing continuously would hold the badge
  for its whole length. A read the pace holds back waits until it is due rather
  than being dropped, the five-second tick reading only shares and merge
  re-asks.
- **Badges are read frontmost only, as before**; a return to the front reads
  everything, and a row the pace holds back then is read once it allows, as on
  opening a project. Without that, a change made in the background waited for
  the backstop. A read queued in front and due after the app leaves it does not
  run. git's records are still compared in the background, a new worktree being
  a row.
- **Terminal output, a retitle and a finished command read no git now.** The
  file event covers each, and a spinner's retitles or a streaming log armed a
  read for nothing.
- **A sixty-second poll stays as the backstop**, for what no event reports, such
  as an add's lock growing old. A dropped batch counts as a change to everything
  watched.
- **A worktree on a volume that is not local is read every five seconds too**,
  as every worktree was before: FSEvents reports only what this Mac writes to a
  share, not what another machine does. Its branch scan and records wait for the
  round. Which worktrees those are is asked when the watcher is armed, off the
  main actor.
- **The line count against `HEAD` is `diff-index`, not `diff`.** `diff HEAD`
  writes refreshed stat data into a new index whenever a tracked file was only
  touched, `--no-optional-locks` or not, and the watcher read the app's own
  write as a change. `diff-index` counts the same at the same cost and writes
  nothing; a file only touched is left out of its `--numstat`.
- **No git command the app runs by itself may write under `.git`.** A write
  there is a change event, and the event schedules the read that wrote it again,
  once a second for as long as the app is in front. The reads that run on an
  event or the poll are `rev-parse`, `worktree list`, `status`, `diff-index`,
  `diff --cached`, `hash-object` without `-w`, `ls-files`, `check-ignore`,
  `for-each-ref`, `branch --merged`, `log -g`, `cherry`, `rev-list`, `cat-file`
  and `diff` between two commits; none writes.
  `everyReadTheAppRunsByItselfLeavesGitsDirectoryAsItWas` calls each on a
  repository with a touched, a changed, a staged and a new file and compares
  every file under `.git` before and after; a new read joins it.
- **git's file monitor is the exception git makes for us**: with
  `core.fsmonitor` on, every query writes a cookie under the git directory it
  ran in: `.git/fsmonitor--daemon/`, or the same under a linked worktree's
  `worktrees/<name>/` or a submodule's `modules/<path>/`, or an embedded
  repository's own `.git` in the worktree, which the outer status recurses into.
  A path through any `fsmonitor--daemon` entry there calls for no read, and the
  watcher keeps those names whole, or the directory and socket a monitor makes
  as the app's read starts it would read as their parent, once per start.
  Turning the monitor off for the app's reads would end the write but cost the
  speed-up on the large repositories that turn it on.
- **What writes does so once, on a request**: add, remove, prune, a branch
  delete and Fetch, each followed by one round of reads that write nothing. The
  one write the app makes unasked is the index refresh a second after a create,
  once per worktree.
- **A change in a git directory inside another's is the inner project's.** A
  submodule added as a project keeps its git directory under the outer one's
  `modules/`, and the first match a dictionary yielded picked between them.
- **The counts pin renames and the diff algorithm**, so two people with the same
  app settings see the same numbers: a personal `diff.algorithm=histogram` read
  an edit Myers counts +1 −6 as +8 −13 in `diff --cached`, which follows it
  where the plumbing `diff-index` does not, and `status.renames` decided whether
  a `git mv` was one file or two. A move is a file gone and a file added.
- **The algorithm is a global setting, Histogram by default**, the user's choice
  over git's own Myers. It is about the person reading the badge, not the
  repository, so no project overrides it, and a change re-reads every badge as
  the indicator's does.
- **A change belongs to the deeper of the git directory and the worktree holding
  it**: `.git` sits in the main worktree, and a bare repository's worktrees can
  sit in its git directory, whose edits were read as git's scratch and dropped.
- **A re-arm keeps the stream it replaces delivering until `stop`.** The new
  stream starts after its paths resolve and reports nothing from before, so a
  change in that window lived only in the old stream's batch, which was being
  dropped. A change reported twice costs a coalesced read.
- **A re-arm overtaken while it awaited arms nothing**: landing last with the
  older list, it left a new worktree unwatched until the next re-arm.
- **A queued read waits again if the pace moved while it slept.** A forced read
  begun before the change and landing in that wait moved it on, and the read it
  then refused was the change's own.
- **Opening the board reads the rows only it shows**, as opening a project does:
  a worktree in a collapsed project with a live shell went unread while hidden,
  and the card wore that until the round.
- **Cost: a change to the user's own git config or global excludes file waits
  for the sixty-second round.** Both sit outside every repository, and watching
  `~/.gitconfig`'s directory would be watching the home folder.
- **A change only under directories git ignores reads no status**: `npm install`
  filling `node_modules`, or a dev server writing its build, read the row once a
  second for as long as it wrote. `git check-ignore` is asked once per
  directory, the shallowest unanswered first, and the answers are kept per
  worktree. Cost: an ignored file beside tracked ones below the worktree's top,
  `src/debug.log` or a nested `.DS_Store`, still reads, changes there being
  reported by the directory holding them.
- **The watcher still reports those changes**, filtered only where a status read
  is decided: the Files panel and a file tab show an ignored file change. Cost:
  an install's events still reach the main actor, a dictionary lookup per
  directory once git has answered.
- **A directory holding a tracked file is not ignored**, as git says, however
  deep the file, so a force-added file under `node_modules` still reads. Any
  `.gitignore` in a worktree changing forgets that worktree's answers; any
  change to the project's git state forgets its worktrees', since `info/exclude`
  or a file forced into the index changes what git ignores. A return to the
  front and the round forget them all, the global excludes file raising no
  event.
- **An answer is kept only for a path that exists.** git matches `node_modules/`
  against nothing while the directory is gone, as between `npm ci` removing it
  and the install, and that answer kept read the whole install. A negated
  `!/gen/` goes wrong the other way, reading ignored.
- **The Files panel's worktree is read on its events while the window shows**,
  front or not, so coming back never shows a stale list; its listing re-reads on
  its project's git changes, never because a count moved (files.md). Other rows
  keep the frontmost-only reads.
- **A tracked file forced in under an ignored folder still reads on an edit**,
  the folder holding a tracked file not being ignored, as git says
  (`anEditToAFileForcedInUnderAnIgnoredFolderIsRead`).
- **Adding a project, or Refresh on one, reads its badges and branches at
  once.** Its rows' files were written before the watcher armed, so no event
  brings them, and the round is a minute off: an added project showed no badge
  for up to a minute.
- **Each worktree with shells holds a block of ports**, so dev servers in two
  worktrees, or two projects, never collide. Blocks are unique across projects,
  the ports being the machine's. A project counts up from `MULTISHELL_PORT`.
- **Unique within one copy of the app only.** A debug build keeps its own state
  file, so it hands out 3000 again beside the installed app. Cost: a debug
  build's servers stay clear only under a starting port of its own.
- **The block is stored as an index from a global start**, not as a port, so a
  change of start or size moves every block's ports and no worktree with a port
  changes block. A shell already open keeps its value until reopened, its
  environment set at launch.
- **Kept beside the worktrees, as a name is**, and dropped wherever the store
  forgets one, so a worktree removed outside the app frees its block at the next
  refresh.
- **The lowest free block goes to a worktree the first time a refresh lists
  it**, the main checkout included. A load gives one to every worktree without,
  which is how a state file from before blocks takes them.
- **A bare repository gets none**, having no checkout to run a server in.
- **A block that would end past 65535 is not given**: the variable is unset and
  a caption under the port fields in Settings names every such worktree, live. A
  setting that moves a held block past the end keeps the index and loses the
  port, until a lower block that fits is free and it moves there: otherwise
  removing a worktree freed a block the next new worktree took.
- **What a launching pane was given is dropped at launch**, as mise's state is
  (terminals.md): a debug build started from a pane handed that pane's
  `MULTISHELL_PORT` to every shell and hook given none, its session and socket
  to every hook, whose reports reached the other app, and a custom agent
  command's worktree variables to every pane.
- **A caption, not an alert, for what a setting caused**, chosen 2026-10-24. The
  defaults leave 6,253 blocks, so in practice only a start or size change leaves
  a worktree without a port, and the caption says so where it was changed. An
  alert sharing the one slot every alert uses took four review passes of
  bookkeeping to be neither lost under another nor raised twice.
- **An alert only when a created worktree gets no block**, raised by the create
  and never over another alert, the caption keeping the record.
- **That alert belongs to no command line request.** Filed under the one that
  caused it, a `worktree new` that succeeded answered "refused" and took the
  alert down unread.
- **A stored block no setting could fit is given again on load**, its first port
  being past any start: a hand-edited index of 10^18 overflowed the multiply and
  crashed every launch.
- **The port fields are read tolerantly**, every block being given again on
  load: a value past Int or of the wrong type costs itself, not the sidebar.
- **The pre-create hook gets no port**, the block coming with the refresh after
  `git worktree add`. The post-create hook runs after that refresh, and the
  delete hooks are handed the port before the record goes.
- **A removal's row outlives git's record until the removal ends.** The refresh
  its own `git worktree remove` causes came about 250 ms in, dropped the row and
  so ended the post-delete hook. Kept, the row keeps its pane and Cancel, its
  block, and its place in a project removal, which ends it.
- **Only from the record's removal on.** A pre-delete hook whose worktree goes
  outside the app still ends with its row, as before.
- **A create at a path a removal is running on is refused**, at any stage: from
  the pre-delete hook on, the record can go while the create's own pre-create
  hook runs, and git then adds at a path whose row, entry and port are the
  removal's (`aCreateAtAPathWhoseRemovalIsInItsPreDeleteHookIsRefused`).
- **A worktree re-added outside the app at a kept path takes a fresh block**,
  never the one the removal's hook may be stopping servers on. No worktree takes
  the old block until that removal ends; the first refresh after frees it.
- **Costs of a port read once at launch**: a tab dragged to another worktree
  keeps the old one's port, and a start or size change can give a new shell a
  port an open one still uses, both until reopened. A worktree removed outside
  the app frees its block at once, whatever it left listening; nothing checks.
- **Settings clamps a start or size; `config global` refuses one.** As the hook
  timeout does: a typed field has no refusal to show, and a command line write
  reads back as given or not at all.
- **No UI shows the port**; the variable is enough. Cost: nothing checks whether
  another program already holds a port in the block.

## Reviewed and left as is

Raised by reviews and settled; a review need not raise these again.

- **`select` taking a `turning` closure rather than a typed pane or tab.** A
  menu's New Shell Tab and New Agent Tab open a tab there, which is neither. The
  closure runs before the focus because the focus marks seen the pane it lands
  in, which would otherwise be the tab the user passed over.
- **A control request's `bringIntoView` turning and reconciling itself for a
  worktree in view.** A select there would ask the shared-hooks question and
  note the worktree as recent for a request, not a click.
- **`reveal(pane:)` selecting a worktree already in view where `bringIntoView`
  does not.** A notification click or a board card is the user's own turn to
  that worktree, so it is noted as recent as a row click would be.
- **`reveal`, `bringIntoView` and the switcher's `goTo` as three wrappers over
  `select`.** Each answers a refusal its own way: nothing, a control refusal, or
  a beep with the keyboard handed back.
- **`show(pane:)` beside `reveal(pane:)`.** Show stays inside the selected
  worktree; reveal selects the pane's worktree first, with all a select does.
- **The Editor's Open in Tab and a tab moved to a worktree changing the store
  before `select`.** Each probes the directory just before, so a refusal needs
  the folder to vanish between two calls on the main actor.

### Asked both ways

Reviews have asked for each of these and for its opposite. The side below is
the one kept; a review that would argue the other side need not raise it.

- **A typed pane-or-tab target for `select`, or a closure.** Round 3 asked for
  one entry point that turns before the reconcile; round 4 for a typed target
  instead. The closure stays, as above, since a menu's new tab is neither.
- **`newAgentTab(selecting:)` with one `select`, or one per branch.** Round 6
  asked to branch once on the agent, round 7 to call `select` once. It calls
  `select` once and notes a missing agent in the closure.
- **The menu openers' readiness check: the full rule, or no second probe.**
  Round 4 asked not to probe the directory again after `select`; round 7 to
  reuse `requireShellReady`. They call `isShellReadyBesidesDirectory`, the rule
  without the probe, which `requireShellReady` is built from.
- **Which alert wins the one slot: No agent chosen, or a launch failure.** Round
  5 asked for the no-agent alert to be set last, round 7 for the failure not to
  be lost. The no-agent alert shows, as it answers the user's click, and the
  reconcile logs every launch failure, the one it shows included.
- **One helper for revealing a pane, or each caller its own.** Rounds 5 and 6
  asked to share it; each sharing then drew the next wrapper finding. Board and
  notifications share `reveal(pane:)`; the switcher and control requests keep
  their own refusal handling, as above.
- **The folder-gone tests passing on the code before the fix.** They guard the
  order `select` runs the closure in, not a bug that was there; they stay.
