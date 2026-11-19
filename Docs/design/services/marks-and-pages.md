# Marks and panel pages

A worktree's pull request and its newest CI run, drawn on its row and on the
panel's pages.

- **Opening a page is the tool's**, `gh pr view --web`, `circleci run open` and
  `circleci job open`, so an Enterprise host or CircleCI server opens its own. A
  check's own link opens only where it is http or https.
- **The pull request glyph is green only where the host would merge it now**
  (GitHub's `CLEAN` or `HAS_HOOKS`): the user asked that green mean ready, so an
  approval still waiting on checks is not. Changes requested is red whatever
  GitHub says. A conflict's dot wins over auto-merge's, the conflict being what
  needs the user.
- **The merge glyph takes `ui.git.merged`**, the colour of the badge it
  replaces; the rest take `ui.pull_requests` and `ui.ci`, seeded from each
  built-in theme's `ui.states`.
- **Every services glyph is the approved design's own strokes, not an SF
  Symbol**, and so is the Files tab's file tree since 2026-11-05 (REVERSAL of
  keeping its symbol): `doc.on.doc` is the system's Copy and the app's Copy
  button.
- **The running ring turns by Core Animation in the render server**, so it costs
  the app no frame; a SwiftUI rotation redrew the whole sidebar each frame,
  which kept it still on rows before. Reduce Motion keeps it still.
- **The window's header shows no services**: the user cut a header pill that
  repeated the row and the panel. A click on the row's glyph opens the panel on
  its page; the user cut a popover that repeated the pages on 2026-10-29. The
  glyphs sit just after the git changes, left of the terminal count, where the
  user put them.
- **A page whose tool has gone shows Files**, rather than a page nothing can
  fill.
- **A services page drops the Files listing**: it lists no files, and Linux
  holds 80 MB of tracked and ignored entries.
- **A page's reads are its own and only while it shows**, logged per worktree
  and page, so turning pages mid-read still reads the new one.
- **A run's details are read again at most once a minute while it runs**,
  however often its list appears: the row's and the page's copies, read at other
  times, can disagree. A settled run's are read once, and once more as it ends,
  a run reading failed while jobs still went.
- **When each read last answered is kept apart from the observed state**, so an
  answer that changed nothing redraws nothing.
- **Run details are kept only for the panel's own worktree**, so other
  worktrees' workflows and reports do not sit in memory; a return to a row asks
  again only when due. Rows passed quickly read nothing; the one the selection
  rests on reads once it settles. See [reads.md](reads.md).
- **A turn of the page or a change of row reads only what is due**, and only
  while frontmost, as the poll does: arrowing through ten rows asked `gh` twenty
  times.
- **Checks are two calls run together**, `gh pr checks` and
  `gh pr checks --required`, the second being the only way `gh` says which are
  required. It exits 1 for a failing check and 8 for a pending one with the list
  printed either way, and 1 with none where there are no checks, read as an
  empty list.
- **A rerun is listed once, as its newest job**, the one with the higher number
  in its link: `gh` lists it beside the run it replaced.
- **Whether a pull request can merge is the panel's verdict**, drawn as the
  merge path's steps; see [merge-path.md](merge-path.md). GitHub answers
  `mergeable: UNKNOWN` until it has worked conflicts out, which the panel says
  as checking rather than as none. Checks count only for the head they were read
  at, so a push leaves the verdict waiting on the new head's. The host's own
  "blocked" is said only where nothing else accounts for it, such as a rule for
  signed commits.
- **A pull request waiting on a person is on hold, not running**, as a CI run on
  hold is, since either may wait days. The ring turns only while a machine
  works. The user chose this on 2026-10-28.
- **The CI card's link opens the branch by its upstream name**, the page showing
  a run the row may not have.
- **Both pages send what failed to an agent**; see
  [send-feedback.md](send-feedback.md).

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
