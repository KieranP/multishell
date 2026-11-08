# The board, pane rows and agent marks

The board that shows the agents, the sidebar's pane rows and the mark each agent
is drawn as. Newest at the bottom.

- **The Agents board is a roster, not a queue.** Every open pane has a card,
  moving between columns as its state moves, so nothing is hidden by having been
  looked at.
- **A card goes when its pane closes**, and in one other case: an agent whose
  process has gone leaves a plain shell behind, which the filter hides.
- **Failed waits with Waiting, not in Done**: a failure wants the user, which is
  what that column means, and Done keeps one meaning.
- **They part on a dead process**: a question was a claim about that process and
  goes with it; a failure outlives the thing that failed and stays.
- **The filter is the one control and decides membership alone.** A shell it
  lets in lands where its state says, the injected integration already reporting
  a command started and finished, so a build is Working and a failed test suite
  waits.
- **No duration floor, though the banner policy has one**: a banner interrupts,
  a card does not, and the sidebar dot already goes green for a trivial command.
- **The filter lives on the model, not the view**, because the Dock badge counts
  what the Waiting column shows and must read the same flag.
- **The filter is saved in the workspace**, as the Files panel's page is, so
  someone who watches their shells on the board no longer turns it on at every
  launch. Cost: a toggle schedules a save.
- **While the board is up, nothing acting on "the tab in front" acts**: closing
  would end a shell nobody can see, opening would make a tab that appears only
  once the board is left. One predicate answers for all of them.
- **Showing the board also means no pane is shown**, or the selected worktree's
  Done states would clear as it opens and their cards reach Idle without passing
  through Done.
- **An agent's pid is polled only while the board is up**, one sweep as it
  opens: nowhere else shows a quit agent, and always watching would leave a
  timer running for as long as any agent had ever reported.
- **The shell's word that its foreground command returned drops the agent at
  that prompt too**, the agent having been that command, since the Dock badge is
  read with the board closed where no pid is polled.
- **Four columns are always drawn, empty or not.** Labelled columns say what the
  board is for, where a page in their place says only that it is not working.
- **An empty board adds one line saying what would put something on it**, since
  without a report nothing can know an agent is at a prompt. Not gated on hooks
  being installed: one agent's being in place says nothing about the agent at
  the prompt.
- **The board is built once and held until anything the build read changes**: it
  reads every pane's title, state, note and workers and every worktree's status,
  so a title change in one pane rebuilt every card on every render. The build
  runs under observation tracking rather than a hand-kept list of inputs, which
  would drift from the sidebar the first time someone added one. Cost: any store
  write drops it, a focus change included.
- **Newest first everywhere**, so an arriving card pushes the rest down a place
  and nothing else about a card moves on its own.
- **Columns share the room down to a floor and the board scrolls past it**, a
  partial column at the edge saying there is more.
- **No end arrows**, which the tab strip needs because a tab scrolled out of
  sight is one you forget exists; the board has four fixed columns.
- **No line of output on a card**: the core can read a pane's text since
  `panes read`, but each read takes the engine's renderer lock on the main
  thread, a cost paid per card every time a line would refresh.
- **The selected worktree lists its panes in the sidebar**, one row per pane,
  not per tab, so a glance says which pane is working and which has a swarm
  without reading the strip.
- **A tab was the row first**, and a split's second pane, with its own agent and
  dot, was nowhere.
- **A split's panes carry a split glyph and their position**, since a renamed
  tab names every pane alike and two plain shells both read as the shell.
- **The worktree row keeps its terminal count while its panes are listed**,
  though the rows under it say it again (REVERSAL, mockups 2026-11-05). Dropped,
  the selected row's pull request and CI glyphs sat a capsule further right than
  every other row's. The capsule is at least two digits wide for the same
  reason. A row with no terminals keeps no room for it (user, 2026-11-05): the
  empty slot left that row's other badges stranded off the edge. Cost: on such a
  row the services glyphs sit a capsule further right than on rows with
  terminals.
- **The active tab's focused pane is bold, one per worktree**: with two groups
  two tabs are on screen, and two bold rows read as two selections.
- **Only the selected worktree's**, so one set takes room at a time and a
  project with many panes does not become that many rows. Cost: selecting a
  worktree shifts every row under it.
- **Each pane row's height is what the sidebar's block height counts off**, or
  the drop indicator lands in the wrong half.
- **An agent is drawn as its own mark** wherever a pane says what it is running:
  the five the app draws, two letters for everything else, the terminal glyph
  for a shell.
- **A mark is recognised without reading**, which is all a slot at the smallest
  UI font can carry; letters at that size are pairs a glance has to tell apart
  on shape alone.
- **A stock symbol per agent is a mapping nobody can learn**: nothing about a
  generic glyph says which agent it is.
- **One `.svg` per mark, not hundreds of lines of path calls**, each a single
  path in the square the test holds them to: the art is data, a mark can be
  replaced without touching Swift, and a diff of a new mark is one line.
- **Only absolute move, line, curve and close commands are read**, which is all
  those files hold; anything else is refused rather than drawn half.
