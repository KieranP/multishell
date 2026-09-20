# Terminals and sessions

What a shell is launched as, what it reports, what can be dropped on it. Newest
at the bottom.

- **A terminal's state comes from what runs in it.** The engine cannot say a
  command is running, so engine activity means only what a terminal's dot means:
  something happened here. Working and Waiting come from reports alone.
- **An exit code above the signal boundary is a signal**, usually an interrupt,
  not a failure.
- **Done is about the user, so being seen clears it**: the pane with the
  keyboard, and the app in front. A pane can be focused for hours with the
  window behind another app.
- **A click into a pane moves the keyboard through the engine**, not through a
  reconcile, so the registry hands that focus back and the model marks the pane
  seen from there.
- **Not every pane on screen counts as seen.** A split's other pane and the
  other column's tab are in view and not looked at, where clearing on the
  worktree's selection took a finished agent's dot away before anyone read it.
- **The banner keeps the wider notion**: any pane on screen raises none and
  loses one it had. So a Done can stand on a pane in view with no banner, and
  the two never disagree about an off-screen pane.
- **Working and Waiting are about the process**, so they stay while the user
  looks.
- **Failed takes half of each**: a failure is something to act on and a glance
  is not acting, so it survives being seen and survives the process dying, the
  thing that failed being gone by definition.
- **Red until the source reports again or the user clears it.** Cost: a failure
  nobody deals with holds its dot until the shell is closed, which is the point.
- **An interrupt sends no stop**, so reports carry a pid the app polls. No
  timeout, a long task not being a stale one. Cost: closing a working pane asks
  first.
- **The shell's own end-of-command outranks a report.** It settles background
  workers, the owed Done and which agent is at the prompt, whatever was in the
  foreground having returned (agents.md).
- **A closed tab ends its shell next turn.** The engine no longer frees a
  surface in the view's deinit, the view outlives any frame that adopted it, and
  on a process exit the close runs inside the engine's own callback, where
  freeing would free the object mid-call.
- **Shell integration is injected, never written to a user's file.** It is
  written at launch into the app's own directory, and every session is pointed
  at it.
- **The helper sits behind a symlink refreshed at the same time**, so a moved
  bundle breaks no hook line. An agent's hooks are the one exception, appended
  on the user's click with a copy kept.
- **Under the engine, bash is launched through `sh`**, the engine keying its own
  injection on the command's first word and adding a POSIX flag under which
  macOS's bash reads neither file.
- **A session starts with no `ZDOTDIR` of the user's**, as a stock terminal
  does, and the chain picks up one their own files set: two of our files capture
  what they left and the third hands it back.
- **The captured login environment is not handed in as the user's**, though it
  would carry a `ZDOTDIR` set in either file: ours would then source that
  directory's copy in place of the home one, skipping the file that set it.
- **Cost: a `ZDOTDIR` set system-wide redirects zsh past our files**, as it
  would past any, and that tab has no hooks.
- **The bash init file is read in place of the rc file**, so the generated one
  reproduces a login shell's chain itself and reads the rc file only where that
  found nothing, as a login shell does.
- **Reading the rc file unconditionally ran it twice** for everyone whose
  profile ends by sourcing it. A user whose profile does not source it sees what
  they already see in any login shell.
- **The debug trap and prompt command are chained to, never replaced.**
- **The trap is taken back at every prompt** rather than captured once:
  bash-preexec installs its own at the first prompt, long after the rc file has
  returned, and read ours before it existed, so ours was replaced and nothing
  was reported for the rest of the session.
- **Both halves are spliced in as text, not called from a function**: inside an
  untraced function bash reports no debug trap and puts back the one set, so a
  function could neither see theirs nor install ours. Cost: a subshell per
  prompt.
- **Theirs is unquoted before it is kept**, the print form being quoted for
  re-input: eval of a body still wearing its quotes runs the whole of it as one
  word, a line of shell complaint per command.
- **Our prompt hook returns the status it was given.** bash does not restore the
  last status between prompt-command entries, so a user's prompt opening by
  reading it saw ours and every command looked successful. zsh needs none of
  this.
- **A command starting carries the program's name**, its first word without a
  path, and only where that word is one of the agents, the list being filled
  into the generated file so the shell decides.
- **That is what marks an agent typed at a prompt** on a machine with none of
  its hooks installed (agents.md).
- **The two shells reach that word differently.** bash's is already
  alias-expanded; zsh is handed the line as typed and the expanded one, and the
  expanded one is what is read, or an alias left the pane a plain shell.
- **zsh splits it into a real array first**, its word subscript taking
  characters rather than words for a bare path, which came out empty. Both then
  step over a leading assignment, `command`, `env` or `exec`.
