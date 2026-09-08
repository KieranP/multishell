# Design decisions

Why the code is shaped as it is, and what each shape costs. What the code
does is in the code; this records what it does not say. Newest at the bottom.

## The core decides what exists; the GUI decides how it appears

libghostty and SwiftTerm disagree about who owns the pty, and a Linux
frontend will disagree again, so the core never sees a descriptor, a byte
stream or a view. `AppModel` carries the runtime state the core refuses, and
lives in a library rather than the Mac app so a Linux frontend need not copy
it out; a Linux CI job compiled it with no GUI framework, which is what
enforced that until the job was dropped. Windows went the same way: never
built, nobody writing its port. Cost: `public` on every moved type and a
`Platform` conformance per frontend.

## Reconcile, don't command

One path for tab open, tab close, worktree removed, project removed, process
exited and relaunch. Cost: a session that fails to open is reported and
removed afterwards, not prevented.

## Identity is the path

Worktrees are rediscovered from git on every refresh, and a minted id would
change under persisted selection. Cost: moving a repository on disk is a new
project.

## Shell out to git

libgit2's worktree support is the part it does worst, gitoxide's is
incomplete, and the porcelain formats are a stable contract. Cost: git must
be installed and every operation is a process spawn.

## Tabs own a pane tree, from day one

So splits, which came later, were a renderer change with no schema change.
Same-axis splits add a sibling and halve the focused pane's share, as tmux
and iTerm do.

## A tab dragged to a worktree moves, it does not re-open

Dropping a tab on a worktree's row in the sidebar relists it there. The
shells keep running: nothing is restarted, and no `cd` is typed at a prompt
on the user's behalf here any more than it is on the socket's word. What
moves with the tab is where its panes start and which shell they start,
which are read together at launch and are both the destination's to decide;
a tab left pointing at the directory it came from would open one project's
shell in another project's checkout on the next launch.

A tab whose shells are live is turned to when it lands, which is also what
makes the destination warm: leaving it cold would have the next reconcile
close the very shells that were dragged there.

The drag carries its own pasteboard type rather than the plain text a project
is dragged as, because the sidebar already drags projects to reorder them:
with one type for both, a worktree row would light up for a project it cannot
take, and swallow the drop that was meant to move the project.

The store keeps a session's worktree in step with its tab's, since that is
what decides whether a shell runs at all. `repairReferences` puts a file that
disagrees back to what the tab says.

Cost: a moved tab's shell is still in the directory it was started in until
the user cds, so a file dropped on it is written against the worktree the tab
now belongs to rather than where that shell stands — the same approximation
the app already makes for anyone who has cd'd. A worktree with no tabs left
loses what was on screen, since the tab it was showing is somewhere else.

## Themes are hex strings

Portability and user theme files for free. Cost: a light terminal gets a
light sidebar whatever the OS mode.

## Settings resolve project over global, and a repository may ship its own

A team convention set once, with per-repository exceptions. `nil` follows the
global and an empty string overrides to "none", a distinction the sheet makes
visible with toggles. A repository's `.multishell.json` fills only the gaps
the user left, because a team default should never override a choice someone
made. It may also say what a worktree here opens and whether that runs the
agent, so a team gets one setup rather than each person finding four
settings, and what order its worktree rows come in; those start the shell or
agent the user themselves chose and change only what is drawn, so unlike a
hook they run nothing the repository wrote and need no trust.

Its hooks run code on the say of whoever committed the file, so they wait for
a one-time yes stored with the exact text. The question comes when the user
selects one of that project's worktrees, not when a refresh finds the file,
or a launch would open onto a queue of questions about repositories nobody is
looking at. The file is re-read whenever its modification date moves, since a
hook edited while the app was up used to stay the version the run started
with. Cost: the layering must be asked of the model, never read off
`project.settings`, and a trust question can arrive without a click.

