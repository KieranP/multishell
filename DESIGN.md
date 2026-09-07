# Design decisions

Why the code is shaped as it is, and what each shape costs. What the code
does is in the code; this records what it does not say. Newest at the bottom.

## The core decides what exists; the GUI decides how it appears

libghostty and SwiftTerm disagree about who owns the pty, and a Linux
frontend will disagree again, so the core never sees a descriptor, a byte
stream or a view. Cost: `AppModel` is a real component carrying the runtime
state the core refuses.

## Reconcile, don't command

One path for tab open, tab close, worktree removed, project removed, process
exited and relaunch. Cost: a session that fails to open is reported and
removed afterwards, not prevented.

## Identity is the path

Worktrees are rediscovered from git on every refresh, and a minted id would
change under persisted selection. Cost: moving a repository on disk is a new
project.

## Shell out to git

libgit2's worktree support is the part it does worst; gitoxide's is
incomplete; the porcelain formats are a stable contract. Cost: git must be
installed, and every operation is a process spawn.

## Tabs own a pane tree, from day one

So that splits, which came later, were a renderer change with no schema
change. Same-axis splits add a sibling and halve the focused pane's share,
as tmux and iTerm do.

## Themes are hex strings

Portability and user theme files for free. Cost: a light terminal gets a
light sidebar whatever the OS mode. A trailing alpha byte, common in exported
themes, is read and ignored rather than turning the slot grey.

## Settings resolve project over global

A team convention set once, with per-repository exceptions. `nil` follows
the global and an empty string overrides to "none"; the cost is making that
distinction visible, which the sheet does with toggles.

The prefix is not applied to an existing branch: prefixing it asked git for
a branch that did not exist. A blank worktree directory means the default,
because the empty path resolved to the repository itself and worktrees
inside the main checkout are untracked files in it. `.`, `..` and an empty
slug become `_` because the path is shown, and its parent created, before
git gets to refuse the name.

## Hooks get context from the environment

Variables rather than arguments, so nothing needs quoting. A post hook's
failure does not roll git back: the worktree exists whether or not the hook
liked it.

The shell is interactive and login (`-l -i`) because `-l` alone misses
`.zshrc`, where many people set PATH, and a Finder-launched app has only the
system PATH, so `npm install` failed for anyone on Homebrew or a version
manager. Cost: a hook pays for the shell's startup, and rc files write to
stderr under `-i` with no terminal (`can't change option: zle`), which used
to be the whole of a failing hook's message; hence the marker line and the
stdout-then-stderr message.

## Watch where git records worktrees, poll for everything else

Never the `.git` root once `worktrees/` exists: `git status` rewrites
`.git/index`, so every status poll became a refresh. Working-tree edits
touch nothing under `.git`, so status is polled, frontmost only, eight at a
time because thirty at once on a large checkout thrash the disk. One
coalesced poll 250 ms after terminal activity, because a prompt raises
several events and each spawned its own `git status`.

`--no-optional-locks`: a plain `git status` takes `index.lock` to refresh
the index, and a `git commit` typed at the wrong moment failed with
"index.lock exists". The flag also keeps the poll from rewriting the index
the records check ignores.

## The dot means "something happened here since you looked"

Neither engine can say "a command is running"; SwiftTerm's local view
swallows even the bell. So engine activity is what Terminal.app's dot is,
cleared when shown, and became the Done state of the richer scheme below.

## Sessions warm up when visited

A saved workspace could imply dozens of shells at launch, so nothing starts
until a worktree is selected.

## Engines coexist

"Next launch" is a poor answer to an engine change. Cost: two renderers the
theme conversion must keep identical, and a command reaches libghostty as
one shell-quoted line but SwiftTerm as an array.

## Persisted state never loses data to a decode error

Silently starting empty and then saving deletes the user's sidebar to fix a
bug of ours. Projects stay strict where the other collections are lossy: a
project is the one thing git cannot give back, and a tab from a newer build
with an unknown pane kind once cost every project.

## The sidebar and the splits are drawn by hand

macOS 26 renders `NavigationSplitView` sidebars as floating glass, and
`HSplitView`/`VSplitView` size children however they like and expose
nothing. Cost: sidebar keyboard navigation has to be built, and
`WeightedSplit` uses `_VariadicView`.

