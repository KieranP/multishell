# Bugs

Open findings from a whole-repo review on 2026-09-12, against commit 9209231.

One is left. It is not a defect to patch: reporting Done only once a turn's
background subagents have ended needs `SubagentStart` and `SubagentStop`
written into the user's settings file and a count carried over the socket,
which is a change to the protocol and to what Add installs.

Numbers are never reused, which is why the one that remains is 10.

| # | Effect | What |
| --- | --- | --- |
| 10 | Medium | Done is reported while background subagents are still running |

## Agents

### 10. Medium. Done is reported while background subagents are still running

`Sources/MultishellCore/Agents/AgentHooks.swift:70`, `AgentHookEvent("Stop", .done)`.
Claude Code fires `Stop` when its main assistant loop stops, which happens
while subagents launched in the background are still working; their own end is
a separate `SubagentStop` event, and the list does not carry it. So the pane
goes to Done and the banner fires at the wrong moment, then the session goes
back to running when a subagent reports, so the user is told it finished once
per subagent wave.

`.done` is in `isFinished` (`SessionState.swift:49`) and a hook sends no
duration, so `NotificationPolicy.swift:19` cannot suppress it on the
short-command rule: the banner always posts.

Confirmed by reading, and seen: it fired during this review while four
subagents were still running. Fix = take `Stop` as done only when no subagent
is outstanding, which needs `SubagentStop` in the list to count them, or drop
`Stop` to a quieter state and let idle settle it.

Unchecked: Codex (line 89) and Gemini (line 131) carry the same
`AgentHookEvent("Stop", .done)`, but whether either has work that outlives its
stop event has not been looked at.

## Checked and clear

Not bugs, recorded so nobody spends the time again.

- zsh preserves `$?` across `precmd` hooks, so `_multishell_precmd` running
  after `_multishell_prompt_click` still sees the user's command's status and
  reports `error` correctly. Reproduced under a pty with two hooks: the
  second saw 42.
- `make lint` passes with no findings.
- Process handling holds up: both pipes are drained concurrently so a large
  output cannot deadlock, the failed-launch path balances its descriptors, and
  Darwin spawns with `POSIX_SPAWN_CLOEXEC_DEFAULT`, so a hook or a git child
  does not inherit the listening socket. Tested directly: a child writing to
  fd 3 got `Bad file descriptor`. An `FD_CLOEXEC` on `newSocket` would still be
  wanted for Linux, which has never compiled.
- Nothing a branch name or path holds is interpolated into a command line.
  `ShellCommand` passes the script as one argv element and hook context goes
  through the environment. `worktree add` and `branch -d` take absolute paths
  and `-b` consumes its value, and git refuses refnames with spaces, newlines,
  control characters and a leading dash, so the missing `--` on those two is
  not reachable.
- No parsed git output is translated, so `LC_ALL` would add nothing: the
  `%(upstream:track)` messages are the untranslated plumbing forms, porcelain
  v1 forces fixed strings, and `cherry` and `worktree list --porcelain` are
  plumbing.
- `FileDigest` matches FIPS 180-4 and is locale-independent. Every custom
  `init(from:)` was read against its synthesized `encode(to:)`. The package's
  three force unwraps are each guarded by a preceding removal or count check.
- No user-visible literal sits outside `t(...)` in the Mac target, there are no
  force unwraps in it, and the observers and monitors that could retain are all
  weak.
- The comment trimming in 9209231 removed no code: every hunk carrying a
  non-comment change is one of 5 to 9, and no blank-line-only change fell
  inside a multi-line string literal.
