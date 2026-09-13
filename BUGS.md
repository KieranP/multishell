# Bugs

Open findings from a whole-repo review on 2026-09-13, against commit 7fa714f.

Eighteen defects stand, none High. Each was read a second time by a verifier
working from the code as it is, and the git-behaviour ones were reproduced in
a scratch repository.

After them, thirty findings that are not defects: Perf, Design, Simplify,
Reuse and Style. Those are one finder's reading each, kept as written and not
checked by a second, so read the code before acting on one. The Style entries
are breaches of the repo's own rules on comment length and one type per file;
whether the MARK banners are one is for the owner to say.

Numbers continue from the last review, which ended at 33. A fixed entry is
taken out rather than kept.

| # | Effect | What |
| --- | --- | --- |
| 34 | Medium | Removing one worktree makes git forget every other whose directory is away |
| 35 | Medium | A branch brought up with a bare `git rebase` is badged merged with certainty |
| 36 | Medium | Export drops the keys of `.multishell.json` this build does not know |
| 37 | Medium | `multishell state` at a prompt pins the dot to the app's own pid, forever |
| 38 | Medium | A removal whose Trash refuses deletes the tree on the main thread |
| 39 | Medium | A subagent ending after an uncounted start flips Done back to Working |
| 40 | Medium | The Agents board closes by itself when a post-create stage ends |
| 41 | Medium | A report from a subdirectory of a worktree is dropped without a word |
| 42 | Medium | A control character in a worktree path kills every zsh report from it |
| 43 | Low | A failed Trash leaves a locked worktree unlocked |
| 44 | Low | The container directory is made by hand, so a refused create leaves it |
| 45 | Low | An agent tab opened during the launch scan says the agent is not installed |
| 46 | Low | A late `git status` writes against a worktree that may have been replaced |
| 47 | Low | The signing script deletes the spaces inside the keychain path |
| 48 | Low | A second `start()` on a live socket server drops its own claim |
| 49 | Low | A socket path of 102 or 103 bytes passes the check and fails to bind |
| 50 | Low | Ghostty focus writes into the store from inside a SwiftUI update |
| 51 | Low | The existing-branch path runs the hook before git rejects the name |
| 52 | Low | ZDOTDIR is read from the app's environment, not the login shell's |
| 53 | Perf | The status poll runs `git status` for missing projects' worktrees |
| 54 | Perf | Every split-divider drag frame writes the workspace and re-arms autosave |
| 55 | Perf | The sidebar scans every session four times per worktree per render |
| 56 | Perf | Every watcher tick re-reads every project's records and re-arms every watch |
| 57 | Perf | Autosave encodes and writes the workspace on the main actor |
| 58 | Perf | The Agents board does a linear worktree scan per session on every render |
| 59 | Design | The launch alert is identified by comparing its translated title |
| 60 | Design | Per-worktree runtime state is pruned at five sites in four files |
| 61 | Design | `settle(group:vacating:)` relies on every caller precomputing the slot |
| 62 | Design | `SessionStates` keeps six parallel per-key collections |
| 63 | Design | The shell-start precondition is spelled differently at three entry points |
| 64 | Design | Which worktrees may be removed is decided twice with two spellings |
| 65 | Simplify | The three `moveTab` overloads repeat most of one body |
| 66 | Simplify | `moveProjects` takes an `IndexSet` its only caller never needs |
| 67 | Simplify | `apply(_ report:)` has two branches identical but for the key |
| 68 | Simplify | `select`'s `byUser` flag is derivable from `openingFirstTab` |
| 69 | Simplify | The assign-only-if-changed idiom is hand-written sixteen times |
| 70 | Simplify | Wrap-around neighbour arithmetic is written twice, in two modules |
| 71 | Reuse | `helperReference` re-implements the home-prefix check |
| 72 | Reuse | Five min/max chains re-implement `clamped(to:)`, which sits in the Mac layer |
| 73 | Reuse | Ref-namespace prefixes are spelled outside `BranchRef` |
| 74 | Reuse | Three is-under-directory checks use two algorithms |
| 75 | Reuse | Four on-disk JSON writers with diverging encoder options |
| 76 | Reuse | The one-path-per-line grammar is parsed in two places |
| 77 | Style | A six-line doc comment in `UnixSocketServer` |
| 78 | Style | A six-line doc comment on `GitRefName` |
| 79 | Style | `GitRefName.swift` holds an unrelated error type beside its own |
| 80 | Style | A four-line doc comment on an `EditorLaunch` case |
| 81 | Style | `TabDrops.swift` declares four types and is named for none |
| 82 | Style | MARK section banners across four packages |

## Worktrees

### 34. Medium. Removing one worktree makes git forget every other whose directory is away

`Sources/MultishellGitKit/WorktreeCoordinator.swift:211`, `try await service.prune(project)`.
Removal trashes one directory then runs a repository-wide `git worktree
prune`, which drops the record of every worktree whose directory is missing at
that moment, not only the one just trashed. A worktree on an unmounted
external drive is the case: its record goes, and when the drive returns the
directory's `.git` file points at a gitdir that no longer exists.

Reproduced with git 2.55: two linked worktrees, one moved aside, the other
deleted, then `prune`. Only the main worktree remained. Moving the first back
gave `fatal: not a git repository` and `git worktree repair` did not bring it
back. A lock protects a record from prune, but that depends on the user having
set one. `git worktree remove --force <path>` on the already deleted directory
exited 0 and left the other worktree listed as prunable.

Fix = scope the forget to the worktree just trashed with `git worktree remove
--force <path>`, falling back to `prune` only if that fails.

### 35. Medium. A branch brought up with a bare `git rebase` is badged merged with certainty

`Sources/MultishellGitKit/ReflogWorkParser.swift:22`.
A branch cut from an old trunk, with no commits of its own, brought up with
`git rebase main` gets the reflog entry `rebase (finish): refs/heads/feat onto
<sha>`, the same wording as a rebase that replayed commits. The parser treats
every `(finish)` as work, `git branch --merged` lists the branch since its tip
now equals the trunk, and the verdict is `.merged(.ancestor)`, which is
certain. The sidebar badge goes green and the removal dialog leads with Delete
branch, for a branch that never began. merged-branch.md:10 says a branch
carried up must not badge, and its list of arrivals at lines 15-17 (branch,
reset, clone, fetch, a merge or pull fast-forward) names a rebase's `(finish)`
as work of its own, so the doc endorses the current reading and rests on the
same wrong premise.

Reproduced with git 2.55. `git pull --rebase` on the same setup wrote `pull
... : Fast-forward`, which is handled; only a bare `git rebase`, or a pull
configured to run a real rebase, hits this. No data is lost since the tip
equals the trunk, but the wording is wrong for the case the design singles
out. `MergeParserTests.swift:127` asserts that `(finish)` implies own commits,
which git does not guarantee.

Fix = read the reflog as `%H %gs` and treat a `rebase (finish): <ref> onto
<sha>` whose new value equals `<sha>` as an arrival; keep any other `(finish)`
as work. Update the test.

### 43. Low. A failed Trash leaves a locked worktree unlocked

`Sources/MultishellGitKit/WorktreeCoordinator.swift:203`.
The unlock runs before the Trash step. When the Trash refuses, `TrashFailure`
is thrown at line 208 and nothing re-locks, so the worktree stays on disk
without the lock the user set, and the reason they gave is gone. Reaching it
needs both `moveToTrash` and the `removeItem` fallback to fail, so a read-only
or permission-refusing volume. The lock is consulted only by prune and gc, so
the loss bites when that volume is later unmounted while another removal
prunes.

`git worktree unlock` succeeds on a record whose directory has already been
deleted, checked in a scratch repository, so the unlock can move after the
trash. Fix = unlock after the trash succeeds, or re-lock in the catch.

