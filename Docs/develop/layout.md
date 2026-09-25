# Layout, layering and style

## Layout

- **One package: four libraries, the helper and the app.** MultishellCore:
  model, store, theme, ports, the libraries' word lookup, and the small
  extensions every other library reaches for.
- **MultishellProcess**: processes and sockets. **MultishellGitKit**: worktree
  operations, the output readers, what a branch is and where it points, and the
  runner above them all.
- **MultishellAppCore**: AppModel, detections, dialogs, error mapping, every
  decision a view makes; what a screen reader is told; and, under `Support/`,
  the pieces that belong to no concern.
- **Everything about a program someone else wrote is in `Integrations/`**, one
  folder per kind: agents, editors, shells, and the JSON reading the agents
  share. Another agent touches the agents folder and no other.
- **MultishellCLI is the helper**, built as `multishell-helper` and installed in
  the bundle as `multishell`, since it and the app would share one products path
  on a case-insensitive disk. **MultishellAppUI is the app**, built as
  `Multishell`: views, the engine host, the Mac platform port, and a word lookup
  of its own.
- **Its views sit under the part of the window they draw.** The rest draw no
  part of one: reused small views, the AppKit modifiers and representables that
  reach under SwiftUI for an event it has no gesture for, the scene and menus.
  What draws nothing at all sits under `Support/`.
- **Each half's words live in the target that says them.** The libraries' also
  carry the shell-integration scripts; the app's also carries the agent marks. A
  second frontend is a third of these.
- **`Resources/` at the root is not one of those**: the icon, the Info.plist
  template and the entitlements, which the bundling script reads and SwiftPM
  never sees.
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

- **`swift-format` from the toolchain with the root config.** One type per file,
  named for the type; a plus-name for an extension, a failures file for a group
  of error types.
- **Two exceptions**: an error thrown from one file alone may sit at its bottom,
  and several small types of one shape only ever read together may share a file
  named for what they are. A `private` helper type is its file's own and stays
  in it; a null object is a type like any other and gets a file.
- **No `MARK` banners**: a file is the grouping. Tests are swift-testing, named
  as sentences about behaviour. A dialog is a `View` extension in a file named
  for it, attached by the scene that asked.

## Layering rules

- **The four libraries import Foundation, System, Observation, Synchronization
  and CryptoKit, which Apple ships, and one package, nothing else**:
  swift-subprocess in the process layer (dependencies.md).
- **MultishellAppUI is views, AppKit and the engine host.** Everything else
  lives in MultishellAppCore, including a plain value beside a view unless it
  names AppKit, a Mac measurement or the engine.
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
  every type a frontend or another library names and nothing beyond that; the
  tests reach the rest with `@testable`, and an internal type's members carry no
  `public` either.
- **No user-visible literal outside a catalogue**, wherever it is written, and
  in the catalogue of the half that says it. A view never reads the libraries'
  words; one they both say is written in both (translation.md).
