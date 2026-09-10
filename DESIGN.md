# Design decisions

Why the code is shaped as it is, and what each shape costs. What the code does
is in the code; this records what it does not say. Newest at the bottom.

## The core decides what exists; the GUI decides how it appears

The engines disagree about who owns the pty, so the core never sees a
descriptor, a byte stream or a view. `AppModel` holds the runtime state the
core refuses, and lives in a library rather than the Mac app so a Linux
frontend need not copy it out. Windows went the same way and was never built.
Cost: `public` on every moved type and a `Platform` conformance per frontend.

## Reconcile, don't command

One path for tab open, tab close, worktree removed, project removed, process
exited and relaunch. Cost: a session that fails to open is removed afterwards,
not prevented.

## Identity is the path

Worktrees are rediscovered from git on every refresh, and a minted id would
change under persisted selection. Cost: moving a repository is a new project.

## Shell out to git

libgit2's worktree support is the part it does worst, gitoxide's is incomplete,
and the porcelain formats are a stable contract. Cost: git must be installed
and every operation is a spawn.

## Tabs own a pane tree, from day one

So splits, which came later, were a renderer change with no schema change.
Same-axis splits add a sibling and halve the focused pane, as tmux and iTerm do.

## A tab dragged to a worktree moves, it does not re-open

The shells keep running; nothing is restarted and nothing is `cd`'d. Where
panes start and which shell they start are the destination's to decide, or the
next launch opens one project's shell in another's checkout. A live tab is
turned to on landing, which keeps the destination warm. The drag has its own
pasteboard type, since projects drag as text to reorder and one type for both
would offer each drag the other's targets.

Cost: the shell is still in its old directory until the user cds, so a dropped
file is written against the tab's new worktree. A worktree left with no tabs
loses what was on screen.

## Themes are hex strings

Portability and user theme files for free. Cost: a light terminal gets a light
sidebar whatever the OS mode.

## Settings resolve project over global, and a repository may ship its own

`nil` follows the global, an empty string overrides to "none" — for the
worktree path, branch prefix and default branch, which have no other spelling
for it, in the user's settings and in a repository's file alike, so an export
can carry a project pinned that way. Elsewhere blank reads as absent, because
"none" and "no opinion" come to the same thing: a field with a sentinel of its
own, an agent's `none` or a shell's `login`, would otherwise have two ways to
say one thing and lose the distinction on the next load, an empty hook is not
a hook to be trusted, and an empty file list links nothing. Cost: a stray
empty key for one of those three fields is an opinion, not a typo.

A repository's `.multishell.json` fills only the gaps the user left: a team
default must never override a choice someone made. What it may say — what a
worktree opens, whether that runs the agent, the row order — changes only what
is drawn, so unlike a hook it needs no trust.

Its hooks run code committed by someone else, so they wait for a one-time yes,
held against the sha256 of the file's bytes and asked when the user selects one
of that project's worktrees. The file is re-read when its modification date
moves, and an answer is kept per file, sixteen of them: the file is tracked, so
it differs between branches, and one shared answer asked again on every switch.

Costs: the layering must be asked of the model, never read off
`project.settings`; a trust question can arrive without a click; editing any
other key re-asks; and a yes outlives the file.

Grey in a hook editor means inherited and nothing else. Odd shapes, each from a
bug: no prefix on an existing branch, a blank worktree directory means the
default, `.` and `..` and an empty slug become `_`, a whitespace-only hook is
"none".

## A hook is a shell script, and only a pre hook can refuse

Context arrives in environment variables, so nothing needs quoting. The shell
is login *and* interactive, or a Finder-launched app's bare PATH fails
`npm install` for anyone on Homebrew or a version manager; `set -e` goes inside
the script, after the rc files. A running hook shows in the pane, not a modal,
which would hold the window. It is stopped by SIGHUP to the child's process
group then SIGKILL, interactive shells ignoring SIGTERM.

Cost: startup time, stderr noise from rc files under `-i`, and a failed hook
holds its worktree until Dismiss.

## A new worktree is given files by a list, not by a hook

Copying `.env` in was the post-create hook nearly everyone wrote, at the cost
of a login shell, a timeout and the pane. The lists run between
`git worktree add` and the hook, so both it and the first terminal find the
files. Nothing is placed over what git checked out, and a path the repository
lacks is skipped.

Two lists: a copy gives the worktree its own file, a symlink shares the
repository's, which is what `node_modules` wants. Links run first, so a path in
both ends up the link, and a link is absolute, a relative one pointing at where
the worktree sits today. A name may be a pattern, `*` and `?` within one
component, not matching a leading dot, or `*` would take `.git` in. Bracket
expressions are left out rather than half-supported.

Both lists run nothing, so a repository may ship them untrusted; nothing
overwriting a checked-out path is the other half of that, since a committed
`linkedPaths: src` must not point a worktree's source at the main checkout.
Containment is decided against the disk, not the spelling: the deepest existing
folder on each path is resolved and checked, catching `..`, a leading `/` or
`~`, and a folder that is itself a symlink. A symlink at the end of a path is
copied as a symlink, never followed.

