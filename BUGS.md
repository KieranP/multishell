# Bugs

Open findings, numbered from the whole-repo review of 2026-09-13; numbers are
never reused and a fixed entry is taken out rather than kept. The whole-repo
review of 2026-09-16, one reader per layer over every file in full and a second
over each High and Medium, numbered 88 to 122; every one of those was fixed by
2026-09-17. The review of 2026-09-19, four readers over the whole repo at the
MVP mark, one each for defects, design, cost and project health, numbered 123
to 188. "Unproven" is behaviour nobody has shown, kept because the fix is cheap
or the cost is high.

| #   | Effect   | What                                                                             |
| --- | -------- | -------------------------------------------------------------------------------- |
| 131 | Medium   | One commit on the trunk re-asks every branch's merge verdict                     |
| 132 | Medium   | `git status` runs for worktrees that are collapsed or filtered out of sight      |
| 133 | Medium   | A drag rebuilds the sidebar or the tab strip at pointer rate                     |
| 162 | Medium   | The bundle is signed without a hardened runtime, a timestamp or entitlements     |
| 175 | Medium   | Six tests sleep a fixed interval and then assert a count did not grow            |
| 176 | Medium   | Two suites read the process-wide descriptor count without `.serialized`          |
| 183 | Medium   | The two sidebar header buttons carry no accessibility label                      |
| 127 | Low      | A subagent roster with no matching stop grows without bound                      |
| 128 | Low      | The 500-character cap guards `message` and none of the other reported strings    |
| 130 | Low      | `forget` reports a prune's success as its own, then the branch is deleted anyway |
| 134 | Low      | Theme colours are parsed out of hex on every access                              |
| 135 | Low      | Rows hold fresh closures, so SwiftUI can never skip one                          |
| 136 | Low      | The branch scan spawns a git process per project per tick, serially              |
| 138 | Low      | The agent board is rebuilt whole on every body evaluation                        |
| 139 | Low      | The whole tab strip sits inside a `GeometryReader`                               |
| 140 | Low      | The sidebar filter folds every worktree name per keystroke                       |
| 141 | Low      | Row order and block height are recomputed on every sidebar rebuild               |
| 143 | Low      | The dropped-file sweep runs synchronously on the main actor at launch            |
| 144 | Low      | A drag over a pane re-reads the pasteboard on every mouse move                   |
| 145 | Low      | A view measures the drop indicator's hit split, so nothing tests it              |
| 146 | Low      | `claimedPaths` is read by seven tests and nothing in production                  |
| 147 | Low      | `warmWorktrees` is absent from the one place per-worktree state is dropped       |
| 148 | Low      | `AppModel+Runtime` is four unrelated concerns under a name that says none        |
| 149 | Low      | Agent, shell and editor detection sits in a file named Agents                    |
| 150 | Low      | `WorkspaceStore` writes the same index lookup sixteen times                      |
| 151 | Low      | The two translation test files duplicate their scanner and have drifted          |
| 152 | Low      | The window header chrome is written out twice                                    |
| 153 | Low      | The centred-caption styling is written out twice                                 |
| 154 | Low      | Sixty-eight `public` declarations are named by no other target                   |
| 155 | Low      | Catalogue keys are split by a stray `s`, which breaks the sort into groups       |
| 156 | Low      | A general SVG path parser lives in the Agents view folder                        |
| 157 | Low      | Three unrelated extensions share one file in a folder that does no detection     |
| 164 | Low      | CI pins the runner image but selects no Xcode, so it builds under the default    |
| 165 | Low      | CI has no concurrency cancellation and no job timeouts                           |
| 166 | Low      | CI runs neither the Markdown formatter nor a shell linter                        |
| 167 | Low      | COMPAT.md blames Apple silicon on libghostty, which ships both slices            |
| 168 | Low      | The Xcode floor is stated three different ways in three files                    |
| 171 | Low      | The split-button thresholds in two docs are three points out                     |
| 172 | Low      | known-gaps.md names a test suite that does not exist                             |
| 173 | Low      | tests.md names a file as though it were a suite                                  |
| 174 | Low      | AGENTS.md ends a rule with a bare path that resolves from nowhere                |
| 177 | Low      | Two watcher tests sample the descriptor count over a fifth of a second           |
| 178 | Low      | A main-actor AppKit suite spins the run loop without `.serialized`               |
| 179 | Low      | A misspelled SF Symbol passes its test and draws nothing                         |
| 180 | Low      | A parser test asserts two counts are not negative, which cannot fail             |
| 181 | Low      | Three tests skip silently when node or python3 is absent                         |
| 182 | Low      | Nothing tests the four appearance setters, each of which writes and persists     |
| 184 | Low      | No shortcut moves focus between the panes of one tab                             |
| 187 | Low      | A public repository with no SECURITY.md, CONTRIBUTING.md or issue template       |
| 188 | Low      | The short version string is a date and a hash, not a version                     |
| 86  | Low      | An OpenCode server reused by a second pane lands the dot on the first pane's tab |
| 87  | Low      | CI never runs `make-app.sh`, so bundling and signing can break with it green     |
| 129 | Unproven | A recycled pid between the hangup and the kill sends SIGKILL to a stranger       |
| 137 | Unproven | A `cwd`-only report resolves every worktree's symlinks on the main actor         |
| 142 | Unproven | The directory watcher stats every watched directory on the main actor            |
| 85  | Unproven | Three of the four agents' hook files have never been watched moving a dot        |

