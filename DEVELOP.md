# Developing Multishell

## Requirements

Xcode 26 with Swift 6, selected if only the command line tools are active:

    sudo xcode-select -s /Applications/Xcode.app

`git` on `PATH`. The app shells out to it.

## Build, test, run

    make signing-identity  # once per machine, before the first build
    make test              # libraries and model, then the Mac hosts
    make test-app          # compile the macOS app without bundling
    make build             # -> build/Multishell.app; CONFIG=release for optimised
    make run               # build and open it
    make install           # release build to /Applications (INSTALL_DIR= to change)
    make format            # rewrite to the project style; run before reading a diff
    make lint              # what CI runs, --strict: a warning fails

`Scripts/make-app.sh` wraps the SwiftPM binary in a bundle, copies SwiftPM's
resource bundles into `Contents/Resources` (libghostty's terminfo has to be
there), builds the `multishell` helper into `Contents/Helpers`, and signs
both. The version it writes into the bundle is the commit it built from, so
an About panel screenshot in a bug report names the code; a build from a
modified tree is marked `-dirty`. The first app build downloads the
libghostty xcframework, about 80 MB.

`make signing-identity` creates the self-signed `Multishell Dev` certificate
`make-app.sh` signs with; without it it signs ad hoc and says so. Not for
distribution — nothing else trusts it — but so the permissions the user grants
survive a rebuild. See Permissions macOS asks for.

CI builds and tests the libraries on macOS, the app the same, then runs
`make lint`. Nothing compiles the libraries without a GUI framework any
more, so the portability rule is on review rather than on a job.

## Layout

Four Foundation-only libraries in the root package: `MultishellCore` (model,
store, theme, ports), `MultishellProcess` (processes, sockets),
`MultishellGitKit` (worktree operations, parsers, hooks) and
`MultishellAppCore` (`AppModel`, detections, dialogs, error mapping, every
decision a view makes). `MultishellCLI` is the helper. `Apps/macOS` is its
own package: views, the two engine hosts, `MacPlatform`.

## Style

`swift-format` from the toolchain with the root `.swift-format`: 2-space
indent, 100 columns, the standard rules. One type per file, named for the
type; `Type+Concern.swift` for an extension. Tests are swift-testing, named
as sentences about behaviour.

A dialog is a `View` extension in a file named for it, not a type:
`RootView` attaches one line per dialog, and the project settings window
attaches its own removal dialog because a dialog belongs to the scene that
asked for it.

## Rules that CI or tests enforce

- The four libraries import Foundation only: no AppKit, SwiftUI, GTK or
  terminal library, checked by hand in a `swift:6.0` container now that
  Linux is out of CI. `Apps/macOS` holds views and AppKit only; a plain value
  beside a view goes in `MultishellAppCore` and is tested there, and the
  model reaches the desktop only through `Platform`. Views are not tested.
- Mac and Linux only. `#if os(Linux)` or `#if canImport(Darwin)`, in the
  process layer or a port, never in a model or a view. `Paths.swift` is the
  one core file allowed `#if os(...)`.
- Every persisted field decodes with a default, including an unknown enum
  value (`DecodingDefaultsTests`). Worktrees, sessions, tabs and a project's
  shared-hook answers are lossy; projects are strict.
- Every store operation keeps `WorkspaceInvariants` true, and
  `repairReferences` restores references after a load. Extend both, and the
  seeded tests, with any new collection or reference; a failure prints its
  seed and step.
- Runtime state (titles, session states, statuses, live sessions) is
  `AppModel`'s, never the workspace's.
- Nothing in the core blocks a thread. `ProcessRunnerTests` runs 96 children
  at once under a wall-clock bound. `DescriptorExhaustionTests` lowers the
  process-wide limit, so it needs `MULTISHELL_EXHAUST_DESCRIPTORS=1` and a
  `--filter`.
- A closed tab's shell ends and is collected (`SwiftTermHostTests`, real
  shells). Ghostty's path is not covered: its surface needs a window and
  Metal.
- The socket says what a session is doing and who is doing it, and nothing
  else: no tabs opened, no commands run, no text of its own at a prompt. Its
  protocol only adds fields.
- Shell integration is generated per session and never written to a file the
  user owns; `ShellLaunch` and `SessionEnvironment` are the only places that
  decide how a tab's shell starts.
- Git on a timer reads only (`StatusLockTests`): no `commit-tree`, and
  `git fetch` only from a menu item.
- Git is tested against real repositories (`RepositoryFixture`), including a
  bare clone with worktrees beside it. `FakeGit` is only for what real git
  cannot do on demand: print nothing, fail once, run slowly. Parsers get
  fixture text, CRLF and malformed lines included.
