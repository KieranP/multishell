# Quick switcher

One box over the window that goes to any agent, worktree, tab, project, file or
menu command. Newest at the bottom.

- **Cmd+P opens it on All, Shift+Cmd+P on Commands.** Cmd+K is what every Mac
  terminal clears the screen with, Ghostty included, and the people here come
  from those terminals; Cmd+P and Shift+Cmd+P are the editors' Go To and command
  palette. Ghostty's own palette sits on Shift+Cmd+P and an embedding never
  shows it, so the surface gives the key up, as it does Cmd+F.
- **One box with scopes, not two boxes.** The keys pick the scope it opens on;
  Tab and Shift+Tab step through All, Agents, Worktrees, Tabs, Files and
  Commands. A `>` typed into the empty field in All turns it to Commands, as an
  editor's palette takes it; one carried into All by Tab stays text. The key of
  the scope in view closes it, Cmd+P on All and Shift+Cmd+P on Commands; on any
  other scope either key goes to its own.
- **Empty, All lists who is waiting, longest first, then the worktrees turned to
  lately**, the one in view left out. A failed agent waits with them, as in the
  board's Waiting column. Return on an open box therefore answers the agent that
  has waited longest. With neither, it lists every worktree, so a first launch
  never opens on nothing.
- **Typed, All lists places, then the selected worktree's files, then
  commands**, eight, five and four at most. A waiting agent, and only the agent,
  is lifted by a fixed amount. It rises over a slightly better match, never over
  a row the text names far better; the worktree holding it is not lifted.
- **Text is folded before it is matched**, by case and accent, a letter that
  folds to two, ß, matching both and bolding itself.
- **A place reads as its path from its project down**: `billing › main` for a
  worktree, `billing › fix-port (Port fix)` for one with a name of its own,
  `billing › main › Claude Code` for an agent with its pane's title after, and
  `billing › main › api` for a tab. The user's own words, asked for over a title
  with its place beside it.
- **A place matches by letters in order through its path**, a run of letters
  keeping the bonus of where it starts, as fzf scores, and the best of the
  alignments from each place the first letter is. Scoring each letter alone put
  `pricing-order-test` above `fix-port-block` for `port`; the first alignment
  alone matched `main` scattered through the project's name. A word may instead
  match the start of a word after the path, so `api` finds an agent by its
  pane's title; scattered letters there matched nearly everything.
- **The pointer moving over a row selects it**, so one row is ever lit; it
  neither scrolls nor is announced, and rows moving under a still pointer as the
  text changes leave the selection. Only the selected row has a background.
- **It sits below the tab strip**, the header's height and a tab's under the
  window's top, so it covers neither the window's title nor its tabs.
- **A file matches by every word inside its path**, the Files panel's byte
  search, not the letters in order. A repository of 200,000 paths is searched on
  every key, and the ordered match is too slow for that. Ignored files, files a
  sparse checkout left out, submodules and an opened submodule's files are not
  listed, and its name is bold where a word was found in it.
- **Only the best hundred paths are kept as the listing is walked**, for Files
  and All alike, All showing five, so Tab between them reuses the search, never
  all the matches sorted, since one letter names nearly every path. The last
  search is reused until the text or the listing moves, an agent's report
  redrawing the box, and dropped as it closes, since it holds the listing.
- **Files come from the panel's own listing**, read once the Files scope or text
  in All lists them, never for Commands or an empty box, as a large repository's
  read is not worth paying for nothing. Closing drops them unless the panel is
  shown, as the panel keeps only its own worktree's. Nothing re-reads them on a
  checkout while it is up, the panel's watch reading only for a shown panel.
  Until they land, typed text that finds nothing says the files are still being
  read.
- **Commands are the menu bar's enabled items, walked once as it opens.** A walk
  validates every item of every menu, and the list never drifts from the menus.
  Choosing one is the user's own click, not the command line's, so Paste saves
  an image and words files as a Cmd+V does. It runs on a timer, which fires only
  once the run loop has waited and SwiftUI has taken the field down; until then
  the field has the keyboard, and Copy would copy it. A queued block ran before
  that redraw.
