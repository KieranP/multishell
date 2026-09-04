# Design decisions

Each entry is a decision, the reason, and what it costs. Newest at the bottom.

## The core decides what exists; the GUI decides how it appears

`MultishellCore` holds projects, worktrees, tabs and sessions as values, and
the one place they change (`WorkspaceStore`). The GUI owns every process and
every view. They meet at `TerminalHost`: open, close, focus, restyle a
session. The core never sees a file descriptor, a byte stream or a view.

Why: libghostty and SwiftTerm disagree about who owns the pty, and a Linux
frontend will disagree again. A boundary that leaks either would have to be
redrawn per engine. Cost: the app layer (`AppModel`) is a real component, not
glue; it carries runtime state the core refuses to (activity, statuses, live
sessions).

## Reconcile, don't command

Views never open a terminal. They mutate the store; `SessionRegistry` compares
the store's sessions with the host's open set and opens or closes the
difference. Every state-changing action in `AppModel` ends in `sync()`.

Why: one path for tab open, tab close, worktree removed, project removed,
process exited, and relaunch. Cost: a session that fails to open is reported
and removed after the fact, not prevented.

## Identity is the path

A project is its repository path; a worktree is its directory. Only tabs and
sessions have generated ids.

Why: worktrees are rediscovered from git on every refresh, and a minted id
would change under persisted selection state. Adding the same directory twice
is the same project. Cost: moving a repository on disk is a new project.

## Shell out to git

`git` from `PATH`, porcelain formats, parsed by pure functions.

Why: libgit2's worktree support is the part it does worst; gitoxide's is
incomplete; the porcelain formats are a stable contract. Cost: git must be
installed, and every operation is a process spawn.

## Tabs own a pane tree, from day one

`TerminalTab.root` is a `PaneNode`: a terminal or a split with children and
weights. Before splits shipped every tree was a single leaf.

Why: making splits a renderer change rather than a schema change. It held:
splits arrived without touching persisted state. Same-axis splits add a
sibling and halve the focused pane's share (tmux, iTerm); cross-axis splits
nest.

## Themes are hex strings

`Theme` is sixteen ANSI colours plus background, foreground, cursor and
selection, as hex, Codable. Each GUI converts at its edge. Every chrome colour
derives from the theme (`Theme+SwiftUI`), and the window's appearance follows
the theme, not the system.

Why: portability and user theme files for free. Cost: no per-platform colour
semantics; a light terminal gets a light sidebar whether or not the OS is in
dark mode.

## Settings resolve project over global

`WorktreeSettings` (path template, branch prefix) is one type in two roles:
the app-wide defaults, and a project's effective values after its optional
overrides. Nothing computes a path from `ProjectSettings` directly. `nil`
means follow the global; an empty string is an override of "none". Hooks are
per project only.

Why: a team convention set once, with per-repository exceptions. Cost: the
nil/empty distinction has to be made visible; the sheet uses toggles for it.

## Hooks get context from the environment

Post-create and post-delete hooks are command lines run through the platform
shell with `MULTISHELL_*` variables set. A failing hook is reported and the git
operation is not rolled back.

Why: nothing to quote, and the worktree exists whether or not the hook liked
it. Cost: hook errors are a second alert after a successful create.

## Watch where git records worktrees, poll for everything else

