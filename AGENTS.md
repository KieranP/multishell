# For agents working in this repository

Read these before changing anything:

- `DEVELOP.md`: how to build and test, which package holds what, the rules
  CI enforces, how to add an engine, theme, shell or platform, where state
  lives, the known gaps.
- `DESIGN.md`: why each decision was made and what it cost, and nothing the
  code already says. Do not undo one without knowing what it cost to make; a
  few record features that were removed on purpose.
- `TODO.md`: what is queued. Finishing something means moving its note to the
  right file: a decision made to `DESIGN.md`, a gap left rather than fixed to
  `DEVELOP.md` under Known gaps, and only work still wanted stays here.

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
- A worktree's tabs sit in columns, `TabGroup`, side by side and never one
  above another. A column holds its width and its active tab; a tab names
  its column. `activeTab(in: worktree)` is the focused column's, which is
  what a keystroke, a split and a rename act on; `shownTabs(in:)` is every
  column's, which is what "the user can see this" means. A column never
  stands empty: the store takes it away with its last tab, and
  `repairReferences` gives an ungrouped tab the column its worktree already
  has.
- Run `make format` on anything you touched, then `make lint`, `make test`
  (both packages), `make build` and `make release`. All must pass, and both
  builds must compile with no warnings, before you say something works.
- You cannot see or drive the app: no Apple events (System Events answers
  `-1743`) and no Screen Recording (`screencapture` cannot create an image).
  Do not try, and do not ask for those permissions. A view change goes as far
  as the checks above and no further: say what is unverified and leave the
  looking to the user, and record what you could not check in `DEVELOP.md`
  under Known gaps, with the fallback if it turns out wrong. Whatever can be
  decided without a screen belongs in a plain value in `MultishellAppCore`,
  tested there.
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
  agent that reported in each pane, the desktop's answer about notification
  permission) lives in `AppModel`, never in the workspace, so a prompt does
  not save or re-render. `SessionStates` owns who clears what; change it
  there and in `SessionStatesTests`, not in a view.
- The socket accepts reports that say what a session is doing and who is
  doing it, and nothing else: no opening tabs, no running commands, no text
  put at a prompt. A report moves a dot, and its `agent` names which agent
  is at that pane's prompt, which is read when the user themselves drops a
  file there. Its protocol only ever adds fields, so an old helper keeps
  working against a new app. A report naming a session the app does not
  know is dropped, not matched by its directory.
- Shell integration is generated per session under the state directory and
  injected through `ZDOTDIR` (zsh) or `--init-file` (bash). Never write to a
  user's rc file. An agent's hooks are the one exception, and only on the
  user's click, with a copy kept beside a file that is the user's; the
  agents that read a file of their own are given one to themselves.
- An agent's hooks are one `AgentHookIntegration` in `AgentHooks`: the file,
  what each event is called, what each event says the session is doing, and
  how that file spells one hook. Nothing else in the app names an agent, and
  nothing recommends one: no install prompt, no setup link, no section of its
  own. The settings offer what detection found on the PATH.
- A new keyboard shortcut is an `AppShortcut` in `AppShortcuts`, listed in
  its `all`, which is where both the menu item and the surface's unbind come
  from; a shortcut declared and not listed is one the surface eats before the
  menu sees it. `surfaceKeeps` is for the few the terminal handles itself.
  Check the combination is not the system's before claiming it: Cmd+Option+D
  reads as the third of the split family and is the Dock's own, taken by the
  WindowServer before a menu bar sees it. Those go in `systemOwned`.
- A dragged tab is `TabTransfer`, under its own type, spelled both in that
  file and in the `Info.plist` `make-app.sh` writes. Its own type and not
  text: a project is dragged as text to reorder the sidebar, and one type
  for both would offer each drag the other's targets. A worktree row would
  light up for a project it cannot take, and swallow the drop.
- A tab drag carries no image: `.onDrag` gets a one-point clear `preview:`,
  because AppKit holds the card it draws on screen for the best part of a
  second after the mouse comes up and nothing in SwiftUI reaches that. Do not
  give it one back without owning the drag in AppKit. Nothing is drawn from a
  flag set when the drag began, only from what the pointer is over
  (`TabDragState.isEngaged`, `showsBands`): a drag can be let go where no
  target sees it, and a highlight would stay on screen with no drag behind it.
  Every drop answers `true` and moves the tab a turn later, so the drag ends
  against the view tree it began in and a refusal does not slide the preview
  home.
- The Agents board fills the detail area in place of the selected worktree's
  terminals, and that worktree stays selected behind it. So nothing on screen
  is a pane while it is up: `isShown` and `markShownTabSeen` answer false, or
  a Done clears before anyone has seen it, and everything that acts on "the
  tab in front of the user" asks `worktreeInView`, or Cmd+W ends a shell in a
  pane nobody can see. A card is one open pane, never a tab and never a
  worktree-level report, which has no pane to take you to.
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
  (`NewWorktreeDraft`, `SplitMath`, `SidebarFilter`, `EditorLaunch`,
  `TabStripLayout`, `TabShuffle`, `TabDragState`, `AgentBoard`,
  `AgentBoardLayout`, `NotificationSettings`) and are tested there. Views are
  not tested. A tab strip measures nothing: `TabStripLayout` gives every tab
  one width from the room and the count, and the drop reads that; the board's
  columns come the same way, and its wording, ordering and elapsed text are
  values too.
- Which pane the keystrokes go to is drawn from the theme, never from a
  colour in a view: `focusRing` is a colour, `""` for no ring, or absent for
  the selection colour, and `inactivePaneOpacity` fades the rest. A colour
  that will not parse falls back rather than reading as off, so a typo costs
  the colour and not the ring.
- Settings help text goes behind an `InfoButton`, not a caption under the
  row. A `SettingsCaption` is for a value computed live: from the settings,
  or from what the desktop reports, as the note under the notification
  toggles is.
- Which states notify is one toggle each in `NotificationPreference`, whose
  subscript answers for every state so a caller can hand it whatever was
  reported. Permission is asked for as a state goes on, never on the way
  down, through `SessionNotifier`; the page's words are
  `NotificationSettings`, and no desktop is named in them. Where a refusal is
  lifted comes from `Platform`, and a desktop that posts without asking
  answers `unavailable`.
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
  value each time; a field with its own `Binding` goes stale against a change
  made elsewhere. A project override is an `OverrideSection`, which names the
  key path once — written out it appeared three times and a wrong one still
  compiled. `SettingsBindingTests` catches a swapped `hasOverride` /
  `overrideValue` pair, which take the same arguments and return the same
  type.
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
- Timing bounds in tests are sized for a single-core CI runner, many times a
  laptop's figure. Keep that headroom when you add one.
- Small single-purpose files. Comments only for why, non-local consequences,
  or facts the code cannot show. No restatements.
- Nothing is committed unless the user asks.
