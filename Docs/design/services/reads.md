# Reading pull requests and CI runs

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
- **Every read lists the whole project at once.** `gh pr list --state all` lists
  the newest hundred, open or not; `circleci run list` the newest fifty runs on
  any branch. A branch either list left out is asked alone: for pull requests
  every worktree's pushed branch but the trunk, its remote branch gone or not;
  for runs a shown, pushed one.
- **A branch's pull requests are asked alone with `gh pr list --head`**, every
  state, ten at most. A busy repository's hundred covers only weeks, and a
  branch whose pull request was older, open or merged, read "No pull request".
  GitHub deletes a merged branch, so a gone branch is still asked: its merged
  pull request is the proof the removal dialog leads with.
- **Not one list of every open pull request.** Asking all of them in full failed
  GitHub at a hundred open on rails/rails on 2026-11-02: `mergeStateStatus` is
  worked out per open pull request. Numbers and branches alone answered, but
  found no closed or merged one.
- **The trunk is not asked alone**: forks open pull requests from their own
  `main`, and each would be read every round. `--head` matches a branch name in
  any repository; the match then drops a fork's. A fork's same-named pull
  request in the hundred is not the branch's, so the branch is still asked.
- **A branch asked alone is not asked again until it is pushed to**, or until
  its run ends, on hold included: an approval raises no event, and a row stuck
  on "on hold" after one cost more than a call per such branch each round.
  Otherwise every round paid a call for each old or never-run branch. Cost: a
  run started on a branch by another trigger, a schedule or an API call, is seen
  only once its branch moves or the recent runs list it.
- **After a push, a branch asked alone is asked each round until a run of the
  pushed tip appears, for ten minutes at most.** The read straight after a push
  can beat CircleCI to making the run, and its answer, the run before or none,
  stood until the next push in a repository busy enough that fifty runs never
  named the branch. Past ten minutes the tip is taken never to run, a
  `[skip ci]` commit say, and the answer stands. A run whose status is unknown
  is asked each round, as one under way is.
- **A pull request found alone is asked again while it is open**, as its review,
  checks and merge move with no push; one merged or closed stands until the
  branch moves. A branch the hundred names drops what it was asked alone, so its
  pull request falling out of the hundred later is asked afresh.
- **A branch that fails alone fails the pull request read**, which keeps the
  list and lookups before it.
- **Cost of the hundred**: a closed or merged pull request older than the
  hundred newest, on a branch no worktree has out, reads as none.
- **Polled, unlike `git fetch`.** A review, a teammate's push, a run finishing
  and a pull request opened on the web raise no local event, and these reads
  write nothing local, ask for no credentials and time out at 30 s.
- **Every two minutes for each project with a row in view, while frontmost**, a
  launch in the background, as a login item, asking nothing until it comes to
  the front; every minute where a shown run is under way, a hidden or filtered
  row's run hastening nothing. A return to the front reads again past thirty
  seconds, so switching apps asks nothing. A run on hold is not under way here:
  it waits on a person, perhaps for days.
- **The pull request page reads its checks every minute too while nothing it
  read accounts for GitHub's blocked.** Straight after a push GitHub made the
  runs 44 s later, and `gh` lists no required check before then, so the page
  named a rule as the blocker for two minutes. A required review accounts for
  the block, so a pull request waiting on one keeps the two minutes. Cost: one
  held by a rule Multishell cannot read, signed commits say, is asked each
  minute while its page shows.
- **A branch's kept lookup goes once the remote has deleted the branch**: it is
  never asked again, so its last run, running when the branch merged, spun on
  the row and hastened the poll for good.
- **The checks are kept only where the pull request still heads the listed
  commit**, read with `gh pr view --json headRefOid` once they answer.
  `gh pr checks` reads the head as it is now, so after a push the list had not
  seen, the new head's empty checks stood as the old head's passing ones and the
  page offered Merge. A moved head reads the list again. Cost: one more `gh`
  call per checks read.
- **A merged or closed pull request's checks are read again while any still runs
  or the last read failed**, as one merged past its checks leaves them running
  and a failed read's note would stand for good; otherwise once at its head.
  Cost: a status its service left pending for good is asked each minute while
  that pull request's page shows.
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
  pull request from reading ready, and Create Pull Request counts the commits
  the remote lacks, `rev-list` from the upstream's tip, before deciding there is
  nothing to push, and opens nothing where git cannot count them. It counts
  afresh on every click and asks the remote, `ls-remote`, whether the branch is
  still there.
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
- **Every tool run is timed into the git run log**, named with its program, so
  Debug Info counts it beside git's.
- **CircleCI's phase and outcome words are not documented.** The fixtures are
  1.11's real output, `ended` with `succeeded`, `failed` or `canceled`. The
  current outcome is read first, then the outcome, then the phase, each in full,
  its API's words exactly and any other loosely, so a rerun's new word still
  outranks the first attempt's. A word neither knows is not guessed: the run,
  workflow or job reads as unknown, a grey ring holding a question mark, said
  "status unknown". Dropping it, as builds before 2026-11-03 did, showed the run
  before it as the branch's newest, or nothing. A job's `(execution …)` note is
  dropped from its name, and only that.
- **A run or workflow under way says `started` and no outcome at all**, as 1.13
  prints it. Until 2026-11-03 that word was unknown, so a running run was
  dropped: its row showed the run before it, often the failure being fixed, or
  nothing, and a branch asked alone kept "never run" until its next push.
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
- **A branch hidden for a round keeps its lookup**, as long as a worktree
  follows it, so clearing a filter asks nothing again. One the recent runs list
  drops its lookup, their answer being newer; one whose lookup fails keeps the
  run it showed and is asked again next round; only its row says so, dated when
  that branch last answered.

## Reviewed and left as is

- **A run's workflows or report read across a tool change are dropped**, not
  read again at once: the CI page's poll asks again.
- **Every tool adoption drops the reads under way**, a login-shell re-adoption
  included: they asked tools since replaced, and each is read again at once.
- **Each reader takes the integration count before its tool and compares it
  after**, eight of them, as the toggles' reads always have: a token type would
  wrap one `Int` and one comparison.
- **The branch scan's ref query has one retry, not two.** A review asked for a
  tier keeping the dates where the upstream atoms fail, but
  `upstream:remotename` (2.16) and `upstream:remoteref` (2.22) predate the 2.36
  floor, so no supported git refuses them.
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
- **A tooltip says one read's failure, the pull request host's first.** It dates
  what the row shows; a second line for the run's would repeat the reason for
  one glyph out of two.
- **A project removed and re-added at its path mid-read** may take that read's
  answer. Unproven: the fake host cannot tell the two reads apart, and the
  window is the read's few seconds.
- **CircleCI words no fixture has shown keep the rules they have.** An unknown
  current outcome falls back to the outcome, as an unknown phase does; a
  `succeed…` word other than `succeeded`, a phase on hold over a failing
  outcome, and an `authentication.` error code are guesses at output 1.11 has
  never printed.
- **`ProjectSettings.init` takes `disabledIntegrations`** though no caller
  passes it: the init lists every setting a user sets, as it does the rest.
