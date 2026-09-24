# TODO

Most pressing first within each heading. A decision that gets made moves to
`Docs/design/`; a gap documented rather than fixed goes to `BUGS.md`.

## Features

- File tree and git changes diff in a right-hand panel.

## Refinements

- Keyboard focus. Nothing moves focus inside a tab, so a split pane is
  mouse-only and the terminal takes every keystroke. The sidebar filter, folded
  behind the header's glass, is mouse-only too. Each new binding is an
  `AppShortcut` in `AppShortcuts.all`.
- Use Selection for Find: Cmd+F with text highlighted puts that text in the
  search field. Waits on a wrapper release exposing the surface's selection; the
  engine's own binding for it stays bound and does nothing here.

- Subagent nesting. A subagent that launches its own shows in the chip as a flat
  list beside them, every row named `general-purpose`, where Claude shows
  `code-review` with its two workers under it. The roster is by id with no
  parent (agents.md); first find whether any hook payload names the parent.

## Packaging

- Developer ID signing and notarisation, so another machine will run it. The
  hardened runtime, the entitlement and the timestamp rule are in already
  (signing.md). Still unwatched under the runtime: the CLI install's
  administrator prompt (BUGS.md).
- A release workflow: a versioned DMG or zip built from a `vX.Y.Z` tag, which
  `build-lib.sh` already reads as the version.
- What the README owes someone installing a release rather than building:
  download, Gatekeeper, where state lives, and the agent flag placeholders,
  which the settings rows give one example of.
