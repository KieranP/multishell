# Developing Multishell

## Requirements

Xcode 26 with Swift 6. Select it if only the command line tools are active:

    sudo xcode-select -s /Applications/Xcode.app

`git` on `PATH`. The app shells out to it.

## Build, test, run

    make test        # libraries, then the app's pure parts (two swift test runs)
    make test-app    # compile the macOS app without bundling
    make build       # -> build/Multishell.app (debug); CONFIG=release for optimised
    make run         # build and open it
    make install     # release build copied to /Applications (INSTALL_DIR=... to change)

Underneath: `swift test`, `swift build --package-path Apps/macOS`, and
`Scripts/make-app.sh [release]`.

`make-app.sh` wraps the SwiftPM binary in a bundle with an Info.plist, copies
SwiftPM's resource bundles into `Contents/Resources` (libghostty's terminfo
lives there) along with `Multishell.icns`, and ad-hoc signs it. The first app
build downloads the libghostty xcframework, about 80 MB.

CI (`.github/workflows/ci.yml`) has four jobs: the libraries built and tested
on Linux in a `swift:6.0` container, the same on macOS, the app built and its
tests run on macOS, and `make lint`. The Linux job is the enforcement of the
portability rule below.

## Layout

    Package.swift               root package: the three portable libraries
    Sources/
      MultishellCore/           model, store, theme, ports. Foundation only.
        Model/                  Project, Worktree, TerminalTab, TerminalSession,
                                PaneNode, settings, WorktreeStatus,
                                Workspace+Repair (load-time reference repair)
        Store/                  WorkspaceStore (all mutation), WorkspaceSnapshot
                                (JSON on disk), Paths
        Sessions/               SessionRegistry: store <-> TerminalHost
        Ports/                  TerminalHost, DirectoryWatcher (GUI implements)
        Theme/                  Theme, Appearance, ThemeCatalog, hex parsing
      MultishellProcess/        ProcessRunner (handler-driven, never blocks),
                                ShellCommand, ExecutableLookup
      MultishellGitKit/         git worktree ops, porcelain parsers, hooks,
                                WorktreeRecords (what a watcher tick compares)
    Tests/                      one test target per library; RepositoryFixture
                                builds real temp repositories for the git tests;
                                WorkspaceInvariants and a seeded generator drive
                                the randomised store and repair tests
    Apps/macOS/                 SwiftUI app; its own Package.swift
      Sources/Multishell/
        App/                    AppModel and its extension files (the only
                                thing views talk to), commands, delegate,
                                PresentedError
        Sidebar/                project tree, drawn by hand
        Terminals/              hosts (Ghostty, SwiftTerm, MultiEngine),
                                SurfaceView, PaneTreeView + WeightedSplit,
                                SplitMath (divider arithmetic), TabBar
        Sheets/                 new-worktree sheet, project settings window,
                                app settings
        Support/                theme -> Color, UIMetrics, kqueue watcher,
                                ToolbarTabs, title-bar behaviour, WindowAccessor,
                                home-directory abbreviation
      Tests/MultishellTests/    the app's pure parts: AppModel against fake
                                engines and watcher (examples and a seeded
                                random sequence), error mapping, metrics,
                                SplitMath, MultiEngineHost routing, the watcher
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

- `MultishellCore`, `MultishellProcess` and `MultishellGitKit` import
  Foundation only. No AppKit, SwiftUI, GTK, or terminal library. The Linux CI
  job fails if this slips.
- `Paths.swift` is the one file in the core allowed an `#if os(...)`.
  Anything else platform-specific goes behind a protocol in `Ports/` and is
  implemented in the app.
- Every field of every persisted type decodes with a default, and an enum
  value this build does not know falls back rather than failing the file.
  State from an older or a newer build must load. `PersistenceTests` and
  `DecodingDefaultsTests` cover the shapes so far; add a case there when you
  add a field.
- References between collections are repaired after a load by
  `Workspace.repairReferences`, and every store operation must keep
  `WorkspaceInvariants` true. `WorkspaceRepairTests` and
  `WorkspaceStoreInvariantTests` check both, the latter over seeded random
  sequences; extend all three when you add a collection or a reference.
- Nothing in the core blocks a thread. `ProcessRunnerTests` runs 96 children
  at once with a wall-clock bound and counts open descriptors after failed
  launches; `DispatchDirectoryWatcherTests` counts them across 200 re-arms.
- Runtime state that changes without the user (shell titles, activity,
  statuses, live sessions) is `AppModel`'s, not the workspace's.
  `AppModelInvariantTests` checks it agrees with the engine after random
  actions and events.
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
  mocks: creation, removal, hooks, status, remotes, watcher paths.

## Adding things

**A theme.** Drop a `.json` in the themes folder (Settings > Appearance >
Open Folder). The shape is `Theme`'s Codable form; `examples/` in that folder
has the built-ins to copy. Nothing in `examples/` is loaded.

**A terminal engine.** Implement `TerminalSurfaceHost` (the core's
`TerminalHost` plus `view(for:)`), add a case to `TerminalEngine`, and return
it from `TerminalEngine.makeHost()`. `MultiEngineHost` routes each session to
the engine that opened it, so engines coexist.

**A platform GUI.** Depend on the three root libraries. Implement
`TerminalSurfaceHost` for that platform's terminal, `DirectoryWatcher` for its
file events (inotify, ReadDirectoryChangesW), and the views. `AppModel` is
Mac-specific only where it touches NSOpenPanel, NSWorkspace and NSCursor;
most of it is a template for the next platform's equivalent.

## State on disk

macOS: `~/Library/Application Support/Multishell/`. Linux:
`$XDG_CONFIG_HOME/multishell/`. Windows: `%APPDATA%\Multishell\`.

- `state.json`: projects, worktrees, tabs, pane trees, appearance, engine,
  worktree defaults. Not processes, and not the titles shells report; each
  saved tab gets a fresh shell and shows its starting title until that shell
  speaks.
- `state.<timestamp>.broken.json`: a state file that failed to decode, moved
  aside rather than overwritten.
- `themes/*.json`, `themes/examples/`.

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

Sidebar keyboard navigation. Tab strip overflow. A shortcut to focus the
sidebar filter. No automated view tests; the app test target covers only
model-facing code. Linux and Windows have never been compiled locally, and
Docker is not available on the development machine; CI is the first run, and
the `ProcessRunner`, `WorktreeRecords` and repair code has only been audited
for Linux, not built there. `swift-format` output may differ slightly between
the local 6.3 toolchain and the runner's.

Open decisions, not defects: a post-create hook that never exits keeps the
sheet waiting, with no timeout; New Worktree from the menu with several
projects and nothing selected does nothing, silently; the existing-branch
picker lists local branches only, so a remote-only branch is created as a new
one based on its remote.
