# TODO

The queue, most pressing first within each heading. A decision that gets
made moves to the right file under `docs/design/`; a gap that is documented rather
than fixed lives in `docs/develop/known-gaps.md`; a defect goes to `BUGS.md`.

* Change subagents count to actually track state, so worktree shows in progress whebn any subagent is still working

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
