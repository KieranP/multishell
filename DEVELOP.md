# Developing Multishell

## Requirements

Xcode 26 with Swift 6 (`sudo xcode-select -s /Applications/Xcode.app` if only
the command line tools are active), and `git` on `PATH` — the app shells out to
it.

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
there), builds the helper into `Contents/Helpers`, and signs both. The version
it writes is the commit it built from, `-dirty` for a modified tree. The first
app build downloads the libghostty xcframework, about 80 MB.

`make signing-identity` creates the self-signed `Multishell Dev` certificate;
without it the build signs ad hoc and says so. Not for distribution — it is so
the user's permission grants survive a rebuild.

Every target works the same from a git worktree as from the checkout: the
build directories are the worktree's own, and the version is the worktree's
commit. A debug bundle still shares `state.debug.json` and
`multishell.debug.sock` with every other build on the machine, so `make run`
in two worktrees at once is two apps over one state file. A bundle built in a
worktree also keeps reading its resources from that worktree, which the build
says as it finishes; Known gaps has the why.

CI builds and tests the libraries and the app on macOS, then runs `make lint`.

## Layout

Four Foundation-only libraries in the root package: `MultishellCore` (model,
store, theme, ports), `MultishellProcess` (processes, sockets),
`MultishellGitKit` (worktree operations, parsers, hooks) and
`MultishellAppCore` (`AppModel`, detections, dialogs, error mapping, every
decision a view makes). `MultishellCLI` is the helper. `Apps/macOS` is its own
package: views, the two engine hosts, `MacPlatform`.

## Style

`swift-format` from the toolchain with the root `.swift-format`: 2-space
indent, 100 columns. One type per file, named for the type; `Type+Concern.swift`
for an extension. Tests are swift-testing, named as sentences about behaviour. A
dialog is a `View` extension in a file named for it, attached by the scene that
asked for it.

## Rules CI and tests enforce

CLAUDE.md states the rules; this is what catches a breach.

- Persisted defaults, unknown enum values included: `DecodingDefaultsTests`.
- `WorkspaceInvariants` and `repairReferences`: the seeded random tests, which
  print the failing seed and step. Extend both with any new collection.
- No blocking in the core: `ProcessRunnerTests` runs 96 children under a
  wall-clock bound. `DescriptorExhaustionTests` lowers the process-wide limit,
  so it needs `MULTISHELL_EXHAUST_DESCRIPTORS=1` and a `--filter`.
- A closed tab's shell ends and is collected: `SwiftTermHostTests`, real
  shells. Ghostty's path is not covered — its surface needs a window and Metal.
- Git on a timer reads only: `StatusLockTests`.
- Git behaviour against real repositories, a bare clone with worktrees beside
  it included: `RepositoryFixture`. `FakeGit` is only for what real git cannot
  do on demand; parsers get fixture text, CRLF and malformed lines included.
- Detection runs against fake executables on a fake PATH, never the machine;
  hooks run through real shells under a substitute home.
- Foundation-only imports are checked by hand in a `swift:6.0` container, Linux
  being out of CI. Views are not tested.
- Timing bounds are sized for a single-core CI runner, many times a laptop's
  figure. Keep that headroom.

## Adding things

**A theme.** A `.json` in the themes folder (Settings > Appearance > Open
Folder), in `Theme`'s Codable shape. `examples/` there is not loaded.

**A terminal engine.** Implement `TerminalSurfaceHost`, add a case to
`TerminalEngine`, return it from `makeHost()`. Pass
`SessionEnvironment.variables` to the child, report a finished command through
`didFinishCommandIn` if the engine can tell, and frame `paste` as a bracketed
paste where it can.

**An agent or editor.** A row in `AgentCatalogue.agents` or
`EditorCatalogue.editors`; detection and the dropdowns follow.

**A hook stage.** A case in `HookFailure.Stage`, run from `WorktreeCoordinator`
in order, a `PresentedError` title saying whether the operation happened, an
editor in `ProjectHooksTab`, and a step value with its text.