Odd shapes, each from a bug: the prefix is not applied to an existing branch,
a blank worktree directory means the default rather than the repository
itself, `.` and `..` and an empty slug become `_`, and a whitespace-only hook
is the user's "none".

## A hook is a shell script, and only a pre hook can refuse

Context arrives in environment variables, so nothing needs quoting. The shell
is login and interactive, because `-l` alone misses `.zshrc` and a
Finder-launched app has only the system PATH, so `npm install` failed for
anyone on Homebrew or a version manager. `set -e` goes inside the script,
after the rc files, so a chatty `.zshrc` is not what stops it. Cost: startup
time, and rc files write to stderr under `-i` with no terminal, which used to
be the whole of a failing hook's message.

A running hook shows in the pane, not in a modal, because `npm install` held
the sheet and the window for a minute; a failed one stays there, because an
alert raised as the sheet went away was dropped and one raised later landed
over whatever the user had moved on to. Cost: a failed hook holds its
worktree until Dismiss.

It is stopped by SIGHUP to the child's process group and then SIGKILL:
interactive shells ignore SIGTERM, and SIGHUP to the shell alone left its
`sleep` running. To the group only, since by then the leader's pid may have
been reissued.

## Watch where git records worktrees, poll for everything else

Never the `.git` root once `worktrees/` exists: `git status` rewrites
`.git/index`, so every status poll became a refresh. Working-tree edits touch
nothing under `.git`, so status is polled, frontmost only, eight at a time,
coalesced 250 ms after terminal activity because a prompt raises several
events. A tick compares the records before it runs git, or every return to
the app cost one `git worktree list` per project. Cost: a change git makes
elsewhere waits for the next tick.

Git on a timer reads only, and `git status` carries `--no-optional-locks`,
because a plain one takes `index.lock` and a `git commit` typed at the wrong
moment failed.

## A terminal's state comes from what runs in it

Neither engine can say a command is running, and SwiftTerm's view swallows
even the bell, so engine activity is only what Terminal.app's dot is:
something happened here since you looked. Only the program in the terminal
can say it is waiting for an answer, so Working and Waiting come from reports
alone; inferring Working from the title flipped a tab the moment it opened.
An exit code above 128 is a signal, usually the user's own Ctrl+C, not a
failure.

Done and Failed are about the user, so showing the tab clears them. Working
and Waiting are about the process, so they stay while the user looks: a
question seen but not answered is still waiting. An agent killed with Ctrl+C
sends no Stop, so reports carry a pid the app watches; no timeout, because a
long task is not a stale one. Cost: Cmd+W on a Working pane asks first.

## The inbound channel is a Unix socket and a small helper

A socket rather than a URL scheme, because a URL activates the app and hooks
fire dozens of times a minute; a helper rather than `nc` for quoting, a
stable protocol and one place for the Claude mapping. Fields are only ever
added, so an old helper keeps working. A report naming an unknown session is
dropped rather than matched by directory: the channel is trusted no further
than the tab it can prove.

A report carries only what the app cannot see for itself. A state and a pid,
because no engine says whether the program in a pty is working or waiting. A
message, because "Claude needs your permission to use Bash" says more than
"waiting". A duration, so a command over in milliseconds posts no banner. And
an `agent`, because which agent a pane holds is otherwise unknowable: it is
usually started by hand at a shell prompt, so the tab's `agentID` is nil, and
libghostty's foreground-pid call is a stub on the pinned Ghostty.

What a report may do is unchanged: it moves a dot, raises a notification, and
decides how a dropped file is written. It opens no tab, runs no command, and
puts no text of its own at a prompt. The shell reports run inline, because
backgrounded a fast command's finished overtook its started and job notices
printed at the prompt. A stale socket is unlinked only after a connect to it
is refused, since one that answers belongs to a running instance.

## Shell integration is injected, never written to a user's file

