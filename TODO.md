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
- Two instances share one state file. A debug build from `make run` and the
  installed release both use the same bundle identifier and the same
  `state.json`, and each autosaves, so the last writer wins and the other's
  changes are lost. Detect a second instance (the socket bind failing is the
  natural signal) and either activate the first or refuse to start, and give
  debug builds their own state directory through an environment variable so
  developing the app does not clobber the copy in use.
- A README for people who install it, not people who build it: download,
  first launch past Gatekeeper, add a project, the hooks setup, where state
  lives. The current one starts at `xcode-select`.

### 2. The reason to use it instead of a terminal and a script

- Session state from hooks, with the amber and blue dots and a notification
  for a background tab.
- Preferred agent, global and per project, and auto-start.
- Terminals view with the next-waiting shortcut.
- Verify before building on it: whether libghostty's shell integration is
  active in this embedding. Ghostty's command-finished callback needs it,
  and if the resource bundle does not inject it, plain shells never report
  Done and the state feature rests on hooks alone.

### 3. After shipping

Custom icons, the actions menu and preferred editor, pre hooks and the
multi-line editors, accessibility labels, a Linux GUI, and the rest of the
Gaps section.

## Features

### Session state from what runs inside a terminal

The dot today is one bit per session, "activity you have not seen", raised by
a bell, a title change or Ghostty's command-finished callback, and cleared
when the tab is shown. Nothing distinguishes running from finished from
waiting for input, and nothing outside the engine can raise it. The first
customer is Claude Code's hooks: PreToolUse for running, Stop for finished,
Notification for needs input. The same channel serves a test runner, a long
build, or `npm run dev` reporting ready.

Missing pieces:

- An inbound channel. A small `multishell` command-line helper talking over a
  Unix socket in the state directory, or a URL scheme the hook opens. The
  socket does not activate the app, so prefer it.
- Session identity in the terminal's environment. Both hosts start the shell
  with no extra environment: SwiftTerm passes `environment: nil` and the
  Ghostty options carry only directory and command. Export a session id and
  the worktree path so a hook can name its tab. Claude's hook payload carries
  `cwd`, so worktree-level dots work without this; tab-level dots need it.
- A state per session, not a flag. `unseenActivity` becomes an enum such as
  idle, running, attention, kept in `AppModel` as runtime state, fed through
  a new port beside `TerminalHost`. Tab bar and sidebar rows draw amber for
  running and blue for attention. The same state can post a macOS
  notification for a background tab.
- Who clears what. Done is about the user and clears when the tab is shown,
  as the dot does today. Attention is about the agent and clears when the
  source reports running again, not when the user looks: a question the
  user has seen but not answered is still waiting. Running clears on the
  next report or on process exit. Extend `AppModelInvariantTests` so the
  state keys stay a subset of the live sessions.
- Colour clash. The sidebar's dirty-files dot is already the theme's yellow
  (slot 3), so an amber running dot beside it would read as two of the same
  thing. Either pick the running colour from another slot, give the state
  dot a different shape or position, or move the dirty count off a dot.
  Decide before drawing.
- Installing the hooks. Claude reads hooks from `~/.claude/settings.json` or
  a project's `.claude/settings.json`. The app should not edit those files
  silently. Offer a "Set up Claude Code hooks" button in settings that shows
  the JSON to add and can write it to the user file on request, and a
  matching subcommand on the helper. The hook lines must find the helper: it
  ships inside the bundle, and an absolute path there breaks when the app
  moves, so keep a symlink at a stable path under the state directory,
  refreshed at launch, and reference that. For people writing their own
  hooks for other tools, an "Install command line tool" action that links
  it into `/usr/local/bin` with an admin prompt, the way editors do.
- Trust. The socket is a file the user owns, mode 0600, and the messages it
  accepts change a dot and nothing else: no opening tabs, no running
  commands. Keep it that way until there is a reason not to. A message with
  a session id the app does not know is dropped; one with only a `cwd` that
  matches a worktree updates the worktree, so a hook fired from Terminal.app
  in that directory shows up too.
- Notifications need `UNUserNotificationCenter` authorisation, asked for on
  first use, and a setting to turn them off, with the option of only
  Waiting rather than Waiting and Done.
- SwiftTerm has no shell integration and swallows the bell, so under that
  engine hooks are the only source of any state. Say so in the settings
  caption for the engine.
- Stale Running. An agent that crashes, or is killed with Ctrl+C, sends no
  Stop hook, so its tab stays amber. The app cannot see the agent exit: it
  is the shell's child, not the session's process. Mitigations, in order:
  Ghostty's command-finished callback clears Running where shell integration
  is active; the helper reports the agent's pid on Running and the app polls
  it with `kill(pid, 0)` while any session is amber; and clicking the dot
  clears it by hand. Do not add a timeout: a long task is not a stale one.