## Settings and trust

## App launch

## Agents and session state

### 85. Unproven. Three of the four agents' hook files have never been watched moving a dot

`Sources/MultishellCore/Integrations/Agents/AgentHooks.swift`. The four hook
files are written from each agent's documented shape, and only Claude Code's has
been watched moving a dot in a real session. Run each agent once: check its
events fire, that the pid reported is the agent and not a wrapper outliving the
hook, and that Codex's `/hooks` trust holds. The OpenCode plugin
(OpenCodePlugin.swift) has been driven against a stub helper; unproven is that
OpenCode loads a plugin exporting a function rather than a default
`{ id, setup }`, its loader having two generations of that contract, and that
the two permission events arrive under the names the plugin now listens for,
with the title where it reads it.

### 86. Low. An OpenCode server reused by a second pane lands the dot on the first pane's tab

`Sources/MultishellCore/Integrations/Agents/OpenCodePlugin.swift:31`. The plugin
spawns the helper from the OpenCode server's process, and the helper reads
`MULTISHELL_SESSION` from its environment (Helper.swift:13). An OpenCode server
started from one pane and reused by another therefore reports that first pane's
session, so the dot lands on the wrong tab. Only the plugin has this: every
other agent's hook runs in the session's own process.

### 127. Low. A subagent roster with no matching stop grows without bound

`Sources/MultishellAppCore/States/SessionStates+Entry.swift:62`. `keep(_:)`
appends a `Subagent` for every unseen id, and only `settleTurn()` empties the
roster, on a new turn, on idle or error, on a finished command, or when the pid
goes. An agent that emits `SubagentStart` with fresh ids, never a matching
`SubagentStop` and never a `UserPromptSubmit` grows `entry.workers` for as long
as it runs, and `SubagentList` draws a row for each. The
`.done where !entry.workers.isEmpty` arm of `settlingOwn` also holds the agent's
Done, so the tab never shows it finished.

### 128. Low. The 500-character cap guards `message` and none of the other reported strings

`Sources/MultishellCore/Sessions/SessionStateReport.swift:86`. `message` is
capped both in and out, with the reasoning at line 93 that any process of the
user's may write a line so the cap is the reader's rule. `subagent.type`, which
`SubagentList.swift:30` draws verbatim, along with `subagent.id`, `agent` and
`cwd`, carry no cap. Any local process writes one line of about 60 KB, under the
64 KB `UnixSocketServer.maximumLineLength`, with a 60 KB `subagent.type`; the
string is kept in the roster and laid out by SwiftUI on every render of the pane
row and the board card.

## Worktrees and git

### 129. Unproven. A recycled pid between the hangup and the kill sends SIGKILL to a stranger

