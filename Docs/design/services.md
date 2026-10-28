# Pull requests and CI

A worktree's pull request and its newest CI run, read through each service's own
command-line tool.

- **Two kinds of service, each behind a protocol**: a pull request host and a CI
  provider, so another of either is a new conformance and an integration case.
  GitHub through `gh` and CircleCI through `circleci` are the ones there are.
- **Kept apart because CI runs on a branch before any pull request exists**, so
  the row draws the two marks apart and either can be missing.
- **A tool that cannot be run says so in words**, not as a system error, and a
  closed Integrations page asks the tools nothing more as they are found.
- **The tools run with the login shell's whole environment**, as a terminal's
  do, so a login kept there, `GH_TOKEN` or `CIRCLECI_CLI_TOKEN`, reaches them.
- **Through the tool, never its API.** The tool keeps the login, `gh` in the
  keychain and `circleci auth login` likewise, so the app never reads or stores
  a token. Calling the API would mean reading the CLI's keychain item, a prompt
  and a tie to its storage, for no fewer calls.
- **Every read is one call per project.** `gh pr list --state all` lists the
  newest hundred, open or not; `circleci run list` the newest fifty runs on any
  branch. A shown, pushed branch the recent runs left out is asked alone.
- **A branch asked alone is not asked again until it is pushed to**, or until
  its run ends, on hold included: an approval raises no event, and a row stuck
  on "on hold" after one cost more than a call per such branch each round.
  Otherwise every round paid a call for each old or never-run branch. Cost: a
  run started on a branch by another trigger, a schedule or an API call, is seen
  only once its branch moves or the recent runs list it.
- **Cost of the hundred**: a pull request older than the hundred newest reads as
  none, and the row falls back to the merged badge.
- **Matched by the branch's upstream**, its name on the remote and the owner and
  name the remote's URL gives, never its local name: a local branch can track
  another name, and a fork's branch of the same name is someone else's. A run is
  matched the same way, by the `repository_url` CircleCI gives it, so a fork
  shows none of the project's runs on its same-named branch; where either side
  names no repository, the branch name alone decides.
- **The branch's upstream here is where it is published**: its own name on the
  remote its pushes go to, `pushRemote` or `remote.pushDefault` resolved by
  git's `%(push:remotename)`, where that remote has it; else the branch it
  follows. A fork's push remote then finds the fork's pull request, and a branch
  pushed without `-u` its own, its unpushed commits counted against that.
- **A branch nobody pushed has no pull request or run to find**, so it is asked
  about for neither.
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
- **Polled, unlike `git fetch`.** A review, a teammate's push, a run finishing
  and a pull request opened on the web raise no local event, and these reads
  write nothing local, ask for no credentials and time out at 30 s.
- **Every two minutes for each project with a row in view, while frontmost**, a
  launch in the background, as a login item, asking nothing until it comes to
  the front; every minute where a shown run is under way. A return to the front
  reads again past thirty seconds, so switching apps asks nothing. A run on hold
  is not under way here: it waits on a person, perhaps for days.
- **A read asked for while one runs follows it**, the running one having begun
  before what moved, and the remotes are read once a round for both services. So
  does a return to the front during a poll, at its shorter interval. A Fetch
  compares its own project's upstreams only. A Fetch that moves an upstream
  leaves the read to the move's settled one. An upstream moving in the
  background schedules nothing and leaves the project due, so the return to the
  front reads it however recent the last read; a read spanning a turn of an
  integration off and on is not kept.
- **The reads run beside git's rounds, one poll at a time, never inside them**:
  a hung tool held the round, and every status read, for its 30 s timeout. A
  Fetch's spinner likewise ends with git's reads, not the services'.
- **A push, pull or fetch moving an upstream reads again once it settles.** A
  first scan's upstreams appearing do not, the first read being the poll's.
- **A project is not counted asked before a tool is there to ask**, or the login
  shell's PATH landing waited out a whole interval; a read with none to ask is
  no read.
- **A failed read is not a verdict**: the row keeps the last answer, and the
  tooltip says since when, with the day where it is not today, and why. A branch
  asked alone that fails keeps its own last run while the others take their new
  ones.
