# TODO

Most pressing first within each heading. A decision that gets made moves to
`Docs/design/`; a gap documented rather than fixed goes to `BUGS.md`.

## Features

- File tree and git changes diff in a right-hand panel.
- A task field on the New Worktree sheet, handed to the agent as its first
  prompt, and a `{prompt}` placeholder beside `{branch}`, `{path}` and
  `{project}` for the flags. `NewWorktreeDraft` carries only the branch and base
  today.
- A quick switcher on a shortcut: fuzzy search over every project, worktree, tab
  and agent, waiting agents ranked first. Changing worktree is mouse-only today.
- Pull request and CI state on a worktree row, read through `gh` where it is on
  the PATH: number, review state, checks, and a Create Pull Request action. The
  merged badge answers whether a branch landed; this answers where it is before
  then.
- Listening ports per worktree: the sockets the panes' process trees listen on,
  found from the pids `AppModel+PIDWatch` already holds, shown on the row as a
  link. Perhaps a per-worktree port offset in the environment too, so project
  hooks can keep dev servers apart.
- A tab layout per project in `.multishell.json`, such as an agent beside a dev
  server with a test watcher below, opened in every new worktree. A post-create
  hook runs in one pane and cannot describe tabs.
- More CLI commands over the existing socket: `multishell open .` to add the
  project and select this worktree,
  `multishell new-worktree <branch> [--agent] [--prompt]`, and
  `multishell tab -- <command>`, so scripts and agents can drive the app.
- State dots for fish, through `fish_preexec` and `fish_postexec` reporting
  `command-started` and `command-finished`. COMPAT.md lists it as a terminal
  with nothing injected.

## Refinements

- Keyboard focus. Nothing moves focus inside a tab, so a split pane is
  mouse-only and the terminal takes every keystroke. The sidebar filter, hidden
  behind the header's glass, is mouse-only too. Each new binding is an
  `AppShortcut` in `AppShortcutCatalogue.all`.
- Use Selection for Find: Cmd+F with text highlighted puts that text in the
  search field, read with `ghostty_surface_read_selection`. The engine's own
  binding for it stays bound and does nothing here until then.
- The find bar's match count, "3 of 12": decode libghostty's search total and
  selected actions in `GhosttySurfaceEvent` and show them beside the field.

## Packaging

- Developer ID signing and notarisation, so another machine will run it. The
  hardened runtime, the entitlements and the timestamp rule are in already
  (signing.md). Nobody has yet watched the CLI install's administrator prompt
  under the runtime. Step: Install Command Line Tool in Settings > Agents, then
  `ls -l /usr/local/bin/multishell`.
- A release workflow: a versioned DMG or zip built from a `vX.Y.Z` tag, which
  `build-lib.sh` already reads as the version.
- What the README owes someone installing a release rather than building:
  download, Gatekeeper, where state lives, and the agent flag placeholders,
  which the settings rows give one example of.
