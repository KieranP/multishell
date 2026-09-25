# Layout, layering and style

## Layout

- **One package: four libraries, the helper and the app.** MultishellCore:
  model, with what a user or a repository sets under `Model/Settings/` and a
  worktree's tabs and panes under `Model/Tabs/`; store; theme; ports; the
  sessions and the reports about them; the decoding every persisted type leans
  on; the libraries' word lookup; and, under `Support/`, the small extensions
  and helpers every other library reaches for.
- **MultishellProcess**: processes and sockets. **MultishellGitKit**: worktree
  operations, a project's hooks and file lists, the output readers, what a
  branch is, where it points and whether it landed, a worktree's status, and the
  runner above them all.
- **MultishellAppCore**: AppModel, detections, dialogs, error mapping, settings
  as inherited, what a tab runs, what each session is doing, when to read git,
  when to notify, every decision a view makes; what a screen reader is told;
  what it needs from the app, and its own implementations of Core's ports, under
  `Ports/`; and, under `Support/`, the pieces that belong to no concern.
- **AppModel's extensions sit under `Model/` by concern**: agents, tabs,
  worktrees, git reads, projects, and the tools it drives. What spans them all
  stays at the root beside the type, since the concerns are too many for one
  alphabetical listing to keep a concern's files together.
- **AppCore's `Integrations/` is the app's own side of them**: the helper and
  shell-integration files it installs, and each agent's hooks as installed.
- **Everything about a program someone else wrote is in Core's
  `Integrations/`**, one folder per kind: agents, editors, shells, and the
  settings files the agents share the reading of. Another agent touches the
  agents folder and no other, until someone draws its mark.
- **MultishellCLI is the helper**, built as `multishell-helper` and installed in
  the bundle as `multishell`, since it and the app would share one products path
  on a case-insensitive disk. **MultishellAppUI is the app**, built as
  `Multishell`: views, the engine host, the Mac platform port, and a word lookup
  of its own.
- **Its views sit under the part of the window they draw**: the sidebar, the
  detail area, a group of tabs or a pane in it, the board, a settings window, a
  dialog. The rest draw no part of one: reused small views under `Shared/`, or
  `Settings/Controls/` where only the settings windows use them, the agent
  marks, the AppKit modifiers and representables that reach under SwiftUI for an
  event it has no gesture for, the scene and menus. The engine host and the
  platform port each have a folder. What draws nothing sits under `Support/`,
  the in-app drag's pieces under `Support/Drag/`, unless one part alone reads
  it: the mark parser sits with the marks, a dialog's AppKit alert with the
  dialogs, and what both settings windows share at `Settings/`'s root.
- **Each half's words live in the target that says them.** The libraries' also
  carry the shell-integration scripts; the app's also carries the agent marks. A
  second frontend is a third of these.
- **`Resources/` at the root is not one of those**: the icon, the Info.plist
  template and the entitlements, which the bundling script reads and SwiftPM
  never sees, and a smaller icon for the README.
- **Each suite's folders mirror the target it tests**, so a file and its tests
  sit at the same place in two trees. A suite's harnesses and fakes stay at its
  root, and a file covering several concerns goes by the one it spends most of
  its lines on.
- **What the suites share sits in plain targets**, a test target not being
  dependable on. Two of them, split by what they drag in: TestScratch, needing
  only Process and Subprocess, that every suite but the app's reaches, and
  TestSupport, needing GitKit, for the suites that touch a real repository, so a
  Core or Process suite does not link GitKit for a temporary path.
- **TestScratch starts a child with the runner's own spawn options**, reached
  with `@testable`, so a test's shell and the app's cannot start differently.
- **The app's suite, MultishellAppUITests, reaches neither**; its harness is its
  own.

## Style

- **`swift-format` from the toolchain with the root config.** Every type that is
  not `private` gets a file named for it, an error type and a null object
  included; an extension of another type goes in `<Type>+<Concern>.swift`.
- **A `private` helper type is its file's own and stays in it**, since moving it
  out would widen it. One that is reused, or long enough to bury the type it
  serves, gets its own file and goes internal. A dialog is a `View` extension in
  a file named for it, attached by the scene that asked.
- **No `MARK` banners**: a file is the grouping. Tests are swift-testing, named
  as sentences about behaviour, one suite to a file named for it.

## Layering rules

- **The four libraries import Foundation, Dispatch, System, Observation,
  Synchronization and CryptoKit, which Apple ships, and one package, nothing
  else**: swift-subprocess in the process layer (dependencies.md).
- **MultishellAppUI is views, AppKit and the engine host.** Everything else
  lives in MultishellAppCore, including a plain value beside a view unless it
  names SwiftUI, AppKit, a Mac measurement or the engine.
- **What the model needs from the desktop goes through the platform port**,
  never a direct AppKit call.
- **Mac only, with no other platform's branches.** Platform code belongs in the
  process layer or a port implementation, never a model or a view.
- **Views call AppModel**, never the store, a host or git. A terminal's view
  comes from the model.
- **A decision a view makes is a plain value in MultishellAppCore**, tested
  there. Views measure nothing, and a test lays one out only to hold its size or
  its pixels, in a window never ordered in.
- **Small single-purpose files.** Comments only for why, a non-local
  consequence, or a fact the code cannot show.
- **`public` only where another target reads it.** The split costs a `public` on
  every type a frontend or another library names, or meets in a signature it
  calls, and nothing beyond that; the tests reach the rest with `@testable`, and
  an internal type's members carry no `public` either.
- **No user-visible literal outside a catalogue**, wherever it is written, and
  in the catalogue of the half that says it. A view never reads the libraries'
  words; one they both say is written in both (design/translation.md).
