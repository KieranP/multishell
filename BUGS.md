# Bugs

Open findings from a whole-repo review on 2026-09-12, against commit 9209231.

Every Critical and High has been fixed and its entry taken out, so what is
left here is Medium and Low. Numbers are never reused: the ones that remain
keep what they were given, which is why they have gaps, and a number in a
message always means the same bug.

A finding says where it is, what goes wrong, and how far it was verified.
Confirmed means traced end to end or reproduced; plausible names the gap that
is left. Entries already in `docs/develop/known-gaps.md` are not repeated
here.

Each label is what the bug does to the user when it fires, not how often it
fires.

- Medium: wrong behaviour the user meets and has to work around.
- Low: churn, cost, or a wrong detail that costs nothing to live with.

Worst first, then by number:

| # | Effect | What |
| --- | --- | --- |
| 5 | Medium | The icon picker searches in the reader's locale |
| 6 | Medium | Tab dedup runs before the dangling prune, and can keep the dead copy |
| 8 | Medium | The sidebar filter folds case in the reader's locale |
| 10 | Medium | Done is reported while background subagents are still running |
| 14 | Medium | Open in Editor acts while the Agents board is up, and skips the busy check |
| 15 | Medium | Launch-time detection blocks the main actor on every PATH entry |
| 18 | Medium | An unknown Claude notification type is dropped, and two docs disagree about that |
| 21 | Medium | An abandoned project drag makes the next text drop move that project |
| 23 | Medium | Escape on a tab's name field can still commit the abandoned draft |
| 26 | Medium | The promise reader's queue is a local that goes out of scope |
| 29 | Medium | A non-transient accept failure spins the socket queue |
| 2 | Low | The same locale gives bash a wrong duration |
| 3 | Low | CI never builds the app bundle |
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

## Build and CI

### 3. Low. CI never builds the app bundle

`.github/workflows/ci.yml`. All three jobs run `swift build` and `swift test`;
none runs `Scripts/make-app.sh`, so bundling, the generated Info.plist and
signing can all break with CI green. The Makefile's opening comment says "CI
and the Makefile cannot drift", which holds for the test half and not for
this one.

Confirmed by reading both files.

## MultishellCore

### 5. Medium. The icon picker searches in the reader's locale

`Sources/MultishellCore/Model/ProjectIcon.swift:67`. `localizedStandardContains`
folds case with `Locale.current`, but the words it matches are English
constants and the SF Symbol names are ASCII. Under `tr_TR` the dotted and
dotless I stop folding together, so typing `DISK` matches nothing and the
palette comes back empty. `Locale.current` follows the system, not the app's
`en.lproj`, so shipping English only does not protect it. The old
`lowercased().contains` was locale-independent.

Confirmed by the first review against `tr_TR`. Distinct from the known gap
about `searchWords` being English, which is about translated words rather
than ASCII folding. Fix = fold with `lowercased()`, or pass
`Locale(identifier: "en_US_POSIX")`.

### 6. Medium. Tab dedup runs before the dangling prune, and can keep the dead copy

`Sources/MultishellCore/Model/Workspace+Repair.swift:15`. `tabs.uniqued(by: \.id)`
is first-entry-wins and runs before the `worktreeIDs` prune on line 19. A file
holding tab id `X` twice, the first naming a worktree that is gone and the
second a live one, keeps the dead copy; the prune then deletes it, and the
valid tab goes with it, its sessions losing their owner at line 45. The old
order kept the live copy.

Confirmed. Narrow: duplicate ids come from a hand-edited file, which is the
case the comment cites. Fix = move the dedup below the prune.

### 7. Low. A comment documents a hazard that does not exist

`Sources/MultishellCore/Model/Workspace.swift:176` and
`Sources/MultishellAppCore/Model/AppModel+TabGroups.swift:35`. Both say the
`count - 1` step keeps the sum positive for Swift's `%`. Neither call site can
go negative: `neighbour` is reached only with ±1 and guards `siblings.count > 1`,
and `focusGroup` guards `columns.count > 1` the same way. The rewrite preserved
behaviour and the comment now misleads, which costs more here than elsewhere
because comments are the reasoning of record.

Confirmed; no other modulo-wrapping site remains.

### 18. Medium. An unknown Claude notification type is dropped, and two docs disagree about that

`Sources/MultishellCore/Agents/AgentHookIntegration.swift:65`. The check is an
allow list of the five names in `AgentHooks.claudeQuestions`, so a
`notification_type` the build has not heard of returns nil, the helper writes
nothing to the socket, and the pane's dot stays green while the agent sits at a
prompt.

`docs/design/agents.md:65` ends that bullet with "A type we have not heard of is
taken to ask", which the code contradicts. The sentence before it covers the
no-type case, which the `let type =` binding already handles separately, so the
last sentence is about an unrecognised type. It also runs against the pattern
beside it: `AgentHookPayload.promptsForPermission` takes an unknown mode as
prompting, and merged-branch.md chose a deny list for the same reason.

`docs/develop/known-gaps.md` records the opposite as settled, saying a type
Claude adds later falls out of the list and naming the flip as the fix if it
bites. So the two docs disagree and the code follows known-gaps. Decide which
doc is right before changing code.

Confirmed as a divergence; I read agents.md:65. The doc line landed in
`fc89bd8`, the same commit as the code.
`claudeOnlyWaitsOnANotificationThatAsksSomething` pins the nine known types and
the nil type, never an unknown one. Related to 10.

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

### 8. Medium. The sidebar filter folds case in the reader's locale

