# For agents working in this repository

Read these before changing anything:

- `DEVELOP.md`: how to build and test, which package holds what, the rules
  CI enforces, how to add an engine, theme, shell or platform, where state
  lives, the known gaps.
- `DESIGN.md`: why each decision was made and what it cost, and nothing the
  code already says. Do not undo one without knowing what it cost to make; a
  few record features that were removed on purpose.

Working rules:

- The four root libraries import Foundation only. `Paths.swift` is the only
  core file allowed `#if os(...)`. Platform code goes behind `Ports/`.
- `Apps/macOS` is views and AppKit only. `AppModel`, the runtime state, the
  detections, the dialog text, the error presentation and the socket channel
  live in `MultishellAppCore`; a plain value beside a view goes there too
  unless it names AppKit or a Mac measurement. What the model needs from the
  desktop goes through the `Platform` port, never a direct AppKit call.
- Mac and Linux only: no Windows branches. An OS difference is
  `#if os(Linux)` or `#if canImport(Darwin)`, in the process layer or a
  port implementation, never in a model or a view.
- Views call `AppModel`; they never touch the store, a host, or git. A view
  gets a terminal's view through `model.surface(for:)`.
- Run `make format` on anything you touched, then `make lint`, `make test`
  (both packages), `make build` and `make release`. All must pass, and both
  builds must compile with no warnings, before you say something works.
- You cannot see or drive the app. This environment has neither Apple events
  (System Events answers `-1743`) nor Screen Recording (`screencapture`
  answers "could not create image from display"), so there is no window to
  click through and no screenshot to look at. Do not try, and do not ask for
  those permissions. A view change goes as far as the checks above and no
  further: say what is left unverified and leave the looking to the user.
  Whatever can be decided without a screen belongs in a plain value in
  `MultishellAppCore`, tested there, which is what makes that boundary worth
  keeping.
- Every persisted field decodes with a default, including an enum value this
  build does not know. Add a case to `DecodingDefaultsTests` when you add one.
  Worktrees, sessions, tabs and a project's shared-hook answers decode
  element by element and drop a broken one (`LossyArray`); projects stay
  strict. References between collections are restored by
  `Workspace.repairReferences` after a load; extend it, and
  `WorkspaceInvariants`, when you add a collection or a reference.
- Every store operation must leave `WorkspaceInvariants` true. The seeded
  random tests (`WorkspaceStoreInvariantTests`, `AppModelInvariantTests`) will
  find it if not; a failure prints its seed and step so it can be replayed.
- Runtime state (shell titles, session states, statuses, live sessions, the
  agent that reported in each pane) lives in `AppModel`, never in the
  workspace, so a prompt does not save or re-render. `SessionStates` owns who clears what; change it there and in
  `SessionStatesTests`, not in a view.
- The socket accepts reports that say what a session is doing and who is
  doing it, and nothing else: no opening tabs, no running commands, no text
  put at a prompt. A report moves a dot, and its `agent` names which agent
  is at that pane's prompt, which is read when the user themselves drops a
  file there. Its protocol only ever adds fields, so an old helper keeps
  working against a new app. A report naming a session the app does not
  know is dropped, not matched by its directory.
- Shell integration is generated per session under the state directory and
  injected through `ZDOTDIR` (zsh) or `--init-file` (bash). Never write to a
  user's rc file. Claude Code's hooks are the one exception, and only on the
  user's click, with a copy kept beside the file.
- A new keyboard shortcut also goes in `GhosttyTerminalHost.appShortcuts`, or
  the surface eats it before the menu sees it.
- A dragged tab is `TabTransfer`, under its own type, spelled both in that
  file and in the `Info.plist` `make-app.sh` writes. Its own type and not
  text: a project is dragged as text to reorder the sidebar, and one type
  for both would offer each drag the other's targets. A worktree row would
  light up for a project it cannot take, and swallow the drop.
- The sidebar and detail headers are `UIMetrics.headerHeight` tall, the
  height of the hidden title bar's band. Nothing but a header may reach into
  that band, or AppKit paints over it.
- A worktree row's height is `UIMetrics.worktreeRowHeight`, asked by both the
  row that draws it and the sidebar, which counts a project's block off it to
  place the drop indicator. The two disagreeing puts the indicator in the
  wrong half of the block.
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
- Decisions a view makes live in a plain value in `MultishellAppCore`
  (`NewWorktreeDraft`, `SplitMath`, `SidebarFilter`, `EditorLaunch`) and are
  tested there. Views are not tested.
- Settings help text goes behind an `InfoButton`, not a caption under the
  row. A `SettingsCaption` is for a value computed live from the settings.
- Anything that acts on a worktree goes in `WorktreeActions`, which the
  detail header's menu and the sidebar's context menu both show.
- A project's settings are read through `model.effectiveSettings(for:)` and
  `model.worktreeSettings(for:)`, never `project.settings` directly: the
  repository's `.multishell.json` fills the gaps the user left, and its
  hooks apply only once trusted. The user's own value always wins. The
  override forms are the exception, and go through `model.settings(of:)`:
  they edit what the user set, where blank has to keep meaning "follow the
  global" rather than "override with nothing".
- A settings row binds through `model.setting(...)`, which reads the stored
  value each time. A form field written as its own `Binding` goes stale
  against a change made elsewhere.
- A hook is ended through `ProcessStopper`, SIGHUP to the child's process
  group then SIGKILL, never `Process.terminate()`: interactive shells ignore
  SIGTERM, and a shell with no terminal does not pass SIGHUP to its job.
- What a hook is told is a case in `HookVariable`, which both builds the
  environment and draws the Hooks tab's table. A name spelled into only one
  of those is a variable the help never mentions.
- A worktree is removed by moving its directory to the Trash through the
  `Platform` port and running `git worktree prune`; `git worktree remove` is
  not used. A Trash that refuses falls back to deletion.
- Test git behaviour against a real repository with `RepositoryFixture`, not
  with mocks. Test parsers on fixture text, including the odd lines in the
  robustness tests.
- Timing bounds in tests are sized for a two-core CI runner, several times a
  laptop's figure. Keep that headroom when you add one.
- Small single-purpose files. Comments only for why, non-local consequences,
  or facts the code cannot show. No restatements.
- Nothing is committed unless the user asks.
