# Create Pull Request and merging

A worktree's pull request, pushed and opened with Create Pull Request and merged
from its page through `gh`.

- **Create Pull Request is busy while it counts the commits and asks the
  remote**, so a second click on a slow network asks nothing again.
- **A closed pull request stays shown, and Create Pull Request is offered**
  beside it: the host takes a new one from the same branch.
- **After a push the page opens from what was pushed**, whatever the scan after
  it finds. A branch with no upstream of its own whose name the remote already
  has is asked about as that, not as new.
- **Create Pull Request is GitHub Desktop's**: a branch the remote lacks, or
  commits it lacks, is pushed after asking, then the host's page for a new pull
  request opens against the trunk the merged badge uses. Pushing, merging and
  turning auto-merge off are the app's only writes to a remote; the first two
  ask every time, and the third takes back only a merge not yet made. SwiftUI
  may clear the dialog's binding, which answers No, before it runs Push, so a
  Push that follows still pushes, but never answers a different question.
- **The push goes to the branch's upstream, else its push remote, else `origin`,
  else the first remote**, with no prompt and a two-minute timeout. It sets the
  upstream unless the push goes to a `pushRemote` or `remote.pushDefault` other
  than the remote the branch follows, a fork's triangular setup: `-u` would turn
  its `git pull` to the fork. With no push remote named, the upstream is how the
  next scan finds what was pushed. The push remote is read from those two keys,
  not `%(push:remotename)`, which falls back to the remote the branch follows: a
  branch cut from `upstream/main` would push to `upstream`, not to `origin`.
- **Merge is offered at the merge path's end only where nothing holds it back**,
  Merge When Ready where only machines do, required checks running or GitHub
  working out conflicts, and Cancel Auto-Merge where auto-merge is on; see
  [merge-path.md](merge-path.md). GitHub's own CLEAN no longer offers Merge on a
  pull request the page holds back, as it did for an admin past a required
  review or before the checks were read: the user called that a bug on
  2026-10-29. A newer checks read outranks the list's CLEAN either way.
- **Merge turns the page into a form**, chosen on 2026-10-29 over a dialog: the
  method, then the commit's subject and message, then the merge. The form is the
  question asked every time; Cancel turns back to the page. Cancel Auto-Merge
  asks nothing, taking back a merge not yet made.
- **The form opens on GitHub's own default**, the method its merge box opens on
  for the user, `viewerDefaultMergeMethod`, the user having declined a
  per-project setting. It lists only the methods the repository allows, and each
  method's message is GitHub's own, `viewerMergeHeadlineText` and
  `viewerMergeBodyText`, kept per method as edited, Restore Default taking an
  edit back. A rebase takes no message.
- **One `gh api graphql` call reads them all**, as the form opens, with whether
  the repository allows auto-merge and the user's role on it. No `gh pr` command
  prints GitHub's messages, and `gh api` still keeps the login. It is asked of
  the host, owner and name the pull request's page names: `gh api` fills
  `{owner}` and `{repo}` its own way, apart from `gh pr`, which honours
  `gh repo set-default`. The offer is decided before that read, so the form says
  when either refuses and offers no confirm: GitHub ships with auto-merge off.
  Only a read or triage role refuses; a role not answered is left for GitHub to
  judge.
- **The merge is `gh pr merge` held to the head the page showed**,
  `--match-head-commit` with the listed head whose checks decided the offer, not
  the one the form's read found, and a read begun by an earlier opening never
  fills a later one.
- **A form is weighed where the list or the checks change, never as it is
  drawn**: a push, a pull request no longer open, auto-merge turned on or a
  blocker for good drops it, and whether it waits for checks follows the offer.
  The offer's own rule decides it, so the two never disagree: an UNKNOWN alone
  keeps it waiting, as Merge When Ready, and checks not yet read for its head
  leave it as it was. Only a merge being sent is left alone. Weighing it on each
  read brought a dropped form back when its conditions held again.
