# TODO

The queue, most pressing first within each heading. A decision that gets made
moves to the right file under `Docs/design/`; a gap that is documented rather
than fixed goes to `BUGS.md`, ranked by what it costs and tagged [Unconfirmed]
where nobody has watched it go either way.

## Features

- File tree and git changes diff right hand panel

## Refinements

- Ability to rename worktree using default agent
- Pin worktrees in the sidebar
- "Locate…" on a missing project, rebinding it to a chosen directory.
- Keyboard: Cmd+1 to 9 for tabs, next and previous worktree, focus between the
  panes of one tab, focus the sidebar filter. Each is an `AppShortcut` in
  `AppShortcuts.all`. Nothing moves focus inside a tab today, so a split pane is
  mouse-only and the terminal takes every keystroke.
- Sidebar keyboard navigation, and a route to the filter now that it is folded
  behind the header's glass: the mouse is the only way to it. No view tests, and
  the accessibility labels have not been read with VoiceOver.
- Auto-scroll a tab strip while a tab is dragged near its end, so a reorder
  reaches past the tabs on screen. Wants the drop's own pointer position, a
  repeating step, and the strip's scroll proxy reaching the drop delegate.
- Use Selection for Find, which every other Mac find bar offers. Waits on a
  wrapper release exposing the surface's selection; the engine's own binding for
  it stays bound and does nothing here.
- Name the lines of a user's engine config that did not count, where a theme
  file that will not parse is already reported. Two ways for a line to go
  quietly: a key outside the allowed list, and one the repair dropped because
  the engine complained.
- Offer remote branches in the existing-branch picker, which lists local ones
  only today, so a remote-only branch is created as a new one based on its
  remote. A large repository has hundreds of remote branches, so it wants a
  search rather than another long menu.
- Somewhere a user can read the agent flag placeholders. The settings rows name
  one as an example and the rest live in the enum, waiting for a documentation
  site.
- `os.Logger` for process runs, hooks, refreshes and decode failures; only
  `MacPlatform` logs today. A Help menu with the repository and issue tracker,
  and "Copy diagnostics".

## Packaging

- Developer ID signing and notarisation, so another machine will run it; the
  local certificate buys privacy grants and nothing towards distribution. The
  hardened runtime, the entitlement and the timestamp rule are in already
  (signing.md); libghostty is static, so it asked for no entitlement of its own.
  What is still unwatched under the runtime is the CLI install's administrator
  prompt (BUGS.md).
- A release workflow: versioned DMG or zip from a tag, and the version from the
  tag rather than the commit `build-lib.sh` stamps.
- In-app update: notice a newer release, say so, and install it on the user's
  word. Wants the release workflow's versioned artefact and Developer ID first,
  since an unnotarised update will not launch on the machine it replaces itself
  on. Sparkle, or a tag check against the API and a download the user opens.
- What the README owes someone installing a release rather than building:
  download, Gatekeeper, where state lives. Adding a project and the agent hooks
  are already there.
- Homebrew cask.

## Future

- Remote Hosts: group projects under another remote host, adding projects /
  worktrees spins them up on the remote host, and any terminals opened are
  ssh/tmux sessions
- Linux support: a GUI, an inotify `DirectoryWatcher`, and an XDG Trash for its
  `Platform` (removal deletes outright until then). The core is already
  Foundation-only and never compiled on Linux, locally or in CI.