- **The trap is disarmed before anything else runs at the prompt.** The arm is
  set last and consumed by the next command, so an empty Enter left it alive
  into the next prompt, where the user's own prompt entry was reported as a
  command starting.
- **That read as Working until the next Enter**, which then reported the whole
  idle time as its duration. zsh has no preexec for an empty line and never had
  this.
- **A click in the prompt moves the cursor because the prompt claims it.** The
  engine answers a click only for a shell whose prompt mark says the line is
  editable, over cells an input mark covers.
- **The engine points the shell at its own bootstrap**, which never claims, so a
  zsh session names both, ours behind the engine's variable.
- **The zsh claim rides at the front of the prompt string**, a plain mark
  printed later withdrawing it; bash prints the whole set instead, or readline
  edits at the wrong column.
- **No end mark**: the exit code is the socket's. And only where the terminal
  names itself, half a set opening a prompt that never ends. Cost: no
  click-to-move on the later lines of a multi-line buffer.
- **The claim rides the prompt string because of the other integration.** The
  engine ships an MIT rewrite that claims nothing while printing a plain mark
  from a hook registered after ours, which would withdraw ours; the prompt
  string is expanded last and on every redraw.
- **Both halves put an input mark at the end and each sees the other's.** The
  output-start mark is printed by both, harmlessly, and earns its place where
  that integration is absent, the claim otherwise standing for the whole
  session.
- **bash's start mark is printed rather than embedded**, because it moves to a
  fresh line where a command left the cursor mid-line, and inside the prompt
  string that would be a line readline had been told cost nothing.
- **Its input mark rides the end of the prompt string**, put back after any
  framework has rebuilt it, which is why the marks run last of all.
- **The engine writes none of this for bash itself**, refusing the system bash
  outright, and the launch through `sh` hides the rest. The command mark comes
  off the same debug trap as the hooks.
- **Files dropped on a terminal are pasted, never run.** A shell gets absolute
  quoted paths; an agent whose prompt reads mentions gets its prefix and paths
  relative to the session's directory.
- **Which agent a pane holds is asked of what reported there**, not of the tab:
  one started by hand leaves no id, and a tab keeps its id after the agent
  quits.
- **Bracketed where the engine can frame it, trailing space, never a newline**,
  so the user reads what landed and presses Return themselves.
- **A name with a control character is left out altogether**, no quoting
  stopping a newline from pressing Return itself.
- **The pane takes focus only if still on screen when the files land**, since
  focus switches and saves the worktree's tab.
- **A copy macOS made for this app is asked for again through its promise**,
  into a directory of ours swept of old drops, because such a copy can sit
  somewhere the app can read and the pane's shell cannot.
- **Only a copy is refused**, a copy not being the file, recognised by the marks
  it carries rather than by reading it.
- **Costs**: a promised drop cannot be refused back to the drag, a copy macOS
  stops marking is pasted as a path again, and a file whose name a terminal
  would act on must be typed.
- **Agents and shells are ids in the store, command lines at launch.** A newer
  build's agent loads harmlessly on an older one, and a custom shell is an id
  rather than a typed path, which would show as not installed either way.
- **An agent launches through the login shell and execs a shell after it**, the
  exec carrying the integration a fresh tab gets: the agent is found on the
  terminal's PATH and a shell remains with the scrollback.
- **A session off disk resumes rather than starts**: four saved agent tabs must
  not start four agents. Cost: a shell that cannot take the login-interactive
  form still gets a plain shell for hooks.
- **One login-shell environment is captured at launch**, agents living under
  Homebrew, npm or a version manager, none of which a Finder-launched app has on
  PATH. Past a time limit a poorer PATH beats empty dropdowns.
- **Its output is read from the first line shaped like an assignment**: an rc
  file's greeting lands in front of the first entry, and cutting at the first
  separator gave a banner an empty key and lost that entry, which was PATH.
- **A greeting line itself shaped like an assignment is still not told apart**
  (BUGS.md).
- **Auto-start opens the agent where a shell would have**, held back until the
  post-create hook ends. New Shell Tab always opens a shell, so one stays
  reachable.
- **The hook ending is what opens that tab**, wherever the user is looking: out
  of view the shell starts and the keyboard stays put, in view it takes the
  keyboard as a new tab does.
- **Waiting for the next visit went through the select path**, which reads the
  select settings and closed the board by itself, so a team that opens a
  terminal on create and not on select got nothing.
- **A user's Ghostty config is the middle of three layers**: this app's terminal
  defaults first, their file over them, the theme over both.
- **So their file decides font family, cursor, scrollback and padding**, and
  cannot decide the colours the chrome is painted to match or the font size a
  settings row owns.
- **Keybinds arrive as written**, less the app's own combinations and the keys
  it releases, unbound by name as before, so a binding they put over a menu item
  is theirs no longer.