## One workspace window, and `Window` scenes only

Each surface is one `NSView`; a second window would steal it. Project
settings is a `Window` too because a `WindowGroup` adds its own Close
(Cmd+W), and AppKit gives a key equivalent to the first matching item, so
that Close beat Close Pane and shut the app.

## Ghostty keeps its keybinds except the app's own

Unbound by name, not `keybind = clear`, which also removes alt+arrow word
movement and super+backspace.

## Paths are directory URLs, always

`URL(fileURLWithPath:)` asks the filesystem whether a path is a directory,
and a relative worktree path resolved against a URL Foundation took for a
file landed in the parent. It worked where the repository existed and failed
where it did not.

## Errors are mapped, not stringified

The alert is the only place a user learns why something failed, so it gets a
title naming the situation and git's own words, not a struct description.

## A missing directory is refused, not worked around

A shell spawned in a missing directory silently lands in `$HOME`. A project
whose directory is gone stays dimmed rather than dropped: an unmounted drive
must not delete someone's setup, and the failure is reported once because
every tick would otherwise re-raise it.

## Settings windows look like Settings

One settings idiom, the Mac's. SwiftUI gives the toolbar-tab style only to
the `Settings` scene, so project settings hosts `NSTabViewController` in
`.toolbar` style. Cost: `ToolbarTabs`, a small AppKit bridge.

## The headers stand in for the title bar

Both headers are 40 pt and not less: a hidden title bar with a
unified-compact toolbar keeps a 40 pt band (`NSWindow.contentLayoutRect`,
measured: 32 without a toolbar, 52 unified), and a 28 pt header put the tab
strip inside it, where AppKit painted the band's backdrop over it.

## Nothing collapses the sidebar

A collapse toggle existed and was removed: it fought the hidden title bar
(the traffic lights need something under them) and was not worth its edge
cases. Do not add it back without that history.

## Engines are injectable

Protocol plus recording fake is how the engines, the registry, the watcher
and the platform are tested without a terminal or a desktop.

## State is repaired on load, not trusted

Per-field defaults do not cover references between types, and a session no
tab shows would get a shell nothing can close. Cost: a hand edit that breaks
a reference is tidied quietly.

## A project is the main worktree, whatever was picked

A linked worktree lists the same worktrees as its repository, so two rows
would select together and share tabs. Cost: the sidebar shows the
repository's name, not the folder picked.

## A watcher tick checks the records before it runs git

The watched directories also hold each linked worktree's `index`, which
`git status` rewrites, so a status poll after an edit cost one `git worktree
list` per project, and so did every return to the app. Cost: a change git
makes elsewhere waits for the next tick or poll.

## Shell titles are runtime state

A title change used to re-evaluate every view and schedule a save several
times per prompt, for a string a relaunched tab's fresh shell replaces
within a second. Cost: a saved tab shows its starting title until its shell
speaks.

## Nothing in the core blocks a thread

The first `ProcessRunner` waited inside `Task`s. Each wait held a
cooperative-pool thread, one per core, the readers were GCD blocks, GCD ran
out of threads, children blocked on full pipes, and the test suite hung.
Both pipes are drained at once because the second would otherwise fill its
64 KiB buffer and block the child.

The EOFs get one second after the exit and then count as arrived: a hook
like `npm run dev &` exits at once but its server inherits the pipes, and
the sheet waited on the server. Whatever the child itself wrote is read
within milliseconds.

## A closed tab ends its shell, next turn

libghostty no longer frees a surface in the view's `deinit`, and the view
lives as long as any SwiftUI frame that adopted it, so a closed tab's shell
ran on; and on a process exit `close` runs inside libghostty's own callback,
where freeing the surface would free the object mid-call. SwiftTerm sends
SIGTERM and then cancels the monitor that would have reaped the child, so
every closed tab left a zombie; the host reaps with `waitpid` itself. No
signal to a child that already exited: the pid may have been reissued.

## Invariants are tested at random, with seeds

Example tests pin the cases someone thought of; the selection of a worktree
a refresh had just removed was found by a seed. Cost: a failing seed has to
be replayed to understand.

