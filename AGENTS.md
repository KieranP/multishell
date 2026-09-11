# Multishell, for agents

An index. Pull in the file you need; do not read them all. Rules live with
their reasons, so a file under `docs/design/` is binding and not background.

Commit only when the user asks. That is the one rule that lives here.

## Working on the code

| Read | For |
| --- | --- |
| [docs/develop/build.md](docs/develop/build.md) | The make sequence every change must pass, and what you cannot verify: no screen, no Apple events. Read before claiming something works. |
| [docs/develop/layout.md](docs/develop/layout.md) | Which package holds what, what may import Foundation only, views versus core, file and comment style. |
| [docs/develop/adding.md](docs/develop/adding.md) | What an addition needs beyond the code. Covers an engine, theme, agent, editor, hook stage or variable, file list, shortcut, board column or card fact, menu item, project icon, sort order, shell, platform, persisted field, collection, runtime state, per-build file, settings row, notified state. |
| [docs/develop/tests.md](docs/develop/tests.md) | Which test catches which breach, and the conventions a new one follows. |
| [docs/develop/state-on-disk.md](docs/develop/state-on-disk.md) | What is written where, the debug build's own files, a repository's `.multishell.json`. |
| [docs/develop/permissions.md](docs/develop/permissions.md) | What macOS prompts for, what it only denies, how to read the TCC log. |
| [docs/develop/dependencies.md](docs/develop/dependencies.md) | libghostty, SwiftTerm, the one underscored SwiftUI API. |
| [docs/develop/known-gaps.md](docs/develop/known-gaps.md) | What is unverified or unbuilt, with the fallback where there is one. Settled behaviour under Known issues, what nobody has watched happen under Unconfirmed behaviour. Add to it when you leave a gap. |
| [TODO.md](TODO.md) | Queued work. Finishing something moves its note: a decision to the right file under `docs/design/`, a gap left rather than fixed to known-gaps.md. |

## Why it is like this, and the rules that follow

Telegraphic notes, one file per subject. Newest at the bottom within each.

| Read | For |
| --- | --- |
| [docs/design/architecture.md](docs/design/architecture.md) | Core versus GUI, reconcile don't command, identity is the path, shelling out to git, why nothing blocks a thread. |
| [docs/design/state-and-store.md](docs/design/state-and-store.md) | Why persisted state is repaired rather than trusted, why projects are strict where the rest are lossy, why invariants are tested at random. |
| [docs/design/settings.md](docs/design/settings.md) | User over project over repository, what blank means, and the trust that guards a hook someone else committed. |
| [docs/design/hooks.md](docs/design/hooks.md) | Why a hook is a login and interactive shell, only a pre hook refuses, how one is stopped, and why a new worktree gets files by a list instead. |
| [docs/design/worktrees.md](docs/design/worktrees.md) | What is watched and what is polled, naming, the trunk row and row ordering, removal to the Trash, bare repositories, a missing directory. |
| [docs/design/merged-branch.md](docs/design/merged-branch.md) | How "this branch landed" is decided from three signs, none of which writes. |
| [docs/design/tabs-and-columns.md](docs/design/tabs-and-columns.md) | Pane trees, what a drag to another worktree does, columns beside each other, `activeTab` versus `shownTabs`, the drag with no image, a strip out of room. |
| [docs/design/terminals.md](docs/design/terminals.md) | Where a session's state comes from, how a shell ends, injected integration, click-to-move, dropped files, agent and shell ids. |
| [docs/design/agents.md](docs/design/agents.md) | What the socket accepts, each agent's hooks and why each event was narrowed, and the board as a roster. |
| [docs/design/appearance.md](docs/design/appearance.md) | Hex themes, the focused pane's ring and the fade, hand-drawn window chrome, the header and row heights. |
| [docs/design/translation.md](docs/design/translation.md) | One catalogue in the lowest layer, why a view holds no literal, counted forms, and what stays in English. |
| [docs/design/signing.md](docs/design/signing.md) | Why a local build carries a dev certificate rather than signing ad hoc. |
| [docs/design/smaller-decisions.md](docs/design/smaller-decisions.md) | Sixteen one-liners: warm-up, both engines, keybinds, error mapping, help behind an (i), notification toggles, the icon palette, the rest. |
