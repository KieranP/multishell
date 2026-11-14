# Sidebar

Projects, naming, ordering, the filter, a worktree's dot, hidden rows and
cramped names. Newest at the bottom, above "Reviewed and left as is".

- **A worktree's name is the user's, kept beside the worktrees.** Every refresh
  replaces a project's whole list, so a name written onto the worktree would be
  gone next tick. It is cleared wherever the store forgets a worktree.
- **The branch is never replaced, only demoted**: every git command in that
  directory acts on it, so a row that hid it would lie. The removal dialog names
  the worktree as its row does, and the branch in its body, where what cannot be
  undone belongs.
- **The trunk row holds the top whatever the sort says.** Rows sort in tiers
  first: git's main worktree, a linked worktree on the trunk, the active ones if
  asked for, then the rest. The trunk gets a tier of its own because a bare
  clone's trunk is a linked worktree, and it is what every other row is read
  against.
- **The trunk is the default branch the badges use**, falling back to the usual
  names until the first scan resolves one. Cost: a project on another trunk can
  settle its rows once, seconds after launch.
- **git records no creation date**, so it is the directory's birth time, read
  where the list is made so the parser stays testable on fixture text.
- **Persisted, and kept over a stat that cannot answer**, or a volume that
  blinked would cost a save, a re-render and a row's place.
- **Last commit is runtime state instead**, so a commit does not rewrite the
  workspace. The orders are named for the commit, which is what they measure.
- **It rides the ref scan the badges already run.** git fails a whole query on
  an unknown format atom, so the scan asks again without it, or an old git would
  cost every badge.
- **A worktree with no date sorts last in both directions**: "oldest first" is
  not a claim that an undated worktree is the oldest. Name breaks ties and is
  the default, being the only order that reads the same everywhere.
- **Active-at-the-top is off by default**: a worktree is active while it has a
  terminal or a reported state, so rows would move as agents report in.
- **Both order settings are shippable by a repo and run nothing**, and the
  override form seeds from what is in force, not the user's global.
- **The two globals are a menu behind a sort glyph beside the sidebar's Projects
  caption**, not a settings row: an order is changed while looking at the rows
  it moves, and the settings window was three clicks away.
- **A project's override stays in its settings**, the only place with room for
  the (i) text. Cost: the help saying the main and trunk rows hold the top is
  only there.
- **The glyph is badge-sized and dimmer than the caption**, lit as a button only
  under the pointer (appearance/window-chrome.md; it was a mark that only
  brightened until 2026-11-05). It uses the strip's plain menu style, since the
  borderless AppKit one draws the image at its own size and tint whatever the
  label asks (tabs-and-groups/tab-strip.md).
- **A missing directory is refused, not worked around.** A shell spawned in one
  silently lands in the home directory.
- **That check waits a second at most**, the stat running off the main actor: a
  click on a dead mount froze the window until the mount timed out. A stat still
  stuck is not joined by another, and the click is refused as not answering.
  Cost: a volume that takes longer to wake is refused once.
- **A project whose directory is gone stays dimmed rather than dropped**, an
  unmounted drive not being reason to delete someone's setup. Its tooltip says
  why; a project that is there but git fails on is reported once.
- **Both ends of a refresh check the project is still listed** before dimming
  it: one removed while its git call was failing was dimmed under a stale id and
  alerted about after it had left.
- **A bare repository is a project.** The work-tree question answers false for
  one, so the git-dir question is what is asked.
- **A repo hidden inside a folder takes that folder's name.** Cost: the default
  sibling worktree directory then lands inside it.
- **A project is the main worktree whatever was picked**, a linked one listing
  the same worktrees, so two rows would select together and share tabs. Cost:
  the sidebar shows the repo's name, not the folder picked.
- **One actions menu serves the detail header, the sidebar and a board card**,
  the last under a heading naming the worktree, since the card carries a Clear
  Status of its own and two unlabelled ones would read alike.
- **The sidebar filter is tucked behind a glass in the header.** Standing open
  it cost a row of height in every session to a control reached in few of them.
- **Names are folded per keystroke, not kept folded**: a folded copy searched
  with `contains` parts from a folded `range(of:)` on some letters, ß for one,
  and the whole filter measured 0.05 ms at 40 rows.
- **Closing it clears the text**, so rows are never missing with nothing on
  screen saying why, and Escape closes rather than empties.
- **Closing hands the keyboard to the active pane**, or first responder drops to
  the window and typing reaches nothing. Cost: the filter is a click further
  away, with no keyboard route to it.
- **While the filter has text it holds every project it shows open**, and the
  chevron says so. A click collapses the project for that text alone, as Xcode's
  navigator does, and leaves the stored flag for after the filter. Reading the
  flag, the chevron pointed right over open rows and its click moved nothing.
- **A collapse lasts until the text changes**, being about the rows that text
  found. Rows a text change brings back out of a collapse are read, as those it
  brings back out of hiding are.