## Running out of descriptors is an error, never an empty answer

launchd gives a GUI app 256 descriptors. At the limit `Pipe()` cannot fail
and returned two handles on descriptor 0, the child wrote to the app's
stdin, the reader saw stdin's EOF at once, `git worktree list` seemed to say
the project had no worktrees, and the store dropped every tab and saved.
Hence the `pipe` syscall, the refused empty list and the raised limit. Cost:
a genuinely empty list, which git never produces, would show an error.

## New Worktree always opens

The menu item with several projects and nothing selected used to do
nothing, silently. The first version of the sheet let a cancelled branch
load re-enable Create against the wrong project's branches, which is why
the draft's decisions are a tested value. The existing-branch picker offers
local branches only because a large repository has hundreds of remote ones
and a picker is the wrong control for that many.

## A terminal's state comes from what runs in it

Only the program in the terminal can say it is waiting for an answer.
Working comes from reports alone: inferring it from the title flipped a tab
to Working the moment it opened. An exit code above 128 is a signal, usually
the user's own Ctrl+C, and not a failure.

Done and Failed are about the user, so showing the tab clears them. Working
and Waiting are about the process, so they stay while the user looks: a
question seen but not answered is still waiting. Ghostty's command-finished
is the one engine signal that outranks a report. An agent killed with Ctrl+C
sends no Stop, so reports carry a pid the app watches; no timeout, because a
long task is not a stale one.

The state dot takes the icon's place on the left because the dirty-files
dot is already yellow on the right, and a project row takes its worktrees'
dots only once collapsed so a state is never drawn both above and below.
Cost: Cmd+W on a Working pane asks first, and the quit guard counts working
agents apart from shells.

## The inbound channel is a Unix socket and a small helper

A socket rather than a URL scheme because a URL activates the app and hooks
fire dozens of times a minute; a helper rather than `nc` for quoting, a
stable protocol and one place for the Claude mapping. Fields are only ever
added so an old helper keeps working. A report naming an unknown session is
dropped rather than matched by directory: the channel is trusted no further
than the tab it can prove.

What a report carries is what the app cannot see for itself. A state and a
pid, because no engine says whether the program in a pty is working or
waiting on the user. A message, because "Claude needs your permission to
use Bash" says more than "waiting". A duration, so a command over in
milliseconds posts no banner. And an `agent`, because which agent a pane
holds is otherwise unknowable: it is usually started by hand at a shell
prompt, so the tab's own `agentID` is nil, and libghostty's foreground-pid
call is a stub on the pinned Ghostty, so there is no process to inspect
either. Claude Code's hooks set it and `multishell state --agent` offers it
to any tool.

What a report may do is unchanged: it moves a dot, raises a notification,
and now decides how a file the user drops on that pane is written — a path
for a shell, a mention for an agent that reads them. It still opens no tab,
runs no command, and puts no text of its own at a prompt; the drop is the
user's gesture, and the report only says who is listening.

The shell reports run inline: backgrounding them let a fast command's
finished overtake its started, let a fast close skip one, and printed job
notices at the prompt. zsh writes through `zsocket` (under 2 ms for both
reports here); bash spawns the helper twice (about 12 ms each).

Injected through `ZDOTDIR` and `--init-file` so nothing is written to the
user's rc files. Under Ghostty bash goes through `/bin/sh -c 'exec bash …'`
because Ghostty keys its own injection on the command's first word: handed
`bash --init-file X` it added `--posix`, under which macOS's bash 3.2 read
neither its bootstrap nor our init, so nothing attached. Reproduced on a
pty with the bundled bootstrap. Ghostty's OSC 133 marks are lost for bash,
which the hooks more than replace.

The helper is reached through a symlink refreshed at launch so a moved
bundle breaks no hook line. A stale socket is unlinked only after a connect
to it is refused: one that answers belongs to a running instance, and
stealing its path would leave that instance deaf.

## Claude Code's hooks are added, never edited silently

The merge appends one entry of ours per event and touches nothing else, and
keeps a copy of the file the first time because re-serialising changes its
formatting.

## One login-shell environment, captured once

