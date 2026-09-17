# Known gaps

What is unverified or unbuilt, with the fallback where there is one. A gap whose
behaviour is settled goes under Known issues; one that nobody has watched happen
goes under Unconfirmed behaviour, and moves up when someone does.

## Known issues

- Agent settings is the one page nothing holds: its `onAppear` refresh reads the
  machine, so the page is as tall as whatever is installed and a test would be
  measuring a laptop. Measured headlessly with the refresh taken out, it is
  260pt with no agent's hooks installed, 357 with one, 481.5 with four and 550.5
  with all five, so the 600pt window covers every case this developer can
  produce. A sixth supported agent would put it over again, and nothing would
  say so; fix then = the hooks rows want their own scroll.
- A `ZDOTDIR` set in `/etc/zprofile` leaves the tab without hooks: zsh reads
  `$ZDOTDIR/.zprofile` and `.zshrc` from wherever the variable points at that
  moment, so a system file relocating it after our `.zshenv` steers the rest of
  the chain past our files, as it would past any user's. The user's own
  `.zshenv` and `.zprofile` relocating it are followed; terminals.md. No
  fallback short of the helper hooks being appended to that directory's
  `.zshrc`, which the design refuses.
- Project settings' Hooks tab wants 973pt in a 600pt window, so its last editors
  are below the fold with nothing saying so. Six monospaced editors were never
  going to fit a window the other pages can share, and SettingsPageSizeTests
  records this one as deliberate so the next page to overflow is not lost in it.
  Every other page fits, Project General closest at 581.5.
- Directory check before a click starts a shell runs on the main thread, so a
  network volume that has gone away blocks until the mount times out. Polling
  paths' checks run off it.
- A file list a new worktree is given has no timeout, unlike a hook: runs until
  done or the pane's Cancel, which lands between paths. Nor has
  `git worktree add`, by decision (worktrees.md): the sheet's Cancel ends it.
- The login shell's `env -0` output is read from the first line shaped `KEY=`,
  so a greeting an rc file prints ahead of it is skipped, but a greeting line
  that itself reads `word=word` is taken for the first variable and swallows the
  real one, PATH where the shell exports it first. Not decidable from the text;
  the fallback is the process's own PATH.
- A scrolled tab strip does not auto-scroll while a tab is dragged near its end,
  so a tab cannot be dragged past the visible tabs: reordering reaches only what
  is on screen, and a tab off the end cannot be dropped on. Auto-scroll needs
  the drop's own pointer position, a repeating step, and the strip's
  `ScrollViewProxy` reaching the drop delegate.
- A tab drag released where nothing takes it, outside the window or over a part
  of the sidebar that is not a worktree row, never ends: `.onDrag` has no
  cancellation callback, and only a drop clears `AppModel.tabDrag`. The five
  drop paths do clear it, the sidebar row included, so what is left is the
  abandoned drag. `TabDragState.isDragging` then stays true and every column
  keeps `TabGroupBands` mounted over its pane: the bands stay hidden, being
  drawn from `overColumn` and `band` which the pointer leaving does clear, so
  the cost is a `Color.clear` drop target and its accessibility label over the
  terminal area until the next drag begins, which resets the state. Not seen on
  screen. Fix would want a gesture that reports its own end.
- While the Agents board is up, what acts on a pane does nothing, but Open in
  Editor and New Worktree still act on the selected worktree, and no sidebar row
  draws as selected then, so those two have nothing on screen naming their
  subject. Left because neither is destructive; fix = route them through
  `worktreeInView` as the pane commands are.
- Sidebar keyboard navigation and a shortcut to focus the filter are not built,
  and the filter is now behind the header's magnifying glass, so the mouse is
  the only way to it. No view tests, and the accessibility labels have not been
  read with VoiceOver.
- Existing-branch picker lists local branches only, so a remote-only branch is
  created as a new one based on its remote. A decision, not a defect.
- `.multishell.json` is read from the project path, which for a bare repository
  holds no checkout.
