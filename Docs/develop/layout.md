# Layout, layering and style

## Layout

- **One package: five libraries, a highlighting library, the helper and the
  app.** MultishellCore holds the model, the store, the theme and ports,
  sessions and their reports, persisted state, the command line's requests and
  the libraries' words. MultishellProcess holds the children it starts, shells,
  sockets and what the kernel answers. MultishellGitKit holds worktree
  operations, hooks and every git read and write. MultishellServices holds the
  pull request hosts and CI providers, read through each service's own tool.
  MultishellAppCore holds AppModel and every decision a view makes.
- **MultishellCLI is the helper**, built as `multishell-helper` and installed as
  `multishell`, since it and the app would share one products path on a
  case-insensitive disk. **MultishellAppUI is the app**, built as `Multishell`:
  views, the engine host, the Mac platform port and its own words.
- **MultishellHighlight is a file tab's colouring**, a target of its own to keep
  the grammars out of the five libraries (Layering rules).
  **TreeSitterScanners** compiles the four scanners copied under
  `ThirdParty/tree-sitter/` and gives Swift nothing (dependencies.md).
- **WorktreeGit and WorktreeCoordinator sit at GitKit's root** with their
  extensions under each concern, since nine concerns extend them and none owns
  them.
- **AppModel's extensions sit under `Model/` by concern**: the concerns are too
  many for one alphabetical listing to keep a concern's files together.
- **Everything about a program someone else wrote is in Core's
  `Integrations/`**, one folder per kind. AppCore's `Integrations/` is the app's
  own side: what it installs and what it hands the helper.
- **Views sit under the part of the window they draw**, and views that draw no
  one part under `Shared/`. What draws nothing sits under `Support/` unless it
  is by nature a piece of one part. Every `Theme+` and `UIMetrics+` extension
  sits under `Support/Appearance/`, whichever part reads it: placed beside their
  parts, they moved back and forth between reviews.
- **AppCore's values for a part of the window sit under the folder its views
  use**, so a view and the decision it reads share one path in two targets.
- **A generic extension stays in `Support/` when one concern alone calls it**
  (CLAUDE.md's folder rule); a file moves only when its folder is wrong for what
  it holds.
- **Each half's words live in the target that says them.** The libraries' also
  carry the shell-integration scripts and the built-in themes, the app's the
  agent marks. A second frontend is a third.
- **A suite's harnesses and fakes stay at its root**, and a file covering
  several concerns is mirrored by the one it spends most of its lines on.
- **What the suites share sits in plain targets**, a test target not being
  dependable on, split by what they drag in: TestScratch, needing only Process
  and Subprocess, which every suite but MultishellHighlightTests reaches, and
  TestSupport, needing GitKit, for the suites that touch a real repository, so a
  Core or Process suite does not link GitKit for a temporary path.
- **TestScratch starts a child with the runner's own spawn options**, reached
  with `@testable`, so a test's shell and the app's cannot start differently.

## Style

- **`swift-format` from the toolchain and SwiftLint, each with its root
  config**; build/compiler-and-lint-strictness.md says which rules are off and
  why.
- **CLAUDE.md's file per type covers an error type, a null object and a test's
  helper too**.
- **A call or declaration that wraps puts each argument on its own line, with a
  trailing comma**, so adding or removing one changes one line. Chained calls
  are not split one to a line: that moved `.flatMap {` off its receiver.
- **Tests are swift-testing, one suite to a file named for it.**

## Layering rules

- **The five libraries import only what Apple ships, Foundation, Darwin,
  Dispatch, System, Observation, Synchronization, CryptoKit, CoreGraphics and
  CoreServices, and one package**, swift-subprocess in the process layer
  (dependencies.md). CoreGraphics is there for the `CGRect` a pane's frame comes
  back as, CoreServices for the FSEvents stream the directory watcher runs on.
- **MultishellHighlight is the one library outside that rule**, importing
  SwiftTreeSitter and the grammars, and only the app imports it; the language
  pick and the capture roles stay plain values in MultishellAppCore.
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
