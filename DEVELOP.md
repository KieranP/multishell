# Developing Multishell

## Requirements

Xcode 26 with Swift 6. Select it if only the command line tools are active:

    sudo xcode-select -s /Applications/Xcode.app

`git` on `PATH`. The app shells out to it.

## Build, test, run

    make test        # libraries and the model, then the Mac hosts (two swift test runs)
    make test-app    # compile the macOS app without bundling
    make build       # -> build/Multishell.app (debug); CONFIG=release for optimised
    make run         # build and open it
    make install     # release build copied to /Applications (INSTALL_DIR=... to change)
    make format      # rewrite to the project style; run before looking at a diff
    make lint        # what CI runs, --strict: a warning fails

Underneath: `swift test`, `swift build --package-path Apps/macOS`, and
`Scripts/make-app.sh [release]`, which wraps the SwiftPM binary in a bundle,
copies SwiftPM's resource bundles into `Contents/Resources` (libghostty's
terminfo lives there), builds the `multishell` helper into
`Contents/Helpers`, and ad-hoc signs both. The first app build downloads the
libghostty xcframework, about 80 MB.

CI (`.github/workflows/ci.yml`): the libraries built and tested on Linux in
a `swift:6.0` container, the same on macOS, the app built and tested on
macOS, and `make lint`. The Linux job is what enforces the portability rule.

## Layout

Four portable libraries in the root package, each Foundation only:
`MultishellCore` (model, store, theme, ports), `MultishellProcess`
(processes, sockets), `MultishellGitKit` (git worktree operations, parsers,
hooks) and `MultishellAppCore` (the app layer: `AppModel`, detections,
dialogs, error mapping, every decision a view makes). `MultishellCLI` is the
helper that ships in `Contents/Helpers`. `Apps/macOS` is its own package:
views, the two engine hosts and `MacPlatform`. One test target per library;
the Mac target tests the SwiftTerm host against real shells and the plain
values beside the views.

## Style

`swift-format` from the toolchain with the root `.swift-format`: 2-space
indent, 100 columns, the standard rule set. One type per file, named for the
type; `Type+Concern.swift` for an extension file. Tests are swift-testing,
named as sentences about behaviour.

## Rules that CI or tests enforce

- The four libraries import Foundation only: no AppKit, SwiftUI, GTK or
  terminal library. The Linux job fails if this slips.
- `Apps/macOS` holds views and AppKit only. A plain value beside a Mac view
  goes in `MultishellAppCore` unless it names AppKit or a Mac measurement,
  and is tested there; views are not tested. The model reaches the desktop
  only through `Platform` (`AppModelPlatformTests`).
- Mac and Linux only. `#if os(Linux)` or `#if canImport(Darwin)`, in the
  process layer or a port implementation, never in a model or a view.
  `Paths.swift` is the one core file allowed `#if os(...)`.
- Every persisted field decodes with a default, including an enum value this
  build does not know. Add a case to `DecodingDefaultsTests` for each field.
  Worktrees, sessions and tabs are lossy (`LossyDecodingTests`); projects
  are strict.
- Every store operation keeps `WorkspaceInvariants` true, and
  `Workspace.repairReferences` restores references after a load. Extend
  `WorkspaceInvariants`, `WorkspaceRepairTests` and
  `WorkspaceStoreInvariantTests` with any new collection or reference; the
  seeded tests print seed and step on a failure.
- Nothing in the core blocks a thread. `ProcessRunnerTests` runs 96 children
  at once under a wall-clock bound and counts descriptors after failed
  launches. `DescriptorExhaustionTests` lowers the process-wide limit, so it
  runs only with `MULTISHELL_EXHAUST_DESCRIPTORS=1` and `--filter`.
- A closed tab's shell ends and is collected (`SwiftTermHostTests`, real
  shells). Ghostty's path is not covered: its surface needs a window and
  Metal.
- Runtime state (titles, session states, statuses, live sessions) is
  `AppModel`'s, never the workspace's (`AppModelInvariantTests`,
  `SessionStatesTests`).
