# Creating and removing worktrees

Creation, the New Worktree sheet, removal, and the stages around both. Newest at
the bottom.

- **A removal reads its worktree first, slow checkout or not, on screen or
  not.** A row's status could be as old as the pace allowed, ten times a slow
  read, and a dialog built on it warned of nothing while Remove deleted the
  edits.
- **A read landing after another removal was asked for, or under a dialog
  already up, opens nothing**: it replaced that dialog, so the click meant for
  one confirmed the other. A click repeated while its read runs starts none.
- **A removal waits three seconds for its read, then asks anyway**, saying the
  changes could not be read rather than showing a count from before the click.
  `git status` has no timeout, and on a dead mount the dialog never came up. A
  removal asked again waits the old read out rather than start another git on
  that mount. Cost: on a large repository a status slower than that opens the
  dialog without its count.
- **A removed worktree goes to the Trash**, not `git worktree remove`, which
  refuses a dirty tree and whose force unlinks the files. The one time someone
  removes the wrong worktree is the time that matters.
- **A Trash that refuses falls back to deletion.** Cost: on such a volume the
  recovery the Trash promised is not there.
- **A global setting deletes outright instead**; the Trash stays the default. A
  tree with a large `node_modules` or build output fills the Trash, and emptying
  it takes as long as the move saved. It is about the machine, not the repo, so
  no project overrides it.
- **Trash and fallback run off the main actor**: a share with no trash folder
  walks a dependency tree for as long as it takes, and the window stood still
  for it.
- **The record is forgotten only after the Trash has the directory.** With it
  still there the record's removal would unlink it, so a Trash that returned
  with the directory in place is a failed removal.
- **A directory that is not the record's checkout is never trashed**: a stale
  record's path may since hold anything, a folder of notes or a clone. Only the
  record is forgotten, and neither delete hook runs, each being handed that
  path.
- **git failing inside the directory is not proof it is someone else's.** A
  `safe.directory` refusal or a timeout sent a real checkout down the stale
  path, skipping its pre-delete hook. The `.git` file git wrote there decides
  instead, pointing under the project's common directory or not.
- **A stale record is forgotten by deleting its directory under the common
  `.git`**, the one whose `gitdir` names the path, as prune would.
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
- **Force Deletion uses `-D` only while the branch is where git refused it**:
  one that gained a commit while the alert stood is judged by `-d` again, and
  the alert comes back saying what it holds now.
- **A create asks for its project again after each wait before git runs**: a
  project removed while it checked for a running removal stopped no create, none
  having begun, and git made the branch for nothing.
- **The branch goes last, after the post-delete hook**, so a hook that pushes it
  still finds it.
- **The branch the repository's `HEAD` names is never deleted**, and neither the
  dialog nor `worktrees remove --delete-branch` deletes the default branch. A
  bare clone's `HEAD` is a branch no checkout holds, and `branch -d` measures
  merged against `HEAD`, so removing the trunk's worktree deleted `main` with
  its unpushed commits. `HEAD` is read as a full refname:
  `rev-parse --abbrev-ref` says `heads/main` beside a tag `main`, which the
  guard took for another branch. A failed read deletes no branch, as it once let
  the delete through.
- **A worktree holding another worktree, or a populated submodule with work, is
  refused.** The Trash took the inner worktree's uncommitted files, and the
  record took the submodule's repository, kept under it, with its unpushed
  commits. Work is a change, an untracked file, or a commit on none of the
  submodule's remotes, a stash's included, at any depth. Populated, as git
  judges it: a `.git` in the submodule's folder.
- **A submodule holding nothing else is let through, not deinitialised.**
  `worktree remove` refuses any populated submodule, so every worktree of a repo
  with one, Ghostty here, needed `git submodule deinit --all` first. The Trash
  takes the submodule's files with the rest, ignored build output included,
  which `deinit` would delete for good, and before a pre-delete hook that may
  still fail.
- **A detached worktree's commits on no branch are read before removing it**,
  and the dialog asks about them even with confirmation off. Its record holds
  the only `HEAD` and reflog, so `worktree remove` leaves them dangling.
- **The main worktree and a bare repository are refused by the coordinator**,
  not only by the condition that hides the menu item: the call is public and the
  trash step would take `.git` with it.
- **A stage that ends with its worktree gone takes its entry with it.** Stages
  are keyed by path, so an entry outlives its row and a worktree made again at
  that path inherits it.
- **A failure with the worktree gone ends its own entry and says nothing**
  (hooks.md). It once left the entry running, which reads as busy: no shell
  opens there, removal is refused, and Cancel finds a stopper already cleared.
- **Forgetting a worktree drops the entry and stops the stage**, as the pane's
  Cancel would: a hook left running in a directory removed in a terminal ran to
  its timeout and then alerted about a worktree that was not there.
