# TODO

The queue, most pressing first within each heading. A decision that gets
made moves to the right file under `docs/design/`; a gap that is documented rather
than fixed lives in `docs/develop/known-gaps.md`.

## Features

- "Locate…" on a missing project, rebinding it to a chosen directory.
- Terminal: find.

## Refinements

- Keyboard: Cmd+1 to 9 for tabs, next and previous worktree, focus between
  panes, focus the sidebar filter. Each is an `AppShortcut` in
  `AppShortcuts.all`.
- `os.Logger` for process runs, hooks, refreshes and decode failures; only
  `MacPlatform` logs today. A Help menu with the repository and issue
  tracker, and "Copy diagnostics".

## Issues

- Status polling on a monorepo: every five seconds, a `git status` per
  worktree eight at a time, and after the last of them a ref scan per
  project, one project after another. Only while the app is frontmost, so
  it costs nothing in the background, but a large checkout keeps the disk
  busy for as long as it is in front. A per-project toggle or a longer
  interval, hiding the badge rather than showing it stale.
- Two copies of one build both autosave and the last writer wins. The
  second already sees the first's socket; make it activate the first or
  refuse to start.
- The four hook files are written from each agent's documented shape, and only
  Claude Code's has been watched moving a dot in a real session. Run each agent
  once: check its events fire, that the pid reported is the agent and not a
  wrapper outliving the hook, and that Codex's `/hooks` trust holds. The
  OpenCode plugin's logic has been driven against a stub helper; unproven is
  that OpenCode loads a plugin exporting a function rather than a default
  `{ id, setup }`, its loader having two generations of that contract, and
  that the two permission events arrive under the names the plugin now
  listens for, with the title where it reads it.
- An OpenCode server started from one pane and reused by another reports
  that first pane's `MULTISHELL_SESSION`, so the dot lands on the wrong
  tab. Only the plugin has this: every other agent's hook runs in the
  session's own process.

## Packaging

- The bundle runs only where it was built: libghostty's `Bundle.module`
  never looks in `Contents/Resources`. Build with Xcode or patch
  libghostty-spm. See `docs/develop/known-gaps.md`.
- Developer ID signing and notarisation, so another machine will run it; the
  local certificate buys privacy grants and nothing towards distribution.
  Check whether libghostty needs an entitlement under the hardened runtime.
- A release workflow: versioned DMG or zip from a tag, and the version from
  the tag rather than the commit `make-app.sh` writes.
- In-app update: notice a newer release, say so, and install it on the
  user's word. Wants the release workflow's versioned artefact and Developer
  ID first, since an unnotarised update will not launch on the machine it
  replaces itself on. Sparkle, or a tag check against the API and a download
  the user opens.
- What the README owes someone installing a release rather than building:
  download, Gatekeeper, where state lives. Adding a project and the agent
  hooks are already there.
- Homebrew cask.

## Future

- Linux support: a GUI, an inotify `DirectoryWatcher`, and an XDG Trash for
  its `Platform` (removal deletes outright until then). The core is already
  Foundation-only and never compiled on Linux, locally or in CI.