Generated per session and reached through `ZDOTDIR` or `--init-file`. The
helper is reached through a symlink refreshed at launch, so a moved bundle
breaks no hook line. Claude Code's hooks are the one exception, appended one
entry per event on the user's click, with a copy kept the first time. Under
Ghostty bash goes through `/bin/sh -c 'exec bash …'`, because Ghostty keys
its own injection on the command's first word and handed `bash --init-file X`
added `--posix`, under which macOS's bash 3.2 read neither file.

## A click in the prompt moves the cursor, because the prompt claims it

Ghostty answers a click only for a shell whose OSC 133 A mark carries
`cl=line`, and only over cells its B mark called input. Neither shell got
either from the engine: libghostty's MIT rewrite of the zsh integration,
Ghostty's own being GPLv3, never claims, and it was not loading at all,
because the engine points `ZDOTDIR` at its bootstrap and then applies a
surface's variables on top, so ours replaced it. A claim with no input mark
answers with no keys, silently, which is why it looked handled in every log.
So a zsh session names both, the bootstrap in `ZDOTDIR` and ours in
`GHOSTTY_ZSH_ZDOTDIR`.

The zsh claim rides at the front of PS1 rather than being printed, because
the rewrite prints a plain A from a later precmd, a plain mark withdraws the
claim, and PS1 is expanded on every redraw. bash writes the whole set, since
the engine refuses Apple's bash 3.2; its A is printed rather than put in PS1,
or readline counts that fresh line as free and edits at the wrong column. D
is absent: the exit code is the socket's to report.

Only when `TERM_PROGRAM` names ghostty, since half a set opens a prompt that
never ends. Cost: no click-to-move under SwiftTerm, none on the later lines
of a multi-line buffer, which needs PS2 marks neither integration writes, and
a printed A is not rewritten on redraw.

## Files dropped on a terminal are pasted, never run

A drop is text at the prompt and nothing else. A shell gets absolute paths
quoted for it; an agent whose prompt reads mentions gets its prefix and paths
relative to the session's directory, which is what a mention resolves
against. The prefix is a catalogue column, unset for an agent not known to
resolve them, which then gets a plain path it can still read. Which agent a
pane holds is asked of what reported there, not of the tab: an agent started
by hand leaves `agentID` nil, and a tab opened for one keeps that id long
after the agent quit.

Bracketed where the engine can frame it, a trailing space, never a newline:
the user reads what landed and presses Return. A name carrying a control
character is left out altogether, since no quoting reaches through a terminal
to stop a newline pressing Return itself. The pane takes focus, but only if
it is still on screen when the files land, since taking focus switches and
saves the worktree's tab.

A copy macOS made for this app is asked for again through its promise, into a
directory of ours. A screenshot's floating preview is the case that matters:
its copy sits under `TemporaryItems`, which macOS opens to the receiving app
alone, so the app could read the file and the pane's own shell could not.
Only a copy is refused, because a copy is not the file: an agent told to edit
one would edit something swept in a week. Reading cannot tell the two apart,
so the marks a copy carries are read instead, and copies of ours are swept at
launch once a week old.

Cost: a wrong mention column leaves a stray `@` in front of a path the agent
can still read; a promised drop is answered before its copies land, so it is
the one that cannot be refused back to the drag; a copy macOS stops marking
that way would be pasted as a path again, which is the bug this fixed; and a
file whose name a terminal would act on has to be typed by hand.

## A merged branch is inferred from three signs, none of which writes

Deciding it is the whole feature; the green glyph is the easy half.

`git branch --merged` finds only a branch whose tip the base can reach, and
`git worktree add -b` cuts a branch at the commit it starts from, so ancestry
cannot tell "landed" from "never began": a fast-forwarded branch and a
brand-new one sit on the same commit. The branch's reflog can, since a branch
cut and not committed to has one entry; where there is none, a bare
repository keeps no reflog unless told to, the fallback is the case that is
certainly fresh, its tip still the base's own. A rebase-merge or a run of
cherry-picks leaves no reachable tip, so those branches get a `git cherry`,
which compares patch ids. A squash merge leaves neither, and finding one
needs `commit-tree`, a write, so the sign taken instead is the `[gone]`
upstream that "delete branch on merge" leaves behind.

