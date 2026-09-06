# TODO

What is missing, and the shape of the features under discussion. Decisions
that get made move to DESIGN.md; this file is the queue.

## MVP

What has to be true before someone else can install this and use it all
day. Three tiers; ship after the first two.

### 1. It installs and does not lose work

- The bundle only works where it was built. libghostty locates its
  terminfo through SwiftPM's `Bundle.module`, which never looks in
  `Contents/Resources`; on another machine the first terminal traps. See
  Known gaps in DEVELOP.md. Building with Xcode, or a patched libghostty-spm
  that checks the main bundle's resources, fixes it; either has to land
  before anyone else installs this.
- Signed and notarised build. Without a Developer ID and notarisation,
  Gatekeeper refuses the download on every machine but the author's.
  Notarisation needs the hardened runtime; check whether libghostty needs
  any entitlement under it before assuming a clean pass.
- A release workflow that produces a versioned DMG or zip from a tag, with
  the version taken from the tag rather than the `0.1.0` in `make-app.sh`.
  An update check, Sparkle or a plain "a newer version exists" link, so the
  first bug fix reaches people.
- Bare repositories (Gaps, below).
- A hook timeout, or a Cancel on the pane. A pre-create hook that never
  exits blocks the sheet; any other hook that never exits leaves its
  worktree busy, with the pane showing the stage and no way to stop it
  short of a relaunch. A configurable limit, a minute by default, with the
  hook killed and reported, or a Cancel that kills it.
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

Accessibility labels, a Linux GUI, and the rest of the Gaps section.

## Features

* Translation support
* Add support for defining project config in config files

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
  does today, in one step. The row's context menu is `WorktreeActions`. A
  "next waiting terminal" command with a shortcut is worth more than the view
  itself for keyboard users. Optionally the Dock badge shows the Waiting
  count.
- Testable value. Grouping, ordering and the elapsed-time text live in a
  plain value beside the view, the way `SidebarFilter` does, and are tested
  there. The view is not.

## Gaps

### Everyday

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
- Worktree operations stop at create and remove: no fetch to refresh the
  remote list, no tracking checkout of a remote-only branch, no view of
  merged branches that could go.
- Nothing per project shapes the terminal beyond its shell: no startup
  commands or environment variables. The store can open a tab running a
  command; the agent tab and Open in Editor reach it.
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
- The Ghostty engine, the default, has no automated test. Linux has the
  core, the model and the socket channel but no GUI, no inotify
  `DirectoryWatcher`, and has not been built locally.
- Documented open decisions: a hook that never exits cannot be stopped from
  the app; the directory check before a click runs on the main thread.
- Unverified: whether this embedding loads the user's own Ghostty config
  from `~/.config/ghostty`. If it does, a user's keybinds can undo the app's
  unbinds and their theme can fight the app's; if it does not, people with
  a tuned Ghostty lose it here. Either answer needs a line in DESIGN.md and
  probably a setting.