`Sources/MultishellProcess/ProcessStopper.swift:77`. After `kill(-pid, SIGHUP)`,
a block three seconds later probes with `kill(-pid, 0)` and then sends
`kill(-pid, SIGKILL)`, with nothing checking the surviving group is still the
child's. If the hook's group exits at once and the kernel recycles the pid onto
a new group leader of the same user within `killGrace`, the kill lands on an
unrelated group. The comment there says an empty group answers ESRCH so what
answers is ours, which is the assumption pid recycling breaks. Unlikely on a
lightly loaded machine and nobody has seen it.

### 130. Low. `forget` reports a prune's success as its own, then the branch is deleted anyway

`Sources/MultishellGitKit/Worktrees/WorktreeService.swift`, in `forget`. The
catch falls back to `git worktree prune` and reports prune's exit as the result
of forget, whether or not the target record went. `WorktreeCoordinator.remove`
then runs the post-delete hook and `git branch -d`. If
`worktree remove --force --force <path>` fails for a reason prune does not
address, prune exits 0 having removed nothing, the app says the removal worked,
the branch is deleted, git still lists the worktree, and the next refresh brings
the row back with its branch gone.

## Performance

### 131. Medium. One commit on the trunk re-asks every branch's merge verdict

`Sources/MultishellAppCore/Model/AppModel+Merges.swift:64`, memo key at
line 136. `MergeCheck` holds `baseTip`, so a single commit on the trunk, or a
fetch moving `origin/main`, invalidates the memo for every worktree at once.
Each one then runs `verdict` (WorktreeCoordinator+Merges.swift:53): `git cherry`
for an unmerged branch, plus `rev-list` and two `diff --name-only` where the
upstream is gone, or `log -g` where it is merged. `git cherry` computes a patch
id per commit between base and branch. Any `git pull` on main with 30 worktrees
is 90 to 120 git processes in one tick, eight at a time, with the most expensive
read in the app inside them. Pace the re-verdict the way `StatusPollPace` paces
status, or key the memo on the branch tip and the merge-base so an unrelated
trunk commit does not invalidate it. Reasoned statically; nobody has timed
`git cherry` on a repository large enough to matter.

### 132. Medium. `git status` runs for worktrees that are collapsed or filtered out of sight

`Sources/MultishellAppCore/Model/AppModel+Runtime.swift:131`. The filter is
`isUnderConstruction`, `missingProjects` and `isDue`, and nothing asks whether
the project is expanded or the row survived the sidebar filter. `statuses` is
read by one view (SidebarView.swift:216), the board and the removal dialog. A
dirty worktree costs three git calls plus file reads (WorktreeService.swift:71).
One `git --no-optional-locks status --porcelain=v1 --branch` measures 14 ms on
this repository, so 50 worktrees is about 700 ms of git per five-second tick,
roughly 14 percent of a core held while the app is frontmost, most of it drawing
badges nobody is looking at. Pass the visible worktree set into
`refreshStatuses` and read the rest on expand.

### 133. Medium. A drag rebuilds the sidebar or the tab strip at pointer rate

`Apps/macOS/Sources/Multishell/Sidebar/ProjectDropDelegate.swift:28`, and
`Terminals/TabDrops.swift:56`, `:110`, `:131`. `dropUpdated` and `enter` assign
the same value on every call, about 60 a second for the length of the drag. The
sidebar one writes `SidebarView.dropTarget`, which re-runs the whole body:
`SidebarFilter.apply`, `model.ordered` per project, `blockHeight` per project
and every row. The tab ones write `model.tabDrag`, read by `TabColumnView.body`
and every `TabButton.body`. `TabDragState` is already `Equatable`, so guarding
each of the four with a comparison costs nothing. Bites from about 20 sidebar
rows or six tabs.

### 134. Low. Theme colours are parsed out of hex on every access

`Sources/MultishellCore/Theme/HexColor.swift:46` and
`Apps/macOS/Sources/Multishell/Support/Theme+SwiftUI.swift:30`. `Theme` keeps
hex strings. `backgroundRGB` and `foregroundRGB` parse on each access and
`ansiRGB` parses all sixteen and allocates an array, so
`theme.color(for: state)` costs sixteen parses to use one. `WorktreeRow` calls
`color(for:)` once, indexes `ansiRGB` twice and pulls in `ChangeCounts` for
three more. One parse measures 238 ns in a release build, the
`trimmingCharacters` allocation dominating, so a row is about 96 parses at 23 µs
and a 40-row sidebar render is about 1 ms spent turning constants into colours.
Parse once in `Theme.init` and keep the `RGB` beside the hex.

