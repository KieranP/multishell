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

Paths are normalised once, in `init` and in decoding, and are read-only after
that, so identity reads the stored path rather than standardising it on every
comparison.

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
dark mode. A trailing alpha byte, which exported themes often carry, is read
and ignored rather than turning the slot grey.

## Settings resolve project over global

`WorktreeSettings` (path template, branch prefix) is one type in two roles:
the app-wide defaults, and a project's effective values after its optional
overrides. Nothing computes a path from `ProjectSettings` directly. `nil`
means follow the global; an empty string is an override of "none". Hooks are
per project only.

The branch prefix applies to branches the app creates. An existing branch
chosen in the sheet keeps its name; prefixing it asked git for a branch that
did not exist. A blank worktree directory, global or override, means the
default: the empty path resolved to the repository itself, and worktrees
inside the main checkout are untracked files in it. The worktree path is
always strictly inside the container: `.`, `..` and an empty slug become
`_`, because the path is shown, and its parent created, before git gets to
refuse the name.

Why: a team convention set once, with per-repository exceptions. Cost: the
nil/empty distinction has to be made visible; the sheet uses toggles for it.

## Hooks get context from the environment

Post-create and post-delete hooks are command lines run through the platform
shell with `MULTISHELL_*` variables set. A failing hook is reported and the git
operation is not rolled back.

Why: nothing to quote, and the worktree exists whether or not the hook liked
it. Cost: hook errors are a second alert after a successful create.

The shell is the user's, as an interactive login shell, with `/bin/sh` when
`$SHELL` is unset or missing. An app launched from the Finder has PATH set to
the system directories only, so `npm install`, the example in the settings
window, failed for anyone whose Node came from Homebrew or a version manager.
The terminals in this app are interactive login shells, and a hook should see
what they see; `-l` alone misses `.zshrc`, where many people set PATH. Cost:
a hook pays for the user's shell startup, and rc-file output lands in the
hook's stderr if it fails.

## Watch where git records worktrees, poll for everything else

