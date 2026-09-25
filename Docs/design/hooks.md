# Hooks and file lists

What runs when a worktree is created or removed, and what is copied in. Newest
at the bottom.

- **A hook is a shell script, context in env vars**, so nothing needs quoting.
  Only a pre hook can refuse.
- **Login and interactive**, or interactive alone for csh and tcsh, which refuse
  `-l` beside `-c`, so the rc files set the environment: a Finder-launched app's
  bare PATH fails `npm install` on Homebrew or a version manager. With `$SHELL`
  unset it is zsh, as a terminal's is. Cost: startup time, stderr noise under
  `-i`, no `.login` for csh.
- **The script is sh, which that shell `exec`s**, the text passed in
  `MULTISHELL_SCRIPT` and unset before it runs: csh takes no newline inside
  quotes, and an interactive csh expands a `!` in them. So a hook reads alike
  under every login shell, zsh's unmatched glob no longer ends it, and `set -e`
  stops it at the first failing line where fish and csh had none. A `cd` back to
  its directory comes first, as an rc file may leave the shell anywhere. Cost:
  only exported variables reach it; an rc file's functions and aliases,
  `nvm use` among them, do not. A shell that would refuse the flags, nu or
  xonsh, is passed over for `/bin/sh` alone, with no rc files. An editor's shim
  run in the background goes the same way.
- **No history file.** An interactive shell takes an inherited `HISTFILE` for
  its own: bash truncated a zsh user's history to its rc file's size, and ksh
  rewrote it in its format, a few bytes long. So hooks and the login capture run
  with it empty, and an rc file naming the shell's own still names it.
- **It runs in the pane, not a modal**, which would hold the window. A failed
  one holds its worktree until Dismiss. Pre-create has no worktree yet, so it
  runs under the sheet, whose Cancel stops it.
- **Stopped through ProcessStopper**: SIGHUP to the process group then SIGKILL.
  Interactive shells ignore SIGTERM, and a shell with no terminal does not pass
  SIGHUP on. The SIGKILL is held back only where the group's leader started
  after the hangup, the pid being free for reuse once the group empties.
- **Age alone does not decide it**: a hook's HUP trap can start a child, as
  young as a stranger's. Cost: a stranger's group whose own leader has already
  exited is killed, which needs a pid wrap inside the three-second grace.
- **Files come from a list, not a hook.** Copying `.env` in was the post-create
  hook nearly everyone wrote, at the cost of a login shell and a timeout.
- **Lists run between `git worktree add` and the hook**, so the first terminal
  finds the files. Nothing is placed over what git checked out.
- **Two lists**: copy for a file of the worktree's own, symlink for the repo's,
  which is what `node_modules` wants. Links first, so a path in both is a link.
- **A link is absolute.** A relative one points at where the worktree sits
  today.
- **A name may be a pattern**, `*` and `?` within one component, reaching a
  leading dot only where spelled, or `*` would take `.git`. No bracket
  expressions.
- **A repo's list waits for the same yes its hooks wait for** (settings.md): it
  reads the reader's checkout, git-ignored files included.
- **Containment twice refuses, for a repo's list only.** Lexically, so `~/x`,
  `$HOME/x`, a leading `/` and a `..` that climbs out are refused rather than
  skipped for not existing; then against the disk, every folder on the way and
  the path's end. A user's list gets the lexical check and the destination's,
  and is named, not refused (below).
- **A symlink named by an entry is judged by where it leads**, since `copyItem`
  copies the link rather than following it: one leading out is refused, one
  staying inside is placed. One inside a listed directory is kept, git having
  checked it out anyway.
- **A user's entry naming somewhere else is named, not refused**: `~/x`,
  `$HOME/x` or `../x` places nothing, and once the rest are placed an alert
  lists them and the post-create hook still runs. Silent, the entry read as
  working; refused, one typo cost the hook.
- **Where a later list fails, they are named in its failure**, not in an alert
  of their own: there is one alert, and the failure's took it. A Cancel still
  names them, the typo being no less one for the stop.
- **Lists and hook are one pane operation in stages**, begun once the worktree
  exists. A failed list stops what follows; Cancel waits for the file in flight
  then ends the lot, a copied directory being copied file by file so that its
  next file is where Cancel lands. The half copied is taken away, after a Cancel
  or a file it could not read, or it reads as placed and nothing places over it.
  No timeout: a list is no shell to wedge, and a large one takes as long as its
  files.
- **A hook runs in the worktree only where one exists at its stage**, since in a
  missing directory it fails at its `cd`. Pre-create and post-delete run in the
  repository, as does the pre-delete of a worktree removed by hand.