Every agent people install lives under Homebrew, npm or a version manager,
none of which a Finder-launched app has on PATH. Eight seconds is the limit
because past that the app would rather run with a poorer PATH than keep the
dropdowns empty.

## Agents are ids in the store, command lines at launch

Ids are strings so a newer build's agent loads harmlessly on an older one.
The command line is `agent; exec <shell> -l` so the agent is found on a
terminal's PATH and a shell remains with the scrollback. A session off disk
resumes rather than starts: four saved agent tabs must not start four
agents.

## Notifications are for reports, not for bells

A bell in a background tab is a dot. A finished report with a duration posts
nothing under ten seconds: `ls` is not news, a build is. Turning it on is
where macOS asks for permission.

## Auto-start opens the agent where a shell would have opened

New Shell Tab always opens a shell so one stays reachable when every New Tab
starts an agent. The first tab is held back until the post-create hook ends
so the agent starts after `npm install`.

## Debug builds keep their own state, socket and integration

So `make run` beside the installed app neither overwrites its state with the
last autosave nor is refused the socket. Themes and the helper link are
shared; both helpers speak the same protocol. Cost: `make clean` after a
debug run leaves the installed app's link pointing at a gone bundle until it
relaunches.

## Pre hooks veto, post hooks report, and a hook is a script

Refusing a create without a ticket number is what a hook is for, and a post
hook cannot refuse. `set -e` goes inside the script, after the rc files have
run, so a chatty `.zshrc` is not what stops it; fish and csh have no such
switch.

## A repository's settings are re-read on their date, not on a git change

`.multishell.json` used to be read only where the worktree records had
moved, so a hook edited while the app was up stayed the version the run
started with, and the create it was written for ran the old script with
nothing on screen to say so. A tick now stats each project's file and reads
only one whose date has moved. Hooks that change under the project on
screen ask for trust there and then, since the next thing the user does may
be the create the edit was for and an untrusted hook does not run; a first
read asks nothing, so a launch still opens without a queue of questions.
The status poll stats it too: the watcher watches `.git`, and a poll's
`git status` carries `--no-optional-locks` precisely so that it writes no
index, so an app sitting frontmost sees no tick at all. Cost: one stat per
project per poll, and a question can now arrive without a click.

## Removing a project asks, in the window that asked

Project settings is its own `Window`, and a dialog on the workspace window
would be behind it.

## A shell is a path in the store, `$SHELL` at launch

`TerminalSession.shell` is left out of its coding keys so a relaunched tab
reads the setting again. Under Ghostty `$SHELL` keeps the engine default,
the path seen to work; a chosen shell is named as the surface's command.
Cost: a shell without `-l -i -c` (nu, xonsh) still gets `/bin/sh` for hooks.

## Open in Editor, and one menu for what acts on a worktree

One `WorktreeActions` view for the header menu and the context menu, so an
action added once appears in both. Terminal editors open as a tab because
one run in the background fails silently with no tty; the custom template
too, since a terminal editor typed there would do the same. VS Code Insiders
answers to `code`, which is why the shim on PATH is the fallback for the
bundle lookup. Cost: an editor tab's command line is saved, so a relaunch
reopens the editor.

## Project icons are descriptions, tinted from the theme

A tint is a theme slot rather than a hex so a theme change keeps the icon in
step with the terminal. Image files were left out: a folder beside
`state.json`, resizing and cleanup on removal.

## Terminal settings have their own tab

The font stays under Appearance with the rest of the look; General keeps
what is about the app or the project itself.

## Help lives behind the (i); captions show live values

The captions doubled every form's height and were read once. A click opens
the same text as a popover because a tooltip alone is easy to miss.

## Selecting a worktree opens a terminal, unless told not to

A person triaging many worktrees wanted to look without starting a shell in
each.

## Removal and the branch are global settings

Whether a removal asks is about the person, not the repository, and a
per-project flag that was off silently made the branch question
unanswerable. The removal still asks about the branch with the confirmation
off because deleting a branch is the one part the sidebar cannot undo. The
branch goes last, after the post-delete hook, so a hook that pushes it still
finds it. Cost: an old project-level flag is read no more.

## A custom shell is a path typed once, an id everywhere

