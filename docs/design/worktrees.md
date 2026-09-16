# Worktrees and projects

Discovery, naming, ordering, removal.
Newest at the bottom.

## Watch where git records worktrees, poll everything else

Never the `.git` root once `worktrees/` exists: `git status` rewrites
`.git/index` -> every poll would be a refresh. Status polled instead:
frontmost only, eight at a time, coalesced 250 ms after terminal activity, a
slow checkout asked less often, each watcher tick comparing the records of the
project whose directory fired before running git. Timer git reads only, and
`git status` carries `--no-optional-locks`, else it takes `index.lock` and
fails the user's own commit. Cost: a change git makes elsewhere waits for a
tick. The pacing and the narrowing are at the bottom of this file.

## A worktree's name is the user's, kept beside the worktrees

Every refresh replaces a project's whole worktree list -> a name written onto
`Worktree` would be gone next tick. `worktreeNames` is a dictionary on the
workspace, cleared wherever the store forgets a worktree.

Branch never replaced, only demoted: every git command in that directory acts
on the branch, so a row that hid it would lie. The removal dialog names branch
and path in its body, where what cannot be undone belongs.

## The trunk row holds the top, whatever the sort says

WorktreeOrder sorts in bands before sorting within one: git's main worktree,
then a linked worktree checked out on the trunk, then the busy ones if the user
asked, then the rest. The trunk is what every other row is read against. Two
bands because in a bare clone with its worktrees beside it the trunk is a
linked worktree.

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
whole query on an unknown format atom -> `branchRefs` asks again without it,
else an old git would cost every badge.

A worktree with no date sorts last in *both* directions: "oldest created first"
is not a claim that an undated worktree is the oldest. Name breaks ties, and is
the default, being the only order that reads the same everywhere.

"Show active at the top" off by default: a worktree is active while it has a
terminal open or a reported state -> with it on, rows move as agents report in.
Both settings are shippable by a repo and run nothing, and the override form
seeds from `InheritedSetting`, what is actually in force, not the user's global.

The two global settings are a menu behind a sort glyph at the right of the
sidebar's Projects header, in the column the rows' + buttons occupy, rather than
a row in Settings > Worktrees: an order is changed while looking at the rows it
moves, and a settings window was three clicks away from them. The menu holds the
five orders as an inline picker and the active-first toggle under a divider; a
project's override stays in its settings, which is the only place with room for
the (i) text. The glyph is badge-sized and dimmer than the caption beside it, a
mark rather than a control. It is the strip's `.button` menu style under
`.buttonStyle(.plain)`, not the detail header's `.borderlessButton`: that
AppKit button draws the image at its own size and tint, so the glyph came out
large and bright whatever the label asked for; see tabs-and-columns.md. Cost:
the help that named the tie-break and where an undated worktree lands is now
only on the override.

## A removed worktree goes to the Trash, not `git worktree remove`

`git worktree remove` refuses a dirty tree, and its `--force` unlinks the
files; the one time someone removes the wrong worktree is the time that
matters. A Trash that refuses falls back to deletion; cost: on such a volume
the recovery the Trash promised is not there. Trash and fallback both run off
the main actor: a share with no `.Trashes` walks a `node_modules` for as long
as it takes, and the window stood still for it.

Once the directory has gone, `git worktree remove --force --force <path>`
forgets that one record, lock and all. The coordinator checks the directory is
gone before asking: with it still there the forget would unlink it, so a Trash
that returned with it in place is a failed removal. The lock is never taken
off before the trash, so a Trash that refuses leaves the worktree as it was,
reason and all.

It was `git worktree prune`, which forgets every record whose directory is
away at that moment, an unmounted drive's included: the drive came back to a
`.git` file naming a gitdir that was gone, and `worktree repair` did not bring
it back. Prune stays as the fallback for a path git cannot match to a record,
the one case it is the only way.

Whether a removal asks at all is a global setting, about the person and not the
repo, but it always asks about the branch, the one part the sidebar cannot
undo. Branch goes last, after the post-delete hook, so a hook that pushes it
still finds it.

The main worktree and a bare repository are refused by the coordinator, not
only by the sidebar condition that hides the menu item: the call is public,
the step that trashes the directory would take `.git` with it, and this is the
operation with no way back. One predicate, `Worktree.isRemovable`, is what the
menu, `requestRemoval` and the coordinator all read, so the two cannot part.

## A missing directory is refused, not worked around

A shell spawned in a missing directory silently lands in `$HOME`. A project
whose directory is gone stays dimmed rather than dropped, an unmounted drive
not being reason to delete someone's setup, and the failure is reported once.

## A stage that ends with its worktree gone takes its entry with it

The create and remove stages are keyed by worktree, and a worktree is its path,
so an entry outlives the row it belonged to: a worktree made again at the same
path inherits it. A stage that finishes clears its entry either way, but one
that fails had nowhere to say so and left the entry running, which reads as
busy: no shell opens there, removal is refused, and Cancel finds a stopper
already cleared, until relaunch. So a failure with the worktree gone ends its
own entry and raises an alert instead, there being no pane left to put the
message on. Its own: a removal that has since taken the entry keeps it. The
store's discard now drops the entry as well, through `forgetWorktrees` below;
the guard stays for a result landing after that.

## The worktree list is read NUL-terminated

