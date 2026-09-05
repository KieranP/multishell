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

This is now the Done state of the richer scheme below; engine activity still
raises it, and it still clears when shown.

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


## A terminal's state comes from what runs in it

The engine can say a bell rang or a command finished; only the program in the
terminal can say it is waiting for an answer. So each live session has a
state, `SessionState`: Working, Waiting for input, Done, Failed, or nothing.
The engine's bell and title changes raise Done, as the dot always did, and
Ghostty's command-finished raises Done or Failed by the exit code (a code
above 128 is a signal, usually the user's own Ctrl+C, and is not a failure).
libghostty reports a command finishing but not one starting, and inferring
the start from the title flipped a tab to Working the moment it opened, so
that heuristic was removed: Working comes from a report, not the engine.
Reports from outside the engine set the rest: Claude Code's hooks first
(`UserPromptSubmit`, `PreToolUse`, `PostToolUse` are Working, `Notification`
is Waiting, `Stop` is Done, `StopFailure` is Failed, `SessionStart` and
`SessionEnd` clear), the user's shell through the command-status hooks below,
and any script through the helper's `state` command. The state lives in
`AppModel` (`SessionStates`), never in the workspace.

An agent needs no special case: launching it is a command, so the shell hook
flashes Working, then the agent's own SessionStart reports idle and the dot
returns to grey until a prompt drives its states. A new shell is grey, a
plain command turns it amber, and an agent sitting at its prompt is grey.

Who clears what. Done and Failed are about the user: showing the tab clears
them, and a report of either about the shown tab is already seen; a Failed
is never hidden behind an unseen Done. Working and Waiting are about the
process: they stay while the user looks, because a question the user has
seen but not answered is still waiting. They clear when the source reports
again, when Ghostty's command-finished says the foreground command returned
(the one engine signal that outranks a report), when the process the report
named is gone, or when the user clicks the dot. Engine activity never
downgrades a reported state: an agent retitles its tab on every step.

An agent killed with Ctrl+C sends no Stop hook. The helper reports the pid of
the program that ran it, found by walking past any `sh -c` layers to the
first ancestor that is not a shell, and while any state names a pid the app
checks it every two seconds and drops Working and Waiting once it is gone.
No timeout: a long task is not a stale one.

Colour and place. Working is the theme's yellow (slot 3), Waiting its blue
(slot 4), Done its green (slot 2), Failed its red (slot 1), and a worktree
with nothing running a grey. The sidebar's dirty-files dot is already that
yellow on the right of the row, so the state dot takes the icon's place on
the left rather than sitting beside it as a second dot of the same colour.
A worktree row always shows the dot, so one glance down the sidebar answers
"is anything happening"; a tab keeps its icon until it has a state. A project
row keeps its folder while its worktrees are showing, and takes the most
urgent of their dots only once collapsed, so a state is drawn once and never
both above and below. Urgency, for a tab or worktree with several: Waiting,
then Failed, then Working, then Done.

Cost: two more things to reason about when a tab is closed. Cmd+W on a pane
whose agent reported Working asks first, the way worktree removal does, and
the quit guard counts working agents apart from plain shells.

## The inbound channel is a Unix socket and a small helper

Reports arrive on `multishell.sock` in the state directory, one JSON object
per line with a version field, so a helper left behind by an older install
keeps working against a newer app: fields are only added, and a state this
build does not know costs that line only. The socket is the user's, mode
0600, and what it accepts changes a dot and nothing else: no opening tabs,
no running commands. A report naming a session the app does not know is
dropped, not matched by its directory; one with only a directory that is a
worktree marks the worktree, so a hook fired from Terminal.app in that
directory shows up too.

The shell command-status hooks are the accurate, engine-independent source
of Working and the exit-code Done/Failed. A `preexec`/`precmd` pair calls the
helper's `command-started` and `command-finished --exit $?`; the helper maps
the code. They work under both engines, where the Ghostty finish signal is
absent (SwiftTerm) or the start is not reported at all, and they carry the
real exit code. Both reports run inline: backgrounding them let a fast
command's finished overtake its started, let a fast close skip one, and
printed job notices at the prompt. zsh writes the JSON line to the socket
itself through `zsocket`, so a command line costs two socket writes and no
process, under 2 ms for both here; the helper is its fallback for a zsh built
without `zsh/net/socket`. bash has no such builtin and spawns the helper
twice, about 12 ms each here.
A shell that exits mid-command, `exit` being the usual case, runs preexec but
never the next precmd, so the started report carries the shell's pid for the
watch to clear, and zsh clears at once from a `zshexit` hook.

They are injected per session, silently, with no setting: the app writes
generated startup files under the state directory at every launch. A zsh
session gets `ZDOTDIR` pointed at them, and each generated file chains to the
user's own file first, so their config loads unchanged, then `.zshrc` adds
the hooks and hands `ZDOTDIR` back so a nested shell is untouched. bash has
no `ZDOTDIR`, so a bash tab is launched with `--init-file` naming a generated
init that reproduces the login startup (`/etc/profile`, the first of
`.bash_profile`, `.bash_login`, `.profile`, then `.bashrc`) before adding the
hooks; `ShellLaunch` decides the arguments, and for Ghostty the command
override. The hooks therefore exist only inside these terminals and nothing
is written to the user's rc files; any other shell is launched plainly with
no hooks.