- **The container directory is git's to make.** A refused add makes none;
  creating them first left an empty chain behind a taken branch name.
- **The add runs with no timeout**: a checkout takes as long as the repository
  is, and a bound sized for one would cut off another.
- **A new worktree's index is refreshed once, a second after its checkout**,
  while its path is still held and no terminal is open: git trusts no stat data
  from the second an index was written in, and a status that takes no locks
  never writes it back, so every poll re-read the tree, four times slower. It is
  the one write git does outside a user's command. Cost: up to a second on the
  sheet.
- **A Cancel during that wait takes the worktree back**, git having finished.
  Kept, it was selected and ran the file lists and the post-create hook of a
  create the user had cancelled. The same goes for a stop that lands as git is
  exiting.
- **A row whose create still runs cannot be removed**: git lists it before its
  checkout ends, and a removal then trashed the directory git was writing. git's
  own `initializing` mark counts too, so an add run in a terminal is held the
  same way.
- **Removing a project stops its creates**, a command line's too: left running,
  the add landed a worktree nothing in the app lists.
- **A stopped add takes back only a worktree git listed nowhere at that path
  before.** An unforced remove still forgets a registered worktree whose
  directory is away, so a stop landing on git's refusal of such a path took the
  user's record with it. Cost: an empty directory the user made there goes with
  the worktree, git filling an empty directory.
- **That question ignores case**, as git matches a path it is given under
  `core.ignorecase`, macOS's default: undoing `away` forgot the record of an
  `Away` whose directory was away.
- **A worktree git lists after its add failed is made**: git exits with a
  failing `post-checkout` hook's status once the checkout is done, and the app
  read husky's failed install as a refused create, skipping the file lists, the
  post-create hook and the first tab.
- **Listed paths are compared by their real path through the part that exists.**
  Foundation leaves a missing path's `/var` unresolved where git lists
  `/private/var`, so a registered path read as unlisted.
- **What ends an add that hangs is the sheet's Cancel.** git takes back the
  directory and the record but not a new branch, so a stopped add deletes the
  branch it made where no worktree lists it, and the empty directories it made,
  or the same name could not be tried again.
- **A refused add deletes its new branch too.** git makes the branch before it
  checks the path, so a taken directory, or a slug two branch names share, left
  a branch the user never got a worktree for.
- **A tree still being built wears no badge.** The add writes the record
  directory before checking a file out, and that is what is watched, so a tick
  lands mid-checkout where status counts every file not there yet.
- **So status is skipped while a tree is being written**, by an add or by a
  create's or a removal's stage. A failed stage is not one, nothing writing
  there until the Dismiss.
- **A claimed path forgets its status and its merged badge**, the last checkout
  there being gone and paths being ids.
- **A stage on a listed worktree keeps both and is asked nothing new**, or a
  removal would blank the very count and landed-branch note its dialog asks
  about.
- **Both merge and status rechecks re-read after their await**, since a stage
  can start under a git call.
- **The claim is counted, not a set**: two creates can name one path, and the
  first to end must not let go of what the other is checking out into.
- **A path already listed is not claimed at all**, or a doomed create would
  blank someone's row for the length of its pre-create hook.
- **The add takes its path from the one derivation**, so what the sheet shows,
  what is held back and what is made cannot part. The first of two creates to
  end lets go only of its own, so the other keeps its Cancel and its steps. A
  create from the command line takes no slot, or the sheet's Cancel would stop
  that one instead.
- **git's own mark is read too**: the list prints `locked initializing` while an
  add is checking out, which covers an add run in a terminal and a symlinked
  volume, where git lists a path other than the planned one. git writes that
  reason in the user's language, so a lock over a checkout whose index is not
  yet written also counts, where the lock is no newer than the record's
  `gitdir`. The add writes the lock first; a user's `worktree lock` on a
  worktree added with `--no-checkout` comes after. `add --lock --no-checkout`
  writes its lock first but nothing beside `.git`, so a checkout holding nothing
  else is not counted. Cost: a user's lock whose reason is exactly
  `initializing` holds the badge back, and an add is counted finished for the
  moment before its first file lands.
- **A lock over ten minutes old is an add that died**: git clears it only on a
  signal it can catch, so a SIGKILL or a power cut left the row badgeless for
  good. Cost: a checkout slower than that is counted mid-way.
- **A project wearing git's mark is listed again every round**: time passing
  changes nothing in the records a watcher tick compares, so the age would
  otherwise be judged only at the next launch. Cost: one `git worktree list` a
  minute while an add runs.
- **A branch name git will reject is refused before anything runs.** Nothing
  between the sheet and the add judged it, so a bad name ran the pre-create hook
  and git refused after. The sheet judges the name with the project's prefix
  added, as git sees it: `kp.` and `lock` make `kp.lock`, which git refuses.
