# Bugs

Open findings, numbered from the whole-repo review of 2026-09-13; numbers are
never reused and a fixed entry is taken out rather than kept. 85, 86 and 87
are from that review. 88 onward are from the whole-repo review of 2026-09-16:
one reader per layer over every file in full, then a second reader over each
High and Medium and over the Low entries marked "checked". 88, 89 and 97 were
reproduced by running something; the rest were read, not run. "Unproven" is
behaviour nobody has shown, kept because the fix is cheap or the cost is high.

| # | Effect | What |
| --- | --- | --- |
| 88 | High | The build-path check in `make-app.sh` never fires: `grep -q` under `pipefail` turns a match into a false branch |
| 89 | Medium | Under bash, Enter on an empty prompt marks the pane Working when the user has a `PROMPT_COMMAND` |
| 90 | Medium | A pane whose agent died with a background worker out stays Working, and later commands in that shell can too |
| 91 | Low | The Dock badge counts a dead agent's shell failure as an agent waiting until the board is opened |
| 92 | Low | A stage's hook keeps running with no Cancel once its worktree is removed outside the app |
| 93 | Low | A project removed while its refresh is failing raises an alert about it and stays in `missingProjects` |
| 94 | Low | `git worktree add` runs with no timeout and no stopper while the sheet's Cancel is greyed out |
| 95 | Low | A `forget` that fails after the trash step is read as "nothing moved" |
| 96 | Low | A shell greeting holding `=`, or one with no final newline, loses the first environment variable |
| 97 | Low | Installing or removing an agent's hooks rewrites every float in the user's settings file |
| 98 | Low | A cancelled sidebar-divider drag makes the next drag jump to a stale width |
| 99 | Low | A banner still pending when it is withdrawn is never taken back |
| 100 | Low | A generated Ghostty config file is left in the temp directory on every launch |
| 101 | Low | Test harnesses make a temp directory per test and never remove it |
| 102 | Low | `LOCK` in the Makefile is unquoted, so a home directory with a space breaks `make test` |
| 103 | Low | `setSplitWeights` writes weights unchecked where `setGroupWeights` refuses them, and `PaneNode` lets a zero through |
| 104 | Low | A `.multishell.json` that will not parse is explained on screen in English written outside the catalogue |
| 105 | Low | Help text for the project icon picker describes a search field that no longer exists |
| 106 | Low | The sidebar's rename field is invisible to assistive technology |
| 107 | Low | A settings view reaches the Platform port directly instead of through the model |
| 108 | Low | `didExit` reports code 0 for every close and nothing reads it |
| 109 | Low | Nine comments run over the two-line limit, and one doc comment is orphaned |
| 110 | Low | The socket server's comment names `flock` for a lock taken with `fcntl` |
| 111 | Low | Three public entry points have no caller outside the tests |
| 112 | Low | Six tests read the developer's own machine |
| 113 | Low | Test helpers duplicated across suites that layout.md puts in TestScratch |
| 114 | Low | Three tests wait on a fixed sleep where the suite elsewhere polls the state |
| 115 | Low | `ChangeCounter` saturates at one, so it cannot tell one change from many |
| 116 | Low | HelperTests finds the helper at a hard-coded `.build/debug/multishell` |
| 117 | Low | Three `// MARK: -` banners in test files |
| 118 | Low | `make-app.sh` prints every warning line, not "one each" as build.md says |
| 119 | Low | `.gitignore` names a `Vendor/libghostty/build/` tree that does not exist |
| 86 | Low | An OpenCode server reused by a second pane lands the dot on the first pane's tab |
| 87 | Low | CI never runs `make-app.sh`, so bundling and signing can break with it green |
| 120 | Unproven | The helper binary is built with `swift build` and never checked for the build path the app binary is refused over |
| 121 | Unproven | The sheet's step may be left set after a create ends, silencing the shared-hooks question |
| 122 | Unproven | A starvation test's bound grows with core count while the spawn rate does not |
| 85 | Unproven | Three of the four agents' hook files have never been watched moving a dot |

## Scripts and build

### 88. High. The build-path check in `make-app.sh` never fires

