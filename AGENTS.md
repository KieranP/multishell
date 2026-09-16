# Multishell, for agents

An index. Pull in the file you need; do not read them all. Rules live with
their reasons, so a file under `docs/design/` is binding and not background.

Three rules live here. The rest are in the files below.

* Commit only when the user explicitly asks.
* No code comment exceeds two lines. Where more is needed, add it to a file
  under `docs/design/` or `docs/develop/` and refer to it from the comment.
* When fixing a bug, write a failing test first where practical, then fix it.

## Working on the code

| Read | For |
| --- | --- |
| [docs/develop/build.md](docs/develop/build.md) | The make sequence every change must pass, what CI runs, and what you cannot verify: no screen, no Apple events. Read before claiming something works. |
| [docs/develop/layout.md](docs/develop/layout.md) | Which package holds what, what may import Foundation only, views versus core, file and comment style. |
| [docs/develop/adding.md](docs/develop/adding.md) | What an addition needs beyond the code. Covers an engine, theme, agent, editor, hook stage or variable, flag placeholder, file list, shortcut, tab strip measurement, board column or card fact, menu item, project icon, sort order, shell, platform, persisted field, preference, collection, runtime state, per-build file, settings row, user-visible string, language, notified state. |
| [docs/develop/tests.md](docs/develop/tests.md) | Which test catches which breach, and the conventions a new one follows. |
| [docs/develop/state-on-disk.md](docs/develop/state-on-disk.md) | What is written where, the debug build's own files, the socket and its lock, where each agent's hooks go, a repository's `.multishell.json`. |
| [docs/develop/permissions.md](docs/develop/permissions.md) | What macOS prompts for, what it only denies, how to read the TCC log. |
| [docs/develop/dependencies.md](docs/develop/dependencies.md) | libghostty and what moving its pin costs, the one underscored SwiftUI API, the git version floor. |
| [docs/develop/known-gaps.md](docs/develop/known-gaps.md) | What is unverified or unbuilt, with the fallback where there is one. Settled behaviour under Known issues, what nobody has watched happen under Unconfirmed behaviour. Add to it when you leave a gap. |
| [BUGS.md](BUGS.md) | Open findings from the whole-repo review and the issues once queued in TODO.md, numbered and labelled by what each does to the user. Numbers are never reused, so they have gaps; a fixed entry is taken out rather than kept. |
| [TODO.md](TODO.md) | Queued work. Finishing something moves its note: a decision to the right file under `docs/design/`, a gap left rather than fixed to known-gaps.md. |

## Why it is like this, and the rules that follow

Telegraphic notes, one file per subject. Newest at the bottom within each.

| Read | For |
| --- | --- |
| [docs/design/architecture.md](docs/design/architecture.md) | Core versus GUI, reconcile don't command, identity is the path, shelling out to git, why nothing blocks a thread. |
| [docs/design/state-and-store.md](docs/design/state-and-store.md) | Why persisted state is repaired rather than trusted, why projects are strict where the rest are lossy, why invariants are tested at random, when a file is moved aside, saves off the main actor and in order, one copy of a build at a time. |
| [docs/design/settings.md](docs/design/settings.md) | Project over global, a repository's file filling only gaps, what blank means, and the trust that guards a hook someone else committed. |
| [docs/design/hooks.md](docs/design/hooks.md) | Why a hook is a login and interactive shell, only a pre hook refuses, how one is stopped, and why a new worktree gets files by a list instead. |
| [docs/design/worktrees.md](docs/design/worktrees.md) | What is watched and what is polled, naming, the trunk row and row ordering, removal to the Trash, a branch name refused before git runs, bare repositories, a missing directory, the NUL-terminated list, runtime state dropped in one place, a slow status asked less often. |
| [docs/design/merged-branch.md](docs/design/merged-branch.md) | How "this branch landed" is decided from three signs, none of which writes; why the user's git config cannot change a read; refnames, never bare names. |
| [docs/design/tabs-and-columns.md](docs/design/tabs-and-columns.md) | Pane trees, what a drag to another worktree does, columns beside each other, `activeTab` versus `shownTabs`, the drag with no image, a strip out of room, a dropped tab taking the keyboard. |
| [docs/design/terminals.md](docs/design/terminals.md) | Where a session's state comes from, how a shell ends, injected integration, click-to-move, dropped files, agent and shell ids, the three layers a user's Ghostty config sits in the middle of and the allow list it is read through. |
| [docs/design/agents.md](docs/design/agents.md) | What the socket accepts, each agent's hooks and why each event was narrowed, the board as a roster, and flags per agent against one list of placeholders. |
| [docs/design/appearance.md](docs/design/appearance.md) | Hex themes, the focused pane's ring and the fade, hand-drawn window chrome, one workspace window, the header and row heights, a board card's three lines. |
| [docs/design/translation.md](docs/design/translation.md) | A catalogue per frontend and one for the libraries, why a view holds no literal, counted forms, what stays in English, no language picker. |
| [docs/design/signing.md](docs/design/signing.md) | Why a local build carries a dev certificate rather than signing ad hoc, and what happens without one. |
| [docs/design/smaller-decisions.md](docs/design/smaller-decisions.md) | Seventeen one-liners: warm-up, keybinds, error mapping, help behind an (i), notification toggles, the icon palette, one banner per pane, one engine, the rest. |
