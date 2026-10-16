# Layout, layering and style

## Layout

- **One package: four libraries, the helper and the app.** MultishellCore holds
  the model, with user settings under `Model/Settings/`, a repository's
  `.multishell.json` under `Model/Settings/Shared/` and a worktree's tabs and
  panes under `Model/Tabs/`; the store, theme and ports; sessions and their
  reports; the decoding every persisted type leans on; the libraries' word
  lookup; state on disk under `StateOnDisk/`; the command line's requests and
  the app's answers under `Control/`; and under `Support/` the small helpers
  every other library reaches for.
- **MultishellProcess**: the children it starts, how a shell is started and
  quoted, sockets, what the kernel answers about a process, descriptor or
  terminal under `Kernel/`, and under `Support/` what belongs to no concern.
  **MultishellGitKit**: worktree operations, a create's and a removal's each in
  its own folder of `Worktrees/`; a project's hooks and file lists; the output
  readers; what a branch is, where it points and whether it landed; status; the
  runner; and `Support/`. WorktreeGit and WorktreeCoordinator sit at its root
  with their extensions under each concern, since five concerns extend them and
  none owns them, beside the state every WorktreeGit a launch builds shares.
- **MultishellAppCore**: AppModel, detections, dialogs, error mapping, inherited
  settings, what a tab runs, what each session is doing, when to read git and to
  notify, creates and removals under way, every decision a view makes, and what
  a screen reader is told. What it needs from the app and its own
  implementations of Core's ports go under `Ports/`, what Debug Info measures
  and shows under `Debug/`, the JSON the command line prints, its settings keys
  and what a request keeps while it runs under `Control/`, the rest under
  `Support/`.
- **AppModel's extensions sit under `Model/` by concern**, what spans them all
  at the root beside the type: the concerns are too many for one alphabetical
  listing to keep a concern's files together.
- **AppCore's `Integrations/` is the app's own side of them**: the helper and
  shell-integration files it installs, each agent's hooks as installed, and what
  the app's executable hands the helper when started with a command.
- **Everything about a program someone else wrote is in Core's
  `Integrations/`**, one folder per kind: agents, editors, shells, and
  `AgentHookFiles/` for the files hooks are written into. A new agent touches
  the agents folder alone, until someone draws its mark. Its hooks sit under
  `Agents/Hooks/`, and what reads or writes one agent's own files under
  `Agents/Hooks/AgentOwnFiles/`.
- **MultishellCLI is the helper**, built as `multishell-helper` and installed as
  `multishell`, since it and the app would share one products path on a
  case-insensitive disk. Commands that drive the app sit under `Control/` by
  command group with the parsing, polling and errors they share, every usage
  text under `Usage/`, and the reports hooks and shells send under `Reports/`.
  **MultishellAppUI is the app**, built as `Multishell`: views, the engine host,
  the Mac platform port and its own word lookup.
- **Views sit under the part of the window they draw**: sidebar, detail area, a
  group of tabs or a pane, board, Debug Info, a settings window, a dialog. Views
  that draw no part of one go under `Shared/`, or `Settings/Controls/` where
  only the settings windows use them, beside the agent marks, the AppKit
  modifiers and representables reaching under SwiftUI, and the scene and menus.
  The engine host and the platform port each have a folder, the host split by
  what each part is to libghostty: config, runtime, surface, input, clipboard,
  links.
- **What draws nothing sits under `Support/`**, the in-app drag under
  `Support/Drag/`, unless it is by nature a piece of one part: the mark parser
  with the marks, a dialog's AppKit alert with the dialogs, what both settings
  windows share at `Settings/`'s root. Every `Theme+` and `UIMetrics+` extension
  sits under `Support/Appearance/`, whichever part reads it: placed beside their
  parts, they moved back and forth between reviews.
- **AppCore's values for a part of the window sit under the folder its views
  use**, `Sidebar/` or `Terminals/Panes/` for instance, so a view and the
  decision it reads share one path in two targets.
- **A generic extension stays in `Support/` when one concern alone calls it**
  (CLAUDE.md's folder rule); a file moves only when its folder is wrong for what
  it holds.
- **Each half's words live in the target that says them.** The libraries' also
  carry the shell-integration scripts, the app's the agent marks. A second
  frontend is a third.
- **`Resources/` at the root is none of those**: the icon, the Info.plist
  template, the entitlements and the stand-ins under `ghostty/`, which the
  bundling script reads and SwiftPM never sees, and a smaller icon for the
  README.
- **`ThirdParty/` holds what is built rather than written here**: Ghostty as a
  submodule, and the patches the build lays over it. `Scripts/build-ghostty.sh`
  builds it into the GhosttyKit binary target under `.build/ghostty/`, which
  only the app links.
- **A suite's harnesses and fakes stay at its root**, and a file covering
  several concerns is mirrored by the one it spends most of its lines on.
- **What the suites share sits in plain targets**, a test target not being
  dependable on, split by what they drag in: TestScratch, needing only Process
  and Subprocess, which every suite reaches, and TestSupport, needing GitKit,
  for the suites that touch a real repository, so a Core or Process suite does
  not link GitKit for a temporary path.
- **TestScratch starts a child with the runner's own spawn options**, reached
  with `@testable`, so a test's shell and the app's cannot start differently.
- **The app's suite, MultishellAppUITests, reaches TestScratch alone**; its
  model harness is its own.

## Style

- **`swift-format` from the toolchain and SwiftLint, each with its root
  config**; build.md says which rules are off and why.
- **CLAUDE.md's file per type covers an error type, a null object and a test's
  helper too**, a test's helper at the suite's root. A dialog is a `View`
  extension in `View+<Dialog>.swift`, attached by the scene that asked.
- **A call or declaration that wraps puts each argument on its own line, with a
  trailing comma**, so adding or removing one changes one line. Chained calls
  are not split one to a line: that moved `.flatMap {` off its receiver.
- **Tests are swift-testing, one suite to a file named for it.**

## Layering rules

- **The four libraries import only what Apple ships, Foundation, Darwin,
  Dispatch, System, Observation, Synchronization, CryptoKit, CoreGraphics and
  CoreServices, and one package**, swift-subprocess in the process layer
  (dependencies.md). CoreGraphics is there for the `CGRect` a pane's frame comes
  back as, CoreServices for the FSEvents stream the directory watcher runs on.
- **MultishellAppUI is views, AppKit and the engine host.** Everything else
  lives in MultishellAppCore, including a plain value beside a view unless it
  names SwiftUI, AppKit, a Mac measurement or the engine.
- **What the model needs from the desktop goes through the platform port**,
  never a direct AppKit call.
- **Mac only, with no other platform's branches.** Platform code belongs in the
  process layer or a port implementation, never a model or a view.
- **Views call AppModel**, never the store, a host or git. A terminal's view
  comes from the model.
- **Views measure nothing**, and a test lays one out only to hold its size or
  its pixels, in a window never ordered in.
- **The split costs a `public` on every type a frontend or another library
  names, or meets in a signature it calls**, and nothing beyond that; CLAUDE.md
  has the rule.
- **No user-visible literal outside a catalogue**, wherever it is written, and
  in the catalogue of the half that says it. A view never reads the libraries'
  words; one they both say is written in both (design/translation.md).