- **Both places the engine reads on a Mac are read**, in its own order, the
  app-support one having the later word. The XDG variable is not read, an app
  the Finder launched not being given it. Read once, when the host is created.
- **The merged text reaches the engine through a file under the temp
  directory.** The wrapper removes that file only when it replaces it, so the
  host clears the directory at launch and at quit.
- **Every copy of the build shares that directory**, so only the copy holding
  the instance socket may sweep it. A copy that handed over keeps its terminals
  until it quits, and sweeping from it would take the running copy's file.
- **Cost: a yielded copy's own file is left** until the next launch that owns
  the socket clears it.
- **A line the engine refuses costs that line, not the file.** It answers one
  complaint by refusing the whole config and falling back to its own defaults,
  where Ghostty names the line and carries on.
- **So the app does what Ghostty does**: the lines a diagnostic names are
  blanked and the rest offered again, a few passes, then the app's defaults.
- **Line numbers are read out of the diagnostic text**, which is all there is,
  so a wrapper that words them differently costs the repair and not the
  terminal.
- **This is not a corner**: the embedded build is not the Ghostty a user runs,
  and the two differ in both directions, one carrying keys the other lacks.
- **A user's config is read through a list of what is allowed**, not a list of
  what to refuse. The keys worth refusing are the ones about what runs and what
  a window is, and those are the keys a release is likeliest to add another of.
- **So a refusal list is one release behind** where an allowance list is only
  ever missing a nicety.
- **What is allowed is families that can only draw or drive a surface**, plus a
  short list named one at a time, of which one option key is the only
  platform-prefixed key a surface reads.
- **A family also carries a rename**: a limit key that was split in two keeps
  every spelling whichever build is pinned.
- **What is left out is chrome that does nothing in an embedding**, and the keys
  that would take a decision the app has already made: the command and the input
  that reach the child, the working directory, the title, the integration the
  prompt marks come from, and holding a surface open after its shell has gone.
- **The environment key is left out too**, the app giving each child the
  variables that name its session.
- **The theme key is left out** because this embedding ships no themes
  directory, so it is the one complaint carrying no line number for the repair
  to place, and the app paints its own theme anyway.
- **Cost: a key we have not thought about is ignored in silence**, and nothing
  says which lines of a user's file did not count.
- **The reporting line is built without anything the user's locale decides.**
  The duration is integer milliseconds with the point written by hand, never a
  float format, which takes the locale's decimal separator.
- **Under a comma region the field was not JSON**, so the reader dropped the
  whole line and the pane sat on Running until the next command.
- **A locale prefix on the print cannot fix it**, zsh setting its locale once at
  startup and the blanket variable outranking the numeric one in any case.
- **Clamped at zero for the same reason**: a zero-padded negative prints its
  sign, so a clock stepped back over a sleeping laptop would break the line
  exactly as a comma did.
- **bash's clock variable carries the same separator**, so the fraction is cut
  at either one; matching a dot alone left the whole string in the arithmetic
  and reported six figures.
- **The worktree path is escaped on the zsh-built line** and built once at
  startup rather than per report.
- **git refuses a control character in a branch name but not in a parent
  directory**, which the NUL-terminated list is read to allow, and a raw tab or
  newline made every line from that tab unparseable, in silence.
- **The socket path is taken on any stock zsh**, so the helper that encodes
  correctly was never reached. bash always goes through the helper.
- **Find is the engine's search under a bar of ours**, driven by its three
  search actions. The bar is the app's, the engine's own being a GUI the
  embedding never shows.
- **A bar is a pane's own**, keyed by session with its own needle, and nothing
  about one reaches another: one left up in another worktree is still up when
  the user comes back.
- **The first cut had one bar in the window that followed the keystroke**, and
  Find Next in a second worktree pulled a search out from under the first.
- **The needle is kept per pane across closes**, as the Mac's find field is, and
  reopening searches it again so the matches light up.
- **Every find keystroke acts on the bar whose field has the keyboard**, else on
  the focused pane of the tab in front, and the next and previous items are
  disabled while that pane has no bar.
- **The field's case is told apart** because clicking into a field moves the
  store's focus nowhere: without it, the step keystroke typed in one pane's
  field stepped the other pane's search in a split.
- **Escape, the close button and the menu's close all hand the keyboard to the
  bar's own pane**, not the focused one, as the sidebar filter hands it back.
- **The field takes the keyboard on the open keystroke alone**, through a
  request the bar claims once it is on screen; a bar a worktree switch brings
  back claims nothing.
- **Next walks towards the prompt and Previous away**, as a stock terminal does,
  wrapping in the engine's own arithmetic. The engine's own next walks the other
  way, so the host crosses them.