### 44. Low. The container directory is made by hand, so a refused create leaves it

`Sources/MultishellGitKit/WorktreeCoordinator.swift:148`.
`createDirectory(at: path.deletingLastPathComponent(),
withIntermediateDirectories: true)` runs before `service.add`, and nothing
removes it when git refuses. A new-branch name that already exists reaches
this from the sheet: `canCreate` checks only `GitRefName.isValidBranch` and
never whether the name is taken, so `git worktree add -b feat` fails after the
folder exists. With a nested setting like
`~/wt/{project}/{project}-worktrees`, a chain of empty folders is left.

The call is unnecessary. In a scratch repository `git worktree add -b ok
../deep/er/proj-worktrees/ok` created every leading directory itself, and both
rejected adds left none. Fix = delete the `createDirectory` call. The sheet
could also refuse a new-branch name that already exists.

### 46. Low. A late `git status` writes against a worktree that may have been replaced

`Sources/MultishellAppCore/Model/AppModel+Runtime.swift:113`.
`refreshStatus(of:)` writes `statuses[worktreeID]` after its await, guarded at
line 112 only by the value having changed and not by the worktree still
existing, while `refreshStatuses` at line 89 re-reads `known` after its await
and filters. Nothing cancels `pendingStatusRefreshes` on removal, and
`forgetVanishedWorktrees` runs at `replaceWorktrees`, before the late write
lands. Paths being ids, a worktree removed and re-created at the same path
inherits the old checkout's changed-files badge until the next frontmost poll.

Plausible rather than confirmed: the visible effect needs a remove and a
re-add inside one status run, about 250 ms plus git's time, which the UI's own
remove and create cannot do. Fix = after the await, guard that the worktree
still exists and is the same value before assigning.

### 51. Low. The existing-branch path runs the hook before git rejects the name

`Sources/MultishellGitKit/WorktreeCoordinator.swift:138`, `guard !createBranch || GitRefName.isValidBranch(branch)`.
The name is validated only when a branch is being created. With `createBranch:
false` and an empty or malformed name, the pre-create hook runs with
`MULTISHELL_BRANCH` empty, the container directory is made (44), and only then
`git worktree add` fails with an invalid reference. worktrees.md:84 says the
opposite: `add` throws before the hook for a caller that did not ask.

The sheet cannot reach it, Create being disabled unless the name is in
`availableBranches`. Only an API caller does. Skipping the check for an
existing branch is not explained anywhere; if the reason is to allow a
commit-ish like `HEAD` or `origin/main`, which `isValidBranch` rejects, that
wants writing down. Fix = refuse an empty name before the hook regardless of
`createBranch`, and either validate the existing-branch name too or record in
worktrees.md that this path takes any commit-ish and is not guarded.

## Shared settings

### 36. Medium. Export drops the keys of `.multishell.json` this build does not know

`Sources/MultishellCore/Model/SharedProjectSettings.swift:135`.
`load` decodes through a fixed `CodingKeys` container at line 195, which drops
an unknown key, and `decodeTolerantly` at lines 199, 202, 220 and 224 drops a
known key of the wrong type; the comment at 218 says as much. Export builds
from `effectiveSettings`, keeps only the four hooks through
`keepingHooks(of:)`, and `write` encodes `self`, which emits only the
seventeen keys, then replaces the file atomically. A teammate on a newer build
who committed a key this build lacks, or a `$schema` line, loses it from the
repository on the user's next commit. Nothing in the app shows the loss; only
`git diff` would.

settings.md:34 covers hooks only: export keeps the file's own hooks where the
user wrote none. Fix = have `load` keep the file's raw top-level dictionary
alongside the decoded fields, and have `write` merge the export over it.

## Agents and session state

### 37. Medium. `multishell state` at a prompt pins the dot to the app's own pid, forever

`Sources/MultishellCLI/Helper.swift:96`, `pid: options.int32("pid") ?? ProcessAncestry.reportingProcess()`.
Without `--pid`, the helper walks up from its parent while the process name is
a shell. From a prompt in a tab the parent is `zsh`, then either the app
directly (SwiftTerm forks in-process) or `login`, which is in the shell list,
then the app. `Multishell` is not a shell, so the walk returns the app's pid.
`SessionStates.report` stores it for Running and Waiting, and `sweepGonePIDs`
asks `isGone(pid)` every two seconds, which for the app's own live pid is
never true. The Working dot, the board card and the Cmd+W confirmation stay
until another report or a manual Clear Status. With `--agent`,
`ReportedAgent.isAtThePrompt` stays true as well.

This is the documented use of the helper (README.md:68). The shell hooks pass
`--pid $$` and are unaffected. No guard anywhere compares a reported pid to
`ProcessInfo.processInfo.processIdentifier`. Fix = export the app's pid to
sessions and have `reportingProcess` stop when the next parent equals it,
returning the last shell visited so the state clears when that shell exits;
and have `apply` treat a pid equal to its own as absent.

### 39. Medium. A subagent ending after an uncounted start flips Done back to Working

`Sources/MultishellAppCore/States/SessionStates.swift:79`, `return state` in `settling`.
With `states[key] == .done` and `background[key] == nil`, a `SubagentStop`
tick of `-1` gives `count = 0`, `owedDone.remove` finds nothing, the
`.attention` guard on line 78 does not match Done, so the tick returns
`.running`. In `report`, `isBookkeeping` is false, lines 55 and 56 write
Working with Claude's live pid, and line 61 replaces the Done note. The pid is
live, so `processGone` never fires; only the next turn's Stop moves it.

The uncounted start is reachable: the app launched or hooks installed after
`SubagentStart`, a Clear Status which drops `background`, or an idle or error
report at line 89 while workers were out, then Stop, then `SubagentStop`.
agents.md:80 says a counting tick is bookkeeping and not news, but the code
makes it so only for Waiting. `SessionStatesTests.swift:346` covers the stray
tick from nil and line 354 from Waiting, not from Done. Fix = when a tick pays
no owed Done, return the key's current state and have `report` treat that as
bookkeeping, so only a real Working report moves a Done.

### 41. Medium. A report from a subdirectory of a worktree is dropped without a word

`Sources/MultishellAppCore/Model/AppModel+SessionState.swift:88`, `worktree(atPath:)`.
The lookup builds two spellings of the cwd and asks whether either equals a
worktree's path. Claude Code started in an outside terminal from
`<worktree>/packages/api` sends `payload.cwd` as that subdirectory with no
session id; `multishell state` from outside a pane falls back to the current
directory the same way. Neither matches, `apply` drops the report at line 49,
and nothing is logged: no dot, no banner, no card.

`SessionStateModelTests.swift:44` pins exact path and trailing slash only.
agents.md decides that an unknown session id is not matched by directory;
nothing decides subdirectories. Fix = match the worktree whose path is a
path-component prefix of the cwd, taking the longest so a nested worktree wins
over the one containing it.

### 42. Medium. A control character in a worktree path kills every zsh report from it

`Sources/MultishellCore/Resources/hooks.zsh:43`, `_multishell_json`.
The zsh fast path builds the JSON line by hand and escapes only backslash and
double quote in `MULTISHELL_WORKTREE`. A tab or newline in the path goes in
raw, `SessionStateReport.parse` returns nil from `try? JSONDecoder()`, and
`SocketStateSource` drops the line with no log. Because the `zsocket` branch
is taken whenever `zsh/net/socket` loads, which it does on stock macOS zsh,
the helper binary, which encodes cwd correctly, is never reached. Every
command-started, command-finished and idle report from that tab is lost.

