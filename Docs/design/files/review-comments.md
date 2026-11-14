# Review comments

Comments on a file tab's lines, sent to the worktree's agent from the Files
panel's Review page (issue #6). Newest at the bottom.

- **Comments sit inline in the file tab, as cards under their lines.** A popover
  per comment and a tray under the file were tried in mockups and dropped:
  neither showed a comment beside the code it is about.
- **Sending lives on a Review page of its own, between Changes and PR.** Changes
  has no review section. A dot on Review's glyph says a comment waits,
  files/panel.md having ruled out counts on the switch; the count is in the
  page's heading, on each file tab's title and on the file's row in Files and
  Changes (owner's choice, 2026-11-13).
- **Every part of Review is in the theme** (owner's choice, 2026-11-13): its
  buttons and the picker through `ThemedButtonStyle`, `.borderedProminent`
  drawing the system accent; the composer's text, caret, selection and prompt in
  the file tab's colours; the gutter's + knocked out of its mark in the file's
  ground.
- **A Review row's menu deletes or dismisses its comment**, as its card does, so
  a comment on a file that no longer opens can still be removed.
- **No hints in the composer or under the picker**, and Send's label carries no
  count (owner's choice, 2026-11-13): ⌘↩ submits a multi-line field anywhere,
  and the heading already counts what Send carries.
- **One review per worktree.** Comments from every file collect until Send, and
  one Send carries them all.
- **A file, then a mention.** Send writes the comments to a Markdown file in the
  drops directory and pastes a mention of it into the agent's prompt: Claude
  Code folds a long paste to a placeholder. Code in the file is indented, not
  fenced, so a quoted line holding a fence cannot end the block.
- **The mention lands where the cursor is and Return is the user's**, as a
  drop's does, so a half-typed prompt keeps its text. Clearing the line was
  rejected. A working agent can still be picked: the paste waits in its input
  and Return queues it, as typed text would.
- **The picker defaults to the agent pane focused last in the worktree**, then
  the first the board lists. With no agent there, Send is off; starting one from
  Review was left out (owner's choice, 2026-11-12).
- **Each worktree's comments are a file of their own**, under the reviews
  directory, not in `state.json` (owner's choice, 2026-11-12): a review is
  written over a while and a crash should not lose it, and a worktree's removal
  deletes one file. The file records the worktree's path, so a digest's
  collision would read as no comments rather than another's.
- **A worktree's file is read when the worktree is first listed**, at launch or
  by a later list read, so a worktree added again shows what was saved for its
  path rather than writing over it.
- **Taking a project off the sidebar keeps its worktrees' review files**, the
  worktrees staying on disk, so the project added again shows its comments.
- **A file that will not read or decode is moved aside and said at launch**, as
  the state file is, stamped so a second never replaces the first, and one
  comment this build cannot read costs that comment alone.
- **A sent comment is dropped at launch once a week old**, the drops sweep
  having removed the file it went in. Pending comments never age out.
- **Held by the text it quotes, not by row.** Each read of a tab looks for the
  quote at its lines, then nearest them; a match moves the comment, lines added
  above being the common case. Rows move with every change above, and Unified
  and Split number them differently.
- **A missed quote keeps the comment's lines**, so the next read searches near
  them: a read landing mid-save sees a cut file. A card on lines past the file's
  end sits under its last line.
- **A sent comment whose lines changed is Outdated** and can only be dismissed:
  it is what the agent read. A read that finds its quote again makes it Sent, a
  read landing mid-save having missed it. **A pending one is kept, marked Lines
  changed, and sent with its quote** (owner's choice, 2026-11-12), the file
  saying the lines have moved on. Dropping it, or holding it out of Send, lost a
  comment the user still meant. Once sent it stays Sent: its quote was already
  missing, so a missing quote says nothing of the agent.
- **Only a shown tab re-anchors.** A hidden tab holds no rows (file-tabs.md), so
  a comment on a file not shown keeps its lines until the file is shown. Cost:
  Review can list a stale line number for a file nobody has open. The All
  changes tab re-anchors each of its files whose rows a read moved.
- **A comment on removed lines shows only under the scope it was written in**,
  `HEAD` and the merge base holding different text. Review lists it either way,
  marked "(Branch)" or "(Modified)". Cost: switching scope hides those cards. A
  comment on the file on disk shows under both.
- **A range never mixes sides.** The row a drag starts on picks the side, up the
  gutter or down, so its numbers are one file's. Unchanged lines alone are the
  file on disk's, even from a split's left column, whose card then sits right.
- **The gap is in the row geometry**, which the forced layout, the tints, the
  gutter, find and the change steps all place rows through, so none of them
  learns about cards. Gaps are summed once and searched by halving, so a 1 MiB
  file stays as fast; with none the geometry gives what it gave before, which
  the drift tests hold, with a second run with gaps open.
- **A split opens each gap in both columns at the taller column's height**, so
  the offset lock still means the same row. The card sits in the column holding
  its lines. Cost: a comment inside a change sits between that change's removed
  and added rows.
- **Cards are hosted views over the text, not text.** Copy, find and the Changes
  rotor see rows only, and a selection dragged across a card copies the rows
  either side.
- **The row at the top stays put as a card opens or closes**, so adding a
  comment above the view moves nothing in it.
- **A composer opening below the clip scrolls just enough to show it**, and one
  in view scrolls nothing; a comment picked in Review comes to near the top.
- **Comment on Lines is in the text's own menu**, acting on the rows the
  selection touches or the caret's row: the gutter's + is reachable by neither
  the keyboard nor VoiceOver. No shortcut (owner's choice, 2026-11-12).
- **The composer's draft is the model's**, unobserved, so hiding the tab or
  switching layout keeps what was typed without redrawing the tab on every key.
- **Closing a file tab whose composer holds text asks first**, as a close over a
  working agent does: the draft goes with the tab. `tabs close` on the command
  line does not ask, a script having named the tab.
- **The composer quotes its lines when it opens.** A read landing while the user
  types would otherwise quote whatever moved onto those line numbers. An Edit
  whose comment was sent or removed meanwhile saves as a new comment, so the
  text typed is not lost.
- **A composer holding text stays** when another line's + or an Edit is clicked,
  unless the scope hides it, and closing it hands the keyboard back to the tab.
  It takes the keyboard once when opened, not each time a layout switch rebuilds
  its card.
- **The composer is plain text**, as a hook script's field is: SwiftUI's editor
  curls quotes and dashes, which would change code quoted to the agent. It
  follows its lines as a read moves them, and hides under the other scope as a
  comment on removed lines does.
- **An agent with no catalogue entry, one from a custom command, gets a sentence
  around the path** rather than a mention it might not read.
- **Send goes to the pane the picker showed, or nowhere.** Working the recipient
  out again at the click would send to another agent, unannounced, when the
  picked pane closed in between.
- **`review send` on the command line leaves the shown tab and the keyboard
  alone**, as `panes paste` does: a script runs while the user types elsewhere.
  Review's Send takes both, so Return is one key away.
- **`review add` on the command line needs the file's tab shown**, the quote
  coming from its rows as a comment written in the tab does. A hidden tab holds
  none, so it is refused rather than quoting nothing. Where no file tab shows
  the path, the shown All changes tab quotes it.
- **The handoff is its own type, `AgentHandoff`**, writing entries and wording
  the mention, so #34 can send a pull request's failing checks the same way.
- **Cards show in the All changes tab too** (files/all-changes-tab.md), placed
  per file against that file's rows. The composer carries its file's path, the
  All changes tab holding several, and the tables a composer and its draft live
  in are keyed by the tab hosting cards, a file or All changes tab.

## Reviewed and left as is

- **The nearest match wins, however far.** A short quote such as `}` can match
  unrelated code. A distance limit would drop the comment when a long block is
  added above it, the case anchoring is for.
- **An agent waiting on a question can be picked**, as a working one can. What
  its menu does with the paste is unchecked.
- **Between a scope switch and the re-read**, cards are placed, and comments
  written, by the new scope over rows read under the old. The switch re-reads at
  once.
- **Any comment change redraws every shown file tab**, all reading one table.
  Comments change on an action or a read that moved one, never per keystroke.
- **A live resize re-measures each card** at every new width. Unmeasured; a file
  holds few cards.
- **A paste that fails says nothing.** It happens only when the pane closes
  between the picker drawing and the click, and the comments stay pending.
- **Placing cards walks the tab's rows on each update**, but only for a file
  with comments; any other tab returns before the walk.
- **Launch tries each worktree's review file**, one failed open where none
  exists, rather than listing the directory first.
- **The composer's label and a comment's line label each switch on side and
  count.** The words differ, and a helper taking four keys is longer than both.
- **`review send` reports a failed handoff write as the pane not being live.**
  The app's alert names the write, and the pane check is what fails otherwise.
- **A tab hidden while its top cuts a card shows the row after the card** when
  shown again: the saved scroll is a row. Counting a point in a gap as its own
  row would move find, the change steps and the drift tests with it.
- **Pruning file tabs assigns the reveal requests unguarded.** Observation skips
  a value equal to the last, which a test of it showed, so no tab redraws.
- **`multishell`'s command dispatch is one switch with its complexity rule
  off.** A table would lose the compiler's check that every command is handled.
- **`review add` and the composer each build their comment**, refusing in their
  own words: the command line says which check failed.
- **A worktree removed outside the app keeps its review file only until the next
  git read**: the file is known from launch, so forgetting the worktree deletes
  it.
- **The composer's re-anchoring builds its own copy of the side's text.** It
  runs only while a composer is open, and an unchanged reading re-anchors
  nothing.
- **The composer card checks for text itself** with the shared
  `trimmedOfAllWhitespaceOrNil`, the rule the model's commit uses. A model
  method for it was added and removed by earlier reviews.
- **The hand-built text view fills its box**, which a test of a click below the
  first line holds, though `scrollableTextView` is no longer used.
- **Review and the handoff order a file's comments by line number, either
  side's.** A removed line's number is the committed file's, so it can sort away
  from where it sits in the diff; placing it needs the tab's rows, which a
  hidden tab does not hold.
- **One flag stops repeat alerts for every worktree's review file.** They share
  a directory, so a failure that hits one and not the others has not been found.
- **The picker still says "at its prompt" for an idle or finished agent.** That
  is its state; only the claim that a recipient must be at its prompt went.
- **A card's pointer over the text view is unchecked**: the text view's I-beam
  may show over a card's buttons, the hosted card adding no cursor rect. Left to
  manual testing.
- **Under Branch the handoff says removed lines are the base branch's** even
  where the tab fell back to `HEAD`: a submodule's file, a file the branch added
  and deleted, a branch with no history in common. The reading does not record
  which it compared against.
- **A copy about to yield moves a broken review file aside before it learns it
  must**, launch reading the files first. The running copy writes the file again
  on its next change.
- **A review file that will not read and cannot be moved aside is not guarded
  against a save.** An atomic save renames into the same folder a move would
  need, so a file that could not be moved cannot be written over either.
- **Comment on Lines takes the side from the selection's top row**, not the row
  it started on as the gutter's drag does: a text view's selection does not say
  which end it was dragged from.
- **A comment's text goes to the agent as typed**, its own Markdown: a heading
  or a `---` in it is the user's. Escaping it changed code the text quoted.
- **A split's first card pass can end the following column's wait for the lock**
  before the other column restores. Traced twice; its report maps back to the
  scroll handed over.
- **A worktree git stops listing and lists again at once can lose its
  comments**: the forget's delete, still in flight, lands after the new read. A
  list read takes a second or more, the delete milliseconds.
- **Every count of comments to send redraws on any comment change**, tab faces
  and the Files and Changes lists all reading one table. Comments change on an
  action or a read that moved one, never per keystroke.
- **The count badge takes `theme.commentMark`, the chips the attention colour
  through a palette**: both are the theme's waiting colour. Round 9 had the
  badge leave the palette route, which ignores the palette for that state.
- **VoiceOver may read the empty composer's prompt after its label**, the prompt
  being the same words. Hiding it in the shared editor took the only words the
  Settings window's script fields have.
- **A link's row in Files carries no count**: its comments are its target's, as
  its tab is, and the target's row counts them. Matching the link would mean
  reading each listed link.
- **Send writes its one file on the main actor.** It is a few kilobytes on a
  click, where the state file's save runs on every change.
- **A composer whose first focus fails keeps asking for the keyboard**, so a
  later layout switch takes it. No case was found where the card has no window
  on the turn it asks.
- **`review add` resolves a link on the main actor**: one stat per command, as
  `tabs open-file` would cost the click it stands for.
- **A `review add` the command line gave up on may still add its comment**, so a
  retry adds it twice. It waits on one read of one file, which would have to run
  past the 30 s ask timeout.
- **Review's state is eleven dictionaries on `AppModel`, cleared by hand** in
  the worktree forget, the project release and the file-tab prune. One value per
  worktree would redraw every file tab reading comments on each pane focus,
  which writes the focus history, and would observe the drafts kept unobserved.
- **The handoff's mention is absolute, a drop's relative**, the drops directory
  being outside every worktree. Both take the agent's prefix from
  `fileMentionPrefix(ofAgent:)` and the wording from `FilePathText`.
- **`askOnceRead`'s `return 1` is not reached**: the poll looks at least once,
  so a wait that runs out has a refusal to throw.