- The placeholders an agent's flags may use are documented nowhere a user can
  reach: the settings rows name `{{branch}}` as an example, and the rest live in
  `AgentPlaceholder` waiting for a documentation site.
- The app ships English only, so nothing has been seen in another language: what
  is unproven is not the lookup, which TranslationTests and a read out of a
  built bundle both cover, but the layouts. Several settings pages already fit
  their fixed window with little to spare, and a language that runs thirty per
  cent longer than English would be the thing that overflows them;
  SettingsPageSizeTests measures English. The sidebar rows, the tab strip and
  the board columns all size themselves off measured text, so those should give
  rather than clip.
- A number inside a phrase is written the way Swift writes one, no locale: the
  board's one decimal reads `0.4s` in a language that would write a comma.
  Deliberate, since the alternative makes every test of it read the machine's
  region; fix if it grates = a locale in `t(_:_:)` and those tests pinned to
  one.
- A tab's title is a persisted field, and a plain shell's starts as the
  translated word for Shell, so tabs made before a language change keep the old
  one. It corrects itself under zsh and bash, whose integration retitles the tab
  on the next command; with another shell it stays until the tab is closed. Fix
  if it matters = store the default as absent and translate it where it is
  drawn, which is a change to a persisted field.
- A git older than 2.36 cannot list worktrees at all, `-z` being unknown to it
  there. Nothing checks the version or falls back to the plain porcelain: the
  read fails, the row says so and names the option. Left because the supported
  macOS ships 2.39 and the call site is one line either way; fix if it bites =
  retry without `-z` on that one failure.
- A tag named exactly like a local trunk still decides the base: the worktree's
  branch goes to git as a refname, the base does not, `DefaultBranch.ref` being
  the short print form. Every merge read for that project would then be measured
  against the tag. Unlikely enough to leave: a remote-tracking base cannot tie
  with a tag, so it needs a repository whose default resolves to a local `main`
  with a `main` tag beside it.
- A hook group holding one of our commands as a bare `command` beside a `hooks`
  array of the user's keeps our command after Remove, which reads as Remove not
  working. No agent writes that shape and Add never produces it, so it is
  reachable only by hand-editing; the two shapes are handled separately and the
  bare one is taken as ours whole.
- Saving is off for the whole session once state is found unreadable and
  unmovable, and the check is made once at restore. Permissions fixed while the
  app runs are not noticed until relaunch, and the session's work goes at quit
  with only the launch alert having said so.
- A worktree is held back from `git status` while the app is making it, by the
  path `git worktree add` was given and by the stage running on it, so two ways
  past remain. One: `git worktree add` run in a terminal, where the app learns
  of the row from the watcher and knows nothing of a checkout in progress. Two:
  a symlinked volume, where git's resolved path and the planned one differ and
  the comparison misses. Either shows the row's changed count reading the
  half-made tree until the next poll after it settles. Fix = read git's own
  mark: mid-add the porcelain list says `locked initializing` and
  `.git/worktrees/<name>/` holds `locked` with no `index`; match the files, the
  reason being localised, and a plain `isLocked` would blank a worktree the user
  locked. See docs/design/worktrees.md.
- Use Selection for Find, Cmd+E on every other Mac find bar, is not offered: the
  wrapper's AppKit view keeps its `surface` internal, and the selection is read
  through it. Ghostty's own Cmd+E stays bound and does nothing here. Fix = a
  wrapper release exposing `readSelection` on the view.
- The find bar shows no match count and no "wrapped" mark: the engine sends both
  through `GHOSTTY_ACTION_SEARCH_TOTAL` and `SEARCH_SELECTED`, which the
  wrapper's callback bridge logs under its `default` arm and forwards to no
  delegate, on the pinned tag and on its main branch alike, and its debug sink
  logs an action's name without its value. Fix = a patch to the bridge
  forwarding the two, upstreamed and the pin moved at the cost dependencies.md
  names, or carried as a copy of the wrapper in this repo. Decided against for
  now: a count is not worth carrying the wrapper.
