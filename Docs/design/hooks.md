# Hooks and file lists

What runs when a worktree is created or removed, and what is copied in. Newest
at the bottom.

## A hook is a shell script, only a pre hook can refuse

Context in env vars -> nothing needs quoting. Shell is login _and_ interactive,
or a Finder-launched app's bare PATH fails `npm install` for anyone on Homebrew
or a version manager; `set -e` inside the script, after the rc files. A running
hook shows in the pane, not a modal, which would hold the window. Stopped
through ProcessStopper, never `Process.terminate()`: SIGHUP to the child's
process group then SIGKILL, interactive shells ignoring SIGTERM and a shell with
no terminal not passing SIGHUP to its job. Cost: startup time, stderr noise from
rc files under `-i`, a failed hook holds its worktree until Dismiss.

## A new worktree is given files by a list, not a hook

Copying `.env` in was the post-create hook nearly everyone wrote, at the cost of
a login shell, a timeout and the pane. Lists run between `git worktree add` and
the hook -> both it and the first terminal find the files. Nothing is placed
over what git checked out; a path the repo lacks is skipped.

Two lists: copy gives the worktree its own file, symlink shares the repo's,
which is what `node_modules` wants. Links first -> a path in both ends up the
link. A link is absolute, a relative one pointing at where the worktree sits
today. A name may be a pattern, `*` and `?` within one component, reaching a
leading dot only where the pattern spells the dot, or `*` would take `.git` in.
Bracket expressions left out rather than half-supported.

Both lists run nothing, but they read the reader's own checkout, git-ignored
files included -> a repo shipping one waits for the same yes its hooks wait for
(settings.md). Nothing overwriting a checked-out path is the other half, since a
committed `linkedPaths: src` must not point a worktree's source at the main
checkout. Containment decided twice, and only for a list the repo ships:
lexically first, each entry resolved against the root and required to land under
it, so `~/.aws.json`, `$HOME/x`, a leading `/` and every spelling of `..` are
refused rather than skipped for happening not to exist under the repo; then
against the disk, resolving the deepest existing folder on each path, the
folders on the way, and the path's own end. A symlink named by the entry is
refused, its own end included: `copyItem` copies a link rather than following
it, so the worktree would hold a pointer at whatever it names. One inside a
listed directory is not: it is copied as it stands, which is what git would
check out anyway. A list the user typed is theirs and is used as written
(settings.md), bar the one end that is not theirs: the destination mirrors the
entry rather than being asked for, so an entry landing outside the worktree
places nothing, quietly, rather than failing the stage.

Lists and hook = one pane operation in stages, begun once the worktree exists
rather than under the sheet; a failed list stops the stages after it. Costs: no
`node_modules` of the worktree's own; Cancel lands between paths, so it waits
for the file being copied and ends the whole setup rather than skipping a stage.
