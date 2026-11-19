# Find bar

Searching a pane's scrollback. Newest at the bottom.

- **Find is the engine's search under a bar of ours.** The engine's own bar is a
  GUI the embedding never shows.
- **A bar is a pane's own**, with its own find text, so one left up in another
  worktree is still up when the user comes back. The first cut had one bar in
  the window that followed the keystroke, and Find Next in a second worktree
  pulled a search out from under the first.
- **The find text is kept per pane across closes**, as the Mac's find field is.
- **Every find keystroke acts on the bar whose field has the keyboard**, else on
  the focused pane. Clicking into a field moves the store's focus nowhere, so
  without the field's case a step typed in one pane's field stepped the other
  pane's search in a split.
- **Closing a bar hands the keyboard to the bar's own pane**, not the focused
  one, as the sidebar filter hands it back. `panes find --close` moves no
  keyboard, except where a tab request on the worktree in view would
  (architecture.md).
- **The field takes the keyboard on the open keystroke alone**; a bar a worktree
  switch brings back claims nothing.
- **Next walks towards the prompt and Previous away**, as a stock terminal does.
  The engine's own next walks the other way, so the host crosses them.
- **Typing highlights and selects nothing**, and the first step after a new find
  text lands on the match nearest the prompt, the one nearest what is on screen.
- **The model keeps which panes have a selected match**, the engine reporting
  nothing back. Cost: typing alone scrolls nowhere, and the first Next after the
  nearest match wraps to the top of the scrollback.
- **Escape is released from the engine's bindings** along with the four that
  meet find: the engine binds it to end the search as a performable key, so
  while a search ran it ate Escape in the pane. Of the four, one opened a bar
  this embedding never shows and another ended a search under a bar of ours that
  stayed up.
- **Cmd+F over a selection in the pane finds its text.** A Cmd+F from the field
  keeps what was typed there.
- **A selection is taken once.** It stays drawn after the bar opens, so a Cmd+F
  after typing over it, or after closing the bar, took it back and lost the
  typed text. Cost: the same text selected again with no Cmd+F between is not
  taken.
- **Only a selection on one line with something in it is taken**: the engine
  matches within a line, and Cmd+A then Cmd+F put the whole scrollback in the
  field. Its trailing spaces are dropped, libghostty reading a selection with
  them kept.
- **The engine's search-for-selection is left bound and does nothing here**, its
  whole effect being an action the app does not answer. Cmd+F covers it.
- **The engine's match counts arrive a turn after the search**, as actions of
  their own. The engine posts only a changed selection, so a step over the only
  match keeps its selected index; dropping it there left `panes find --next`
  waiting out its two seconds. A find text differing only in ASCII case keeps
  both, the engine sending none for it.
- **`panes find` prints a count once it holds for three looks**: the engine
  posts a 0 as a search changes, then a running total as it reads the
  scrollback. Cost: the total is the engine's, and after 200,000 lines it
  counted more matches than the scrollback it still held, read back whole. It
  keeps matches in pages it has pruned until a later feed sweeps them, which the
  host cannot ask for.
- **The same find text set again is nothing to the model.** The field commits on
  Return as well as on each keystroke, and a repeat taken as a change would send
  the find text again and start the selection over.
- **A navigate sent with the find text selects nothing**: both go through one
  mailbox, which drains before the thread has matched anything, so the first
  step is the model's to send and to remember.
- **Find text differing only in ASCII case is unchanged to the engine**, so the
  selection stands and the step after it moves on by one.
- **An empty find text ends the engine's search outright**, so the bar's close
  sends the end action, which also tells the engine's own bar.
- **The bar numbers matches down the scrollback, as Chrome does down a page.**
  The engine numbers them from the prompt up.
- **The bar shows the match a step left until the engine names the next**, a
  turn later, or its count blinked to `-/34` on every Return.
- **Counts wait for the end the engine posts for each replaced search**, or the
  bar said `0/0` on every keystroke, and a count still in flight for a find text
  typed past showed as the new one's. A search is replaced only where the engine
  held one. Cost: a find text typed past with no matches ends the wait one 0
  early.
- **The end is a 0, or no total where the find text was emptied**: that stops
  the engine's search thread rather than changing its text, and the thread posts
  no total as it quits. Waiting for a 0 there dropped every later count.
- **A selected match past the total shows as none selected.** A switch to the
  alternate screen posts that screen's total but no cleared match, and the bar
  read `-17/3`. Cost: a stale match inside the new total still shows until the
  next step.

## Reviewed and left as is

- **Closing the first pane of a split may hand its open find bar's focus to the
  pane that moves into its place** (2026-11-12): split children are keyed by
  position, which `SurfaceFrame` relies on. Unproven on screen.
