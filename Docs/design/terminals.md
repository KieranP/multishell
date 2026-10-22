# Terminals and sessions

What a shell is launched as, what it reports, what can be dropped on it. Newest
at the bottom.

- **A terminal's state comes from what runs in it.** The engine cannot say a
  command is running, so engine activity means only what a dot means, that
  something happened here. Working and Waiting come from reports alone.
- **An exit code above the signal boundary is a signal**, usually an interrupt,
  not a failure.
- **Done is about the user, so being seen clears it**: the pane with the
  keyboard, and the app in front. A pane can be focused for hours with the
  window behind another app.
- **A click into a pane moves the keyboard through the engine**, not a
  reconcile, so the reconciler hands that focus back and the model marks the
  pane seen from there.
- **Not every pane on screen counts as seen.** A split's other pane and the
  other group's tab are in view and not looked at; clearing on the worktree's
  selection took a finished agent's dot away before anyone read it.
- **The banner keeps the wider notion**: any pane on screen raises none and
  loses one it had. So a Done can stand on a pane in view with no banner, and
  the two never disagree about an off-screen pane.
- **Working and Waiting are about the process**, so they stay while the user
  looks.
- **Failed survives being seen and the process dying.** A glance is not acting
  on a failure, and the thing that failed is gone by definition.
- **Red until the source reports again or the user clears it.** Cost: a failure
  nobody deals with holds its dot until the shell is closed, which is the point.
- **An interrupt sends no stop**, so reports carry a pid the app polls. No
  timeout, a long task not being a stale one. Cost: closing a pane whose agent
  is working asks first (agents.md).
- **The shell's own end-of-command outranks a report.** It settles background
  workers, the owed Done and which agent is at the prompt, whatever was in the
  foreground having returned (agents.md).
- **A closed tab ends its shell next turn.** The view outlives any frame that
  adopted it, so the host frees the surface rather than waiting for the view,
  and on a process exit the close runs inside libghostty's own callback, where
  freeing would free the surface mid-call.
- **Its reports stop at the close**, though the surface lives a turn longer: a
  report queued in it reached the model for a closed session
  (`aSessionReportsNothingOnceClosed`).
- **A close libghostty is asked for while the process runs goes through the
  app's own**, so a `close_surface` keybind asks first over a working agent, as
  Cmd+W does. Whether the process is there is asked of the surface; the
  callback's flag says only whether Ghostty would confirm, by its own rule.
- **Shell integration is injected, never written to a user's file.** It is
  written at launch into the app's own directory, and every session pointed at
  it.
- **The helper sits behind a symlink refreshed at the same time**, so a moved
  bundle breaks no hook line. An agent's hooks are the one exception, written
  only on the user's click: merged into a settings file of theirs with a copy
  kept, or a file of ours written whole (agents.md).
- **The engine's own shell integration is off** (`shell-integration = none`), so
  ours is the only one in a pane; two integrations printing marks from their own
  hooks fought over the prompt. develop/dependencies.md has its scripts'
  licence.
- **bash is launched through `sh`**: libghostty runs a command as `exec -l`,
  which makes bash a login shell, and a login bash skips `--init-file`. Run
  straight, a bash tab got none of our hooks (EngineCommandLineTests).
- **A session starts with no `ZDOTDIR` of the user's**, as a stock terminal
  does, unless the app's own environment has one, as after a launch from a
  shell; that one goes in as `MULTISHELL_USER_ZDOTDIR` for ours to chain to. Two
  of our files capture one their own files set and the third hands it back.
- **The captured login environment does not hand one in**: ours would then
  source that directory's copy in place of the home one, skipping the file that
  set it. Cost: a `ZDOTDIR` set system-wide redirects zsh past our files, as
  past any, and that tab has no hooks.
- **macOS's `/etc/zshrc` names the history file after `ZDOTDIR`**, and runs
  while it is still ours, so our `.zshrc` moves a history file inside our
  directory back to where the user's shell would have put it, before their own
  file can set another.
- **bash 5.1 made `PROMPT_COMMAND` an array**, so a user's array gets ours as
  elements; before 5.1 bash runs only element 0, so the string form goes there,
  or an array in the rc file silenced every hook.
- **The bash init file is read in place of the rc file**, so the generated one
  reproduces a login shell's chain and reads the rc file only where that found
  nothing, as a login shell does.
- **Reading the rc file unconditionally ran it twice** for everyone whose
  profile ends by sourcing it. A user whose profile does not source it sees what
  they see in any login shell.
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
  re-input: eval of a body still in its quotes runs it as one word, a line of
  shell complaint per command.
- **Our prompt hook returns the status it was given.** bash does not restore the
  last status between prompt-command entries, so a user's prompt reading it saw
  ours and every command looked successful. zsh needs none of this.
- **A command starting carries its first word where that names an agent**, which
  marks an agent typed at a prompt with no hooks installed (agents.md).
