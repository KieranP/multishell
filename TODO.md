# TODO

What is missing, and the shape of the features under discussion. Decisions
that get made move to DESIGN.md; this file is the queue.

## MVP

What has to be true before someone else can install this and use it all
day. Three tiers; ship after the first two.

### 1. It installs and does not lose work

- Signed and notarised build. Without a Developer ID and notarisation,
  Gatekeeper refuses the download on every machine but the author's.
  Notarisation needs the hardened runtime; check whether libghostty needs
  any entitlement under it before assuming a clean pass.
- A release workflow that produces a versioned DMG or zip from a tag, with
  the version taken from the tag rather than the `0.1.0` in `make-app.sh`.
  An update check, Sparkle or a plain "a newer version exists" link, so the
  first bug fix reaches people.
- Bare repositories (Gaps, below).
- Remove Project confirmation (Gaps, below).
- A hook timeout. A hook that never exits blocks the sheet forever; a
  configurable limit, a minute by default, with the hook killed and reported.
- "Remove Anyway" deletes uncommitted work for good. The forced removal is
  `git worktree remove --force`, which unlinks the directory. When the status
  badge says the worktree is dirty, move the directory to the Trash with
  `NSFileManager.trashItem` first and run `git worktree prune`, which is the
  path already used for a directory that is gone. The confirmation then says
  "moved to the Trash" instead of "will be lost". Same cost, one fewer way
  to lose an afternoon.
- Status polling on a monorepo. `git status` on a very large checkout takes
  seconds, and eight of them every five seconds while the app is frontmost
  keeps the disk busy. A per-project toggle to turn status polling off, or a
  longer interval, with the badge hidden rather than stale.
- Logging through `os.Logger` for process runs, hook runs, refreshes and
  decode failures, so a report can be traced. A Help menu with links to the
  repository and issue tracker, and a "Copy diagnostics" that gathers the
  app version, macOS version, git version, engine and recent log lines.
- Keyboard for the things a terminal user does all day: Cmd+1 to 9 for tabs,
  a pair for next and previous worktree, arrows with a modifier for focus
  between split panes, and a shortcut to the sidebar filter. Each one also
  goes in `GhosttyTerminalHost.appShortcuts`.
- Tab overflow. Twelve tabs in one worktree shrink to icons; scroll the
  strip or collapse the inactive ones.
- Two release instances share one state file. Debug builds now keep their
  own `state.debug.json`, socket and integration files, so `make run` beside
  the installed copy is safe; two copies of the same build still both
  autosave and the last writer wins. The second one already learns of the
  first when its socket bind is refused; make it activate the first or
  refuse to start rather than only saying so.
- A README for people who install it, not people who build it: download,
  first launch past Gatekeeper, add a project, the hooks setup, where state
  lives. The current one starts at `xcode-select`.

### 2. The reason to use it instead of a terminal and a script

- Session state, the preferred agent, New Agent Tab and auto-start are done.
- Terminals view with the next-waiting shortcut.
- Verify whether libghostty's shell integration is active in this
  embedding. Ghostty's command-finished callback needs it; it is what clears
  a Working dot when the agent exits at the prompt, and if the resource
  bundle does not inject it, plain shells never report Done and stale
  Working rests on the pid check alone.
- The pid a hook reports is the first non-shell ancestor of the helper.
  Confirm against a real Claude Code session that this is Claude and not a
  wrapper of its own that outlives the hook.

### 3. After shipping

Custom icons, the actions menu and preferred editor, pre hooks and the
multi-line editors, accessibility labels, a Linux GUI, and the rest of the
Gaps section.

## Features

### Custom project icons

The sidebar row draws a fixed `folder` symbol, swapped for
`folder.badge.questionmark` when the project is unreachable. The detail
header shows the name with no icon.

- A field on `ProjectSettings`: a string for the glyph and an optional tint.
  The core is Foundation-only, so it stores a description, not an image.
  Decodes with a default; add a case to `DecodingDefaultsTests`.
- Glyph source: emoji first (one string, every platform, the character
  palette is the picker), SF Symbol name second (Mac-only, needs a curated
  list since SwiftUI has no public symbol picker). Image files mean an
  `icons/` folder beside `state.json`, resizing and cleanup on removal; leave
  them out of the first version.
- Tint as an index into the theme's sixteen ANSI colours, not a hex, so a
  later theme change does not clash. The branch name already uses slot 6 and
  the dirty dot slot 3.
- Draw it in the sidebar row, the detail header and the New Worktree project
  picker, where same-named projects are told apart by path today.
- Missing state becomes a dimmed icon plus a small badge, so the user's
  choice survives an unmounted drive.
- Settings UI in Project Settings > General through the existing `setting`
  binding helper.
- Deriving an icon from project files (`package.json`, `Package.swift`) is
  tempting but adds a filesystem read per project and a taxonomy. Explicit
  choice, folder by default.

### Project hooks: pre-create, pre-delete, multi-line editors