### 135. Low. Rows hold fresh closures, so SwiftUI can never skip one

`Apps/macOS/Sources/Multishell/Sidebar/WorktreeRow.swift:26`,
`ProjectRow.swift:20` and `AgentsRow.swift:12`. Each row stores freshly
allocated closures, which SwiftUI's structural comparison cannot match, so a
child body always re-runs when its parent does, and on every one of those it
builds `.help` strings and an accessibility label that are usually never read.
`.contextMenu` takes a non-escaping closure, so its content is built when the
modifier is applied rather than when the menu is opened: SidebarView.swift:197
with :252 is eight lookups per project per rebuild, TabButton.swift:125 with
:173 is six per tab. An accessibility label measures 5.5 µs and eight
`String(format:)` calls 12 µs, so about 10 to 15 µs a row, half a millisecond
per sidebar rebuild at 40 rows and 2.5 ms at 200. Give the rows an `==` that
ignores the closures and apply `.equatable()`, or pass the model and an id
instead.

### 136. Low. The branch scan spawns a git process per project per tick, serially

`Sources/MultishellAppCore/Model/AppModel+Merges.swift:19`. `refreshMergeStates`
loops the projects with an `await` inside, and each runs `git for-each-ref` over
`refs/heads` and `refs/remotes` unconditionally; the `MergeCheck` memo
suppresses the follow-up queries but not the scan. Refs are not watched so it
has to poll, which worktrees.md records, but the loop is serial and unpaced. Ten
projects is ten spawns every five seconds, about 200 ms of the tick. Run the
projects in a task group and pace the scan per project.

### 137. Unproven. A `cwd`-only report resolves every worktree's symlinks on the main actor

`Sources/MultishellAppCore/Model/AppModel+SessionState.swift:112`.
`worktree(atPath:)` calls `resolvingSymlinksInPath()` on every worktree in the
workspace, a `realpath` chain each, plus one for the reported path, and it runs
on the main actor for every socket report carrying no session id, which is the
hooks of an agent started outside a Multishell tab. With 50 worktrees that is 51
chains per report and an agent turn sends several; on a network-mounted worktree
each can block. Resolve each path once when `replaceWorktrees` stores it. Not
instrumented.

### 138. Low. The agent board is rebuilt whole on every body evaluation

`Apps/macOS/Sources/Multishell/Agents/AgentBoardView.swift:21` into
`Sources/MultishellAppCore/Model/AppModel+AgentBoard.swift:7`. The body builds
three dictionaries over all projects, worktrees and tabs, then a card per live
session with title, status, subagent list and occupant name, then sorts and
buckets. It re-evaluates on the ten-second tick and on any change to
`workspace`, `statuses`, `sessionStates`, `liveSessions`, `reportedAgents` or
`sessionTitles`, so a title change in one pane rebuilds every card. The comment
at line 14 already records that the body runs several times a second. Noticeable
from about 30 live panes. Move the tick into a child view and hold the board in
a stored property the model invalidates.

### 139. Low. The whole tab strip sits inside a `GeometryReader`

`Apps/macOS/Sources/Multishell/Terminals/TabBar.swift:44`. `tabViews` is inside
the reader, so every resize frame of the window or of a column divider rebuilds
every `TabButton`, each calling `model.state(of:)`, `model.title(of:)` and
`model.agentID(of:)` and building an accessibility label and a context menu.
Read the width in the reader and hand `layout` to a child whose body can be
skipped when it has not changed. Bites from about eight tabs per column.

### 140. Low. The sidebar filter folds every worktree name per keystroke

`Sources/MultishellAppCore/Worktrees/SidebarFilter.swift:30`, called from
`SidebarView.swift:97` inside `body`. `foldedContains` is `range(of:options:)`
with case and diacritic folding (FoldedMatch.swift:8), up to twice per worktree,
and it drags the full row rebuild behind it. Measured 0.53 ms for ten projects
of 200 worktrees, 0.05 ms at 40. Matters past about 300 worktrees, or sooner
because it is on the keystroke path. Fold the names once into a side table when
the workspace changes.

### 141. Low. Row order and block height are recomputed on every sidebar rebuild