Ran the function with a tab in the path: `od -c` shows the raw byte and
`json.loads` rejects it. bash always goes through the helper and is fine.
worktrees.md reads the worktree list with `-z` so that such a path is
supported. Rare, since git refuses control characters in a branch name, so
only a parent directory carries one. Fix = omit `cwd` from the zsh-built line
when the path holds a control character, every shell report carrying the
session id, or escape the 0x00 to 0x1f range as `\uXXXX`.

### 45. Low. An agent tab opened during the launch scan says the agent is not installed

`Sources/MultishellAppCore/Model/AppModel+Agents.swift:16`, `loginEnvironment = environment`.
`loginEnvironment` is set, then the model awaits the `offMain` PATH scan
before `agentDetection` is filled at line 33. `start()` has already shown the
sidebar, so a click on a worktree with a saved agent tab in that window
reaches `agentCommand`, where line 148 reads `loginEnvironment != nil` and
`!agentDetection.isInstalled(id)` as true for the empty detection. The "not
installed" alert is raised, `reportMissingAgentOnce` then suppresses any real
report for that agent this run, and the tab opens as a plain shell. The window
is the scan's duration: milliseconds normally, seconds per PATH entry on a
dead mount.

Traced in code, not on screen. Fix = assign `loginEnvironment` together with
the detections after the scan returns, or gate the check on the detection
having been filled.

## Board and tabs

### 38. Medium. A removal whose Trash refuses deletes the tree on the main thread

`Sources/MultishellAppCore/Model/AppModel+WorktreeRemoval.swift:104`, `try FileManager.default.removeItem(at: url)`.
`AppModel` is `@MainActor`. The coordinator's `trash` closure hops to it and
runs `platform.moveToTrash`, which is `trashItem(at:)`, synchronously, and on
any error the fallback unlinks the whole tree in the same call. Neither goes
through `offMain`, which the file placement two files over does use. On a
network share or a volume with no `.Trashes`, a multi-gigabyte `node_modules`
is walked on the main thread: socket reports, delivered on `.main`, queue; the
two-second pid sweep and the status poll stall; the window does not respond.
`cancelHelp` is nil for `.removingWorktree`, so the pane offers no Cancel.

Distinct from the known gap about the directory check before a click.
worktrees.md:63 records the fallback to deletion, not where it runs. Fix = run
both the trash and the fallback through `offMain` inside `moveToTrash`,
keeping the log call on the main actor.

### 40. Medium. The Agents board closes by itself when a post-create stage ends

`Sources/MultishellAppCore/Model/AppModel+WorktreeCreation.swift:231`, `select(current, openingFirstTab: .onCreate, byUser: false)`.
`openHeldBackTab` guards only on the new worktree still being selected, and
`showAgentBoard` leaves the selection alone, so the guard holds while the
board is up. `select` then calls `leaveAgentBoard` unconditionally and `sync`,
which moves first responder to a terminal. It is reached from `finishStage`,
which the post-create hook and the file-list stages call from the setup task
with no user action. agents.md:189 says that while the board is up nothing
acting on the pane acts at all and that `worktreeInView` answers for them;
`openHeldBackTab` does not go through it.

No test covers a stage ending with the board shown. Fix = add
`!showsAgentBoard` to the guard so the held-back tab opens on the next visit,
which the comment at line 227 already promises.

### 50. Low. Ghostty focus writes into the store from inside a SwiftUI update

`Apps/macOS/Sources/Multishell/Terminals/SurfaceView.swift:23`, `frame.show(...)` in `updateNSView`.
When the frame is already in a window, `show` calls `requestFocus`
synchronously, and the chain runs inline: `focusSurface`, `host.focus`,
`takeFirstResponder`, libghostty's `becomeFirstResponder` calling
`core.setFocus(true)`, `TerminalSurfaceCoordinator.setFocus` calling
`terminalDidChangeFocus` on its delegate, `SurfaceObserver`, `host.focused`,
`SessionRegistry.terminalHost(didFocus:)`, `store.focusSession`, which writes
`focusedSessionID`, `activeTabID` and `focusedGroupByWorktree`
unconditionally. That is an `@Observable` mutation and an autosave schedule
from inside `updateNSView`, which SwiftUI flags as undefined behaviour. The
wrapper's own `TerminalViewState` defers exactly this callback for exactly
this reason; `SurfaceObserver` does not. SwiftTerm is unaffected, having no
focus callback.

No symptom has been seen on screen. Fix = hop one runloop turn in
`SurfaceObserver.terminalDidChangeFocus` before reporting, or defer
`requestFocus` in `focusIfReady`; and have `focusSession` skip writes that
change nothing.

## Process and sockets

### 48. Low. A second `start()` on a live socket server drops its own claim

`Sources/MultishellProcess/UnixSocketServer.swift:40`.
`claimOrRefuse` returns without error when the claim is already held, then
`probeAndUnlinkStale` connects to this process's own listener and throws
`.inUse`. The catch at line 41 calls `releaseClaim`, closing the descriptor
and with it the `fcntl` lock, while `listener` keeps accepting. The claim is
what stops a second launch from unlinking a live socket whose backlog is full,
so after this the server runs unguarded. No caller does it today: `start()`
runs once from `startStateSource`, and `stop()` then `start()` is fine because
`stop()` releases the claim. Fix = make `start()` idempotent with a guard on
`listener == nil`, or have `claimOrRefuse` report that the claim was already
held so the catch does not release it.

### 49. Low. A socket path of 102 or 103 bytes passes the check and fails to bind

`Sources/MultishellProcess/UnixSocketServer.swift:59`.
Line 55 checks `UnixSocketAddress.make(path)` against the real path, then line
59 binds `path + ".b"`, and `bindSocket` calls `make(staging)`, which throws
`.pathTooLong` naming the staging file. Proved with a Swift probe doing a real
bind: 102 and 103 bytes pass the first and fail the second, while a direct
bind of the real path succeeds. The alert reads `.../multishell.sock.b is too
long`, contradicting the comment on line 53, and the app has no socket though
the real path would fit. With the variant cut to its full 16 characters
(Paths.swift:58), the debug path is 85 bytes plus the short username, so a 17
or 18 character username lands in the window. The existing test uses a
130-byte path.

Fix = check the length of `staging` up front, so the limit is honestly 101
bytes, and update the comment and the `debugVariant` cut in Paths.swift.

## Terminals

### 52. Low. ZDOTDIR is read from the app's environment, not the login shell's

`Sources/MultishellCore/Sessions/SessionEnvironment.swift:49`, `environment["ZDOTDIR"]`.
Both hosts call `SessionEnvironment.variables` with no environment, so the
default `ProcessInfo.processInfo.environment` is read, and `loginEnvironment`
on the model, which holds the full `env -0` of a login interactive shell, is
never handed over. A ZDOTDIR set in `~/.zshenv` is re-captured by the
generated chain, so the common case works. One set in `~/.zprofile` or
`/etc/zprofile` is not: the `.zprofile` chain sources the user's with
`capturesUserZdotdir` false and restores ours, so the `.zshrc` chain sources
`$HOME/.zshrc` while Terminal.app would read `$ZDOTDIR/.zshrc`.

Plausible rather than confirmed: not traced against a live shell. Fix = pass
`loginEnvironment?.variables` into `SessionEnvironment.variables` from both
hosts, and set `capturesUserZdotdir: true` on the `.zprofile` chain too.

## Scripts

### 47. Low. The signing script deletes the spaces inside the keychain path