The lists and the hook are one pane operation in stages, begun once the
worktree exists rather than under the sheet, and a failed list stops the stages
after it. Costs: no `node_modules` of the worktree's own; and Cancel lands
between paths, so it waits for the file being copied and ends the whole setup
rather than skipping a stage.

## Watch where git records worktrees, poll for everything else

Never the `.git` root once `worktrees/` exists: `git status` rewrites
`.git/index`, so every poll would be a refresh. Status is therefore polled —
frontmost only, eight at a time, coalesced 250 ms after terminal activity, each
tick comparing records before it runs git. Timer git reads only, and
`git status` carries `--no-optional-locks`, or it takes `index.lock` and fails
the user's own commit. Cost: a change git makes elsewhere waits for a tick.

## A terminal's state comes from what runs in it

Neither engine can say a command is running, so engine activity means only what
Terminal.app's dot means: something happened here. Working and Waiting come
from reports alone. An exit code above 128 is a signal, usually Ctrl+C, not a
failure.

Done and Failed are about the user, so showing the tab clears them; Working and
Waiting are about the process, so they stay while the user looks. Ctrl+C sends
no Stop, so reports carry a pid the app watches; no timeout, a long task not
being a stale one. Cost: Cmd+W on a Working pane asks first.

## The Agents board is a roster, not a queue

Every open pane has one card for as long as it is open, and the card moves
between columns as its state moves. State picks the column; it never decides
whether a card exists, so nothing is ever hidden by having been looked at. A
card goes when its pane closes, and in one other case: an agent whose process
has gone leaves a plain shell behind, which the filter then hides.

Failed waits with Waiting rather than sitting in Done. A failure wants the
user, which is what that column means, and it leaves Done meaning one thing.
Cost: two clearing rules in one column, a question clearing only when its agent
says so and a failure when its tab is shown.

The filter is the one control and decides membership alone: a shell it lets in
lands where its state says, exactly as an agent does, because the zsh and bash
integration already reports a command started and finished. So `make release`
is Working and a failed `swift test` waits, with no new plumbing. No duration
floor, though `NotificationPolicy` has one: a banner interrupts and a card does
not, and the sidebar dot already goes green for an `ls`. It lives on the model
rather than in the view because the Dock badge counts what the Waiting column
shows and has to read the same filter; cost, it is off again after a relaunch.

While it is up, nothing that acts on "the tab in front of the user" acts at
all: Cmd+W would otherwise end a shell in a pane nobody can see, and Cmd+T open
a tab that appears only once the board is left. One `worktreeInView` answers
that for every one of them.

An agent's pid is polled only while the board is up, with one sweep as it
opens. Nowhere else shows a quit agent — a dropped file asks whether it is
still at the prompt at the moment of the drop — and watching always would leave
a two-second timer running for as long as any agent had ever reported.

The four columns are always drawn, empty or not: labelled columns say what the
board is for, where a page in their place says only that it is not working. An
empty board adds one line saying what would put something on it, since without
a report nothing can know an agent is at a prompt. Not gated on whether hooks
are installed: one agent's being in place says nothing about the agent actually
at the prompt.

Showing the board means no pane is shown, or the selected worktree's Done
states clear as it opens and their cards reach Idle having never passed through
Done. Ordering is newest first everywhere, so an arriving card pushes the rest
down a place; nothing else about a card moves on its own. Columns share the
room down to a floor and the board scrolls past it, a partial column at the
edge saying there is more. No end arrows, which the tab strip needs because a
tab scrolled out of sight is one you forget exists; the board has four fixed
columns and half of one showing says which way the rest are. No line of output
on a card: neither engine hands scrollback to the core.

## The inbound channel is a Unix socket and a small helper

A socket rather than a URL scheme, which would activate the app dozens of times
a minute; a helper rather than `nc` for quoting, a stable protocol and one
place for each agent's mapping. Fields are only ever added, and a report naming
an unknown session is dropped rather than matched by directory.

It carries only what the app cannot see for itself: a state and a pid, a
message, a duration so a millisecond command posts no banner, and an `agent`,
a pane's agent usually being started by hand with the tab's `agentID` nil. It
moves a dot, raises a notification and decides how a dropped file is written;
it opens no tab, runs no command and puts no text at a prompt. Shell reports
run inline, or a fast command's finished overtakes its started.

## Five agents' hooks, one hook line and one parser

Claude Code, Codex, Gemini CLI and Copilot CLI each run a command at each
lifecycle event and hand it the same three fields, so all four get the same
line: run the helper, which reads the payload and maps the event that fired.
What differs is the file, what each agent calls an event, and how that file
spells one hook, and that is all an `AgentHookIntegration` holds — the app
knows no agent by name anywhere else. Codex has a permission request where
Gemini has a notification, and Claude, which has both, is asked for both;
Copilot is asked in the spelling whose payload names its event, since the other
spelling names none. Gemini counts the timeout
in milliseconds, and five would kill the helper before it reached the socket.