`Apps/macOS/Sources/Multishell/Sidebar/SidebarView.swift:102` and `:166`.
`model.ordered` sorts with comparators that call `workspace.displayName` and
`isActive` per comparison and use `localizedStandardCompare`, and
`worktreeOrder(for:)` scans for the project and reads `effectiveSettings` per
project. `blockHeight` additionally scans all tabs once per project. None is
cached, so all of it runs on every invalidation from 133 and from a status or
session write, not only when the list changes. Reasoned statically.

### 142. Unproven. The directory watcher stats every watched directory on the main actor

`Sources/MultishellAppCore/Ports/DispatchDirectoryWatcher.swift:46` and `:57`.
`watch(_:)` stats every currently watched directory on the main actor and
`rearmWatcher` calls it after every refresh. Microseconds locally, but a
worktree on a stalled mount blocks the window. Do the staleness check off the
main actor, or only for the directories the tick named.

### 143. Low. The dropped-file sweep runs synchronously on the main actor at launch

`Sources/MultishellAppCore/Model/AppModel.swift:297`. `DroppedFiles.sweep()`
runs synchronously on the main actor inside `start()`, and each expired drop is
a recursive `removeItem`. Wrap it in `Self.offMain`. `host.claimSharedFiles()`
nine lines above is the same shape: a recursive `removeItem` of the generated
config directory, on the main actor, and it must stay ahead of the first
controller, so moving it off needs an await rather than a detached task.

### 144. Low. A drag over a pane re-reads the pasteboard on every mouse move

`Apps/macOS/Sources/Multishell/Terminals/SurfaceView.swift:113` and `:156`.
`draggingUpdated` re-reads the pasteboard, both `readObjects` and
`PromisedDrop.receivers`, on every mouse move over a pane. Re-asking the
receivers is deliberate, because the shell can exit mid-drag; re-reading the
pasteboard is not. Cache the file URLs against the `draggingSequenceNumber`.

## Code design

### 145. Low. A view measures the drop indicator's hit split, so nothing tests it

`Apps/macOS/Sources/Multishell/Sidebar/SidebarView.swift:166`.
`blockHeight(of:metrics:)` does arithmetic over row heights, pane counts and
rename state inside a view, and layout.md says views measure nothing and are
untested. A wrong answer here is a user-visible bug with no test. Extract it
beside `UIMetrics` in `Apps/macOS/Sources/Multishell/Support/`, where it stays
because it names a Mac measurement, and cover it.

### 146. Low. `claimedPaths` is read by seven tests and nothing in production

`Sources/MultishellAppCore/Worktrees/WorktreeWorkInFlight.swift:88`. Delete it
and have the tests assert through `isClaimed(_:)`.

### 147. Low. `warmWorktrees` is absent from the one place per-worktree state is dropped

`Sources/MultishellAppCore/Model/AppModel.swift:108`. It is keyed by
`Worktree.ID` and `forgetWorktrees` (AppModel+Runtime.swift:88), which adding.md
names as the single place this state is dropped, does not touch it. The comment
says it never shrinks and gives no reason. Either add it there or write the
reason into worktrees.md.

### 148. Low. `AppModel+Runtime` is four unrelated concerns under a name that says none

`Sources/MultishellAppCore/Model/AppModel+Runtime.swift`, 229 lines: session
reconcile and error reporting at 5 to 64, the `offMain`, `setIfChanged` and
`forgetWorktrees` utilities at 66 to 107, status polling at 109 to 188, and
activity and title notes at 190 to 229. Split into `AppModel+Reconcile`,
`AppModel+StatusPolling` and `AppModel+Activity`, and move the two utilities to
`Support/`.

### 149. Low. Agent, shell and editor detection sits in a file named Agents

`Sources/MultishellAppCore/Model/AppModel+Agents.swift:9`.
`refreshLoginEnvironment` captures the login shell and then detects agents,
shells and editors. Move lines 9 to 49 into `AppModel+Detection.swift`; the rest
of the file is named correctly.

### 150. Low. `WorkspaceStore` writes the same index lookup sixteen times