- `creationStopper` and `worktreeCreationStep` are one slot each, so with two
  creates overlapping, Cmd+N reopening the sheet while the last one runs, the
  first to end nils both: the second sheet's Cancel then does nothing, its hook
  and its `git worktree add` cannot be stopped, and its later steps are dropped
  as belonging to a create that has ended. The row hold-back is counted per
  create and is not affected.
- Copilot keys a worker by `agentName` at both ends, so two of one kind out at
  once share one place on the roster and one raiser. Nothing in the payload
  separates them, so no report under that place answers a prompt raised there
  while another worker is still on it: a prompt the asking worker answered stays
  on the dot until its sibling's next report. The chip counts the workers rather
  than the places, so the number is right even where the list holds one row for
  two.

## Unconfirmed behaviour

- `make-app.sh` has run through `xcodebuild` only under Xcode 27, where
  `swift build` had already stopped writing the build path it was switched away
  from (build.md). That Xcode 26's xcodebuild writes none either rests on its
  accessor having looked in `Contents/Resources` since packages could carry
  resources, not on a run. The helper is checked too and is built with
  `swift build`, so under 26 the build is expected to be refused at that check
  rather than install a helper that breaks at the next `make clean`; neither
  outcome has been watched there. Fallback = Xcode 27.
- The sheet's Cancel ending a running `git worktree add` is tested against a
  fake git that sleeps, not against a real checkout held by an LFS smudge or a
  credential helper; what git leaves behind when signalled mid-checkout, and
  whether the next refresh lists it, has not been watched.
- The generated Ghostty config directory is cleared at launch and at quit; the
  quit half runs from `applicationWillTerminate` and nobody has looked in
  `$TMPDIR/io.multishell.app` after one. If a file survives, macOS's temp purge
  takes it within three days.
- The worktree row's rename field is inside an accessibility container only
  while renaming; whether VoiceOver lands on it once the Rename action opens it
  has not been read, the labels never having been.
- The tab strip's two split buttons have never been watched on a screen.
- A split or column divider drag now holds its weights in the view and writes
  the model once when the drag ends, the end read off the gesture state
  resetting so a drag the system cancels commits too rather than snapping back.
  Nobody has watched a cancelled drag; if it snaps back instead, the fallback is
  the model's last saved weights. The sidebar divider reads its start width off
  gesture state for the same reason, and the same is unwatched: a drag Cmd+Tab
  interrupts used to leave the next one jumping to where the last began. Every
  number behind them is held by UIMetricsTests: a column at
  `SplitMetrics.minimumPane` drops them at every font size, the threshold runs
  187pt at 10-point to 338pt at 18, and a width of zero or NaN reads as "no
  splits", so a first frame degrades to New Tab alone. What a screen would
  settle is what a measurement cannot: that the buttons sit where the plus does
  rather than under the scroll gutter, that the collapse is not seen as a
  flicker while a column divider is dragged across the threshold, and that the
  split lands in the column clicked rather than the focused one. Fallback if the
  collapse reads badly: the threshold is `UIMetrics.stripShowsSplits` alone.
- A scroll wheel over a scrolling tab strip works, watched on a screen with a
  mouse whose turns arrive as points. A wheel that sends lines instead has not
  been: SidewaysWheelTests holds its rate to the scroller's own, 10 points a
  line, so a notch may read as slow across a tab of 100 to 190 points. Fallback:
  scale the swapped deltas before handing them on. A trackpad's vertical turn
  has not been watched either: its gesture opens with a `mayBegin` event whose
  deltas are both zero, which the catcher does not answer for, and if AppKit
  routes the whole gesture by that first event the strip never moves. Not a
  regression, a trackpad scrolling it sideways as before. Known and not fixed:
  the two arrow gutters are outside the strip's scroller but under the catcher,
  so a turn with the pointer over an arrow scrolls the tabs, which is the
  behaviour wanted, but a turn with the pointer over the New Tab or split
  buttons does nothing.