- The socket says what a session is doing and who is doing it, and nothing
  else: no tabs opened, no commands run, no text of its own put at a prompt
  (`UnixSocketTests`, `HelperTests` on the built binary,
  `SessionStateReportTests` on malformed lines). Its protocol only adds
  fields. `agent` is the newest: it names the agent at a pane's prompt,
  because an agent started by hand leaves the tab's `agentID` nil and
  libghostty's foreground-pid call is a stub on the pinned Ghostty. A file
  the user drops on that pane is written the way that agent reads one
  (`AppModel.agentAtThePrompt`, `ReportedAgent`, `FileDropTests`), and the
  entry lasts only while the pid it named is in the process table.
- Shell integration is generated per session and never written to a file
  the user owns; `ShellLaunch` and `SessionEnvironment` are the only places
  that decide how a tab's shell starts.
- Detection runs against fake executables on a fake PATH, a fake
  `/etc/shells` and a table for the bundle lookup, never the machine.
- Timing bounds in tests are sized for a two-core CI runner, several times a
  laptop's figure. Keep that headroom.
- Git is tested against real repositories (`RepositoryFixture`), including a
  bare clone with worktrees beside it. `FakeGit`, a shell script, is only
  for what real git cannot do on demand: print nothing, fail once, run
  slowly. Parsers are tested on fixture text including CRLF, spaces, an
  unborn repository and malformed lines.
- Git on a timer reads only (`StatusLockTests`). The merged-branch check
  keeps to it: no `commit-tree`, and `git fetch` only from a menu item.
- Hooks are checked through real shells under a substitute home
  (`HookShellTests`), and ending them through real zsh and bash
  (`ProcessStopTests` checks the `sleep` they started is gone too).
- A test path that must not exist on any machine exists nowhere
  (`resolutionDoesNotDependOnTheDirectoryExisting`).

## Adding things

**A theme.** Drop a `.json` in the themes folder (Settings > Appearance >
Open Folder). The shape is `Theme`'s Codable form; `examples/` there has the
built-ins to copy and is not loaded.

**A terminal engine.** Implement `TerminalSurfaceHost`, add a case to
`TerminalEngine`, return it from `TerminalEngine.makeHost()`. Pass
`SessionEnvironment.variables` to the child and report a finished foreground
command through `didFinishCommandIn` if the engine can tell. `paste` puts
text at the prompt, framed as a bracketed paste where the engine can; a file
dropped on a surface arrives that way (`FileDrop`, `AppModel.dropFiles`).

**An agent or editor.** A row in `AgentCatalogue.agents` or
`EditorCatalogue.editors`; detection and the dropdowns follow.

**A hook stage.** A case in `HookFailure.Stage`, run from
`WorktreeCoordinator` in order, a `PresentedError` title that says whether
the operation happened, an editor in `ProjectHooksTab`, and a
`WorktreeCreationStep` or `WorktreeRemovalStep` with its text.

**A keyboard shortcut.** Also in `GhosttyTerminalHost.appShortcuts`, or the
surface eats it before the menu sees it.

