# TODO

Most pressing first within each heading. A decision that gets made moves to
`Docs/design/`; a gap documented rather than fixed goes to `BUGS.md`.

## Features

- File tree and git changes diff in a right-hand panel.

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
