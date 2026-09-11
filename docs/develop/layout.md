# Layout, layering and style

Which package holds what, what may import what, how a file is written.

## Layout

Root package, four Foundation-only libraries:
- MultishellCore: model, store, theme, ports
- MultishellProcess: processes, sockets
- MultishellGitKit: worktree operations, parsers, hooks
- MultishellAppCore: AppModel, detections, dialogs, error mapping, every
  decision a view makes

MultishellCLI = the helper. `Apps/macOS` = its own package: views, the two
engine hosts, MacPlatform.

What the suites share sits in plain targets, since a test target cannot be
depended on. Two of them, split by what they drag in: `Tests/TestScratch`
(`Scratch`, throwaway paths and shell shims) has no dependencies, so a Core
or Process suite can have a temp directory without linking the git layer;
`Tests/TestSupport` (`TestGit`, `TestRepository`) needs MultishellGitKit and
is for the two suites that touch a real repository. `Apps/macOS` is its own
package and reaches neither, so its harness keeps its own.

## Style

`swift-format` from the toolchain with the root `.swift-format`: 2-space
indent, 100 columns. One type per file, named for the type;
`Type+Concern.swift` for an extension, `*Failures.swift` for a group of error
types. Tests are swift-testing, named as sentences about behaviour. A dialog =
a `View` extension in a file named for it, attached by the scene that asked.

## Layering rules

- Four root libraries: Foundation only. `Paths.swift` = the only core file
  allowed `#if os(...)`. Platform code behind `Ports/`.
- `Apps/macOS` = views and AppKit. Everything else in MultishellAppCore,
  including a plain value beside a view unless it names AppKit or a Mac
  measurement. What the model needs from the desktop goes through the
  `Platform` port, never a direct AppKit call.
- Mac and Linux only, no Windows branches. An OS difference is `#if
  os(Linux)` or `#if canImport(Darwin)`, in the process layer or a port
  implementation, never a model or a view.
- Views call AppModel; never the store, a host, git. A terminal's view comes
  from `model.surface(for:)`.
- A decision a view makes is a plain value in MultishellAppCore
  (NewWorktreeDraft, SplitMath, SidebarFilter, EditorLaunch, TabStripLayout,
  TabShuffle, TabDragState, AgentBoard, AgentBoardLayout,
  NotificationSettings), tested there. Views are untested and measure nothing.
- Small single-purpose files. Comments only for why, non-local consequence, or
  a fact the code cannot show.