An id rather than the typed path, because the dropdown lists paths it found
and a typed one not among them would show as "not installed" whether it
exists or not.

## A slow hook shows in the pane, not in a modal

`npm install` in a post-create hook held the sheet, and the window, for a
minute; a pre-delete hook did the same with nothing on screen at all. A
failed hook stays on the pane rather than in an alert: an alert raised while
the sheet was still going away was dropped (macOS drops a presentation
started under another), and one raised later landed over whatever the user
had moved on to. Cost: a failed hook holds its worktree until Dismiss.

## The app layer is a library, and the Mac app is views

A Linux frontend would otherwise start by copying the model and nineteen
files out of the Mac app, and "plain values beside the view" was a rule with
no test. The Linux CI job compiles the model with no GUI framework, so an
`NSView` in it fails the build. Windows was dropped: never built, nobody
writing its port. Cost: `public` on every moved type and a `Platform`
conformance per frontend.

## Shell scripts are files, and an operation's owner is a value

The hook scripts were Swift string literals with quadruple backslashes; a
script one can read and lint as shell is a script one can fix. SwiftPM's
`Bundle.module` looks beside the executable and in the build directory, not
in `Contents/Resources` where `make-app.sh` puts bundles, so the core looks
there first. `WorktreeOperations` exists because its ownership rules were
comments in `AppModel`, and the case that motivated it, a removal asked for
during a post-create hook, is now a test.

## A hook is stopped by the clock or by the user, through its process group

`Process.terminate()` did nothing: interactive bash and zsh ignore SIGTERM.
SIGHUP to the shell alone left its `sleep` running: a shell with no terminal
exits on SIGHUP without passing it to the job. `Process` makes each child a
process-group leader, so the group is the shell and everything it started;
SIGKILL follows after three seconds, to the group only, since by then the
leader's pid may have been reissued. The stopper is made before the hook's
task starts because a click that landed first found nothing to stop. The
sheet's Cancel is disabled once git itself runs: there is nothing to stop.

A stopped post-create hook hands the worktree over as a finished one would;
a stopped pre-delete hook leaves the worktree quietly; a stopped or timed
out post-delete hook is reported like a failed one because the worktree is
already gone and the branch was kept. Cost: a hook that traps HUP gets three
seconds it may not use for cleanup.

## A removed worktree goes to the Trash, not through `git worktree remove`

`git worktree remove` refused a dirty tree and its `--force` unlinked the
files, which needed a second dialog and a Remove Anyway, and the one time
someone removes the wrong worktree is the time that matters. Prune takes a
record whose directory has moved at once; the expiry applies only when the
`gitdir` file itself is unreadable. A locked worktree is unlocked first
because prune skips locked records. A Trash that refuses, as on a volume
without a `.Trashes`, falls back to deletion rather than leaving a worktree
the app cannot remove. Cost: on such a volume the recovery the Trash
promised is not there.

## A bare repository is a project

`--is-inside-work-tree` prints `false` for a bare repository, and a bare
clone with its worktrees beside it is a common layout for people who live
in worktrees; `--git-dir` succeeds anywhere inside one. `git status` has no
work tree to read in the bare entry, so it is never asked. A repository
hidden as `proj/.bare` or `proj/.git` takes the name of the folder holding
it because that is the name the layout is known by. Cost: the default
`../{project}-worktrees` lands inside `proj/` for that layout, which usually
wants a per-project path such as `..`.

## A repository can ship its settings, and its hooks are trusted once

The user's own settings win and the file fills the gaps, because a team
default should never override a choice someone made. A whitespace-only hook
is the user's "none", the opt-out shape the prefix already had.

Hooks run code on the say of whoever committed the file, so they wait for a
one-time yes, stored with the exact text so a change asks again. The
question is asked when the user selects one of the project's worktrees, not
when a refresh finds the file: a launch with several projects would open
onto a queue of questions about repositories nobody is looking at, and the
selection that follows a create lands while the sheet is still going away,
where macOS drops the dialog. Export trusts what it wrote: the hooks are the
user's own words. A file that will not parse is a caption and a log line,
not an alert on every refresh. Cost: the layering must be asked of the
model, never read off `project.settings`, and a changed file waits for the
next refresh.