**A shell with command-status hooks.** A script under
`Sources/MultishellCore/Resources` with `__MULTISHELL_HELPER__` for the
helper's path, listed in `Package.swift`, loaded by `ShellStateHooks`,
written by `ShellIntegration.refresh`, and picked up by `ShellLaunch` (and
`SessionEnvironment` if carried by a variable, as zsh's `ZDOTDIR` is). Add
its name to `ShellCatalogue.searched` if Homebrew installs it without
registering it in `/etc/shells`. The hooks call `multishell command-started
--pid $$` before a command and `command-finished --exit $? --duration S` at
the next prompt, and must do nothing when `MULTISHELL_SESSION` is unset. An
agent's own hooks report through `multishell state <state> --agent <id>`,
which is what tells a pane running an agent from a pane at a shell prompt;
`multishell claude-hook` is that call with Claude Code's payload mapped to a
state and its id filled in.

**A platform GUI.** Depend on the four libraries, fix `AppModel<Surface>`
to the platform's view type once, and implement `Platform`,
`TerminalSurfaceHost`, `DirectoryWatcher` (inotify on Linux) and
`SessionNotifier`. `Platform.moveToTrash` may delete outright until the
platform has a Trash. Everything else comes ready-made and tested.

## State on disk

macOS: `~/Library/Application Support/Multishell/`. Linux:
`$XDG_CONFIG_HOME/multishell/`. A debug build uses `state.debug.json`,
`multishell.debug.sock`, `integration.debug/` and `drops.debug/` so `make run`
never touches
the installed app's state; themes and the helper link are shared.

- `state.json`: the sidebar, tabs, pane trees, the names given to worktrees
  and every setting. Not processes, not shell titles, not the shell a tab
  resolved to.
- `state.<timestamp>.broken.json`: a state file that failed to decode.
- `themes/*.json`, with `themes/examples/` not loaded.
- `multishell.sock`, mode 0600, unlinked on quit and at launch when nobody
  answers.
- `bin/multishell`: a symlink to the helper in the current bundle, refreshed
  at launch; hook lines reference this path.
- `integration/zsh/`, `integration/bash/init.bash`: generated at launch.
- `drops/<uuid>/`: files a drag promised rather than handed over, one
  directory per drag, swept at launch once a week old.

Claude Code's hooks live in `~/.claude/settings.json`; the app writes there
only when asked and keeps `settings.json.before-multishell` the first time.
Sidebar width is in `UserDefaults`. A repository may carry
`.multishell.json` at its root, written by Export in project settings, with
the same keys as a project's settings in `state.json`. It is read at launch,
whenever a project's worktree records change, and on any watcher tick or
status poll where its modification date has moved.

## Dependencies worth knowing about

- **libghostty** via `Lakr233/libghostty-spm`, pinned to an exact tag because
  the embedding API is not stable. A third-party prebuilt with patches; build
  it from source with its `Script/build.sh` before distributing.
- **SwiftTerm**, pure Swift, no binary.
- `WeightedSplit` uses `_VariadicView`, an underscored SwiftUI API, stable
  for years but not public contract.

## Known gaps

The release bundle runs only on the machine that built it. libghostty finds
its terminfo through SwiftPM's generated `Bundle.module`, which looks at the
root of `Multishell.app` and then at an absolute path inside
`Apps/macOS/.build`, never in `Contents/Resources`, the only place a signable
app can hold it. Elsewhere `TerminalController()` traps when the first
terminal opens. The fix is building with Xcode, whose accessor looks in the
main bundle, or a patched libghostty-spm.

The Ghostty engine's path is untested; its shell integration has been seen
active by hand, not by a test. Linux has never been compiled locally; CI is
the first run. `swift-format` output may differ slightly between the local
6.3 toolchain and the runner's.

The directory check before a click starts a shell runs on the main thread;
on a network volume that has gone away it blocks until the mount times out.
The polling paths' checks run off it (`AppModel.offMain`).

Files are dropped on a terminal through `SurfaceFrame`, which relies on
AppKit walking up from an unregistered engine surface to the frame that is
registered, the same mechanism a table view's row drop rests on. Apple's
documentation states the registration requirement but not the search order,
and neither engine registers a dragged type today; if one ever does, it
becomes the destination and the frame stops seeing drops. The text below it
is tested against a real shell, the walk itself only by hand. A drag that offers a promised file rather than one on
disk, as an image dragged out of a browser does, is refused. The sidebar and
the tab strip take no drops.

Sidebar keyboard navigation, tab strip overflow and a shortcut to focus the
filter are not built. No automated view tests. The accessibility labels have
not yet been read with VoiceOver. The existing-branch picker lists local
branches only, so a remote-only branch is created as a new one based on its
remote; a decision, not a defect. `.multishell.json` is read from the project
path, which for a bare repository holds no checkout.