`Scripts/make-signing-identity.sh:18`, `tr -d ' "'`.
`security login-keychain` prints four leading spaces and a quoted path, and
the `tr` meant to strip those also removes every space inside the path. Fed
`"/Users/Shared Dev/Library/Keychains/login.keychain-db"` it gives
`/Users/SharedDev/...`. Line 62 passes that to `security import -k` outside
the `run` wrapper, so under `set -e` the script exits after openssl has made
the certificate, which the trap then deletes. `make-app.sh` finds no
`Multishell Dev` certificate and signs ad hoc, the state the script exists to
avoid. Narrow: a short name cannot hold a space, so only a relocated home or a
volume with a space in its name reaches it. Fix = strip only leading
whitespace and the surrounding quotes with `sed`.

## Performance

### 53. Perf. The status poll runs `git status` for missing projects' worktrees

`Sources/MultishellAppCore/Model/AppModel+Runtime.swift:85`.
`let fresh = await worktrees.statuses(of: workspace.worktrees)` polls every
worktree of every project every five seconds while frontmost, including the
persisted worktrees of `missingProjects`, whose directory is gone. `refresh`
returns before `replaceWorktrees` for a missing project
(AppModel+Projects.swift:97), so its worktrees stay in the store and are
polled, while the two sibling poll paths at AppModel+Merges.swift:22 and
AppModel+SharedSettings.swift:65 do filter them out.

For a worktree whose directory is gone, `Process.run()` throws before any
child exists (ProcessRunner.swift, the catch after `try process.run()`), so
the cost per missing worktree is a failed launch and two pipes made and
closed, not a git process. Three projects with 30 worktrees, one project on an
unmounted drive holding 8: 22 git processes plus 8 failed launches per tick,
at most 8 running together. Filtering `missingProjects` is safe and matches
the siblings. The finder's further suggestion, polling only visible or live
worktrees, would break `refreshProjectsWhoseBranchMoved` at lines 97-107,
which uses the fresh status of every worktree to notice a checkout in one
whose HEAD is not watched (worktrees.md:8); a collapsed project's checkout
would go unseen until expanded. TODO.md:25 already records the general polling
cost; the missing-project angle is new.

### 54. Perf. Every split-divider drag frame writes the workspace and re-arms autosave

`Apps/macOS/Sources/Multishell/Terminals/WeightedSplit.swift:60`.
`if updated != start { onWeightsChange(updated) }` runs on every drag frame
and reaches `model.setSplitWeights` (PaneTreeView.swift:42) or
`model.setGroupWeights` (TabGroupsView.swift:23), which write
`WorkspaceStore.workspace`, the one `@Observable` stored property, with no
equality guard. Every view that reads `model.workspace` re-evaluates per
frame: SidebarView with its per-project sort, every TabColumnView, DetailView.
The autosave observer re-arms per change (AppModel+Persistence.swift:14-33)
and writes pretty-printed sorted JSON atomically 300 ms after the last one.
Cheaper is to hold the live weights in `@State` during the drag, which
`dragStartWeights` already does for the start, and call `onWeightsChange` once
from `onDragEnded`.

Dragging for two seconds at the mouse-event rate, 60 per second or 120 on a
ProMotion display, issues about 120 workspace mutations: 120 sidebar body
evaluations, each sorting every worktree (with `localizedStandardCompare` per
comparison under alphabetical order, on ties otherwise) and scanning all
sessions per row, 120 tab-strip rebuilds, 120 `scheduleSave` allocations, then
one JSON write. Caveat for the remedy: `.onEnded` does not fire for a
cancelled gesture, so an interrupted drag would snap back rather than commit.

### 55. Perf. The sidebar scans every session four times per worktree per render

`Apps/macOS/Sources/Multishell/Sidebar/SidebarView.swift:239`.
`terminalCount: model.workspace.sessions(in: worktree.id).count` is one of
four linear scans of `workspace.sessions` per worktree per body evaluation:
this line, `model.state(ofWorktree:)` on the next, which calls `sessions(in:)`
again, and `isActive` inside `model.ordered(...)` at line 86, which does both
once more. `visibleProjects` at line 81 is computed twice per body, at lines
44 and 58. Line 217 `state(ofProject:)` adds a scan per worktree of each
collapsed project, and line 28 `agentSidebarCounts` one more over all
sessions. Cheaper is one `[Worktree.ID: [TerminalSession]]` grouping per body,
fed to `SessionStates.state(ofWorktree:sessions:)`, which already takes the
ids, and to `WorktreeOrder.sort`, which takes closures.

Forty worktrees and 60 live sessions is about 9,600 session comparisons plus a
40-element locale-aware sort per render. What triggers a render is narrower
than the finder claimed: every workspace write, yes; the five-second poll only
when a status changed (Runtime.swift:91); a prompt or bell only when it
changes a state, `noteActivity` writing one only when none is set and the tab
is unseen (SessionStates.swift:99) and `mutateStates` dropping a no-op.

### 56. Perf. Every watcher tick re-reads every project's records and re-arms every watch

`Sources/MultishellAppCore/Model/AppModel.swift:303`.
`await Self.offMain({ WorktreeRecords.read(commonDirectory: common) }) ==
known` runs for every project on every watcher tick, then `rearmWatcher()` at
line 310 spawns one `offMain` per project (line 319) doing `fileExists` plus
`contentsOfDirectory` plus `fileExists` per worktree
(WorktreeCoordinator.swift:82-89), and `watch()` stats every watched directory
on the main actor for staleness (DispatchDirectoryWatcher.swift:45 and 57).
The watcher knows which directory fired but `onChange` carries no URL
(Ports/DirectoryWatcher.swift:7). Cheaper is to pass the changed URL through
and re-read records only for the owning project, rearming only after a refresh
that changed the list.

Four projects, 40 worktrees, agents committing in several: each `git add` or
`commit` writes under `.git/worktrees/<name>/`, and the watcher fires once per
burst, 400 ms after the last event (DispatchDirectoryWatcher.swift:94), so
continuously only while git keeps writing. Each fire costs 12 detached tasks
(8 plus `refreshSharedSettingsIfChanged` per project on the equal path), about
120 small file reads and about 85 stats, for ticks that almost always compare
equal. The no-argument all-projects path must stay: `refreshAll` runs it on
return to the foreground with no URL. The protocol change also touches the
test fake in Apps/macOS/Tests/MultishellTests/ModelHarness.swift.
worktrees.md:9 records the design, not the cost.

### 57. Perf. Autosave encodes and writes the workspace on the main actor

`Sources/MultishellAppCore/Model/AppModel+Persistence.swift:37`.
`try store.save()` encodes the whole workspace as pretty-printed, sorted-keys
JSON and does an atomic write synchronously on the main actor (from the `Task
{ @MainActor }` at lines 28-31), 300 ms after any workspace change. Cheaper is
to copy the `Workspace` value, which is `Sendable`, and encode and write in a
detached utility task, keeping only the failure report on the main actor.

The finder called this the one disk write in the model that does not go
through `offMain`; it is not. Export's `write(to:)`
(AppModel+SharedSettings.swift:154), the Trash fallback (38), and
`HelperLink.refresh`, `ShellIntegration.refresh` and `DroppedFiles.sweep` in
`start()` are on the main actor too, as is the staleness stat in
`DispatchDirectoryWatcher.watch`. On a home directory on a network volume or a
stalled disk, every debounced save, each divider drag, tab move, rename or
selection change, blocks the UI for the write. `Data.write(options: .atomic)`
writes a temp file and renames without an fsync, so the stall is the volume's,
not a sync. Two conditions on the remedy: writes must be serialised, one in
flight and the latest wins, or two saves 300 ms apart on a slow volume can
land out of order; and `saveNow()` at quit (`shutDown`, from `willTerminate`)
must stay synchronous or the process exits before the write lands.
known-gaps.md:31 records the analogous case for reads only.

### 58. Perf. The Agents board does a linear worktree scan per session on every render