`Sources/MultishellCore/Store/WorkspaceStore.swift`, at lines 104, 196, 206,
207, 224, 238, 255, 273, 306, 307, 363, 379, 409, 425, 437 and 453, twelve of
them the identical `workspace.tabs.firstIndex(where: { $0.id == id })`.
`Workspace` has value lookups (Workspace.swift:150) and no index ones. Add
`tabIndex(_:)` and `groupIndex(_:)` and collapse all sixteen. The file's 580
lines are justified and documented, because `private(set) var workspace` means
every writer shares it, but state-and-store.md should say that this file only
grows.

### 151. Low. The two translation test files duplicate their scanner and have drifted

`Tests/MultishellCoreTests/Text/TranslationTests.swift` (221 lines) and
`Apps/macOS/Tests/MultishellTests/Text/TranslationTests.swift` (302). About 100
lines of scanning machinery, `callSites`, `arguments`, `placeholders`,
`catalogue` and `swiftFiles`, exist in both, and they have already drifted:
`aCountedPhraseReadsAsSingularAndPlural` and `aKeyWithNoEntryAnswersWithItself`
have no app counterpart. The package split forces the duplication. Equalise the
check lists and record the pairing in tests.md.

### 152. Low. The window header chrome is written out twice

`Apps/macOS/Sources/Multishell/Terminals/DetailView.swift:81` and
`Agents/AgentBoardHeader.swift:25` apply the same five modifiers to the same
window header. Make it one `View` extension so it cannot drift.

### 153. Low. The centred-caption styling is written out twice

`Apps/macOS/Sources/Multishell/Terminals/WorktreeOperationView.swift:28` and
`EmptyStateView.swift:24`.

### 154. Low. Sixty-eight `public` declarations are named by no other target

Many are nested types reached through a public signature and genuinely need it.
These are confinable: `Sources/MultishellGitKit/GitRunner.swift:11` and
`Worktrees/WorktreeService.swift:6`, public only to serve inits that only
`@testable` tests call;
`Sources/MultishellCore/Integrations/Shells/ShellStateHooks.swift:5`, `:13` and
`:67`, called from `ShellIntegration.swift` in the same module;
`Sources/MultishellCore/Store/FileDigest.swift:5`, called only from
`SharedProjectSettings.swift`;
`Sources/MultishellCore/Store/Workspace+Repair.swift:6`;
`Integrations/Agents/AgentHooks.swift:54`, where `claude` is public while
`codex`, `gemini`, `copilot` and `openCode` beside it are internal and used
identically, along with `helperReference` at :19 and `AgentHookEvent.swift:5`;
and `Sources/MultishellAppCore/Worktrees/WorktreeWorkInFlight.swift`, where nine
members are public and five internal in one 89-line file nothing outside the
module names, with `AppModel.workInFlight` (AppModel.swift:86),
`StatusReadLog.invalidate` (:39), `WorktreeOperations.advance` (:35) and the six
mutating funcs at `SessionStates.swift:206` the same pattern.

### 155. Low. Catalogue keys are split by a stray `s`, which breaks the sort into groups

Fourteen keys under `action.` and ten under `actions.`, so `action.remove` sorts
away from `actions.remove-worktree` and `action.refresh` away from
`actions.fetch`. Same for `notification.` against `notifications.`, and
`worktree.not-removable` alone against `worktrees.`. translation.md says the
catalogue is sorted by key so that it groups by part of the app, which this
defeats. Pick one spelling per group.

### 156. Low. A general SVG path parser lives in the Agents view folder

`Apps/macOS/Sources/Multishell/Agents/SVGPathParser.swift`, 95 lines. layout.md
gives view folders to the part of the window they draw and this draws none. Move
it to `Support/`.

### 157. Low. Three unrelated extensions share one file in a folder that does no detection

`Sources/MultishellAppCore/Detection/DisplayNames.swift` extends
`AgentCatalogue`, `EditorCatalogue` and `ShellCatalogue`, in a folder named
Detection while detecting nothing. The style rule is `Type+Concern.swift` per
extension, so this is three files named `+DisplayName`.

## 158. Low. Twelve comments in shipping source exceed two lines

