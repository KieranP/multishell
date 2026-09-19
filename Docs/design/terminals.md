# Terminals and sessions

What a shell is launched as, what it reports, what can be dropped on it. Newest
at the bottom.

## A terminal's state comes from what runs in it

libghostty cannot say a command is running -> engine activity means only what
Terminal.app's dot means, something happened here. Working and Waiting come from
reports alone. Exit code above 128 = a signal, usually Ctrl+C, not a failure.
Done is about the user -> being seen clears it, which is the pane with the
keyboard and the app in front; a pane can be the focused one for hours with the
window behind another app. A click into a pane moves the keyboard through the
engine and not through a reconcile, so the registry hands that focus back,
`onFocus`, and the model marks the pane seen from there. The engine's own
signals, a bell or a retitle, read the same notion: one in a split's other pane
puts a Done there that waits for its focus, where it used to be swallowed as
seen. Not every pane on screen: a split's other pane, and the other column's
tab, are in view and not looked at, so their Done waits for their focus, where
it used to clear with the worktree's selection and take a finished agent's dot
away before anyone read it. The banner is the other half and keeps the wider
notion: any pane on screen raises none, its Done being visible as a dot, and
loses one it had. So a Done can stand on a pane in view with no banner, which is
the state meant; the two never disagree about an off-screen pane, which gets
both. Working and Waiting are about the process -> they stay while the user
looks. Failed takes half of each: a failure is something to act on and a glance
is not acting -> it survives being seen as Working and Waiting do, and survives
the process dying as Done does, the thing that failed being gone by definition.
Red until the source reports again or the user clears it by hand. Cost: a
failure nobody deals with holds its dot until the shell is closed, which is the
point. The banner goes on the look either way, an interruption being spent once
it has interrupted.

Ctrl+C sends no Stop -> reports carry a pid the app polls. No timeout, a long
task not being a stale one. Cost: Cmd+W on a Working pane asks first. The
shell's own end-of-command is the one engine signal that outranks a report: it
settles background workers, the owed Done and which agent is at the prompt,
since whatever was in the foreground has returned; see agents.md.

## A closed tab ends its shell, next turn

libghostty no longer frees a surface in the view's `deinit`, the view outlives
any SwiftUI frame that adopted it, and on a process exit `close` runs inside
libghostty's own callback, where freeing the surface would free the object
mid-call.

## Shell integration is injected, never written to a user's file

Written at launch into the app's own directory, one `ZDOTDIR` and one
`--init-file` every session is pointed at; the helper sits behind a symlink
refreshed at the same time, so a moved bundle breaks no hook line. An agent's
hooks are the one exception: appended on the user's click, copy kept. Under
Ghostty bash goes through `/bin/sh -c 'exec bash ...'`, Ghostty keying its own
injection on the command's first word and adding `--posix`, under which macOS's
bash 3.2 reads neither file.

A session starts as Terminal.app's does, with no `ZDOTDIR` of the user's, and
the chain picks up one their own files set: `.zshenv` and `.zprofile` each
capture what they left, `.zshrc` hands it back. The login shell's captured
environment is not handed in as the user's, though it would carry a `ZDOTDIR`
set in either file: our `.zshenv` would then source `$ZDOTDIR/.zshenv` in place
of `~/.zshenv`, skipping the file that set it and whatever else it exported, for
everyone on the documented route. Cost: a `ZDOTDIR` set in `/etc/zprofile`
redirects zsh past our remaining files, as it would past any, and that tab has
no hooks.

`--init-file` is read in place of `.bashrc`, so the generated file reproduces a
login shell's chain itself: `/etc/profile`, then the first of `.bash_profile`,
`.bash_login`, `.profile`. `.bashrc` only where that found nothing, as a login
shell does -> whether one runs is the profile's business, and reading it here as
well ran it twice for everyone whose profile ends by sourcing it. A user whose
profile does not source it sees no `.bashrc` here, which is what they already
see in any login shell. Its DEBUG trap and `PROMPT_COMMAND` are chained to,
never replaced.