- **Whether the field is up is the model's, as its text is**, and only closing
  takes it down. Held by the view, a reopened window showed the field for the
  text left in the model, and emptying that text removed the field with the
  keyboard in it.
- **A worktree's dot is the most urgent state among its tabs**, a project's
  among its worktrees: failed, waiting, working, done, idle.
- **Failed above waiting**, where it was below: a question answered still leaves
  the failure. Done needs one finished tab, not all of them. Idle only when
  every tab is.
- **A hidden worktree moves to a Hidden row under its project's others**,
  collapsed until clicked, rather than leaving the sidebar behind a global
  toggle. The rows stay one click from where they were, and the row's count says
  what is there.
- **The main worktree cannot be hidden**, so every project keeps a row and the
  trunk every other row is read against stays in sight. A hand-edited file
  marking it is ignored.
- **Which rows are hidden is saved; whether a section is expanded is not.** Kept
  beside the custom names, for the reason those are, and dropped with the
  worktree. Each launch starts with hidden rows out of sight.
- **A collapsed section's rows are not polled**, as a collapsed project's are
  not. Expanding it, or showing a worktree again, reads those rows at once.
  Hidden and shown rows are sorted as one list and split, so the sort cache
  keeps one entry per project.
- **The filter narrows the Hidden section and leaves it collapsed**; its count
  says what the text found inside. Holding it expanded would mean a second
  collapse-while-filtering, and a match in a hidden row alone still lists the
  project. Rename expands the section, the field being on the row.
- **A cramped name gives up the part before its last `/` first**, drawn fainter,
  then `…/` and the leaf, then the leaf's middle. Middle truncation of the whole
  name made `feat/dashboard` `feat…oard`, keeping the prefix half the branches
  share and cutting what told them apart. The leaf keeps both its ends, so
  `fix-login-v2` and `-v3` still differ. The tooltip names it whole.
- **A crowded row keeps three characters of its name and drops badges whole**:
  the terminal count, then the PR and CI glyphs, then the git counts, a running
  or failed glyph always staying; a pane row drops its workers, then its time.
  At the 18 pt UI size and the narrowest sidebar the badges kept their widths
  and the branch drew nothing.

## Reviewed and left as is

Raised by reviews and settled; a review need not raise these again.

- **A renamed row's branch tooltip sits inside its name's** (round 2,
  2026-11-05): the outer one covers the custom name, the inner one the branch
  line, so neither repeats the other's area.
- **`select` taking a `turning` closure rather than a typed pane or tab.** A
  menu's New Shell Tab and New Agent Tab open a tab there, which is neither. The
  closure runs before the focus because the focus marks seen the pane it lands
  in, which would otherwise be the tab the user passed over.
- **A control request's `bringIntoView` turning and reconciling itself for a
  worktree in view.** A select there would ask the shared-hooks question and
  note the worktree as recent for a request, not a click.
- **`reveal(pane:)` selecting a worktree already in view where `bringIntoView`
  does not.** A notification click or a board card is the user's own turn to
  that worktree, so it is noted as recent as a row click would be.
- **`reveal`, `bringIntoView` and the switcher's `goTo` as three wrappers over
  `select`.** Each answers a refusal its own way: nothing, a control refusal, or
  a beep with the keyboard handed back.
- **`show(pane:)` beside `reveal(pane:)`.** Show stays inside the selected
  worktree; reveal selects the pane's worktree first, with all a select does.
- **The Editor's Open in Tab and a tab moved to a worktree changing the store
  before `select`.** Each probes the directory just before, so a refusal needs
  the folder to vanish between two calls on the main actor.

### Asked both ways

Reviews have asked for each of these and for its opposite. The side below is the
one kept; a review that would argue the other side need not raise it.

- **A typed pane-or-tab target for `select`, or a closure.** Round 3 asked for
  one entry point that turns before the reconcile; round 4 for a typed target
  instead. The closure stays, as above, since a menu's new tab is neither.
- **`newAgentTab(selecting:)` with one `select`, or one per branch.** Round 6
  asked to branch once on the agent, round 7 to call `select` once. It calls
  `select` once and notes a missing agent in the closure.
- **The menu openers' readiness check: the full rule, or no second probe.**
  Round 4 asked not to probe the directory again after `select`; round 7 to
  reuse `requireShellReady`. They call `isShellReadyBesidesDirectory`, the rule
  without the probe, which `requireShellReady` is built from.
- **Which alert wins the one slot: No agent chosen, or a launch failure.** Round
  5 asked for the no-agent alert to be set last, round 7 for the failure not to
  be lost. The no-agent alert shows, as it answers the user's click, and the
  reconcile logs every launch failure, the one it shows included.
- **One helper for revealing a pane, or each caller its own.** Rounds 5 and 6
  asked to share it; each sharing then drew the next wrapper finding. Board and
  notifications share `reveal(pane:)`; the switcher and control requests keep
  their own refusal handling, as above.
- **The folder-gone tests passing on the code before the fix.** They guard the
  order `select` runs the closure in, not a bug that was there; they stay.
