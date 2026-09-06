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

Underneath: `swift test`, `swift build --package-path Apps/macOS`, and
`Scripts/make-app.sh [release]`.

`make-app.sh` wraps the SwiftPM binary in a bundle with an Info.plist, copies
SwiftPM's resource bundles into `Contents/Resources` (libghostty's terminfo
lives there) along with `Multishell.icns`, builds the root package's
`multishell` helper into `Contents/Helpers`, and ad-hoc signs both. The first
app build downloads the libghostty xcframework, about 80 MB.

CI (`.github/workflows/ci.yml`) has four jobs: the libraries built and tested
on Linux in a `swift:6.0` container, the same on macOS, the app built and its
tests run on macOS, and `make lint`. The Linux job is the enforcement of the
portability rule below.

## Layout

    Package.swift               root package: the four portable libraries
    Sources/
      MultishellCore/           model, store, theme, ports. Foundation only.
        Model/                  Project, Worktree, TerminalTab, TerminalSession,
                                PaneNode, settings, ProjectIcon (glyph kinds
                                and the curated symbols), WorktreeStatus,
                                SessionState, NotificationPreference,
                                Workspace+Repair (load-time reference repair),
                                LossyArray (element-wise decoding), ShellQuoting
        Store/                  WorkspaceStore (all mutation), WorkspaceSnapshot
                                (JSON on disk), Paths
        Sessions/               SessionRegistry: store <-> TerminalHost;
                                SessionStateReport (the socket protocol),
                                SessionEnvironment (MULTISHELL_* variables)
        Agents/                 AgentCatalogue, ShellCatalogue (the chosen
                                shell's id and resolution), EditorCatalogue
                                (editors by bundle id and shim),
                                ClaudeHookPayload (hook event -> state),
                                ClaudeCodeHooks (settings.json merge),
                                ShellStateHooks (the generated zsh and bash
                                startup files; the hook scripts themselves are
                                Resources/hooks.zsh and Resources/init.bash),
                                ShellIntegration (writes them at launch),
                                ShellLaunch (how a tab's shell is started)
        Ports/                  TerminalHost, DirectoryWatcher, SessionStateSource
                                (GUI implements), NullStateSource
        Theme/                  Theme, Appearance, ThemeCatalog, hex parsing
      MultishellProcess/        ProcessRunner (handler-driven, never blocks),
                                ShellCommand, ExecutableLookup, UnixSocketServer
                                and UnixSocketClient, LoginShellEnvironment,
                                ProcessAncestry (the pid behind a hook)
      MultishellGitKit/         git worktree ops, porcelain parsers, hooks,
                                WorktreeRecords (what a watcher tick compares)
      MultishellAppCore/        the app layer: everything a GUI needs that is
                                not a view or a platform API
        Model/                  AppModel<Surface> and its extension files (the
                                only thing views talk to), ProjectPlacement
        Ports/                  Platform (what the model needs from the
                                desktop: picker, clipboard, file browser,
                                frontmost, key window, application lookup,
                                the bundled helper, a log line), NullPlatform,
                                DispatchDirectoryWatcher (kqueue, Darwin only)
        Terminals/              TerminalSurfaceHost<Surface> (a TerminalHost
                                with a view per session), MultiEngineHost
                                (routes each session to the engine that opened
                                it)
        Detection/              AgentDetection, ShellDetection, EditorDetection,
                                the DetectionOption rows their dropdowns show,
                                the catalogues' display names, ClaudeCodeInstall
        Launch/                 AgentLaunch, EditorLaunch (the command lines)
        States/                 SessionStates (who clears what),
                                NotificationPolicy, the SessionNotifier port
        Dialogs/                PendingClose, PendingProjectRemoval,
                                PendingWorktreeRemoval (what a dialog asks
                                and warns), NewWorktreeRequest, QuitGuard
        Worktrees/              WorktreeOperation (the stage a pane shows),
                                WorktreeOperations (who owns a worktree's
                                entry), RemovalFailure (what a failed stage
                                shows),
                                NewWorktreeDraft (the sheet's decisions)
        PresentedError (error -> title and message, and the alerts the
        model raises itself), SidebarFilter, SplitMath (divider arithmetic),
        HomeAbbreviation, HelperLink (the stable link to the helper),
        SocketStateSource (SessionStateSource over the Unix socket)
      MultishellCLI/            the `multishell` helper: state, command-started,
                                command-finished, claude-hook, install-claude-hooks.
                                Ships in Contents/Helpers.
    Tests/                      one test target per library; RepositoryFixture
                                builds real temp repositories for the git tests
                                and FakeGit stands a shell script in for git;
                                WorkspaceInvariants and a seeded generator drive
                                the randomised store and repair tests;
                                MultishellCLITests runs the built helper against
                                a real socket; MultishellAppCoreTests runs
                                AppModel against fake engines, watcher, channel
                                and desktop (examples and a seeded random
                                sequence) and against real git
                                (AppModelGitTests), and covers detection on
                                fake PATHs, the launch and editor decisions,
                                the session-state clearing rules, the dialog
                                texts, error mapping, the new-worktree draft,
                                the sidebar filter, SplitMath, MultiEngineHost
                                routing, the kqueue watcher (Darwin only) and
                                the socket source driven by a real client
    Apps/macOS/                 SwiftUI app, views and AppKit only; its own
                                Package.swift
      Sources/Multishell/
        App/                    MacPlatform (the Platform port on AppKit),
                                AppModel+Mac (the typealias fixing Surface to
                                NSView, the real dependencies, UIMetrics),
                                commands, delegate
        Sidebar/                project tree, drawn by hand; WorktreeActions,
                                the menu items shared with the detail header
        Terminals/              hosts (Ghostty, SwiftTerm) and the engine
                                factory, SurfaceView, PaneTreeView +
                                WeightedSplit, TabBar, WorktreeOperationView
                                (a hook in progress)
        Sheets/                 new-worktree sheet, app settings,
                                AgentSettingsTab, the project-removal dialog,
                                ProjectSettings/ (the window and one file per
                                tab)
        Support/                theme -> Color, UIMetrics, ToolbarTabs,
                                InfoButton (settings help), IconButton
                                (refresh and reveal), the project icon view,
                                title-bar behaviour, WindowAccessor,
                                UserNotifier (the SessionNotifier port on
                                UNUserNotificationCenter)
      Tests/MultishellTests/    the SwiftTerm host against real shells;
                                metrics and colour derivation
      Resources/Multishell.icns
    Scripts/make-app.sh
    Makefile, .swift-format, .github/workflows/ci.yml

## Style

`swift-format`, which ships in the Swift toolchain, with the project's
`.swift-format` at the root: the toolchain defaults (2-space indent, 100
columns) plus the standard rule set. `make format` rewrites in place;
`make lint` reports and is what CI runs, with `--strict`, so a warning fails
the build. Run `make format` before you look at a diff.

Naming follows the Swift API Design Guidelines. One type per file, named for
the type; `Type+Concern.swift` for an extension file. Tests are swift-testing,
named as sentences about behaviour.

## Rules that CI or tests enforce

- `MultishellCore`, `MultishellProcess`, `MultishellGitKit` and
  `MultishellAppCore` import Foundation only. No AppKit, SwiftUI, GTK, or
  terminal library. The Linux CI job fails if this slips.
- `Apps/macOS` holds views and AppKit only. The model, every decision a
  view makes and the runtime state live in `MultishellAppCore`; a new plain
  value beside a Mac view goes there unless it names AppKit or a Mac
  measurement. What the model needs from the desktop goes through the
  `Platform` port, and `AppModelPlatformTests` checks the model reaches for
  the port rather than the desktop.
- Mac and Linux only. Where the two differ at the API level the branch is
  `#if os(Linux)` (Glibc's rlimit and socket types, `/proc`) or
  `#if canImport(Darwin)` (kqueue, `OPEN_MAX`, `sysctl`); there is no
  Windows branch anywhere.
- `Paths.swift` is the one file in the core allowed an `#if os(...)`.
  Anything else platform-specific goes behind a protocol in `Ports/` and is
  implemented in the app.
- Every field of every persisted type decodes with a default, and an enum
  value this build does not know falls back rather than failing the file.
  State from an older or a newer build must load. `PersistenceTests` and
  `DecodingDefaultsTests` cover the shapes so far; add a case there when you
  add a field. A broken element in `worktrees`, `sessions` or `tabs` is
  dropped and repaired around, never the file (`LossyDecodingTests`);
  projects stay strict.
- References between collections are repaired after a load by
  `Workspace.repairReferences`, and every store operation must keep
  `WorkspaceInvariants` true. `WorkspaceRepairTests` and
  `WorkspaceStoreInvariantTests` check both, the latter over seeded random
  sequences; extend all three when you add a collection or a reference.
- Nothing in the core blocks a thread. `ProcessRunnerTests` runs 96 children
  at once with a wall-clock bound and counts open descriptors after failed
  launches; `DispatchDirectoryWatcherTests` counts them across 200 re-arms.
  A run at the descriptor limit must throw, never read the app's stdin as
  the child's output; `DescriptorExhaustionTests` checks that but lowers the
  process-wide limit, so it runs only with `MULTISHELL_EXHAUST_DESCRIPTORS=1`
  and `--filter DescriptorExhaustionTests`.
- A closed tab's shell ends and is collected. `SwiftTermHostTests` spawns
  real shells through the SwiftTerm engine and checks the title and exit
  code reach the core, that a closed session's shell leaves the process
  table rather than staying a zombie, and that one ignoring SIGTERM is
  killed after the grace. Ghostty's engine needs a window and Metal, so its
  path is not covered.
- Runtime state that changes without the user (shell titles, session
  states, statuses, live sessions) is `AppModel`'s, not the workspace's.
  `AppModelInvariantTests` checks it agrees with the engine after random
  actions, events and socket reports: state keys stay a subset of the live
  shells and known worktrees, and nothing shown carries an unseen Done.
  `SessionStatesTests` pins the clearing rules on the plain value.
- The inbound channel is a Unix socket the user owns, mode 0600, that
  changes a dot and nothing else. `UnixSocketTests` checks the mode, a
  stale file replaced and a live one refused, and a flood dropped;
  `HelperTests` runs the built `multishell` binary against it, including
  the pid walk past two `sh -c` layers, and the generated zsh and bash
  startup files driven through real shells, including a home whose `.zshenv`
  relocates `ZDOTDIR`. `SessionStateReportTests` feeds the parser malformed
  lines. Keep it that narrow: a message must never do more than mark a tab.
- Shell integration is generated per session and never written to a file
  the user owns. `ShellLaunch` and `SessionEnvironment` are the only places
  that decide how a tab's shell starts; a new shell is a case in each plus a
  generated file, not an rc edit.
- Agents and editors are catalogue ids in the store, the shell a path; the
  command line is built when the shell starts (`AgentLaunch`, `EditorLaunch`,
  `AppModel.prepared`, all tested) from the login shell's environment
  (`LoginShellEnvironment`, captured once). `AgentDetectionTests`,
  `ShellDetectionTests` and `EditorDetectionTests` run detection against a
  temp directory of fake executables on a fake PATH, a fake `/etc/shells`,
  and a table standing in for the bundle lookup.
- Timing bounds in tests are sized for a two-core CI runner. Locally each is
  several times under its bound.
- Project and worktree paths are directory URLs, normalised in `init` and in
  `init(from:)` through `Project.directory`. Relative worktree paths resolve
  against them, and `URL(fileURLWithPath:)` alone would ask the filesystem
  whether the path is a directory. A test uses a path that exists nowhere.
- Parsers of git output (`WorktreeListParser`, `WorktreeStatusParser`) are
  pure functions tested on fixture text, including CRLF, paths with spaces,
  an unborn repository, a deleted upstream, and a set of malformed lines that
  must not crash them.
- Git behaviour is tested against real repositories (`RepositoryFixture`), not
  mocks: creation, removal, hooks, status, remotes, watcher paths. `FakeGit`,
  a shell script, is for what real git cannot be made to do on demand:
  print nothing, fail once, or run slowly enough to count concurrency.
- Git on a timer reads only. `StatusLockTests` checks a status poll leaves
  the index untouched (`--no-optional-locks`).
- Hooks run in the project's shell, `$SHELL` unless one is chosen, as an
  interactive login shell and as one script that stops at its first failing
  line where the shell has `set -e`. `HookShellTests`
  checks a hook sees the rc files under a substitute home, for zsh, bash and
  sh, and that a failing middle line stops the rest. A pre hook's failure
  leaves no worktree and no branch; `WorktreeCoordinatorTests` checks both
  stages against a real repository.

## Adding things

**A theme.** Drop a `.json` in the themes folder (Settings > Appearance >
Open Folder). The shape is `Theme`'s Codable form; `examples/` in that folder
has the built-ins to copy. Nothing in `examples/` is loaded.

**A terminal engine.** Implement `TerminalSurfaceHost` (the core's
`TerminalHost` plus `view(for:)`), add a case to `TerminalEngine`, and return
it from `TerminalEngine.makeHost()`. `MultiEngineHost` routes each session to
the engine that opened it, so engines coexist. Pass
`SessionEnvironment.variables` to the child, and report a finished
foreground command through `didFinishCommandIn` if the engine can tell.

**An agent.** Add a row to `AgentCatalogue.agents`: id, display name,
executable, launch arguments, and resume arguments if the agent has them.
Detection and the dropdowns follow.

**An editor.** Add a row to `EditorCatalogue.editors`: id, display name,
whether it is an application or runs in a terminal, its bundle identifier,
and the command line shim that opens a directory. `EditorDetection` finds
it by either and `EditorLaunch` decides what Open in Editor does.

**A hook stage.** Add a case to `HookFailure.Stage`, run it from
`WorktreeCoordinator` in the right order, give `PresentedError` a title that
says whether the operation happened, and an editor in `HooksTab`. A stage
the sheet waits on gets a `WorktreeCreationStep` and its text in
`NewWorktreeDraft.progressText`; one the pane shows gets a
`WorktreeRemovalStep` or a `WorktreeOperation.Step` and its title there.

**A keyboard shortcut.** Also add it to `GhosttyTerminalHost.appShortcuts`,
or the surface consumes the keystroke before the menu bar sees it.

**A shell.** Any shell can already be chosen; this is for giving one the
command-status hooks. Add its script under `Sources/MultishellCore/Resources`
with `__MULTISHELL_HELPER__` for the helper's path, list it in `Package.swift`,
have `ShellStateHooks` load it, write it from
`ShellIntegration.refresh`, and teach `ShellLaunch` (and `SessionEnvironment`
if it is carried by an environment variable, as zsh's `ZDOTDIR` is) how a
tab's shell picks it up. Add its name to `ShellCatalogue.searched` if
Homebrew installs it without registering it in `/etc/shells`. The hooks call `multishell command-started --pid $$`
before a command and `command-finished --exit $? --duration S` at the next
prompt, and must do nothing when `MULTISHELL_SESSION` is unset.

**A platform GUI.** Depend on the four root libraries. Fix the model's
surface type once (`typealias AppModel = MultishellAppCore.AppModel<GtkWidget>`
or the like) and implement four ports: `Platform` for the desktop (picker,
clipboard, file browser, frontmost and key-window checks, application lookup,
the bundled helper, a log line), `TerminalSurfaceHost` for that platform's
terminal, `DirectoryWatcher` for its file events (inotify on Linux; the kqueue
one ships for Darwin), and `SessionNotifier` for its notifications. Then write
the views against `AppModel`. `SocketStateSource`, the model, the states, the
dialogs and the error mapping come ready-made and are tested without a GUI.

## State on disk

macOS: `~/Library/Application Support/Multishell/`. Linux:
`$XDG_CONFIG_HOME/multishell/`.

- `state.json`: projects with their settings (hooks, icon, overrides),
  worktrees, tabs, pane trees, appearance, engine, worktree defaults, the
  default shell, the editor, the agent. A debug build reads and writes
  `state.debug.json` instead, and likewise `multishell.debug.sock` and
  `integration.debug/`, so `make run` does not touch the installed app's
  state or its socket. Not processes, not the titles shells report, and not
  the shell a tab resolved to; each saved tab gets a fresh shell and shows
  its starting title until that shell speaks.
- `state.<timestamp>.broken.json`: a state file that failed to decode, moved
  aside rather than overwritten.
- `themes/*.json`, `themes/examples/`.
- `multishell.sock`: where the running app listens for session-state
  reports. Mode 0600; unlinked on quit, and at launch when nobody answers.
- `bin/multishell`: a symlink to the helper inside the current bundle,
  refreshed at launch. Hook lines reference this path.
- `integration/zsh/` and `integration/bash/init.bash`: generated startup
  files that carry the command-status hooks into the app's terminals only,
  through `ZDOTDIR` for zsh and `--init-file` for bash. Rewritten at launch.

Claude Code's hooks live in the user's own `~/.claude/settings.json`; the
app writes there only when asked, and keeps `settings.json.before-multishell`
beside it the first time.

Sidebar width is in `UserDefaults`; it is about the machine, not the
workspace.

## Dependencies worth knowing about

- **libghostty** via `Lakr233/libghostty-spm`, pinned to an exact tag because
  the embedding API is not stable. It is a third-party prebuilt of Ghostty's
  xcframework with patches; build it from source with its `Script/build.sh`
  before distributing.
- **SwiftTerm**, pure Swift, no binary.
- `WeightedSplit` uses `_VariadicView`, an underscored SwiftUI API, to lay out
  a `ForEach` with explicit sizes. It has been stable for years but is not
  public contract.

## Known gaps

The release bundle runs only on the machine that built it. libghostty finds
its terminfo and shell integration through SwiftPM's generated
`Bundle.module`, which looks for `GhosttyKit_GhosttyTerminal.bundle` at the
root of `Multishell.app` and then at an absolute path inside `Apps/macOS/.build`;
`make-app.sh` puts the bundle in `Contents/Resources`, the only place a
signable app can hold it, where that accessor never looks. On this machine the
build-directory fallback answers; on any other, `TerminalController()` traps
when the first terminal opens. The core's own resources sidestep this by
checking `Contents/Resources` first (`ShellStateHooks.resourceBundle`), but the
Ghostty lookup is the package's. The fix is either building the app with
Xcode, whose accessor looks in the main bundle's resources, or a patched
libghostty-spm that does the same.

Sidebar keyboard navigation. Tab strip overflow. A shortcut to focus the
sidebar filter. No automated view tests; the app test target covers
model-facing code, the SwiftTerm engine and the plain values beside the
views, not layout.
The Ghostty engine's path is untested: its surface needs a window and Metal.
Its shell integration has been seen active by hand (command-finished fires
and the injected zsh hooks run under it), not by a test. The bash init has
been driven on a pty by itself and under Ghostty's bundled bootstrap; the
latter showed the system bash never reads that bootstrap, which is why bash
is launched through `sh` there (see DESIGN.md).
Linux has never been compiled locally, and Docker is not available on the
development machine; CI is the first run, and the `ProcessRunner`,
`WorktreeRecords`, `DescriptorLimit`, `AppModel` and repair code has only
been audited for Linux, not built there. `swift-format` output may differ slightly between
the local 6.3 toolchain and the runner's.

The directory check before a click starts a shell (select, new tab, split)
runs on the main thread. On a local disk it is microseconds; on an SMB or NFS
volume that has gone away it blocks for as long as the mount takes to time
out. The checks the polling paths make run off the main thread
(`AppModel.offMain`), so a dead mount slows a tick rather than the app.

Open decisions, not defects: a pre-create hook that never exits keeps the
sheet waiting, and any other hook that never exits keeps its worktree busy,
with no timeout and no Cancel; the existing-branch picker lists local
branches only, so a remote-only branch is created as a new one based on its
remote.