- Detection runs against fake executables on a fake PATH, never the machine.
  Hooks run through real shells under a substitute home.
- Timing bounds are sized for a single-core CI runner, many times a laptop's
  figure. Keep that headroom. Where the machine's width is what the bound is
  really about, the runner is the machine it has to hold on
  (`manyConcurrentProcessesDoNotStarveEachOther` says what that costs).

## Adding things

**A theme.** A `.json` in the themes folder (Settings > Appearance > Open
Folder), in `Theme`'s Codable shape. `examples/` there is not loaded.

**A terminal engine.** Implement `TerminalSurfaceHost`, add a case to
`TerminalEngine`, return it from `makeHost()`. Pass
`SessionEnvironment.variables` to the child, report a finished foreground
command through `didFinishCommandIn` if the engine can tell, and frame
`paste` as a bracketed paste where it can.

**An agent or editor.** A row in `AgentCatalogue.agents` or
`EditorCatalogue.editors`; detection and the dropdowns follow.

**A hook stage.** A case in `HookFailure.Stage`, run from
`WorktreeCoordinator` in order, a `PresentedError` title saying whether the
operation happened, an editor in `ProjectHooksTab`, and a step value with its
text.

**A list of files a new worktree is given.** A case in `WorktreePlacement`
with the settings field it reads, a `WorktreeOperation.Step` for its stage
with its titles and the help its Cancel shows, an editor in `ProjectHooksTab`,
and, if a repository may ship it, a field on `SharedProjectSettings` and a
line in `ProjectSettings.layered`. `AppModel` runs one stage per list the
project has filled in, in the enum's own order, before the post-create hook.

**A variable a hook receives.** A case in `HookVariable` with its meaning and
its value. That one list both builds the environment and draws the Hooks
tab's table, so the help cannot fall behind what a hook is given.

**A keyboard shortcut.** Also in `GhosttyTerminalHost.appShortcuts`, or the
surface eats it before the menu sees it.

**A way of ordering worktree rows.** A case in `WorktreeSortOrder` with its
display name, a comparison in `WorktreeOrder.precedes`, and a case in
`WorktreeOrderTests`. Its raw value goes into repositories through
`.multishell.json`, so a new case is free but renaming an existing raw value
breaks a file someone has committed: their order would silently become the
default. The picker in Settings > Worktrees and the override in
Project Settings > General are driven off `allCases`, so both follow, but
their `InfoButton` text does not. Anything an order needs that is not already
on `Worktree` is passed to `sort` as a closure, the way `isActive` and
`lastCommit` are: they read `AppModel`'s runtime state, and the sorter stays
pure. The bands stay: nothing sorts above the trunk row.

