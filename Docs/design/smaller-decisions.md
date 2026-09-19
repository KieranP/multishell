# Smaller decisions

One line each, too small for a section of their own. Newest at the bottom.

- Sessions warm up when visited, a saved workspace implying dozens of shells at
  launch. Selecting a worktree opens a terminal unless told not to; a create is
  asked about separately, a worktree asked for and a worktree looked at not
  being the same event. Cost: four settings where there were two.
- Ghostty keybinds unbound by name, not `keybind = clear`, which also removes
  alt+arrow word movement and super+backspace. Names and menu items come from
  one AppShortcuts table, a shortcut in only one list having been a keystroke
  that worked everywhere but a pane. Clipboard ones stay bound: in a pane Cmd+C
  is Ghostty's copy of the terminal's selection, and unbinding it hands the
  keystroke to a menu item with nothing to copy.
- Paths are directory URLs always: a relative worktree path resolved against a
  URL Foundation took for a file lands in the parent.
- Errors mapped, not stringified: the alert is the only place a user learns why
  something failed -> it gets git's own words.
- Project settings hosts `NSTabViewController` in `.toolbar` style, which
  SwiftUI gives only to the `Settings` scene, and asks about removing a project
  in that window, else the dialog would be behind it.
- Help behind an (i): captions doubled every form's height and were read once. A
  caption is left only for a value computed live.
- Notifications are for reports, not bells, and nothing under ten seconds: `ls`
  is not news, a build is. A bell in a background tab is a dot.
- Which states raise a banner = three toggles on a tab of their own, not one
  picker with a rung per combination. The picker offered three of the eight
  answers and could not say "only when something failed", which is the whole of
  what some people want; a rung per combination is a menu nobody reads. Cost: a
  state file written by this build reads as off on a build with the picker, the
  settings being an object where a name was. One caption at the foot of the page
  holds whichever toggles are on, where three (i) buttons said it three times.
- Permission asked as a toggle goes on, not at the first report: the dialog
  arrives while the user is looking at the thing it is about, and a refusal can
  be answered where it is read, the caption becoming where to lift it. Asking on
  the way down is a question about something just refused. The answer is runtime
  state, re-read as the page opens and as the app returns to the front, that
  being the way back from the settings the caption points at. No desktop named
  in the core: where to lift a refusal comes from `Platform`, and one that never
  asks answers `unavailable`, which keeps the page from promising a dialog
  nobody will see.
- Debug builds keep their own state file, socket, integration and drops
  directories, so `make run` beside the installed app touches none of them.
- The app package names its path dependency rather than only pointing at it.
  SwiftPM identifies a local package by its directory, which is `multishell` in
  a checkout and the branch's name in a worktree -> the unnamed form built from
  the checkout alone. Cost: the name is written twice, in the dependency and in
  the directory it usually matches.
- Terminal font is picked, not typed, some programming fonts not being marked
  fixed-pitch. A project icon is tinted from a theme slot rather than a hex, so
  a theme change keeps it in step with the terminal.
- Project icon picked from a grouped palette read by shape, not a popup menu of
  names read line by line: the menu is what held the list to sixty, where the
  palette carries close to four hundred. Still keyboard-drivable. It had a
  search over English words for what each symbol is used for, an SF Symbol being
  named for its picture; taken out rather than translated, since it made every
  other language search words it could not see, for a palette small enough to
  read by eye. Emoji, which a field beside the menu once set, are gone: they
  looked out of place, and a glyph is now a symbol name or nothing, one rule
  read the same way everywhere, so a leftover emoji neither masks the icon a
  repo's shared file names nor is written back into it. Cost: a project that had
  one draws the folder. What a new name must satisfy is in
  `Docs/develop/adding.md`.
- One WorktreeActions menu serves the detail header, the sidebar's context menu
  and a board card's, the last under a heading naming the worktree, since the
  card carries a Clear Status of its own for the pane and two unlabelled ones
  would read as the same thing. A terminal editor opens as a tab, one run in the
  background failing silently with no tty; cost: a relaunch reopens the editor.
  That background launch captures nothing and is never timed out: a shim can
  hold the editor open for as long as the file is, so a bound would end the
  editor the user just asked for, and pipes held alongside it were two
  descriptors per click for the life of the app.
