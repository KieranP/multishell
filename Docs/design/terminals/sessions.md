# Session state, launch and environment

What a shell is launched as, and what its state means. Newest at the bottom.

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
  is working asks first (agents/background-work.md).
- **The shell's own end-of-command outranks a report.** It settles background
  workers, the owed Done and which agent is at the prompt, whatever was in the
  foreground having returned (agents/background-work.md,
  agents/board-and-pane-rows.md).
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
- **It resumes by the conversation its agent last reported**, where the agent
  takes an id: each one's own flag reopens the latest conversation in the
  directory, so two tabs of one agent in a worktree both came back as the later
  one, two processes writing one transcript. Hooks send the agent's session id;
  only the tab's own agent's is kept, and one that could read as a flag is not.
- **Taken from the first prompt on, never a start, an ending or a subagent's**:
  a conversation started but never prompted may be written nowhere, and resuming
  it fails where the latest flag reopened something; an ending can land after
  the next start on /clear or /resume. Copilot's child events name the child
  with no transcript to tell it by, so its id is kept only where it is the
  conversation the pane's state took as its own.
- **Cost: OpenCode and Antigravity still resume the latest**, reporting no id
  through a hook. A tab moved to another worktree keeps its id, which an agent
  that files conversations by directory may not find there; it no longer reopens
  another tab's.
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
- **Sessions warm up when visited**, a saved workspace implying dozens of shells
  at launch. Selecting a worktree opens a terminal unless told not to; a create
  is asked about separately. Cost: four settings where there were two.
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
- **Launch takes back every banner the last run left**: they describe agents its
  quit ended, and the keys a withdrawal goes by were that run's alone. Only once
  the socket is this copy's, or a copy handing over took the running one's.
- **Taking back removes the pending request too**: delivery lands a moment after
  the call returns, and a look landing in that gap left the banner arriving with
  nothing to retract it.
- **Only Done clears on the look.** Failed keeps its dot, so the banner and the
  dot say different things about one pane on purpose: the interruption spent,
  the thing to deal with still there.
- **The model keeps the keys it has posted about**, so nothing is taken back
  that was never there. Cost: a Done nobody looked at disappears when the next
  state lands, the dot being what persists.
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
  starts**: mise's `__MISE_*`, direnv's record of what it loaded, and the
  session variables a Multishell pane gave it. `open` from a pane passes that
  pane's environment on, and mise in a new pane then rebuilt PATH from the
  parent's, the helper going last again (`InheritedShellStateTests`); kept, the
  pane's variables sent hooks' reports to that pane and named another app's
  worktree. Their settings stay.
- **The app's executable hands any argument but AppKit's to its helper**, by
  `execv`, for a shell whose own files rebuild PATH and for `Multishell help`
  typed against the bundle. AppKit's are a single dash and a name, as `-psn_`
  and `-AppleLanguages` are, `-h` excepted (`HelperHandOffTests`).
