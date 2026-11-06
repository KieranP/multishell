# Watching and status reads

The watcher, the poll, which rows are read when, the pace, and the git reads
that write nothing. Newest at the bottom.

- **Status is polled frontmost only, and for rows in view**: a collapsed
  project's worktrees wait until it opens, bar the main one, whose branch
  catches a checkout, the selected one, any the sidebar filter shows and any on
  the board. While the filter has text it decides alone, so an open project's
  hidden rows wait too, which is why the model holds the filter's text. Opening
  a project reads its rows alone; reading every project's let a few clicks run
  full rounds beside the poll's. A change to the filter's text reads a quarter
  second after typing stops, or the rows it brings back showed what they had
  when hidden until the next tick.
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
- **The app's git reads write nothing**, and the status read forbids optional
  locks, or it takes the index lock and fails the user's own commit. A read that
  wrote under a watched folder would fire the watcher into reading again.
- **The worktree list is read NUL-terminated.** git's own documentation calls
  the plain form unsafe for a path holding a newline, whose second half read as
  another attribute, so the row carried a directory that does not exist. A git
  under 2.36 refuses `-z` and is asked for the plain form instead.
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
- **A change in the worktree reads a quarter second later where the pace has
  nothing against it**; the same rule holds a slow one back, where bursts of
  changes would otherwise arm that read constantly.
- **Only a read that badged a row is remembered.** One thrown away because its
  worktree went would pace the next read out, which is the stale badge the pace
  exists to avoid.
- **Adaptive rather than a per-project toggle**, so a small repository beside a
  large one loses nothing and nobody has to find a setting. Tests that read
  right after a change opt out.
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
  `for-each-ref`, `branch --merged`, `log -g`, `reflog show`, `remote -v`,
  `cherry`, `rev-list`, `merge-base`, `cat-file` and `diff` between two commits;
  none writes. `everyReadTheAppRunsByItselfLeavesGitsDirectoryAsItWas` calls
  each on a repository with a touched, a changed, a staged and a new file and
  compares every file under `.git` before and after; a new read joins it.
  `hash-object` runs only before a first commit, so
  `everyCountBeforeTheFirstCommitLeavesGitsDirectoryAsItWas` holds it instead.
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
  delete, Fetch and the push before a new pull request, each followed by one
  round of reads that write nothing. The one write the app makes unasked is the
  index refresh a second after a create, once per worktree.
- **A change in a git directory inside another's is the inner project's.** A
  submodule added as a project keeps its git directory under the outer one's
  `modules/`, and the first match a dictionary yielded picked between them.
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
  deep the file, so a force-added file under `node_modules` still reads
  (`anEditToAFileForcedInUnderAnIgnoredFolderIsRead`). Any `.gitignore` in a
  worktree changing forgets that worktree's answers; any change to the project's
  git state forgets its worktrees', since `info/exclude` or a file forced into
  the index changes what git ignores. A return to the front and the round forget
  them all, the global excludes file raising no event.
- **An answer is kept only for a path that exists.** git matches `node_modules/`
  against nothing while the directory is gone, as between `npm ci` removing it
  and the install, and that answer kept read the whole install. A negated
  `!/gen/` goes wrong the other way, reading ignored.
- **The Files panel's worktree is read on its events while the window shows**,
  front or not, so coming back never shows a stale list; its listing re-reads on
  its project's git changes, never because a count moved (files/panel.md). Other
  rows keep the frontmost-only reads.
- **Adding a project, or Refresh on one, reads its badges and branches at
  once.** Its rows' files were written before the watcher armed, so no event
  brings them, and the round is a minute off: an added project showed no badge
  for up to a minute.