`Sources/MultishellAppCore/Model/AppModel+AgentBoard.swift:19`.
`let worktree = workspace.worktree(session.worktreeID)` is `worktrees.first {
$0.id == id }` (Workspace.swift:151), run once per session inside
`agentBoardCards`. `agentBoard` then sorts the cards once and filters them
once for membership plus once per lane, four lanes (AgentBoard.swift:9-13),
all recomputed on every `AgentBoardView` body, which the `now` tick re-runs
every 10 s and every change to `sessionStates`, `sessionTitles`, `statuses`,
`liveSessions`, `reportedAgents` or `workspace` re-runs at once. Cheaper is a
`[Worktree.ID: Worktree]` beside the existing `projectNames` and
`tabsBySession` maps, and one pass that sorts then buckets into lanes, keeping
`AgentBoardOrder.precedes` within each.

Sixty live sessions across 40 worktrees with the board open: up to 2,400
worktree comparisons, about half on average, plus a 60-card sort and five
filters per render. A title change in any pane triggers a render when the
title differs (Runtime.swift:145); a prompt only when it changes a state, as
in 55. AppModel+AgentBoard.swift:7 records the choice not to cache: a cache is
one more thing that can disagree with the sidebar. The dictionary is not a
cache across reads, so it does not cross that.

## Design

### 59. Design. The launch alert is identified by comparing its translated title

`Sources/MultishellAppCore/Model/AppModel+Agents.swift:42`.
The second git lookup identifies the launch alert by comparing display
strings, `presentedError?.title == PresentedError(GitUnavailable()).title`,
instead of the model knowing what it presented. The root fix is to keep the
missing-git state typed, a flag set where the alert is raised at
AppModel.swift:207 or a kind on `PresentedError`, and clear it when the user
dismisses.

No live collision exists: there is one catalogue, no other key has the value
"git not found", `GitUnavailable` is thrown only from `GitRunner.init`, and
`RemovalFailure` titles cannot be it since the coordinator already holds a
runner. Nor does a catalogue change break it, both sides calling
`t("error.git-not-found-title")` at runtime; only a code change on one side
would. What stands is that this is the one place in the model that reasons
about an alert by its text, and that a future error given the same wording
would be dismissed by the PATH landing. Deriving dismissal from `worktrees ==
nil` alone would not do: a load-error alert takes precedence at
AppModel.swift:204 and a later alert may have replaced the git one, so the
code must still know which alert is up.

### 60. Design. Per-worktree runtime state is pruned at five sites in four files

`Sources/MultishellAppCore/Model/AppModel+Projects.swift:121`.
Per-worktree runtime state is pruned piecemeal at whichever site last bit:
`forgetVanishedWorktrees()` (statuses, mergeStates, lastCommits, mergeChecks
at AppModel+Merges.swift:107-116) after `replaceWorktrees`,
`renamingWorktreeID` cleared on the next line, `statuses` filtered again
inside `refreshStatuses` at AppModel+Runtime.swift:88, `worktreeOperations`
handled by a late guard in `failStage` at AppModel+WorktreeCreation.swift:176,
`pendingRemoval` only on project removal at Projects.swift:65. The root fix is
one removed-worktree hook in the model, fed from the point the store discards
a worktree, that every keyed collection registers with.

The live consequence is real: `pendingRemoval` is set at
AppModel+WorktreeRemoval.swift:28 and nothing clears it when
`replaceWorktrees` discards the worktree, so the dialog stays up and Confirm
runs `worktrees.remove` on a path git no longer lists. The harm is smaller
than it sounds: the coordinator runs the pre-delete hook in the project
directory, skips the trash, prunes as a no-op, runs the post-delete hook and
deletes the branch if asked. Only a failing hook is visible, and then the
failed entry is keyed to a path with no row, which a worktree re-created there
inherits. `stageStoppers` and `worktreeSetups` do not leak; their stage's end
clears them. `WorkspaceStore.discardWorktree` is private and the store has no
callback, so `replaceWorktrees` and `removeProject` would need to return the
removed ids, or the model diff before and after. The two late-result guards,
in `refreshStatuses` and `failStage`, handle a result arriving after the
discard and must stay whatever else changes.

### 61. Design. `settle(group:vacating:)` relies on every caller precomputing the slot

`Sources/MultishellCore/Store/WorkspaceStore.swift:370`.
`settle(group:vacating:)` takes the vacated slot as an optional every caller
must precompute with `let vacated = slot(of: id)` before mutating, five call
sites at 208, 228, 258, 286 and 316, and defaults to `remaining.last` when
forgotten. The cheapest fix is to drop the `= nil` default so the slot is
mandatory; a `vacate(_:)` returning the source group and slot before the
mutation would suit all five, where a `takeOut` that also removes the tab
would not fit `moveTabToNewGroup` at 315, which retags in place.

A sixth mutator that removes a tab from a column and calls `settle(group:)`
with the default reintroduces what f84fed6 fixed: the column activates its
rightmost tab rather than the neighbour, per `remaining[min(slot ??
remaining.count - 1, remaining.count - 1)].id` at 383.
`Workspace+Repair.swift:91` also takes `last`, but by choice: its comment at
89-90 says nothing on disk records which tab the column showed, so there is no
vacated place to hand on. tabs-and-columns.md:38 records the behaviour, not
the shape.

### 62. Design. `SessionStates` keeps six parallel per-key collections

`Sources/MultishellAppCore/States/SessionStates.swift:150`.
`SessionStates` keeps six per-key collections (`states`, `pids`, `since`,
`notes`, `background`, `owedDone`, lines 14-27) and the lifecycle methods each
touch a different subset: `retain` all six (157-162), `clear` and
`processGone` four, `settling` two, `stampChanges` two. f84fed6 added
`background` and `owedDone` with four touch points apiece. The root fix is one
`[Key: Entry]` with a struct per key, so a prune is one dictionary operation.

The next per-key fact added to `report` but missed in one of `retain`,
`clear(_:)` or `processGone` leaks state for a dead key or resurrects an owed
Done for a re-used session id. `retain` alone is six filters. `stampChanges`
clears `notes` but not `background` or `owedDone` for a key whose state went
nil; bounded, since `report` cannot set Done while a count is held, but
`noteCommandFinished` can and `markSeen` then nils the state, leaving the
count until `retain`, `processGone` or the next idle or error report, which
delays the next turn's Done, the same class as 39. Two facts constrain the
struct: `since` deliberately outlives a nil state (line 184 stamps the
transition), and `clear(_:)` deliberately leaves `since` and `notes` for
`stampChanges`, so a clear is not a plain removal for every field.
agents.md:73 records that a stuck count costs the Done banner and nothing
else; TODO.md:7 asks for the count to track state.

### 63. Design. The shell-start precondition is spelled differently at three entry points

`Sources/MultishellAppCore/Model/AppModel+Editor.swift:35`.
`openInEditor` re-spells the shell-start precondition at its own call site,
`guard !isBusy(worktree.id), requireDirectory(of: worktree)`, and adds
`leaveAgentBoard()` by hand at 64, while `newTab`, `newShellTab`,
`splitActivePane` and `newAgentTab` go through `worktreeReadyForShell()` at
AppModel+Tabs.swift:24 and `moveTab(to:)` at 197 spells it a third way. The
root fix is one `readyForShell(_ worktree:)` taking an explicit worktree,
since `worktreeReadyForShell()` is bound to `worktreeInView` and
`openInEditor` is called from any row's context menu.

The comment at 33-34 admits the invariant is enforced per caller: "which every
other way of starting something there already refuses". No live path starts a
shell in a busy worktree today: the notification reveal and `openHeldBackTab`
both go through `select`, which checks `isBusy` before opening, and the
sidebar file drop starts no shell. The risk is the next entry point. Refusing
in `prepared` or the registry instead would not do: a prepare failure is
reported as an alert and the session closed, worse than a silent guard, and
the store cannot see `worktreeOperations`. That `openInEditor` leaves the
board rather than refusing is already in known-gaps.md.

