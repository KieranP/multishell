# Hooks and file lists

What runs when a worktree is created or removed, and what is copied in.
Newest at the bottom.

## A hook is a shell script, only a pre hook can refuse

Context in env vars -> nothing needs quoting. Shell is login *and* interactive,
or a Finder-launched app's bare PATH fails `npm install` for anyone on Homebrew
or a version manager; `set -e` inside the script, after the rc files. A running
hook shows in the pane, not a modal, which would hold the window. Stopped through ProcessStopper, never
`Process.terminate()`: SIGHUP to the child's process group then SIGKILL,
interactive shells ignoring SIGTERM and a shell with no terminal not passing
SIGHUP to its job. Cost: startup time, stderr noise from rc files under `-i`, a failed
hook holds its worktree until Dismiss.

## A new worktree is given files by a list, not a hook

Copying `.env` in was the post-create hook nearly everyone wrote, at the cost
of a login shell, a timeout and the pane. Lists run between `git worktree add`
and the hook -> both it and the first terminal find the files. Nothing is
placed over what git checked out; a path the repo lacks is skipped.

Two lists: copy gives the worktree its own file, symlink shares the repo's,
which is what `node_modules` wants. Links first -> a path in both ends up the
link. A link is absolute, a relative one pointing at where the worktree sits
today. A name may be a pattern, `*` and `?` within one component, not matching
a leading dot, or `*` would take `.git` in. Bracket expressions left out rather
than half-supported.

Both lists run nothing -> a repo may ship them untrusted; nothing overwriting a
checked-out path is the other half, since a committed `linkedPaths: src` must
not point a worktree's source at the main checkout. Containment decided against
the disk, not the spelling: deepest existing folder on each path is resolved
and checked, catching `..`, a leading `/` or `~`, and a folder that is itself a
symlink. A symlink at the end of a path is copied as a symlink, never followed.

Lists and hook = one pane operation in stages, begun once the worktree exists
rather than under the sheet; a failed list stops the stages after it. Costs: no
`node_modules` of the worktree's own; Cancel lands between paths, so it waits
for the file being copied and ends the whole setup rather than skipping a stage.
