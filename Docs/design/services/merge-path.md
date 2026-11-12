# The merge path

The pull request page under its card: the steps a merge goes through, on a rail
ending at the merge. Chosen on 2026-11-12 over a tinted banner above a flat
list, issue #39: the banner's reasons repeated as rows below it, and with eight
or more checks the failing one sat among the passing ones.

- **The steps, in order**: the draft, conflicts with the base, being behind it,
  the checks, the review, then a rule on the base. The order is the page's, not
  GitHub's, which imposes none. A rule shows only where nothing else accounts
  for the host's blocked, as `MergeReadiness` adds `.blockedByRules`. A merged
  or closed pull request lists no conflicts step, GitHub having stopped working
  them out, no base or rule step, though GitHub still answers it BEHIND or
  BLOCKED, and a review step only where it was approved: a closed one said it
  was still waiting on a review until 2026-11-12.
- **Each step wears the CI run glyph of its state**, a conflict the warning
  glyph, and the rail under a passed one is green, faded. The glyphs start at
  the card's left edge, as every other row's glyph on the panel does.
- **Every check sits under Checks, in the host's order**, each required one
  tagged, where the old list put the required first. Its line counts the
  required ones, a skipped or cancelled one named apart as not run, and adds the
  optional ones that failed; its glyph is the worst required check's, as the
  verdict weighs only those, letting one that did not run pass. The title
  collapses the list, which starts open. No check listed, no step.
- **Before a read answers the step says it reads them**; after a failed one it
  says they were not read, `gh`'s words and that the next poll reads again. A
  failed read after one that answered is a note under the card: the checks still
  shown may be out of date, or, where it listed none, they were not read again,
  then `gh`'s words. A required check on hold or of unknown status counts as not
  run, as the verdict lets it pass.
- **A step that needs the user says what fixes it**: merging the base in for a
  conflict or being behind, marking a draft ready, the host naming a rule. A
  required review says a person may take a while.
- **The last step offers what the page offered before, by the same rule**:
  Merge, Merge When Ready or Cancel Auto-Merge; see
  [create-and-merge.md](create-and-merge.md). Otherwise a disabled Merge says
  how many steps are left, or that only the checks' read is. A merge the host
  took shows no button, and says so, until the list shows it: Merge When Ready's
  pending checks would otherwise call for a click already made. The disabled
  button is new: the banner showed none until it could act. Asked on issue #39
  and kept until the user says otherwise.
- **A merged pull request ends on the merge glyph** and Remove Worktree, the
  sidebar menu's own item, shown and greyed where that menu shows and greys it.
  One the branch outgrew, and a closed one, end on Create Pull Request where the
  model offers it.
- **The words are the theme's text colour, not its secondary grey**: at 11 pt
  the grey measured 4.0:1 on the panel in Multishell Light. The chevron and the
  card keep their greys.

## Reviewed and left as is

- **A merged pull request says "Merged into main" on the card and at the path's
  end.** The card's state line is shared with the row's tooltip; the end is the
  rail's last stop.
- **"2 of 3 required passed" takes its plural from the total.** The counted part
  is "3 required passed" inside "%1$d of %2$@": `TranslationTests` hold every
  counted phrase to one argument, and English reads the same either way. A
  language whose verb agrees with the passed count would need the rule changed
  first.
- **A merged pull request does not say what is left in the worktree**, which
  issue #39 asked for where Remove is unavailable. The issue took the sidebar to
  grey Remove over uncommitted or unpushed work; it does not, and its removal
  dialog warns of the changed files instead. The button greys only while a
  create or removal runs there.
- **The rail turns green in the view, on a step's status being passed.** It
  reads the status MultishellAppCore decided and tested; a property saying
  `status == .passed` again would only rename it.
- **The test that a reason ending in a full stop is not given a second has no
  format left that could fail it.** It failed on the format it replaced, and
  stays to catch that format coming back.