### 64. Design. Which worktrees may be removed is decided twice with two spellings

`Apps/macOS/Sources/Multishell/Sidebar/WorktreeActions.swift:39`.
Which worktrees may be removed is decided in the view, `if
!worktree.isPrimary`, and in `WorktreeCoordinator.remove` at 193, `guard
!worktree.isPrimary, !worktree.isBare`, with a third spelling for another
purpose at WorktreeMergeState.swift:80. `requestRemoval(of:)` at
AppModel+WorktreeRemoval.swift:20 guards on `isBusy` but not on primary or
bare, and `PendingWorktreeRemoval.decide` has no guard. The root fix is one
`Worktree.isRemovable` in MultishellCore that the menu, `requestRemoval`,
`decide` and the coordinator all read.

The two agree only because the parser marks the bare entry primary
(`isPrimary: worktrees.isEmpty` at WorktreeListParser.swift:23). A saved state
whose `isPrimary` fell back to `false` with `isBare` true needs a hand-edited
file, `isPrimary` being encoded on every save. The board card is not a second
spelling; AgentCardActions.swift:18 embeds the same view. No keyboard shortcut
or command calls `requestRemoval` today, WorktreeActions.swift:42 being its
only caller, and if one were added the coordinator turns it into a
`NotAWorktree` alert rather than damage. worktrees.md:71 records why the
coordinator refuses on its own; the duplication is the cost of that.

## Simplification

### 65. Simplify. The three `moveTab` overloads repeat most of one body

`Sources/MultishellCore/Store/WorkspaceStore.swift:187`.
The three moveTab overloads (beside a target, to the end of a group, to
another worktree) each run slot(of:), remove(at:), retag groupID, insert or
append, settle(group:vacating:), then activate. One private
relocate(_:toGroup:insertingAt:) taking the resolved destination and index
would leave each public method as its own guard and arithmetic plus one call.

Lines 199-209, 223-229 and 244-260. The third copy calls setActiveTab plus
focusedGroupByWorktree where the first two call activateTab; read side by side
these are equivalent after the retag at 247-248, so the difference is not
behavioural, but a reader has to check. Not the whole body is shared: the
first overload settles and re-activates only when source differs from
destination (line 207), which is what a same-column reorder from shuffleTab
relies on, and computes a landing index rather than appending; the third
resolves a group that may not exist yet and retags the worktree.
moveTabToNewGroup at 296-319 is a fourth near-copy the helper would not reach,
since it retags in place. The saving is about twelve lines, not three bodies.
tabs-and-columns.md explains why a cross-column drop activates the moved tab,
which the helper must keep.

### 66. Simplify. `moveProjects` takes an `IndexSet` its only caller never needs

`Sources/MultishellCore/Store/WorkspaceStore.swift:68`.
moveProjects(from: IndexSet, to:) implements SwiftUI's general multi-index
move contract (shift count, descending removal loop, insert(contentsOf:)) but
its only caller, AppModel.moveProject at AppModel+Projects.swift:80, always
passes IndexSet(integer: from); a moveProject(at: Int, to: Int) doing one
remove(at:) and one insert does the same job.

Grep for moveProjects and IndexSet across Sources and Apps/macOS/Sources
returns only the definition and that call site. For a single index,
`destination - shift` equals `destination > from ? destination - 1 :
destination`, so the change is behaviour-preserving if the range guard at
lines 69-72 stays: PersistenceTests.swift:313 passes out-of-range values and
expects no change. Five test calls at PersistenceTests.swift:307-317 all use
IndexSet(integer:), and the test named for SwiftUI's contract would want
renaming. The multi-index path is unexercised.

### 67. Simplify. `apply(_ report:)` has two branches identical but for the key

`Sources/MultishellAppCore/Model/AppModel+SessionState.swift:27`.
apply(_ report:) has two branches, session-keyed and worktree-keyed, whose
tails are identical except for the key, the worktree id and how `seen` is
computed; resolving a (key, worktreeID, seen) triple in one guard and then
running a single mutateStates plus notifyIfNeeded halves the function.

The mutateStates closure and the notifyIfNeeded call appear twice, lines 40-47
and 55-62. Two things only the session branch does and which the merged form
must keep: the liveSessions.contains(id) guard at line 29 and the
reportedAgents write at 32-35. The fall-through case must still reach
updatePIDWatch() at line 65, which today runs on every path except the early
return at 29.

### 68. Simplify. `select`'s `byUser` flag is derivable from `openingFirstTab`

`Sources/MultishellAppCore/Model/AppModel+Worktrees.swift:11`.
select(_:openingFirstTab:byUser:) takes a byUser flag that is derivable from
the TabOpening already passed: the only two callers passing byUser: false,
AppModel+WorktreeCreation.swift:113 and :231, both pass .onCreate, and no
caller pairs .onCreate with byUser true. Computing `openingFirstTab !=
.onCreate` inside removes a pair that must stay in sync.

Checked at all five explicit call sites, including WorktreeActions.swift:26
and :31 which pass .never with byUser defaulted, and at every default-argument
site and test: the derived value equals the passed one everywhere. The flag is
load-bearing at line 231, where the create's defer has already cleared
worktreeCreationStep and byUser: false is what keeps
askAboutSharedHooksIfNeeded quiet (its guard at
AppModel+SharedSettings.swift:117 checks both newWorktreeRequest and
worktreeCreationStep); the derived value keeps it false. TabOpening.swift:3
already says a create is asked apart throughout. TabOpening has its own
`.byUser` case, so the Bool and the case share a name today.

### 69. Simplify. The assign-only-if-changed idiom is hand-written sixteen times

`Sources/MultishellAppCore/Model/AppModel+Merges.swift:107`.
The assign-only-if-changed idiom (`if x != y { x = y }`, or filter, compare
counts, then assign) is written by hand at sixteen sites across the AppModel
extensions: AppModel.swift:232 and :237, +Agents:67-68, +Merges:87, :97,
:101-102, :110, :112, :114, +Runtime:91, :112-114, :145, +SessionState:34,
:256-258. One generic helper such as `set<T: Equatable>(_ path:
ReferenceWritableKeyPath<AppModel, T>, _ value: T) -> Bool` would state the
observation-avoiding intent once.

The idiom exists to avoid spurious @Observable notifications, recorded in
merged-branch.md:75 and in comments at four sites (AppModel.swift:234,
+Merges:84 and :90, +SessionState:30). The bare sites are +Agents:67-68,
+Runtime:91, :112-114 and :145, +Merges:101-102 and :110-114. `mergeChecks` at
+Merges:115 is correctly unguarded, being @ObservationIgnored, but is
indistinguishable from an oversight. The helper must return whether it wrote,
since +SessionState:256 calls updateDockBadge only on change; the three
filter-then-count sites would compare whole dictionaries instead of counts.
One oddity for the owner: AppModel.swift:121 says installedAgentHooks is not
observed, yet +Agents:67-68 guards it anyway.

### 70. Simplify. Wrap-around neighbour arithmetic is written twice, in two modules

`Sources/MultishellAppCore/Model/AppModel+TabGroups.swift:27`.
The wrap-around neighbour arithmetic (find index, step = forward ? 1 : count -
1, index (i + step) % count, nil when count <= 1) is written twice, in
Workspace.neighbour(of:_:) at Workspace.swift:177-187 for tabs and in
AppModel.focusGroup(_ direction:) for columns, with the second's comment
pointing at the first as its reason; one `Array.neighbour(of:where:_
direction:)` extension in MultishellCore would serve both and let selectTab
and focusGroup read alike.

