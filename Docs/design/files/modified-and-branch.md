# Modified and Branch

What the Changes list and a file tab count from, and why each went the way it
did. Newest at the bottom.

- **Changes counts against `HEAD` under Modified, and under Branch against where
  the branch left its project's base branch**, committed or not, new files
  whole: once an agent commits, Modified empties while Branch still shows its
  work. The base is the merged badge's (merged-branch.md), and the count is
  `diff-index` against `git merge-base HEAD <base>`, the working tree included.
- **Modified or Branch is one choice for the Changes list and every file tab,
  kept with the settings**, its switch drawn in both, so a tab never counts from
  somewhere other than the list it was opened from. Files counts against `HEAD`
  whatever it says, being what All was.
- **Branch is read on every status read of the panel's worktree**, one that
  moved no count included: an edit back to the base's text leaves the count
  against `HEAD` as it was, and under Staged Only an edit on disk moves no
  status at all. Each read waits ten times what the last cost, a second at
  least, so a busy checkout's take at most a tenth of a core. A git event and a
  new diff algorithm each set off a status read, so a reset that leaves the
  status alone is read too; the base resolving or moving reads it as well, and a
  scan that finds nothing moved reads nothing. A worktree being written or in a
  missing project is not read, as its status is not. Only the panel's worktree
  is read, its result forgotten with the listing or on leaving Branch, so coming
  back draws none as current, and a new file's lines are the status read's where
  it counted them.
- **A Branch read that fails keeps the last**, an unborn `HEAD` being the one
  failure that is a verdict, no shared history.
- **One `diff-index --raw --numstat` pass, numstat saying which paths changed
  and the raw record only how**: against a commit, a file whose stat alone
  moved, a touched one, gets a raw record and no count.
- **No base branch, no Branch**: the list is empty and its footer says so once a
  scan has said so, saying nothing before, and a file tab offers no switch,
  counting from `HEAD`. A branch sharing no history with its base, or with no
  commit yet, says that instead, its tabs counting from `HEAD` under either.
  Cost: a project no scan has answered for, missing or failing, lists nothing
  under Branch and says nothing.
- **A tab under Branch marks nothing staged**, the index holding the branch's
  commits too: every change is drawn filled, and VoiceOver says neither staged
  nor unstaged. On the base itself, no commit of its own yet, the merge base is
  `HEAD` and the marks are exact, so they stay. Before its project's first scan
  a tab under Branch counts from `HEAD`, the scan reading it again, as waiting
  would leave it blank where a scan never answers; a hidden tab's dot follows a
  new scope's or base's reads until it is shown, a new diff algorithm or base
  tip leaving it as it was. A file the branch added and has since deleted shows
  `HEAD`'s text removed, the base holding none. A submodule's file still counts
  from the submodule's `HEAD`, its bar keeping the switch, which is the one
  choice and so still moves the list and the other tabs. Cost: a file the branch
  deleted lists under Branch but does not open, the open rule reading only the
  index's and `HEAD`'s copies.
- **Each read of a tab under Branch asks `git merge-base` afresh**, about 8 ms
  on Ghostty's 18,000 commits, rather than keeping one that a commit, a checkout
  or a fetch would each make stale. The tab's pace counts it.
- **Switching scope reads again the tabs in a project with a base**, at once
  rather than at their pace; a submodule's among them reads the same rows again,
  only a read telling which repository holds a file. A base that moves reads
  every tab in its project again under Branch, as it may move the merge base:
  fetching is the user's, so that is rare.
- **A tab counts its anchors and saved scroll by the committed side**, the merge
  base's text under Branch, so a new scope moves them as a commit does.
- **A tab's dot under Branch is the panel's Branch read's** where the panel
  holds a current one, a submodule's file keeping its submodule's status. Cost:
  with the panel elsewhere it has none for what its rows cannot tell, a binary
  file or a hidden tab, the status counting from `HEAD`; recording the kind on
  the tab's own read would end that.
- **A click on a row's git badge sets Modified for every tab too**, the scope
  being one choice, so a Branch reader loses the choice there.
- **Costs left under Branch**: a merge base git cannot read leaves a tab its
  last rows of text, which may be the other scope's after a switch, and one with
  none says git could not say, rather than count from `HEAD` unseen; a Branch
  read that fails with none before it leaves the list blank, its footer saying
  it could not read; and with a local `main` as the base, each commit to it
  reads every tab in the project again, as a fetch does a remote one, at once; a
  scope switch landing mid-read waits out that read's pace; each tab read asks
  `rev-parse HEAD` beside `merge-base`, run at once; a Branch tab's saved
  scroll, numbered by the merge base, lands by `HEAD`'s numbering if the first
  read after a relaunch comes before its project's scan; and a worktree whose
  status read keeps failing reads no Branch either, its new files coming from
  that read.
