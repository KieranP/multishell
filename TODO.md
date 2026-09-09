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
- Tabs and panes: swap or zoom a pane.
- A view of a project's merged branches. The badge says which worktree has
  landed; a branch whose worktree is already gone is in no list.
- Per-project startup commands and environment variables.
- "Locate…" on a missing project, rebinding it to a chosen directory.
- Terminal: find.
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
- The four hook files are written from each agent's documented shape, and
  only Claude Code's has been watched moving a dot in a real session. Run
  each agent once and check its events fire and that Codex's `/hooks` trust
  holds. The OpenCode plugin's own logic has been driven against a stub
  helper; what is unproven is that OpenCode loads a plugin exporting a
  function rather than a default `{ id, setup }`, its loader having two
  generations of that contract.
- An OpenCode server started from one pane and reused by another reports
  that first pane's `MULTISHELL_SESSION`, so the dot lands on the wrong
  tab. Only the plugin has this: every other agent's hook runs in the
  session's own process.
- Whether this embedding loads `~/.config/ghostty` is unverified.

## Packaging

- The bundle runs only where it was built: libghostty's `Bundle.module`
  never looks in `Contents/Resources`. Build with Xcode or patch
  libghostty-spm. See Known gaps in DEVELOP.md.
- Developer ID signing and notarisation, so another machine will run it; the
  local certificate buys privacy grants and nothing towards distribution.
  Check whether libghostty needs an entitlement under the hardened runtime.
- A release workflow: versioned DMG or zip from a tag, the version from the
  tag rather than the commit `make-app.sh` writes, and an update check.
- What the README owes someone installing a release rather than building:
  download, Gatekeeper, where state lives. Adding a project and the agent
  hooks are already there.
- Homebrew cask.