- **A file that will not parse is left out of the table**, so the mark draws
  nothing; the test walks every file, turning that into a failing test rather
  than an empty tab.
- **All five are traced from the projects' own icon sets and icons**, the shape
  being what is recognised.
- **One outline is sampled from the icon itself**, radii from its centroid
  through a smooth curve: regular lobes were tried by hand, and neither is that
  irregular shape.
- **Two marks run to the edges of their square** rather than sitting inset,
  those icons being the mark itself with no padding of their own.
- **One prompt is cut out of its blob rather than drawn over it**, so one fill
  colour carries both; the cut is made when the file is generated.
- **Two are alike at tab size and told apart by their tint**, which is the
  projects' doing and not something to fix by drawing either one wrong.
- **A mark black or white upstream is drawn in the text around it**; the rest
  carry the project's own colour as the built-in themes' `ui.agent_marks`, which
  a user theme may change or empty.
- **Cost: a mark redrawn upstream is wrong here until someone notices**, a trace
  is only as good as its source, and the programs that traced these are not in
  the tree. The `.svg` is the artefact and the thing to edit.
- **A mark is drawn, so it is said**: a tab and a pane row name their agent
  after their title, and drop it where the title is the agent's name.
- **The fallback is letters rather than nothing**, one from each of the first
  two words, so a command the user typed and an id a newer build stored both
  draw something.
- **A typed agent is known from the command, not only from its hooks.** A pane's
  mark comes from the hook report that names it, then the command the shell said
  it was starting, then the tab's own id.
- **The middle one is why typing an agent's name in a plain shell marks the
  pane** with no hooks installed: the injected integration carries the program's
  name, first word and no path, matched against each agent's executable.
- **That answer is held only while the command runs.** Any report from the shell
  itself that names no command takes it back: the prompt coming back, the shell
  exiting, or the next command.
- **Keyed on the report having no agent, not on its state**: an agent's own
  hooks report running all through a turn and name themselves, and clearing on
  those would drop the shell's answer the moment it started working.
- **Which reports are the shell's is a field it sets**, not a guess: the helper
  is documented for the user's own scripts, and one run inside a turn reports
  with no agent and no command; read as the shell's, it would blank the mark.
- **Matched on the executable alone**, so a wrapper invocation is nobody: the
  word is the command. A leading assignment, `command`, `env` or `exec` is
  stepped over first.
- **Only a word naming an agent's executable goes on the shell's own line**, the
  shell matching it against the list it was generated with, so no word needs a
  JSON escape. Cost: a script of the user's named after an agent marks its pane
  as that agent.
- **The state dot badges the mark instead of taking the slot.** A tab has one
  leading slot, which used to hold either the dot or the tab's kind.
- **The dot sits on the mark's lower-right corner, ringed in what is behind
  it**, so a row says what is running and how it is doing at once, covering the
  mark's edge rather than the middle that carries the shape.
- **Covering part of the mark is the right trade**: a state is read down a whole
  strip, a mark only where the eye already is, and an idle pane draws the mark
  whole.
- **The sizes were set by rendering the shapes from tab size up and looking**,
  which threw out a hand-drawn mark that read as an animal at tab size.
- **A mark that only works blown up is no mark**, and the box cannot grow: the
  tab floor holds only what a tab already draws at the smallest UI font and a
  short title.
- **The tab's dot keeps its click**, which clears a stale Working state, and the
  whole glyph is now that target, reaching as far as the scaled badge does.
- **A split tab loses its split symbol where an agent is at the prompt**: one
  slot draws one thing, and which agent is working matters more from across a
  strip than which tabs hold two panes. The row still says split to a screen
  reader.
- **A pane row says its state on its right edge, with how long**, as a board
  card's rail does, and its mark carries no corner dot. The corner dot was small
  beside the mark and said nothing of time. An idle pane leaves the edge empty,
  most shells resting there. The tab strip keeps the corner dot; a card draws
  Failed's before its mark. Cost: the selected worktree's pane rows keep a
  ten-second clock of their own, board open or not; a row drawing no time sits
  each tick out, and a time under a minute lags by up to the tick, as a card's
  does.
- **A pane row's title is caption-sized**, 11 pt at the default 13, where at
  badge size it was the smallest text in the sidebar. The row keeps its height,
  so nothing below moves (mockups, 2026-11-05).
- **A board card draws a dot only where its column does not say the state**,
  which leaves Failed, waiting in the Waiting column (2026-11-08). A dot
  repeating its column's name was noise on every card. Failed's sits before the
  mark rather than on its corner, so it covers nothing and needs no room
  reserved past the mark as it scales.

## Reviewed and left as is

- **The pane rows' clock runs while every pane is idle** (round 1, 2026-11-04):
  one body run every ten seconds, each idle row comparing equal and skipping its
  redraw. Gating the task on a rail would restart it as panes change state.
- **A card passes `PaneGlyph` a ring fill it never draws** (round 3 of the dot
  scale review, 2026-11-08): the card's mark has no badge now, and a second
  initialiser for one caller would be more than the unused argument costs.
