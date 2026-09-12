# Bugs

Open findings from a whole-repo review on 2026-09-12, against commit 9209231.

Every Critical and High is fixed, and every Medium but one; their entries are
taken out. 10 is the exception and is not a defect to patch: reporting Done
only once a turn's background subagents have ended needs `SubagentStart` and
`SubagentStop` written into the user's settings file and a count carried over
the socket, which is a change to the protocol and to what Add installs.

Numbers are never reused: the ones that remain keep what they were given,
which is why they have gaps, and a number in a message always means the same
bug.

A finding says where it is, what goes wrong, and how far it was verified.
Confirmed means traced end to end or reproduced; plausible names the gap that
is left. Entries already in `docs/develop/known-gaps.md` are not repeated
here.

Each label is what the bug does to the user when it fires, not how often it
fires. Medium: wrong behaviour the user meets and has to work around. Low:
churn, cost, or a wrong detail that costs nothing to live with.

| # | Effect | What |
| --- | --- | --- |
| 10 | Medium | Done is reported while background subagents are still running |
| 2 | Low | The same locale gives bash a wrong duration |
| 7 | Low | A comment documents a hazard that does not exist |
| 9 | Low | Recording engine ownership before the open trades one leak for its mirror |
| 16 | Low | Every agent report redraws the sidebar and the board |
| 19 | Low | Remove rewrites an agent settings file even when it removed nothing |
| 24 | Low | Every font family is enumerated on each settings tab switch |
| 25 | Low | The resize cursor is pushed with no matching pop |
| 33 | Low | A worktree path containing a newline is mis-parsed |

## Shell integration

### 2. Low. The same locale gives bash a wrong duration

`Sources/MultishellCore/Resources/init.bash:41`. `${now%.*}` strips a
fractional part written with a dot and not one written with a comma, so the
subtraction runs on the whole string and yields a wrong duration. It stays
valid, being an argv to the helper rather than JSON, so the report survives
with a bad number.

Plausible: reachable only on bash 5, which has `EPOCHREALTIME`, and this
machine carries Apple's 3.2 only, so it is read rather than reproduced.

## MultishellCore

### 7. Low. A comment documents a hazard that does not exist

`Sources/MultishellCore/Model/Workspace.swift:176` and
`Sources/MultishellAppCore/Model/AppModel+TabGroups.swift:35`. Both say the
`count - 1` step keeps the sum positive for Swift's `%`. Neither call site can
go negative: `neighbour` is reached only with ±1 and guards `siblings.count > 1`,
and `focusGroup` guards `columns.count > 1` the same way. The rewrite preserved
behaviour and the comment now misleads, which costs more here than elsewhere
because comments are the reasoning of record.

Confirmed; no other modulo-wrapping site remains.

### 19. Low. Remove rewrites an agent settings file even when it removed nothing

`Sources/MultishellCore/Agents/AgentHookIntegration+Install.swift:137`. For a
shared-settings agent, `remove(from:)` always calls `HookSettingsFile.write`
with no check that `removing(from:)` changed anything.

A user with a hand-written `~/.gemini/settings.json` who has never installed the
hooks, or who clicks Remove twice, gets a `settings.json.before-multishell`
copy they never asked for and their file rewritten with sorted keys and
two-space indentation. No content is lost, since a file with comments is
refused upstream, but the file is churned for an operation that did nothing.

Confirmed.

## MultishellAppCore

### 9. Low. Recording engine ownership before the open trades one leak for its mirror

`Sources/MultishellAppCore/Terminals/MultiEngineHost.swift:35`. `SessionRegistry.reconcile`
retries a session whose open threw, since it never reached `openSessionIDs`. If
the engine changes between the failure and the retry, `owner[id]` is overwritten
and a surface the first engine registered before throwing can never be closed,
which is the defect the change was meant to close. The failed entry is never
cleared either, only `close` removes one.

Confirmed in the code, unreachable in shipping builds: `GhosttyTerminalHost.open`
and `SwiftTermTerminalHost.open` are declared `throws` and contain no `throw`,
so only `RecordingEngine.failNextOpen` exercises it. Which leak to prefer is a
judgement call, not an obvious fix. A second reviewer read the same line
and called the current order correct, so settle which leak is wanted before
touching it.

### 16. Low. Every agent report redraws the sidebar and the board

`Sources/MultishellAppCore/Model/AppModel+SessionState.swift:32`.
`reportedAgents[id]` is assigned unconditionally, and the Observation macro
fires on every set regardless of equality. Claude Code sends `PreToolUse` and
`PostToolUse` per tool call, so a fifty-call turn writes the same
`ReportedAgent` a hundred times and invalidates the sidebar's Agents row and
every board card each time. The sibling code at `AppModel.swift:223` guards
against exactly this, and so do `noteTitle`, `note(_:asMergeBaseOf:)` and
`refreshStatuses`.

Confirmed.

## MultishellGitKit, Process and CLI

### 33. Low. A worktree path containing a newline is mis-parsed

`Sources/MultishellGitKit/WorktreeService.swift:34` and `:55`. git marks the
non-`-z` porcelain format unsafe for paths with newlines. A directory named
`my\nrepo` produces `worktree /Users/dev/my` then `repo`;
`WorktreeListParser.split` turns the second into a key with an empty value and
`flush()` emits a worktree whose path is `/Users/dev/my`, which does not exist.
Its status read fails so the row shows no status, and since the path is the
worktree's identity, selection and the tab store key off a path git never
reported.

`--porcelain -z` with a NUL record split fixes it, and the parser's structure
survives the change.

## macOS app

### 24. Low. Every font family is enumerated on each settings tab switch

`Apps/macOS/Sources/Multishell/Sheets/AppSettings/AppearanceSettingsTab.swift:10`.
`@State private var fonts = InstalledFonts.detect()` is an ordinary initializer
expression, evaluated whenever the View value is constructed; SwiftUI keeps the
first box and discards the rest. The tab is constructed inside `SettingsView.body`,
which re-runs on every tab switch, and `detect` walks
`availableFontFamilies`, calling `availableMembers` and instantiating an
`NSFont` per family.

Clicking between the five settings tabs enumerates and instantiates several
hundred fonts synchronously on the main thread each time, for a result thrown
away. `.task` or a lazy store gives the same picker for one pass.

Confirmed.

### 25. Low. The resize cursor is pushed with no matching pop

`Apps/macOS/Sources/Multishell/Terminals/WeightedSplit.swift:128` and
`App/RootView.swift:44`. `NSCursor.push()` in `onHover` has no `pop()` for a
view removed under the pointer, and `onHover(false)` cannot fire for a view that
is gone. Hover a divider so the resize cursor is pushed, then Cmd+W a pane: the
handle disappears and the cursor stack keeps the resize cursor on top.

Confirmed in the code; the visible effect is plausible, since AppKit resets from
cursor rects on the next mouse-move and how long the wrong cursor shows depends
on what the pointer crosses.

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