- **The two shells reach that word differently.** bash's is already
  alias-expanded; zsh is handed the line as typed and the expanded one, and the
  expanded one is read, or an alias left the pane a plain shell.
- **zsh splits it into a real array first**, its word subscript taking
  characters rather than words for a bare path, which came out empty.
- **A zsh hook returns 0 and counts words under zsh's own options.** Under a
  user's `err_exit` a hook returning 1 ended the shell at its first prompt, and
  under `ksh_arrays` the word list began at 0 and the agent's name was lost
  (`aUsersErrExitDoesNotEndTheShellAtItsFirstPrompt`).
- **The trap is disarmed before anything else runs at the prompt.** The arm is
  set last and consumed by the next command, so an empty Enter left it alive
  into the next prompt, which reported the user's own prompt entry as a command
  starting.
- **That read as Working until the next Enter**, which then reported the whole
  idle time as its duration. zsh has no preexec for an empty line and never had
  this.
- **A click in the prompt moves the cursor because the prompt claims it.** The
  engine answers a click only for a shell whose prompt mark says the line is
  editable, over cells an input mark covers.
- **The zsh claim rides at the front of the prompt string**, expanded last and
  on every redraw, so a prompt framework rebuilding it in a hook cannot leave
  the claim out; bash writes the whole set itself and prints its start mark, or
  readline edits at the wrong column.
- **zsh ends a command with its status** (`133;D`), which is where the engine's
  finished-command signal comes from; bash writes none, its exit code being the
  socket's alone. All of it only where the terminal names itself, half a set
  opening a prompt that never ends. Cost: no click-to-move on the later lines of
  a multi-line buffer.
- **The input mark goes on the end of a prompt only once**, our zsh hook leaving
  it off a prompt a framework already ended with one. The output-start mark ends
  the claim while a program runs.
- **zsh titles a pane and shapes its cursor as Ghostty's own integration does**:
  the directory at a prompt and the command while it runs, a bar to edit in, a
  block in vi command mode and the configured shape back for a program. Each
  only where the user's `shell-integration-features` ask, which Ghostty exports
  whatever the integration setting, `cursor:steady` and all. bash shapes no
  cursor.
- **zsh and bash wrap `sudo` and `ssh` where those features ask**, as Ghostty's
  own zsh integration did before ours replaced it: `sudo` keeps the bundled
  `TERMINFO`, root's terminfo having no `xterm-ghostty`, and `ssh` sends
  `xterm-256color`. A user's own function by either name is kept. bash never had
  Ghostty's, its tab starting through `sh`, which Ghostty does not integrate.
- **Cost: `ssh-terminfo` installs nothing on the host**, only sending that TERM
  as `ssh-env` does. Ghostty installs the entry and remembers each host through
  its own CLI, which the bundle does not carry.
- **The cursor follows a keymap change through zle's hook widgets**, chained
  rather than set, and stands back where the user has a keymap widget of their
  own: oh-my-zsh's vi-mode and prezto draw their own shapes there, and ours
  running after theirs overdrew them.
- **zsh reports its directory at each prompt and on every `cd`**, so a command
  after `cd x &&` resolves paths from the new one. Raw, in Ghostty's
  `kitty-shell-cwd://` form: percent-encoding tripled a long path past the 2 KB
  Ghostty reads it into. A directory holding a control character, able to end
  the sequence early, is reported as unknown, an empty report; unreported, the
  pane resolved links from the directory before it.
- **Only after a first prompt**, so a `zsh -c` a hook runs in prints nothing
  into the output the hook is judged by.
- **bash reports its directory at each prompt and at the first command after a
  `cd`**, from the DEBUG trap, bash having no `cd` hook: one builtin test per
  command, so `cd x && make` resolves `make`'s paths from `x`. fish 4 reports
  its own. Cost: a function that does both waits for the prompt, bash running
  the trap inside a function only under `set -T`, which would change the user's
  own traps.
- **bash titles its pane by directory at a prompt, never by the command**, `…/`
  and the last three parts as zsh and Ghostty do, a tab having room for the end
  of a path rather than the start. Only where the `title` feature asks: a pane
  with no title takes libghostty's from each directory report, the raw full
  path.
- **bash writes to the terminal on a descriptor of its own**, 61, opened on
  `/dev/tty`: the DEBUG trap runs inside a redirected block's redirect, and the
  output mark it printed there landed at the top of the file
  (`aBashBlockRedirectedToAFileGetsNoMarkInIt`). Not 63: a process substitution
  takes the highest free descriptor under 64, and with 63 held the relay's pipe
  landed on 62 and every report fell back to a helper (HelperRelayTests). It
  goes to `/dev/tty` only once a write there succeeds, and to stdout otherwise,
  a failed `exec` ending a script's shell.
- **Cost: no continuation-prompt marks**, which Ghostty's integration writes on
  PS2.
- **bash's start mark is printed rather than embedded**, because it moves to a
  fresh line where a command left the cursor mid-line, and inside the prompt
  string that would be a line readline had been told cost nothing.
