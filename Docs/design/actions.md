# Project actions

Named commands a project's worktrees keep needing, Start Server or Run
Migrations, run on request in a tab of their own (issue 47). Newest at the
bottom.

- **Per project only.** A command such as `bin/rails db:migrate` means nothing
  outside its repository, so there is no global list.
- **An action never starts on its own.** Starting a server when a worktree is
  created stays the post-create hook's job. So a relaunch opens an action's tab
  as a shell: only a run asked for this time starts it, the way a restored agent
  tab resumes rather than starts (terminals/sessions.md).
- **The user's own and the file's are layered by name, not one list or the
  other.** The user's come first in the Actions page's order, which they drag to
  set, then the file's others in its order; an own action of a file action's
  name stands in for it. Owner's call, 2026-11-27: the page's order is the play
  menu's and, on Export, the file's. It replaced the file's order with an own
  action in its place, under which reordering the page changed nothing. Both
  menus draw a divider between the user's and the file's where both are there.
  The path lists are wholly one or the other (settings.md), but a teammate's
  committed actions would all vanish the moment the user added one of their own.
- **Export merges the same way**, so an untrusted file's actions, out of force
  and so missing from the settings in force, are written back rather than
  dropped (`carryingOver(from:)`). A file of only the user's own, in any order,
  is still trusted on export. An entry or a field this build cannot read goes
  back as written, after the rest, each own action written over the entry of its
  name (settings.md: export never rebuilds the file). Such an entry is a
  teammate's word a newer build runs, so export no longer answers the trust
  question for the user over it.
- **The file's actions wait for the yes its hooks wait for**, held against the
  same sha256 (settings.md): they run in the reader's checkout. Until then the
  play menu lists them greyed and runs nothing, and `actions run` is refused
  naming the trust.
- **A command runs as a hook runs** (hooks.md): sh through the login shell,
  interactive and login, `set -e`, the empty history file.