The trap is taken back at every prompt rather than captured once: bash-preexec,
which Atuin's bash install ships, installs its own at the first prompt, long
after `.bashrc` has returned, and its own saved trap was read before ours
existed -> ours was replaced and nothing was reported for the rest of the
session, with no sign of it. Both halves of the claim are spliced into
`PROMPT_COMMAND` as text rather than called from a function: inside an untraced
function bash reports no DEBUG trap and puts back the one set, so a function
could neither see theirs nor install ours. Cost: one `trap -p` subshell per
prompt.

Theirs is unquoted before it is kept, `trap -p` printing a body quoted for
re-input: eval of a body still wearing its quotes runs the whole of it as one
word, which for every real trap body is a line of shell complaint per command
rather than the call it was meant to be. That held for the `.bashrc` trap this
has always chained to, not just for a later one.

`_multishell_precmd` ends by returning the status it was given: bash does not
restore `$?` between `PROMPT_COMMAND` entries, so a prompt of the user's that
opens with `local ret=$?` read ours instead and every command looked successful.
zsh needs none of this, restoring `lastval` around each `precmd_functions`
entry.

A command starting also carries the program's name, its first word without a
path, and only where that word is one of the agents: the list is filled into the
generated file, so the shell decides and nothing else the user runs is reported.
That is what marks an agent typed at a prompt on a machine with none of its
hooks installed; see agents.md.

Which word that is, the two shells reach differently. bash's `BASH_COMMAND` is
already alias-expanded; zsh hands preexec the line as typed in `$1` and the
expanded one in `$2`, so `$2` is what is read, or an
`alias claude='claude --flag'` left the pane a plain shell. zsh splits it into a
real array first: `${${(z)1}[1]}` subscripts words for `codex --x` and
characters for a lone `/path/to/codex`, which came out empty. Both then step
over a leading `VAR=value`, `command`, `env` or `exec` before taking the word.

It also disarms the trap before anything else runs at the prompt. The arm is set
last in `PROMPT_COMMAND` and consumed by the next command's DEBUG firing; an
empty Enter runs no command, so the arm lived on into the next prompt, where the
user's own entry (`history -a`, starship, direnv) fired first and was reported
as a command starting. The dot read Working until the next Enter, whose precmd
reported it finished with the whole idle time as duration. zsh has no preexec
for an empty line and never had this.

## A click in the prompt moves the cursor, because the prompt claims it

Ghostty answers a click only for a shell whose OSC 133 A mark carries `cl=line`,
over cells its B mark called input; a claim with no input mark answers silently.
The engine points `ZDOTDIR` at its own bootstrap, which never claims -> a zsh
session names both, ours in `GHOSTTY_ZSH_ZDOTDIR`. The zsh claim rides at the
front of PS1, a plain A printed later withdrawing it; bash writes the whole set
and prints its A, else readline edits at the wrong column. No D: the exit code
is the socket's. Only when `TERM_PROGRAM` names ghostty, half a set opening a
prompt that never ends. Cost: no click-to-move on the later lines of a
multi-line buffer.

Why the zsh claim rides in PS1 rather than being printed: libghostty ships an
MIT rewrite of the integration, not Ghostty's own GPLv3 one, and it claims
nothing while printing a plain A from a precmd registered after ours, which
would withdraw ours. PS1 is expanded once every precmd has run, and again on
every redraw -> riding it is what makes ours the last A the terminal sees. Both
halves put an input mark on the end of PS1 and each sees the other's. Output
start is printed by both, harmlessly twice; it earns its place where that
integration is absent, the claim otherwise standing for the whole session and
every click in a program's own screen being taken as one in a prompt.

bash's A is printed instead, because it moves to a fresh line where a command
left the cursor mid-line, and inside PS1 that would be a line readline had been
told cost nothing. Its input mark rides the end of PS1, put back after any
framework has rebuilt it from a `PROMPT_COMMAND`, which is why the marks run
last of all. Ghostty writes none of this for bash itself: it refuses Apple's 3.2
outright, and the launch through `sh` hides the rest. C comes off the same DEBUG
trap as the hooks, a prompt marked without it answering a click while a program
is still running.

