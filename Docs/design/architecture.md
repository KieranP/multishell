# Architecture

What the core is, what it refuses, how work reaches it. Newest at the bottom.

- **Core owns what exists, the GUI how it looks.** The engine owns the pty, so
  core never sees a descriptor, a byte stream or a view. Cost: `public` on every
  moved type, one `Platform` per frontend.
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
- **git comes off the login shell's PATH**, twice: at launch and when the login
  environment lands. The process's own PATH from the Finder misses Nix and
  version managers.
- **That PATH rides on the runner**, so `git-lfs`, credential helpers and diff
  drivers are found too. Hence the coordinator is rebuilt when the environment
  lands even if launch found git.
- **Nothing in the core blocks a thread.** Waits inside `Task`s held a pool
  thread per core until GCD ran out and the suite hung.
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