- **A command reads the worktree from variables, with no `{{}}` placeholders**
  (owner's call, 2026-11-27): `$MULTISHELL_PORT`, `$MULTISHELL_BRANCH`,
  `$MULTISHELL_WORKTREE_NAME`, `$MULTISHELL_WORKTREE_PATH`,
  `$MULTISHELL_PROJECT_NAME` and `$MULTISHELL_PROJECT_PATH`, set by `env`. The
  command runs as written, so a branch someone pushed is never script text.
  Writing `{{}}` into a script quoted for where it sat needs most of an sh
  parser: comments, heredocs, `$((1<<2))`, line joins and `$(…)` each broke it.
  Cost: the user quotes a variable as sh asks, and a value handed on to
  `sh -c "…"` or `eval` is parsed there.
- **The wrapper reports the run as a shell reports a command**:
  `command-started` and `command-finished` through the helper, and OSC 133's C
  and D for the engine. So working, done on exit 0 and failed otherwise, a
  notification, the sidebar and the Agents Dashboard come from the paths shell
  commands already take. An interrupt's 130 is done, a signal not being a
  failure. The end carries its seconds, as a shell's does: without them the
  notification rule took every run for an agent's Stop and announced it.
- **Action tabs count like agents**, on the board and in the sidebar's header,
  with Show all terminals off too (owner's call, 2026-11-26). Cost: a dev server
  reads as working for as long as it runs. A card says it is an action to
  VoiceOver and in `board list` and `sidebar list`, where it is not an agent and
  not a plain shell.
- **The wrapper traps Ctrl+C**, so the end is still reported after the user
  stops the script; the subshell running it takes the signal as usual. Without
  the trap the wrapper died with it, nothing reported the end, and the tab
  stayed working.
- **The script and the wrapper travel in two variables**, neither written into
  the other or into the login shell's line, for the reasons hooks.md gives for
  one.
- **A shell takes the tab once the action ends**, `exec`ed by the wrapper, so
  the output stays readable and an agent can read the pane. The wrapper unsets
  `HISTFILE` first, or that shell would keep no history, and the worktree's
  variables but the port, which would stay frozen at launch where a plain tab
  has none.
- **Running it again while it runs asks to restart**; the command line refuses
  instead and takes `--restart`, a script being unable to answer a dialog. After
  it ended, the tab is reused without asking.
- **A restart is a fresh session in the old one's pane**, which the engine stops
  as it does a closed tab's: SIGHUP to its process group, repeated until the
  group's leader is gone. Not `ProcessStopper`, as the issue asked: the engine
  owns the pane's child and gives no pid to stop. Cost: a grandchild that left
  the group and ignores SIGHUP outlives the restart, holding its port.
- **The tab keeps the action's name** over whatever the shell after it reports
  as a title.
- **The play button sits beside the ⋯ menu, never in it.** That menu is shared
  with the sidebar's right-click and the board's cards, and the owner did not
  want actions crammed in there. It shows in a project with no actions too, so
  Edit Actions… is always one click away; owner's call, 2026-11-27.
- **The play menu is AppKit's, popped up below the button**, as a menu row shows
  a title and an image, not a view. A running action's dot turns as still frames
  a timer swaps while the menu is open, on the common run loop modes its
  tracking runs in; SwiftUI's `Menu` gave no way to swap them. Under Reduce
  Motion no timer starts, so the dot holds still as `StateDot` does. Rows are
  marked only while one has a state: blank marks alone indented every name.
- **A play menu row shows its keys at the right, as a menu bar item does.** In a
  popped-up menu they act only while it is open, so the Terminal menu's item is
  still what fires them.
- **The Actions submenu is skipped when the menu's keys are set by title**, as
  the theme picker is: an action named New Tab took New Tab's keys and lost its
  own.
- **The Terminal menu's Actions submenu carries an item per action** of the
  selected worktree's project, under the action's own name, since names such as
  Run Tests read "Run Run Tests" with a prefix. That is what gives an action its
  keys and the quick switcher its "Start Server" command, both of which read the
  menu bar.
- **Keys are set on the Actions page, not Settings > Shortcuts**, owner's call
  on 2026-11-26: Shortcuts is global and lists menu commands, and an action is a
  project's. They are stored with the user's project settings by action name,
  the file never carrying keys. They are judged as Shortcuts judges a command's,
  but keys a menu command holds are refused rather than taken: the menu would
  fire first anyway. Keys a command is given later stay the action's, and its
  row names the command that now fires in its place.
- **A rename carries an action's keys; a removal frees them**, unless the file
  still has an action of that name.
- **Keys given to a second action move from the first** without asking, both
  being the same project's and the user's own; only a menu command's are asked
  about, and refused.
- **A row the Actions page has not filled in runs nothing and is never
  exported**, and a relaunch drops it, a blank name or command decoding as no
  action.

- **An action's run is tracked apart from its tab's dot**, from its launch to
  its wrapper's end mark. The dot cannot say: the shell taking over reports its
  own commands there, and a `tail -f` typed after a crash read as the action
  running, so picking it asked to restart and killed the `tail`. Its age counts
  from that launch too, the dot's time moving with a bell.
- **A rename carries the action's open tabs and title with it**, or a running
  server's tab matched no action and the next pick started a second one on the
  same port. A restart question asked before the rename is asked again under the
  new name, the sheet up having kept the old, and goes once its tab is no
  action's or its action is out of force: a command cleared, the trust taken
  back, or the file read without it.
- **Except from a `.multishell.json` action's name**: that action is back in
  force, so its keys and tabs stay with it. Renaming onto a name that already
  holds keys keeps those, the renamed action standing in for the file's.
- **A name is written back on Return or on leaving the field, trimmed**, and one
  another own action has is refused. Per keystroke, backspacing through another
  action's name took its keys, and a trailing space lost them at the next
  launch, the read trimming what the keys were stored under.
- **No action starts in a worktree a create or remove is running in**, as no new
  tab does; `actions run` is refused there as `tabs open` is.

- **Only the keys of actions in force are taken from the panes.** A row with no
  command, or a file's action deleted or not trusted, runs nothing, and its keys
  outlived it with no row left to clear them. The configuration is applied again
  whenever that set can move: a trust answer, the file read again, a command
  filled in or cleared, a rename, a project removed. Keys a dropped row left
  under a name go when a rename takes that name, and its tabs stop being any
  action's, or the new action asked to restart a run not its own.
- **A row is dragged as its own type, `io.multishell.action-row`**, never text:
  a name or command field took a text drag as typing and pasted the row's id
  into itself. Each row takes a drop over the gap either side of it, its line
  drawn only where the row would move.
- **Add Action adds a blank row**, the name typed rather than a placeholder
  deleted first. A blank row takes no keys, so its keys cell waits for a name.
- **Rows are keyed by an id each action carries in memory**, never stored and no
  part of its equality. By index, a removal handed an edit to the next row; by
  name, a rename rebuilt the row and Tab lost the command field.

- **`config project set` takes neither `actions` nor `actionShortcuts`**, as it
  takes no trust answers: a raw write passed by the keys' judge and the tabs a
  rename carries.
- **A tab moved to another worktree stops being its action's**: its run still
  serves the worktree it left, on that worktree's port, and kept, the
  destination's menu showed it running. Cost: a pick in the worktree it left
  starts a second copy, which finds the port taken. A removed action's tabs stop
  being any action's, or the next action given its name took them over, a
  running server included.

- **A pick asks before replacing a tab anything still runs in**, its own run or
  what the shell after it started, an agent say, idle at its prompt too.
  Replacing it unasked ended an agent and its conversation with no question,
  where ⌘W on the same pane asks.
- **The menu bar's action items carry no run state**, or every agent's report
  rebuilt the menu bar. The header reads none of them; the play button reads the
  run states, so a report redraws only the button.

- **Until `.multishell.json` has been read, or while it will not read, a removal
  or rename moves no keys or tabs**: the file may still hold that name, and
  reading it as empty cost every file action its keys on any removal. A project
  whose folder is missing is never read, so it stays that way all run.

- **`actions run` starts the run in the background**, as `tabs open` does: an
  agent in one worktree running a server in another moved the user's view and
  keyboard there.
- **`actions run --restart` takes `--force` over a working agent**, as every
  request over one does, the agent being what the shell after the action ran.
- **A tab renamed onto a name its worktree already has a tab of is no
  action's**, or it kept a name no action had, and the next action given that
  name took it over.

## Asked both ways

- Round 1 had a command typed after an action ended read as the action running,
  and a pick restart over it unasked; round 6 had a pick replace that command
  unasked. Kept: the menu shows the action idle, and a pick asks before ending
  whatever runs in its tab.
- An earlier round kept a tab moved within its project its action's where the
  destination had none; round 9 found the source then started a second copy.
  Kept: any move ends it, as above.

## Reviewed and left as is

- An action's end carries whole seconds, as bash's does; zsh and fish send
  milliseconds. The wrapper is sh, which has no finer clock without starting
  another process. Cost: a card's tenths read .0, and a run can count up to a
  second long against the notification threshold.

- Unproven: that SwiftUI redraws the Terminal menu's action items on every
  change of selection or actions. `Commands` are not reliably redrawn
  (shortcuts.md); the items read the model, and the AppKit pass that sets
  command keys by title does not touch them.
- A menu command later given keys an action holds shares them with it until one
  is changed; the menu's own item, earlier in the bar, fires.
- Once a run has ended, the play menu shows the tab's done or failed, which a
  command typed in the shell after it also sets. Keeping the run's own outcome
  would need a second Done that being seen does not clear.
- Unproven: an rc file that `exec`s another program, tmux say, before the
  wrapper's line runs leaves the action reading as running until its tab closes.
  No shell here was driven to show it, and marking the run from the wrapper's
  own report would leave a gap in which a second pick starts a second copy.
- One project's action keys are taken from every pane, other projects' included,
  where its items are not in the menu. Unbinding per project in view would apply
  the configuration to every pane on each switch of project.
- "Worktree actions" (the ⋯ menu, `WorktreeActions`) and project actions share
  the word: the issue names the feature, and the ⋯ menu's names predate it. Each
  is qualified where they meet.
- Unproven: a shell the action starts, `nix develop` say, whose rc prints OSC
  133 by hand ends the run at its first command, and a pick then replaces it
  unasked. Multishell's own integration hands `ZDOTDIR` back, so a nested shell
  never loads it, and the engine's end mark names no sender to tell them apart.
- Unproven: a server slow to stop on SIGHUP, Puma say, may still hold its port
  when a restart's new run starts, which then fails. Waiting for the old
  session's exit would need the engine to report one per replaced pane.
- A yes given by a build before actions, to a file a newer build wrote with
  some, covers those actions after an upgrade: trust is held against the file's
  bytes, not the text shown. The agent and terminal starts added to the question
  earlier went the same way. Asking again would need each answer to record which
  fields it covered, and actions never run without a pick.
- Unproven: an unsaved edit in a name field landing on the next row when its own
  row is removed while the field has focus. It needs SwiftUI to report a removed
  view's focus change, which no run here showed.
- AppCore's `ActionMenu` and `ActionMenuItem` keep their names beside AppUI's
  `ActionsPlayMenu` view (review of 2026-11-27): renaming the value to match
  would give the value and the view one name across the two targets.