- **Typing highlights and selects nothing**, and the first step after a needle,
  whichever arrow asked, lands on the match nearest the prompt, which is the one
  nearest what is on screen.
- **The model keeps which panes have a selected match**, the engine reporting
  nothing back, and a new needle or a reopened bar starts over. Cost: typing
  alone scrolls nowhere, and the first step wraps to the top of the scrollback.
- **Four of the engine's own bindings meet this**, unbound like every other menu
  shortcut, one of them opening a bar this embedding never shows and another
  ending a search under a bar of ours that stayed up.
- **Escape is released too**: the engine binds it to end the search as a
  performable key, so while a search ran it ate Escape in the pane. Released, it
  is a plain key again and only the bar ends a search.
- **The engine's search-for-selection is left bound and does nothing here**, its
  whole effect being an action the wrapper drops, and the app cannot offer it,
  the wrapper keeping the selection internal.
- **The same needle set again is nothing to the model.** The field commits on
  Return as well as on each keystroke, and a repeat taken as a change would send
  the needle again and start the selection over.
- **Three engine facts decide that shape.** A needle change highlights and
  selects none, nothing scrolling until a navigate arrives.
- **A navigate sent with the needle selects nothing either**: both go through
  one mailbox, which drains before the thread has matched anything, so the first
  step is the model's to send and to remember.
- **A needle differing only in case is unchanged to the engine**, so the
  selection stands and the step after it moves on by one.
- **An empty needle ends the engine's search outright**, so an emptied field
  sends a search with nothing after it and the bar's close sends the end action,
  which also tells the engine's own bar.
- **Cost: no "3 of 12".** The engine reports its match count and which is
  selected through two actions the wrapper logs and drops, on its main branch as
  on the pinned tag, so only a patch to the wrapper buys it back (BUGS.md).
- **Sessions warm up when visited**, a saved workspace implying dozens of shells
  at launch. Selecting a worktree opens a terminal unless told not to; a create
  is asked about separately. Cost: four settings where there were two.
- **Ghostty keybinds are unbound by name**, not cleared wholesale, which also
  removes word movement and delete-to-start.
- **Names and menu items come from one shortcuts table**, a shortcut in only one
  list having been a keystroke that worked everywhere but a pane.
- **Clipboard binds stay bound**: in a pane the copy key is Ghostty's copy of
  the terminal's selection, and unbinding it hands the keystroke to a menu item
  with nothing to copy.
- **Notifications are for reports, not bells**, and nothing short: a listing is
  not news, a build is. A bell in a background tab is a dot.
- **A terminal editor opens as a tab**, one run in the background failing
  silently with no tty. Cost: a relaunch reopens the editor.
- **That background launch captures nothing and is never timed out.** A shim can
  hold the editor open as long as the file is, so a bound would end the editor
  the user just asked for, and pipes were two descriptors per click for the life
  of the app.
- **One banner per pane, replaced rather than added to.** A request carries the
  state key as its identifier, so a terminal holds one row in Notification
  Centre saying what its dot says.
- **Stacking four reports described one pane four times**, three of them wrong
  by the time they were read. The identifier and not the thread identifier,
  which groups rows without retiring stale ones.
- **A banner is taken back when what it said stops being true**: the state
  moving on, or the user reaching the pane. Waiting survives being looked at,
  its question still standing.
- **Reaching it is one flag, computed once per report.** Two flags let a turn
  ending in a shown pane while the user was in another app raise a banner and
  clear the dot in the same breath, each right by its own rule.
- **So returning to the app is a look**, alongside selecting, activating and
  closing the board; a shell exiting while the user is elsewhere is not.
- **Taking back removes the pending request too**, delivery landing a moment
  after the call returns, in which a look landed and the banner then arrived
  with nothing left to retract it.
- **Only Done clears on the look.** Failed keeps its dot, so the banner and the
  dot say different things about one pane on purpose: the interruption spent,
  the thing to deal with still there.
- **The model keeps the keys it has posted about**, so nothing is taken back
  that was never there. Cost: a Done nobody looked at disappears when the next
  state lands, the dot being what persists.
- **One terminal engine, embedded and named outright.** It owns the pty, the
  renderer and the config, so the core never sees a descriptor and a pane's
  surface is Metal-backed.
- **Cost of one engine**: a pinned build that misbehaves has nothing to fall
  back to, the unfocused fade is a scrim rather than view opacity, and nothing
  tests the host against a real shell (BUGS.md).
- **The terminal host is told the app is quitting**, and told that it holds the
  instance socket. The engine's generated config directory is shared by every
  copy of the build, so only the copy that claimed sweeps it, on the claim and
  again at quit.
- **"Built a controller" was the earlier test and did not hold**: a copy that
  handed over keeps its terminals until it quits, so it builds one too. The
  controller is still built on first use, the theme held until there is one.