The two copies live in different modules and take different element types, so
a reader confirming that Cmd+] on tabs and Cmd+Option+] on columns wrap the
same way must trace both; a fix to one has to be mirrored by hand in the
other, and the cross-reference comment is the only thing tying them together.
TerminalTab.Placement lives in MultishellCore, so the extension is placeable
there. The only difference today is that Workspace returns nil where
focusGroup returns early, which the callers already handle.

## Reuse

### 71. Reuse. `helperReference` re-implements the home-prefix check

`Sources/MultishellCore/Agents/AgentHooks.swift:20`.
`AgentHooks.helperReference` re-implements the whole-component home-prefix
check that `String.abbreviatingHomeDirectory(home:)` in
Sources/MultishellAppCore/HomeAbbreviation.swift already does, substituting
`$HOME` for `~`. The helper sits in AppCore, which Core cannot import, so the
fix is to move it into MultishellCore with a `replacement:` parameter and call
it from both.

Both spell `home + "/"` and `dropFirst(home.count)` against
`FileManager.default.homeDirectoryForCurrentUser.path`. HomeAbbreviation
handles the `self == home` case and documents why `/Users/meg` is not `~g`;
AgentHooks omits the equality case, which is moot since `Paths.helperLink` is
under the config directory and never equals home. A fix such as tolerating a
symlinked home applied to HomeAbbreviation would leave the hook line written
to the agent's settings file on the old rule.
`WorktreeSettings.expandingTilde` at WorktreeSettings.swift:66 is the reverse
mapping, `~` to home, and does handle `~` alone; it is not a copy of this
check and would want its own function rather than a `replacement:` parameter.
The `$HOME` choice must survive the move: the helper path sits inside double
quotes in the hook line at AgentHooks.swift:29, where `~` would not expand.
AgentHooks.swift:17 records the `$HOME` reason; nothing under docs/ does.

### 72. Reuse. Five min/max chains re-implement `clamped(to:)`, which sits in the Mac layer

`Sources/MultishellAppCore/Terminals/TabStripLayout.swift:34`.
`min(max(share, floor), ceiling)` and four more min/max chains
(TabStripLayout.swift:94, Terminals/SplitMath.swift:27,
MultishellCore/Theme/RGB.swift:18, MultishellCore/Theme/Theme.swift:56)
re-implement `Comparable.clamped(to:)`, which exists only in
Apps/macOS/Sources/Multishell/Support/Comparable+Clamped.swift, internal, with
a single caller at App/RootView.swift:51. These are the only min/max chains in
the tree.

The helper is in the Mac app, so none of the five library sites can call it.
Moving the file into MultishellCore as public is stdlib-only and gives
identical results at all six sites, NaN included. One edge to know before
doing it: `lo...hi` traps when lo > hi, where the raw chain silently returns
hi. Every current site guarantees the order (TabStripLayout pre-orders floor
and ceiling at 16-17, SplitMath guards `pair >= minimum * 2` at 23-25, the
theme ranges are literals), so nothing changes today, but the "silently
returns hi" complaint becomes a precondition failure rather than being fixed.
TabStripLayout:94 clamps a Double then converts to Int.

### 73. Reuse. Ref-namespace prefixes are spelled outside `BranchRef`

`Sources/MultishellGitKit/WorktreeListParser.swift:50`.
`WorktreeListParser.shortBranchName` re-spells `"refs/heads/"` twice at lines
49-51, and `WorktreeService.remoteBranches` at WorktreeService.swift:119
declares `let prefix = "refs/remotes/"`, beside `BranchRef.localPrefix` and
`remotePrefix` at BranchRef.swift:36-37 and `shortName` at 43-47, which strips
either namespace. These are the only two literal copies outside BranchRef;
DefaultBranch.swift already goes through the constants.

Replacing the two literals with the constants is byte-identical. A static
`BranchRef.shortName(of:)` stripping both namespaces would change the parser
only for a `branch refs/remotes/...` record, which `git worktree list` does
not emit, a checkout of a remote ref being detached; and merged-branch.md:94
says the parsed branch is later re-qualified as `refs/heads/<branch>`, so a
remote short name landing there would be wrong. Keep the parser stripping
`localPrefix` only.

### 74. Reuse. Three is-under-directory checks use two algorithms

`Sources/MultishellAppCore/Terminals/FileDrop.swift:39`.
`FileDrop.path(of:relativeTo:)` implements an is-under-directory test by
string prefix, while `DroppedFiles.isTemporaryCopy` (DroppedFiles.swift:14-18)
and `WorktreeFiles.isInside` (MultishellGitKit/WorktreeFiles.swift:132-136)
each implement it by `pathComponents` prefix; there is no shared
`URL.isInside(_:)` or `URL.path(relativeTo:)`.

The `hasSuffix("/")` branch in FileDrop is dead for every base except `/`,
because `standardizedFileURL.path` drops trailing slashes except there. The
three differ in two policies, not one. Symlinks: WorktreeFiles resolves the
leaf and its caller pre-resolves the base (WorktreeFiles.swift:26-27), for the
security reason hooks.md:33 gives; FileDrop says at 35-36 it resolves nothing,
as the session recorded its own path, though `standardizedFileURL` does map
`/private/tmp` to `/tmp` on macOS, so it resolves one thing it did not ask
for. Inclusivity: WorktreeFiles counts the base itself as inside (`leaf.count
>= root.count`), FileDrop and DroppedFiles do not. On `/` the two algorithms
agree. A shared URL extension in MultishellCore is placeable and preserves
behaviour only if it takes both policies as parameters; the divergence is
intended, so the gain is that a containment fix lands in one place.

### 75. Reuse. Four on-disk JSON writers with diverging encoder options

`Sources/MultishellCore/Model/SharedProjectSettings.swift:133`.
`SharedProjectSettings.write`, `WorkspaceSnapshot`
(Store/WorkspaceSnapshot.swift:47) and `ThemeCatalog`
(Theme/ThemeCatalog.swift:44) each construct a `JSONEncoder` with
`[.prettyPrinted, .sortedKeys]`, while `HookSettingsFile.render`
(Agents/HookSettingsFile.swift:44-48) uses `JSONSerialization` with
`[.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]` and appends a
newline. The other two JSONEncoder sites, the socket line and the pasteboard,
are not on disk.

The four already diverge: workspace.json, `.multishell.json` and exported
themes escape `/` as `\/` in every path and hook script, agent settings files
do not. Probed: the default `.multishell.json` really carries
`"worktreeDirectory" : "..\/{project}-worktrees"`, which the user's teammates
see in every diff. ThemeCatalog.swift:48 also writes without `.atomic` where
the other two Codable writers use it. All four live in MultishellCore, so a
shared encoder factory is placeable. It is behaviour-neutral only if it keeps
`[.prettyPrinted, .sortedKeys]`: adding `.withoutEscapingSlashes` changes the
bytes of `.multishell.json`, and `SharedProjectSettings.digest` (lines 90 and
138) is the SHA-256 of those bytes that settings.md:37 keys hook trust on, so
a re-export would yield a new digest. Decide that separately. HookSettingsFile
round-trips `[String: Any]` and cannot share a JSONEncoder.

### 76. Reuse. The one-path-per-line grammar is parsed in two places

`Sources/MultishellAppCore/Detection/ShellDetection.swift:41`.
`ShellDetection.listed(in:)` (lines 39-45) parses `/etc/shells` by splitting
on newlines, trimming, and dropping blanks and `#` comments, which is exactly
the first three steps of `WorktreeFiles.paths(in:)`
(MultishellGitKit/WorktreeFiles.swift:10-17). Extract a
`LineList.entries(in:)` into MultishellCore, which both packages import, and
call it from both, with WorktreeFiles adding its de-dup and ShellDetection its
executable filter on top.