- Ghostty's focus report reaches the store a turn after libghostty raises it,
  because a frame showing a surface already in a window raised it from inside
  `updateNSView`, where a store write is undefined. Before it writes, the host
  checks the surface still holds the window's first responder, so a report
  cannot land for a pane the keyboard has since left. The store's half is
  tested; the hop and the check are not, Ghostty's path needing a window and
  Metal. The wrapper's `AppTerminalView` makes itself first responder and calls
  `setFocus` from `becomeFirstResponder`, so the check is exact; a descendant is
  accepted too in case a later wrapper adds one. If a click's focus is ever seen
  to lag or go missing, fallback = report synchronously again and defer
  `requestFocus` in `SurfaceFrame.focusIfReady`.
- The engine's path untested, its zsh chain checked only against a stand-in
  bootstrap. Click-to-move does not work on the later lines of a multi-line
  buffer.
- Nothing drives a `TerminalHost` against a real child. Untested: a closed tab's
  shell ending and being collected, a title from OSC reaching the delegate, an
  exit code arriving, a `close` after it being safe. libghostty's surface needs
  a window and a GPU, which the tests cannot give it; see build.md. `FakeEngine`
  covers the core's half of the seam and none of the host's. Fix = a host test
  under a window server.
- The user's Ghostty config is read and handed to libghostty as the base config,
  but only the text that is sent has been tested, and against libghostty rather
  than a surface: whether a font, keybind or cursor from it changes what is on
  screen is unseen. What was checked is that libghostty accepts it, every key of
  a Ghostty 1.3.2 default config having been offered to the pinned build one
  line at a time. Three limits. Nothing tells a user which of their lines did
  not count, and there are two ways for a line to go quietly: a key outside
  `GhosttyUserConfig`'s allowed list, and a line `repair` dropped because
  libghostty complained. Fix = the dropped lines named in Settings, where a
  theme file that will not parse is already reported. The files are read once,
  when the engine's host is created, so an edit lands at the next launch and
  nothing says that either. And a `config-file` line is not followed: the
  wrapper loads with `ghostty_config_load_file` and never calls
  `ghostty_config_load_recursive_files`, which is the call that expands one, so
  a user who splits their config keeps the two files read here and loses every
  part those include; the key is not on the allowed list either, which at least
  keeps it out of the text libghostty is handed. Any other relative path in the
  file resolves from the temporary directory the effective config is written to
  rather than from the file's own.
- Whether SwiftUI calls `updateNSView` when every stored value of the view
  compares equal is unseen, so how often the focus guard in `SurfaceView` was
  actually firing is unknown. The guard is right either way and costs nothing;
  what a screen would settle is whether the keyboard was being pulled out of the
  sidebar filter in practice or only in principle.
- `SurfaceFrame.show` asks for focus whenever the surface it holds changes,
  which is what closing a pane does to the frame that keeps its index. That a
  frame really is reused across sessions is read off
  `ForEach(children.indices, id: \.self)` rather than watched: what
  SurfaceFrameTests pins is the frame's own behaviour, in a window nothing
  ordered in. Whether three panes minus the focused one leaves the keyboard in
  the right place is still a question for a screen.
- The DEBUG-trap claim is spliced into `PROMPT_COMMAND` as `owns || trap`, which
  needs bash to parse each entry as a command rather than as a bare argv. That
  is what bash does for the string form, tested here against Apple's 3.2. The
  array form arrived in bash 5.1 and this machine has no bash 5, so the array
  half is read off bash's source rather than run: if it turns out wrong, the
  words appear at every prompt as a command not found, and the fix is to give
  the array its own single-word entry.
- A promised drop waits for as many reader calls as the item's `fileNames`
  promised, which is what `NSFilePromiseReceiver` documents. If a source instead
  reports once for an item it promised several files for, the drop waits out the
  two-minute patience rather than pasting early. A real promise drag cannot be
  staged in a test (PromisedDropTests says why), so this is read off the
  documented contract rather than watched. The fallback if it turns out wrong:
  retire an item on its first failing report.
