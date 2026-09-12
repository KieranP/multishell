# Known gaps

What is unverified or unbuilt, with the fallback where there is one. A gap
whose behaviour is settled goes under Known issues; one that nobody has
watched happen goes under Unconfirmed behaviour, and moves up when someone
does.

## Known issues

- Release bundle runs only on the machine that built it: libghostty finds its
  terminfo through `Bundle.module`, which looks at the app root then an
  absolute path inside `Apps/macOS/.build`, never `Contents/Resources`, so
  elsewhere `TerminalController()` traps on the first terminal. Fix = build
  with Xcode or a patched libghostty-spm. Same path is why a bundle installed
  from a worktree stops working once that worktree is removed: install from
  the checkout, or rebuild after removal.
- Agent settings is the one page nothing holds: its `onAppear` refresh reads
  the machine, so the page is as tall as whatever is installed and a test
  would be measuring a laptop. Measured headlessly with the refresh taken
  out, it is 260pt with no agent's hooks installed, 357 with one, 481.5 with
  four and 550.5 with all five, so the 600pt window now covers every case
  this developer can produce. A sixth supported agent would put it over
  again, and nothing would say so; fix then = the hooks rows want their own
  scroll.
- Project settings' Hooks tab wants 973pt in a 600pt window, so its last
  editors are below the fold with nothing saying so. Six monospaced editors
  were never going to fit a window the other pages can share, and
  SettingsPageSizeTests records this one as deliberate so the next page to
  overflow is not lost in it. Every other page fits, Project General closest
  at 581.5.
- Directory check before a click starts a shell runs on the main thread, so a
  network volume that has gone away blocks until the mount times out. Polling
  paths' checks run off it.
- A file list a new worktree is given has no timeout, unlike a hook: runs
  until done or the pane's Cancel, which lands between paths.
- A scrolled tab strip does not auto-scroll while a tab is dragged near its
  end, so a tab cannot be dragged past the visible tabs: reordering reaches
  only what is on screen, and a tab off the end cannot be dropped on.
  Auto-scroll needs the drop's own pointer position, a repeating step, and the
  strip's `ScrollViewProxy` reaching the drop delegate.
- A tab drag released where nothing takes it, outside the window or over a
  part of the sidebar that is not a worktree row, never ends: `.onDrag` has no
  cancellation callback, and only a drop clears `AppModel.tabDrag`. The five
  drop paths do clear it, the sidebar row included, so what is left is the
  abandoned drag. `TabDragState.isDragging` then stays true and every column
  keeps `TabGroupBands` mounted over its pane: the bands stay hidden, being
  drawn from `overColumn` and `band` which the pointer leaving does clear, so
  the cost is a `Color.clear` drop target and its accessibility label over the
  terminal area until the next drag begins, which resets the state. Not seen
  on screen. Fix would want a gesture that reports its own end.
- While the Agents board is up, what acts on a pane does nothing, but Open in
  Editor and New Worktree still act on the selected worktree, and no sidebar
  row draws as selected then, so those two have nothing on screen naming their
  subject. Left because neither is destructive; fix = route them through
  `worktreeInView` as the pane commands are.
- Sidebar keyboard navigation and a shortcut to focus the filter are not
  built. No view tests, and the accessibility labels have not been read with
  VoiceOver.
- Existing-branch picker lists local branches only, so a remote-only branch is
  created as a new one based on its remote. A decision, not a defect.
- `.multishell.json` is read from the project path, which for a bare
  repository holds no checkout.
- The placeholders an agent's flags may use are documented nowhere a user can
  reach: the settings rows name `{{branch}}` as an example, and the rest live
  in `AgentPlaceholder` waiting for a documentation site.

- The app ships English only, so nothing has been seen in another language:
  what is unproven is not the lookup, which TranslationTests and a read out
  of a built bundle both cover, but the layouts. Several settings pages
  already fit their fixed window with little to spare, and a language that
  runs thirty per cent longer than English would be the thing that overflows
  them; SettingsPageSizeTests measures English. The sidebar rows, the tab
  strip and the board columns all size themselves off measured text, so
  those should give rather than clip.
- A number inside a phrase is written the way Swift writes one, no locale:
  the board's one decimal reads `0.4s` in a language that would write a
  comma. Deliberate, since the alternative makes every test of it read the
  machine's region; fix if it grates = a locale in `t(_:_:)` and
  those tests pinned to one.
