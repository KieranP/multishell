# Updating a worktree from its base

Merge from Base and Rebase onto Base, and what a stop on conflicts offers (issue
#48). Mockups on the issue. Newest at the bottom.

- **The base is the project's default branch at its remote copy, fetched
  first.** The local trunk is often stale, and the merged-branch reads already
  measure against the remote one (merged-branch.md). Only the base's remote is
  fetched, with Fetch's timeout. A project whose default branch resolves to a
  local branch, having no remote, updates from it with no fetch.
- **Named to git by refname**, as every base is (merged-branch.md). The merge
  passes `-m` in git's own words with the short name, or its subject read
  `'refs/remotes/origin/main'`.
- **On the shared worktree menu, not the project's.** The sidebar row, the
  header and a board card get both items, each naming the base: "Rebase onto
  origin/main". Neither shows on a detached or bare worktree, on the default
  branch itself, or before a scan has resolved a base.
- **No behind-base count, and no greying at zero.** The row's ↓ counts against
  the upstream, and a count against the base costs a `rev-list` per worktree per
  refresh (owner's choice, 2026-11-27). A merge with nothing to take in leaves
  the branch as it was and says nothing.
- **Uncommitted changes refuse it, the files named, and nothing is stashed.** An
  agent may be mid-edit, and the stash stack is shared by every worktree of a
  repository. Both commands take `--no-autostash`, or `rebase.autoStash` or
  `merge.autoStash` in the user's config would stash anyway.
- **The merge takes `--ff`**, standing over a `merge.ff=only` that refuses the
  merge commit a branch with work of its own needs.
- **Pseudo-refs are read through git where it keeps refs in reftable**: there
  `ORIG_HEAD`, `CHERRY_PICK_HEAD` and `REVERT_HEAD` are no files, and a merge's
  own stop read as git's failure. Other repositories keep the file reads. It is
  `show-ref --verify`, as `rev-parse` takes a tag of the same name instead.
- **The rebase takes `--no-update-refs`**: a `rebase.updateRefs` in the user's
  config moved other branches stacked on the rebased commits, pushed ones too,
  which the question never named. The flag came in git 2.38, under the 2.39
  floor (develop/dependencies.md).
- **Asked first where an agent works there, or a rebase rewrites pushed
  commits**, each reason a paragraph of one dialog. A merge rewrites nothing, so
  a pushed branch's merge asks nothing. The app does not push.
- **Pushed is a branch of its name on any remote**, a fork's included, each
  remote git lists asked in full, as a remote's name may hold a slash that a
  `refs/remotes/*/<branch>` pattern's `*` stops at. The upstream is not asked: a
  worktree cut from `origin/main` or `origin/release-2` tracks it, which read as
  pushed and asked on every rebase, and a push to a fork beside an upstream on
  the base was missed. `@{push}` resolves to nothing under `push.default=simple`
  with an upstream of another name. A failed read counts as pushed: asking costs
  a click, a rewrite unasked more. Cost: a branch pushed under another name
  reads as unpushed.
- **Everything is read again after the fetch, on every path**: a fetch can take
  minutes, and a question can stand for longer, while an agent works. A stop, a
  cherry-pick, uncommitted changes, a branch switched or a base the project
  changed refuses it, each by name; `git merge` refuses only changes its own
  files touch, so other edits rode into the merge and an Abort could not take
  them back out. The reasons to ask are read again too: what the click or the
  command line's flags agreed to is carried as a consent, and a reason it does
  not cover asks again, or refuses, before git writes.
- **A removal and an update exclude each other**: Remove is off while the app's
  fetch, merge, rebase or Abort runs there, a removal confirmed in its dialog
  meanwhile does nothing, and a removal begun first ends the update silently.
- **A cancelled request stops before git writes**: Ctrl-C on `worktrees update`
  is checked after the fetch and again before the merge, which then runs on
  uncancelled, as git cannot be stopped partway cleanly. A stop it leaves still
  opens the conflict tab the setting asks for.
- **`worktrees update` answers a refusal as data however late it is found**:
  before the fetch or after it, a stop, a cherry-pick or uncommitted changes are
  the same refusal, the files listed.
- **A base whose remote git no longer lists fails rather than going unfetched**:
  a renamed remote leaves its refs, and updating from one took in a months-old
  copy as though fetched.
- **A second question while one stands beeps**, an update's or an Abort's; an
  update that needs none still runs beside it.
- **A held index lock fails it and says so, never retried**: the holder may be
  mid-commit. git's words follow the app's, naming the lock file. Matched on
  `index.lock` rather than git's sentence, which a locale translates. Only
  before anything began: a lock met partway leaves the rebase stopped, so git's
  words say so instead, as no retry can start it afresh.
- **A conflict stops it and leaves it in progress**; the app never resolves one.
  "Rebasing · 2 conflicts" takes the place of the row's line counts until a
  `--continue` or an Abort ends it.
- **The stop is read from the files git leaves**, `rebase-merge`, `rebase-apply`
  or `MERGE_HEAD` in the checkout's git directory, with no git run: per status
  read, a hop to Dispatch, a read of a linked checkout's `.git` file and up to
  four stats, beside the git processes the read already starts. Anyone's stopped
  merge or rebase reads the same, a hand-typed `git pull --rebase` included, and
  gets the same menu.
- **The watcher sees a stop and its end without a new rule**: each writes `HEAD`
  or the index, which count, where `MERGE_HEAD` or `rebase-merge` alone would
  not (watching-and-status-reads.md).
- **A stopped rebase's row shows its short commit, not its branch**, git listing
  the worktree detached until the rebase ends. Cost taken over reading
  `rebase-merge/head-name` into the list. The Abort question and the conflicts
  file do read it, once each, as they name the branch to the user and an agent.
  A rebase begun detached writes "detached HEAD" there, so only a `refs/heads/`
  line names a branch.
- **A stop's menu offers Abort, and Send Conflicts To while a path is
  unmerged.** Send writes the conflicted paths and the continue command to one
  file in the drops directory and pastes a mention into the picked agent's
  prompt, Return left to the user: the PR and CI pages' handoff
  (services/send-feedback.md). The submenu's New Agent Tab starts the project's
  agent on the file instead, the worktree selected. A Send that finds no path
  left unmerged re-reads the row, which drops the submenu.
- **The paths are read at Send, not taken from the row**, whose status may be a
  poll behind, through `ls-files --unmerged`, which writes no index.
- **Send conflicts to the preferred agent is off by default**, under Updating
  from base in All Projects' Existing worktrees part, which the section's height
  split off (settings.md), and a project overrides it in its own Worktrees table
  as Auto-start is overridden. A repository's file cannot set it, so it asks no
  trust question. With no agent chosen its switch is greyed, and off whatever it
  says, in every project: one with its own agent turns it on by its override, as
  a switch the user cannot turn off must not act (owner's choice, 2026-11-27).
  The switch alone: greying the row took its (i) with it, which then opened
  nothing to say why (owner's report, 2026-11-27). A disabled switch dims as the
  settings buttons do, as AppKit's off switch looks the same enabled or not. A
  caption under it names where to pick an agent, as the dimming alone still left
  the owner asking why (2026-11-27); the Agents page's Auto-start switches carry
  it too.
- **With it on, a stop opens a new tab running the preferred agent**, its first
  prompt naming the file and the continue command, and the agent starts at once.
  Not the worktree's own agent tab: that agent may be mid-turn, and a prompt
  typed into it would wait or land in the middle of its work. Out of view, the
  tab starts there without turning to it, as a script's new tab does.
- **`worktrees update --merge|--rebase` does the same from a script and follows
  the setting.** What the click would ask about is refused: `--force` goes past
  a working agent, `--rewrite-pushed` past a pushed branch. A stop answers with
  the paths and any pane opened, exiting 0; an update over a stop is refused,
  naming git's `--continue` and `--abort`.

- **A stop is a stop only with paths left unmerged.** A `commit-msg` or
  `pre-merge-commit` hook rejecting the merge commit leaves `MERGE_HEAD` too,
  which read as conflicts with none listed and lost the hook's words. git's
  failure is presented instead, and the row still reads Merging, its menu
  offering Abort. Only the update's own stop is its own, one that began from the
  `HEAD` and base tip read just before git ran (`ORIG_HEAD` and `MERGE_HEAD`, or
  `orig-head` and `onto`): a merge an agent began a moment earlier failed the
  app's update, and was reported as its conflicts.
- **The row's spinner says which step runs**: the checks, the fetch, the checks
  again, the update, or an Abort. One map of merges running marked all three and
  said "Merging from the base" during an Abort, and through a minute's fetch.
- **Too crowded for its words, a stop keeps the warning glyph**, its text the
  tooltip, as the row's other alerts do.

- **Abort asks first while an agent works there**, as the update does: the agent
  may be resolving the very conflicts the abort throws away. A red button, the
  abort discarding work. The confirm reads the stop again, and aborts only the
  merge or rebase it asked about: the agent may have finished it and begun
  another meanwhile, even of the same kind. A stop is known by the commits git
  records for it, a rebase's `orig-head` and `onto` or a merge's `MERGE_HEAD`;
  not both, as a `rebase -r` writes `MERGE_HEAD` at each merge step. A confirm
  that finds another stop says nothing was aborted. A click from a menu one poll
  stale is held to its label the same way.
- **A stop the row had not read is named, not called uncommitted changes**: its
  `UU` paths would have steered the user to commit mid-rebase. The refusal reads
  the status, which brings the stop's menu. A stopped cherry-pick, revert or
  `git am` is named the same way, by the menu and by `worktrees update`, though
  its menu offers no Abort. A pick list counts until `sequencer/` goes, as
  committing one stop by hand drops CHERRY_PICK_HEAD and leaves the rest to
  replay. A `git am` writes `rebase-apply` as a rebase does, and
  `rebase-apply/applying` tells them apart.
- **The base's remote is found among the names git lists**, the longest one its
  ref starts with: a remote may hold a slash, so cutting the ref's text at its
  first one fetched `team` for `team/origin` and failed every update.
- **An agent is handed `env GIT_EDITOR=true git <method> --continue`**: plain
  `--continue` opens the message's editor, which with no terminal waits for
  ever. `GIT_EDITOR` outranks `core.editor`, so `-c core.editor=true` lost to a
  `GIT_EDITOR` the user exports; `env` keeps it one line in any shell, tcsh's
  and fish's included. The row and the refusals say the plain command, which a
  person types.
- **`worktrees show` reports a stop and the step under way**, as its row does: a
  script polling it otherwise learnt of a stop only by trying an update.

Not covered: pushing afterwards, updating every worktree of a project at once,
and a base other than the project's default branch.

## Reviewed and left as is

- **The merge or rebase has no timeout and no Cancel** (round 1, 2026-11-27,
  unproven). A hook waiting on input or a signing prompt that never answers
  would leave the row spinning. A rebase of many commits with slow hooks can
  rightly take minutes, so any timeout would be a guess; none has been seen to
  hang.
- **`worktrees update` exits non-zero over a stop whose conflict tab failed to
  open** (round 2, 2026-11-27): the drops write's or the directory probe's alert
  is the request's answer, as every alert raised in a request's task is
  (agents/command-line.md). The rebase is still stopped; the alert says why no
  tab opened.
- **Settings search opens Worktrees on its first part, New worktrees**, whose
  rows do not hold Send conflicts (round 3, 2026-11-27). The search finds pages,
  and each split page, Agents and Hooks included, opens its first part; finding
  parts is a change to the search for all of them.
- **A failed read of the unmerged paths shows git's failure, not a stop** (round
  10, 2026-11-27). git's words hold its CONFLICT lines and the row still reads
  the stop, its menu offering Abort; a stop with no paths listed would tell an
  agent to resolve nothing.
- **`UnmergedPathParser` keeps its own loop beside `TrackedFileListParser`'s**
  (round 10, 2026-11-27). Sharing the NUL split and tab cut would cost the
  tracked list its stop at the cap in a large repository, or need a lazy
  sequence type, to save five lines.
- **A base on a remote whose name holds a slash matches a branch by the ref's
  last part**: `refs/remotes/team/origin/main` is `main`'s (round 10,
  2026-11-27). A base `origin/release/main` would also hide the menu on a branch
  named `main`; the remote names that would tell them apart are not read there.
- **`--ff` also stands over `merge.ff=false`** (round 12, 2026-11-27). A branch
  with nothing of its own that takes in its base gains only an empty merge
  commit, and honouring the setting would read the config before every merge.