`Scripts/make-app.sh:74`; same shape at `:80`.
Under `set -euo pipefail` (line 6):
`if strings "$app/Contents/MacOS/Multishell" | grep -q '\.build/.*\.bundle$'; then ... exit 1`.
`grep -q` exits at its first match, `strings` keeps writing, gets EPIPE and
dies with SIGPIPE, and `pipefail` makes the pipeline's status 141, so the `if`
goes false and the error never prints. A binary that does carry the `.build`
path, the exact case build.md says the script "refuses", passes silently and
the installed app loses its terminfo at the next build. `strings` on the
current binary emits 1.3 MB, twenty times the pipe buffer, so the check can
only fire when the match is in the last 64 KB. Reproduced:
`bash -c 'set -euo pipefail; if strings /bin/bash | grep -q e; then echo fired; else echo "skipped $?"; fi'`
prints `skipped 141`. Line 80 (`otool -l | grep -q __llvm_prf`) has the same
shape; otool's output is 21.6 KB here, so it holds until the binary grows.
Fix: read the producer to EOF, by capturing to a variable or file, or with
`grep -c ... >/dev/null`.

### 102. Low. `LOCK` in the Makefile is unquoted

`Makefile:14-15`, `:30-33`.
`LOCK := $(shell ... echo lockf -k $(TEST_LOCK_FILE))` then
`$(LOCK) swift test --skip-build`. With `HOME=/Users/Jane Doe`, lockf takes
`/Users/Jane` as the lock file and `Doe/Library/...` as the command. build.md
promises every target works from any path.

### 118. Low. `make-app.sh` prints every warning line, not one each

`Scripts/make-app.sh:62`; docs/develop/build.md.
`grep -E ': (warning|error): ' ... || true` has no dedupe, and xcodebuild
repeats a warning per compile step and again in its summary.

### 119. Low. `.gitignore` names a tree that does not exist

`.gitignore:8` ignores `Vendor/libghostty/build/`. There is no `Vendor`
directory; dependencies.md says libghostty comes from libghostty-spm.

### 87. Low. CI never runs `make-app.sh`, so bundling and signing can break with it green

`.github/workflows/ci.yml:12`.
CI runs `swift build` and `swift test` for both packages and nothing else,
while `make build` goes on to `Scripts/make-app.sh` (Makefile:26), which
writes the generated Info.plist (make-app.sh:98) and signs the bundle
(make-app.sh:172). A change that breaks any of those passes CI, and nothing
notices until someone runs `make build`. The Makefile's own header at line 2
says the two are meant not to drift.

### 120. Unproven. The helper binary is never checked for the build path

`Scripts/make-app.sh:65-70` and `:74`; `Sources/MultishellCore/Store/PackageBundle.swift:6-8`;
`Sources/MultishellCore/Agents/AgentHooks.swift:94-95`.
The helper is built with `swift build` (line 65) and the line 74 check runs
on the app binary only. The helper touches MultishellCore's resources on every
`agent-hook`: `AgentHooks.integration(for:)` forces `integrations`, whose
`codex` entry calls `t("agent-hooks.codex-trust")`, whose `Bundle.catalogue`
passes `.module` to `PackageBundle.holding`. Under a `swift build` that bakes
the `.build` path, which build.md says Xcode 26's does, `make clean` after
`make install` would trap every Claude hook in the helper and the dots would
stop silently. Not reproducible on this machine: its toolchain generates the
Xcode-style accessor, `strings` on the bundled helper finds no `/.build/`,
and the bundled helper's `install-agent-hooks --print` and `agent-hook` both
exit 0. Cheap to close: run the line 74 check on `Contents/Helpers/multishell`
too, or raise the Xcode floor to 27.

## Shell integration

### 89. Medium. Under bash, Enter on an empty prompt marks the pane Working when the user has a `PROMPT_COMMAND`