- **Unread is not "none" either.** Before a list answers, the page says it is
  not read yet, and why where a read failed, and Create Pull Request is not
  offered: it would be offered for a branch that has one. Checks not read keep a
  pull request from reading ready, and Create Pull Request reads an unread
  status before deciding there is nothing to push, and opens nothing where git
  cannot say. It reads the status afresh on every click and asks the remote,
  `ls-remote`, whether the branch is still there.
- **A ref read retried without the upstream atoms says nothing of upstreams**,
  so a failed first query leaves every row's marks as they were.
- **A tool gone from the PATH takes what it read with it**, the panel turning
  back to Files with its listing read again, and a setting written from the
  command line turns an integration off or on as the page's toggle does.
- **"Not ours" is asked again when the remotes change, else after ten minutes**,
  counted from the latest time it was said, for the host and the provider alike.
  `gh` decides it from the remotes and its logins, and an Enterprise host is not
  ours until `gh auth login` names it, which changes no remote.
- **CI is asked only where a checkout holds the provider's configuration file**,
  `.circleci/config.yml`, by the CI page's own reads too, and not where the
  provider said the repository is not its own, which also takes its runs off the
  rows and is said on the CI page. Before the project's first read the page
  looks for the file on disk itself. A bare repository's own folder has no
  checkout, so its worktrees are looked in too.
- **Toggles per project, on until turned off**, on the Integrations page. No
  global and no repository file: the reads are display only, and a repository
  without the service already shows nothing. A list of what is off, in case
  order, so an unknown id costs itself and the state file does not churn.
- **A worktree with no branch has no runs to find**, not "not pushed", and no
  pull request to head, which its page says rather than calling it the trunk.
- **`gh auth status` failing for one host while another is logged in reads as
  logged in**, as the reads for that host work.
- **The page asks each tool's version and login as it opens, never on the
  poll**: both `gh auth status` and `circleci auth me` go to the network. A page
  opened before the login shell's PATH arrived is answered once it does.
- **`circleci` must be 1.0 or later**, the release that brought the run
  commands; 0.1 has none of them. `circleci version`, which asks no service, is
  read once the tool is found, and only one known to be older gets no reads and
  no tab: a version that fails to run or read is no verdict. It is asked aside,
  the provider passed over until it answers, so a cold start waits on nothing;
  found able, its runs are read at once, a few projects at a time, with the pull
  requests only where no list has answered yet, and its page shown where it was
  the one saved. The same tools found again rebuild nothing.
- **Create Pull Request is busy while it reads the status and the remote**, so a
  second click on a slow network asks nothing again.
- **A closed pull request stays shown, and Create Pull Request is offered**
  beside it: the host takes a new one from the same branch.
- **After a push the page opens from what was pushed**, whatever the scan after
  it finds. A branch with no upstream of its own whose name the remote already
  has is asked about as that, not as new.
- **Create Pull Request is GitHub Desktop's**: a branch the remote lacks, or
  commits it lacks, is pushed after asking, then the host's page for a new pull
  request opens against the trunk the merged badge uses. Pushing is the app's
  only write to a remote; it asks every time. SwiftUI may clear the dialog's
  binding, which answers No, before it runs Push, so a Push that follows still
  pushes, but never answers a different question.
- **The push goes to the branch's upstream, else its push remote, else `origin`,
  else the first remote**, with no prompt and a two-minute timeout. It sets the
  upstream unless the push goes to a `pushRemote` or `remote.pushDefault` other
  than the remote the branch follows, a fork's triangular setup: `-u` would turn
  its `git pull` to the fork. With no push remote named, the upstream is how the
  next scan finds what was pushed. The push remote is read from those two keys,
  not `%(push:remotename)`, which falls back to the remote the branch follows: a
  branch cut from `upstream/main` would push to `upstream`, not to `origin`.
- **Opening a page is the tool's**, `gh pr view --web` and `circleci run open`,
  so an Enterprise host or CircleCI server opens its own.
- **Every tool run is timed into the git run log**, named with its program, so
  Debug Info counts it beside git's.
