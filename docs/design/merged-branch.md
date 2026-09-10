# The merged-branch badge

How "this branch landed" is decided without ever writing to the repository.
Newest at the bottom.

## A merged branch is inferred from three signs, none of which writes

Deciding it is the whole feature; the green glyph is the easy half.

Ancestry cannot tell "landed" from "never began", `git worktree add -b` cutting
a branch at its start commit, nor from "was carried up", a `git pull` in a
worktree cut before the trunk moved fast-forwarding it onto commits it was
handed.

Sign 1, the branch's reflog. Arrivals: creation, reset, clone, fetch, and a
merge or pull that fast-forwarded. Work of its own: everything else, a
`commit:`, a rebase's `(finish)`, a merge that made a commit. A deny list,
because the arrivals are the closed set and a message a later git invents reads
as work, which is what counting entries assumed of every entry anyway. Names
given to git whole with `--` after, else a branch sharing a name with a path in
the repo is "both revision and filename" and the read fails instead of
answering.

No reflog at all -> nothing claimed. A bare repo logs no branch creation, so
guessing from the tips instead badges every worktree it holds that was cut from
anywhere but the trunk's own tip, which in that layout is most of them. It does
log a commit, so a branch that landed still says so. Cost: no badge on a branch
whose reflog expired, and a badge not drawn is a worktree nobody is told to
remove.

Sign 2, patch ids. A rebase-merge or a run of cherry-picks leaves no reachable
tip -> `git cherry`: at least one `-` and no `+`. Not "no `+`" alone, cherry
skipping merge commits, so a worktree that merged the trunk in and wrote
nothing of its own prints nothing at all, and read as "every patch landed" that
badges a branch that landed nothing.

Sign 3, a gone upstream. A squash merge leaves neither of the above, and
detecting one needs `commit-tree`, a write -> the sign taken is the `[gone]`
upstream "delete branch on merge" leaves, with two things beside it, `[gone]`
alone being three different stories:
- A base that has moved on, since `branch.<name>` config outlives the branch it
  names and a name used before hands its successor an upstream that was never
  on the remote, spelled `[gone]` in the very same words.
- The branch's own changes reading the same on the base, since the badge hides
  while a worktree holds work only it has, and `git status` cannot see that
  here, a branch whose upstream is gone being ahead of nothing. Two `git diff
  --name-only`: paths the branch changed since it forked against paths where
  the two differ now, nothing in both. A path the base changed since counts as
  differing -> errs towards no badge. Four reads, paid only by branches whose
  upstream is gone.

Sign 3 is inference, a PR closed unmerged leaving it too -> `isCertain`
separates the three. All three badge; only the two that are proof get a removal
dialog led by the button that deletes the branch, which may be the only copy of
the work. Badge hides while the worktree holds uncommitted or unpushed work.

A failed read is not a verdict: `nil` not an empty set from the merged list;
`nil` not `false` from the patch, behind and content reads; `nil` from the ref
read, which otherwise says a project has no branches at all and drops every
badge and commit date it has; `nil` from the reflog read, git answering "no
reflog" with empty output and success, so only a real failure is silent. A
verdict is recorded, and memoised, only where git answered.

Base = `origin/HEAD`, then `origin/main`, `origin/master`, `main`, `master`,
with a repo override. A remote-tracking ref beats a local branch of the same
name. An override resolving to nothing = no badges rather than a guess.
Fetching on a timer is out, being network, credentials and the one git call
here that can hang -> a badge is only as fresh as the last fetch, and Fetch is a
menu item with a timeout and the only sidebar spinner.

The check rides the status poll, not the watcher: a commit moves a ref no
watched file mentions. Each verdict memoised on base tip, branch, branch tip and
whether its upstream was gone: the branch because two branches may sit on one
commit with only one gone upstream, the upstream because a first push puts one
back without moving either tip. Nothing observable written unless it changed,
else the sidebar redraws every five seconds.

Never badged: main worktree, bare repo, detached HEAD, the trunk's own checkout.