`Sources/MultishellCore/Resources/init.bash:85` (`_multishell_arm`), `:63-66`
(the armed check in `_multishell_debug`), `:68` (`_multishell_precmd` never
disarms).
`_multishell_arm` runs last in `PROMPT_COMMAND` and sets `_multishell_armed=1`;
the next DEBUG trap for a command not named `_multishell_*` consumes it and
sends `command-started`. On an empty Enter no command runs, so the arm
survives into the next `PROMPT_COMMAND`, where the user's own entry
(`history -a`, bash-preexec, starship, direnv, an editor's integration) fires
DEBUG first and is reported as a started command. The dot and the board card
read Working until the next Enter, whose precmd reports it finished with the
whole idle time as duration. Ctrl+C at an empty prompt takes the same path.
zsh is immune, having no preexec for an empty line.
Reproduced under `/bin/bash --init-file init.bash -i` with a logging
stand-in helper: a `.bashrc` with `PROMPT_COMMAND='history -a'` and input
`\n\ntrue\n\nexit\n` logged seven lines (started, finished, started, started,
finished, started, started); with no `PROMPT_COMMAND` the same input logged
the expected three. Adding `_multishell_armed=0` as the first line of
`_multishell_precmd` brought it to three.
Test gap: PromptMarkTests.swift:105-136 sets a user `PROMPT_COMMAND` but never
sends an empty line, and its stand-in helper is `/bin/echo` whose output is
not counted. A test feeding the input above and counting `command-started`
lines fails before the fix and passes after.

## Agents and session state

### 90. Medium. A pane whose agent died with a background worker out stays Working

`Sources/MultishellAppCore/States/SessionStates.swift:137-153`
(`noteCommandFinished`), `:89-125` (`settling`), `:193-205` (`processGone`);
`Sources/MultishellAppCore/Model/AppModel+SessionState.swift:154-160`; fired
from `Apps/macOS/Sources/Multishell/Terminals/GhosttyTerminalHost.swift:193`.
`claude` typed at a prompt in an app tab. `SubagentStart` lands `subagents: 1`,
so the entry has `background = 1` and Claude's pid. Claude is killed, or a
`SubagentStop` never fires: no Stop, SubagentStop or SessionEnd arrives. The
shell's precmd then fires two signals for that command end. libghostty's
OSC 133 D reaches `noteCommandFinished`, which sets `state = finished` and
`pid = nil` and never touches `background` or `owesDone`. hooks.zsh's `done`
over the socket, carrying no pid, hits `settling`'s `.done where background > 0`,
sets `owesDone` and returns `.running`. With the pid nil, `trackedPIDs` is
empty and `processGone`, the path agents.md relies on ("the process going
clears it"), can never run.
Engine-first order: the pane sits on Working at a bare prompt, Cmd+W asks
"an agent is working", the quit guard counts it, and every later `make` in
that shell ends as Working. Socket-first order: the pane lands on Done but
`background` stays 1, so the next agent session's every Stop is held as
Working until a SubagentStop or SessionStart arrives. Only Clear Status or an
idle or error report resets it.
`finished(exitCode: 130)` is `.done` (SessionState.swift:59-62). `settling`
resets `background` only on `.idle` and `.error` and via `processGone`.
SessionStatesTests' `noteCommandFinished` cases (78-101) and `subagents:` cases
(280-413) never meet. Fix: `noteCommandFinished` resets `background` and
`owesDone`, the foreground command having returned, with a test pairing a
subagent tick and a shell finish.

### 91. Low. The Dock badge counts a dead agent's shell failure as an agent waiting until the board is opened

`Sources/MultishellAppCore/Model/AppModel+AgentBoard.swift:43-45`, `:49-56`;
`Sources/MultishellAppCore/Model/AppModel+SessionState.swift:41-43`, `:253-256`.
`claude` at a prompt sets `reportedAgents[session]`; Claude quits, and
SessionEnd still carries `agent`, so the entry stays. `swift test` then fails
in that shell: the `error` puts the key in Waiting, `isAgentPane` reads
`reportedAgents != nil`, the badge shows 1. Opening the board runs
`sweepGonePIDs`, drops the entry, the card becomes a shell the filter hides,
and the badge goes to 0. agents.md says the badge "must read the same flag"
as the Waiting column; they disagree while the board is closed because the
pid is polled only while the board is up. AgentBoardModelTests cover the badge
and the sweep with the board shown, not the badge with it hidden after an
agent exits.

### 97. Low. Installing or removing an agent's hooks rewrites every float in the user's settings file

`Sources/MultishellCore/Agents/HookSettingsFile.swift:12` (`JSONSerialization.jsonObject`),
`:43-49` (`render`).
`~/.claude/settings.json` or `~/.gemini/settings.json` holding `"x": 0.1`
comes back from Add or Remove as `0.10000000000000001`, and `1.0` as `1`.
agents.md promises the file is the user's and refuses comment-bearing files
for exactly this reason. Reproduced with a Foundation script parsing
`{"a": 1.0, "c": 0.1}` and rendering with `render`'s options: `"a" : 1`,
`"c" : 0.10000000000000001`. Whether any agent ships a float setting by
default is not established.

### 85. Unproven. Three of the four agents' hook files have never been watched moving a dot

`Sources/MultishellCore/Agents/AgentHooks.swift`.
The four hook files are written from each agent's documented shape, and only
Claude Code's has been watched moving a dot in a real session. Run each agent
once: check its events fire, that the pid reported is the agent and not a
wrapper outliving the hook, and that Codex's `/hooks` trust holds. The
OpenCode plugin (OpenCodePlugin.swift) has been driven against a stub helper;
unproven is that OpenCode loads a plugin exporting a function rather than a
default `{ id, setup }`, its loader having two generations of that contract,
and that the two permission events arrive under the names the plugin now
listens for, with the title where it reads it.

### 86. Low. An OpenCode server reused by a second pane lands the dot on the first pane's tab

`Sources/MultishellCore/Agents/OpenCodePlugin.swift:31`.
The plugin spawns the helper from the OpenCode server's process, and the
helper reads `MULTISHELL_SESSION` from its environment (Helper.swift:13). An
OpenCode server started from one pane and reused by another therefore reports
that first pane's session, so the dot lands on the wrong tab. Only the plugin
has this: every other agent's hook runs in the session's own process.

## Worktrees and projects

### 92. Low. A stage's hook keeps running with no Cancel once its worktree is removed outside the app

`Sources/MultishellAppCore/Model/AppModel+Runtime.swift:80-95` (`forgetWorktrees`);
compare `AppModel+Projects.swift:40`.
A post-create hook is running for W and the user runs
`git worktree remove --force W` in a terminal. The tick's `replaceWorktrees`
discards W and `forgetWorktrees` clears the operation entry but leaves
`stageStoppers[id]` and `worktreeSetups[id]`: the hook runs on in a deleted
directory until it ends or hits the 60 s default timeout, with no row or pane
to Cancel from, then `failStage` alerts about a worktree that no longer
exists. `removeProject` calls `cancelStage` per worktree first; this path does
not. No AppModelHookControlTests case removes a worktree from git while a
stage runs.

### 93. Low. A project removed while its refresh is failing raises an alert about it and stays in `missingProjects`

`Sources/MultishellAppCore/Model/AppModel+Projects.swift:116-120`; compare the
guard at `:105`.
`refresh(project)` is awaiting a git call that will fail and the user removes
the project meanwhile. The `catch` runs `missingProjects.insert(project.id).inserted`
with no `workspace.project(project.id) != nil` guard, so it inserts a stale id
and alerts "command failed" about a project no longer in the sidebar. The
success path at line 105 has exactly that guard. `removeProject` clears every
per-project collection before the call returns; nothing on the failure path
re-checks membership.

### 94. Low. `git worktree add` runs with no timeout and no stopper while the sheet's Cancel is greyed out

`Sources/MultishellGitKit/WorktreeCoordinator.swift:161-167`,
`WorktreeService.swift:142-154`, `GitRunner.swift:49-57`;
`Apps/macOS/Sources/Multishell/Sheets/NewWorktreeSheet.swift:84`.
`service.add` passes neither timeout nor stopper, and `GitRunner.run` has no
stopper parameter. An LFS smudge or a credential helper waiting on a dead
network holds the checkout; the sheet shows "Adding worktree" with Cancel
disabled, since `worktreeCreationStep != .preCreateHook`. `hookTimeout` covers
hooks only. known-gaps.md records the file lists having no timeout but not
this step.

### 95. Low. A `forget` that fails after the trash step is read as "nothing moved"

`Sources/MultishellGitKit/WorktreeCoordinator.swift:212-223`,
`WorktreeService.swift:158-168`;
`Sources/MultishellAppCore/Worktrees/RemovalFailure.swift:56-61`.
After the directory is trashed and confirmed gone, `forget` runs
`worktree remove --force --force` then, on any failure, `prune`. If both fail,
say a `.git/worktrees/<name>` the process cannot delete, the untyped
`ProcessFailure` reaches `RemovalFailure.describe`'s `default:` arm, whose
comment says nothing moved and which returns `worktreeRemoved: false`; the
model clears the operation without refreshing. The directory is in the Trash
and git still lists it. `TrashFailure` and `TrashTookNothing` type the trash
step; the forget step has no type. Unproven: whether `prune` exits non-zero on
an undeletable record; if it exits 0 the symptom is a surviving record, the
post-delete hook and `branch -d` running, and a row whose directory is in the
Trash. Either way the caller cannot tell the stages apart.

### 121. Unproven. The sheet's step may be left set after a create ends, silencing the shared-hooks question

`Sources/MultishellAppCore/Model/AppModel+WorktreeCreation.swift:64-67`, `:80`;
`Sources/MultishellGitKit/WorktreeCoordinator.swift:154-166`;
`AppModel+SharedSettings.swift:115`.
`onStep` writes `worktreeCreationStep` through `Task { @MainActor }` from the
coordinator's executor while the `defer` clears it synchronously on return.
If `service.add` threw before its first suspension, the step Task and the
resumption would be queued on the main actor with nothing ordering them; a
step landing last leaves the slot non-nil and `askAboutSharedHooksIfNeeded`
returns early until the next create. Not established: whether `service.add`
has a synchronous throwing path, or whether the executor ever runs the later
job first. Every path read suspends on a process before returning.

## Process layer

### 96. Low. A shell greeting holding `=`, or one with no final newline, loses the first environment variable

`Sources/MultishellProcess/LoginShellEnvironment.swift:59-70`.
`parse` takes `entry.firstIndex(of: "=")` before cutting at the last newline.
A banner like `==== welcome ====` printed by an rc file lands in the first
`env -0` entry, the first `=` is at index 0, the key is empty and the entry is
skipped. A greeting with no trailing newline makes the key `hiTERM`. If the
shell's first exported variable is PATH, line 46 sees no PATH and falls back
to the Finder's, so a Homebrew or Nix git is not found. Fix: cut at the last
newline first, then split on `=`. LoginShellEnvironmentTests.swift:19 covers
a greeting with no `=` and a trailing newline only.

### 110. Low. The socket server's comment names `flock` for a lock taken with `fcntl`

`Sources/MultishellProcess/UnixSocketServer.swift:15-16`;
docs/develop/state-on-disk.md ("Not `flock`").
The comment on `claim` says "`flock` goes with the process"; `claimOrRefuse`
(125-127) takes an `F_WRLCK` record lock, which the design chose over `flock`
deliberately. A reader following the comment could reintroduce the
inherited-lock problem the design names. No `flock(` call exists in Sources.

## Store

### 103. Low. `setSplitWeights` writes weights unchecked where `setGroupWeights` refuses them, and `PaneNode` lets a zero through

`Sources/MultishellCore/Store/WorkspaceStore.swift:451-454` vs `:329-333`;
`Sources/MultishellCore/Model/PaneNode.swift:48` vs `Model/TabGroup.swift:31-32`.
`setGroupWeights` guards `isFinite && > 0`; `setSplitWeights` checks only the
count. `PaneNode.init(from:)` accepts `>= 0`, so a saved `[0, 1]` decodes as
a zero-width pane, while TabGroup.swift's comment claims PaneNode "makes the
same substitution" of zero to 1; it resets the whole array only for a
negative or non-finite weight. The one writer, `SplitMath.transferring`,
clamps above zero, so this is reachable only via a hand-edited file or a
future caller. No zero-weight case in PaneNodeTests or WorkspaceRepairTests;
`weightsAligned` in WorkspaceInvariants.swift:86 checks counts only.

## Settings

### 104. Low. A `.multishell.json` that will not parse is explained on screen in English written outside the catalogue

`Sources/MultishellAppCore/Model/AppModel+SharedSettings.swift:103`; drawn by
`Apps/macOS/Sources/Multishell/Sheets/ProjectSettings/ProjectHooksTab.swift:18-19`.
`let problem = "\(SharedProjectSettings.fileName) could not be read: \(error)"`
is stored in `SharedSettingsCache.problem` and `ProjectHooksTab` draws it as a
`SettingsCaption`. layout.md: no user-visible literal outside a catalogue. The
`error` half is `String(describing:)` of a Swift error. The catalogue has
"could not be read" keys for the theme and saved-state cases only.

## Notifications

### 99. Low. A banner still pending when it is withdrawn is never taken back

`Apps/macOS/Sources/Multishell/Support/UserNotifier.swift:52-56`; caller
`Sources/MultishellAppCore/Model/AppModel+SessionState.swift:134`.
`withdraw` calls `removeDeliveredNotifications(withIdentifiers:)` only.
`notify` posts with `trigger: nil`, which `add` delivers asynchronously, so
for tens of milliseconds the request is pending, not delivered. A report lands
for the shown tab while the app is inactive and the click activating the app
arrives inside that window: `onDidBecomeActive`, `markShownTabSeen`,
`withdrawNotification`, `removeDelivered...` matches nothing, `notifiedKeys`
drops the key, and the banner is delivered a moment later with nothing left to
retract it; its row sits in Notification Centre for hours.
`removePendingNotificationRequests(withIdentifiers:)` beside the delivered
call closes it; nothing in Apps/macOS/Sources calls it. The known-gaps entry
names a different hole, between `pendingAdds` and `add` on the permission
path.

## Terminals

### 100. Low. A generated Ghostty config file is left in the temp directory on every launch

`Apps/macOS/Sources/Multishell/Terminals/GhosttyTerminalHost.swift:15-18`,
`:95-100`; the wrapper's `TerminalController+Config.swift:10-18`, `:216-228`
(libghostty-spm 1.5.20260906).
Every `.generated(text)` source is written to
`$TMPDIR/io.multishell.app/ghostty-config-<UUID>.conf`. The wrapper removes
the previous file when a new one replaces it, but the last one a process
writes is never removed, and the wrapper's doc on `managedConfigDirectory`
says the host is expected to clear the directory before creating controllers
and at termination. The app does neither: nothing in Apps/macOS/Sources or
Sources names `managedConfigDirectory`, `shutDown()` saves and stops the
socket only, and `applicationWillTerminate` calls only `willTerminate`. Each
launch adds one file holding the user's filtered config, bounded by macOS's
three-day temp purge.

### 108. Low. `didExit` reports code 0 for every close and nothing reads it

`Apps/macOS/Sources/Multishell/Terminals/GhosttyTerminalHost.swift:130-132`;
`Sources/MultishellCore/Ports/TerminalHost.swift:29`;
`Sources/MultishellCore/Sessions/SessionRegistry.swift:100`.
`surfaceClosed` reports `didExit: id, code: 0` for every close because
`terminalDidClose(processAlive:)` carries no status, and the registry never
reads `code`. A reader of the port sees a status that is always zero. Either
drop the parameter or pass what the host knows, `processAlive`.

## macOS app views

### 98. Low. A cancelled sidebar-divider drag makes the next drag jump to a stale width

`Apps/macOS/Sources/Multishell/App/RootView.swift:46-53`; compare
`Terminals/WeightedSplit.swift:130-165`.
The drag reads `let start = dragStartWidth ?? sidebarWidth` and clears
`dragStartWidth` only in `.onEnded`. A `DragGesture` the system cancels,
Cmd+Tab or the window deactivating mid-drag, never calls `onEnded`, so
`dragStartWidth` keeps the width the abandoned drag started from. On the next
drag `start` is that stale value and `sidebarWidth = start + translation`
snaps the sidebar to where the last drag began before following the pointer.
`WeightedSplit` was changed to read the end off `@GestureState` for exactly
this reason (its comment at 130-131 and the known-gaps entry on divider
drags); the sidebar divider still has the pattern that was replaced.

### 105. Low. Help text for the project icon picker describes a search field that no longer exists

`Apps/macOS/Sources/Multishell/Resources/en.lproj/Localizable.strings:145`
(`project.icon-info`); `Sheets/ProjectSettings/IconPicker.swift:29-42`, `:81-82`.
The (i) on Project Settings > General > Icon says "the field at the top
matches both a symbol's name and what it is used for ... Down from the field
moves into the grid". `IconPicker` has no field; its own comment at line 81
says the search field used to carry the top of the popover and the grid does
now, and translation.md and smaller-decisions.md record the search being
removed. A user following the help looks for a control that is not there.
ProjectIconSection.swift:23 is the one call site.

### 106. Low. The sidebar's rename field is invisible to assistive technology

`Apps/macOS/Sources/Multishell/Sidebar/WorktreeRow.swift:117-124`; compare
`Terminals/TabButton.swift:115-117`.
The row is `.accessibilityElement(children: .ignore)` and offers
`.accessibilityAction(named: Rename)`. Invoking it sets `isRenaming`, which
swaps `names` for `nameField`, an `InlineNameField` inside the same ignored
subtree: VoiceOver can start the rename but cannot reach the field it opened.
`TabButton` uses `.contain` for the same shape so its field stays reachable.
The `.ignore` is unconditional and `InlineNameField` has no accessibility
modifiers. known-gaps.md says the labels have not been read with VoiceOver,
hence an inconsistency rather than a watched defect.

### 107. Low. A settings view reaches the Platform port directly instead of through the model

`Apps/macOS/Sources/Multishell/Sheets/AppSettings/NotificationSettingsTab.swift:22`.
The footer caption is built from `model.platform.notificationSettingsLocation`.
layout.md: views call AppModel, and what the model needs from the desktop goes
through the `Platform` port. This is the only view site that walks through
the model to the port; the three other `platform` uses pass the `MacPlatform`
instance for `mainWindow?.screen`. It is also the one value on the page a
Linux frontend would read differently, so the model is where the indirection
belongs.

## Codebase conventions

### 109. Low. Nine comments run over the two-line limit, and one doc comment is orphaned

CLAUDE.md: no code comment exceeds two lines.
`Sources/MultishellAppCore/Model/AppModel.swift:297-301` (5 lines);
`AppModel+Runtime.swift:115-118` (4); `Detection/ShellDetection.swift:11-13`,
`Model/AppModel+Agents.swift:126-128`, `Model/AppModel+SharedSettings.swift:141-143`,
`Model/AppModel+Tabs.swift:239-241`, `States/SessionStates.swift:56-58` (3 each);
`Sources/MultishellGitKit/GitRunner.swift:25-28` (4, and its `path` sentence
already lives in architecture.md); `WorktreeFileFailures.swift:31-33` (3).
MultishellCore and Apps/macOS have none.
Orphaned: `Apps/macOS/Sources/Multishell/Terminals/TabButton.swift:26`,
`/// Which tab in the strip is showing its name field, so only one ever is.`
is followed by a blank line and then `private var isActive`. It documented a
property that moved to the model (`renamingTabID`, AppModel+Tabs.swift:215-231)
and now reads as the doc for `isActive`.

### 111. Low. Three public entry points have no caller outside the tests

`Sources/MultishellProcess/ShellCommand.swift:14-22` (`run(_:in:environment:)`),
`Sources/MultishellGitKit/WorktreeCoordinator.swift:43-45` (`statuses(of:)`),
`Sources/MultishellCore/Theme/HexColor.swift:54` (`Theme.cursorRGB`).
The app calls `launch` and `runScript` only; AppModel+Runtime calls
`readStatuses` only; `cursorRGB` is referenced nowhere but its own line. The
first two are exercised solely by ProcessRunnerTests, WorktreeCreationTests,
WorktreeCoordinatorTests and BareRepositoryTests. layout.md counts a public
API nothing calls as a finding.

## Tests

### 101. Low. Test harnesses make a temp directory per test and never remove it

`Tests/MultishellAppCoreTests/Harness.swift:181-193`;
`Apps/macOS/Tests/MultishellTests/ModelHarness.swift:15-18`; also
`ProjectRemovalTraceTests.swift:28` (GitHarness with no `tearDown`, a real git
repo per run), `SessionStateModelTests.swift:421` (`Scratch.directory("socket")`
never removed), `UnixSocketTests.swift:111-113` (dead socket file never
unlinked; `stop()` returns at UnixSocketServer.swift:106 before its `unlink`
because the server never started).
`Harness.init` creates `multishell-appmodel-<UUID>` plus a `feature`
subdirectory under `NSTemporaryDirectory()` with `try?` and has no `tearDown`
or `deinit`; `GitHarness` beside it has one. 138 `Harness(...)` and 6
`ModelHarness()` call sites, so one `swift test` leaves about 150
directories. `$TMPDIR/multishell-*` was empty when checked, so either the
suite had not run since the OS swept the folder or the leak is smaller than
the code says; the suite was not run for this review.

### 112. Low. Six tests read the developer's own machine

tests.md: "never the machine".
`Tests/MultishellProcessTests/LoginShellEnvironmentTests.swift:27-33`;
`Tests/MultishellAppCoreTests/AppModelTests.swift:40-51`;
`Tests/MultishellAppCoreTests/SessionStateModelTests.swift:598-605`, `:666-673`;
`Tests/MultishellProcessTests/ProcessRunnerTests.swift:323-342`;
`Tests/MultishellGitKitTests/GitRefNameTests.swift:35-37`;
`Tests/MultishellCLITests/HelperTests.swift:665-672`.
`LoginShellEnvironment.capture()` (LoginShellEnvironment.swift:26-31) runs the
process's `$SHELL` as a login interactive shell with the real HOME and takes
no shell or PATH argument; the four model and process tests call it, and two
then assert `agentDetection == AgentDetection(path: loginEnvironment.path)`,
the machine's PATH against itself. A developer whose rc prompts, is slow past
8 s, or whose shell is fish fails or vacuously passes:
`HookShellTests.aHookRunsInTheUsersInteractiveLoginShell` evaluates no
`#expect` at all unless `$SHELL` is zsh, bash or sh. `GitRefNameTests.gitAccepts`
uses `/usr/bin/env git`, the PATH's git, as oracle for a runner that may use
another. `HelperTests.zshIntegrationFollowsAZdotdirSetByTheUsersZprofile`
inherits `ProcessInfo.processInfo.environment` and sets no `MULTISHELL_SOCKET`,
so run from inside a Multishell tab its zsh hooks report to the developer's
live app.

### 113. Low. Test helpers duplicated across suites that layout.md puts in TestScratch

`SeededGenerator` three times, byte-identical (WorkspaceInvariants.swift:97,
AppModelInvariantTests.swift:8, IconGridWalkTests.swift:8); `LineRecorder`
twice (UnixSocketTests.swift:7, HelperTests.swift:10); `waitUntil` and
`socketPath` three times (UnixSocketTests, HelperTests, SocketStateSourceTests);
`lowestDescriptorCount` twice (ProcessRunnerTests.swift:201,
DispatchDirectoryWatcherTests.swift:135); `demoStore` twice in one target
(WorkspaceStoreTests.swift:26, TabGroupStoreTests.swift:7); `Fired`
(GitHarness.swift:90) and `Flag` (SessionStateModelTests.swift:678).
`MultishellCLITests` does not depend on `TestScratch` at all
(Package.swift:57-59), which is why HelperTests hand-rolls `/tmp/ms-*` roots
and its own recorder and poller.

### 114. Low. Three tests wait on a fixed sleep where the suite elsewhere polls the state

`Tests/MultishellAppCoreTests/AppModelHookControlTests.swift:396-397`, `:413-414`;
`Tests/MultishellAppCoreTests/AgentBoardModelTests.swift:529`.
tests.md: "Prefer evidence to a clock." Both HookControl tests sleep 300 ms
then assert the stage a not-yet-awaited Task should have reached; a loaded
runner that has not scheduled it fails them, and
`removalShowsItsStageInThePaneUntilItEnds` (AppModelGitTests.swift:345-350)
already shows the polling form. `aGoneAgentTakesItsCardWithIt` sleeps a flat
2 s with a 10 ms poll interval.

### 115. Low. `ChangeCounter` saturates at one, so it cannot tell one change from many

`Tests/MultishellCoreTests/WorkspaceStoreTests.swift:40-53`.
`withObservationTracking` is registered once in `init` and never re-armed, so
`changes` is 0 or 1 while the doc comment says it "counts how often". `== 1`
after one change passes (line 307); `== 1` after two would also pass. Three
call sites.

### 116. Low. HelperTests finds the helper at a hard-coded `.build/debug/multishell`

`Tests/MultishellCLITests/HelperTests.swift:19-23`.
`swift test -c release` or a `--scratch-path` puts the helper elsewhere;
every case then fails at launch with a missing-executable error rather than
one naming the assumption.

### 117. Low. Three `// MARK: -` banners in test files

layout.md forbids `MARK` banners.
`Tests/MultishellCoreTests/DecodingDefaultsTests.swift:666`;
`Tests/MultishellCoreTests/TranslationTests.swift:140`;
`Apps/macOS/Tests/MultishellTests/TranslationTests.swift:171`.

### 122. Unproven. A starvation test's bound grows with core count while the spawn rate does not

`Tests/MultishellProcessTests/ProcessRunnerTests.swift:63-87`.
`manyConcurrentProcessesDoNotStarveEachOther` asserts
`peaks.max() > cores * 2` over 96 one-second children: 5 on a 2-core runner,
33 of 96 alive at once on a 16-core Mac, which depends on `/bin/sh` spawn
rate under the rest of the suite rather than on the pool freeing threads. Not
run for this review; the comment says the previous wall-clock form flaked, so
this may still be the better bound.
