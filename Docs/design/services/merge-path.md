# The merge path

The pull request page under its card: the steps a merge goes through, on a rail
ending at the merge. Chosen on 2026-11-12 over a tinted banner above a flat
list, issue #39: the banner's reasons repeated as rows below it, and with eight
or more checks the failing one sat among the passing ones.

- **The step order is the page's, not GitHub's**, which imposes none. A rule
  shows only where nothing else accounts for the host's blocked. A merged or
  closed pull request lists no conflicts step, GitHub having stopped working
  them out, and no base or rule step, though GitHub still answers it BEHIND or
  BLOCKED; a review step only where it was approved: a closed one said it was
  still waiting on a review until 2026-11-12.
- **Every check sits under Checks, in the host's order**, each required one
  tagged, where the old list put the required first. Its glyph is the worst
  required check's, as the verdict weighs only those, letting one that did not
  run pass. A required check on hold or of unknown status counts as not run for
  the same reason.
- **A disabled Merge says how many steps are left.** The banner showed no button
  until it could act; the disabled one was asked on issue #39 and is kept until
  the user says otherwise. The offer follows
  [create-and-merge.md](create-and-merge.md). A merge the host took shows no
  button until the list shows it: Merge When Ready's pending checks would
  otherwise call for a click already made.
- **The words are the theme's text colour, not its secondary grey**: at 11 pt
  the grey measured 4.0:1 on the panel in Multishell Light.
- **Unresolved review threads are not counted among the steps left**: a thread
  holds no merge back. See [send-feedback.md](send-feedback.md).

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
  dialog warns of the changed files instead.
- **The rail turns green in the view, on a step's status being passed.** It
  reads the status MultishellAppCore decided and tested; a property saying
  `status == .passed` again would only rename it.
- **The test that a reason ending in a full stop is not given a second has no
  format left that could fail it.** It failed on the format it replaced, and
  stays to catch that format coming back.