- **Its input mark rides the end of the prompt string**, put back after any
  framework has rebuilt it, which is why the marks run last of all.
- **bash's command mark comes off the same debug trap as the hooks.**
- **Files dropped on a terminal are pasted, never run.** A shell gets absolute
  quoted paths; an agent whose prompt reads mentions gets its prefix and paths
  relative to the session's directory.
- **One quoting for every shell**, a backslash and a `!` going outside the
  quotes: tcsh at a prompt expands a `!` even inside them, and fish reads `\\`
  and `\'` inside single quotes as escapes, so a name ending in a backslash
  carried the next name out of its quotes. The pane's shell is not known at the
  drop anyway, a fish typed at a zsh prompt being fish. Cost: nu, whose single
  quotes have no escape at all, still breaks on a name holding one.
- **A drop asks which agent a pane holds as its mark does** (agents.md). Cost: a
  tab opened as an agent keeps its id, so a drop after the agent quits still
  gets mentions.
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
- **An item's file count is read as each file lands.** AppKit's `fileNames` is
  empty until the promise is called in, so counted up front, a legacy item
  naming several files counted as one and only the first was pasted.
- **Agents and shells are ids in the store, command lines at launch.** A newer
  build's agent loads harmlessly on an older one, and a custom shell is an id
  rather than a typed path, which would show as not installed either way.
- **An agent launches through the login shell and execs a shell after it**, the
  exec carrying the integration a fresh tab gets: the agent is found on the
  terminal's PATH and a shell remains with the scrollback.
- **Its words take the drop's quoting**, an editor tab's too: the login shell
  may be tcsh or fish, which read a `!` or a backslash inside single quotes. The
  exec after it takes the same; a `!` in its directory made tcsh stop at "Event
  not found" and leave no shell.
- **A session off disk resumes rather than starts**: four saved agent tabs must
  not start four agents. Cost: where the login shell cannot take the
  login-interactive form, as nu cannot, the agent runs under `/bin/sh` as a hook
  does, reading no startup file.
- **One login-shell environment is captured at launch**, agents living under
  Homebrew, npm or a version manager, none of which a Finder-launched app has on
  PATH. Past a time limit a poorer PATH beats empty dropdowns.
- **Its output is read from the first line shaped like an assignment**: an rc
  file's greeting lands in front of the first entry, and cutting at the first
  separator gave a banner an empty key and lost that entry, which was PATH.
- **So the capture prints a marker line first**, after whatever the rc files
  printed, and only what follows it is read: a greeting shaped like an
  assignment was taken for the first variable and swallowed it.
- **The capture runs with no history file**, as a hook does (hooks.md).
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
- **So their file decides cursor, scrollback and padding**, and font family
  while the font row says System monospace, and cannot decide the colours the
  chrome is painted to match or the font size a settings row owns.
- **Keybinds arrive as written**, less the app's own combinations and the keys
  it releases, unbound by name, so a binding they put over a menu item is theirs
  no longer.
- **Both places the engine reads on a Mac are read, under both names**, in its
  own order: `config` then `config.ghostty`, the XDG one then app support, each
  later file having the later word. The XDG variable is not read, an app the
  Finder launched not being given it. Read when the first terminal opens and
  each time the app comes to the front, the file being edited in another app;
  only a change is handed on.
- **Their `config-file` includes are followed here**, in the engine's order:
  each after the whole file naming it, a relative path from beside that file,
  `?` for one that may be missing, a file already read skipped. Left to the
  engine they would resolve from the temp directory the merged text is in.
- **A line ends at `\n` or `\r\n`**, as in Ghostty. Swift reads `\r\n` as one
  character, so a CRLF file split on `\n` was one line: its includes were lost
  and every key after the first rode through the allow list behind it.
- **The merged text reaches the engine through a file under the temp
  directory**, libghostty reading config from nothing else. The file goes the
  moment it is read, so no copy of the build leaves one for another to sweep.
- **A line the engine refuses costs that line, not the file**, as in Ghostty.
  The wrapper before it refused the whole file over one complaint, which the app
  undid by blanking lines and retrying; built here, the base goes over as is.
- **Each refusal goes to the unified log**, category `ghostty`, its line
  numbered in the merged config: the app's defaults, the user's settings, then
  the app's layer.
- **A config that could not be loaded at all is tried again**, at the next
  activation or theme change, and logged. The runtime keeps the text libghostty
  runs apart from what it was offered; recording the offer first skipped every
  retry until the file changed again.
- **This is not a corner**: the embedded build is not the Ghostty a user runs,
  and each carries keys the other lacks.
- **A user's config is read through a list of what is allowed**, not a list of
  what to refuse. The keys worth refusing are about what runs and what a window
  is, the kind a release is likeliest to add, so a refusal list is one release
  behind where an allowance list only ever misses a nicety.