## The terminal font is picked, not typed

Monospaced families first, then a divider and every other family, because
some programming fonts carry ligature and icon glyphs and are not marked
fixed-pitch. A stored name the machine lacks is listed marked rather than
letting the picker go blank, the shape the shell dropdown already had.

## The hand-drawn rows describe themselves

The sidebar and tab strip are plain views, so nothing told a screen reader
what a row was. Each row is one element whose label reads its glyphs in
drawing order. Cost: a string rebuilt per render of a row.

## A worktree's name is the user's, beside the worktrees, not on them

`git worktree list` is the truth about which worktrees exist, and every
refresh replaces the whole list for a project. A name written onto `Worktree`
would be gone on the next tick, so `worktreeNames` is a dictionary on the
workspace keyed by worktree id, next to `activeTabByWorktree`. The store
clears an entry wherever it forgets a worktree, so a removal leaves nothing
in the state file to be inherited by whatever is created at that path next,
and `repairReferences` drops names for worktrees that are not there and
blank ones a hand edit could leave.

The branch is never replaced, only demoted: the sidebar row shows the name
on the first line and the branch under it, and the detail header shows the
branch after the name. Every git command in that directory acts on the
branch, and a row that hid it would be lying about where the user is.

Everywhere else the app names a worktree to the user follows the row: the
detail header, the removal dialog's title and a notification's banner, which
arrives with the app off screen and must match the sidebar they are
picturing. The removal dialog still names the branch and the path in its
body, where the part that cannot be undone belongs.

Which worktree is being renamed is runtime state on `AppModel`, not a flag
on the row. The menu that starts a rename is shared by the sidebar and the
detail header, and only the model is in both places. Cost: a taller row for
a renamed worktree, so the sidebar's drag block measures its rows rather
than counting them.

## A merged branch is inferred from three signs, none of which writes

A worktree whose branch has landed on the default branch can go, and the
sidebar says so with a green merge glyph. Deciding it is the whole feature;
the glyph is the easy half.

`git branch --merged` only finds the branch whose tip the base can reach: a
merge commit or a fast-forward. It also finds every branch that has never
left. `git worktree add -b` cuts a branch at the commit it starts from, so a
worktree is an ancestor of the trunk from the moment it exists, and ancestry
cannot tell "landed" from "never began" — a fast-forwarded branch and a
brand-new one end up on the very same commit. The branch's reflog can: a
branch cut and not committed to has one entry. Where there is no reflog to
ask — a bare repository keeps none unless told to, and entries expire — the
fallback is the case that is certainly fresh, its tip still the base's own.

A rebase-merge and a run of cherry-picks
leave no reachable tip, so the branches `--merged` does not name get a `git cherry`,
which compares patch ids and says whether the base already has every commit
in some other form. A squash merge leaves neither, and the recipe for
finding one — `commit-tree` on the branch's tree with the merge base as
parent, then `git cherry` on the result — writes an object. That write takes
no lock and the object is unreferenced garbage, but this runs on a timer,
and "git on a timer reads only" is a rule worth more than the case it would
buy. What is taken instead is the trace a squash merge leaves for free:
`git for-each-ref` reports `[gone]` for a branch whose upstream has been
deleted, which is what "delete branch on merge" does to it.

That last sign is inference, not proof — a pull request closed without
merging leaves it too — so `WorktreeMergeState.isCertain` separates the
three. The badge appears for all of them; the removal dialog leads with the
button that deletes the branch only for the two that are proof, because that
branch may be the only copy of the work.

Whatever the evidence, the badge is hidden while the worktree holds work
that is only there: uncommitted files, or commits the upstream has not got.
Both would go to the Trash with the directory, and a row that says "this can
go" over them is the one thing this badge must never do. The dialog still
names the branch as merged, because it is: the branch landed, and the files
in the way of removing the worktree are counted separately in its warning.

A git call that fails is not an answer either. `mergedBranches` hands back
`nil` rather than an empty set, and the whole check stops there: taken as an
answer, every branch would be recorded as unmerged and stay that way until
it next moved.

