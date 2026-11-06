# Shell integration

What a shell reports, through the integration injected into zsh, bash and fish.
Newest at the bottom.

- **Shell integration is injected, never written to a user's file.** It is
  written at launch into the app's own directory, and every session pointed at
  it.
- **The helper sits behind a symlink refreshed at the same time**, so a moved
  bundle breaks no hook line. An agent's hooks are the one exception, written
  only on the user's click: merged into a settings file of theirs with a copy
  kept, or a file of ours written whole (agents/reports-and-hooks.md).
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
  marks an agent typed at a prompt with no hooks installed
  (agents/board-and-pane-rows.md).
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
- **Ghostty's manual-integration lines find files that do nothing.** libghostty
  exports its resources folder to every shell, and the line Ghostty documents
  for a manual setup sources a script from it; the bundle has a stand-in in each
  place, the real scripts being GPLv3 and the marks ours.
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
  prefixes as zsh and bash (agents/board-and-pane-rows.md). An abbreviation is
  expanded before the event fires. Cost: an `alias` is a fish function, and the
  word typed is its name.
- **fish runs its postexec for `exit`**, so `exit 3` reports a failure, and the
  exit event then sends idle, ending the session as zsh's does.