Copilot reads a directory of hook files rather than one settings file, so its
is ours alone: written whole, deleted to remove, no copy to keep. OpenCode
reports to no command at all — only a plugin sees a session go idle — so it is
given a plugin that calls the helper the way any script would. It is also the
only agent that says a permission was answered, allowed as well as denied, so
its pane is the only one whose Waiting clears on the answer rather than at the
next tool call. Both come off the event bus. Its `permission.ask` hook, which is
what the plugin used to listen on, is not: it is in the plugin types and has
not been called since the 1.1 permissions rewrite, and the day it is called
again it would report the prompt the bus already reported. Cost: it is
JavaScript in the user's agent, so it spawns, unrefs and swallows everything,
and it is the one integration whose contract we do not control from a payload.

Three events had to be narrowed, because "the agent raised a notification" is
not "the agent is waiting". Copilot raises one when a background shell
finishes as much as when it needs an answer, so ours asks for the two types
that are questions and lets the file do the filtering. Codex has no
notification at all, only a permission request that fires before it decides
whether anyone need answer, so under `--full-auto` every tool call would
have posted a banner; it counts as waiting only in a mode that stops for the
user, and a mode we have not heard of is taken to stop. Claude's request is
the same shape and is narrowed the same way, its classifier mode being one
more that answers without the user. Gemini needed neither: its Notification
has one type, a tool permission.

Claude is asked for that request beside its notification, not instead of it,
because the notification is the slower of the two: it comes six seconds after
the prompt goes up and is dropped if the user answers first, so on its own a
prompt answered quickly never moved the dot and a slower one moved it six
seconds late. The request fires as the call reaches the prompt, and after the
tool call's own `PreToolUse`, so Working does not land on top of it. Both
timings are measured from a session run against this build, not read off a
page.

A prompt therefore reports twice, and only the second is heard from: the
request moves the dot and raises no banner, the notification raises it. Six
seconds is as good a rule as any for when a prompt is worth interrupting
someone for, it is the agent's own rule, and the notification is the report
that carries the wording, the request having no message in it at all. Without
that, one prompt meant two banners six seconds apart. A `silent` report is the
general form: it moves a dot where another report about the same thing will do
the talking.

Nothing reports the answer, so the dot stays amber until the next tool call or
the end of the turn: an approved call that takes two minutes holds it for two
minutes, and a prompt escaped holds it until the next prompt. `PermissionDenied`
is not the missing half, whatever its name suggests. It fires for one thing
only, a call the auto mode's classifier turned down, so a hook can appeal it; a
person refusing at the prompt fires nothing. Taking it would have put a line in
the user's settings for an event that can only arrive in a mode this reports no
waiting in.

The other three CLIs have nothing of the kind to take. Codex's request is
already the immediate one and it reports no answer to it; Gemini's notification
has a single type, a tool permission, and no confirmation event behind it.
Copilot has a permission request, but it fires before its own rules run and its
payload never says the mode, so under `--allow-all-tools` it would post a
banner per tool call with nothing to narrow it by, and its notification already
covers the prompt. Copilot's `errorOccurred` is the one thing deliberately left:
it carries a `recoverable` flag, and a red dot for something the agent recovers
from is worse than no red dot at all.

The line runs the helper rather than `exec`ing it, and exits 0 whatever
became of it. Copilot denies a tool call on any non-zero exit from a
`preToolUse` hook and Claude blocks one on exit 2, so under `exec` a helper
killed by Gatekeeper or dying on a signal would stop the agent working rather
than stop the dots moving. Cost: one short-lived shell per event, and nothing
else — the pid the report carries comes from walking past shells either way.

A settings file that is a symlink is written through, not over: an atomic
write would leave a regular file where a dotfiles repository's link was, and
the user's own copy would stop being the one the agent reads. The copy kept
holds the contents and sits beside the link, not in the repository it points
into, which would leave a file their next `git status` has to explain.

Nothing under an event is written over. Absent means an empty list to add
ours to; a string, an object, or a shape a later version of the agent takes
means something of the user's this cannot put back, so Add refuses and names
the event and Remove steps over it. Remove takes back what Add put in and
nothing else, which is the whole of what it promises.

A settings file that will not read back as plain JSON is refused, not parsed
loosely: Gemini's takes comments and Gemini keeps them when it writes the file
itself, and a re-serialisation here would take them out. Cost: those users add
the entries by hand, so the alert names the file and points at Show JSON.

Codex will run no hook it has not been told to trust, so installing is not the
end of it and the row says so; nothing here can trust a hook on the user's
behalf.

No agent is recommended, and none has anything of its own outside that table.
Claude Code briefly had an install prompt with a setup link and a `curl` line,
an endorsement in a workspace built to run whichever agent the user already
chose; it is gone, with the property that asked about that one agent. Cost: a
machine with none installed gets an empty picker and no help filling it.

