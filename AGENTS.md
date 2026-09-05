# For agents working in this repository

Read these before changing anything:

- `DEVELOP.md`: how to build and test, where things live, the rules CI
  enforces, how to add an engine, theme or platform.
- `DESIGN.md`: the decisions behind the architecture and behaviour, with the
  reasons and costs. Do not undo one without knowing what it cost to make; a
  few record features that were removed on purpose.

Working rules:

- The three root libraries import Foundation only. `Paths.swift` is the only
  core file allowed `#if os(...)`. Platform code goes behind `Ports/`.
- Views call `AppModel`; they never touch the store, a host, or git.
- Run `make format` on anything you touched, then `make lint`, `make test`
  (both packages), `make build` and `make release`. All must pass, and both
  builds must compile with no warnings, before you say something works.
- Every persisted field decodes with a default, including an enum value this
  build does not know. Add a case to `DecodingDefaultsTests` when you add one.
  Worktrees, sessions and tabs decode element by element and drop a broken
  one (`LossyArray`); projects stay strict. References between collections
  are restored by `Workspace.repairReferences` after a load; extend it, and
  `WorkspaceInvariants`, when you add a collection or a reference.
- Every store operation must leave `WorkspaceInvariants` true. The seeded
  random tests (`WorkspaceStoreInvariantTests`, `AppModelInvariantTests`) will
  find it if not; a failure prints its seed and step so it can be replayed.
- Runtime state (shell titles, session states, statuses, live sessions)
  lives in `AppModel`, never in the workspace, so a prompt does not save or
  re-render. `SessionStates` owns who clears what; change it there and in
  `SessionStatesTests`, not in a view.
- The socket accepts reports that change a dot and nothing else: no opening
  tabs, no running commands. Its protocol only ever adds fields, so an old
  helper keeps working against a new app. A report naming a session the app
  does not know is dropped, not matched by its directory.
- Shell integration is generated per session under the state directory and
  injected through `ZDOTDIR` (zsh) or `--init-file` (bash). Never write to a
  user's rc file. Claude Code's hooks are the one exception, and only on the
  user's click, with a copy kept beside the file.
- A new keyboard shortcut also goes in `GhosttyTerminalHost.appShortcuts`, or
  the surface eats it before the menu sees it.
- Debug builds use `state.debug.json`, `multishell.debug.sock` and
  `integration.debug/`, decided by `#if DEBUG` in `Paths`; keep new
  per-build files on that pattern so `make run` never touches the installed
  app's state.
- Nothing in the core blocks a thread. `ProcessRunner` is handler-driven; a
  test runs 96 children at once and another counts descriptors after failed
  launches. Do not add a `wait` inside a `Task`. Pipes come from the `pipe`
  syscall, never `Pipe()`, which cannot fail and hands back stdin at the
  descriptor limit.
- A closed tab's shell ends and is collected. `SwiftTermHostTests` spawns
  real shells to check it; keep it passing when you touch a host.
- Git that runs on a timer reads only: `git status` polls carry
  `--no-optional-locks`. A background call that takes `index.lock` breaks the
  user's own commits.
- Decisions a view makes live in a plain value beside it (`NewWorktreeDraft`,
  `SplitMath`, `SidebarFilter`) and are tested there. Views are not tested.
- Test git behaviour against a real repository with `RepositoryFixture`, not
  with mocks. Test parsers on fixture text, including the odd lines in the
  robustness tests.
- Timing bounds in tests are sized for a two-core CI runner, several times a
  laptop's figure. Keep that headroom when you add one.
- Small single-purpose files. Comments only for why, non-local consequences,
  or facts the code cannot show. No restatements.
- Nothing is committed unless the user asks.
