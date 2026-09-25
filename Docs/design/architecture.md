# Architecture

What the core is, what it refuses, how work reaches it. Newest at the bottom.

- **Core owns what exists, the GUI how it looks.** The engine owns the pty, so
  core never sees a descriptor, a byte stream or a view. Cost: `public` on every
  type a frontend reads, one `Platform` per frontend.
- **Runtime state lives in AppModel, in a library not the Mac app**, so a second
  frontend need not copy it out.
- **Reconcile, don't command.** One path for tab open and close, worktree or
  project removed, process exited, relaunch. Cost: a session that fails to open
  is removed after, not prevented.
- **One `reconcileSessions(takingFocus:)`, and only a user's action passes
  focus.** A refresh runs from the watcher, so focusing there would take the
  keyboard off whatever is being typed.
- **A refresh still reconciles.** Without it a worktree removed outside the app
  keeps its surfaces and its shells run on unreachable.
- **Identity is the path.** A minted id would change under persisted selection.
  Cost: moving a repository is a new project.
- **Shell out to git.** libgit2's worktree support is its worst part, gitoxide's
  incomplete, porcelain a stable contract. Cost: git must be installed.
- **git is looked up twice**, on the process's own PATH at launch and on the
  login shell's once that environment lands. Launch does not wait on the login
  shell, and the process's PATH from the Finder misses Nix and version managers.
- **The login shell's PATH rides on the runner**, so `git-lfs`, credential
  helpers and diff drivers are found too. Hence the coordinator is rebuilt when
  the environment lands even if launch found git.
- **Apple's `/usr/bin/git` is looked past once the environment lands**, through
  `xcrun --find git`: the shim finds that git again on every call, about 3.6 ms
  each, 180 ms a tick at 50 worktrees. Launch keeps the shim, not to run xcrun
  on the main thread. Cost: a changed Xcode is not seen until the next capture.
- **xcrun is not asked where no developer directory exists**, judged off the
  disk in xcrun's own order. With no tools it may raise their install dialog,
  and before the lookup a Mac with no projects ran no git at all.
- **The rebuilt coordinator keeps the launch one's line counts and merge
  slots**: merge reads still in flight hold the old slots, and a fresh set let
  sixteen git processes run where the width is eight.
- **Nothing in the core blocks a thread.** Waits inside `Task`s held a pool
  thread per core until GCD ran out and the suite hung.
- **The directory check before a shell starts is the one wait**, a second at
  most on the main thread and never on a pool thread; worktrees.md has why.
- **Both pipes drain at once**, or the second fills its buffer and blocks the
  child. EOF counts as arrived shortly after the exit, a backgrounded server
  holding them open.
- **Out of descriptors is an error, never an empty answer.** At the limit
  `Pipe()` hands back stdin, and `git worktree list` reading as no worktrees
  dropped every tab.
- **Paths are directory URLs always.** A relative worktree path resolved against
  a URL Foundation took for a file lands in the parent.
- **No desktop is named in the core.** Where to lift a refusal comes from the
  platform, and one that never asks answers unavailable, which keeps the page
  from promising a dialog nobody will see.
- **Detection scans the PATH off the main thread.** It is a stat per PATH
  directory per catalogue entry, and each one blocks for the mount's timeout
  where a PATH directory sits on a mount that has gone.
- **Cancelling the task that awaits a child does not end the child.** A
  superseded status refresh cancels its task mid-read, and Subprocess answers a
  cancel with SIGKILL, so a slow `git status` would never land. Only a
  `ProcessStopper` ends a child.
