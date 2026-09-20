# Hooks and file lists

What runs when a worktree is created or removed, and what is copied in. Newest
at the bottom.

- **A hook is a shell script, context in env vars**, so nothing needs quoting.
  Only a pre hook can refuse.
- **Login and interactive.** A Finder-launched app's bare PATH fails
  `npm install` on Homebrew or a version manager. `set -e` after the rc files.
  Cost: startup time, stderr noise under `-i`.
- **It runs in the pane, not a modal**, which would hold the window. A failed
  one holds its worktree until Dismiss.
- **Stopped through ProcessStopper**: SIGHUP to the process group then SIGKILL.
  Interactive shells ignore SIGTERM, and a shell with no terminal does not pass
  SIGHUP on.
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
- **Containment twice, for a repo's list only.** Lexically, so `$HOME/x`, a
  leading `/` and every `..` are refused rather than skipped for not existing;
  then against the disk, every folder on the way and the path's end.
- **A symlink named by an entry is refused**, since `copyItem` copies the link
  rather than following it. One inside a listed directory is kept, git having
  checked it out anyway.
- **A user's list is used as written** (settings.md), bar the destination, which
  mirrors the entry: one landing outside the worktree places nothing, quietly.
- **Lists and hook are one pane operation in stages**, begun once the worktree
  exists. A failed list stops what follows; Cancel waits for the file in flight
  then ends the lot.