- **So is a new branch's name an existing branch holds**, the same name or one
  git keeps as a folder of it or it of (`feat` beside `feat/x`); git refused it
  only after the pre-create hook had run.
- **The rules are git's own, in Swift, less the ones about slashes** that apply
  only to a full refname, the sheet asking on every keystroke.
- **"Based on" starts on the default branch**, the one the merged badge measures
  against. The main checkout's branch was the start, and a checkout switched to
  other work cut every new worktree from it. A sheet opened before the project's
  first branch scan runs that scan itself rather than fall back.
  `multishell worktrees add` without `--from` starts where the sheet would,
  since an agent calling it has no picker to correct.
- **The sheet's field turns unusual characters into dashes as they arrive**, a
  pasted `Admin::UsersController#index` reading `Admin-UsersController-index`.
  The set is wider than git's list, so a `#` goes too. The structural rules,
  `..` or a trailing `.`, are left to the warning, since a name half typed
  breaks them. Trailing spaces stay until a word follows, since a paste often
  ends in one and the trim already drops it. Only the field does this: an API
  caller's name is refused, not rewritten.
- **That field is an AppKit `NSTextField`.** SwiftUI's `TextField` on macOS
  never writes a binding change back into a field being edited, so the fix
  reached the draft while the field still showed `Admin::Users`. The field waits
  while an input method is composing, and makes the fix through the editor's
  change calls, so one undo takes back a pasted name whole.
- **The field follows its editor's storage while editing.** Undo and redo change
  the text without `controlTextDidChange`, so the draft kept a name the field
  had stopped showing, and Create would have made it. The old SwiftUI field did
  the same.
- **An existing branch is held to the same rules**: the check ran only when
  creating one, so an API caller with an empty name ran the hook and was refused
  after. Cost: a detached checkout git would have allowed is refused too.
- **Runtime state about a worktree is dropped in one place**, all of it keyed by
  path.
- **A collection added later registers there.** Each was pruned at whichever
  site last bit, and the dialog was the one missed: a worktree removed outside
  the app left its dialog up, and Confirm ran a removal on a path git no longer
  listed.
- **New Worktree always opens, even with nothing selected**, and its decisions
  are a tested value because a cancelled branch load once re-enabled Create
  against the wrong project.
- **The New Worktree sheet asks whether the first tab starts an agent**, and its
  answer stands over the create settings, the switch having asked.
- **With no agent to offer the sheet gives no answer**, and the create settings
  decide as they did before it asked. Answering "shell" there turned auto-start
  off for every worktree created before the PATH scan had answered.
- **A stand-in agent gives way to the project's own when the PATH scan offers
  it**; a pick the user made stays while offered. Before the scan only a typed
  custom command is offered, so the sheet started it in place of Claude.
- **A removal's row outlives git's record until the removal ends.** The refresh
  its own `git worktree remove` causes came about 250 ms in, dropped the row and
  so ended the post-delete hook. Kept, the row keeps its pane and Cancel, its
  block, and its place in a project removal, which ends it.
- **Only from the record's removal on.** A pre-delete hook whose worktree goes
  outside the app still ends with its row, as before.
- **A create at a path a removal is running on is refused**, at any stage: from
  the pre-delete hook on, the record can go while the create's own pre-create
  hook runs, and git then adds at a path whose row, entry and port are the
  removal's.
- **The add checks out with one worker per core** (`checkout.workers=0`), git's
  default being one. Nearly all of an add is writing files: on 9,467 files it
  went from 2.8s to 1.2s cold and 1.4s to 0.9s warm. A count the user set wins.
  git stays sequential below 100 files.
- **A checkout back during the pre-delete hook is judged as one there at the
  start**: not the record's checkout, it is left and only the record goes, with
  no post-delete hook; holding another worktree or submodule work, the removal
  is refused. Trashed unasked, a plain folder made there went, and the record
  took a returned checkout's submodule repository with it.
- **A list naming none of the project's own path proves nothing about a
  record**, as worktrees/sidebar.md has it for the list. With the project's
  `.git` gone, the enclosing repository's list lacked the path, the record read
  as gone, and the branch delete that followed took that repository's branch of
  the same name.
- **A submodule's path is everything after the first tab of its index entry**, a
  path holding a tab itself: read after the last, `sub\tx` read as `x`, an
  unpopulated submodule, and the removal took its repository.
- **A failed remove asks whether the project's own git answers before it
  prunes**: with the project's `.git` gone, prune ran in the enclosing
  repository and took its stale records, a write to another repository, before
  the list check refused.

## Reviewed and left as is

- **Each keystroke in the branch field rebuilds the "Based on" picker over every
  branch** (2026-11-12). Unmeasured; settling it needs a run against a
  repository with thousands of remote branches.