They already differ in one rule: `WorktreeFiles.paths` de-duplicates through a
Set and `ShellDetection.listed` does not, harmless only because the caller at
line 30 wraps the result in a Set. A change to the comment rule, such as
allowing a trailing `# comment` after a path, gets made where the bug was
reported and not in the other. CRLF is not an example: `Character.isNewline`
is true for the `\r\n` grapheme, so both already split such a file cleanly.
`WorktreeService.localBranches` at WorktreeService.swift:107 is not a third
copy: it drops blanks but not `#` lines, and `#` is legal at the start of a
branch name, so folding it in would change behaviour. hooks.md:24 documents
the list grammar; nothing says why `/etc/shells` is parsed separately.

## Style

### 77. Style. A six-line doc comment in `UnixSocketServer`

`Sources/MultishellProcess/UnixSocketServer.swift:114`.
AGENTS.md rule "No code comments should exceed two lines. Where more detail is
needed, add to docs/design/ or docs/develop/ files and refer to them in the
comment." is broken by a six-line doc comment.

Lines 114-119: "/// Takes the claim, or refuses to start. A running instance
whose accept" / "/// backlog is full refuses a connect exactly as a dead one's
socket does," / "/// so the probe alone would unlink a live socket; the claim
cannot." / "///" / "/// An `fcntl` record lock rather than `flock`: a child
forked while an" / "/// `flock` is held keeps it until it execs, and this
process spawns freely." Six comment lines on one declaration; the
fcntl-versus-flock reasoning belongs in docs/design/ with a one-line pointer.
The same file has a three-line `//` comment at lines 98-100 ("// After the
socket file has gone, so a launch that takes the claim in ... answering on its
way out.").

### 78. Style. A six-line doc comment on `GitRefName`

`Sources/MultishellGitKit/GitRefName.swift:32`.
AGENTS.md rule "No code comments should exceed two lines" is broken by a
six-line doc comment on `GitRefName`.

Lines 32-37: "/// Whether git would take a name as a branch. `git
check-ref-format" / "/// --branch` answers this, but the sheet asks on every
keystroke and a" / "/// process per keystroke is not worth it, so the rules
are here." / "///" / "/// The rules are `git-check-ref-format(1)`'s, less the
ones about slashes" / "/// that only apply to a full refname." The
why-not-shell-out half is already in docs/design/worktrees.md:80, so only the
pointer is missing; the second half, the rules less the full-refname slash
rules, is not written down anywhere else.

### 79. Style. `GitRefName.swift` holds an unrelated error type beside its own

`Sources/MultishellGitKit/GitRefName.swift:6`.
docs/develop/layout.md rule "One type per file, named for the type;
`Type+Concern.swift` for an extension, `*Failures.swift` for a group of error
types" is broken: the file named GitRefName declares two error types before
the enum, and one of them has nothing to do with it.

Line 6 "public struct NotAWorktree: LocalizedError {" and line 20 "public
struct InvalidBranchName: LocalizedError {" sit in GitRefName.swift alongside
line 38 "public enum GitRefName {". `InvalidBranchName` is about ref-name
validation and belongs nearby; `NotAWorktree` guards worktree removal and
points at docs/design/worktrees.md. Neither is thrown in this file: both come
from WorktreeCoordinator.swift, lines 139 and 194. The same shape, a named
type with error structs beside it, is in eight files: this one,
Store/WorkspaceSnapshot.swift (lines 53 and 69), UnixSocketAddress.swift,
ShellCommand.swift, GitRunner.swift, WorktreeHooks.swift, Helper.swift and
MacPlatform.swift. Across the tree 33 files hold more than one top-level type,
29 outside the `*Failures.swift` carve-out, so this is a pattern rather than a
one-off, and the fix may be a line in layout.md as much as a move.

### 80. Style. A four-line doc comment on an `EditorLaunch` case

`Sources/MultishellAppCore/Launch/EditorLaunch.swift:10`.
AGENTS.md rule "No code comments should exceed two lines" is broken by a
four-line doc comment on an enum case.

Lines 10-13: "/// Run the editor's command line shim through the login shell,
in the" / "/// background: the application it starts is what the user sees.
Nothing" / "/// is captured and nothing times it out, a shim that stays up for
as" / "/// long as the file is open not being something to cut short." The
last two lines restate the reasoning already carried by the `launch(_:)` doc
comment at Sources/MultishellProcess/ShellCommand.swift lines 24-27, itself
four lines and over the limit.

### 81. Style. `TabDrops.swift` declares four types and is named for none

`Apps/macOS/Sources/Multishell/Terminals/TabDrops.swift:16`.
docs/develop/layout.md rule "One type per file, named for the type" is broken:
TabDrops.swift declares four top-level types and none is named TabDrops.

Line 16 "struct TabDropDelegate: DropDelegate {", line 67 "struct
TabStripDropDelegate: DropDelegate {", line 89 "struct TabAreaDropDelegate:
DropDelegate {", line 128 "struct TabBandDropDelegate: DropDelegate {". They
are not error types, so the `*Failures.swift` exemption does not apply, and
layout.md states no other. The file's own header at lines 5-6 records the
grouping as deliberate: "One file rather than four: each is a few lines of the
same shape, and each answers the drag before it moves." So the choice is made,
but in the file rather than in the rule; either layout.md gains the exception
or the file splits. WorktreeSteps.swift has the same shape with two enums.

### 82. Style. MARK section banners across four packages

`Sources/MultishellAppCore/Model/AppModel.swift:15`.
docs/develop/layout.md "Comments only for why, non-local consequence, or a
fact the code cannot show" is broken by MARK section banners. The "section
banners" prohibition the finder also cited is in the user's global
reduce-comments skill, not in the repo.

Line 15 "  // MARK: - Dependencies", line 31 "  // MARK: - Waiting on the
user", line 57 "  // MARK: - The Agents board". A banner names a section and
carries no why, consequence, or hidden fact. There are 61 MARK lines in 27
files: MultishellAppCore 37 (AppModel.swift 9, the AppModel+*.swift extensions
24, SessionStates.swift 4), MultishellCore 20 (WorkspaceStore.swift 10, Agents
6, Model 4), MultishellCLI 3, the Mac app 1. Seventeen of the twenty
AppModel+*.swift files open with a single banner that restates the file name,
AppModel+Tabs.swift:4 "// MARK: - Tabs" for one; layout.md says
`Type+Concern.swift` is the grouping mechanism, which those files already are.
A repo-wide convention rather than a one-off, and nothing under docs/ names it
as accepted, so the fix is either to state it in layout.md or to take the
banners out.

## Checked and clear

Not bugs, recorded so nobody spends the time again.

- The SwiftTerm reap loop cannot exit early on EINTR. `waitpid` with `WNOHANG`
  never sleeps, so nothing interrupts it, and no signal handler is installed
  anywhere in the app or in SwiftTerm. A `-1` there is ECHILD after
  SwiftTerm's own monitor reaped first, and ending the loop is right.
- A create failing synchronously at the container directory does not leave
  `worktreeCreationStep` stuck. `WorktreeCoordinator.add` is a nonisolated
  async method on a struct, so it runs off the main executor and `onStep`'s
  main-actor Task is enqueued before the throw's return hop. Proven with a
  scratch program of the same shape over 200 runs. The same program compiled
  with `NonisolatedNonsendingByDefault` sticks on the first run, so when that
  becomes the default the closure wants to check `creationStopper === stopper`
  before writing.
- A tab drag let go where nothing takes it is already recorded in
  known-gaps.md. Escape mid-drag is the same abandoned drag. Whether an
  undelivered `dropExited` leaves a tab translucent has not been watched.