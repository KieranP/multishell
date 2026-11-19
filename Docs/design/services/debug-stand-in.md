# Debug stand-in

`debug services stand-in` answers for `gh` and `circleci` in place of each
service's own command-line tool, for a scripted run.

- **The stand-in answers for both tools, not for a worktree's state.** Rows,
  pages, checks and run details each read the host or provider, so their answers
  are the one place every reader sees; a stand-in set on a worktree would need a
  copy for each, and the poll would write over it. Cost: a scratch repository
  still needs a remote whose URL names the pull request's repository and the
  branch pushed to it.
- **A stand-in fills GitHub's and CircleCI's slots whatever is installed**, so a
  project's toggles still apply, and a scratch repository needs no CI config
  file.
- **Standing in or clearing drops what either side read**, and a read under way
  is waited out and its answer dropped, so a stand-in answer never shows beside
  a tool's. Clearing never searches the app's own PATH, which a test runner's
  real `gh` is on.
- **A stand-in is JSON keyed as the domain types name their fields, raw values
  as `worktrees show` prints them**: `pullRequests`, each with `number`,
  `title`, `state`, `headBranch`, `headCommit` and `headRepository` (a remote
  URL or `owner/name`), and optionally `url` (its GitHub page by default),
  `review`, `blocker`, `isReadyToMerge`, `autoMergesWhenReady`, `baseBranch`,
  `updatedAt`, `checks` (`name`, `status`, `workflow`, `isRequired`, `link`,
  `log`, the text a failed log read answers) and `threads` (`id`, `path`,
  `line`, `originalLine`, `isOutdated`, `diffHunk`, `comments` of `id`,
  `author`, `body`, `url`), a thread with no comments refused as the host never
  answers one; and `ciRuns`, each with `id`, `branch`, `commit` and `status`,
  and optionally `subject`, `isFinished`, `createdAt`, `repository` (where it
  ran; none matches every project), `workflows` (`name`, `status`, `jobs` of
  `id`, `name`, `status`) and `failures` (`workflow`, `job`, `text`). Dates are
  ISO 8601.
- **A value the stand-in cannot read refuses all of it**, naming the key path,
  rather than dropping one run unseen. The helper sends the file's text, so the
  app opens no path a request names; the socket's line length is the limit.

## Reviewed and left as is

- **`debug services stand-in` works with the debug tools off**, as
  `debug report` does: both set what the app shows for a scripted run, the
  socket is the user's own at mode 0600, and a relaunch clears it.
- **A stand-in's dates may carry fractional seconds**: `.iso8601` reads them.
- **The stand-in's waits live in the shared reads**: `refreshServices` and
  `readPanelServices` say whether their read was kept, and the read logs resume
  waiters. A request answering before the stand-in shows sent scripts to poll.
- **A stand-in recomputes each project's services in turn**: a debug command, at
  a sidebar's few dozen rows.
- **A stand-in's recent runs are every project's**, as it cannot tell which
  repository a directory is. Runs of two repositories on one branch name can
  show on the wrong row; a stand-in gives each its own branch names, or the
  history page, filtered by repository, shows each its own.
- **A stand-in may read a shown project twice.** The read it outwaits schedules
  its own re-read. Its answers are instant, and the extra cost is a `git remote`
  and a past-head check per project, on a debug command.