- **Commands are the app's own, and only those that can act now.** What macOS
  puts in the menu bar is left out: the Services, Window and Help menus it
  fills, matched by title too since SwiftUI's rebuilt bar can hold a copy of the
  menu registered, any submenu of the app menu, and the items it adds to the
  others, Hide and Show All, AutoFill, Dictation, Emoji & Symbols and Enter Full
  Screen, known by their actions since their titles are the user's language. So
  are the app's own editing, Undo to Select All, Find, the theme picker's
  choices and the switcher's own two items, known by their titles, as SwiftUI's
  buttons all share one action. A command that cannot act, New Tab with no
  worktree in view or over the Agents board, Split with no tab, Close with
  nothing to close, is left out by asking the model per title
  (`AppModel+MenuCommandAvailability`). The menu items stay enabled: a disabled
  one gives its key to the pane, and Ctrl+Tab with one tab typed a Tab into the
  shell. The app menu's items read as the application's. `ui menu` still lists
  everything, as the command line drives the whole bar.
- **The field is AppKit's.** SwiftUI's never shows a binding changed while it is
  edited, and the `>` rewrites the text; the arrows, Tab, Return and Escape go
  to the list through the field's own commands. Undo is off in it, because an
  undo changes the text without telling the delegate.
- **Its prompt is drawn over the field and hidden while an input method is
  composing**, the model's text being empty until the composition is confirmed.
  AppKit's own placeholder would hide itself, but setting it as the scope
  changes ends the field's editing, which closes the switcher.
- **Taking the keyboard selects the field's text, in the system's colour**, so
  the caret is put at the end: MonochromeThemeTests found the selection.
- **It wears the find bar's look**, a panel lifted under a hairline with the
  field in a well, under a `ui.quick_switcher` section of its own. The built-in
  themes take its colours from their find bar, and its fainter text and
  selection from their sidebar. Cost: a user's theme written before the section
  draws the switcher in its base theme's colours, as every new key falls back.
- **A place chosen opens its project in the sidebar**, a worktree, a tab or a
  file in a collapsed one, so the row it went to shows; while the sidebar's
  filter has text, the filter opens it instead, as Rename does, and a filter
  whose text hides the row is cleared.
- **Recent is runtime state**, the worktrees selected this run, dropped with a
  worktree git no longer lists. A project chosen opens the worktree of it turned
  to last, else its main one.
- **It closes when its field loses the keyboard to anything**, a find bar's
  field or a pane, and leaves the keyboard where it went. A sheet takes the
  window, not the field, which has the keyboard back when the sheet goes. A
  reconcile taking focus closes it too, the model's own guarantee without a
  window. Left up, it stayed drawn while keys went to whatever had taken them.
- **`multishell info` lists it and `ui dismiss` closes it**, as for a sheet.

- **A read of the files is asked once an opening.** One that failed, a broken
  index or a folder git refuses, would otherwise run again on every key.
- **Shutting the Files panel while the switcher is up keeps the listing** until
  the switcher closes, as it is still searching it.
- **Two menu items whose titles differ only by a "…" are one command**, as
  AppKit's lookup matches them; only the first can ever be chosen.

- **Backspace in an empty field goes back to All**, with Option or Command too,
  which undoes a `>` typed by mistake as an editor's palette does, though the
  `>` itself is gone.
- **A tie goes to the shorter path, then the row's kind**, an agent before a
  worktree before a project before a tab. The shorter path is the more general
  place, so a project's own name lists the project above everything under it;
  the kind added to the score outweighed a better match.
- **Each agent state lists newest first, as the board's columns do**, bar
  Waiting and Failed, longest first; one comparison of the time entered serves
  both.
- **One rule says which listings are kept**: a shown panel's worktree's, and the
  selected worktree's while the switcher is up. The panel shutting and the
  switcher closing both apply it, so neither checks for the other.
- **A file chosen takes down a cover over its worktree once it has opened**, the
  Agents board or Debug Info, as a Files panel row would, without a select: that
  opens a first tab in a worktree with none and can ask the trust question. A
  file refused, a binary one, leaves the cover up, as does a cover raised after
  the choice. The open says whether it opened, a symlink opening at the path it
  points to.
