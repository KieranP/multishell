# Matching a branch to its pull request and runs

A worktree's pull request and its newest CI run, matched to its branch by
upstream, and a merged pull request as proof the branch landed.

- **Matched by the branch's upstream**, its name on the remote and the owner and
  name the remote's URL gives, never its local name: a local branch can track
  another name, and a fork's branch of the same name is someone else's. A run is
  matched the same way, by the `repository_url` CircleCI gives it, so a fork
  shows none of the project's runs on its same-named branch; where either side
  names no repository, the branch name alone decides.
- **A remote's push URL is asked once which repository it names today**,
  `gh repo view <url>`, and a pull request headed there matches too: GitHub
  lists a renamed or moved repository's under its new name while the URL keeps
  the old, which it redirects (`zeit/next.js` heads `vercel/next.js`, checked
  2026-11-07). A fork resolves to itself, so its parent's same-named branch
  stays someone else's; trusting any pull request from no fork with one remote
  was tried and dropped for taking those. A URL `gh` cannot resolve, a GitLab
  mirror, an ssh host alias or a timeout, waits ten minutes before it is asked
  again, as each read waits on the asks. A run matches the new name only while
  the pull request integration has asked, as CircleCI's read asks nothing of
  GitHub.
- **The branch's upstream here is where it is published**: its own name on the
  remote its pushes go to, `pushRemote` or `remote.pushDefault` resolved by
  git's `%(push:remotename)`, where that remote has it; else the branch it
  follows. A fork's push remote then finds the fork's pull request, and a branch
  pushed without `-u` its own, its unpushed commits counted against that.
- **Its own name that git does not track for it counts once the branch held that
  tip**, as its reflog says; else it is the branch it follows. A new branch
  reusing the name of one whose pull request was merged or closed took the old
  remote branch, left undeleted, and with it the old pull request and runs. Read
  again only when either tip moves. A branch with no reflog, or a read that
  fails, keeps its own name. Cost: a teammate's push to a branch this clone
  pushed without `-u` hides its pull request until the branch is pulled.
- **An upstream that is the trunk, on a branch that is not, is no upstream**: a
  branch cut from `main` still tracking it took `main`'s pull request and runs.
  Nor is one on remote `.`, a local branch: nothing was pushed. A worktree's new
  branch started from another remote branch is made with `--no-track`, as GitHub
  Desktop does, or it would take that branch's pull request and push into it;
  one started from the trunk tracks it, as git would. One an earlier build made
  that way is known by its reflog's "Created from" entry, read once per branch a
  worktree in the project's worktree folder has out, and its upstream set aside
  the same way; a read git failed is asked again next scan. git logs the same
  entry for a branch a user made to follow a teammate's, so one outside that
  folder keeps what it follows.
- **An open pull request wins over a newer closed one, then the newest.**
- **A merged pull request stands for the merged badge only while its head is the
  branch's tip.** Then it is proof, `.pullRequest` evidence, and the removal
  dialog leads with deleting the branch. A commit after the merge leaves it
  outgrown: drawn instead of the merged badge, said in the tooltip and to
  VoiceOver, shown on the page with a new one offered, and git's own reads
  decide the merge evidence. Outgrown where a commit on the tip is the branch's
  own and its change is not the head's: `git cherry <head> <tip>` lists it, and
  `git rev-list --no-merges <tip> --not <head> --remotes --branches`, the
  branch's own remote and local branches excluded, holds it. A scan asks once
  per head and tip, each services read again, as the remote branches it weighs
  move with a fetch. A commit after the merge or an amend that changed the work
  is outgrown. A branch behind its head, one the host rebased with Update branch
  where the patches still match, and one synced after the merge by rebase, reset
  or merge from any remote branch, the trunk, another remote's trunk or a
  stacked base, hold nothing the merge left out, and are shown merged with Open
  offered, as Create would push the deleted branch back. So is one whose head
  this clone lacks; a scan leaves that question to the services' next read,
  which a fetch brings. No trunk is asked, so a project with none resolved still
  finds a branch outgrown.
- **Only a pull request merged into the trunk is proof**: one merged into
  another branch, as a stacked one is, has not landed.
- **Removing a branch that proof calls merged deletes it with `-D`**: after a
  squash merge `git branch -d` refuses a branch the pull request shows landed.
  Whether the branch is still at the pull request's head is read once its
  checkout is gone, on every removal path, so a commit made while the dialog was
  up keeps the branch.
- **Cost of tip equality**: a worktree behind the head it was merged at falls
  back to git's reads too, which a fetch usually settles.
- **A merge without a pull request is git's to see**, through the merged badge's
  own reads; the host can say nothing about it.
- **A remote a partial clone filters is still a remote**: git prints its fetch
  line with ` [blob:none]` after it. A branch is matched in the repository its
  remote pushes to, which a triangular set-up sets apart from where it fetches.

## Reviewed and left as is

- **A shown pull request replaces the merged badge, closed ones too**, as was
  decided for the row, even where git proves the branch landed some other way.
