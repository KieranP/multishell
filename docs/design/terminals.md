# Terminals and sessions

What a shell is launched as, what it reports, what can be dropped on it.
Newest at the bottom.

## A terminal's state comes from what runs in it

Neither engine can say a command is running -> engine activity means only what
Terminal.app's dot means, something happened here. Working and Waiting come
from reports alone. Exit code above 128 = a signal, usually Ctrl+C, not a
failure. Done is about the user -> being seen clears it, which is the tab on screen
and the app in front, one notion shared with the banner so the dot and the
notification cannot disagree about whether anyone looked; a pane can be the
shown one for hours with the window behind another app. Working and Waiting
are about the process -> they stay while the user looks. Failed takes half
of each: a failure is something to act on and a glance is not acting -> it
survives being seen as Working and Waiting do, and survives the process
dying as Done does, the thing that failed being gone by definition. Red
until the source reports again or the user clears it by hand. Cost: a
failure nobody deals with holds its dot until the shell is closed, which is
the point. The banner goes on the look either way, an interruption being
spent once it has interrupted.
Ctrl+C sends no Stop -> reports carry a pid the app watches. No timeout, a long
task not being a stale one. Cost: Cmd+W on a Working pane asks first.

## A closed tab ends its shell, next turn

libghostty no longer frees a surface in the view's `deinit`, the view outlives
any SwiftUI frame that adopted it, and on a process exit `close` runs inside
libghostty's own callback, where freeing the surface would free the object
mid-call. SwiftTerm cancels the monitor that would have reaped the child -> the
host reaps with `waitpid` itself. No signal to a child that already exited: the
pid may have been reissued.

## Shell integration is injected, never written to a user's file

Generated per session, reached through `ZDOTDIR` or `--init-file`, helper behind
a symlink refreshed at launch so a moved bundle breaks no hook line. An agent's
hooks are the one exception: appended on the user's click, copy kept. Under
Ghostty bash goes through `/bin/sh -c 'exec bash ...'`, Ghostty keying its own
injection on the command's first word and adding `--posix`, under which macOS's
bash 3.2 reads neither file.

`--init-file` is read in place of `.bashrc`, so the generated file reproduces a
login shell's chain itself: `/etc/profile`, then the first of `.bash_profile`,
`.bash_login`, `.profile`. `.bashrc` only where that found nothing, as a login
shell does -> whether one runs is the profile's business, and reading it here
as well ran it twice for everyone whose profile ends by sourcing it. A user
whose profile does not source it sees no `.bashrc` here, which is what they
already see in any login shell. Its DEBUG trap and `PROMPT_COMMAND` are chained
to, never replaced, both being installed by the time ours are.

## A click in the prompt moves the cursor, because the prompt claims it

Ghostty answers a click only for a shell whose OSC 133 A mark carries
`cl=line`, over cells its B mark called input; a claim with no input mark
answers silently. The engine points `ZDOTDIR` at its own bootstrap, which never
claims -> a zsh session names both, ours in `GHOSTTY_ZSH_ZDOTDIR`. The zsh claim
rides at the front of PS1, a plain A printed later withdrawing it; bash writes
the whole set and prints its A, else readline edits at the wrong column. No D:
the exit code is the socket's. Only when `TERM_PROGRAM` names ghostty, half a
set opening a prompt that never ends. Cost: no click-to-move under SwiftTerm,
none on the later lines of a multi-line buffer.

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
last of all. Ghostty writes none of this for bash itself: it refuses Apple's
3.2 outright, and the launch through `sh` hides the rest. C comes off the same
DEBUG trap as the hooks, a prompt marked without it answering a click while a
program is still running.

## Files dropped on a terminal are pasted, never run

Shell gets absolute quoted paths. An agent whose prompt reads mentions gets its
prefix, a catalogue column, and paths relative to the session's directory.
Which agent a pane holds is asked of what reported there, not of the tab: one
started by hand leaves `agentID` nil, and a tab keeps its id after the agent
quits.

Bracketed where the engine can frame it, trailing space, never a newline: the
user reads what landed and presses Return. A name with a control character is
left out altogether, no quoting stopping a newline from pressing Return itself.
Pane takes focus only if still on screen when the files land, since focus
switches and saves the worktree's tab.

A copy macOS made for this app is asked for again through its promise, into a
directory of ours swept once a week, because such a copy can sit somewhere the
app can read and the pane's shell cannot. Only a copy is refused, a copy not
being the file, recognised by the marks it carries rather than by reading it.

Costs: a promised drop cannot be refused back to the drag; a copy macOS stops
marking is pasted as a path again; a file whose name a terminal would act on
must be typed.

## Agents and shells are ids in the store, command lines at launch