## Files dropped on a terminal are pasted, never run

Shell gets absolute quoted paths. An agent whose prompt reads mentions gets its
prefix, a catalogue column, and paths relative to the session's directory. Which
agent a pane holds is asked of what reported there, not of the tab: one started
by hand leaves `agentID` nil, and a tab keeps its id after the agent quits.

Bracketed where the engine can frame it, trailing space, never a newline: the
user reads what landed and presses Return. A name with a control character is
left out altogether, no quoting stopping a newline from pressing Return itself.
Pane takes focus only if still on screen when the files land, since focus
switches and saves the worktree's tab.

A copy macOS made for this app is asked for again through its promise, into a
directory of ours swept of drops older than a week, because such a copy can sit
somewhere the app can read and the pane's shell cannot. Only a copy is refused,
a copy not being the file, recognised by the `TemporaryItems` and `NSIRD_` marks
it carries rather than by reading it.

Costs: a promised drop cannot be refused back to the drag; a copy macOS stops
marking is pasted as a path again; a file whose name a terminal would act on
must be typed.

## Agents and shells are ids in the store, command lines at launch

Ids are strings -> a newer build's agent loads harmlessly on an older one, and a
custom shell is an id rather than a typed path, which would show as "not
installed" whether it exists or not. An agent launches through the login shell,
`-l -i -c 'agent; exec <shell>'`, the exec carrying the integration a fresh tab
gets: the agent is found on the terminal's PATH and a shell remains with the
scrollback. A session off disk resumes rather than starts: four saved agent tabs
must not start four agents. Cost: a shell without `-l -i -c` (nu, xonsh) still
gets `/bin/sh` for hooks.

Agents live under Homebrew, npm or a version manager, none of which a
Finder-launched app has on PATH -> one login-shell environment captured at
launch, with an eight second limit past which a poorer PATH beats empty
dropdowns. Its `env -0` output is read from the first line shaped `KEY=`: an rc
file's greeting lands in front of the first entry, and cutting at the first `=`
gave a banner of `====` an empty key and lost that entry, PATH when the shell
exported it first, so git fell back to the Finder's PATH and a Homebrew git was
not found. A greeting line itself shaped `word=word` is still not told apart
(known-gaps.md). Auto-start opens the agent where a shell would have, held back
until the post-create hook ends. New Shell Tab always opens a shell, so one
stays reachable. The hook ending is what opens that tab, wherever the user is
looking: out of view or under the Agents board the shell starts and the keyboard
stays put, the way every other background tab runs; in view it takes the
keyboard as a new tab does. The alternative, waiting for the next visit, went
through `select`, which reads the select pair of settings and closed the board
by itself, so a team that opens a terminal on create and not on select got
nothing.

## A user's Ghostty config is the middle of three layers

This app's terminal defaults first, the user's Ghostty config over them, the
theme over both. So the file decides font family, cursor, scrollback, padding
and the rest, and cannot decide the colours the chrome is painted to match or
the font size a settings row owns. Keybinds arrive as written, less the app's
own combinations and the keys it releases (`AppShortcuts.surfaceReleases`,
Escape so far), unbound by name as before -> a binding the user puts over a menu
item, or on Escape, is theirs no longer. Both the places Ghostty reads on a Mac,
`~/.config/ghostty/config` then the app-support file, which is the one Ghostty
writes and so has the later word. `XDG_CONFIG_HOME` is not read, an app Finder
launched not being given it. Read once, when the host is created.

The merged text goes to libghostty through a file the wrapper writes under the
temp directory, named for the bundle. The wrapper removes that file when it
replaces it and never otherwise, so the host clears the directory once and again
at quit. Every copy of the build shares that directory -> only the copy holding
the instance socket may sweep it, which the model says with `claimSharedFiles`
once `startStateSource` has succeeded. A copy that handed over keeps its
terminals until it quits, and sweeping from it would take the running copy's
file; gating on "did this copy build a controller" did not catch that, since a
copy that yielded still opens terminals. Cost: a yielded copy's own file is left
until the next launch that owns the socket clears it.