**A list of files a new worktree is given.** A case in `WorktreePlacement` with
the settings field it reads, a `WorktreeOperation.Step` with its titles and the
help its Cancel shows, an editor in `ProjectHooksTab`, and, if a repository may
ship it, a field on `SharedProjectSettings` and a line in
`ProjectSettings.layered`. `AppModel` runs one stage per filled-in list, in the
enum's order, before the post-create hook.

**An agent's hooks.** An `AgentHookIntegration` in `AgentHooks.integrations`,
naming the file, the events, and what each event says the session is doing;
the agent also needs a row in `AgentCatalogue.agents`, since the settings tab
offers hooks for the agents detection found. Four agents hand a command the
same payload on stdin, which `AgentHookPayload` reads and `agent-hook --agent`
maps; one whose file is ours alone is written whole and deleted to remove it.
An agent with no hooks at all needs a `.plugin`, as OpenCode has.

**A variable a hook receives.** A case in `HookVariable`. That one list both
builds the environment and draws the Hooks tab's table, so the help cannot fall
behind.

**A keyboard shortcut.** Also in `GhosttyTerminalHost.appShortcuts`, or the
surface eats it before the menu sees it.

**A way of ordering worktree rows.** A case in `WorktreeSortOrder` with its
display name, a comparison in `WorktreeOrder.precedes`, and a case in
`WorktreeOrderTests`. Raw values reach repositories through `.multishell.json`,
so a new case is free but renaming one silently turns a committed order into
the default. The picker and the project override follow `allCases`; their
`InfoButton` text does not. Anything not on `Worktree` is passed to `sort` as a
closure, as `isActive` and `lastCommit` are. Nothing sorts above the trunk row.