`Sources/MultishellAppCore/SidebarFilter.swift:31`. Same cause as 5, reached
from user data instead of English constants: under `tr_TR` an uppercase `I`
stops matching a branch holding a lowercase `i`, so `kieran/rate-limits` drops
out of the list for a filter of `I`.

Confirmed. Lower than 5 because branch names vary. Same fix.

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

### 14. Medium. Open in Editor acts while the Agents board is up, and skips the busy check

`Sources/MultishellAppCore/Model/AppModel+Editor.swift:58`. The `.openTab`
branch calls `store.openTab` and `store.selectWorktree` directly rather than
going through `select(_:)`, so `leaveAgentBoard()` never runs and `isBusy` is
never checked. agents.md says nothing acting on the tab in front of the user
acts at all while the board is up.

With a terminal editor set and the board showing, Cmd+Shift+O starts a live
shell running the editor in a pane the board covers, and Cmd+W will not close
it because `closeInShownTab` returns early on a nil `worktreeInView`. Separately,
the missing `isBusy` check starts a shell in a directory whose pre-delete hook
is already running, which `requestRemoval`, `newTab` and `splitActivePane` all
refuse.

Confirmed. Related to the known gap about Open in Editor and New Worktree
acting on the selected worktree while the board is up, but that gap says
neither is destructive; this adds that one of them opens a shell where a
removal is in flight.

### 15. Medium. Launch-time detection blocks the main actor on every PATH entry

`Sources/MultishellAppCore/Model/AppModel+Agents.swift:17`.
`refreshLoginEnvironment` awaits the environment capture off-main, then builds
`AgentDetection`, `ShellDetection` and `EditorDetection` synchronously on the
main actor. Each `ExecutableLookup.find` stats every PATH directory,
`ShellDetection` reads and stats every line of `/etc/shells`, `EditorDetection`
runs a LaunchServices lookup per editor, and `refreshAgentStatus` parses five
settings files. None goes through `Self.offMain`.

A stale network mount on PATH makes each stat block for the mount's timeout
with the main actor held, which is the hazard `offMain`'s own comment
describes; it is used on the polling paths and not here.

Plausible: read from the code, no stall measured.

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

### 29. Medium. A non-transient accept failure spins the socket queue

`Sources/MultishellProcess/UnixSocketServer.swift:87`. `guard client >= 0 else
{ return }` returns on every error alike. On `EMFILE` or `ENFILE` the pending
connection stays in the listen backlog, and the read source on a listening
socket is level-triggered, so the handler fires again at once: a tight
accept-and-fail loop holding a core until a descriptor frees, which is when the
app can least afford it.

Plausible on the spin rate rather than confirmed, since `DescriptorLimit.raise()`
lifts the soft limit to `OPEN_MAX` and reaching `EMFILE` needs a real leak or
`ENFILE`. The unguarded path is the confirmed part. Fix = treat
`EAGAIN`/`EWOULDBLOCK` as done and back off on `EMFILE`/`ENFILE`.

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

### 21. Medium. An abandoned project drag makes the next text drop move that project

`Apps/macOS/Sources/Multishell/Sidebar/SidebarView.swift:226` with
`Sidebar/ProjectDropDelegate.swift:35`. `.onDrag` sets `draggingProject` and
nothing clears it on cancellation: `endDrag()` runs only from `performDrop` and
from the catch-all `.onDrop(of: [.text])` on the ScrollView, which covers the
scroll area alone. SwiftUI gives `.onDrag` no cancellation callback.

Drag project A's row and release it over the terminal area, the sidebar header
or another app, so `draggingProject` stays A. Later drag a text selection out of
Safari onto project B's row. `validateDrop` accepts anything conforming to
`.text` and `performDrop` never inspects the item, so `moveProject(A, .above, B)`
runs and A silently changes position, with a save scheduled. Before the drop the
blue insertion capsule also draws, because line 379 tests `draggingProject != nil`
rather than the item's contents, so the sidebar advertises the wrong move during
any text drag.

Confirmed for the code path. Gap: whether AppKit delivers `performDrop` for
every external text flavour, though `public.utf8-plain-text` conforms to
`public.text` so the type check passes.

### 23. Medium. Escape on a tab's name field can still commit the abandoned draft

`Apps/macOS/Sources/Multishell/Terminals/TabButton.swift:197` with
`Support/InlineNameField.swift:30`. The field commits on blur, and Escape sets
`editingTabID = nil`, which removes the field and drops its focus.
`TabButton`'s commit closure calls `model.renameTab` with no check that the edit
is still current. The worktree path guards exactly this:
`AppModel.commitRename` starts with `guard renamingWorktreeID == id`.

Double-click a tab, type `scratch`, press Escape, and the tab is renamed and the
persisted `customTitle` written. The same ordering makes commit's second half
wipe a rename just started on another tab: double-click A, type, double-click B,
and B's field opens and closes immediately because A's blur-commit reset
`editingTabID`.

Plausible; the gap is whether SwiftUI delivers the focus change to a view being
removed in the same update. The asymmetry with `commitRename` is the argument
that it does.

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

### 26. Medium. The promise reader's queue is a local that goes out of scope

`Apps/macOS/Sources/Multishell/Terminals/PromisedDrop.swift:38`. The
`OperationQueue` passed to `receivePromisedFiles` is a local released when
`receive` returns. The call is not documented to retain it, and Apple's sample
keeps it as a stored property.

Drag a screenshot preview onto a pane. If the queue is released before the
source writes the file, the reader never runs, the `Collector` waits out its
120-second patience and delivers nothing, so the file is never pasted and the
drop directory is swept a week later.

Plausible, and untestable here by the suite's own admission
(`PromisedDropTests.swift:16`, the drag cannot be staged). One stored property
removes the question.

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