## A line libghostty refuses costs that line, not the file

libghostty answers one complaint by refusing the whole config and falling back
to its own defaults, where Ghostty names the line, skips it and carries on. So
the app does what Ghostty does: the lines a diagnostic names are blanked and the
rest offered again, three passes, then the app's defaults if it is still
refused. Line numbers are read out of the diagnostic text, which is all there is
-> a wrapper that words them differently costs the repair and not the terminal.
This is not a corner: libghostty here is not the build of Ghostty a user runs,
and the two differ in both directions. It has the newer `scrollback-limit-bytes`
and the older `scrollback-limit` both, and does not have
`copy-on-select = none`, which a current Ghostty writes.

## A user's config is read through a list of what is allowed

Not a list of what to refuse. The keys worth refusing are the ones about what
runs and what a window is, and those are the keys a Ghostty release is likeliest
to add another of -> a refusal list is one release behind, an allowance list is
only ever missing a nicety. 117 of Ghostty 1.3.2's 207 keys are let through:
fourteen families that can only draw or drive a surface (`font-`, `adjust-`,
`cursor-`, `mouse-`, `selection-`, `palette`, `clipboard-`, `background`,
`scrollback-`, `search-`, `bell-`, `link`, `resize-overlay`, `window-padding-`)
which carry 86 between them, and thirty-one named one at a time, of which
`macos-option-as-alt` is the only `macos-` key a surface reads.

