# Debug stand-in

`debug services stand-in` answers for `gh` and `circleci` in place of each
service's own command-line tool, for a scripted run.

- **`debug services stand-in` answers for both tools, not for a worktree's
  state.** Rows, pages, checks and run details each read the host or provider,
  so their answers are the one place every reader sees; a stand-in set on a
  worktree would need a copy for each, and the poll would write over it. Cost: a
  scratch repository still needs what the tools would, a remote whose URL names
  the pull request's repository and the branch pushed to it.
- **A stand-in fills GitHub's and CircleCI's slots whatever is installed**, so a
  project's toggles still apply. Every repository runs on its CI, the
  configuration path being the checkout, so a scratch one needs no config file.
- **Standing in or clearing drops what either side read**, and before it answers
  reads again the projects with rows in view and an open services page, the rest
  when next due, as the poll would. A read under way is waited out and its
  answer dropped, so a stand-in answer never shows beside a tool's. Cleared, the
  last adopted tools come back without searching again; none where the login
  shell's PATH was never adopted, so the app's own PATH, which a test runner's
  real `gh` is on, is never searched. A relaunch clears it too.
- **A stand-in is JSON keyed as the domain types name their fields, raw values
  as `worktrees show` prints them**: `pullRequests`, each with `number`,
  `title`, `state`, `headBranch`, `headCommit` and `headRepository` (a remote
  URL or `owner/name`), and optionally `url` (its GitHub page by default),
  `review`, `blocker`, `isReadyToMerge`, `autoMergesWhenReady`, `baseBranch`,
  `updatedAt` and `checks` (`name`, `status`, `workflow`, `isRequired`, `link`);
  and `ciRuns`, each with `id`, `branch`, `commit` and `status`, and optionally
  `subject`, `isFinished`, `createdAt`, `repository` (where it ran; none matches
  every project), `workflows` (`name`, `status`, `jobs` of `id`, `name`,
  `status`) and `failures` (`workflow`, `job`, `text`). Dates are ISO 8601.
- **A value the stand-in cannot read refuses all of it**, a key no record takes
  or one missing included, naming the key path, rather than dropping one run
  unseen. The helper reads the file and sends its text, so the app opens no path
  a request names; the socket's line, the JSON's quotes escaped, is the limit.

## Reviewed and left as is

- **`debug services stand-in` works with the debug tools off**, as
  `debug report` does: both set what the app shows for a scripted run, the
  socket is the user's own at mode 0600, and a relaunch clears it.
- **A stand-in's dates may carry fractional seconds**: `.iso8601` reads them, as
  `aDateWithFractionalSecondsIsRead` shows.
- **The stand-in's waits live in the shared reads**: `refreshServices` and
  `readPanelServices` say whether their read was kept, and the read logs resume
  waiters. A request answering before the stand-in shows sent scripts to poll.
- **A stand-in recomputes each project's services in turn**, each pass over the
  worktrees' services: a debug command, at a sidebar's few dozen rows.
- **A stand-in's recent runs are every project's**, as it cannot tell which
  repository a directory is; the reads trust a tool to list the project's own.
  Runs of two repositories on one branch name show the newer on both; a stand-in
  gives each its own branch names, or the history page, filtered by repository,
  shows each its own.
- **A stand-in may read a shown project twice.** The read it outwaits schedules
  its own re-read, and a provider turning readable schedules another; the
  stand-in's own read runs beside them. Its answers are instant, and the extra
  cost is a `git remote` and a past-head check per project, on a debug command.
