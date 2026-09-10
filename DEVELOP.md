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
for an extension, and `*Failures.swift` for a group of error types, which go
together rather than under the type that throws them. Tests are swift-testing,
named as sentences about behaviour. A
dialog is a `View` extension in a file named for it, attached by the scene that
asked for it.

## Rules CI and tests enforce

AGENTS.md states the rules; this is what catches a breach.

- Persisted defaults, unknown enum values included: `DecodingDefaultsTests`.
- A state file written before a feature existed still loads with what it said:
  `TabGroupMigrationTests` reads a real pre-columns file, tabs, splits, custom
  titles and its `activeTabByWorktree`, through `WorkspaceStore.restored`.
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
- A shortcut's two spellings agree and the clipboard ones stay with the
  terminal: `AppShortcutTests`, pinned against the config Ghostty was given
  before it was derived.
- Identifiers spelled in both Swift and the generated `Info.plist` still
  match: `BundleDeclarationTests`, reading `make-app.sh` out of the checkout.
  Nothing at build or run time notices these having parted.
- Each override binds to its own setting: `SettingsBindingTests`, since
  `hasOverride` and `overrideValue` take the same arguments and return the
  same type.
- The sidebar's Agents counts agree with the columns they summarise:
  `AgentBoardModelTests` walks every state and both filter positions.
  `agentLaneCounts` counts without building a card, so a shell reporting a new
  prompt does not re-render the sidebar, and two ways of counting can part.
- Foundation-only imports are checked by hand in a `swift:6.0` container, Linux
  being out of CI. Views are not tested, but a value a view reads is.

## Adding things

**A theme.** A `.json` in the themes folder (Settings > Appearance > Open
Folder), in `Theme`'s Codable shape. `examples/` there is not loaded, and an
example already written is not rewritten, so keys added since are only in a
folder seeded after them.

Two keys are not colours the terminal draws. `focusRing` is the line round the
pane the keystrokes go to: a colour, `""` for no line, or the key left out for
the theme's `selectionBackground`, which is what the app drew before the key
existed; an unparsable colour falls back the same way rather than reading as
off. `inactivePaneOpacity` fades every other pane towards the theme's
background, `1` fading nothing and anything under `0.25` clamping to it. Both
are drawn per pane by `PaneTreeView`; see `Theme.focusRingRGB`.

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
naming the file, the events, what each event says the session is doing, and
which of two events standing for one thing is `silent`, moving the dot while
the other raises the banner;
the agent also needs a row in `AgentCatalogue.agents`, since the settings tab
offers hooks for the agents detection found. Four agents hand a command the
same payload on stdin, which `AgentHookPayload` reads and `agent-hook --agent`
maps; one whose file is ours alone is written whole and deleted to remove it.
An agent with no hooks at all needs a `.plugin`, as OpenCode has.

**A variable a hook receives.** A case in `HookVariable`. That one list both
builds the environment and draws the Hooks tab's table, so the help cannot fall
behind.

**A tab strip measurement.** `UIMetrics.tabMinWidth` and `tabMaxWidth` are
what a tab is drawn between, and `TabStripLayout` divides the strip by them:
tabs share it up to the cap, shrink together, and stop at the floor, past
which the strip scrolls and clips. The floor has to leave room for the side
padding, the dot or icon, the gap and the close button with something over for
the title, which `MetricsAndColourTests` checks across the font-size range,
along with `tabArrowWidth` holding its own glyph and two gutters still leaving
room for a tab. `TabStripLayout.Edges` says which end has more past it and
`stepTarget` which tab its arrow scrolls to; `newTabWidth` and the two gutters
come off the room before any of that is asked, so nothing measures itself.

**A column on the Agents board.** A case in `AgentBoardLane`, in the order the
columns are drawn, with its title, the state whose colour its header wears, and
a line in `AgentBoardLane.of`, which is total over `SessionState` so a state
with no column is a compile error. Four columns already need about 1135pt of
window against a 720 minimum; a fifth pushes that to about 1355.