- Protocol. JSON lines over the socket with a version field, so a helper left
  behind by an older install keeps working against a newer app. Unlink a
  stale socket file from a crashed instance at launch before binding.
- Closing a Working tab. Cmd+W on a session whose agent is running should
  ask first, the way worktree removal does, and the quit guard's message
  should count working agents separately from plain shells.
- Tests. An end-to-end test that spawns the real helper binary against a
  temporary socket and checks the session's state changes, alongside the
  fake-engine tests for the clearing rules.

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

### One login-shell environment, shared

Hooks already run through the user's interactive login shell to get a
terminal's `PATH`. Agent detection, editor detection, agent tabs and
terminal-editor tabs all need the same environment, so resolve it once: at
launch, off the main thread, run the login shell and capture its environment
(`env -0`, not only `PATH`, so `NVM_DIR` and friends come too), cache it in
`AppModel`, and expose a Refresh that the two dropdowns share. Every consumer
in this file reads from that one value rather than shelling out again. A
shell that fails to start or takes more than a few seconds falls back to the
process environment with a note in the log.

### Preferred agent, global and per project

- Detection. `ExecutableLookup` walks the process's `PATH`, which from the
  Finder is the system directories only. Every agent people install
  (`claude`, `codex`, `gemini`, `aider`, `opencode`, `cursor-agent`) lives
  under Homebrew, npm or a version manager, so that lookup finds nothing.
  Ask the user's interactive login shell for its `PATH` once at launch, off
  the main thread, cache it, and look agents up there. Hand the same `PATH`
  to the agent tab.
- Where it lives. Global value on the workspace, optional override on
  `ProjectSettings`, `nil` meaning follow the global, the pattern
  `worktreeDirectory` and `branchPrefix` already use. Not in
  `WorktreeSettings`, which is about paths. Store the agent id as a string so
  a newer build's agent loads harmlessly on an older one.
- Catalogue. A static table in the core: id, display name, executable name,
  launch arguments, resume arguments where the agent has them. Plus a custom
  entry where the user types a command.
- Dropdown. Lists detected agents, "None", and a Refresh. The stored value
  can name an agent no longer installed; a SwiftUI picker whose selection is
  not in its list shows blank, so include it marked "not installed".
- Actions. New Agent Tab with a shortcut, a button in the detail header, and
  the auto-start toggle below. Tie-in: the preferred agent tells the session
  state feature which hook format to install.
- Tests. Detection against a temporary directory of fake executables on a
  fake `PATH`, the way `FakeGit` stands in for git. Global versus override in
  `ProjectSettingsTests`. A decoding case for an unknown agent id.

### Auto-start preferred agent

Triggers: selecting a worktree with no tabs (which is what follows a create)
and New Tab. Both end in the store's open-tab call, which already takes a
command.

- Record the agent id on the session, not the command line. Build the
  command when the tab opens, from the setting in force and the resolved
  `PATH`. A changed preference or a newly installed agent applies to the next
  tab without touching saved state.
- Relaunch. Saved tabs come back as fresh shells on first visit. With a raw
  command, four saved agent tabs would start four agent sessions at once.
  With the id, resume where the catalogue knows how (Claude's `--continue`),
  otherwise a plain shell with the tab title kept. Make it a setting if
  anyone objects.
- A plain shell must stay reachable. Splits stay plain shells. New Tab gets a
  sibling: Cmd+T for the agent, Cmd+Shift+T for a shell, or a modifier.
- When the agent quits the tab would close with its scrollback. Launch as
  `agent; exec $SHELL` through the login shell so a shell remains.
- Title. The default title is the command's name, which after the wrapper
  reads `zsh`. A session with an agent id takes the agent's display name
  until the shell reports one.
- Ordering with hooks. The post-create hook finishes before the worktree
  appears, so the agent starts after `npm install`. A failing hook still
  selects, so the agent starts with the hook's alert on top.
- A preferred agent no longer on `PATH` falls back to a plain shell and
  reports once, like an unreachable project.
- Tests with the fake engine: New Tab carries the agent id when auto-start
  is on, the first tab after select does too, a split does not, the project
  override beats the global, a missing agent yields a plain shell plus one
  alert. Extend the relaunch test with the resume case. A decoding case for
  the field.

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

- State mapping. The runtime enum has idle, running and attention. Working
  is running, Waiting is attention (needs input), Done is finished since the
  tab was last shown. Decide whether a plain idle shell that has never
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
  variables or default shell. The store can open a tab running a command but
  no UI reaches it (the agent features above are the first to).
- Terminal: no find, no notifications, font chosen by typed name, SwiftTerm
  sessions never raise activity because the view swallows the bell.
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