- **Auto-merge is held to the head only as it is turned on.** GitHub keeps it on
  for a later push by anyone who may write, and merges that too; the form says
  so, there being no way to hold it.
- **Each value is joined to its flag**, so a subject starting with `-` is not
  read as one. Merge When Ready adds `--auto`. A merge gets two minutes, as a
  push does: one killed after GitHub took it would read as refused.
- **After the host answers the project's pull requests are read again**, a
  refusal too, as one may have landed past its timeout or met a push. The form
  then says the host took it, not that it merged, as a merge queue only queues
  it, until the first list answer from a read begun after: by then the list says
  where it stands, whoever turned auto-merge on or off since. Done hides it
  sooner, the page offering nothing until the read the merge asked for answers:
  the list it would read still shows the pull request as before the merge. A
  refusal keeps what was written and says `gh`'s words. The merged badge and
  removal dialog take over from there.
- **A list that failed to read is said on the pull request page too**, as on the
  row's tooltip: the page offers Merge from it, and the popover that said it
  went.
- **The merge and the cancel name the pull request by its page**,
  `gh pr merge <url>`, so they act on the repository the options were read of,
  not on the number in whichever repository `gh repo set-default` names.
- **A merge the host accepted and a cancel in flight each name their pull
  request's page**, so a checkout onto another branch, showing another pull
  request or none, neither ends them nor lends them to it: the offer's hold and
  the cancel's disabled button stay with their own until a list read begun after
  says where it stands.
- **The form goes with its host**: a host turned off drops it, as it drops the
  checks. Cancel Auto-Merge stays off until the list shows auto-merge off, or
  answers from a read begun after `gh` returned, not just until `gh` returns: a
  read begun before it would turn the button back on beside auto-merge still on.
  A list that keeps failing keeps it off until one answers.

## Reviewed and left as is

- **A pull request in a merge queue is offered Merge again after Done.**
  `gh pr list` names no queue entry in 2.103, and asking GitHub's GraphQL on
  every poll would cost a call per project each round; a second merge is refused
  by GitHub, and the form already says the host took it rather than that it
  merged.
- **A merge or a cancel reads the project's CI runs again with its pull
  requests.** A read of the pull requests alone would need its own re-read
  bookkeeping beside `readsPullRequests`, for a write made a few times a day.
- **A form opened as Merge When Ready sends `--auto` if its checks pass before a
  read shows it.** `gh` then merges at once, its source says, where GitHub calls
  the pull request mergeable, so the form says the host took it to merge now or
  once its checks pass rather than that auto-merge is on; a re-read of the
  checks before each send would cost a call on every confirm.
- **The options read names the host without a port.** Unproven whether `gh`
  keeps an Enterprise login under `host:port`; adding the port would break the
  usual case to guess at the rare one.
- **A sent merge and a cancel each wait for a later list answer their own way**,
  `PendingMerge`'s accepted phase and `AutoMergeCancellation`. One ends a form
  with the writer's words, the other a disabled button, and auto-merge shown on
  ends the first early and off the second; one type would tie them.
- **Whether a services read answered the list is read from its answer time
  changing**, a new time standing after it, rather than a flag the read returns:
  `readPullRequests` returns early in several ways and shares its call with the
  CI read, and a wiped reading leaves no time to mistake for one.
- **The merge code documents enum cases and fields where they sit**, as
  `MergeReadiness.Blocker` does; the codebase's own form wins over the comment
  rule's hoisting.
- **Confirm and Cancel Auto-Merge each mark, call `gh`, say a refusal and read
  the list again in their own lines.** One marks a form's phase and ends in it,
  the other a cancel's token; a shared helper would take both as parameters for
  two callers.
- **`GitHubMergeOptionsRecord`'s fields are internal**, as
  `GitHubPullRequestRecord`'s are; the records keep one form.