`SessionStates+Entry.swift:96` at five lines, `:128` at four and `:46` at three;
`WorktreeHooks.swift:82` at four; `UIMetrics.swift:44` at four and `:54` at
five; and `AppModel.swift:83`, `AppModel+SessionState.swift:32`,
`TabBar.swift:112` and `:157`, `PromisedDrop.swift:66` and
`SurfaceView.swift:50` at three each. The test tree breaks the rule about 306
times, worst at `SettingsPageSizeTests.swift:7` with 35 lines, which suggests
the rule was only ever meant for source. Either say so in AGENTS.md or fix the
twelve.

## Licensing and release

### 162. Medium. The bundle is signed without a hardened runtime, a timestamp or entitlements

`Scripts/build-lib.sh:162` signs with neither `--options runtime` nor
`--timestamp`, and there is no entitlements file in the tree.
`codesign -d -vvv build/Multishell.app` reports `flags=0x0(none)` and
`TeamIdentifier=not set`. TODO.md queues Developer ID and records none of these
three.

## Scripts and build

### 87. Low. CI never runs `make-app.sh`, so bundling and signing can break with it green

`.github/workflows/ci.yml:12`. CI runs `swift build` and `swift test` for both
packages and nothing else, while `make build` goes on to `Scripts/make-app.sh`
(Makefile:26), which writes the generated Info.plist (make-app.sh:49) and signs
the bundle (make-app.sh:58). A change that breaks any of those passes CI, and
nothing notices until someone runs `make build`. The Makefile's own header at
line 2 says the two are meant not to drift. `make build` completes here in under
ten minutes with no warnings, so a fourth job is cheap.

### 164. Low. CI pins the runner image but selects no Xcode, so it builds under the default

`.github/workflows/ci.yml:9`, `:17`, `:23` pin `macos-15` and never run
`xcode-select`, so the toolchain is whatever the image defaults to, which is
neither the 26 the docs state as the floor nor the 27 the developer runs.
`make lint --strict` is toolchain-sensitive, so a green CI lint does not mean a
green local one.

### 165. Low. CI has no concurrency cancellation and no job timeouts

`.github/workflows/ci.yml`. Every push runs three full macOS jobs to completion.

### 166. Low. CI runs neither the Markdown formatter nor a shell linter

`Makefile:57` formats Markdown and `Scripts/` holds three non-trivial bash
files. Both trees are clean today and nothing keeps them that way.

### 167. Low. COMPAT.md blames Apple silicon on libghostty, which ships both slices

`COMPAT.md:12` calls Apple silicon a platform limit, but libghostty ships a
`macos-arm64_x86_64` slice and `Scripts/build-lib.sh:52` builds
`arch=$(uname -m)`. Single-architecture is this project's choice, not the
dependency's.

## Documentation

### 168. Low. The Xcode floor is stated three different ways in three files

`README.md:24` says 26 or later, `COMPAT.md:14` says 27 or 26 for the libraries
alone, and `Docs/develop/build.md:5` and `:81` say 26 while adding that nobody
has built it under 26.

### 171. Low. The split-button thresholds in two docs are three points out

`Docs/design/tabs-and-columns.md:152` and `Docs/develop/known-gaps.md:176` give
190, 249 and 346 points at 10, 13 and 18 point; `UIMetrics.swift:60` computes
193, 252 and 351.

### 172. Low. known-gaps.md names a test suite that does not exist

`Docs/develop/known-gaps.md:175` says every number behind the thresholds is held
by UIMetricsTests. There is no such suite; it is `MetricsAndColourTests`, and
`MetricsAndColourTests.swift:57` recomputes the threshold from the
implementation's own expression, so it could not have caught 171.

### 173. Low. tests.md names a file as though it were a suite

`Docs/develop/tests.md:50` names ShellStateHooksTests. That is a filename whose
suites are `ZshIntegrationTests` and `ShellLaunchTests`. Eight test files carry
no suite of their own name, which is what commit a0393d1 set out to fix.

### 174. Low. AGENTS.md ends a rule with a bare path that resolves from nowhere

`AGENTS.md:14` ends with "See layout.md." Every other link and inline path in
the tree resolves from the repository root.

## Tests

### 175. Medium. Six tests sleep a fixed interval and then assert a count did not grow