- **Ghostty 0538f75 bore that out.** It added `vt-window-resize-allowed`, which
  lets a program resize the window, and the key stayed out with no edit here.
- **What is allowed is families that can only draw or drive a surface**, plus a
  short list named one at a time. Its only platform-prefixed keys are the option
  key, which a surface reads, and auto secure input, which the app reads back.
- **A family also carries a rename**: a limit key that was split in two keeps
  every spelling whichever build is pinned.
- **What is left out is chrome that does nothing in an embedding**, and the keys
  that would take a decision the app has already made: the command and the input
  that reach the child, the working directory, the title, the integration the
  prompt marks come from, and holding a surface open after its shell has gone.
- **The environment and theme keys are left out too**: the app gives each child
  the variables that name its session, and ships no themes directory, painting
  its own theme anyway.
- **Cost: a key we have not thought about is ignored in silence**, and nothing
  says which lines of a user's file did not count.
- **The reporting line is built without anything the user's locale decides.**
  The duration is integer milliseconds with the point written by hand. A float
  format took a comma region's separator, the field was not JSON, and the pane
  sat on Running until the next command. A locale prefix on the print cannot fix
  it, zsh setting its locale once at startup and the blanket variable outranking
  the numeric one anyway.
- **Clamped at zero for the same reason**: a zero-padded negative prints its
  sign, so a clock stepped back over a sleeping laptop broke the line as a comma
  did.
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
- **bash writes to one resident helper per shell**, `multishell relay` behind a
  process substitution on descriptor 62, since bash 3.2 cannot open a socket. A
  helper launched per report cost 9.4 ms a command, nearly all of it launch; a
  pipe keeps the order as running inline did.