- Linux never compiled, locally or in CI. The counted phrases are the part of
  the catalogue to look at first when it is: `Localizable.strings` is plain
  enough that corelibs-foundation reads it, and whether its `NSLocalizedString`
  applies a `.stringsdict` plural rule at all is unchecked. If it does not,
  every counted phrase answers with its own key and the number is dropped; the
  fallback is to build those few forms by hand where they are read, which is
  where they came from before the catalogue had them.
- Notifications settings page never seen on screen: the toggles, the caption
  under them, the six-tab band in a 560pt window. SettingsPageSizeTests holds
  this page's height under the window's own, so what is left is how it reads
  rather than whether it runs off the bottom. The band is measurable by nothing,
  SwiftUI drawing it outside the AppKit hierarchy; if it clips, raise the width
  in SettingsView. Caption and the help behind each (i) are strings in
  NotificationSettings.
- The 600pt settings window has not been seen on screen. It is the height the
  tallest page needs, so General shows 159pt of rows above 441pt of nothing, and
  whether that reads as roomy or as broken is a question for the screen. Fix if
  it reads badly = the tall pages scroll and the window goes back to about 480.
- Drops reach SurfaceFrame because AppKit walks up from an unregistered engine
  surface to the frame that is registered: documented for the registration,
  undocumented for the search order, so if the engine ever registers a dragged
  type the frame stops seeing drops. Checked only by hand. Same walk carries a
  dragged tab past a surface to the SwiftUI band over it, SurfaceFrame being
  registered for files and promises and not for `io.multishell.tab`; if a band
  never lights, fallback = register the tab type on the frame and answer it
  there. Every column's tab strip takes a tab, and the sidebar's worktree rows
  do; nothing else.
- Tab-group drawing unverified on screen: whether bands appear as a tab crosses
  a terminal area, whether the insertion line lands in the right strip, how an
  unfocused column reads, whether a strip's scroll arrows read as "more tabs
  this way" better than the fade they replaced. Store, model and wording tested;
  drawing not. Cost of drawing only from what the pointer is over: bands are not
  on screen until the tab reaches a terminal.
- Whether a SwiftUI overlay composites above the engine's surface is unverified,
  libghostty's being Metal-backed: the focus ring has always been drawn that
  way, and now the unfocused-pane fade and the find bar too. If none appears,
  the first two are silent rather than wrong, and the fade would have to become
  a view inside SurfaceFrame the way its drop highlight is; a find bar that does
  not appear still searches, its shortcuts reaching the model, and would have to
  move into SurfaceFrame the same way.
- The find bar has never been seen on a screen. Unwatched: that the first step
  after a needle lands on the newest match and scrolls to it, which is the
  engine's `selectNext` from no selection read off its source; that a bar whose
  field has the keyboard is the one the menu items act on, the model's half of
  which is tested and the field's `onChange` of its focus and `onDisappear` not;
  that Shift+Return steps up, the shift being read off `NSEvent.modifierFlags`
  at the submit rather than off the event, so a Shift+Return that steps down is
  the sign, and the fallback is the up arrow or Cmd+Shift+G; that the Find
  menu's items enable and disable as bars open and close, which rests on a
  `Commands` body re-evaluating for an `@Observable` read, the doubt the file's
  own comment records, and whose failure is an item that stays grey or stays
  black while its action still guards; that Escape in a pane under an open bar
  reaches the program, `escape=unbind` in the config being what releases
  Ghostty's own binding, and an Escape that instead takes the highlights down is
  the sign; that a bar a worktree switch brings back leaves the keyboard in the
  pane, the model's half of which is tested and the field's `.task` not; and
  that a 340pt bar reads at every font size over a pane at
  `SplitMetrics.minimumPane`. Cmd+X, C, V and A in the field are read off the
  wrapper rather than watched: its `performKeyEquivalent` answers only while the
  surface itself is first responder, so the field's editor gets them through the
  Edit menu's `sendAction`. Wrap-around is read off the engine's source on its
  main branch, `selectNext` and `selectPrev` in `terminal/search/screen.zig`,
  not watched in the pinned build, and the wrapper's dropped count means nothing
  on screen would say if it had stopped.
