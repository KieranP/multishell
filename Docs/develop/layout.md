# Layout, layering and style

## Layout

Root package, four Foundation-only libraries:

- MultishellCore: model, store, theme, ports, and `t(_:_:)`, which reads the
  libraries' string catalogue; `Support/` holds the small extensions every other
  library reaches for, `clamped(to:)` and the path helpers
- MultishellProcess: processes, sockets
- MultishellGitKit: worktree operations in `Worktrees/`, the output readers in
  `Parsers/`, what a branch is and where it points in `Branches/`, and
  `GitRunner` above them all
- MultishellAppCore: AppModel, detections, dialogs, error mapping, every
  decision a view makes; `Text/` is what a screen reader is told, `Support/` the
  two pieces that belong to no concern, the helper's link and the icon grid's
  arrow keys

Everything the app knows about a program someone else wrote lives in
`Sources/MultishellCore/Integrations/`, one folder per kind: `Agents/` (the
catalogue, the flags, each agent's hooks and OpenCode's plugin), `Editors/`,
`Shells/` (the catalogue, the launch, the state hooks and the generated startup
files), and `Hooks/`, the JSON reading and rewriting the agents share. Adding
support for another agent touches `Agents/` and no other integration folder; see
adding.md for what it needs outside one.

MultishellCLI = the helper. `Apps/macOS` = its own package: views, the engine
host, MacPlatform, and a `t(_:_:)` of its own. Its views sit under the part of
the window they draw: `Sidebar/`, `Terminals/`, `Agents/`, `Sheets/`. The rest
draw no part of one. `Controls/` = the small views several screens reuse.
`AppKit/` = the modifiers, representables and `NSView`s that reach under SwiftUI
for an event it has no gesture for. `App/` = the scene, the menus, and the two
port implementations the model is handed, MacPlatform and
UserNotificationNotifier. `Text/` = its `t(_:_:)`, `Support/` what is left.

Each half's words are a `Resources/en.lproj` inside the target that says them:
`Sources/MultishellCore/Resources` for the libraries, with the shell-integration
scripts, and `Apps/macOS/Sources/Multishell/Resources` for the Mac app, which
also holds `Marks/`, one `.svg` per agent mark. A second frontend is a third of
these. `Apps/macOS/Resources` is not one of them: that is the icon, which the
bundling script copies and SwiftPM never sees.

Each suite's folders mirror the target it tests, so a file and its tests sit at
the same place in two trees: `Tests/MultishellCoreTests/Integrations/Agents`
against `Sources/MultishellCore/Integrations/Agents`, and so on. A suite's own
harnesses and fakes stay at its root. The two flat targets, MultishellProcess
and the helper, have flat suites. A file covering several concerns goes by the
one it spends most of its lines on.

What the suites share sits in plain targets, since a test target cannot be
depended on. Two of them, split by what they drag in. `Tests/TestScratch` has no
dependencies, so every root suite, the helper's included, reaches it: `Scratch`
for throwaway paths, sockets and shell shims, `waitUntil`,
`lowestDescriptorCount`, `Flag`, `LineRecorder` and `SeededGenerator`.
`Tests/TestSupport` (`TestGit`, `TestRepository`) needs MultishellGitKit and is
for the two suites that touch a real repository. `Apps/macOS` is its own package
and reaches neither, so its harness keeps its own (`ModelHarness`).

## Style

`swift-format` from the toolchain with the root `.swift-format`: 2-space indent,
100 columns. One type per file, named for the type; `Type+Concern.swift` for an
extension, `*Failures.swift` for a group of error types. Two exceptions: an
error type thrown from one file alone may sit at the bottom of that file, and
several small types of one shape that are only ever read together may share a
file named for what they are (`TabDrops.swift`, `WorktreeSteps.swift`). No
`MARK` banners: a file is the grouping. Tests are swift-testing, named as
sentences about behaviour. A dialog = a `View` extension in a file named for it,
attached by the scene that asked.

## Layering rules

- Four root libraries: Foundation only. `Paths.swift` = the only MultishellCore
  file allowed `#if os(...)`. Platform code behind `Ports/`.
- `Apps/macOS` = views and AppKit. Everything else in MultishellAppCore,
  including a plain value beside a view unless it names AppKit or a Mac
  measurement. What the model needs from the desktop goes through the `Platform`
  port, never a direct AppKit call.
- Mac and Linux only, no Windows branches. An OS difference is `#if os(Linux)`
  or `#if canImport(Darwin)`, in the process layer or a port implementation,
  never a model or a view.
- Views call AppModel; never the store, a host, git. A terminal's view comes
  from `model.surface(for:)`.
- A decision a view makes is a plain value in MultishellAppCore
  (NewWorktreeDraft, SplitMath, SidebarFilter, EditorLaunch, TabStripLayout,
  TabShuffle, TabDragState, AgentBoard, AgentBoardLayout, NotificationSettings),
  tested there. Views are untested and measure nothing.
- Small single-purpose files. Comments only for why, non-local consequence, or a
  fact the code cannot show.
- `public` only where another target reads it. The split costs a `public` on
  every type a frontend or another library names (architecture.md), and nothing
  beyond that: a parser, a policy or a stage's own helper that one library uses
  stays internal, and the tests reach it with `@testable`. An internal type's
  members carry no `public` either.
- No user-visible literal outside a catalogue: a word on screen is a
  `t("a.key")`, wherever it is written, and it goes in the catalogue of the half
  that says it. A view never reads the libraries' words; one they both say is
  written in both. See `Docs/design/translation.md`.
