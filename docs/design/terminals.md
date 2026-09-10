# Terminals and sessions

What a shell is launched as, what it reports, what can be dropped on it.
Newest at the bottom.

## A terminal's state comes from what runs in it

Neither engine can say a command is running -> engine activity means only what
Terminal.app's dot means, something happened here. Working and Waiting come
from reports alone. Exit code above 128 = a signal, usually Ctrl+C, not a
failure. Done and Failed are about the user -> showing the tab clears them.
Working and Waiting are about the process -> they stay while the user looks.
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