- New Worktree always opens, even with nothing selected, and its decisions are a
  tested value because a cancelled branch load once re-enabled Create against
  the wrong project. Its branch picker offers local branches only.
- One banner per pane, replaced rather than added to: a request carries the
  state key as its notification identifier, so a terminal holds one row in
  Notification Centre saying what its dot says. Stacking four reports about one
  pane described the same pane four times, three of them wrong by the time they
  were read. The `identifier` and not `threadIdentifier`, which groups rows
  without retiring stale ones. A banner is also taken back when what it said
  stops being true: the key's state moving on, or the user reaching the pane.
  Waiting survives being looked at, its question still standing, but the
  interruption has been answered by the arrival. Reaching it is `isSeen`, the
  pane on screen and the app in front, the only notion of seen there is:
  `shouldNotify` once took a shown flag and an active flag and the state rules
  took the shown one alone, so a turn ending in the shown pane while the user
  was in another app raised a banner and cleared the dot in the same breath,
  each right by its own rule. One flag, computed once per report. Coming back to
  the app is therefore a look, alongside selecting, activating and closing the
  board; a shell exiting while the user is elsewhere is not. Taking back removes
  the pending request as well as the delivered one, `add` delivering a moment
  after it returns, in which a look landed and the banner then arrived with
  nothing left to retract it. Only Done clears on the look: Failed keeps its
  dot, so the banner and the dot say different things about one pane on purpose,
  the interruption spent and the thing to deal with still there. The model keeps
  the keys it has posted about, so nothing is taken back that was never there.
  Cost: a Done nobody looked at disappears when the next state lands, the dot
  being the thing that persists.
- One terminal engine, libghostty, embedded and named outright by `AppModel`. It
  owns the pty, the renderer and the config, so the core never sees a descriptor
  and a pane's surface is Metal-backed. Nothing chooses it and no setting offers
  an alternative. Cost: a pinned build that misbehaves has nothing to fall back
  to, the unfocused fade is a scrim rather than `.opacity`, and nothing tests
  the host against a real shell, the surface needing a window and a GPU
  (known-gaps.md).
- The sidebar filter is folded behind a magnifying glass in the sidebar header,
  next to the folder-plus. It was a field standing open above the project list,
  costing a row of height in every session to a control reached in few of them.
  Closing it clears the text, so rows are never missing with nothing on screen
  saying why, and Escape in the field closes rather than just empties. Closing
  hands the keyboard to the active pane through `focusActivePane`: the focused
  field leaving would otherwise drop first responder to the window, and typing
  would reach nothing. Cost: the filter is one click further away, and with no
  keyboard route to it (known-gaps.md) the mouse is the only way in.
- A worktree's dot is the most urgent state among its tabs, and a project's
  among its worktrees, in the order failed, waiting, working, done, idle. Failed
  above waiting, where it was below: a question answered still leaves the
  failure, so a row with a failed tab is red whatever the others ask. Done needs
  one finished tab, not all of them: one you have not looked at is the point of
  the dot. Idle only when every tab is. A report naming only a directory, from a
  terminal outside the app, is one more state in the worktree's set.
- Install Command Line Tool is the one thing run as root,
  `do shell script ... with administrator privileges`. The two paths go in as
  Apple event parameters to a handler in a constant script, never interpolated
  into it, and the script quotes them for the shell with AppleScript's own
  `quoted form of` (`AppleScriptHandler`). Interpolating and escaping by hand
  was the earlier shape and it escaped for `sh`, not for AppleScript, so a `"`
  in the home path ended the literal and ran the rest as root (BUGS 125). Costs:
  three four-char codes Swift does not import, and the OSA components are
  main-actor only.
- The terminal host is told the app is quitting, through `TerminalHost.shutDown`
  with a default no-op, and that it holds the instance socket, through
  `claimSharedFiles`. libghostty's generated config directory is shared by every
  copy of the build, so only the copy that claimed sweeps it, on the claim and
  again at quit (BUGS 124). "Built a controller" was the earlier test and did
  not hold: a copy that handed over keeps its terminals until it quits, so it
  builds one too. The controller is still built on first use rather than in
  `init`, `apply` holding the theme until there is one.