The kqueue watcher covers `.git/worktrees/` and its entries (a linked
worktree's `HEAD` lives there), or the common `.git` only until `worktrees/`
exists. It never watches the `.git` root once it has that folder.

Why: `git status` rewrites `.git/index`, so watching the root turned every
status poll into a refresh. Working-tree edits touch nothing under `.git`, so
`git status` runs every five seconds while the app is frontmost, at most eight
worktrees at a time, plus once for a worktree whose terminal showed activity,
250 ms after the last event: one prompt raises several (title before, command
finished, title after), and each used to spawn its own `git status`. The main
worktree's branch switches, which the watcher cannot see, are caught when the
status header's branch disagrees with the sidebar.

The poll runs `git --no-optional-locks status`. A plain `git status` refreshes
a stale index and takes `index.lock` to write it back; with up to eight of
those every five seconds, a `git commit` typed in a terminal at the wrong
moment fails with "index.lock exists". The flag is what git added for
background tools, and it also means the poll never makes the index write the
records check exists to ignore. A worktree whose read fails one round keeps
its last badge rather than blinking off; one that is gone loses it.

## The dot means "something happened here since you looked"

Neither engine can say "a command is running". Ghostty reports command
finished and progress; SwiftTerm's local view swallows even the bell. Both
report title changes. So the indicator on a background tab or worktree is
activity you have not seen, cleared when the tab is shown, which is also what
Terminal.app's dot means. A shell exiting can bring another tab into view;
that clears its dot too.

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
A session's command reaches libghostty as one line it hands to a shell, so
the arguments are shell-quoted first (`ShellQuoting`); SwiftTerm takes them
as an array.

## Persisted state never loses data to a decode error

Every persisted type decodes each field with a default, and an enum value
this build does not know (an engine or a split axis from a newer build) falls
back rather than failing the file. A file that will not decode at all is
renamed `state.<timestamp>.broken.json`, the app starts empty and says where
the file went. A save that fails is reported once, not after every change
until the disk is writable again.

Why: the alternative, silently starting empty and then saving, deletes the
user's sidebar to fix a bug of ours.

Within a file, worktrees, sessions and tabs decode element by element and a
broken one is dropped (`LossyArray`); the repair pass then removes whatever
pointed at it. Projects stay strict. A tab from a newer build with a pane
kind this one does not know used to fail the whole file and so cost every
project; now it costs that tab, which was going to get a fresh shell anyway,
and worktrees are re-read from git on the first refresh. A project is the one
thing the user cannot get back from git, so a broken one still moves the
file aside and says so.

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
a tab, and so do New Tab and Split in one that was selected while it existed;
a shell spawned in a missing directory silently lands in `$HOME`. Removing
such a worktree runs `git worktree prune`, since `git worktree remove` refuses
it, and the post-delete hook still runs.

A project whose directory is gone, or whose repository git cannot read, stays
in the sidebar dimmed rather than being dropped: an unmounted drive must not
delete someone's setup. The failure is reported once, not on every watcher
tick and every return to the foreground; a Refresh the user asks for reports
it again.

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

## State is repaired on load, not trusted

After a decode, `Workspace.repairReferences` drops worktrees whose project is
gone, tabs whose worktree is gone, panes whose session is missing, and
sessions no tab owns; it fixes an active-tab entry that points at a missing
tab and a focused pane outside its tree. A project, worktree or session
listed twice keeps its first entry; a session shown in two panes keeps its
first; a nested split left with one child collapses into it and one with
none disappears. `PaneNode` decodes weights that are absent or misaligned as
equal shares, and `Theme` refuses a file without exactly sixteen ANSI
colours.

Why: a session no tab shows would be given a shell that nothing displays and
nothing can close, and a missing active tab hid the whole tab strip. Each
persisted type decoding its own fields with defaults does not cover the
references between them. Cost: a hand edit that breaks a reference is quietly
tidied rather than reported.

## A project is the main worktree, whatever was picked

Adding a subdirectory or a linked worktree resolves, through `git worktree
list`, to the repository's main worktree before it becomes a project.

Why: identity is the path, and a linked worktree lists the same worktrees as
its repository, so both rows would select together and share tabs. Cost: the
sidebar shows the repository's name, not the folder the user chose.

## A watcher tick checks the records before it runs git

The watched directories hold each linked worktree's `index`, which `git
status` rewrites after any edit. A tick first reads the files `git worktree
list` is derived from (`HEAD`, `worktrees/*/HEAD`, `gitdir`, `locked`) and
refreshes only the projects where they differ from the last refresh. Coming
back to the foreground takes the same path. The common `.git` path is asked
of git once per project and cached; a project without it, or without records
yet, is refreshed in full.

Why: a status poll after an edit otherwise cost one `git worktree list` per
project, and so did every return to the app. Cost: a change git makes
elsewhere goes unnoticed until the next tick or the status poll, which is
already the contract for the main worktree's `HEAD`.

## Shell titles are runtime state

What a shell reports through OSC lives in `AppModel.sessionTitles`, not in
the workspace. `TerminalSession.title` is the starting title only ("Shell",
or the command's name) and `TerminalTab.customTitle` the user's.

Why: the workspace is one observed value, so a title change re-evaluated
every view and scheduled a save, several times per prompt, for a string a
relaunched tab's fresh shell replaces within a second anyway. After this the
workspace changes only when the user does something. Cost: a saved tab shows
its starting title until its shell speaks.

## Nothing in the core blocks a thread

`ProcessRunner` drains a child's pipes with readability handlers and learns
of its exit from the termination handler; the caller awaits a continuation.
Both pipes are read at once, because whichever is read second can fill its
64 KiB buffer and block the child. A launch that fails releases its pipes.

Why: the first version waited inside a `Task`. Each wait held a
cooperative-pool thread, one per core, and the readers were GCD blocks; with
enough concurrent `git status` calls GCD ran out of threads for the readers,
the children blocked on full pipes, and the waits never returned. The test
suite hung. Cost: the exit and the two EOFs are three events that must all
arrive; a `DispatchGroup` counts them.

The EOFs are given one second after the exit, then counted as arrived. A
hook such as `npm run dev &` exits at once but its server inherits the pipes
and holds them open for as long as it runs, so the sheet waited on the
server. Whatever the child itself wrote is in the pipe when it exits and is
read within milliseconds; only a descendant can add more, and that is not the
hook's output.

## A closed tab ends its shell, next turn

`GhosttyTerminalHost.close` detaches the view's controller, which tears the
surface down, closes the pty and ends the shell. It does so on the next
main-loop turn, not inline. `SwiftTermTerminalHost.close` sends SIGTERM,
except to a child that already exited.

Why: libghostty no longer frees a surface in the view's `deinit`, and the
view lives as long as any SwiftUI frame that adopted it, so a closed tab's
shell ran on. On a process exit, `close` runs inside libghostty's own close
callback, and freeing the surface there would free the object mid-call.
SwiftTerm keeps the reaped pid, and a signal to it could reach whatever the
kernel reissued the number to. Cost: a one-turn delay nobody can see.

After SwiftTerm's `terminate`, the host collects the child itself with
`waitpid`, off the main thread, and sends SIGKILL to one still there five
seconds later. SwiftTerm sends SIGTERM and then cancels the monitor that
would have reaped the child, so every closed tab left a zombie until the app
quit, and a shell that trapped TERM without exiting ran on.

## Invariants are tested at random, with seeds

`WorkspaceInvariants` states what must hold between the workspace's
collections. Seeded tests run hundreds of random store operations, random
model actions and engine events, random damage through the repair pass, and
random routing through the engine composite, checking the invariants after
every step. A failure prints its seed and step.

Why: example tests pin the cases someone thought of; the selection of a
worktree a refresh had just removed was found by a seed, not by reading.
Cost: a failing seed has to be replayed to understand, and the tests run a
few hundred milliseconds rather than a few.

## Running out of descriptors is an error, never an empty answer

`ProcessRunner` makes its pipes with the `pipe` syscall and throws when that
fails. `WorktreeService.list` refuses an empty list. The app raises its soft
descriptor limit to the kernel's ceiling at launch.

Why: launchd gives a GUI app 256 descriptors. Each watched worktree directory
holds one, each live shell a pty and its engine's pipes, each concurrent
`git status` six. At the limit `Pipe()` cannot fail and returned two handles
on descriptor 0, so the child wrote to the app's stdin, the reader saw
stdin's EOF at once, and `git worktree list` seemed to say the project had no
worktrees. The store took that as truth and dropped every tab and shell of
the project, then saved. Cost: a project with a genuinely empty list, which
git never produces, would show an error instead.

## New Worktree always opens

The sheet has a project picker. From the sidebar it is preset to that row's
project; from the menu it is preset to the selected worktree's project, or
the only project, and otherwise starts blank. With no projects at all the
sheet says so.

Why: the menu item with several projects and nothing selected did nothing,
silently, because the sheet needed a project to exist. Cost: one more row in
the sheet, and the sheet's decisions moved out of the view into
`NewWorktreeDraft` so that a project switch mid-load could be tested; the
first version let a cancelled load re-enable Create against the wrong
project's branches.

The existing-branch picker offers local branches not checked out, and only
those: a large repository has hundreds of remote branches, and a picker is
the wrong control for that many. A fresh clone has only `main` locally, so
the list was empty with nothing to say why; it now says every local branch
is checked out already and points at New branch, where a remote branch can
be named as the base.