## Shell integration is injected, never written to a user's file

Generated per session, reached through `ZDOTDIR` or `--init-file`, with the
helper behind a symlink refreshed at launch so a moved bundle breaks no hook
line. An agent's hooks are the one exception: appended on the user's click,
with a copy kept. Under Ghostty bash goes through `/bin/sh -c 'exec bash …'`,
Ghostty keying its own injection on the command's first word and adding
`--posix`, under which macOS's bash 3.2 reads neither file.

## A click in the prompt moves the cursor, because the prompt claims it

Ghostty answers a click only for a shell whose OSC 133 A mark carries
`cl=line`, over cells its B mark called input; a claim with no input mark
answers silently. The engine points `ZDOTDIR` at its own bootstrap, which never
claims, so a zsh session names both, ours in `GHOSTTY_ZSH_ZDOTDIR`. The zsh
claim rides at the front of PS1, a plain A printed later withdrawing it; bash
writes the whole set and prints its A, or readline edits at the wrong column.
No D: the exit code is the socket's. Only when `TERM_PROGRAM` names ghostty,
half a set opening a prompt that never ends.

Cost: no click-to-move under SwiftTerm, and none on the later lines of a
multi-line buffer.

## Files dropped on a terminal are pasted, never run

A shell gets absolute quoted paths; an agent whose prompt reads mentions gets
its prefix, a catalogue column, and paths relative to the session's directory.
Which agent a pane holds is asked of what reported there, not of the tab, since
one started by hand leaves `agentID` nil and a tab keeps its id after the agent
quits.

Bracketed where the engine can frame it, a trailing space, never a newline: the
user reads what landed and presses Return. A name with a control character is
left out altogether, no quoting stopping a newline from pressing Return itself.
The pane takes focus only if still on screen when the files land, since focus
switches and saves the worktree's tab.

A copy macOS made for this app is asked for again through its promise, into a
directory of ours swept once a week, because such a copy can sit somewhere the
app can read and the pane's shell cannot. Only a copy is refused, a copy not
being the file, and it is recognised by the marks it carries rather than by
reading it.

Costs: a promised drop cannot be refused back to the drag; a copy macOS stops
marking is pasted as a path again; and a file whose name a terminal would act
on must be typed.

## A merged branch is inferred from three signs, none of which writes

Deciding it is the whole feature; the green glyph is the easy half.

Ancestry cannot tell "landed" from "never began", since `git worktree add -b`
cuts a branch at its start commit, nor from "was carried up", since a `git pull`
in a worktree cut before the trunk moved fast-forwards it onto commits it was
handed. What the branch's reflog says was done to it can: a creation, a reset,
a clone, a fetch and a merge or pull that fast-forwarded are arrivals, and
everything else — a `commit:`, a rebase's `(finish)`, a merge that made a
commit — is work of its own. A deny list, because the arrivals are the closed
set and a message a later git invents reads as work, which is what counting
entries assumed of every entry anyway. The names are given to git whole, with
`--` after them, or a branch sharing a name with a path in the repository is
"both revision and filename" and the read fails instead of answering.

Where there is no reflog at all, nothing is claimed. A bare repository logs no
branch creation, so guessing from the tips instead badges every worktree it
holds that was cut from anywhere but the trunk's own tip, which in that layout
is most of them. It does log a commit, so a branch that landed still says so;
what the rule costs is the badge on a branch whose reflog has expired, and a
badge not drawn is a worktree nobody is told to remove.

A rebase-merge or a run of cherry-picks leaves no reachable tip, so those get a
`git cherry` on patch ids: at least one `-` and no `+`. Not "no `+`" alone —
cherry skips merge commits, so a worktree that merged the trunk in and wrote
nothing of its own prints nothing at all, and read as "every patch landed" that
badges a branch that landed nothing.

A squash merge leaves neither, and detecting one needs `commit-tree`, a write,
so the sign taken is the `[gone]` upstream that "delete branch on merge" leaves
— with two things beside it, `[gone]` alone being three different stories. A
base that has moved on, since `branch.<name>` config outlives the branch it
names and a name used before hands its successor an upstream that was never on
the remote, spelled `[gone]` in the very same words. And the branch's own
changes reading the same on the base, since the badge hides while a worktree
holds work only it has, and `git status` cannot see that here: a branch whose
upstream is gone is ahead of nothing. That last is two `git diff --name-only`,
the paths the branch changed since it forked against the paths where the two
differ now, and nothing in both; a path the base has changed since counts as
differing, so it errs towards no badge. Four reads, paid only by the branches
whose upstream is gone.

That last is inference, a PR closed unmerged leaving it too, so `isCertain`
separates the three. All three badge; only the two that are proof get a removal
dialog led by the button that deletes the branch, which may be the only copy of
the work. The badge hides while the worktree holds uncommitted or unpushed
work. A failed read is not a verdict: `nil` and not an empty set from the merged
list, `nil` and not a `false` from the patch, behind and content reads, `nil`
from the ref read, which otherwise says a project has no branches at all and
drops every badge and commit date it has, and `nil` from the reflog read, where
git answers "no reflog" with an empty output and a success, so only a real
failure is silent. A verdict is only recorded, and only memoised, where git
answered.

