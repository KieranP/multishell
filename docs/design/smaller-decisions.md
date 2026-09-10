# Smaller decisions

One line each, too small for a section of their own.
Newest at the bottom.

- Sessions warm up when visited, a saved workspace implying dozens of shells at
  launch. Selecting a worktree opens a terminal unless told not to; a create is
  asked about separately, a worktree asked for and a worktree looked at not
  being the same event. Cost: four settings where there were two.
- Engines coexist, "next launch" being a poor answer to an engine change. Cost:
  two renderers the theme conversion must keep identical, and a command reaches
  libghostty as one quoted line but SwiftTerm as an array. Both behind a
  protocol with a recording fake, which is how they are tested without a
  terminal.
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
- Debug builds keep their own state file, socket and integration directory, so
  `make run` beside the installed app touches neither.
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
  palette carries close to four hundred. Still keyboard-drivable, and its search
  covers a word for what each symbol is used for as well as its name, an SF
  Symbol being named for its picture rather than for a database or a git branch.
  Emoji, which a field beside the menu once set, are gone: they looked out of
  place, and a glyph is now a symbol name or nothing, one rule read the same way
  everywhere, so a leftover emoji neither masks the icon a repo's shared file
  names nor is written back into it. Cost: a project that had one draws the
  folder. What a new name must satisfy is in `docs/develop/adding.md`.
- One WorktreeActions menu serves the detail header, the sidebar's context menu
  and a board card's, the last under a heading naming the worktree, since the
  card carries a Clear Status of its own for the pane and two unlabelled ones
  would read as the same thing. A terminal editor opens as a tab, one run in the
  background failing silently with no tty; cost: a relaunch reopens the editor.
- New Worktree always opens, even with nothing selected, and its decisions are a
  tested value because a cancelled branch load once re-enabled Create against
  the wrong project. Its branch picker offers local branches only.