- **The marks**: the pull request glyph green where the host would merge it now
  (GitHub's `CLEAN` or `HAS_HOOKS`), red for changes requested whatever GitHub
  says, faint while a review is wanted, and the area's text colour otherwise, an
  approval still waiting on checks included: the user asked that green mean
  ready, and the state's words say "Ready to merge" with it. It is dashed for a
  draft, crossed when closed, the merge glyph once merged, and one corner dot,
  yellow for a conflict over blue for auto-merge, the conflict being what needs
  the user. Every services glyph, the Changes, PR and CI tabs and a conflict's
  warning too, is the approved design's own strokes, not an SF Symbol; the Files
  tab keeps the symbol it had. The running ring, the design's four arcs, turns
  wherever it is drawn, the sidebar's rows included, by Core Animation in the
  render server, so it costs the app no frame; a SwiftUI rotation redrew the
  whole sidebar each frame, which kept it still there before. Reduce Motion
  keeps it still.
- **The window's header shows no services.** The row and the panel's pages say
  them; the user cut a header pill that repeated them. The row's popover draws
  the pull request with the card's own view, state and corner link included, so
  the two never drift apart. On the row the pull request and run glyphs sit just
  after the git changes, left of the terminal count, where the user put them,
  and VoiceOver reads them in that order.
- **Colours are the theme's `ui.pull_requests` and `ui.ci`**, seeded from each
  built-in theme's `ui.states`; the greys are the area's, as idle's is, and the
  merge glyph takes `ui.git.merged`, the colour of the badge it replaces.
- **CircleCI's phase and outcome words are not documented.** The fixtures are
  1.11's real output, `ended` with `succeeded`, `failed` or `canceled`. The
  current outcome is read first, then the outcome, then the phase, each in full,
  its API's words exactly and any other loosely, so a rerun's new word still
  outranks the first attempt's; a word neither knows is no status, not a guess.
  A job's `(execution …)` note is dropped from its name, and only that.
- **1.11 prints a run's commit as seven characters**, so a run matches the local
  tip by prefix, seven characters at least, and a longer one exactly.
- **An empty run list may come as `null`**, Go's nil slice, read as no runs.
- **A run ends at an ended phase with a settled outcome**, a rerun moving the
  outcome back to running first, **or a phase that is itself a settled
  outcome**, `errored` say, so one stuck there is not polled as under way;
  `failing` still runs. A phase neither list knows leaves it to the outcome, or
  a new word would poll its run every minute for good.
- **`circleci` prints its errors as JSON on stderr**: `project.not_found` is
  "not ours" and an `auth.` code logged out. Its login error is unseen, so plain
  text naming a login reads as logged out too.
- **The panel has a page for each**, beside Files and Changes, its tab drawn
  where a host's or provider's tool is installed. A page whose tool has gone
  shows Files, rather than a page nothing can fill.
- **A services' page lists no files, so keeps no listing**: turning to one drops
  the tracked files and the ignored entries, which Linux holds 80 MB of.
- **Its reads are its own and only while it shows**, logged per worktree and
  page, so turning pages mid-read still reads the new one: the pull request's
  checks, the branch's last ten runs and a failed run's report. At the poll's
  interval, every minute while one is under way, and at once where the shown
  pull request moved its head or a new run appeared.
- **Two copies of a run can disagree**, the row's and the page's read at other
  times, so a detail read for one is read again at most once a minute.
- **When a run's details were read is kept apart, unobserved**, as the lists'
  answer times are, so a re-read that found the same workflows redraws nothing.
- **The pages keep every worktree's checks and run list, but run details only
  for the rows and the panel's own worktree**: a return to a row asks again only
  when due, and other worktrees' workflows and reports do not sit in memory.
  Rows passed quickly read nothing; the one the selection rests on reads once it
  settles. A merged or closed pull request's checks are read once at its head.
- **An earlier failed run's report is read as its row opens**, with its
  workflows, as the newest run's is.
- **A turn of the page or a change of row reads only what is due**, and only
  while frontmost, as the poll does: arrowing through ten rows asked `gh` twenty
  times. A page whose host or provider is turned off or gone keeps nothing it
  read.
- **Checks are two calls run together**, `gh pr checks` and
  `gh pr checks --required`, the second being the only way `gh` says which are
  required. It exits 1 for a failing check and 8 for a pending one with the list
  printed either way, and 1 with none where there are no checks, read as an
  empty list.
- **A rerun is listed once, as its newest job**, the one with the higher number
  in its link: `gh` lists it beside the run it replaced.
- **Whether a pull request can merge is the panel's verdict**, from its draft
  state, conflicts, failing and pending required checks, its review and being
  behind its base. GitHub answers `mergeable: UNKNOWN` until it has worked
  conflicts out, which the panel says as checking rather than as none; a merged
  or closed one lists no conflicts row. Checks count only for the head they were
  read at, so a push leaves the verdict waiting on the new head's. The host's
  own "blocked" is said only where none of those accounts for it, such as a rule
  for signed commits.
- **A pull request waiting on a person is on hold, not running**: a required
  review, and a banner held back only by that or its draft state, draw the
  pause, as a CI run on hold does, since either may wait days. The ring turns
  only while a machine works: a check running, conflicts not worked out, checks
  not read. The user chose this on 2026-10-28.
- **A check opens its own link, http or https only**; a CI job opens through
  `circleci job open`, which knows the server. The CI card's link opens the
  branch by its upstream name, the page showing a run the row may not have.
- **A failed run's report is split at its `### job:` headings**, each part under
  its job, as the design drew it; what names no listed job follows the
  workflows. A rerun under way hides the old report, and a run listed as going
  again drops what was read of its ended attempt, read afresh when it ends.
- **Rows, pages and menus redraw from observed state**: the connections, the
  lists, the runs and the upstreams, each written only where it changed. When
  each last answered is kept apart, unobserved, so an answer that changed
  nothing redraws nothing; the read logs and pending reads are not observed.
- **A branch hidden for a round keeps its lookup**, as long as a worktree
  follows it, so clearing a filter asks nothing again. One the recent runs list
  drops its lookup, their answer being newer; one whose lookup fails keeps the
  run it showed and is asked again next round; only its row says so, dated when
  that branch last answered.
- **A settled run's workflows and report are read once**, a run under way or on
  hold at most once a minute however often its list appears, one read at a time
  per run, and once more as it ends, a run reading failed while jobs still went;
  an earlier run's when its row opens.
- **A remote a partial clone filters is still a remote**: git prints its fetch
  line with ` [blob:none]` after it. A branch is matched in the repository its
  remote pushes to, which a triangular set-up sets apart from where it fetches.
- **A word for a job or workflow neither list knows leaves it out**, as a run's
  does, rather than drawing it as running for good.

## Reviewed and left as is

- **The branch scan's ref query has one retry, not two.** A review asked for a
  tier keeping the dates where the upstream atoms fail, but
  `upstream:remotename` (2.16) and `upstream:remoteref` (2.22) predate the 2.36
  floor, so no supported git refuses them.
- **Two switches word blockers**, `MergeReadiness.Blocker` for the panel and
  `PullRequestBlocker` for the row. Their shared cases already name the same
  catalogue keys; one type would tie the panel's verdict to the host's answer.
- **A shown pull request replaces the merged badge, closed ones too**, as was
  decided for the row, even where git proves the branch landed some other way.
- **Recent runs are keyed by branch name alone, before the repository check.** A
  CircleCI project lists only its own repository's runs, so two repositories
  never share one branch's key; the check only turns a fork's upstream away.
- **`GitRunLog` keeps its name though `gh` and `circleci` runs join it**, so
  Debug Info counts them beside git's. Renaming it means renaming Debug Info's
  git command feature, 23 files written before this work; its comment says what
  it holds.
- **The services' test fixtures sit with their tests**, `CircleCIFixtures` and
  `GitHubFixtures` beside the provider's and host's suites, as the user asked,
  rather than at the suite root.
- **`ServiceReadLog.isAsking` is internal for the tests alone**, which CLAUDE.md
  allows: they wait on a read's end through it rather than a timer.
- **The poll asks what is due on every five-second tick, and each project's CI
  read builds the sidebar's rows itself.** A tick with nothing due took 0.26 ms
  at 31 worktrees in a debug build; a deadline, or passing the rows down, would
  widen `refreshServices` and each of its callers for that.
- **Whether the provider's file is there is read from disk on each CI read**,
  the project's checkout first and each worktree after. A worktree on a mount
  that has gone stalls only its own project's read, off the main thread, and the
  status poll stats that worktree first anyway.
- **A branch whose reflog lost its creation entry keeps its upstream.** git gc
  expires reflog entries, by default after 90 days, and nothing else records
  what a branch was made from.
- **A failed `gh pr checks --required` fails the checks read.** Keeping the list
  with nothing required would call every required check optional and could call
  a blocked pull request ready; the next read asks again.
- **A branch pushed without `-u` to a remote other than `origin` has no
  upstream** where nothing names a push remote: git's own default is `origin`,
  and Create Pull Request asks about the remote's same-named branch as that.
- **A tooltip says one read's failure, the pull request host's first.** It dates
  what the row shows; a second line for the run's would repeat the reason for
  one glyph out of two.
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
- **The glyph's green and the page's Ready can briefly disagree.** The glyph
  takes GitHub's own `mergeStateStatus`, as the user chose; the banner weighs
  the checks, reviews and blockers it lists. GitHub answers `UNKNOWN` for a
  while after a push, and the glyph waits for its answer.
- **A rebase that changed a patch's context, or a squash before the merge, reads
  as outgrown.** Patch ids hash the context lines, as the merged badge's own
  patch proof does. Create then asks before it pushes, so the wrong answer costs
  a question declined. See "Asked both ways" for the rules tried before it.
- **A trunk commit cherry-picked onto a branch after its merge reads as
  outgrown.** The copy's hash is on no other branch, and its patch is not the
  head's. Seeing it on the trunk means patching every trunk commit since the
  fork, which round 6 dropped for its cost on each read; Create asks first.
- **A pull request GitHub calls `CLEAN` with a review still required is green**
  and says both: GitHub lets that viewer merge past the review.
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
- **A project removed and re-added at its path mid-read** may take that read's
  answer. Unproven: the fake host cannot tell the two reads apart, and the
  window is the read's few seconds.
- **CircleCI words no fixture has shown keep the rules they have.** An unknown
  current outcome falls back to the outcome, as an unknown phase does; a
  `succeed…` word other than `succeeded`, a phase on hold over a failing
  outcome, and an `authentication.` error code are guesses at output 1.11 has
  never printed.
- **A panel tab's tooltip stays up after a click until the pointer leaves.**
  Hiding it on the click needs a gesture beside the button's own, which no test
  here can drive.
- **`ExternalLinkButton`, `CreatePullRequestButton` and `View+CornerLink` stay
  in `Files/Panel/Services/`** though the popover draws them: a file's folder
  follows what it is, not who calls it.
- **`ProjectSettings.init` takes `disabledIntegrations`** though no caller
  passes it: the init lists every setting a user sets, as it does the rest.
- **`aSlowCheckOfAnEarlierToolCannotOverwriteTheNewOnesVerdict` waits three
  seconds for a verdict that must not come.** A check that nothing happened
  needs a window; under load it can pass without reaching the guard, never fail
  with the guard in place.
- **VoiceOver reaches the row's popover only through the actions menu's Open and
  Create.** The popover adds the run's workflows and jobs, which the CI page
  lists with each status spoken; the row reads out the stale note itself.
- **`ExternalLinkButton`'s stroke and `PullRequestGlyph`'s are each written
  out.** Both are 1.5 in 16, each glyph's own design stroke, and only the pull
  request's keeps a one-point floor; a shared width would tie them.
- **The row's popover lists a run's jobs as they stood when it opened or the run
  last changed.** The CI page follows a run under way through its poll; a
  popover is a glance, and following it would take a timer of its own.
- **A run whose status changes while its workflows are read for the popover may
  keep that read's answer.** Unproven: the new read waits on the one in flight,
  and the window is one `circleci` call.
- **A rerun that starts and fails between two reads keeps the first attempt's
  report.** Unproven: it holds only if `circleci` keeps a run's id across a
  rerun, which no output here has shown.
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
- **Where `UIMetrics.serviceGlyphSize` lives.** Round 1 moved it from
  `UIMetrics.swift` into `UIMetrics+ServicePages.swift`; round 3 asked it back,
  the sidebar row using it too. Kept in `+ServicePages`: that file holds the
  services' glyph sizes, the row's included.