The kqueue watcher covers `.git/worktrees/` and its entries (a linked
worktree's `HEAD` lives there), or the common `.git` only until `worktrees/`
exists. It never watches the `.git` root once it has that folder.

Why: `git status` rewrites `.git/index`, so watching the root turned every
status poll into a refresh. Working-tree edits touch nothing under `.git`, so
`git status` runs every five seconds while the app is frontmost, plus once for
a worktree whose terminal just showed activity. The main worktree's branch
switches, which the watcher cannot see, are caught when the status header's
branch disagrees with the sidebar.

## The dot means "something happened here since you looked"

Neither engine can say "a command is running". Ghostty reports command
finished and progress; SwiftTerm's local view swallows even the bell. Both
report title changes. So the indicator on a background tab or worktree is
activity you have not seen, cleared when the tab is shown, which is also what
Terminal.app's dot means.

## Sessions warm up when visited

Terminals stay alive across worktree switches, so a saved workspace could
imply dozens of shells at launch. Nothing is selected and no shell starts at
launch; a worktree warms when first selected and stays warm. The quit guard
and removal warning count live shells, not saved tabs.

## Engines coexist

`MultiEngineHost` fronts both engines. A session belongs to the engine that
opened it for life; changing the engine in Settings affects the next tab.

Why: switching used to mean "next launch", which is a poor answer. Cost: two
renderers in one window, which the theme conversion has to keep identical.

## Persisted state never loses data to a decode error

Every persisted type decodes each field with a default. A file that will not
decode at all is renamed `state.<timestamp>.broken.json`, the app starts empty
and says where the file went.

Why: the alternative, silently starting empty and then saving, deletes the
user's sidebar to fix a bug of ours.

## The sidebar and the splits are drawn by hand

macOS 26 renders `NavigationSplitView` sidebars as a floating glass panel,
and `HSplitView`/`VSplitView` size children however they like and expose
nothing. Both were replaced: plain views for the sidebar with painted
selection; `WeightedSplit` for panes, laying out from the model's weights and
writing divider drags back so proportions are exact and persist.

Cost: keyboard navigation in the sidebar has to be built rather than
inherited (not yet done), and the split uses `_VariadicView`.

## One workspace window, and `Window` scenes only

The workspace is a `Window` scene, not a `WindowGroup`. Each surface is one
`NSView`; a second window adopting it would steal it from the first. The
project-settings window is a `Window` too, retargeted by the sidebar, for a
different reason: a `WindowGroup` makes SwiftUI add its own Close (Cmd+W) to
the File menu, and AppKit gives a key equivalent to the first matching item,
so that Close beat Close Pane and shut the app.

Commands that act on the workspace check which window is key. Cmd+W in a
settings window closes that window; in the workspace it closes a pane.

## Ghostty keeps its keybinds except the app's own

The surface consumes matching keystrokes before the menu bar sees them, so
the app's shortcuts (`super+t`, `super+w`, `super+d`, `ctrl+tab`, ...) are
unbound in the Ghostty config, by name. Not `keybind = clear`: that also
removes alt+arrow word movement and super+backspace, which make a Mac terminal
feel right.

## Paths are directory URLs, always

`Project.path` and `Worktree.path` go through `Project.directory`, in `init`
and in decoding, which marks them as directories regardless of what is on
disk.

Why: `URL(fileURLWithPath:)` asks the filesystem whether a path is a
directory, and a relative worktree path resolved against a URL Foundation took
for a file lands in the parent. It worked on the author's machine, where the
repository existed, and failed on a path that did not. Cost: none, once seen.

## Errors are mapped, not stringified

`PresentedError` turns each error type into a title that names the situation
and a message in git's own words: stderr for a git failure, "the worktree
exists" for a hook failure, the backup filename for unreadable state, and
plain words for an unborn `HEAD`. A failure that has a stronger form of the
same action (a dirty worktree, `--force`) carries that as a retry button.

Why: the alert is the only place a user learns why something failed.

## A missing directory is refused, not worked around

Selecting a worktree whose directory is gone shows an error instead of opening
a tab; a shell spawned in a missing directory silently lands in `$HOME`.
Removing such a worktree runs `git worktree prune`, since `git worktree remove`
refuses it, and the post-delete hook still runs.

## Worktree removal asks first, per project

The confirmation names the path, says the branch is kept, and adds what the
status badge and live-shell count know: uncommitted files and open terminals.
A project can turn it off in its settings.

## Settings windows look like Settings

Project settings is a window with the toolbar-icon tabs of Multishell >
Settings, closed by its own close button, with fields applied as they change.
SwiftUI gives that tab style only to the `Settings` scene, so the window hosts
`NSTabViewController` in `.toolbar` style, the control that scene wraps.

Why: one settings idiom in the app, and the Mac's. Cost: `ToolbarTabs` is a
small AppKit bridge.

## The headers stand in for the title bar

The title bar is hidden; the sidebar and detail headers occupy its place. A
double-click on either follows the system's "double-click a window's title
bar to" setting (zoom, minimise, nothing), not a hard-coded zoom.

## Nothing collapses the sidebar

A collapse toggle existed and was removed: it fought the hidden title bar
(the traffic lights need something under them) and was not worth its edge
cases. The sidebar is always visible and resizable by its divider. Do not add
it back without that history.

## Engines are injectable

`MultiEngineHost` takes a factory for its engines, defaulting to the real
ones, so its routing is tested with recording fakes. The same shape,
protocol plus recording fake, is how the registry and the watcher are tested.