- A tab's title is a persisted field, and a plain shell's starts as the
  translated word for Shell, so tabs made before a language change keep the
  old one. It corrects itself under zsh and bash, whose integration
  retitles the tab on the next command; under SwiftTerm with another shell
  it stays until the tab is closed. Fix if it matters = store the default
  as absent and translate it where it is drawn, which is a change to a
  persisted field.
- A git older than 2.36 cannot list worktrees at all now, `-z` being unknown
  to it there. Nothing checks the version or falls back to the plain
  porcelain: the read fails, the row says so and names the option. Left
  because the supported macOS ships 2.39 and the call site is one line either
  way; fix if it bites = retry without `-z` on that one failure.
- A tag named exactly like a local trunk still decides the base: the worktree's
  branch goes to git as a refname now, the base does not, `DefaultBranch.ref`
  being the short print form. Every merge read for that project would then be
  measured against the tag. Unlikely enough to leave: a remote-tracking base
  cannot tie with a tag, so it needs a repository whose default resolves to a
  local `main` with a `main` tag beside it.
- A hook group holding one of our commands as a bare `command` beside a
  `hooks` array of the user's keeps our command after Remove, which reads as
  Remove not working. No agent writes that shape and Add never produces it, so
  it is reachable only by hand-editing; the two shapes are handled separately
  and the bare one is taken as ours whole.
- Saving is off for the whole session once state is found unreadable and
  unmovable, and the check is made once at restore. Permissions fixed while the
  app runs are not noticed until relaunch, and the session's work goes at quit
  with only the launch alert having said so.
- `MultiEngineHost` records ownership before the open, so an engine changed
  between a failed open and the retry leaves the first engine's surface
  unreachable by `close`. Neither shipping host throws from `open`, so only
  `RecordingEngine.failNextOpen` reaches it; which of the two leaks is wanted
  was read both ways by two reviewers and is unsettled.

## Unconfirmed behaviour

- Ghostty engine's path untested, its zsh chain checked only against a
  stand-in bootstrap. Click-to-move works there and nowhere else, and not on
  the later lines of a multi-line buffer.
- The user's Ghostty config is read and handed to libghostty as the base
  config, but only the text that is sent has been tested, and against
  libghostty rather than a surface: whether a font, keybind or cursor from it
  changes what is on screen is unseen. What was checked is that libghostty
  accepts it, every key of a Ghostty 1.3.2 default config having been offered
  to the pinned build one line at a time. Three limits. Nothing tells a user
  which of their lines did not count, and there are two ways for a line to go
  quietly now: a key outside `GhosttyUserConfig`'s allowed list, and a line
  `repair` dropped because libghostty complained. Fix = the dropped lines
  named in Settings, where a theme file that will not parse is already
  reported. The files are read once, when the engine's host is created, so an
  edit lands at the next launch and nothing says that either. And a
  `config-file` line is not followed: the wrapper loads with
  `ghostty_config_load_file` and never calls
  `ghostty_config_load_recursive_files`, which is the call that expands one,
  so a user who splits their config keeps the two files read here and loses
  every part those include; the key is not on the allowed list either, which
  at least keeps it out of the text libghostty is handed.
  Any other relative path in the file resolves from the temporary directory
  the effective config is written to rather than from the file's own.
- Whether SwiftUI calls `updateNSView` when every stored value of the view
  compares equal is unseen, so how often the focus guard in `SurfaceView` was
  actually firing is unknown. The guard is right either way and costs nothing;
  what a screen would settle is whether the keyboard was being pulled out of
  the sidebar filter in practice or only in principle.
- Linux never compiled, locally or in CI. The counted phrases are the part
  of the catalogue to look at first when it is: `Localizable.strings` is
  plain enough that corelibs-foundation reads it, and whether its
  `NSLocalizedString` applies a `.stringsdict` plural rule at all is
  unchecked. If it does not, every counted phrase answers with its own key
  and the number is dropped; the fallback is to build those few forms by
  hand where they are read, which is where they came from before the
  catalogue had them.
- Notifications settings page never seen on screen: the toggles, the caption
  under them, the six-tab band in a 560pt window. SettingsPageSizeTests holds
  this page's height under the window's own, so what is left is how it reads
  rather than whether it runs off the bottom. The band is measurable by
  nothing, SwiftUI drawing it outside the AppKit hierarchy; if it clips, raise
  the width in SettingsView. Caption and the help behind each (i) are strings
  in NotificationSettings.
- The 600pt settings window has not been seen on screen. It is the height
  the tallest page needs, so General shows 159pt of rows above 441pt of
  nothing, and whether that reads as roomy or as broken is a question for
  the screen. Fix if it reads badly = the tall pages scroll and the window
  goes back to about 480.