- **The relay is started in the background of the substitution**, which then
  exits. bash 4.4 and later set `$!` to a process substitution and a bare `wait`
  waits on it (`wait_for_background_pids` in bash's `jobs.c`), so a relay that
  was the substitution itself hung it for the life of the tab.
- **Each write ignores SIGPIPE for itself alone**: a write to a relay that has
  gone kills an interactive bash. The disposition is put back before anything
  else runs, or it would pass to every command the user runs. A subshell per
  write did the same at two forks a command. A failed write sends that report
  and every later one inline.
- **What is put back is the handler standing at that write**, read each time.
  Read once at startup, a `trap … PIPE` set later was lost at the next report.
- **bash 5.3 reads it with `${ …; }`**, which runs in the shell: 0.14 ms a read
  against 0.47 ms. Cost before 5.3: a command substitution, a fork per report,
  as a subshell per write cost.
- **The prompt's read of the DEBUG trap keeps its fork, 5.3 included.** At the
  top level of the prompt command `${ …; }` runs the user's DEBUG trap on the
  read and captures what it prints, so bash-preexec took our read for a command.
  Cost: a fork a prompt. The PIPE read runs in a function, where it fires none.
- **A relay that exits in failure hands its pipe to a shell loop**, a helper
  launched per line. A helper older than `relay` exits 2 without reading, so
  what the shell wrote before that went nowhere, and only a later write's EPIPE
  turned it inline. Cost: lines the relay had read are lost.
- **The loop ends with the shell too**, asked each time a read waits a second.
  At EOF alone, a background child holding the pipe kept the loop's bash
  resident under launchd after the tab closed. bash 3.2 gives a timeout EOF's
  status, so a read that fails inside one tick of `SECONDS` is taken for EOF.
  Cost: a wake a second while the loop runs, and a timeout taken for EOF sends
  the rest inline.
- **The relay ignores interrupt, quit, job-control and hang-up**, sharing the
  shell's process group at the prompt, where a Ctrl-C reaches it. Cost: a
  resident process per bash tab.
- **The inline loop traps neither interrupt nor quit**: bash starts an `&` job
  with both ignored where job control is off, as inside the substitution, and
  the helper inherits that. A Ctrl-C at the prompt left the loop running under
  bash 3.2 and 5.3; one with interrupt reset to default lost every later line.
- **The relay ends at EOF or when the shell's pid exits**, whichever is first.
  bash has no close-on-exec, so every command inherits descriptor 62, and 61 the
  terminal reports go out on, and an editor or server started in the tab held
  the pipe open long after the tab closed.
- **Find is the engine's search under a bar of ours**, driven by its three
  search actions. The engine's own bar is a GUI the embedding never shows.
- **A bar is a pane's own**, keyed by session with its own find text, so one
  left up in another worktree is still up when the user comes back. The first
  cut had one bar in the window that followed the keystroke, and Find Next in a
  second worktree pulled a search out from under the first.
- **The find text is kept per pane across closes**, as the Mac's find field is,
  and reopening searches it again so the matches light up.
- **Every find keystroke acts on the bar whose field has the keyboard**, else on
  the focused pane of the tab in front, and next and previous are disabled while
  that pane has no bar. A file tab in front takes them all (files.md). Clicking
  into a field moves the store's focus nowhere, so without the field's case a
  step typed in one pane's field stepped the other pane's search in a split.
- **Escape, the close button and the menu's close all hand the keyboard to the
  bar's own pane**, not the focused one, as the sidebar filter hands it back.
  `panes find --close` moves no keyboard, even on the worktree in view, where a
  tab request takes it as its click would (architecture.md;
  `aCloseLeavesTheKeyboardWhereItWas`).
- **The field takes the keyboard on the open keystroke alone**, through a
  request the bar claims once on screen; a bar a worktree switch brings back
  claims nothing.
- **Next walks towards the prompt and Previous away**, as a stock terminal does,
  wrapping in the engine's own arithmetic. The engine's own next walks the other
  way, so the host crosses them.
- **Typing highlights and selects nothing**, and the first step after a new find
  text, whichever arrow asked, lands on the match nearest the prompt, which is
  the one nearest what is on screen.
- **The model keeps which panes have a selected match**, the engine reporting
  nothing back, and a new find text or a reopened bar starts over. Cost: typing
  alone scrolls nowhere, and the first Next after the nearest match wraps to the
  top of the scrollback.
- **Four of the engine's own bindings meet this**, unbound like every other menu
  shortcut, one opening a bar this embedding never shows and another ending a
  search under a bar of ours that stayed up.
- **Escape is released too**: the engine binds it to end the search as a
  performable key, so while a search ran it ate Escape in the pane. Released, it
  is a plain key again and only the bar ends a search.
- **Cmd+F over a selection in the pane finds its text**, read off the pane as
  the keystroke lands and set as if typed. A Cmd+F from the field keeps what was
  typed there.
- **A selection is taken once.** It stays drawn after the bar opens, so a Cmd+F
  after typing over it, or after closing the bar, took it back and lost the
  typed text (`aSelectionAlreadyTakenLeavesWhatWasTypedAfterIt`). A Cmd+F with
  nothing selected forgets it. Cost: the same text selected again with no Cmd+F
  between is not taken.
- **Only a selection on one line with something in it is taken**: the engine
  matches within a line, and Cmd+A then Cmd+F put the whole scrollback in the
  field. Its trailing spaces are dropped, as the copy key drops them, libghostty
  reading a selection with them kept.
- **The engine's search-for-selection is left bound and does nothing here**, its
  whole effect being an action the app does not answer. Cmd+F covers it.
- **The engine's match counts are kept per pane while its bar is up.** Its
  search total and selected index arrive as actions of their own, a turn after
  the search. A step drops the selected index until the engine names the new
  one, bar a step over the only match: the engine posts only a changed
  selection, and `panes find --next` waited out its two seconds. A find text
  differing only in ASCII case keeps both, the engine sending none for it
  (`aFindTextInAnotherCaseKeepsTheCountAndANewOneDropsIt`).
- **`panes find` prints a count once it holds for three looks**: the engine
  posts a 0 as a search changes, then a running total as it reads the scrollback
  (`aCountIsPrintedOnceTheEngineHasSettledNotItsInterimZero`). Cost: the total
  is the engine's, and after 200,000 lines it counted more matches than the
  scrollback it still held, read back whole. It keeps matches in pages it has
  pruned until a later feed sweeps them, which the host cannot ask for.
- **A key the command line presses is a key event, not text**: a US keyboard's
  key code and modifiers, with the text the current layout gives that key, as a
  real press carries, so libghostty encodes Ctrl+C, Escape and the arrows as a
  keyboard would. Option types the layout's character unless the user's
  `macos-option-as-alt` makes it Alt, asked of the surface for each key. Its
  modifier keys go down before it and up after, as a keyboard sends them:
  libghostty keeps the last modifiers it saw for the mouse, so a Cmd left held
  kept a link under the pointer lit (`GhosttyKeyInputModifierKeysTests`).
- **Cost: a key is named by its place on a US keyboard**, so on another layout
  `a` types what that key types there. `GhosttyKeyInputControlKeyTests` runs
  only under the US layout.
- **The same find text set again is nothing to the model.** The field commits on
  Return as well as on each keystroke, and a repeat taken as a change would send
  the find text again and start the selection over.
- **A navigate sent with the find text selects nothing**: both go through one
  mailbox, which drains before the thread has matched anything, so the first
  step is the model's to send and to remember.
- **Find text differing only in ASCII case is unchanged to the engine**, so the
  selection stands and the step after it moves on by one.
- **An empty find text ends the engine's search outright**, so an emptied field
  sends a search with nothing after it and the bar's close sends the end action,
  which also tells the engine's own bar.
- **The bar numbers matches down the scrollback, as Chrome does down a page.**
  The engine numbers them from the prompt up, so the first step shows the last
  match, `34/34`, and Next wraps to `1/34`
  (`theCountNumbersMatchesDownTheScrollbackAsNextWalksTowardsThePrompt`).
- **The bar shows the match a step left until the engine names the next**, a
  turn later, or its count blinked to `-/34` on every Return. `panes find` still
  sees the selection dropped, so it waits for the new one
  (`aStepKeepsShowingTheMatchItLeftUntilTheEngineNamesTheNext`).
- **Counts wait for the end the engine posts for each replaced search**, or the
  bar said `0/0` on every keystroke, and a count still in flight for a find text
  typed past showed as the new one's. A search is replaced only where the engine
  held one: a bar up on a non-empty find text differing in more than ASCII case
  (`countsForFindTextsTypedPastAreDroppedUntilTheLastSearchStarts`). Cost: a
  find text typed past with no matches ends the wait one 0 early.
- **The end is a 0, or no total where the find text was emptied**: that stops
  the engine's search thread rather than changing its text, and the thread posts
  no total as it quits. Waiting for a 0 there dropped every later count
  (`emptyingTheFieldShowsNoCountAndTheNextFindTextCountsAfresh`).
- **A selected match past the total shows as none selected.** A switch to the
  alternate screen posts that screen's total but no cleared match, and the bar
  read `-17/3` (`aSelectedMatchPastANewTotalIsShownAsNoneSelected`). Cost: a
  stale match inside the new total still shows until the next step.
- **Sessions warm up when visited**, a saved workspace implying dozens of shells
  at launch. Selecting a worktree opens a terminal unless told not to; a create
  is asked about separately. Cost: four settings where there were two.
- **Ghostty keybinds are unbound by name**, not cleared wholesale, which also
  removes word movement and delete-to-start.
- **Names and menu items come from one shortcuts table**; a shortcut in only one
  list was a keystroke that worked everywhere but a pane.
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
  state key as its identifier, not the thread identifier, which groups rows
  without retiring stale ones, so a terminal holds one row in Notification
  Centre saying what its dot says. Stacking four reports described one pane four
  times, three of them wrong by the time they were read.
- **A banner is taken back when what it said stops being true**: the state
  moving on, or the user reaching the pane. Waiting survives being looked at,
  its question still standing.
- **Reaching it is read once per report, and both of its flags need the app in
  front.** Flags that disagreed let a turn ending in a shown pane while the user
  was in another app raise a banner and clear the dot at once, each right by its
  own rule.
- **So returning to the app is a look**, alongside selecting, activating and
  closing the board; a shell exiting while the user is elsewhere is not.
- **Taking back removes the pending request too**: delivery lands a moment after
  the call returns, and a look landing in that gap left the banner arriving with
  nothing to retract it.
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
  tests the host against a real shell, a test's surface running `/bin/sleep`.
- **The app talks to libghostty's C API itself**, after Ghostty's own macOS app,
  built from source with our patches (develop/dependencies.md).
- **libghostty draws on its own thread**, paced to the display the window is on,
  so the view keeps no display link; a wakeup from any thread only ticks the app
  on the main one.
- **A command key goes to the menus before the terminal**, and is typed only
  when AppKit offers the same event again, which it does when no menu took it.
  The event's timestamp is the identity, events comparing no other way. A key
  libghostty binds goes to the pane first, which is why the menus' keys are
  unbound.
- **A right click goes to the program**, and nowhere else where the program does
  not take it: the app has no context menu over a pane. Right and middle clicks
  take the keyboard as a left one does, or a paste landed in one pane and the
  typing stayed in another.
- **A click on a pane in a window not in front takes the keyboard too.** AppKit
  spends that click on bringing the window forward and never delivers it, so a
  split's other pane kept the keyboard.
- **A command key's release is caught on its way through the app**, AppKit
  delivering it to no view, and sent only to the pane with the keyboard in the
  window it came from.
- **One monitor for the app catches both**, handing the release to the window's
  first responder and the click to the pane it hit. A monitor per pane ran every
  click past every pane's hit test.
- **The pointer is what libghostty asks for**, an I-beam over text and a hand
  over a link, hidden while typing where the user's config says so.
- **A program asking whether the terminal is light or dark is told the theme's
  answer**, the view's appearance following the app's theme, not the system's.
- **Secure keyboard entry is on while a pane at a password prompt has the
  keyboard**, which libghostty spots by the program turning echo off; the
  `toggle_secure_input` keybind flips it for that pane. Off altogether where the
  user's `macos-auto-secure-input` says so, as accessibility and snippet tools
  need. It is one switch for the whole Mac, so every enable is balanced and it
  is let go while another app is in front.
- **Cost: the pane shows libghostty's lock cursor at the prompt**, not whether
  macOS took the switch, and a keybind toggle shows nothing.
- **Copied files paste as quoted paths, as a drop does**, single-quoted for any
  shell and a name holding a control character left out, where the wrapper
  escaped them with backslashes.
- **Files all left out paste nothing.** Finder puts a copied file's name beside
  it as text, so falling back to the text pasted the very name left out.
- **The right-hand Option key is told apart**, so `macos-option-as-alt = left`
  leaves the right one typing accents.
- **An astral character an input method commits in two UTF-16 halves is joined
  before it is sent**, as Ghostty's app does. The lead half commits as empty
  text, and that empty commit let the key type its own character ahead of the
  pair (`aLeadSurrogateCommittedAloneSendsNothingUntilItsPairArrives`).
- **Ghostty's manual-integration lines find files that do nothing.** libghostty
  exports its resources folder to every shell, and the line Ghostty documents
  for a manual setup sources a script from it; the bundle has a stand-in in each
  place, the real scripts being GPLv3 and the marks ours.
- **A paste libghostty judges unsafe is asked about in a sheet showing the
  text**, Paste taking Return as in Ghostty's app. That is a multi-line paste
  into a program without bracketed paste, macOS's bash 3.2 or a REPL; refused
  unasked, it typed nothing and said nothing.
- **A program's clipboard read or write libghostty would ask about is still
  refused unasked**, OSC 52 and kitty's protocol alike. Cost: a program that
  reads the clipboard that way gets nothing here.
- **One paste is asked about at a time**, another meanwhile refused, and one
  still waiting when its pane closes is refused before the surface goes.
- **A read with nothing to hand back is unavailable, not refused**, answered
  before libghostty's callback returns, as Ghostty's app does. Started first and
  refused after, an empty clipboard read as a denial to a kitty-protocol
  program.
- **The runtime is built on first use**, the theme held until there is one, so a
  copy that hands over at launch never starts one.
- **Each pane's view holds the runtime**, so libghostty's app is freed after the
  last surface made in it. A view holding only the runtime's secure input let
  releasing the host free the app before its surfaces, a crash
  (`aSurfaceViewKeepsTheRuntimeItWasMadeInAlive`).
- **An item's files are pasted in the order it names them**, a name it did not
  give going last. They land in whatever order its queue runs, so an item naming
  several pasted them out of order: `PromisedDropTests`.
- **fish is told through `-C`**, a line it runs once its own config has, as bash
  is told through `--init-file`. Ghostty's route, a `vendor_conf.d` reached
  through `XDG_DATA_DIRS`, would be inherited by every child unless taken back.
- **fish 4 writes every terminal mark itself**: prompt start with
  `click_events`, input, output, the command's end with its status, OSC 7 and
  the title. So the fish file adds only the cursor's shape and the `sudo` and
  `ssh` wrappers in a Ghostty pane, and the engine's finished-command signal
  comes from fish's own end mark.
- **Cost: a fish before 4.0 writes no marks, and before 4.1 no click claim**,
  and fish titles its pane whatever the `title` feature says.
- **The fish cursor stands back under fish's vi mode**, whose own handler draws
  a shape for every mode and would be overdrawn by ours.
- **Each fish report launches the helper**, two a command, the 9.4 ms a command
  bash's relay saves. fish opens no socket and holds no descriptor a relay could
  read, and a job of ours in the background would be the one a bare `fg`
  resumed.
- **fish's own tokenizer reads the agent's word**, quotes off, past the same
  prefixes as zsh and bash (agents.md). An abbreviation is expanded before the
  event fires. Cost: an `alias` is a fish function, and the word typed is its
  name.
- **fish runs its postexec for `exit`**, so `exit 3` reports a failure, and the
  exit event then sends idle, ending the session as zsh's does.
- **Each pane's PATH starts with the helper's directory, then the app's.**
  libghostty appends its own executable's directory, `Contents/MacOS`, and on a
  case-insensitive disk `multishell` there is the app, `Multishell`, so typing
  it opened a second copy. An embedder's variables are applied after that
  append, so the host writes PATH whole. First, not last: a build started from
  another's pane, as `make run` is, inherits that one's `Contents/MacOS`, and an
  installed build from before the hand-off below opened a copy of itself and
  never answered
  (`theHelperComesAheadOfAnotherBuildsAppOnAPathInheritedFromItsPane`).
- **The integration puts the two back in front after the startup files**, from
  `MULTISHELL_LEADING_PATH`: a login shell's profile runs `path_helper`, which
  moves `/etc/paths` ahead of an inherited PATH, so `/usr/local/bin/multishell`
  answered for whichever build it was installed from. Cost: an entry the user's
  own files put first sits behind ours.
- **An agent's or editor's line opens with the same reordering**, in the login
  shell's own syntax, a bash or fish login shell running none of our files. csh
  is left out: `-i -c` reads no `.login`, where its `path_helper` runs
  (`theAgentFindsTheAppsEntriesAheadOfWhatTheLoginProfileAdded`).
- **The line runs the integration's own file, so no other shell starts for it**:
  zsh's and fish's own, and bash's for the rest, written in POSIX sh so sh, ksh
  and dash run it too. The Swift copy that builds a pane's PATH is the fourth
  (`aLoginShellsLineReadsTheLeadingPathInItsOwnSyntaxStartingNoOtherShell`).
- **The app drops the launching shell's own session state before any pane
  starts**: mise's `__MISE_*` and direnv's record of what it loaded. `open` from
  a pane passes that pane's environment on, and mise in a new pane then rebuilt
  PATH from the parent's, the helper going last again
  (`InheritedShellStateTests`). Their settings stay.
- **The app's executable hands any argument but AppKit's to its helper**, by
  `execv`, for a shell whose own files rebuild PATH and for `Multishell help`
  typed against the bundle. AppKit's are a single dash and a name, as `-psn_`
  and `-AppleLanguages` are, `-h` excepted (`HelperHandOffTests`).
- **A link clicked in a pane opens only for the web, mail, a text file in the
  editor, or a folder, image, PDF, audio, video, archive or Office file in its
  default app**, judged by what its path resolves to, refused with a beep
  otherwise. Left to libghostty, `open` ran whatever target a program printed,
  `file:///System/Applications/Calculator.app` among them, and from `ad97d33` it
  opens no link from a pane's text at all (`GhosttyLinkRuleTests`).
- **It is judged through `runOnDispatch` and acted on after the click**: its
  stats can hang on a share that stopped answering, and libghostty reports the
  click holding the pane's renderer lock, which a tab opened or focus moved
  takes again. One answered after a later click, or after its pane closed, opens
  nothing, so a slow one neither holds back nor overtakes the next. A link
  clicked again while still judged is not judged again, each try parking a
  thread, and its answer goes to the latest click. Cost: a click on such a share
  does nothing, not even beep.
- **An OSC 8 hyperlink opens only a file on this Mac**, judged as any other, and
  beeps for a web or mail target. Its target is not the text the pane shows, and
  nothing here shows it before the click, as Ghostty's app does in a banner on
  hover; a local file cannot be someone else's site. Agents, `ls --hyperlink`
  and gcc print their paths this way.
- **A `file:` URL opens only for this Mac**: no host, `localhost` or the Mac's
  own name, which `ls --hyperlink` and `rg` write. A relative one names no file.
- **What a default app may open is a list of kinds, not a list of refusals**:
  the refusals missed a Finder alias and a `.fileloc`, whose target Launch
  Services opens, Calculator for one pointing at it, a `.shortcut` Shortcuts
  imports, a `.dmg` it mounts and a `.prefPane` System Settings installs. A
  bundle is not a folder here. Archives and Office files open, but not a kind
  macOS counts as runnable, a `.jar` or a macro-enabled `.docm`. Cost: those, an
  `.xcodeproj` and an unnamed kind beep.
- **A relative path is looked for in the pane's directory, then under the
  repository root**, the nearest folder up holding `.git`, and there without a
  leading `a/` or `b/`, the sides `git diff` names files by. libghostty joins a
  relative path to the shell's reported directory only where the file is there.
  A shell that reports none, sh or nu, leaves where the pane started. One the
  pane's directory holds wins, a folder named `a` included.
- **A compiler's `Sources/A.swift:12:5` opens the file**, a `file:` URL's too,
  when no file has that name, libghostty's pattern taking `:` as part of a path.
  The line is not passed on, and neither is what follows it, `rg`'s
  `src/main.rs:12:fn`. A bare `A.swift:12:5` is no link, libghostty's pattern
  wanting a `/`.
- **`$HOME/…` and `$PWD/…` expand**, libghostty marking any `$VAR/` path; the
  app knows only these two as the pane's shell has them.
- **A file is text if its type says so or its first 8 KB are UTF-8 with no zero
  byte**: macOS has no text type for a `.rs`, a `.go` or a `Dockerfile`, and
  calls a `.ts` an MPEG-2 video. So a location file written as XML opens as
  text, in the editor, never through Launch Services.
- **A text file opens in the editor Open in Editor uses**, whatever its mode: an
  application is handed the file, a terminal editor opens it in a tab in the
  pane's worktree, and a custom command reads `{path}` from
  `MULTISHELL_FILE_PATH`, the worktree's variable naming a directory. With no
  editor chosen, the app plain text opens in, as it does in a worktree being
  created or removed, which takes no new tab or shell. An application editor
  still takes the file there, unless it is reached through its command-line
  shim, which runs in a shell. Never the file's own type's handler, which can
  run it, Python Launcher for a `.py`; refused outright, every `.py`, `.js` or
  `.sh` a developer clicked beeped. Ghostty's app refuses them. Cost: a custom
  command is trusted as an editor, so `open {path}` hands a script on to
  whatever runs it.
- **The editor is handed the name the pane printed**, which keeps it inside a
  workspace opened through a symlink; a default app gets the resolved target,
  since Launch Services could judge a symlink by its own name. A path with `..`
  goes resolved to both: after a symlink it names another file than on disk.
- **The setting, not `$EDITOR`**: one choice of editor across the app, and
  `$EDITOR` is often a waiting line such as `code -w`, which would hold a tab
  open until the file closed.
- **Cost: another app's scheme, `vscode://` or `slack://`, opens nothing.**
  Ghostty's app asks before handing a scheme on.