The base is `origin/HEAD` where the clone recorded one, then `origin/main`,
`origin/master`, `main`, `master`, with a per-project override that a
repository may ship in `.multishell.json`. A remote-tracking ref is
preferred over a local branch of the same name: a local `main` is stale
until someone pulls, and what a branch has been merged into is a question
about the remote. An override that resolves to nothing leaves the project
with no base and no badges, rather than quietly measuring against a guess.

It follows that a badge is only as fresh as the last fetch, and fetching on
a timer is not on the table: it is network, it may want credentials, and it
is the one git call here that can hang. Fetch is a menu item instead, in the
project's menu where it belongs and in the worktree actions menu where the
badge is read, and it runs with `GIT_TERMINAL_PROMPT=0` and a timeout so a
repository wanting a password fails rather than waits on a terminal the app
does not have. That failure gets its own words, because it is the likeliest
one and "git fetch failed (129)" would not help anybody set up an SSH key.

It is also the only thing this app does that waits on something outside the
machine, so it is the only thing the sidebar shows waiting: the project's
row spins in the icon's own slot, where the collapsed state dot already
goes, so nothing shifts and no control is taken away. The mark covers the
re-reads that follow the fetch, not just the fetch — the badges are what the
click was for, and stopping the spinner before they moved would be a lie —
and a project already fetching refuses a second one rather than queueing it.

The check rides the status poll rather than the watcher: a commit moves
`refs/heads/<branch>`, which no file `WorktreeRecords` compares mentions, so
nothing else would ever see the last change of a branch land. What it costs
on a tick where nothing moved is one read per project: `origin/HEAD` is a
ref like any other, so `%(symref)` carries it in the same `for-each-ref`
that lists the branches. Each verdict is memoised on the base tip, the
branch and the branch's tip, so a branch that has not moved is not asked
about again.

Riding the poll carries an obligation with it: nothing observable may be
written unless it changed. Putting a dictionary entry back unchanged still
tells every view watching it to draw again, so an unguarded write here would
redraw the whole sidebar every five seconds for nothing. A verdict is also
only recorded when git actually answered — a read that failed brings none,
and stamping the memo for it would pin the stale verdict to the new tip and
never ask again. The branch is in that key and not only its tip: `git checkout -b
copy` leaves two branches on one commit, and only one of them may have an
upstream that has gone.

The main worktree, a bare repository, a detached HEAD and the trunk's own
checkout are never badged. The first cannot be removed, the second has no
checkout, the third has no branch to delete, and the fourth is not merged
into itself — which is what a bare layout's `main` worktree would otherwise
claim.

## Files dropped on a terminal are pasted, never run

A drop is text at the prompt and nothing else. A shell gets absolute paths
quoted for it, what every terminal emulator does; an agent whose prompt reads
mentions gets its prefix and paths relative to the session's directory, which
is what a mention resolves against and what its user would have typed. The
prefix is a catalogue column (`fileMentionPrefix`), set for Claude Code's `@`
and left unset for an agent whose prompt is not known to resolve them, which
then gets a plain path it can still read.

Which agent a pane holds is asked of what reported there, not of the tab: an
agent is usually started by hand at a shell prompt, where the tab's `agentID`
is nil, and a tab opened for one keeps that id long after the agent quit. The
answer comes off the inbound channel (see the section on it) and holds while
the pid that report named is still in the process table, so a pane goes back
to plain paths when its agent exits. A build whose hooks are not installed
hears nothing and falls back to the tab's own id: right for a tab opened as
an agent tab, wrong for a hand-started agent, which gets a plain path that
every agent can still read. Bracketed where the engine can frame
it, a trailing space, and never a newline: the user reads what landed and
presses Return. A name carrying a control character is left out of the drop
altogether, since a newline in a file name would press Return itself and no
quoting reaches through a terminal to stop it. The pane takes focus with the
files, since that is where the next keystroke belongs, and a paste that
reached no pty is reported back to the drag as refused rather than swallowed.
Cost: the mention form is a claim about an agent's prompt, so a wrong column
would leave a stray `@` in front of a path the agent can still read; only file
drags are taken, so something promised but not yet on disk is refused rather
than written to a temporary file; and a file whose name a terminal would act
on has to be typed by hand.