Today there are two hooks, post-create and post-delete, each a one-line
`TextField` with a vertical axis. Return submits the field rather than
adding a line, so a multi-step hook has to be chained with `&&`.

- Two more stages. Pre-create runs in the repository before
  `git worktree add`, with `MULTISHELL_WORKTREE_PATH` set to the planned
  path. Pre-delete runs in the worktree before `git worktree remove`, after
  the confirmation dialog. The contract, by exit code: a pre hook that exits
  non-zero stops the operation, and git is never asked; a post hook that
  exits non-zero, or cannot be started at all, raises an alert with its
  stderr, and the git operation stands. That is what a pre hook is for
  (refuse a create without a ticket number, refuse a delete with unpushed
  commits, stop a dev server first). `HookFailure.Stage` gains the two
  cases and `PresentedError` gets titles that say the operation did not
  happen, distinct from the post-hook titles that say it did.
- Multi-line. Each hook becomes a `TextEditor` in a monospaced font, a few
  lines tall, run as one script through the login shell. Decide what a
  failing line does: the shell runs on past it by default, so either prepend
  `set -e` so the first failure stops the script and is the one reported, or
  say in the caption that it does not. Stopping is the less surprising.
- Layout. Four editors plus the environment table outgrow the fixed
  560 by 400 window. Group as Create (pre, post) and Delete (pre, post) with
  a caption under each naming its working directory and whether a failure
  aborts, and let the form scroll or the window grow.
- Persistence. Two new strings on `ProjectSettings`, default empty, with
  cases in `DecodingDefaultsTests`.
- Timeout. The open decision that a hook which never exits blocks the sheet
  gets worse with pre hooks, which now block the operation itself. Worth
  settling at the same time.
- Tests on `RepositoryFixture`: a failing pre-create leaves no worktree and
  no branch; a failing pre-delete leaves the worktree; a multi-line hook runs
  its lines in order in the right directory; a failing middle line stops the
  rest.

### Terminals view

Every open terminal in one list, grouped as Waiting, Working and Done, so a
person running agents in several worktrees can see which one wants them
without visiting each. Depends on the session state feature above; without
it the list has nothing to group by.

- State mapping. The runtime enum has running, attention, done and error.
  Working is running, Waiting is attention (needs input), Done is done or
  error since the tab was last shown, with Failed marked in the row. Decide whether a plain idle shell that has never
  reported anything appears at all; leaving it out keeps the list to what
  matters, showing it under Done makes the list complete. Start with leaving
  it out and a "show all" toggle if that is wrong.
- Where it lives. One window, and a surface is one NSView that cannot appear
  in two places, so the view is a list, not thumbnails. Put an entry at the
  top of the sidebar above Projects, with per-state counts on it; selecting
  it shows the list in the detail area where a worktree's tabs would be.
  The selection is a runtime flag in `AppModel` cleared when a worktree is
  selected, not a change to the persisted `selectedWorktreeID`.
- Rows. Tab title (the shell-reported one, which agents update with their
  status), project › worktree, state, time in that state. No last line of
  output: neither engine hands scrollback to the core. Sorted Waiting first,
  then Working, then Done, most recent change first within each.
- Actions. Clicking a row selects its worktree, activates its tab and focuses
  its pane, which is what a click in the sidebar plus a click on the tab
  does today, in one step. A "next waiting terminal" command with a shortcut
  is worth more than the view itself for keyboard users. Optionally the Dock
  badge shows the Waiting count.
- Testable value. Grouping, ordering and the elapsed-time text live in a
  plain value beside the view, the way `SidebarFilter` does, and are tested
  there. The view is not.

### Actions menu in the detail header, and a preferred editor

The detail header's right side holds only a `+` when the worktree has no
tabs. An actions menu there acts on the selected worktree: Open in Editor,
Reveal in Finder, Copy Path, Copy Branch, New Agent Tab, Remove Worktree.
Reveal and Copy Path exist in the worktree's context menu already; the menu
makes them discoverable. The same items belong in the sidebar context menu
and on a Terminals view row.

Open in Editor needs a preferred editor setting:

- Global, with the agent's dropdown behaviour: detected editors, "None", a
  Refresh, and a stored value that is no longer installed shown as such. The
  per-project override pattern is there if a project ever needs a different
  editor; start global.
- Detection differs from agents. Editors are mostly apps, not `PATH`
  binaries: VS Code, Cursor, Zed, Sublime Text, Xcode, Nova, BBEdit, the
  JetBrains IDEs. Find them by bundle identifier through `NSWorkspace`, plus
  the terminal editors (`nvim`, `emacs`) and CLI shims (`code`, `cursor`,
  `zed`, `subl`) on the login-shell `PATH`. The catalogue (id, name, bundle
  id, CLI name) lives in the core; the lookup by bundle id is Mac-only and
  goes in the app layer behind a port, since a Linux GUI would use
  `.desktop` entries.
