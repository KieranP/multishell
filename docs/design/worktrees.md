# Worktrees and projects

Discovery, naming, ordering, removal.
Newest at the bottom.

## Watch where git records worktrees, poll everything else

Never the `.git` root once `worktrees/` exists: `git status` rewrites
`.git/index` -> every poll would be a refresh. Status polled instead:
frontmost only, eight at a time, coalesced 250 ms after terminal activity, each
tick comparing records before running git. Timer git reads only, and `git
status` carries `--no-optional-locks`, else it takes `index.lock` and fails the
user's own commit. Cost: a change git makes elsewhere waits for a tick.

## A worktree's name is the user's, kept beside the worktrees

Every refresh replaces a project's whole worktree list -> a name written onto
`Worktree` would be gone next tick. `worktreeNames` is a dictionary on the
workspace, cleared wherever the store forgets a worktree.

Branch never replaced, only demoted: every git command in that directory acts
on the branch, so a row that hid it would lie. Removal dialog names branch and
path in its body, where what cannot be undone belongs.

## The trunk row holds the top, whatever the sort says

WorktreeOrder sorts in bands before sorting within one: git's main worktree,
then a linked worktree checked out on the trunk, then the busy ones if the user
asked, then the rest. The trunk row is what every other worktree is read
against. Two bands, because in a bare clone with its worktrees beside it the
trunk is a linked worktree.

Trunk = `DefaultBranch.branch`, the answer the badges use, falling back to
`main` then `master` until the first scan resolves one. Cost: a `develop`
project's rows can settle once, seconds after launch.

Git records no creation date -> `Worktree.createdAt` = the directory's birth
time, read in `WorktreeService.list` so the parser stays testable on fixture
text alone. Persisted, never re-derived, else a volume that blinked would cost
a save, a re-render and a row's place.

Last commit is runtime state instead, the workspace not being rewritten because
someone committed. The orders are named for the commit because that is what
they measure: a week of uncommitted work does not move a row. Rides the
`for-each-ref` the badges already run, as `%(committerdate:unix)`; git fails a
whole query on an unknown format atom -> `branchRefs` asks again without it when
the first call fails, else an old git would cost every badge.

A worktree with no date sorts last in *both* directions: "oldest created first"
is not a claim that an undated worktree is the oldest. Name breaks ties, and is
the default, being the only order that reads the same everywhere.

"Show active at the top" off by default: a worktree is active while it has a
terminal open or a reported state -> with it on, rows move as agents report in.
Both settings are shippable by a repo and run nothing, and the override form
seeds from `InheritedSetting`, what is actually in force, not the user's global.

## A removed worktree goes to the Trash, not `git worktree remove`

`git worktree remove` refuses a dirty tree, and its `--force` unlinks the
files; the one time someone removes the wrong worktree is the time that
matters. A locked worktree is unlocked first, prune skipping locked records. A
Trash that refuses falls back to deletion; cost: on such a volume the recovery
the Trash promised is not there.

Whether a removal asks at all is a global setting, about the person and not the
repo, but it always asks about the branch, the one part the sidebar cannot
undo. Branch goes last, after the post-delete hook, so a hook that pushes it
still finds it.

## A bare repository is a project

`--is-inside-work-tree` prints `false` for one, `--git-dir` succeeds anywhere
inside. A repo hidden as `proj/.bare` takes the name of the folder holding it;
cost: the default `../{project}-worktrees` then lands inside `proj/`.

A project is the main worktree whatever was picked, a linked worktree listing
the same worktrees -> two rows would select together and share tabs. Cost: the
sidebar shows the repo's name, not the folder picked.

## A missing directory is refused, not worked around

A shell spawned in a missing directory silently lands in `$HOME`. A project
whose directory is gone stays dimmed rather than dropped, an unmounted drive
not being reason to delete someone's setup, and the failure is reported once.

## A stage that ends with its worktree gone takes its entry with it

The create and remove stages are keyed by worktree, and a worktree is its path,
so an entry outlives the row it belonged to: a worktree made again at the same
path inherits it. A stage that finishes clears its entry either way, but one
that fails had nowhere to say so and left the entry running, which reads as
busy. That worktree then opens no shell, refuses removal, and shows a Cancel
whose stopper was already cleared, until the app is relaunched. So a failure
with the worktree gone clears the entry and raises an alert instead, there
being no pane left to put the message on.

## The worktree list is read NUL-terminated

`git worktree list --porcelain -z`, and the parser splits on NUL with an empty
field for the end of a record. git's own documentation calls the plain
porcelain unsafe for a path holding a newline, and it is: the second half of
one reads as another attribute, so the row carried a directory that does not
exist, its status read failed, and the path being the identity meant selection
and the tab store keyed off something git never reported.
