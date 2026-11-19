# Sending feedback to an agent

The PR and CI pages send a pull request's failing checks, its unresolved review
threads and a CI run's failed jobs to an agent pane (issue #34). Mockups on the
issue. Newest at the bottom.

- **The pages send, not Review.** An "Add to Review" on each item, so one Send
  carried everything, was offered and not taken (owner's choice, 2026-11-19).
  Each page has Review's foot, the same picker, no count and no hint.
- **The foot and picker are shared, as `Handoff*`.** Review's `ReviewRecipient`,
  `ReviewFooter`, `ReviewRecipientMenu` and `ReviewSendFooter` became
  `HandoffRecipient`, `HandoffFooter`, `HandoffRecipientMenu` and
  `HandoffSendFooter` in `Files/Panel/Handoff/`, and their strings `handoff.*`
  (owner's choice, 2026-11-19; NEW, not a reversal). "Handoff" is the word
  `AgentHandoff` already used. One pick per worktree serves all three pages.
  Each page wraps the foot in a view of its own, `ReviewSendFooter`,
  `PullRequestSendFooter` and `CISendFooter`, so an agent's state change redraws
  the foot and not the page.
- **Every item has a checkbox at the row's trailing edge.** Failing checks stay
  under the Checks step in the host's order; a passing row keeps the empty slot,
  so the Required tags stay in one column. A failing required check and every
  thread start checked, an optional failing check unchecked.
- **A step's own checkbox is AppKit's, with its mixed state.** "Check all" and
  "Uncheck all" were mocked and replaced (owner's choice, 2026-11-19). SwiftUI's
  toggle draws no mixed state from one value, so `HandoffCheckbox` wraps
  `NSButton` and undoes AppKit's own cycling on a click: the model decides. A
  click on a mixed box checks all, as AppKit's does. It answers bot reviewers
  that leave thirty threads.
- **A collapsed step says "1 to send"** after its hint, and a collapsed Latest
  run after its title, since Send carries their checked items unseen.
- **Threads list under the review step**, or, where the path has none, a
  Comments step of their own with Review's speech bubble, since an unresolved
  thread neither passes nor fails. That step is not counted among the steps left
  to clear: a thread holds no merge back. A merged or closed pull request lists
  none, on the page, in the foot or in a Send, though a read before it settled
  is kept until the next.
- **A sent item's checkbox becomes a green bubble**, a paper plane on
  `ui.ci.passed`, its tooltip naming the agent. Review's "Sent to Claude Code"
  chip was mocked and dropped: it took a line per item. A click on the bubble
  turns it back into a checked box, to send the item again.
- **Item keys change where the thing does**: a check by its name, link and head,
  since two checks can share a link and some keep theirs across a push; a thread
  by its id and newest comment, so a new comment comes back checked; a CI job by
  run, its place and job id, two workflows able to share a name; Run output by
  run and its text's hash, a CircleCI rerun keeping the run's id. A rerun or
  push needs no code to clear a bubble.
- **Choices and sent marks are runtime state** on `AppModel`, not saved as
  Review's comments are: a relaunch shows everything unsent, which costs a
  second send at most. Each page read lets go of the keys that page no longer
  lists, each kind once its read answered, a failed run's report included, so a
  failing thread read still lets the checks' old keys go: an item whose details
  another worktree's read dropped keeps its mark.
- **The CI page finds a job's item by its place**, workflow index then job
  index: two workflows can share a name.
- **What Send writes is `AgentHandoff`'s file**, a section per item, and the
  mention is pasted as Review's is, with no Return. A check: its name, the head
  it ran on where the worktree is elsewhere, its log's last 80 lines, its page.
  A thread: its place, the end of its hunk, every comment. A CI job: its
  workflow and name, its part of the report, its job id. Files are
  `pr-<n>-<worktree>.md` and `ci-<worktree>.md`.
- **A worktree on another commit than the failure ran on is told so** in the
  item's caveat, without saying which is ahead: Update branch on GitHub puts the
  head past the worktree, unpushed commits the other way. Both pages match
  commits by `namesSameCommit(as:)`, a seven-character prefix at least.
- **Logs and reports keep their last 80 lines**, a count of those cut said
  first. Where a build fails is at the end, and a whole log is not for an
  agent's context. The number is a choice, not a measurement.
- **An Actions check's log is read at Send** from the job's REST endpoint,
  `gh api --hostname <host> --allow-escape-sequences repos/<owner>/<repo>/actions/jobs/<id>/logs`,
  the job id from the check's link (`/actions/runs/<run>/job/<job>`, seen on
  #43). `gh run view --job` refuses every job until its whole run ends, so a
  lint job failing early sent no log (seen on #46). The endpoint gives the whole
  job, the runner's cleanup after the failure, so the log ends at its last
  `##[error]` line. Each line's timestamp, a step's byte-order mark, its
  terminal codes and Actions' group markers are stripped, a fold's end dropped
  so it takes no line, and a CRLF line split as any other. Four read at once, as
  other service reads, and only the last 160 lines are cleaned, the lines before
  them counted in bytes so the cut is said in the whole log's terms, a line
  ending at `\n` alone so a progress bar's `\r` stays in its line, the tail
  trimming blank and marker lines to 80. "Reading N logs" counts the checks the
  host can read. A check from any other CI sends its name and link.
- **While logs read, the foot says "Reading 1 log" and Send is off**, so a
  second click sends nothing twice: a Send with checks is claimed before any
  read, a thread read included, and the foot says "Reading what to send" until
  its logs are counted. A Send of threads alone reads no log, so goes meanwhile.
  A Send for a worktree whose PR page is not on the panel, or with the app in
  the background, from `pr send`, reads its checks, their head and its threads
  first, together, the page reading them only while shown and frontmost, so none
  sent are stale, and checks a push moved are captioned with the head they ran
  on; one on the page before its first thread read answers sends none, a box
  nobody has seen not going checked; their text dropped with the row; a page
  whose thread read failed sends the threads it still shows from the last read
  that answered, under its note, else its checks without them; checks that fail
  to read off the page are left out the same way; failing that it sends nothing
  and says why, checks first. Threads alone from a page whose thread read failed
  say why too. Send then goes to the pane the picker showed, or nowhere: one
  closed meanwhile gets nothing, the foot says so, and the items stay checked. A
  paste the pane refuses says so over the foot, on either page, as does a pane
  picked and closed before the click, though not a `--to` naming a pane with no
  agent; a file that cannot be written is said by its alert alone. A box
  unchecked meanwhile is left out. A log that fails to read is sent anyway,
  `gh`'s words as its caveat, and an empty one says it printed nothing: the
  agent can open the link, and one log should not hold back the rest.
- **The CI page reads nothing new.** It sends the report its page already read.
  Only the newest run's jobs can be sent; earlier runs are history. A job that
  failed while its run still goes has no report until the run ends, and says so
  under its row; sent then, it goes without one. A job an ended run's report
  leaves out is said to be left out.
- **Report text naming no listed job is "Run output"** with a checkbox of its
  own: it can be the only failure, a config error before any job ran. A job the
  report speaks of can be sent whatever unclear status the provider gave it, its
  text being shown under its row; one that passed cannot, a rerun's passing job
  sharing a failed one's names. A run that passed has nothing to send; a
  cancelled one's failed jobs can be.
- **Unresolved threads are read while the PR page shows**, beside its checks and
  at their pace, through `gh api graphql` (`reviewThreads`, a hundred a page,
  ten pages at most): `gh pr view` does not say whether a thread is resolved.
  `gh api` is still the tool, with `gh`'s login and `--hostname` for Enterprise.
  A failed read is a note under the card. Thread text is kept for the panel's
  worktree alone, as run details are: a change of row drops the rest, and a late
  read for a row left is not kept. A return to a row whose threads were dropped
  reads them at once rather than at the next poll. The two reads run together.
  Only the first comment's hunk is asked for: it places the thread.
- **An outdated thread is labelled by the line it was written on**, its `line`
  being gone, and tagged Outdated; one on a whole file by its path.

## Reviewed and left as is

- **A CircleCI job and its pull request check are two items.** Counting them as
  one needs the check's link matched to the job's id, which nothing here has
  shown can be done.
- **A thread's comments are its first hundred.** No review thread seen comes
  near; paging them would be a query per thread.
- **The PR page's Send keeps the pull request it began with.** A push during the
  log reads leaves the checked checks in, the checks list being the one it drew.
  Only a checks read at the new head between them would drop them, and those
  would be the old head's.
- **Send's focus after the log reads does not move the selection.** Taking the
  agent's tab focuses it within its worktree; selecting another worktree during
  the reads keeps it selected (tried on 2026-11-19).
- **Review keeps its own receipt.** It clears when a comment is added, a rule
  about comments; the PR and CI pages' clears when none of their items is marked
  sent. One store would hold two rules.
- **A worktree removed during the log reads leaves no note behind.** Tried on
  2026-11-19: the Send finds its pane gone and stores nothing for it.
- **A Send whose file cannot be written answers `pr send` with the error's
  alert**, not with a refusal of its own: a request's alert is its answer
  (agents/command-line.md), and the app presents the write's error.
- **`review send` with a file it cannot write answers with the write's alert**,
  not "pane has no shell yet": a request's alert replaces its refusal (tested on
  2026-11-19). `sendReview` keeps its Bool.
- **A Send clicked as the picked agent exits, its pane still open, says
  nothing.** The foot redraws on the board's next change with the next agent or
  "No agent"; the window is one redraw, and a note would need the UI's Send told
  apart from a script's `--to` naming a shell.
- **A script's `--to` naming a closed pane notes "The pane picked has closed"
  over the page's foot**, as a script's other misses are noted there. Telling it
  from the page's Send needs the flag the entry above declines.
- **A thread's comment text goes to the agent as written**, a bot's own headings
  included: escaping it would change the code it quotes, as
  files/review-comments.md settles for Review's comments.
- **The PR page reads its threads twice a draw**, once for the merge path's
  count and once for its rows and foot. Both run in one synchronous draw on the
  main actor, so no read lands between them; one is a dictionary lookup.
- **Unproven: a failed log taking past the 30 s read timeout.** It would be sent
  with "did not answer in time" as its caveat. No log here has come close.
- **Unproven: a thread on removed lines, or on several, is labelled by one line
  number.** GitHub's `line` may be the base file's for a removed line, and a
  range shows its last line; the quoted hunk still places it. Asking for
  `diffSide` and `startLine` would say more.
- **Unproven: OSC escapes, such as terminal hyperlinks, are not stripped** from
  a log, only CSI codes. No log here has carried one.