- Reordering inside one column happens as the pointer passes each tab, not on
  release; see TabShuffle and `AppModel.shuffleTab`. Unverified at the edges: a
  strip whose tabs differ widely in width could in principle move a tab back and
  forth across one boundary, the tab landing under the pointer being what stops
  that.
- Agents board drawing unverified on screen: whether a card reads at the 208pt
  column floor, where the worktree name and the git badge share a line and the
  name is what gives way, whether a partial column at the edge reads as "more
  this way" without the arrows a tab strip has, whether a vertical scroll per
  column nested in the board's horizontal one feels right to a trackpad, whether
  the Dock badge appears at all under this build's signing. If the partial
  column does not read, fallback = the tab strip's: an arrow in a gutter at each
  end that has cards past it, from `TabStripLayout.Edges`. Two known divergences
  from the mockup: columns are full height rather than hugging their cards,
  which is what lets each scroll on its own; and the View menu item's position
  within that menu is AppKit's to decide, being added to the standard group.
- Neither agent-flags row has been seen on screen: the CLI Flags field under the
  agent picker in Settings > Agents, and the CLI Flags override in a project's
  Agent tab. The value they write and the command line it builds are tested; the
  rows' width, and how an empty one reads with no prompt text in it, are not.
- Claude's fourteen notification types were read out of the 2.1.268 binary's own
  list, not watched arriving on the hook, and which four only announce was
  decided from their names. What was checked is the helper's end: synthetic
  payloads through the built helper report `attention` for `permission_prompt`,
  `worker_permission_prompt` and a payload naming no type, and send nothing for
  `idle_prompt`, `agent_completed`, `auth_success` and
  `quota_auto_resume_fired`. Those four are the list, everything else counting
  as a question, so what a new type costs is a banner too many rather than a
  prompt nobody is told about. Nothing says which way it went: an announcing
  type Claude adds later reads as waiting until someone notices and names it.