- **Rows list in the sidebar's order**, projects as stored and each one's
  worktrees by its sort, and tabs in their strips' order, so a tie in the score
  falls as the user sees it.

- **Empty, Files lists what changed, a hundred at most**, kept in one pass as a
  search keeps them and in its order, shortest path first. A fresh build output
  of 50,000 untracked files sorted in full took 72 ms a render in a debug build;
  the pass takes 15.

- **The field takes back the model's text as each edit lands**, not on the next
  redraw: a key typed hard on a `>` would otherwise send the `>` again.
- **VoiceOver is told the row the arrows reach**, and only that, the keyboard
  staying in the field and typing heard as typing; an announcement, not checked
  with VoiceOver running.

- **The kept search goes when its worktree's tree takes another listing**, its
  key holding the old one, and as the switcher closes. A read whose listing
  still builds keeps it, the tree answering from the old listing meanwhile, as
  does a move of scope, or Tab from All round to Files would search every path
  again.
- **Return chooses the row selected as the key lands**, so Down or a letter
  typed hard before it acts first. Only the arrows, the text, the scope and the
  row moved to going scroll the list; an arrow at either end brings its row back
  into view, and a report re-ranking it leaves the scroll where the user put it.

## Reviewed and left as is

Raised by reviews and settled; a review need not raise these again.

- **A worktree selected at launch missing from Recent.** Launch selects nothing
  (`AppModel.init` calls `store.selectWorktree(nil)`), so every selection goes
  through `select` and is noted.
- **Escape over the Agents board or Debug Info leaving the keyboard on
  nothing.** No pane is in view to take it, and none had it before the switcher
  opened.
- **A background close taking focus closing the switcher.** That close takes the
  keyboard from whatever had it, switcher or not.
- **A choice of a menu item on a timer rather than on the field leaving.** The
  timer's ordering is the reason above; tying it to the field would make the
  model wait on a view's event.
- **A failed read of the files bumping `fileTreeBuildLandings`.** A read ending,
  failed or not, is a landing for whatever waited on it.
- **A project row carrying its whole `ProjectSettings`.** The copy is
  copy-on-write and nothing compares the results.
- **Places rebuilt and ranked on each render.** A few hundred rows, each title
  folded once, take well under a millisecond; only the file search, over up to
  200,000 paths, is kept between renders.
- **User themes written before `ui.quick_switcher`.** They fall back to the base
  theme's colours, as every new key does; the cost is above.
- **Cmd+W and the other menu shortcuts acting on the pane behind the open
  switcher.** They act on the window as they always do, and the switcher then
  closes as the pane takes the keyboard.
- **The field's font looked up by family on each redraw.** AppKit keeps the
  fonts it has made, and it is one lookup a redraw.
- **Cmd+Z replaying another field's typing into the switcher's.** Tested: it
  does not (`undoDoesNotReplayAnotherFieldsTypingIntoIt`).
- **A lone combining mark before a ligature shifting the bold letters.** Tried
  with `\u{301}ﬁt`; the letters bolded were the ones matched.
- **A click on the switcher, or beside it, reaching the pane under it.** Tested:
  `hitTest` finds the switcher's own views there, never the pane
  (`aPaneUnderTheSwitcherIsNotWhatAClickOnItOrBesideItFinds`), so the pane
  monitor does not take the click.
- **A project whose last worktree's folder has gone not falling back to its main
  one.** The missing-directory alert says why, and the main worktree is a row of
  its own; probing each recent folder first could block on a mount that hangs.
- **A file choice letting the listing go a second time once it opens.** The
  open's check needs an opened submodule's not-checked-out paths, which only the
  listing gathers, so it reads the tree the dismiss let go.
- **The board closed and opened again while a chosen file opens being taken
  down.** A cover has no identity to tell the two apart, and it is two key
  presses inside the open's few milliseconds; the cost is one more.
- **A second submenu of an earlier one's title listing items nobody can
  choose.** AppKit's lookup by title reaches only the first, as `ui menu` does,
  and no menu here has the shape.
- **The empty-field Backspace reading the field rather than the model.** While
  an input method composes, the model's text is still empty and the field's is
  not, so the model's answer would take Backspace from the composition.