**A shell with command-status hooks.** A script under
`Sources/MultishellCore/Resources` with `__MULTISHELL_HELPER__` for the
helper's path, listed in `Package.swift`, loaded by `ShellStateHooks`,
written by `ShellIntegration.refresh` and picked up by `ShellLaunch` (and
`SessionEnvironment` if carried by a variable, as zsh's `ZDOTDIR` is). It
calls `multishell command-started --pid $$` and `command-finished --exit $?
--duration S`, and must do nothing when `MULTISHELL_SESSION` is unset. Add
the name to `ShellCatalogue.searched` if Homebrew installs it without
registering it in `/etc/shells`.

**A platform GUI.** Depend on the four libraries, fix `AppModel<Surface>` to
the platform's view type once, and implement `Platform`,
`TerminalSurfaceHost`, `DirectoryWatcher` (inotify on Linux) and
`SessionNotifier`. `moveToTrash` may delete outright until the platform has a
Trash.

## State on disk

`~/Library/Application Support/Multishell/` on macOS,
`$XDG_CONFIG_HOME/multishell/` on Linux. A debug build uses
`state.debug.json`, `multishell.debug.sock`, `integration.debug/` and
`drops.debug/`; themes and the helper link are shared.

- `state.json`: the sidebar, tabs, pane trees, worktree names, each
  worktree's directory creation date and every setting. Not processes, not
  shell titles, not the shell a tab resolved to, and not a branch's last
  commit time, which is runtime state beside the merge badges.
- `state.<timestamp>.broken.json`: a state file that failed to decode.
- `themes/*.json`, with `themes/examples/` not loaded.
- `multishell.sock`, mode 0600.
- `bin/multishell`: a symlink to the helper in the current bundle, refreshed
  at launch. Hook lines reference this path.
- `integration/`: generated at launch.
- `drops/<uuid>/`: files a drag promised rather than handed over, swept at
  launch once a week old.

Claude Code's hooks live in `~/.claude/settings.json`, written only when
asked, with `settings.json.before-multishell` kept the first time. Sidebar
width is in `UserDefaults`. A repository may carry `.multishell.json` at its
root, written by Export in project settings, with the same keys as a
project's settings — the ones that run nothing included: what its worktrees
open, the order they are listed in, and the files a new one is linked to or
given. It is
read at launch, when a project's worktree records change, and on any tick or
poll where its modification date has moved. A field a repository ships fills
only a gap the user left, so adding one to `SharedProjectSettings` also
means a line in `ProjectSettings.layered`, a decode that costs the key and
not the file, and a form that seeds its override from `InheritedSetting`
rather than from the global. The answer to its hook question is held
against the sha256 of the whole file (`FileDigest`, one answer per file in
`ProjectSettings.sharedHooks`), so any key added to a file someone has
committed asks about its hooks again.

## Permissions macOS asks for

macOS holds the app that spawned a process responsible for what it reads, so
an alert provoked by a command in a pane names Multishell. The usage strings
in `make-app.sh`'s Info.plist are the only place that can say otherwise;
extend them when a pane starts reaching somewhere new.

A grant is keyed to the signature's designated requirement, so an ad-hoc
build's bare cdhash loses every permission at each rebuild and a certificate
keeps them. What a build will be remembered by:

    codesign -d -r- build/Multishell.app

App Management and Full Disk Access are never prompted for, only denied:
`tccd` logs `does not allow prompting for unentitled binaries` and the user
gets "was prevented from modifying apps on your Mac", a notice with no button.
They are added by hand in System Settings. Anything a pane runs that writes
inside an app bundle needs the first, a `make install` of this app included.

A record the requirement no longer matches is ignored rather than consulted,
so a changed identity is simply asked about again. `tccutil reset
SystemPolicyNetworkVolumes io.multishell.app` is for a remembered no, which is
not revisited, or for tidying what the Settings pane shows. Its service names
are the log's less the `kTCCService` prefix, so App Management is
`SystemPolicyAppBundles`.

Which command actually asked, and for what:

    log show --last 1h --predicate 'subsystem == "com.apple.TCC"' --style compact \
        | grep -i multishell

`AUTHREQ_ATTRIBUTION` names the `accessing` process beside `responsible`,
which is always this app.

## Dependencies worth knowing about

- **libghostty** via `Lakr233/libghostty-spm`, pinned to an exact tag because
  the embedding API is not stable. A third-party prebuilt with patches; build
  it from source with its `Script/build.sh` before distributing.
- **SwiftTerm**, pure Swift, no binary.
- `WeightedSplit` uses `_VariadicView`, an underscored SwiftUI API, stable
  for years but not public contract.

## Known gaps

The release bundle runs only on the machine that built it. libghostty finds
its terminfo through SwiftPM's `Bundle.module`, which looks at the root of
the app and then at an absolute path inside `Apps/macOS/.build`, never in
`Contents/Resources`, the only place a signable app can hold it. Elsewhere
`TerminalController()` traps when the first terminal opens. The fix is
building with Xcode, whose accessor looks in the main bundle, or a patched
libghostty-spm.

The Ghostty engine's path is untested, its zsh chain checked only against a
stand-in bootstrap, since libghostty's own file is a build artifact the core
tests cannot reach. Click-to-move works there and nowhere else, and not on
the later lines of a multi-line buffer. Linux has never been compiled at
all, locally or in CI.

The directory check before a click starts a shell runs on the main thread, so
a network volume that has gone away blocks until the mount times out. The
polling paths' checks run off it.

A file list a new worktree is given has no timeout of its own, unlike a
hook: it runs until it is done or the pane's Cancel, which lands between
paths, so one enormous file or folder holds the stage until the file system
is finished with it.

Drops reach `SurfaceFrame` because AppKit walks up from an unregistered
engine surface to the frame that is registered. Apple documents the
registration requirement but not the search order, and if either engine ever
registers a dragged type it becomes the destination and the frame stops
seeing drops. The walk itself is checked only by hand. The sidebar and the
tab strip take no drops.

Sidebar keyboard navigation, tab strip overflow and a shortcut to focus the
filter are not built. No view tests, and the accessibility labels have not
been read with VoiceOver. The existing-branch picker lists local branches
only, so a remote-only branch is created as a new one based on its remote; a
decision, not a defect. `.multishell.json` is read from the project path,
which for a bare repository holds no checkout.