**A fact on a board card.** A field on `AgentBoardCard`, filled in
`AppModel.agentBoardCards`, and a line in `AgentCardView` and in
`AccessibilityText.card`. A fact that comes off a report rather than the
workspace needs a field on `SessionNote` too, written by `SessionStates.report`;
a note carries the state it arrived with and `describing(_:)` is what stops it
being shown once the pane has moved on.

**An item on a card's context menu.** A line in `AgentCardActions`, above
the `Section` if it acts on the pane and inside `WorktreeActions` if it acts
on the worktree, which the sidebar row and the detail header then show too.
Both halves already carry a Clear Status, and the section heading naming the
worktree is what tells them apart.

**A keyboard shortcut.** An `AppShortcut` in `AppShortcuts`, listed in its
`all`, which the menu item and the Ghostty `keybind=…=unbind` are both derived
from. A key Ghostty names rather than takes the character of (tab, enter,
comma, the arrows) needs a case in `ghosttyName`, or the config carries a
private-use scalar Ghostty cannot parse, and a combination the system owns
belongs in `systemOwned` rather than on a menu item: Cmd+Option+D reads as the
third of the split family and is the Dock's own, taken by the WindowServer
before a menu bar sees it. One declared and left out of `all` works everywhere
but a pane. `surfaceKeeps` marks the clipboard combinations, which the
terminal keeps.

**A project icon.** A name in one of `ProjectIcon.symbolGroups`, or a group of
its own. It must exist as far back as macOS 14: the app's deployment target is
`.v14`, and a name that does not resolve draws nothing at all rather than
failing. Check it in
`/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist`,
whose `year_to_release` maps the year beside each symbol to the macOS it
shipped in. `ProjectIconSymbolTests` then resolves every name through AppKit,
which catches a typo but not a symbol too new for the target, the test machine
being newer. Give it a line in `ProjectIcon.searchWords` where its name does
not say what it is for: an SF Symbol is named for the picture, so `cylinder`
is what a search for "database" has to find. Those words are lowercase, and a
test fails on a key that no longer names a symbol. It must also be no more
than twice as wide as it is tall: the sidebar draws it in a square and SwiftUI
does not clip, so a wider one spills over the project's name.
`ProjectIconSymbolTests` measures every one through AppKit.

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

- `state.json`: the sidebar, tabs, the columns they sit in with each column's
  width and active tab, pane trees, worktree names, each worktree's directory
  creation date and every setting. Not processes, shell titles, the shell a tab
  resolved to, or a branch's last commit time. Nor anything about the Agents
  board: whether it is showing and whether it is filtered to agents are runtime
  state on `AppModel`, so the filter is off again after a relaunch — the Dock
  badge counts what its Waiting column shows and has to read the same flag,
  which a view-local `@AppStorage` could not offer it.
  A file written before columns existed names no group on any tab and carries
  an `activeTabByWorktree` this build no longer has a property for: `Workspace`
  reads that key to know which tab was active, and `repairReferences` gathers
  each worktree's ungrouped tabs into the one column they were saved as.
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
`ProjectSettings.layered`, a decode that costs the key and not the file, and an
`OverrideSection` in the tab, seeded from `InheritedSetting`.

Decide too what a blank one means: `Self.text` for a field where "none" and "no
opinion" agree, and nothing for the worktree path, prefix and default branch,
where blank is how "none" is spelled in both files. Getting that wrong is not
cosmetic — a blank hook left uncoerced counts as a hook, and the trust question
asks about an empty script. The answer is held against the sha256 of the whole
file (`FileDigest`, one answer per file in `ProjectSettings.sharedHooks`), so
any key added to a committed file asks again.

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
  The same walk is what carries a dragged tab past a surface to the SwiftUI
  band over it, `SurfaceFrame` being registered for files and promises and not
  for `io.multishell.tab`; if a band never lights, registering the tab type on
  the frame and answering it there is the fallback. The tab strips of every
  column take a tab, and the sidebar's worktree rows take one; nothing else
  does.
