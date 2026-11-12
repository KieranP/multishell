# Marks and panel pages

A worktree's pull request and its newest CI run, drawn on its row and on the
panel's pages.

- **Opening a page is the tool's**, `gh pr view --web` and `circleci run open`,
  so an Enterprise host or CircleCI server opens its own.
- **The marks**: the pull request glyph green where the host would merge it now
  (GitHub's `CLEAN` or `HAS_HOOKS`), red for changes requested whatever GitHub
  says, faint while a review is wanted, and the area's text colour otherwise, an
  approval still waiting on checks included: the user asked that green mean
  ready, and the state's words say "Ready to merge" with it. It is dashed for a
  draft, crossed when closed, the merge glyph once merged, and one corner dot,
  yellow for a conflict over blue for auto-merge, the conflict being what needs
  the user. Every services glyph, the Changes, PR and CI tabs and a conflict's
  warning too, is the approved design's own strokes, not an SF Symbol, and so is
  the Files tab's file tree since 2026-11-05 (REVERSAL of keeping its symbol):
  `doc.on.doc` is the system's Copy and the app's Copy button. The running ring,
  the design's four arcs, turns wherever it is drawn, the sidebar's rows
  included, by Core Animation in the render server, so it costs the app no
  frame; a SwiftUI rotation redrew the whole sidebar each frame, which kept it
  still there before. Reduce Motion keeps it still.
- **The window's header shows no services.** The row and the panel's pages say
  them; the user cut a header pill that repeated them. A click on the row's pull
  request or run glyph opens the panel on its page, as the git badge opens
  Changes, and VoiceOver reaches both as the row's named actions; the user cut a
  popover that repeated the pages on 2026-10-29. The row's tooltip stays. On the
  row the pull request and run glyphs sit just after the git changes, left of
  the terminal count, where the user put them, and VoiceOver reads them in that
  order.
- **Colours are the theme's `ui.pull_requests` and `ui.ci`**, seeded from each
  built-in theme's `ui.states`; the greys are the area's, as idle's is, and the
  merge glyph takes `ui.git.merged`, the colour of the badge it replaces.
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
  for the panel's own worktree**, its history and the row's run it falls back
  on: a return to a row asks again only when due, and other worktrees' workflows
  and reports do not sit in memory. The row's popover, which read a row's
  details too, went on 2026-10-29. Rows passed quickly read nothing; the one the
  selection rests on reads once it settles. A merged or closed pull request's
  checks are read once at its head, or again while one still runs or the last
  read failed; see [reads.md](reads.md).
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
  conflicts out, which the panel says as checking rather than as none. The page
  draws it as the merge path's steps; see [merge-path.md](merge-path.md). Checks
  count only for the head they were read at, so a push leaves the verdict
  waiting on the new head's. The host's own "blocked" is said only where none of
  those accounts for it, such as a rule for signed commits.
- **A pull request waiting on a person is on hold, not running**: a required
  review's step and a draft's draw the pause, as a CI run on hold does, since
  either may wait days. The ring turns only while a machine works: a check
  running, conflicts not worked out, checks not read. The user chose this on
  2026-10-28.
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
- **A settled run's workflows and report are read once**, a run under way or on
  hold at most once a minute however often its list appears, one read at a time
  per run, and once more as it ends, a run reading failed while jobs still went;
  an earlier run's when its row opens.

## Reviewed and left as is

- **Two switches word blockers**, `MergePath`'s steps for the panel and
  `PullRequestBlocker` for the row. Their shared cases already name the same
  catalogue keys; one type would tie the panel's verdict to the host's answer.
- **A failed `gh pr checks --required` fails the checks read.** Keeping the list
  with nothing required would call every required check optional and could call
  a blocked pull request ready; the next read asks again.
- **The glyph's green and the page's Merge can briefly disagree.** The glyph
  takes GitHub's own `mergeStateStatus`, as the user chose; the merge path
  weighs the checks, reviews and blockers it lists. GitHub answers `UNKNOWN` for
  a while after a push, and the glyph waits for its answer.
- **A pull request GitHub calls `CLEAN` with a review still required is green**
  and says both: GitHub lets that viewer merge past the review.
- **A panel tab's tooltip stays up after a click until the pointer leaves.**
  Hiding it on the click needs a gesture beside the button's own, which no test
  here can drive.
- **`ExternalLinkButton`'s stroke and `PullRequestGlyph`'s are each written
  out.** Both are 1.5 in 16, each glyph's own design stroke, and only the pull
  request's keeps a one-point floor; a shared width would tie them.
- **A rerun that starts and fails between two reads keeps the first attempt's
  report.** Unproven: it holds only if `circleci` keeps a run's id across a
  rerun, which no output here has shown.
- **Each row glyph keeps its own spoken label** though the row ignores its
  children: they are read while the row is being renamed, when they can be
  reached, as the single button's label was.
- **`CIJobRow` greys out a job with no id itself.** It reads one field of the
  job, which `openCIJob` guards again; no rule chooses between rows.

### Asked both ways

- **Where `UIMetrics.serviceGlyphSize` lives.** Round 1 moved it from
  `UIMetrics.swift` into `UIMetrics+ServicePages.swift`; round 3 asked it back,
  the sidebar row using it too. Kept in `+ServicePages`: that file holds the
  services' glyph sizes, the row's included.