`git worktree list --porcelain -z`, and the parser splits on NUL with an empty
field for the end of a record. git's own documentation calls the plain
porcelain unsafe for a path holding a newline, and it is: the second half of
one reads as another attribute, so the row carried a directory that does not
exist, its status read failed, and the path being the identity meant selection
and the tab store keyed off something git never reported.

## The container directory is git's to make

`git worktree add` makes every leading directory of its path, and a refused
add makes none. The app used to `createDirectory` first, so a taken branch
name left an empty chain under a nested `worktreeDirectory`.

## A tree still being built wears no badge

`git worktree add` writes `.git/worktrees/<name>` before it checks a file out,
and that directory is watched -> a tick lands the row mid-checkout, where `git
status` counts every file not there yet. The file lists and the post-create
hook write into the tree after that. Either way a branch a second old read as
thousands of changes.

So `git status` is skipped while `isUnderConstruction`: every path a running
`git worktree add` was given, and any worktree with a stage running. A failed
stage is not one, nothing writing there until the Dismiss.

The two halves treat what was already known differently. A claimed path
forgets its status and its merged badge: the last checkout there is gone, and
paths are ids. A stage on a listed worktree keeps both and is asked nothing
new, as a failed read is kept, or a removal would blank the very count and
"branch landed" note its dialog asks about. `refreshMergeStates` rechecks
after its await as `refreshStatus` does, a stage able to start under a git
call. The end of the add and of each stage schedule the status read and one
merge scan, the poll's own work once over, rather than waiting it out.

The claim is counted, not a set: two creates can name one path, the sheet
reopening under Cmd+N while the last one still runs, and the first to end
must not let go of what the other is checking out into. A path already
listed is not claimed at all, a doomed create otherwise blanking someone's
row for the length of its pre-create hook. `WorktreeCoordinator.add` takes
its path from `plannedPath`, the one derivation, so what the sheet shows,
what is held back and what is made cannot part. `creationStopper` and
`worktreeCreationStep` are still single slots, so under that overlap the
second create's Cancel is lost; recorded in known-gaps.md.

Cost: the planned path is what is compared, not git's answer, so on a
symlinked volume where the two differ the row is badged mid-checkout as before.
Git itself marks the window, `locked initializing` in the porcelain list and
no `index` beside the `locked` file; reading that would cover a terminal-run
add too, and is the fix named in known-gaps.md.

## A branch name git will reject is refused before anything runs

Nothing between the sheet and `git worktree add` used to judge the name, so
`my branch` or `feat.lock` ran the pre-create hook before git refused at the
end of it. `GitRefName` is `check-ref-format`'s rules in Swift, less the ones
about slashes that apply only to a full refname, the sheet asking on every
keystroke and a process per keystroke not being worth it; a
test holds it against real git over a table of names. Create is off for a name
it refuses and the sheet says why, and `WorktreeCoordinator.add` throws before
the hook for a caller that did not ask. An existing branch is held to the same
rules: the check used to run only when a branch was being created, so an API
caller passing an empty or malformed name ran the pre-create hook with
`MULTISHELL_BRANCH` empty and was refused by git after. Cost: `HEAD` or a
remote ref, which git would have checked out detached, is refused too; the
path is for a branch that exists.

## A bare repository is a project

`--is-inside-work-tree` prints `false` for one, `--git-dir` succeeds anywhere
inside. A repo hidden as `proj/.bare` takes the name of the folder holding it;
cost: the default `../{project}-worktrees` then lands inside `proj/`.

A project is the main worktree whatever was picked, a linked worktree listing
the same worktrees -> two rows would select together and share tabs. Cost: the
sidebar shows the repo's name, not the folder picked.

## Runtime state about a worktree is dropped in one place

Statuses, merge verdicts, commit dates, a running operation, a rename field
and the removal dialog are all keyed by worktree path. The store returns what
`replaceWorktrees` and `removeProject` discarded and `AppModel.forgetWorktrees`
drops every one of those for it; a collection added later registers there. It
was pruned at whichever site last bit, and the dialog was the one missed: a
worktree removed outside the app left its dialog up, and Confirm ran a removal
on a path git no longer listed.

## A watcher tick names its directories

Every tick re-read every project's records and re-armed every watch, twelve
detached tasks and a hundred small reads for a comparison that almost always
came out equal. The watcher now hands over the directories that fired, and the
records check runs only for the project whose common `.git` holds one of them;
an empty list, which a return to the foreground sends, is still every project.
The watches are re-armed only after a project was actually refreshed: a tick
whose records compared equal added no directory worth watching.

## A slow `git status` is asked for less often

On a monorepo a large checkout kept the disk busy for as long as the app was
in front, one `git status` every five seconds. `StatusPollPace` remembers how
long each worktree's last read took and does not ask again until ten times
that has passed, so the disk spends at most a tenth of its time on a badge; a
read under half a second is unaffected, ten times it being inside the interval
anyway. The badge is shown stale for that long rather than hidden, and a
prompt in the worktree still reads at once. Adaptive rather than a per-project
toggle, so a small repository beside a large one loses nothing and nobody has
to find a setting. Tests that read right after a change run `.unpaced`. The
missing-project corner was a bug of its own: a project whose directory is
gone had its worktrees polled too, as the two sibling polls already did not.