The base is `origin/HEAD`, then `origin/main`, `origin/master`, `main`,
`master`, with a repository override; a remote-tracking ref beats a local
branch of the same name, and an override resolving to nothing means no badges
rather than a guess. Fetching on a timer is out — network, credentials, and the
one git call here that can hang — so a badge is only as fresh as the last
fetch, and Fetch is a menu item with a timeout and the only sidebar spinner.

The check rides the status poll, not the watcher: a commit moves a ref no
watched file mentions. Each verdict is memoised on the base tip, the branch,
the branch's tip and whether its upstream was gone — the branch is in the key
because two branches may sit on one commit with only one gone upstream, and the
upstream because a first push puts one back without moving either tip.
Nothing observable is written unless it changed, or the sidebar redraws every
five seconds.

Never badged: the main worktree, a bare repository, a detached HEAD and the
trunk's own checkout.

## A worktree's name is the user's, kept beside the worktrees

Every refresh replaces a project's whole worktree list, so a name written onto
`Worktree` would be gone next tick. `worktreeNames` is a dictionary on the
workspace, cleared wherever the store forgets a worktree.

The branch is never replaced, only demoted: every git command in that directory
acts on the branch, so a row that hid it would lie. The removal dialog names
branch and path in its body, where what cannot be undone belongs.

## The trunk row holds the top, whatever the sort says

`WorktreeOrder` sorts in bands before sorting within one: git's main worktree,
then a linked worktree checked out on the trunk, then — only if the user asked
— the busy ones, then the rest. The trunk row is what every other worktree is
read against. Two bands, because in a bare clone with its worktrees beside it
the trunk is a linked worktree.

The trunk is `DefaultBranch.branch`, the same answer the badges use, falling
back to `main` and `master` until the first scan resolves one; cost: a
`develop` project's rows can settle once, seconds after launch.

Git records no creation date, so `Worktree.createdAt` is the directory's birth
time, read in `WorktreeService.list` so the parser stays testable on fixture
text alone. It is persisted and never re-derived, or a volume that blinked
would cost a save, a re-render and a row's place. Last commit is runtime state
instead — the workspace must not be rewritten because someone committed — and
the orders are named for the commit because that is what they measure: a week
of uncommitted work does not move a row. It rides the `for-each-ref` the badges
already run, as `%(committerdate:unix)`; since git fails a whole query on an
unknown format atom, `branchRefs` asks again without it when the first call
fails, or an old git would cost every badge.

A worktree with no date sorts last in *both* directions: "oldest created first"
is not a claim that an undated worktree is the oldest. The name breaks ties,
and is the default, being the only order that reads the same everywhere.

"Show active at the top" is off by default: a worktree is active while it has a
terminal open or a reported state, so with it on the rows move as agents report
in. Both settings are shippable by a repository and run nothing, and the
override form seeds from `InheritedSetting`, what is actually in force, rather
than the user's global.

## Persisted state never loses data, and is repaired rather than trusted

Silently starting empty and then saving deletes the user's sidebar to fix a bug
of ours. Projects stay strict where the other collections are lossy: a project
is the one thing git cannot give back, and one unknown pane kind from a newer
build would otherwise cost every project. Per-field defaults do not cover
references between types, so references are repaired on load.

Runtime state stays out of the file: a shell title would otherwise schedule
several saves per prompt for a string a relaunched tab replaces within a
second. Costs: a hand edit that breaks a reference is tidied quietly, and a
saved tab shows its starting title until its shell speaks.

## Invariants are tested at random, with seeds

Example tests pin the cases someone thought of; the selection of a worktree a
refresh had just removed was found by a seed. Cost: a failing seed has to be
replayed to understand.

## Nothing in the core blocks a thread

Waits inside `Task`s held one cooperative-pool thread per core until GCD ran
out of threads and the suite hung. Both pipes drain at once, or the second
fills its 64 KiB buffer and blocks the child, and the EOFs count as arrived one
second after the exit, since a backgrounded server holds them open.

Running out of descriptors is an error, never an empty answer: at the limit
`Pipe()` cannot fail and hands back stdin, so `git worktree list` read as a
project with no worktrees and the store dropped every tab. Hence the `pipe`
syscall, the refused empty list and the raised limit.

## A closed tab ends its shell, next turn

libghostty no longer frees a surface in the view's `deinit`, the view outlives
any SwiftUI frame that adopted it, and on a process exit `close` runs inside
libghostty's own callback, where freeing the surface would free the object
mid-call. SwiftTerm cancels the monitor that would have reaped the child, so
the host reaps with `waitpid` itself. No signal to a child that already exited:
the pid may have been reissued.

## The window chrome is drawn by hand