- The tab-group drawing is unverified on screen: whether the bands appear as a
  tab crosses a terminal area, whether the insertion line lands in the right
  strip, how a column reads while it has no focus, and whether a strip's
  scroll arrows read as "more tabs this way" any better than the fade they
  replaced. The store, the model
  and the wording are tested; the drawing is not. Nothing is drawn from a flag
  set when the drag began, only from what the pointer is over, so a drag
  released where no target of ours saw it leaves no highlight behind; the cost
  is that the bands are not on screen until the tab reaches a terminal.
- Whether a SwiftUI overlay composites above an engine's surface is unverified
  for Ghostty, whose surface is Metal-backed: the focus ring has always been
  drawn that way and the fade for unfocused panes now is too. If neither
  appears there, both are silent rather than wrong, and the fade would have to
  become a view inside `SurfaceFrame` the way its drop highlight is.
- A tab drag carries no image. AppKit draws the preview for `.onDrag` itself,
  as an elevated card, and holds it on screen for the best part of a second
  after the mouse comes up, wherever the tab landed; nothing in SwiftUI's drag
  API reaches that disposal, and deferring the move out of `performDrop` did
  not change it. So `.onDrag` is given a one-point clear `preview:`, and what
  a drag shows instead is the tab itself: along its own strip it moves as the
  pointer passes its neighbours, and elsewhere it dims where it sits while the
  insertion line, the bands or the sidebar row's highlight say where it would
  land. Bringing a carried image back means
  owning the drag as an AppKit source, where the session's
  `animatesToStartingPositionsOnCancelOrFail` and the image are settable,
  which also means owning the tab's click, double click and middle click.
- Every tab drop still answers the drag before it moves the tab, a turn later
  on the main actor. It made no difference to the preview, but it is the right
  order: the drag ends against the view tree it started in.
- A scrolled tab strip does not scroll itself while a tab is dragged near its
  end, so a tab cannot be dragged past the tabs that are visible: reordering
  reaches only what is on screen, and a tab off the end cannot be dropped on.
  Auto-scroll needs the drop's own pointer position and a repeating step, and
  the strip's `ScrollViewProxy` reaching the drop delegate.
- Reordering inside one column happens as the pointer passes each tab, not on
  release; see `TabShuffle` and `AppModel.shuffleTab`. Unverified on screen is
  how it looks at the edges: a strip whose tabs are of very different widths
  could in principle move a tab back and forth across one boundary, since the
  tab that lands under the pointer is what stops that from happening.
- The Agents board's drawing is unverified on screen: whether a card reads at
  the 208pt column floor, whether a partial column at the edge reads as "more
  this way" without the arrows a tab strip has, whether nesting a vertical
  scroll per column inside the board's horizontal one feels right to a
  trackpad, and whether the Dock badge appears at all under this build's
  signing. The arrangement, the widths, the wording and the badge's count are
  tested in `MultishellAppCore`; the drawing is not. If the partial column does
  not read, the fallback is the tab strip's: an arrow in a gutter at each end
  that has cards past it, from `TabStripLayout.Edges`. Two known divergences
  from the mockup it was drawn from: columns are full height rather than
  hugging their cards, which is what lets each scroll on its own, and the View
  menu item's position within that menu is AppKit's to decide, since it is
  added to the standard group rather than to a menu of ours.
- While the Agents board is up, what acts on a pane does nothing, but what
  acts on a worktree still acts on the selected one — Open in Editor and New
  Worktree — and no sidebar row draws as selected then, so those commands have
  nothing on screen naming their subject. Left as it is because neither is
  destructive; the fix is to route them through `worktreeInView` as the pane
  commands already are.
- Sidebar keyboard navigation and a shortcut to focus the filter are not
  built. No view tests, and the accessibility labels have not been read with
  VoiceOver.
- The existing-branch picker lists local branches only, so a remote-only branch
  is created as a new one based on its remote; a decision, not a defect.
- `.multishell.json` is read from the project path, which for a bare repository
  holds no checkout.