- **Recent runs are keyed by branch name alone, before the repository check.** A
  CircleCI project lists only its own repository's runs, so two repositories
  never share one branch's key; the check only turns a fork's upstream away.
- **A branch whose reflog lost its creation entry keeps its upstream.** git gc
  expires reflog entries, by default after 90 days, and nothing else records
  what a branch was made from.
- **A branch pushed without `-u` to a remote other than `origin` has no
  upstream** where nothing names a push remote: git's own default is `origin`,
  and Create Pull Request asks about the remote's same-named branch as that.
- **The changes past a merged head are asked before the merge reads plan.**
  Answers, and questions git could not answer, are kept per head and tip, so a
  scan asks only where one moved: a `git rev-list`, then a `git cherry` only
  where the branch has commits of its own, merges left out, neither patching the
  trunk; the plan does not wait on anything else. A services read asks every row
  with a merged head again, a few at most, and a branch synced since its merge
  costs it the `rev-list` alone. A scan records each branch's tip whether or not
  a trunk resolved, so the question follows a commit either way.
- **A commit after the merge that another branch also holds is not the branch's
  own**, as a stacked child on it or a follow-up branch: the rule that lets a
  sync from any branch, remote or local, leave nothing out cannot tell the two
  apart, and that work has a home, and a pull request, of its own.
- **A rebase that changed a patch's context, or a squash before the merge, reads
  as outgrown.** Patch ids hash the context lines, as the merged badge's own
  patch proof does. Create then asks before it pushes, so the wrong answer costs
  a question declined. See "Asked both ways" for the rules tried before it.
- **A trunk commit cherry-picked onto a branch after its merge reads as
  outgrown.** The copy's hash is on no other branch, and its patch is not the
  head's. Seeing it on the trunk means patching every trunk commit since the
  fork, which round 6 dropped for its cost on each read; Create asks first.
- **A services read leaves a question a scan is asking to that ask.** Should a
  remote branch move during its few milliseconds of `rev-list`, the answer is a
  poll late; a re-read flag per question would cost more than that window.
- **Another branch made, moved or deleted, local or by a fetch in a terminal, is
  weighed at the next services read**, not at once: it moves no upstream of the
  row's, so schedules none, and a poll is at most two minutes off. The menu's
  Fetch schedules a read of its own. An overtaken scan may still ask its older
  questions, one `rev-list` and `cherry` per merged row, which the next match
  prunes.
- **A branch scan overtaken by a newer one still writes its tips and dates.**
  Unproven: the two would have to land out of order, and the next scan rewrites
  both; `recordUpstreams` already refuses the older scan's upstreams.
- **A scan's branch tips are kept twice**, in `BranchScan.branchTips` and in
  `MergeInputs`, the merge reader's own contract; both come from one
  `localBranchesByName` call.
- **A row that really is outgrown asks git again on each services read**, a
  `rev-list` and a `cherry`, each over the commits since the merged head: a few
  rows at most, every two minutes. Keying the answer on every ref's tip to skip
  that would cost more than it saves.
- **A checkout onto another branch shows no pull request until the next scan
  matches the new branch**, a quarter second and a scan in front, with Create
  offered meanwhile. Showing the old branch's, as before, was worse; Create asks
  before it pushes.
- **A branch pushed from a single-branch or shallow clone has no upstream.**
  Such a clone fetches no ref for it, so git names none, and a branch nobody
  pushed looks the same; telling them apart would ask the remote on each scan.
- **A branch following its own name elsewhere than it pushes opens the page on
  the branch it follows when nothing is unpushed**, and asks to push to the push
  remote once something is. The scan calls a same-named followed branch the
  branch's own, so its commits are already where the page reads them.

### Asked both ways

- **When a merged pull request is outgrown.** Round 1 asked that a branch
  amended after its merge count, which the first rule, the head in the tip's
  history, missed. Flipping it to the tip in the head's history (round 1) called
  a host's rebase outgrown (round 3). Patches against the head (round 3) called
  a branch synced to the trunk outgrown (round 5). Patches against the head and
  the trunk (round 5) missed other remotes' trunks and stacked bases, needed a
  resolved trunk, and patched every trunk commit since the fork on each trunk
  move (round 6). Kept: patches against the head, limited to commits no other
  branch, remote or local, holds (round 11 added the local ones), which answers
  every case the rounds raised but a rebase that changed a patch's context.
- **A commit another branch held, once that branch goes.** Round 7 asked that a
  stacked child's going leave its parent outgrown, as the child's commit is the
  parent's own work; round 13 asked that a synced-in branch's going, pruned by a
  fetch once it merged, leave the branch merged. git sees the same thing in
  both, a commit no branch holds but this one. Kept: such a commit is the
  branch's own, and Create asks before it pushes.
- **The pull request read and the row disagree on a remote whose URL names no
  repository** (2026-11-12): the read counts any same-named pull request as
  listed, the row matches none. Both show the branch with no pull request, and
  tests rely on such a branch being asked alone where the list has none.
- **`publishedTipChecks` and `branchStartPoints` can be written for a project
  removed during the git call** (2026-11-12). Each entry is checked against its
  tips on read, and a re-added project has the same id and the same facts.