A family also carries a rename: `scrollback-limit` was split into
`scrollback-limit-bytes` and `scrollback-limit-lines`, and the family keeps
every spelling whichever build is pinned. What is left out is chrome that does
nothing in an embedding (`window-`, `macos-`, `gtk-`, `quick-terminal-`, the
app's own lifecycle) and these, which would take a decision the app has already
made: `command`, `initial-command` and `input` reach the child, the first two in
place of the session's shell and the third typed into it; `working-directory` is
the worktree; `title` is the name a tab reads from escape sequences;
`shell-integration` is the prompt marks click-to-move and a command's exit code
come from; `wait-after-command` holds a surface open after its shell has gone.
`env` is left out too, the app giving each child the variables that name its
session. `theme` is left out because this embedding ships no themes directory,
so it is the one complaint carrying no line number for the repair above to
place, and the app paints its own theme here anyway.

Cost: a key we have not thought about is ignored in silence, and nothing in the
app says which lines of a user's file did not count.

## The reporting line is built without anything the user's locale decides

The duration a shell hook sends is integer milliseconds with the point written
by hand, never `%f`, which takes the locale's decimal separator. Under a comma
region the field read `"duration":1,234`, which is not JSON: the reader drops
the whole line rather than the number, so the report never arrives and the pane
sits on Running until the next command. It cannot be fixed by a locale prefix on
the printf, zsh setting its locale once at startup and `LC_ALL` outranking
`LC_NUMERIC` in any case. Clamped at zero for the same reason the separator
matters: `%03d` of a negative prints its sign, so `0.-234` after a clock stepped
back over a sleeping laptop would break the line exactly as a comma did. bash's
`EPOCHREALTIME` carries the same separator, so the fraction there is cut at
either one: matching a dot alone left the whole string in the arithmetic and
reported a duration of six figures.

The worktree path goes onto the zsh-built line with its control characters
written as `\u00XX`, and is built once at startup rather than per report. git
refuses one in a branch name but not in a parent directory, which the worktree
list is read with `-z` to allow, and a raw tab or newline made every line from
that tab unparseable: the reader dropped them all in silence, and the zsocket
path being taken on any stock zsh, the helper that encodes correctly was never
reached. bash always goes through the helper.

## Find is the engine's search under a bar of ours

libghostty searches its own scrollback and highlights what it finds, driven by
three keybind actions: `search:<needle>`, `navigate_search:next|previous` and
`end_search`. The bar is the app's, since the engine's own is a GUI the
embedding never shows. A bar is a pane's own, keyed by session with its own
needle, and nothing about one reaches another: a bar left up in one worktree is
still up, its search still running, when the user comes back, and Cmd+F in
another worktree opens that pane's own bar, empty, rather than moving the first.
The first cut had one bar in the window that followed the keystroke, and Find
Next in a second worktree pulled a search out from under the first. The needle
is kept per pane across closes, as the Mac's find field is: Cmd+F on a bar that
is down searches it again so the matches light up. The menu's Find… is disabled
with no terminal tab in view. Every find keystroke acts on the bar whose field
has the keyboard, else on the focused pane of the tab in front: Cmd+F there asks
for that field again rather than opening the focused pane's bar, and Find Next,
Find Previous and Close Find are disabled while that pane has no bar. The
field's case is told apart because clicking into a field moves the store's focus
nowhere: without it, Cmd+G typed in one pane's field stepped the other pane's
search in a split. A bar's own Return and arrows act on its pane whichever pane
has the keyboard. Escape in the field, the close and Cmd+Shift+F from the pane
all take the bar down and hand the keyboard to the bar's own pane, as the
sidebar filter hands it back: that pane and not the focused one, since clicking
into a field moves the store's focus nowhere. The field takes the keyboard on
Cmd+F alone, through a request the bar claims once it is on screen; a bar a
worktree switch brings back claims nothing, so the keyboard stays in the pane
the user turned to.

Next walks down the scrollback towards the prompt and Previous up, as
Terminal.app's do, wrapping at either end in the engine's own index arithmetic.
Ghostty's own `next` walks the other way, newest to oldest, so the host crosses
them. Typing highlights the matches and selects none, and the first step after a
needle, whichever arrow asked, lands on the match nearest the prompt, which is
the one nearest what is on screen; from there Return walks down, wrapping to the
oldest, and Shift+Return or the up arrow walks up. The model keeps which panes
have a selected match, since the engine reports nothing back, and a new needle
or a reopened bar starts over. Cost: typing alone scrolls nowhere, and the first
Return after the nearest match wraps to the top of the scrollback.

Four of Ghostty's own bindings meet this. Cmd+F, Cmd+G, Cmd+Shift+G and
Cmd+Shift+F are unbound like every other menu shortcut, the first opening a bar
this embedding never shows and the last ending a search under a bar of ours that
stayed up. Escape is released too: Ghostty binds it to end the search as a
performable key, so while a search ran it ate Escape in the pane and ended the
search under our bar; released, Escape is a plain key again and only the bar
ends a search. Cmd+E, Ghostty's search-for-selection, is left bound and does
nothing here, its whole effect being a start-search action the wrapper drops,
and the app cannot offer it itself because the wrapper keeps the surface's
selection internal.

The same needle set again is nothing to the model: the field commits its binding
on Return as well as on each keystroke, and a repeat taken as a change would
send the needle again and start the selection over, so Return landed nearest the
prompt instead of stepping. Before the first step was the model's to send it was
paired with the needle in the host, and the repeat then made Return skip every
other match.

Three engine facts decide the shape of that. A needle change highlights the
matches in view and selects none, nothing scrolling until a navigate arrives. A
navigate sent with the needle selects nothing either: both go through the search
thread's one mailbox, which drains both before the thread has matched anything,
so `selectNext` finds no results and returns false; the first cut paired them
and typing never jumped, which is why the first step is the model's to send and
to remember. A needle differing from the last only in case is unchanged to the
engine, so the selection stands and the step after it moves on by one. And an
empty needle ends the engine's search outright, its thread stopped, so `search:`
with nothing after it is what an emptied field sends and `end_search` what the
bar's close sends, the second also telling the engine's own bar, which this
embedding has none of.

Cost: no "3 of 12". The engine reports its match count and which is selected
through two actions the wrapper logs and drops, on its main branch as on the
pinned tag, so the bar cannot say how many there are or when it has wrapped.
Only a patch to the wrapper buys it back, and a count was judged not worth
carrying one; known-gaps.md.