Ids are strings -> a newer build's agent loads harmlessly on an older one, and
a custom shell is an id rather than a typed path, which would show as "not
installed" whether it exists or not. An agent launches as `agent; exec <shell>
-l`, so it is found on the terminal's PATH and a shell remains with the
scrollback. A session off disk resumes rather than starts: four saved agent tabs
must not start four agents. Cost: a shell without `-l -i -c` (nu, xonsh) still
gets `/bin/sh` for hooks.

Agents live under Homebrew, npm or a version manager, none of which a
Finder-launched app has on PATH -> one login-shell environment captured at
launch, with an eight second limit past which a poorer PATH beats empty
dropdowns. Auto-start opens the agent where a shell would have, held back until
the post-create hook ends. New Shell Tab always opens a shell, so one stays
reachable.

## A user's Ghostty config is the middle of three layers

This app's terminal defaults first, the user's Ghostty config over them, the
theme over both. So the file decides font family, cursor, scrollback, padding
and the rest, and cannot decide the colours the chrome is painted to match or
the font size a settings row owns. Keybinds arrive as written, less the app's
own combinations, unbound by name as before -> a binding the user puts over a
menu item is theirs. Both the places Ghostty reads on a Mac,
`~/.config/ghostty/config` then the app-support file, which is the one
Ghostty writes and so has the later word. `XDG_CONFIG_HOME` is not read, an
app Finder launched not being given it. Read once, when the first Ghostty tab
creates the host. SwiftTerm reads none of it.

## A line libghostty refuses costs that line, not the file

libghostty answers one complaint by refusing the whole config and falling
back to its own defaults, where Ghostty names the line, skips it and carries
on. So the app does what Ghostty does: the lines a diagnostic names are
blanked and the rest offered again, three passes, then the app's defaults if
it is still refused. Line numbers are read out of the diagnostic text, which
is all there is -> a wrapper that words them differently costs the repair and
not the terminal. This is not a corner: libghostty here is not the build of
Ghostty a user runs, and the two differ in both directions. It has the newer
`scrollback-limit-bytes` and the older `scrollback-limit` both, and does not
have `copy-on-select = none`, which a current Ghostty writes.

## A user's config is read through a list of what is allowed

Not a list of what to refuse. The keys worth refusing are the ones about what
runs and what a window is, and those are the keys a Ghostty release is
likeliest to add another of -> a refusal list is one release behind, an
allowance list is only ever missing a nicety. 117 of Ghostty 1.3.2's 207 keys
are let through: whole families that can only draw or drive a surface
(`font-`, `adjust-`, `cursor-`, `mouse-`, `selection-`, `palette`,
`clipboard-`, `background`, `scrollback-`, `search-`, `bell-`, `link`,
`resize-overlay`, `window-padding-`) which carry 86 between them, and
thirty-one named one at a time, of which `macos-option-as-alt` is the only
`macos-` key a surface reads.

A family also carries a rename: `scrollback-limit` was split into
`scrollback-limit-bytes` and `scrollback-limit-lines`, and the family keeps
every spelling whichever build is pinned. What is left out is chrome that does
nothing in an embedding (`window-`, `macos-`, `gtk-`, `quick-terminal-`, the
app's own lifecycle) and these, which would take a decision the app has
already made: `command`, `initial-command` and `input` reach the child, the
first two in place of the session's shell and the third typed into it;
`working-directory` is the worktree; `title` is the name a tab reads from
escape sequences; `shell-integration` is the prompt marks click-to-move and a
command's exit code come from; `wait-after-command` holds a surface open after
its shell has gone. `env` is left out too, the app giving each child the
variables that name its session. `theme` is left out because this embedding
ships no themes directory, so it is the one complaint carrying no line number
for the repair above to place, and the app paints its own theme here anyway.

Cost: a key we have not thought about is ignored in silence, and nothing in
the app says which lines of a user's file did not count.

## The reporting line is built without anything the user's locale decides

The duration a shell hook sends is integer milliseconds with the point written
by hand, never `%f`, which takes the locale's decimal separator. Under a comma
region the field read `"duration":1,234`, which is not JSON: the reader drops
the whole line rather than the number, so the report never arrives and the pane
sits on Running until the next command. It cannot be fixed by a locale prefix
on the printf, zsh setting its locale once at startup and `LC_ALL` outranking
`LC_NUMERIC` in any case. Clamped at zero for the same reason the separator
matters: `%03d` of a negative prints its sign, so `0.-234` after a clock
stepped back over a sleeping laptop would break the line exactly as a comma
did. bash's `EPOCHREALTIME` carries the same separator, so the
fraction there is cut at either one: matching a dot alone left the whole
string in the arithmetic and reported a duration of six figures.