- Which type raised the banner that prompted the narrowing is unestablished. It
  followed the turn's Done by about ten seconds, and Claude's idle prompt is its
  own timer of sixty seconds from the turn ending
  (`messageIdleNotifThresholdMs`, unset in this user's config), so it was more
  likely a teammate's `agent_completed`. Both are dropped either way.
- Neither half of the banner grouping has been seen on screen, both being
  UserNotifications behaviour a headless test cannot reach. Unverified: that
  re-adding a request under a delivered notification's identifier replaces its
  row and alerts again rather than being dropped as a duplicate, and that
  `removeDeliveredNotifications` takes down a banner still on screen rather than
  only its row in Notification Centre. If the second turns out to only clear the
  Centre, a stale "Waiting for input" still sits on screen for its few seconds
  after the user has reached the pane, and there is no API for that; the row
  behind it is the part that would have lingered for hours. What is tested is
  the model's half: which key is posted about, which is taken back, that a key
  is taken back once rather than on every report after, that being away from the
  app is not being shown the banner, and that closing a tab takes its banner
  with it. A withdrawal takes back the pending request as well as the delivered
  one, `add` delivering a moment after it returns. One hole left in the
  notifier: a withdrawal between the moment a waiting request is taken out of
  `pendingAdds` and the `add` that follows it lands a banner nothing will
  retract. Microseconds wide, and only on the path where the permission dialog
  has not been answered yet.
- `multishell state` at a prompt in one of the app's own tabs is meant to name
  the shell, the helper's walk stopping at `MULTISHELL_APP_PID`. Checked against
  a real shell chain under the test process, not under the engine: whether
  libghostty puts anything unlisted between the shell and the app is unwatched.
  If it does, the walk ends there instead and the dot outlives the shell, as it
  did before; a pid equal to the app's own is dropped either way.
- The tab strip's + is a `Menu` in `.button` style under `.buttonStyle(.plain)`.
  The `.borderlessButton` version drew no chevron and put the plus in a corner,
  seen on screen; the plain button draws the label as written, also seen. Its
  label paints `chromeColor` over the whole `newTabMenuWidth` frame and carries
  a `contentShape(.rect)`; that a click on the blank part of that frame opens
  the menu is not yet confirmed. Its items and what each opens are tested on the
  model, not through the view. The sidebar's sort menu, on the Projects header,
  paints `sidebarColor` over its 24-point frame for the same reason and is
  unconfirmed the same way; its glyph and items have been seen on screen and
  work.
- The subagent chip's list is a SwiftUI `.popover` opened from `onHover`, held a
  quarter second after the pointer leaves so it can be crossed onto. Nobody has
  watched it: whether the popover takes the keyboard from the terminal under it,
  whether the pointer leaving the chip for the popover keeps it up, and whether
  one in a sidebar row survives the row's own tap gesture, are all unconfirmed.
  The fallback is a multi-line `.help` tooltip carrying the same text, which
  steals nothing and cannot tick.
- Copilot's subagent events are asked for as `SubagentStart` and `SubagentStop`,
  the spelling whose payload names the event, on the strength of its other
  events taking that spelling; its reference documents them as `subagentStart`
  and `subagentStop`, with `agentName` and `agentDisplayName`. Not seen firing.
  If it does not, the file needs the camel spelling and the payload no
  `hook_event_name`, which `AgentHookPayload` refuses today. Its stop is keyed
  by `agentName`, as its start is; should the stop carry `agent_id` in Claude's
  spelling, that would win the key, match no name-keyed place and take nothing,
  and the entry would stand until the next prompt.
- OpenCode's plugin bridge forwards an event only when its directory matches the
  plugin's; that a child session's `session.created` and its later
  `session.status` pass that filter is read from source, not seen.
- A subagent fan-out interrupted with Ctrl+C keeps its chip until the next
  prompt is sent: Claude fires no hook on an interrupt and the killed workers
  send no stop, so the prompt starting the next turn is the first thing that
  says they are gone. Whether Claude sends anything sooner that could stand in
  has not been checked against a run.
- A Done the agent's Stop owes outlives the agent's own later reports, so under
  a helper too old to send `turn` a worker that outlives its turn pays that Done
  in the middle of the next one: a Done banner and dot while the agent is
  working, until its next report. Nothing else says a turn began there. Under a
  current helper the prompt clears what was owed before its Working lands.
- Every hook that fires inside a worker carries `agent_id`, and a main-session
  hook is taken to carry none: `subagentReport(for:)` reads any payload with the
  field as a worker's tool call, whatever the event. Read from Claude's
  documented payloads, not watched. Should a main-session `PreToolUse` carry one
  too, each would put a worker keyed by the session id on the roster and
  `startsTurn(for:)` would stop clearing it at the next prompt, so the pane
  would hold Working with a Done owed to a worker that does not exist.
- A Failed a worker's prompt displaced comes back when that worker ends saying
  what the failure said, `displaced` carrying its note, but with a fresh age:
  the stamp moved when the prompt took the dot, and only the state and the note
  are put back. Needs StopFailure with a worker outliving it, which nobody has
  seen happen.
- OpenCode's plugin takes a `chat.message` from a session it has not seen
  created as the parent's, and a parent's prompt starts a turn: a child's first
  message arriving before its `session.created` would empty the roster. Bus
  order is read as creation first; not seen. A message that names no session at
  all is covered: it reports Working and starts no turn.
- OpenCode's plugin caps the ended child ids it keeps at 64, and only an ended
  one can go from the map: more than 64 children live at once, or children whose
  end events the directory filter drops, grow the map for the life of the
  process. Deleting a live child's id would be worse, its later events being
  read as the parent's. Not seen; OpenCode is not known to run that many at
  once.
- OpenCode's plugin names a child worker by `info.agent` on `session.created`;
  if that field is absent from the session info, as it may be, every OpenCode
  worker shows as "subagent". The kind is also in the child's title, as "(@name
  subagent)", which the plugin does not parse. Not seen against a run.