- Opening. An app takes the worktree directory through `NSWorkspace`. A
  terminal editor opens as a new tab running it in the worktree, which is
  the agent-tab path with a different command. A custom entry takes a
  command template with `{path}`.
- Shortcut. Cmd+O is Add Project, so Open in Editor needs another, and any
  new app shortcut must also be added to `GhosttyTerminalHost.appShortcuts`
  or the surface consumes the keystroke before the menu sees it. That list is
  the non-obvious step for every shortcut in this file.
- Tests. Catalogue and command construction as plain values; detection
  against a fake lookup the way the agent detection is tested.

## Gaps

### Everyday

- A default shell, global and per project. Every tab runs `$SHELL`, and
  there is no way to pick another, so a bash project on a zsh Mac gets zsh.
  Detect the shells present (`/etc/shells` plus the login shell's PATH for
  zsh, bash, fish, nu), a global choice on the workspace with a `nil`
  override on `ProjectSettings` like the agent, and a dropdown in both
  settings windows marking a stored shell that is no longer installed. The
  hooks follow: `ShellLaunch` and `SessionEnvironment` already branch on the
  shell's name, so a chosen shell gets the same per-session integration as
  `$SHELL` does today, and a shell without one launches plainly.
- Three different `plus` icons. The sidebar header's Add Project, each
  project row's New Worktree, and the tab strip's New Tab all draw the same
  `plus` symbol, so the header button reads as "add something" until the
  tooltip appears. Give Add Project `folder.badge.plus`, which the New
  Worktree sheet already uses for its no-projects state, and keep the bare
  `plus` on the project row where the row itself is the context. The tab
  strip's `plus` sits among the tabs and is fine as it is.
- Remove Project asks nothing. The button in Project Settings > General and
  the sidebar context menu item both remove the project at once, closing
  every live terminal in its worktrees, with no undo. Worktree removal has
  the pattern already: a pending value on the model and a confirmation
  dialog that names what will be lost. Do the same for projects, with the
  live terminal count in the message and a note that nothing on disk is
  touched. The settings window is its own `Window`, so the dialog has to be
  presented there when the request comes from it, not only on the main
  window.
- Bare repositories are refused. `isRepository` runs
  `git rev-parse --is-inside-work-tree`, which prints `false` for a bare
  clone, and the error says there is no `.git` directory. The bare-clone-
  plus-worktrees layout is the common one for people with many worktrees.
- A moved repository is a new project. Identity is the path, so a project
  whose directory moves stays dimmed as missing and re-adding it at the new
  path loses its settings, hooks, icon and agent choice. Offer "Locate…" on
  a missing project's context menu that rebinds the existing project to the
  chosen directory, keeping its settings and dropping its saved worktrees for
  the next refresh to rediscover.
- No keyboard path through the sidebar or panes: next worktree, tab N, focus
  between split panes, focus the filter.
- Tabs and panes: no tab overflow, no swap or zoom of a pane, no moving a tab
  to another worktree, no close from a non-active tab.
- Worktree operations stop at create and remove: no open in editor, no fetch
  to refresh the remote list, no tracking checkout of a remote-only branch,
  no "delete the branch too" on removal, no view of merged branches that
  could go.
- Nothing per project shapes the terminal: no startup commands, environment
  variables or default shell. The store can open a tab running a command;
  only the agent tab reaches it.
- Terminal: no find, font chosen by typed name, SwiftTerm sessions never
  raise activity because the view swallows the bell.
- Project settings live on one machine. Hooks, the worktree path template
  and the agent choice are things a team would share. A `.multishell.json`
  in the repository, read as defaults under the user's own project settings,
  would carry them; hooks from a file in the repository run code on
  checkout, so they need a one-time "trust this repository's hooks" prompt
  the way editors do for workspace tasks.
- Files a new worktree needs that git does not carry: `.env`, local config,
  a `node_modules` symlink. A post-create hook can copy them today
  (`cp "$MULTISHELL_PROJECT_PATH/.env" .`), which is enough for now; a
  "copy into new worktrees" list in project settings is the friendlier form
  later.

### Shipping and platform

- Ad-hoc signing, hard-coded version 0.1.0, no Developer ID, notarisation,
  updater, release workflow or Homebrew cask.
- No logging anywhere, so a hung hook or a refused repository cannot be
  traced after the fact.
- No accessibility labels on the hand-drawn sidebar and tab bar.
- The Ghostty engine, the default, has no automated test. Linux and Windows
  have a core but no GUI and have not been built locally.
- Documented open decisions: a hook that never exits blocks the sheet; the
  directory check before a click runs on the main thread.
- Unverified: whether this embedding loads the user's own Ghostty config
  from `~/.config/ghostty`. If it does, a user's keybinds can undo the app's
  unbinds and their theme can fight the app's; if it does not, people with
  a tuned Ghostty lose it here. Either answer needs a line in DESIGN.md and
  probably a setting.