Under Ghostty the bash override goes through `/bin/sh -c 'exec bash …'` on
purpose. Ghostty keys its own bash injection on the command's first word;
handed `bash --init-file X` it swallows the init into `GHOSTTY_BASH_RCFILE`,
adds `--posix` and points `ENV` at its bootstrap, and macOS's bash 3.2 in
that mode reads neither the bootstrap nor, therefore, our init, so nothing
attaches at all. Reproduced on a pty with the bundled bootstrap. `sh` draws
no injection and hands bash our init intact; Ghostty's OSC 133 marks are lost
for bash, which the hooks more than replace. zsh keeps Ghostty's bootstrap,
which chains to our `ZDOTDIR` as it would to a user's.

Why a socket rather than a URL scheme: a URL activates the app, and a hook
fires dozens of times a minute. Why a helper rather than `nc`: quoting, a
stable protocol, and one place to put the Claude mapping. The helper ships
in `Contents/Helpers` and is reached through a symlink at `bin/multishell`
under the state directory, refreshed at launch, so a moved bundle does not
break a hook line. An optional link in `/usr/local/bin`, behind an
administrator prompt, is for people writing their own hooks.

A stale socket file from a crashed instance is unlinked at launch, but only
after a connect to it is refused: one that answers belongs to a running
instance, and stealing its path would leave that instance deaf. The second
instance is told so, once. Every shell the app starts gets
`MULTISHELL_SESSION`, `MULTISHELL_WORKTREE` and `MULTISHELL_SOCKET` in its
environment, which is how a hook names its tab.

## Claude Code's hooks are added, never edited silently

Claude reads hooks from `~/.claude/settings.json`. Settings > Agent shows the
JSON, copies it, and adds it on request, and the helper has the same
subcommand. The merge appends one entry of ours per event and leaves every
other entry, and every other key, as it is; the first write keeps a copy of
the file beside it, since re-serialising changes its formatting. Remove
takes only ours. The section appears only when Claude Code is on the login
shell's PATH; without it, an Install button opens the setup guide and copies
the installer line rather than running anything.

## One login-shell environment, captured once

An app launched from the Finder has PATH set to the system directories, and
every agent people install lives under Homebrew, npm or a version manager.
At launch, off the main thread, the app runs the user's interactive login
shell with `env -0` and keeps the whole environment, so agent detection, the
agent tab and the Claude Code check all read one value; Refresh in the agent
dropdown runs it again. A shell that fails, prints no PATH or takes more than
eight seconds yields the process's own environment, with a line in the log
and the reason in the settings caption. Hooks keep running through the login
shell themselves: the shell's own PATH is the contract there.

## Agents are ids in the store, command lines at launch

The preferred agent is a catalogue id on the workspace, with an optional
override per project where `none` opts a project out and `nil` follows the
global, the pattern the worktree settings use. Ids are strings so a newer
build's agent loads harmlessly on an older one, and a stored id that is no
longer installed is listed in the dropdown marked as such rather than making
the picker go blank.

New Agent Tab (Cmd+Option+T, and a button in the header when an agent is in
force) records the agent id on the session; the command line is built when
the shell starts (`SessionRegistry.reconcile(prepare:)`). It runs through the
user's interactive login shell, `agent; exec $SHELL -l`, so the agent is
found on a terminal's PATH and a shell remains when it quits, keeping the
scrollback; the `exec` comes from `ShellLaunch.execCommandLine`, so that
shell gets the command-status hooks a fresh tab would. A session that came off disk resumes where the catalogue knows
how (`claude --continue`) and is otherwise a plain shell that keeps the
agent's title: four saved agent tabs must not start four agents. An agent
the login shell's PATH does not have opens a plain shell and is reported
once per run, like an unreachable project.

## Notifications are for reports, not for bells

A system notification is posted for a Waiting, Done or Failed report about a
tab the user is not looking at, or any tab while the app is in the
background. Never for Working, and never for engine activity: a bell in a
background tab is a dot. A finished report that carries a duration, which
the shell hooks do, posts nothing under ten seconds: `ls` in a background tab
is not news, a build is. Agent reports carry no duration and always qualify.
Off by default; turning it on in Settings > General is where macOS asks for
permission. A click on the banner selects the worktree and activates the tab.

## Auto-start opens the agent where a shell would have opened

With auto-start on, New Tab (Cmd+T) and the first tab a worktree gets when
selected, which is what follows a create, start the preferred agent instead
of a shell. It is a global toggle with a per-project override, like the agent
itself, and does nothing where no agent is in force. New Shell Tab
(Cmd+Shift+T) always opens a shell so one stays reachable, New Agent Tab
moved to Cmd+Option+T, and splits stay plain shells. The post-create hook
finishes before the worktree appears, so the agent starts after
`npm install`; a failing hook still selects, so it starts with the hook's
alert on top. Nothing else changed: the tab records the agent id and builds
its command line at launch, so a saved agent tab resumes where it can.

## Debug builds keep their own state, socket and integration

A debug build reads and writes `state.debug.json`, listens on
`multishell.debug.sock` and generates `integration.debug/`, decided by
`#if DEBUG` in `Paths`. A `make run` beside the installed app then neither
overwrites its state with the last autosave nor is refused the socket. Themes
are shared, and so is the helper link at `bin/multishell`: Claude's hook
lines reference that one path, and whichever build launched last points it at
its own bundle. The two helpers speak the same protocol and each tab's
`MULTISHELL_SOCKET` names the right socket, so it does not matter which
answers. Cost: `make clean` after a debug run leaves the installed app's
hooks pointing at a bundle that is gone until it relaunches and rewrites the
link.