- **A click on a row ending the field's editing before the click chooses.**
  Unproven: the test window, offscreen, cannot become key, so no test can send
  the click. It is under "Checked by hand" below.
- **A search building the Files panel's change tree with its listing.** One
  cache holds both halves, and the change tree is built off the main actor past
  20,000 changed paths; splitting the cache for that case would change the
  panel's.
- **The changed list and the search judging an openable path by different
  rules.** The changed list vets on the tracked list so it never builds a large
  repository's listing; the search has the listing already. Where they differ,
  an opened submodule's sparse paths, the open itself checks and beeps.
- **Closing the switcher over a cover letting go of the Files panel's listing.**
  Under a cover nothing keeps a listing fresh, so the one rule for kept listings
  drops it; the cost is one read as the cover comes down.
- **A project row matching by a parent folder of its path.** Typing `work` lists
  the projects under `~/Work`, as a project's name lists its worktrees; places
  stop at eight, and a title match outweighs a location's.
- **The field's text set while it edits ending the editing and closing it.**
  Tested: the field keeps the keyboard and shows the text
  (`textTheModelSetsWhileTheFieldEditsIsShownWithoutClosingIt`).
- **A file open landing after the switcher opened again closing it.** The file
  asked for takes the keyboard as it opens, and anything taking the keyboard
  closes the switcher; the open takes milliseconds, a deleted file's a git read.
- **Cmd+P after Tab going to All rather than closing.** Each key names a scope,
  and the one in view is what it closes; the rule above says so.
- **A report re-ranking the rows in the instant between a redraw and Return.**
  Return then takes the new first row; taking the drawn one instead lost the
  user's own Down or letter typed in the same burst, which is the likelier.
- **A pane's row not found by its worktree's own name.** Agents and tabs read
  `project › branch › name`, as asked, so `port fix` finds the worktree named
  Port fix and not the panes in it.
- **A run starting at a later word missed after an earlier word start.** Each
  letter takes the first word start that has it; finding the best of every such
  choice is a search per title on every key.
- **Command availability kept in a table by title, a missing title counting as
  able to act.** SwiftUI's buttons share one action and carry no identifier, so
  the title is the only key; a command left out is listed and does nothing,
  where one wrongly hidden could not be found at all.
- **`isMenuCommandAvailable` an `AppModel` method in MultishellAppUI.** It maps
  the UI's localized titles to the `can…` properties, which are the decisions,
  and those live and are tested in MultishellAppCore.
- **Each Cmd+P walking the whole menu bar, even for an empty All.** Walking on
  first need moves the same cost onto the first letter typed, Shift+Cmd+P needs
  it at once, and a second walk point would be a second place the list is read.
- **Each arrow press building the rows again.** It is the same build as a
  render, above, well under a millisecond.
- **The sidebar filter opened while launch ran losing the keyboard as it ends.**
  Its field is shown whether or not it is editing, and the model has no word of
  which; the switcher's, a rename's and a find bar's are known while they edit.
- **Launch's end skipping the seen-marking while one of those fields edits.**
  Unproven: launch selects nothing, and a Done in a pane in view is seen as it
  arrives, so no test found a pane the skipped marking would have cleared.
- **A rename field taken down without its blur, its id left set at launch's
  end.** Unproven: every way a rename ends found so far clears the id.

## Checked by hand

What tests cannot reach, to check in `make run` before a release:

- A click on a row chooses it, and moving the pointer over rows moves the one
  highlight; rows moving under a still pointer as the text changes do not.
- A click on a scope in the scope bar changes scope and leaves it open; a click
  ending the field's editing would close it instead.
- An input method's composition hides the prompt.
- VoiceOver announces each row the arrows reach, its path steps as a list.
- Cmd+P and Shift+Cmd+P open it from inside a terminal.
- The caret and field in a dark theme on a light system appearance.
- Commands lists no Services, Window, Help, editing or theme item, and drops New
  Tab at first launch and over the Agents board.
- It sits below the tab strip and, in the shortest window, inside it.
- **Files Panel listed under a cover while the panel is on.** Choosing it turns
  the panel off, as View > Files Panel does there; leaving it out hid a command
  that acts.
