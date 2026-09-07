# TODO

The queue, most pressing first within each heading. A decision that gets
made moves to DESIGN.md; a gap that is documented rather than fixed lives in
DEVELOP.md under Known gaps.

## Features

- Terminals view: every open terminal in one list grouped Waiting, Working,
  Done, so someone running agents in several worktrees sees which one wants
  them, with a next-waiting shortcut.
  - Working is running, Waiting is attention, Done is done or error since
    the tab was last shown, Failed marked on the row. Idle shells left out,
    with a "show all" toggle.
  - A list, not thumbnails: a surface is one NSView. An entry above Projects
    in the sidebar with per-state counts, filling the detail area when
    selected; the selection is a runtime flag in `AppModel`.
  - Rows: tab title, project › worktree, state, time in state. No output
    line; neither engine hands scrollback to the core. Sorted by state, then
    most recent change.
  - Click selects the worktree and activates the tab; context menu is
    `WorktreeActions`; optionally the Dock badge shows the Waiting count.
  - Grouping, ordering and elapsed-time text in a plain value beside the
    view, tested there.
- Tabs and panes: swap or zoom a pane, move a tab to another worktree,
  close a non-active tab.
- Worktree operations beyond create and remove: fetch, tracking checkout of
  a remote-only branch, a view of merged branches.
- Per-project startup commands and environment variables.
- A "copy into new worktrees" list for `.env` and the like.
- "Locate…" on a missing project, rebinding it to a chosen directory.
- Terminal: find; SwiftTerm bell raising activity.
- A Linux GUI, an inotify `DirectoryWatcher`, and an XDG Trash for its
  `Platform` (removal deletes outright until then).
- Translation support.

## Refinements

- Keyboard: Cmd+1 to 9 for tabs, next and previous worktree, focus between
  panes, focus the sidebar filter. Each also goes in
  `GhosttyTerminalHost.appShortcuts`.
- Tab overflow: twelve tabs shrink to icons. Scroll the strip or collapse
  the inactive ones.
- `os.Logger` for process runs, hooks, refreshes and decode failures; only
  `MacPlatform` logs today. A Help menu with the repository and issue
  tracker, and "Copy diagnostics".

## Issues

- Status polling on a monorepo: eight `git status` calls every five seconds
  keep the disk busy. A per-project toggle or a longer interval, hiding the
  badge rather than showing it stale.
- Two copies of one build both autosave and the last writer wins. The
  second already sees the first's socket; make it activate the first or
  refuse to start.
- Confirm the pid a hook reports is Claude itself, not a wrapper that
  outlives the hook, against a real Claude Code session.
- Shared settings for a bare layout: `.multishell.json` is read from the
  project path, which for a bare repository holds no checkout.
- Whether this embedding loads `~/.config/ghostty` is unverified.

## Packaging

- The bundle runs only where it was built: libghostty's `Bundle.module`
  never looks in `Contents/Resources`. Build with Xcode or patch
  libghostty-spm. See Known gaps in DEVELOP.md.
- Developer ID signing and notarisation; check whether libghostty needs an
  entitlement under the hardened runtime.
- A release workflow: versioned DMG or zip from a tag, the version from the
  tag rather than `make-app.sh`, and an update check.
- A README for installers: download, Gatekeeper, add a project, hooks,
  where state lives.
- Homebrew cask.