**A shell with command-status hooks.** A script under
`Sources/MultishellCore/Resources` with `__MULTISHELL_HELPER__` for the
helper's path, listed in `Package.swift`, loaded by `ShellStateHooks`, written
by `ShellIntegration.refresh` and picked up by `ShellLaunch` (and
`SessionEnvironment` if carried by a variable, as zsh's `ZDOTDIR` is). It calls
`multishell command-started --pid $$` and `command-finished --exit $?
--duration S`, and does nothing when `MULTISHELL_SESSION` is unset. Add it to
`ShellCatalogue.searched` if Homebrew leaves it out of `/etc/shells`.

**A platform GUI.** Depend on the four libraries, fix `AppModel<Surface>` to
the platform's view type once, and implement `Platform`,
`TerminalSurfaceHost`, `DirectoryWatcher` (inotify on Linux) and
`SessionNotifier`. `moveToTrash` may delete outright until the platform has a
Trash.

## State on disk

`~/Library/Application Support/Multishell/` on macOS,
`$XDG_CONFIG_HOME/multishell/` on Linux. A debug build uses `state.debug.json`,
`multishell.debug.sock`, `integration.debug/` and `drops.debug/`; themes and the
helper link are shared.

- `state.json`: the sidebar, tabs, pane trees, worktree names, each worktree's
  directory creation date and every setting. Not processes, shell titles, the
  shell a tab resolved to, or a branch's last commit time.
- `state.<timestamp>.broken.json`: a state file that failed to decode.
- `themes/*.json`, with `themes/examples/` not loaded.
- `multishell.sock`, mode 0600.
- `bin/multishell`: a symlink to the helper in the current bundle, refreshed at
  launch. Hook lines reference this path.
- `integration/`: generated at launch.
- `drops/<uuid>/`: files a drag promised rather than handed over, swept at
  launch once a week old.

An agent's hooks live in its own file, written only when asked: Claude Code's
in `~/.claude/settings.json`, Codex's in `~/.codex/hooks.json` and Gemini's in
`~/.gemini/settings.json`, each keeping a `.before-multishell` copy the first
time; Copilot's in `~/.copilot/hooks/multishell.json` and OpenCode's plugin in
`~/.config/opencode/plugin/multishell.js`, both files of ours alone, deleted to
remove them. Sidebar width is in `UserDefaults`.

A repository may carry `.multishell.json` at its root, written by Export in
project settings, with the same keys as a project's settings. It is read at
launch, when a project's worktree records change, and on any tick where its
modification date has moved. A field it ships fills only a gap the user left,
so adding one to `SharedProjectSettings` also means a line in
`ProjectSettings.layered`, a decode that costs the key and not the file, and a
form that seeds its override from `InheritedSetting`. Decide too what a blank
one means: `Self.text` for a field where "none" and "no opinion" agree, and
nothing for the worktree path, prefix and default branch, where blank is how
"none" is spelled in both files. Getting that wrong is not cosmetic — a blank
hook left uncoerced counts as a hook, and the trust question asks about an
empty script. The answer to its hook
question is held against the sha256 of the whole file (`FileDigest`, one answer
per file in `ProjectSettings.sharedHooks`), so any key added to a committed
file asks again.

## Permissions macOS asks for

An alert provoked by a command in a pane names Multishell, macOS holding the
spawning app responsible. The usage strings in `make-app.sh`'s Info.plist are
the only place that can say otherwise; extend them when a pane reaches
somewhere new.

A grant is keyed to the signature's designated requirement, so an ad-hoc
build's bare cdhash loses every permission at each rebuild. What a build will
be remembered by, and which command actually asked:

    codesign -d -r- build/Multishell.app
    log show --last 1h --predicate 'subsystem == "com.apple.TCC"' --style compact \
        | grep -i multishell

`AUTHREQ_ATTRIBUTION` names the `accessing` process beside `responsible`, which
is always this app.

App Management and Full Disk Access are never prompted for, only denied, so
they are added by hand in System Settings; anything a pane runs that writes
inside an app bundle needs the first, a `make install` of this app included. A
record the requirement no longer matches is ignored rather than consulted, so a
changed identity is asked about again. `tccutil reset
SystemPolicyNetworkVolumes io.multishell.app` is for a remembered no; service
names are the log's less the `kTCCService` prefix, so App Management is
`SystemPolicyAppBundles`.

## Dependencies worth knowing about

- **libghostty** via `Lakr233/libghostty-spm`, pinned to an exact tag because
  the embedding API is not stable. A third-party prebuilt with patches; build
  it from source with its `Script/build.sh` before distributing.
- **SwiftTerm**, pure Swift, no binary.
- `WeightedSplit` uses `_VariadicView`, an underscored SwiftUI API.

## Known gaps

- The release bundle runs only on the machine that built it: libghostty finds
  its terminfo through `Bundle.module`, which looks at the app root and then an
  absolute path inside `Apps/macOS/.build`, never `Contents/Resources`, so
  elsewhere `TerminalController()` traps on the first terminal. The fix is
  building with Xcode or a patched libghostty-spm. The same path is why a
  bundle installed from a worktree stops working once that worktree is
  removed: install from the checkout, or rebuild after the removal.
- The Ghostty engine's path is untested, its zsh chain checked only against a
  stand-in bootstrap. Click-to-move works there and nowhere else, and not on
  the later lines of a multi-line buffer.
- Linux has never been compiled, locally or in CI.
- The directory check before a click starts a shell runs on the main thread, so
  a network volume that has gone away blocks until the mount times out. The
  polling paths' checks run off it.
- A file list a new worktree is given has no timeout, unlike a hook: it runs
  until it is done or the pane's Cancel, which lands between paths.
- Drops reach `SurfaceFrame` because AppKit walks up from an unregistered
  engine surface to the frame that is registered — documented behaviour for the
  registration, undocumented for the search order, so if either engine ever
  registers a dragged type the frame stops seeing drops. Checked only by hand.
  The sidebar and the tab strip take no drops.
- Sidebar keyboard navigation, tab strip overflow and a shortcut to focus the
  filter are not built. No view tests, and the accessibility labels have not
  been read with VoiceOver.
- The existing-branch picker lists local branches only, so a remote-only branch
  is created as a new one based on its remote; a decision, not a defect.
- `.multishell.json` is read from the project path, which for a bare repository
  holds no checkout.