- Drops reach SurfaceFrame because AppKit walks up from an unregistered engine
  surface to the frame that is registered: documented for the registration,
  undocumented for the search order, so if either engine ever registers a
  dragged type the frame stops seeing drops. Checked only by hand. Same walk
  carries a dragged tab past a surface to the SwiftUI band over it,
  SurfaceFrame being registered for files and promises and not for
  `io.multishell.tab`; if a band never lights, fallback = register the tab
  type on the frame and answer it there. Every column's tab strip takes a tab,
  and the sidebar's worktree rows do; nothing else.
- Tab-group drawing unverified on screen: whether bands appear as a tab
  crosses a terminal area, whether the insertion line lands in the right
  strip, how an unfocused column reads, whether a strip's scroll arrows read
  as "more tabs this way" better than the fade they replaced. Store, model and
  wording tested; drawing not. Cost of drawing only from what the pointer is
  over: bands are not on screen until the tab reaches a terminal.
- Whether a SwiftUI overlay composites above an engine's surface is unverified
  for Ghostty, whose surface is Metal-backed: the focus ring has always been
  drawn that way, and now the unfocused-pane fade too. If neither appears,
  both are silent rather than wrong, and the fade would have to become a view
  inside SurfaceFrame the way its drop highlight is.
- Reordering inside one column happens as the pointer passes each tab, not on
  release; see TabShuffle and `AppModel.shuffleTab`. Unverified at the edges: a
  strip whose tabs differ widely in width could in principle move a tab back
  and forth across one boundary, the tab landing under the pointer being what
  stops that.
- Agents board drawing unverified on screen: whether a card reads at the 208pt
  column floor, where the worktree name and the git badge now share a line and
  the name is what gives way, whether a partial column at the edge reads as
  "more this way" without the arrows a tab strip has, whether a vertical
  scroll per column nested in the board's horizontal one feels right to a
  trackpad, whether the Dock badge appears at all under this build's signing.
  If the partial column does not read, fallback = the tab strip's: an arrow in
  a gutter at each end that has cards past it, from `TabStripLayout.Edges`.
  Two known divergences from the mockup: columns are full height rather than
  hugging their cards, which is what lets each scroll on its own; and the View
  menu item's position within that menu is AppKit's to decide, being added to
  the standard group.
- Neither agent-flags row has been seen on screen: the CLI Flags field under
  the agent picker in Settings > Agents, and the CLI Flags override in a
  project's Agent tab. The value they write and the command line it builds are
  tested; the rows' width, and how an empty one reads with no prompt text in
  it, are not.
- Claude's fourteen notification types were read out of the 2.1.268 binary's
  own list, not watched arriving on the hook, and which four only announce was
  decided from their names. What was checked is the helper's
  end: synthetic payloads through the built helper report `attention` for
  `permission_prompt`, `worker_permission_prompt` and a payload naming no
  type, and send nothing for `idle_prompt`, `agent_completed`, `auth_success`
  and `quota_auto_resume_fired`. Those four are the list, everything else
  counting as a question, so what a new type costs now is a banner too many
  rather than a prompt nobody is told about. Nothing says which way it went:
  an announcing type Claude adds later reads as waiting until someone
  notices and names it.
- Which type raised the banner that prompted the narrowing is unestablished.
  It followed the turn's Done by about ten seconds, and Claude's idle prompt
  is its own timer of sixty seconds from the turn ending
  (`messageIdleNotifThresholdMs`, unset in this user's config), so it was
  more likely a teammate's `agent_completed`. Both are dropped either way.
- Neither half of the banner grouping has been seen on screen, both being
  UserNotifications behaviour a headless test cannot reach. Unverified: that
  re-adding a request under a delivered notification's identifier replaces
  its row and alerts again rather than being dropped as a duplicate, and that
  `removeDeliveredNotifications` takes down a banner still on screen rather
  than only its row in Notification Centre. If the second turns out to only
  clear the Centre, a stale "Waiting for input" still sits on screen for its
  few seconds after the user has reached the pane, and there is no API for
  that; the row behind it is the part that would have lingered for hours.
  What is tested is the model's half: which key is posted about, which is
  taken back, that a key is taken back once rather than on every report
  after, that being away from the app is not being shown the banner, and
  that closing a tab takes its banner with it.
  One hole left in the notifier: a withdrawal between the moment a waiting
  request is taken out of `pendingAdds` and the `add` that follows it lands
  a banner nothing will retract. Microseconds wide, and only on the path
  where the permission dialog has not been answered yet.