macOS 26 renders `NavigationSplitView` sidebars as floating glass, and
`HSplitView` sizes children however it likes and exposes nothing. Cost: sidebar
keyboard navigation has to be built, `WeightedSplit` uses `_VariadicView`, and
each hand-drawn row needs an accessibility label reading its glyphs in order.

Both headers stand in for the title bar at 40 pt, the band a hidden title bar
with a unified-compact toolbar keeps; anything shorter puts the tab strip
inside that band, where AppKit paints over it. Nothing collapses the sidebar,
the traffic lights needing something under them.

## One workspace window, and `Window` scenes only

Each surface is one `NSView`, and a second window would steal it. Project
settings is a `Window` too, because a `WindowGroup` adds its own Close and
AppKit gives Cmd+W to the first matching item, so that Close beat Close Pane
and shut the app.

Either settings window opens centred on the workspace's screen, on its first
tab, scrolled to the top. SwiftUI reshows the same window after a close, so
nothing on the way in can do it: the close places the window while nothing is
on screen to jump, and becoming key is the first point that knows which screen
the workspace is on.

## Agents and shells are ids in the store, command lines at launch

Ids are strings, so a newer build's agent loads harmlessly on an older one, and
a custom shell is an id rather than a typed path, which would show as "not
installed" whether it exists or not. An agent launches as `agent; exec <shell>
-l`, so it is found on the terminal's PATH and a shell remains with the
scrollback. A session off disk resumes rather than starts: four saved agent
tabs must not start four agents. Cost: a shell without `-l -i -c` (nu, xonsh)
still gets `/bin/sh` for hooks.

Agents live under Homebrew, npm or a version manager, none of which a
Finder-launched app has on PATH, so one login-shell environment is captured at
launch, with an eight second limit past which a poorer PATH beats empty
dropdowns. Auto-start opens the agent where a shell would have, held back until
the post-create hook ends; New Shell Tab always opens a shell, so one stays
reachable.

## A removed worktree goes to the Trash, not through `git worktree remove`

`git worktree remove` refuses a dirty tree, and its `--force` unlinks the
files; the one time someone removes the wrong worktree is the time that
matters. A locked worktree is unlocked first, prune skipping locked records. A
Trash that refuses falls back to deletion; cost: on such a volume the recovery
the Trash promised is not there.

Whether a removal asks at all is a global setting, about the person and not the
repository, but it always asks about the branch, the one part the sidebar
cannot undo. The branch goes last, after the post-delete hook, so a hook that
pushes it still finds it.

## A bare repository is a project

`--is-inside-work-tree` prints `false` for one, and `--git-dir` succeeds
anywhere inside. A repository hidden as `proj/.bare` takes the name of the
folder holding it; cost: the default `../{project}-worktrees` then lands inside
`proj/`.

A project is the main worktree whatever was picked, because a linked worktree
lists the same worktrees and two rows would select together and share tabs.
Cost: the sidebar shows the repository's name, not the folder picked.

## A missing directory is refused, not worked around

A shell spawned in a missing directory silently lands in `$HOME`. A project
whose directory is gone stays dimmed rather than dropped, an unmounted drive
not being reason to delete someone's setup, and the failure is reported once.

## A local build is signed by a certificate, not ad hoc

macOS holds the spawning app responsible for what a process reads, so an alert
about a command in a pane names Multishell; hence the usage strings in the
Info.plist, the only place that can say a command asked. And hence a
certificate rather than ad hoc: a grant is keyed to the signature's designated
requirement, and an ad-hoc one is a bare cdhash, so every build asked again for
everything and a box already ticked denied in silence. Disclaiming the child
instead would mean owning the pty spawn, and the name would then be an unsigned
binary, which TCC refuses rather than asks about.

Cost: a setup step before the first build, and a certificate nothing else
trusts.

## A worktree's tabs sit in columns, and a column only ever sits beside another

Two agents in one worktree can be watched at once without either becoming a
pane of the other: a column has its own strip, its own active tab and its own
width. Never one above another, because a pane below is what a split already
is, and a tree of columns holding trees of panes would be two layouts doing
one job. So `TabGroup` is a flat record with a weight and the renderer is one
`WeightedSplit` on the horizontal axis.

A column is a record of its own rather than a field on the tab because it
outlives the tabs that pass through it: its width and which tab it shows have
to survive the last tab moving out and a new one moving in. It holds its own
`activeTabID`, where the worktree's active tab was a dictionary on the
workspace: git hands back worktree records on every refresh, and nothing
rediscovers a column.

A column never stands empty. Its last tab leaving takes it with it and hands
the focus to the column that slid into its place, which is what a strip does
when the active tab closes. Weights are relative, so the rest come back in
proportion with nothing to renormalise.

Only the edges of a terminal area take a tab. A band down each side makes a
column on that side, and the space between them offers nothing: the strip
above is where a tab goes to join a column, and a target over every terminal
in the window would be a second way to do that, drawn over everything. A band
refuses where halving the column would put either half under the minimum a
pane already has, so the drag springs back rather than making two columns
nobody can read.

One pane in the window asks for the keyboard, not one per column: a surface
given focus reports it back, which focuses its column, so two panes asking
would leave the columns trading the focus between renders.

Costs: `activeTabByWorktree` has left the state file, so an older build
reading a newer one forgets which tab each worktree had active. A tab written
before columns existed names no group, so `repairReferences` gathers a
worktree's ungrouped tabs into the one column they were saved as, and a hand
edit that loses a column is repaired the same way rather than by dropping
tabs. And everything that meant "the tab on screen" had to become "the tab on
screen in this column": `isShown`, the Done state that clears when it is
looked at, and the notification that is not raised because it was.

## A dragged tab is its own preview

AppKit draws the preview for a SwiftUI `.onDrag` itself, as an elevated card,
and holds it on screen for the best part of a second after the mouse comes up,
wherever the tab landed. Nothing in SwiftUI's drag API reaches that disposal:
answering the drop before moving the tab, so the drag ends against the view
tree it began in, made no difference, and neither would any return value — the
image is AppKit's. So `.onDrag` is given a one-point clear preview and there
is nothing to hold.

What shows the drag instead is the tab. Along its own strip it moves as the
pointer passes each of its neighbours, which is what a tab strip does
everywhere, and the arithmetic that decides has to agree with the store's
exactly or the tab moves on every mouse event and never settles: hence
`TabShuffle`, tested against the same index sum. The tab that just slid under
the pointer is not an anchor to move itself past, which is what keeps it from
oscillating. Elsewhere the tab stays where it is and fades, and the place it
would land lights up: a line in another column's strip, a band over a
terminal, a row in the sidebar.

Only within one column. A tab crossing into another column waits for the drop,
because a column emptied by the move closes, and closing one under the pointer
takes the layout out from under a drag that is still going on.

Costs: a reorder is committed as the pointer passes, so a drag abandoned
half-way leaves the tabs where it dragged them rather than springing back;
saves are coalesced at 300 ms, so a drag's worth of moves is one write.
Nothing follows the cursor outside a strip, which is a departure from the Mac
convention of carrying a ghost, and bringing one back means owning the drag as
an AppKit source, where the image and the session's
`animatesToStartingPositionsOnCancelOrFail` are settable — and owning the
tab's click, double click and middle click with it.

## A strip out of room scrolls, and says which way there is more

Every tab is drawn at one width, computed from the room and the count. They
share the strip up to a cap, shrink together as more arrive, and stop at a
floor: below it the icon, the title and the close button have nowhere to go
and run into each other and into the next tab, which is what a strip with no
overflow behaviour looks like. Past the floor it scrolls and clips.

A column's own minimum width is not the answer to that, which is where this
started: a minimum would have to grow with the number of tabs, and a worktree
with eight of them would stop being something you can put beside another. The
floor belongs to the tab.

The end with tabs past it carries an arrow, in a gutter of its own outside the
scroller. An arrow drawn over the tabs would either take the click meant for
the tab under it or sit there looking like a button and doing nothing, and a
gutter costs the room an arrow needs and buys a control that actually scrolls:
it moves on by the first whole tab past that end, a tab counting as seen if
any of it is. It was a fade at first, on the argument that a fade cannot be
mistaken for a control, and the fade turned out to be too quiet to read as
anything at all.

Both gutters keep their room whether an arrow is drawn or not, so the tabs do
not shift under the pointer as one end runs out, and that reserved room is
what the viewport is measured as: which arrow shows and how wide the view is
cannot then chase each other. A strip with no room for both gutters and a tab
besides has neither, or two arrows and nothing to scroll would be drawn over
the column beside it.

The New Tab button sits outside the scroller too, so a full strip cannot push
it out of reach, and the tab turned to is scrolled into view, since Cmd+T in a
full strip would otherwise open a tab nobody can see. Neither is laid out
beside a spacer: a scroller and a spacer are both infinitely flexible, and the
stack would divide the strip between the two.

Costs: no auto-scroll while a tab is dragged near an end, so a reorder reaches
only the tabs on screen; and a strip whose tabs differ widely in width is the
one shape where the shuffle could in principle cross a boundary twice.

## The focus ring and the fade are the theme's

Which pane the keystrokes go to was a one-point line in the theme's selection
colour, drawn only inside a split. Columns make that question sharper, and a
line that thin is the wrong answer at a glance, so both signals are theme
keys: `focusRing` is any colour, or empty for no line at all, and
`inactivePaneOpacity` fades every other pane towards the theme's own
background. The built-ins ring in their own blue rather than their selection
colour, which is mixed to sit under text and reads as a smudge as a line, and
fade unfocused panes to four fifths, which is legible without being asked for.

An unparsable colour falls back to the selection colour rather than reading
as off: a typo should cost the colour, not silently remove the thing the key
was setting. The fade clamps at a quarter, below which a pane looks broken
rather than unfocused.

The fade is a scrim in the theme's background colour laid over the pane, not
`.opacity` on the surface: the panes are `NSView`s, one of them Metal-backed,
and view opacity is not something both engines honour the same way. Hit
testing is off, so a click still reaches the terminal and focuses it, which is
what undims it. Cost: a light theme fades towards white, which is a wash
rather than a dimming, and a theme that turns both off has nothing left to
say where the keyboard is.

## Smaller decisions

- Sessions warm up when visited, a saved workspace implying dozens of shells at
  launch. Selecting a worktree opens a terminal unless told not to; a create is
  asked about separately, since a worktree asked for and a worktree looked at
  are not the same event. Cost: four settings where there were two.
- Engines coexist, "next launch" being a poor answer to an engine change. Cost:
  two renderers the theme conversion must keep identical, and a command reaches
  libghostty as one quoted line but SwiftTerm as an array. Both sit behind a
  protocol with a recording fake, which is how they are tested without a
  terminal.
- Ghostty's keybinds are unbound by name, not `keybind = clear`, which also
  removes alt+arrow word movement and super+backspace. The names and the menu
  items come from one `AppShortcuts` table, since a shortcut in only one list
  was a keystroke that worked everywhere but a pane. The clipboard ones stay
  bound: in a pane Cmd+C is Ghostty's copy of the terminal's selection, and
  unbinding it hands the keystroke to a menu item with nothing to copy.
- Paths are directory URLs always: a relative worktree path resolved against a
  URL Foundation took for a file lands in the parent.
- Errors are mapped, not stringified: the alert is the only place a user learns
  why something failed, so it gets git's own words.
- Project settings hosts `NSTabViewController` in `.toolbar` style, which
  SwiftUI gives only to the `Settings` scene, and asks about removing a project
  in that window, or the dialog would be behind it.
- Help is behind an (i): captions doubled every form's height and were read
  once. A caption is left only for a value computed live.
- Notifications are for reports, not bells, and nothing under ten seconds: `ls`
  is not news, a build is. A bell in a background tab is a dot.
- Which states raise a banner is three toggles on a tab of their own, not one
  picker with a rung per combination. The picker offered three of the eight
  answers and could not say "only when something failed", which is the whole
  of what some people want; a rung per combination is a menu nobody reads.
  Cost: a state file written by this build reads as off on a build with the
  picker, the settings being an object where a name was. What holds whichever
  toggles are on is a caption at the foot of the page: three toggles each
  carrying it behind their own (i) said it three times.
- Permission is asked for as a toggle goes on, not at the first report. The
  dialog then arrives while the user is looking at the thing it is about, and
  a refusal is answered where it can be acted on: the caption becomes where to
  lift it, since three toggles that do nothing say nothing about why. Only a
  state going on asks; asking on the way down is a question about something
  the user has just refused. The answer is runtime state, read as the page
  opens and as the app comes back to the front, because it is the system's,
  and the front is the return from the settings the caption points at. No
  desktop is named in the core: the place to lift a refusal comes from
  `Platform`, and a desktop that never asks answers `unavailable`, which is
  what keeps the page from promising a dialog nobody will see.
- Debug builds keep their own state file, socket and integration directory, so
  `make run` beside the installed app touches neither.
- The app package names its path dependency rather than only pointing at it.
  SwiftPM identifies a local package by its directory, which is `multishell`
  in a checkout and the branch's name in a worktree, so the unnamed form built
  from the checkout alone. Cost: the name is written twice, in the dependency
  and in the directory it usually matches.
- The terminal font is picked, not typed, some programming fonts not being
  marked fixed-pitch. A project icon is tinted from a theme slot rather than a
  hex, so a theme change keeps it in step with the terminal.
- The project icon is picked from a grouped palette read by shape, not a popup
  menu of names read line by line: the menu is what held the list to sixty,
  where the palette carries close to four hundred. It stayed keyboard-drivable
  like the menu it replaced, and its search covers a word for what each symbol
  is used for as well as its name, an SF Symbol being named for its picture
  rather than for a database or a git branch. Emoji, which a field beside the
  menu once set, are gone: they looked out of place, and a glyph is now a
  symbol name or nothing. Cost: a project that had one draws the folder. A
  glyph that is not a symbol name counts as no choice at all, one rule read
  the same way everywhere, so a leftover emoji neither masks the icon a
  repository's shared file names nor is written back into it. What a new name
  has to satisfy is in DEVELOP.md.
- One `WorktreeActions` menu serves the detail header, the sidebar's context
  menu and a board card's, the last under a heading naming the worktree, since
  the card carries a Clear Status of its own for the pane and two unlabelled
  ones would read as the same thing. A
  terminal editor opens as a tab, one run in the background failing silently
  with no tty; cost: a relaunch reopens the editor.
- New Worktree always opens, even with nothing selected, and its decisions are
  a tested value because a cancelled branch load once re-enabled Create against
  the wrong project. Its branch picker offers local branches only.