`Tests/MultishellCLITests/HelperTests.swift:125` and `:165` wait 200 ms and then
assert a count did not grow, which tests.md:344 forbids by name. Same shape at
`PromisedDropTests.swift:206`, `AutosaveTests.swift:91`,
`DispatchDirectoryWatcherTests.swift:102`, `SessionStateModelTests.swift:445`
and `AppModelGitTests+Refresh.swift:294`.

### 176. Medium. Two suites read the process-wide descriptor count without `.serialized`

`Tests/MultishellProcessTests/ProcessRunnerTests.swift:157` and `:198` both read
it, neither is serialized, and `ProcessStopTests:449` spawns children in the
same process. This is the one real serialization gap in the suite.

### 177. Low. Two watcher tests sample the descriptor count over a fifth of a second

`Tests/MultishellAppCoreTests/Ports/DispatchDirectoryWatcherTests.swift:137` and
`:151` sample over 120 and 240 ms where tests.md:355 says several seconds.

### 178. Low. A main-actor AppKit suite spins the run loop without `.serialized`

`Apps/macOS/Tests/MultishellTests/AppKit/SidewaysWheelTests.swift:9` and `:44`
spin `RunLoop.main` for 250 ms alongside four other live `@MainActor` AppKit
suites.

### 179. Low. A misspelled SF Symbol passes its test and draws nothing

`Apps/macOS/Tests/MultishellTests/Controls/ProjectIconSymbolTests.swift:32` does
`else { continue }` on a symbol that will not resolve, so a bad name in
`ProjectIcon.symbols` passes and draws nothing in the app.
`AgentMarkResourceTests.swift:14` uses `Issue.record` for the same shape.

### 180. Low. A parser test asserts two counts are not negative, which cannot fail

`Tests/MultishellGitKitTests/Parsers/WorktreeStatusParserTests.swift:71` and
`:74`: `#expect(status.ahead >= 0 && status.behind >= 0)`. It is a crash test
whose name is its only assertion.

### 181. Low. Three tests skip silently when node or python3 is absent

`Tests/MultishellCoreTests/Integrations/Agents/OpenCodePluginRunTests.swift:10`
skips without node, and it is the only test of the generated plugin that 85
already calls unproven. `UnixSocketTests.swift:94` and `:194` skip the
cross-process claim tests without `/usr/bin/python3`.

### 182. Low. Nothing tests the four appearance setters, each of which writes and persists

`Sources/MultishellAppCore/Model/AppModel+Appearance.swift`. `setTheme`,
`setFont`, `setUIFontSize` and `reloadThemes` are named by no test, and each
mutates the workspace, persists it and pushes a theme to every live surface.
`ThemeCatalogue.relocateStrayExamples`, which moves files on disk, is the same.
`Apps/macOS/Sources` is 7,218 lines against 1,880 of test, which is the
deliberate untested-views split, but `MacPlatform.swift`, `TabDrops.swift` and
`ProjectDropDelegate.swift` are logic, not views.

## Accessibility and macOS integration

### 183. Medium. The two sidebar header buttons carry no accessibility label

`Apps/macOS/Sources/Multishell/Sidebar/SidebarHeader.swift:25`. The shared
icon-button helper sets `.help` and no `.accessibilityLabel`, making the filter
and Add Project buttons the only icon-only controls in the app without one.
`IconButton.swift:17`, `TabButton.swift:169`, `DetailView.swift:104`,
`ScrollingTabStrip.swift:92`, `SidebarFilterField.swift:36` and
`TabBar.swift:154` all pair the two.

### 184. Low. No shortcut moves focus between the panes of one tab

`Apps/macOS/Sources/Multishell/App/MultishellCommands.swift` has next and
previous tab and group and nothing that moves focus inside a tab, so a split
pane is mouse-only and Ghostty takes every keystroke. known-gaps.md:59 records
the sidebar half and TODO.md queues the rest.

## Repository hygiene

### 187. Low. A public repository with no SECURITY.md, CONTRIBUTING.md or issue template

`.github/` holds workflows only: no security policy, contributing guide, issue
or pull request template, CODEOWNERS or dependabot config.

### 188. Low. The short version string is a date and a hash, not a version

`CFBundleShortVersionString` is `2026.09.19-a0393d1`. Any DMG, Sparkle feed or
update path needs this changed first. TODO.md's release-workflow entry covers
it.