That last one is inference, since a pull request closed without merging
leaves it too, so `isCertain` separates the three. All three are badged; only
the two that are proof get a removal dialog led by the button that deletes
the branch, which may be the only copy of the work. The badge is hidden while
the worktree holds work that is only there, uncommitted files or unpushed
commits, since both would go to the Trash with the directory. A failed git
call is not an answer: `mergedBranches` hands back `nil` rather than an empty
set, or every branch would be recorded unmerged until it next moved.

The base is `origin/HEAD`, then `origin/main`, `origin/master`, `main`,
`master`, with an override a repository may ship. A remote-tracking ref beats
a local branch of the same name, since a local `main` is stale until someone
pulls. An override that resolves to nothing leaves the project with no badges
rather than a guess.

A badge is therefore only as fresh as the last fetch, and fetching on a timer
is out: it is network, it may want credentials, and it is the one git call
here that can hang. Fetch is a menu item with `GIT_TERMINAL_PROMPT=0` and a
timeout, and its credential failure gets its own words. It is the only thing
the app does that waits on something off the machine, so the only thing the
sidebar shows waiting, spinning in the project icon's own slot so nothing
shifts, and covering the re-reads after it because the badges are what the
click was for.

The check rides the status poll, not the watcher: a commit moves
`refs/heads/<branch>`, which no watched file mentions. A quiet tick costs one
`for-each-ref` per project, and each verdict is memoised on the base tip, the
branch and the branch's tip; the branch is in that key because `git checkout
-b copy` leaves two branches on one commit and only one may have a gone
upstream. Riding the poll means nothing observable may be written unless it
changed, or the sidebar redraws every five seconds, and a verdict is recorded
only when git answered, or a failed read would pin a stale verdict to the new
tip forever.

Never badged: the main worktree, a bare repository, a detached HEAD and the
trunk's own checkout.

## A worktree's name is the user's, kept beside the worktrees

Every refresh replaces a project's whole worktree list, so a name written
onto `Worktree` would be gone on the next tick; `worktreeNames` is a
dictionary on the workspace, cleared wherever the store forgets a worktree so
nothing is left for whatever is created at that path next.

The branch is never replaced, only demoted, and every place the app names a
worktree follows the sidebar row, including a notification that arrives with
the app off screen. Every git command in that directory acts on the branch,
and a row that hid it would be lying about where the user is; the removal
dialog names the branch and the path in its body, where the part that cannot
be undone belongs.

## The trunk row holds the top, whatever the sort says

`WorktreeOrder` sorts a project's rows in bands before it sorts within one:
git's main worktree, then a linked worktree checked out on the trunk, then —
only if the user asked — the busy ones, then the rest. The trunk row is what
every other worktree is read against, and a list that let it drift into
alphabetical or chronological order would read as a different project each
time a branch was cut. Two bands rather than one because a bare clone with
its worktrees beside it is a layout this app's audience favours: there the
main worktree is the bare repository and the trunk is checked out in a linked
one, so both belong above the work.

Which branch is the trunk is the same answer the merged badges use,
`DefaultBranch.branch`, so a project whose trunk is `develop` pins that row
and lets `main` sort with the rest. Until the first merge scan resolves one
the order falls back to the names `main` and `master`, which is git's own
guess and is right nearly always; the cost is that a `develop` project's rows
can settle once, seconds after launch.

Sorting by creation date needed a date, and git records none: a worktree is a
directory and a few files under `.git/worktrees`, none of them stamped with
when the user asked for it. `Worktree.createdAt` is the birth time of the
directory `git worktree add` made, read off the filesystem in
`WorktreeService.list` so `WorktreeListParser` stays testable on fixture text
alone. It is persisted like the branch beside it and, unlike the branch, never
re-derived from anything: `replaceWorktrees` keeps a date it already had when
a later listing comes back without one, so a volume that blinked does not cost
a save, a re-render and a row's place in the order.

Sorting by when a worktree was last committed to is a different date, and it
is runtime state: a commit moves it, and the workspace must not be rewritten
because someone committed. The orders are named for the commit rather than
for the worktree being "updated", because that is exactly what they measure:
a week of uncommitted work does not move a row. It comes nearly free.
`for-each-ref` over the whole
repository already runs once per project on the status poll to resolve the
trunk and every branch tip, so `%(committerdate:unix)` was appended to that
format and `BranchScan` hands back both answers from the one read. The dates
come back even where no trunk could be resolved, which is why that scan is a
value of its own rather than an optional `MergeScan`: a repository with
nothing to measure merges against still has branches the sidebar can order.

The "nearly" is that git fails a whole query on a format atom it does not
know, and the merged badges read this same query. A git too old for
`%(committerdate:unix)` would therefore have cost every badge, silently, on
every poll — a new order taking out a feature that already worked. So
`branchRefs` asks again without the date atom when the first call fails,
which spends a process only where one had already failed for some reason.

`%(committerdate:unix)` is whole seconds, so two branches committed to in the
same second cannot be told apart and fall back to the name. That is right for
a sidebar and wrong for a test: the one that checks a real scan sets
`GIT_COMMITTER_DATE` rather than racing the clock, because a repository
built and committed to inside one second gave every branch the same date and
passed for the wrong reason.

A worktree with no date either way — a directory copied in rather than
created, a detached checkout with no branch to look a commit time up by, a
project whose first scan has not answered — sorts last in *both* directions.
"Oldest created first" is not a claim that an undated worktree is the oldest.
The name breaks the tie among them, and it is also why the default is
alphabetical: it is the only order that reads the same on every machine.

"Show active at the top" is off by default. A worktree counts as active while
it has a terminal open or a state something reported, so with it on the rows
move as agents report in — welcome once asked for, and startling before.

Both settings are things a repository may ship, because a team that works in
worktrees tends to agree about how to read the list, and neither runs
anything. The form therefore seeds an override from what is actually in
force — `InheritedSetting`, the file's value where it has one — rather than
from the user's global: seeding from the global would replace what the
project was already doing with a value nobody was using.

## Persisted state never loses data, and is repaired rather than trusted

Silently starting empty and then saving deletes the user's sidebar to fix a
bug of ours. Projects stay strict where the other collections are lossy: a
project is the one thing git cannot give back, and a tab from a newer build
with an unknown pane kind once cost every project. Per-field defaults do not
cover references between types, and a session no tab shows would get a shell
nothing can close, so references are repaired on load. Cost: a hand edit that
breaks a reference is tidied quietly.

Runtime state stays out of the file. A shell title used to re-evaluate every
view and schedule a save several times per prompt, for a string a relaunched
tab replaces within a second. Cost: a saved tab shows its starting title
until its shell speaks.

## Invariants are tested at random, with seeds

Example tests pin the cases someone thought of; the selection of a worktree a
refresh had just removed was found by a seed. Cost: a failing seed has to be
replayed to understand.

## Nothing in the core blocks a thread

Waits inside `Task`s held one cooperative-pool thread per core, GCD ran out
of threads, children blocked on full pipes, and the test suite hung. Both
pipes are drained at once, or the second fills its 64 KiB buffer and blocks
the child. The EOFs count as arrived one second after the exit, since `npm
run dev &` exits at once and leaves its server holding them.

Running out of descriptors is an error, never an empty answer. launchd gives
a GUI app 256; at the limit `Pipe()` cannot fail and returned two handles on
descriptor 0, so the child wrote to the app's stdin, the reader saw stdin's
EOF, `git worktree list` seemed to say the project had no worktrees, and the
store dropped every tab and saved. Hence the `pipe` syscall, the refused
empty list and the raised limit.

## A closed tab ends its shell, next turn

libghostty no longer frees a surface in the view's `deinit`, the view lives
as long as any SwiftUI frame that adopted it, and on a process exit `close`
runs inside libghostty's own callback, where freeing the surface would free
the object mid-call. SwiftTerm cancels the monitor that would have reaped the
child, so the host reaps with `waitpid` itself. No signal to a child that
already exited: the pid may have been reissued.

## The window chrome is drawn by hand

macOS 26 renders `NavigationSplitView` sidebars as floating glass, and
`HSplitView` sizes children however it likes and exposes nothing. Cost:
sidebar keyboard navigation has to be built, `WeightedSplit` uses
`_VariadicView`, and each hand-drawn row needs an accessibility label reading
its glyphs in drawing order.

Both headers stand in for the title bar and are 40 pt, the band a hidden
title bar with a unified-compact toolbar keeps; a 28 pt header put the tab
strip inside that band, where AppKit painted its backdrop over it. Nothing
collapses the sidebar, since the traffic lights need something under them.
The state dot takes the icon's place on the left because the dirty-files dot
is already yellow on the right, and a project row shows its worktrees' dots
only once collapsed.

## One workspace window, and `Window` scenes only

Each surface is one `NSView`, and a second window would steal it. Project
settings is a `Window` too, because a `WindowGroup` adds its own Close and
AppKit gives Cmd+W to the first matching item, so that Close beat Close Pane
and shut the app.

Either settings window opens centred on the workspace's screen, on its first
tab and scrolled to the top, whatever the user left behind. SwiftUI shows the
same window again after a close, so nothing on the way in can do that by
itself: the close places it while there is nothing on screen to jump, becoming
key is the first point that knows which screen the workspace is on, and each
resize is the window settling to the size of its content, which had been
leaving it half a toolbar's height low. Centring on the window's own screen
was not enough, because one left on a second display kept reopening there,
away from the app.

## Agents and shells are ids in the store, command lines at launch

Ids are strings, so a newer build's agent loads harmlessly on an older one,
and a custom shell is an id rather than the typed path, because the dropdown
lists paths it found and a typed one would show as "not installed" whether it
exists or not. An agent launches as `agent; exec <shell> -l`, so it is found
on the terminal's PATH and a shell remains with the scrollback. A session off
disk resumes rather than starts: four saved agent tabs must not start four
agents. The shell is re-read from the setting at launch rather than
persisted; under Ghostty `$SHELL` keeps the engine default, the path seen to
work. Cost: a shell without `-l -i -c` (nu, xonsh) still gets `/bin/sh` for
hooks.

Every agent people install lives under Homebrew, npm or a version manager,
none of which a Finder-launched app has on PATH, so one login-shell
environment is captured at launch, with an eight second limit past which a
poorer PATH beats empty dropdowns.

Auto-start opens the agent where a shell would have opened, held back until
the post-create hook ends so it starts after `npm install`; New Shell Tab
always opens a shell, so one stays reachable.

## A removed worktree goes to the Trash, not through `git worktree remove`

`git worktree remove` refused a dirty tree, and its `--force` unlinked the
files behind a second dialog; the one time someone removes the wrong worktree
is the time that matters. A locked worktree is unlocked first, since prune
skips locked records. A Trash that refuses, as on a volume without a
`.Trashes`, falls back to deletion. Cost: on such a volume the recovery the
Trash promised is not there.

Whether a removal asks at all is a global setting, about the person and not
the repository, but it always asks about the branch, the one part the sidebar
cannot undo. The branch goes last, after the post-delete hook, so a hook that
pushes it still finds it.

## A bare repository is a project

`--is-inside-work-tree` prints `false` for one, and a bare clone with its
worktrees beside it is a common layout for people who live in worktrees;
`--git-dir` succeeds anywhere inside. A repository hidden as `proj/.bare`
takes the name of the folder holding it, the name the layout is known by.
Cost: the default `../{project}-worktrees` lands inside `proj/` for that
layout.

A project is the main worktree whatever was picked, because a linked worktree
lists the same worktrees and two rows would select together and share tabs.
Cost: the sidebar shows the repository's name, not the folder picked.

## A missing directory is refused, not worked around

A shell spawned in a missing directory silently lands in `$HOME`. A project
whose directory is gone stays dimmed rather than dropped, since an unmounted
drive must not delete someone's setup, and the failure is reported once
because every tick would re-raise it.

## A local build is signed by a certificate, not ad hoc

A terminal is blamed for what runs in it: macOS holds the spawning app
responsible for what a process reads, so an alert about a command in a pane
names Multishell, which was idle. Hence the usage strings in the Info.plist,
the only place that can say a command asked. And hence a certificate rather
than ad hoc, since a grant is keyed to the signature's designated requirement
and an ad-hoc one is a bare cdhash: every build asked again for everything,
and a box already ticked in System Settings stopped matching and denied in
silence.

Cost: a setup step before the first build, and a certificate nothing else
trusts, so it buys nothing towards distribution. App Management is out of
reach either way, never prompted for and only denied.

Disclaiming the child instead, so an alert named the program that asked, would
mean owning the pty spawn — SwiftTerm forks and execs, libghostty spawns
inside the xcframework — and the name would then be an unsigned binary, which
TCC refuses rather than asks about.

## Smaller decisions

- Sessions warm up when visited, since a saved workspace could imply dozens
  of shells at launch. Selecting a worktree opens a terminal unless told not
  to, for someone triaging many worktrees who wants to look first. A create
  is asked about apart from a selection, both for whether a terminal opens
  and for whether it runs the agent, because a worktree asked for and a
  worktree looked at are not the same event: the common setup is a click
  that only shows, and a create that comes up with an agent already working.
  Cost: four settings where there were two, and a project may override the
  two a create reads.
- Engines coexist, because "next launch" is a poor answer to an engine
  change. Cost: two renderers the theme conversion must keep identical, and a
  command reaches libghostty as one quoted line but SwiftTerm as an array.
  Both sit behind a protocol with a recording fake, which is how the engines,
  the watcher and the platform are tested without a terminal or a desktop.
- Ghostty's keybinds are unbound by name, not `keybind = clear`, which also
  removes alt+arrow word movement and super+backspace.
- Paths are directory URLs always: `URL(fileURLWithPath:)` asks the
  filesystem whether a path is a directory, and a relative worktree path
  resolved against a URL Foundation took for a file landed in the parent.
- Errors are mapped, not stringified. The alert is the only place a user
  learns why something failed, so it gets git's own words.
- Settings use the Mac's own idiom, so project settings hosts
  `NSTabViewController` in `.toolbar` style, which SwiftUI gives only to the
  `Settings` scene. Removing a project asks in that window, or the dialog
  would be behind it.
- Help is behind an (i), because captions doubled every form's height and
  were read once. A caption is left only for a value computed live.
- Notifications are for reports, not bells, and nothing under ten seconds:
  `ls` is not news, a build is. A bell in a background tab is a dot.
- Debug builds keep their own state file, socket and integration directory,
  so `make run` beside the installed app neither overwrites its state nor
  takes its socket.
- The terminal font is picked, not typed, monospaced families first and then
  everything else, because some programming fonts carry ligature and icon
  glyphs and are not marked fixed-pitch.
- A project icon is a description tinted from a theme slot rather than a hex,
  so a theme change keeps it in step with the terminal. Image files would
  mean a folder, resizing and cleanup on removal.
- One `WorktreeActions` menu serves the detail header and the context menu,
  so an action added once appears in both. A terminal editor opens as a tab,
  because one run in the background fails silently with no tty. Cost: an
  editor tab's command line is saved, so a relaunch reopens the editor.
- New Worktree always opens, even with several projects and nothing selected,
  and its decisions are a tested value because a cancelled branch load once
  re-enabled Create against the wrong project. The branch picker offers local
  branches only, since a large repository has hundreds of remote ones.
