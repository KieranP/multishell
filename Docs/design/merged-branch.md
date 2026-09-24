# The merged-branch badge

How "this branch landed" is decided without ever writing to the repository.
Newest at the bottom.

- **Deciding it is the whole feature**; the green glyph is the easy half.
- **Ancestry alone cannot tell "landed" from "never began"**, a branch being cut
  at its start commit, nor from "was carried up", a pull in a worktree cut
  before the trunk moved fast-forwarding it.
- **Sign 1 is the branch's reflog**, read as a deny list. Creation, reset,
  clone, fetch, a fast-forward and a rebase that replayed nothing are arrivals;
  everything else is work of its own.
- **A deny list because the arrivals are the closed set.** A message a later git
  invents reads as work, which is what counting entries assumed of every entry
  anyway.
- **Names go to git whole, with `--` after**, or a branch sharing a name with a
  path is "both revision and filename" and the read fails instead of answering.
- **A bare rebase with nothing to replay writes the same words as one that
  replayed**, and the merged list then lists the branch. So a finish whose new
  value is the commit it names is an arrival; one naming no commit, or one the
  branch rested past, stays work.
- **No reflog, nothing claimed.** A bare repo logs no branch creation, and
  guessing from the tips instead badges most of the worktrees it holds. Cost: no
  badge where a reflog expired, and a badge not drawn tells nobody to remove the
  worktree.
- **Sign 2 is patch ids.** A rebase-merge or a run of cherry-picks leaves no
  reachable tip, so `git cherry` wants at least one `-` and no `+`.
- **Not "no `+`" alone.** Cherry skips merge commits, so a worktree that merged
  the trunk in and wrote nothing of its own prints nothing, which read as "every
  patch landed".
- **Sign 3 is a gone upstream.** A squash merge leaves neither other sign, and
  detecting one would need a write, so the sign taken is what "delete branch on
  merge" leaves behind.
- **`[gone]` alone is three different stories**, so two reads go beside it.
- **A base that has moved on**: the branch config outlives the branch it names,
  so a reused name inherits an upstream that was never on the remote, spelled
  the same way.
- **The branch's own changes reading the same on the base**, which status cannot
  see here, a branch with no upstream being ahead of nothing. Two diffs: what
  the branch changed since it forked against where the two differ now, nothing
  in both. A path the base changed counts as differing, erring towards no badge.
- **Sign 3 is inference**, a PR closed unmerged leaving it too, so `isCertain`
  separates the three. All three badge; only the two that are proof get a
  removal dialog led by the button that deletes the branch.
- **The badge hides while the worktree holds uncommitted or unpushed work.**
- **A failed read is not a verdict.** Nil rather than an empty set from the
  merged list, nil rather than false from the patch, behind and content reads,
  nil from the ref read, which otherwise says a project has no branches and
  drops every badge it has.
- **git answers "no reflog" with success and no output**, so only a real failure
  there is silent. A verdict is recorded, and memoised, only where git answered.
- **Base is `origin/HEAD`, then the usual trunk names, with a repo override.** A
  remote-tracking ref beats a local branch of the same name, and an override
  resolving to nothing means no badges rather than a guess.
- **Fetching on a timer is out**, being network, credentials and the one git
  call here that can hang. So a badge is only as fresh as the last fetch, and
  Fetch is a menu item with a timeout and a spinner.
- **The check rides the status poll, not the watcher**: a commit moves a ref no
  watched file mentions. Four projects are scanned at once, one after another
  having been the tick's longest wait at ten projects.
- **Each verdict is memoised on base, base tip, branch, branch tip and whether
  the upstream was gone.** The branch because two may sit on one commit with
  only one gone upstream; the upstream because a first push puts one back
  without moving either tip.
- **A base that moves re-asks every branch**, so a fetch, pull or push misses no
  landing. Keying on the merge-base instead would miss a rebase-merge, which
  leaves the merge-base where it was.
- **Paced by cost, not all at once**: `git cherry` takes 0.6 to 1.3 s a branch
  on a 7,700-commit repository, so thirty long-lived branches after one fetch
  started 20 to 40 s of git together. Each round starts re-asks until their last
  costs reach 2 s across all its projects, always one a project, the longest
  since answered first, so every branch is reached in turn. A budget per project
  let a round of four start four budgets' worth. A lone project's refresh, a
  fetch's or a new worktree's, has a budget of its own and leaves the round's as
  it found it. Cost: after a fetch the last of thirty such branches changes
  about 75 s later.
- **A branch never read is not paced**, having no badge to show meanwhile:
  paced, a project of forty took five rounds at launch to badge them all. Cost:
  the first round asks every branch, held to the shared width below.
- **A failed read is logged at its cost like an answer**, or it stayed never
  read and went unpaced every round.
- **Nothing observable is written unless it changed**, or the sidebar redraws on
  every poll.
- **Never badged**: main worktree, bare repo, detached HEAD, the trunk's own
  checkout.
- **The user's git config cannot change what a read means.** Every runner turns
  signature printing off and untracked files on, through the environment rather
  than `-c`, which a failure would report in its arguments.
- **A printed signature splits a reflog subject into an action no prefix
  matches**, so every freshly cut branch claims to have landed, and being clean
  and certain gets the dialog led by the delete button.
- **Untracked files hidden empties the porcelain** for a worktree whose work is
  all untracked, which reads as clean, so the badge goes over uncommitted work
  and the directory is trashed or deleted. A caller's own entry still wins over
  both.
- **A branch is named to git by refname, never bare.** A bare name reaches a tag
  of that name first, and git's ambiguity warning goes to stderr, which the
  poll's reads discard.
- **The short print form is wrong the other way**, answering a `heads/`-prefixed
  name where a tag ties, which matches no worktree's branch.
- **Either direction is wrong and neither is silent about nothing**: the tie
  loses a badge the branch earned, or hands a certain "merged" to a branch
  holding work nobody has landed.
- **The base goes by refname too**: a tag ties with a local trunk and with a
  remote-tracking one alike, a tag named `origin/main` included. The short form
  stays for what a badge says it was merged into.
- **Every project's per-branch merge reads share one width of eight.** The poll
  scans four projects at once, and each project reading eight branches at once
  started up to 32 git processes a round after a fetch moved every base. A
  read's cost is timed from when it gets a slot, not from its wait.
