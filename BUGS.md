# Bugs

Everything known to be wrong with this build, and everything it is known not to
do. One entry per finding, numbered in the order they are listed here, so a
number is a place in this file and nothing more: renumbering on a fix is
expected, and nothing outside this file cites one.

Ranks, worst first. High is a security risk, data loss, or wrong data written.
Medium is what a user meets in ordinary use. Low needs particular circumstances.
Perf is what it costs to run, UI/UX what it costs to read or reach, Code and
Docs what it costs to work on; none of those four is a defect. CI covers the
build pipeline and the test suite, and lists only what fails or blocks a
release. An unconfirmed entry is reasoning nobody has watched go either way,
where a real agent, another machine or a particular piece of hardware would
settle it; it is ranked by what it would cost if the reasoning is wrong. Whether
a feature draws and works in ordinary use is checked by hand as it is built, so
it gets no entry here.

Code references last checked on 2026-09-25 against the uncommitted tree on
eabde30. Agent behaviour last checked on 2026-09-23 with claude 2.1.280, codex
0.155.1, gemini 0.46.0, copilot 1.0.87 and opencode 1.18.30.

| #   | Effect | What                                                                                  |
| --- | ------ | ------------------------------------------------------------------------------------- |
| 001 | Medium | [Unconfirmed] Parts of three agents' hook files have never been watched               |
| 002 | Medium | [Unconfirmed] A /clear after an interrupted turn leaves the pane Working              |
| 003 | Low    | A dead mount can hold every cooperative-pool thread                                   |
| 004 | Low    | [Unconfirmed] Remove waits on a git status that has no timeout                        |
| 005 | Low    | [Unconfirmed] A worktree path resolved while missing stays unresolved                 |
| 006 | Low    | [Unconfirmed] Ctrl-C at a bash prompt ends the relay's inline fallback                |
| 007 | Low    | A child that exits as its timeout fires is now and then reported as timed out         |
| 008 | Low    | [Unconfirmed] A drop landing 250 ms after the button comes up can be refused          |
| 009 | Perf   | The bash relay still forks twice per command                                          |
| 010 | CI     | [Unconfirmed] The bundle script has run through xcodebuild only under the newer Xcode |
| 011 | Docs   | libintl is LGPL and linked statically, from a libghostty someone else built           |

## Medium

### 001. [Unconfirmed] Parts of three agents' hook files have never been watched

Claude, Codex and Copilot were run with their hooks pointed at a capture script.
Each event they fired reached the helper as spelled, with the agent's own pid.
Still unwatched: Codex's hook trust (the run bypassed it) and its
PermissionRequest and Interrupt; Gemini past SessionStart, its free tier no
longer authenticating; Copilot's `notification`, and its reading of the
user-level `~/.copilot/hooks` rather than a repository's. Step: trust the hook
once with `/hooks` in Codex and start a session without the bypass flag.

### 002. [Unconfirmed] A /clear after an interrupted turn leaves the pane Working

Every agent's SessionStart now carries `startsSession`, and
`SessionStates.report` (`SessionStates.swift:45`) drops such a report while the
pane is Running or Waiting and the shell did not report the Working. Claude
fires no hook when Esc interrupts a turn, so the pane stays Running; a `/clear`
or `/resume` then sends SessionStart, which used to reset it to Idle and is now
dropped. The dot says Working until the next prompt. The comment names Copilot's
prompt mode as the reason, but the flag is on all four agents. Step: interrupt a
Claude turn with Esc, run `/clear`, watch the dot. Fix = set `startsSession` for
Copilot alone, or let a SessionStart with `source` `clear` or `resume` through.

## Low

### 003. A dead mount can hold every cooperative-pool thread

`offMain` (`OffMain.swift:5`, 17 callers: the save, the Trash, the records and
shared-settings reads, detection, the scan in `DispatchDirectoryWatcher.watch`)
and `WorktreeGit.untrackedCounts` (`WorktreeGit+Status.swift:51`) run blocking
file reads in `Task.detached`, which shares the cooperative pool, one thread per
core. `WorktreeGit.list` (`WorktreeGit.swift:43`) stats every worktree with no
detach at all. A probe of 64 tasks each blocking for a second on 12 cores peaked
at 12 at once and took 6.3 s, and an unrelated `.utility` task waited 5.15 s for
a thread. Fix = a concurrent `DispatchQueue` as a `TaskExecutor` (macOS 15.4):
`offMain` becomes
`Task(executorPreference: blockingIO, priority: .utility) { work() }.value`, and
`withTaskExecutorPreference` around `WorktreeGit.list` and the coordinator's
status reads covers what they call. The same probe then peaked at 64, took 1.0
s, and the other task waited 25 µs. Cost: a dead mount holds that many GCD
threads rather than queueing them, and the "Known gap" in
`Docs/design/worktrees.md` changes with it. Turning on
`NonisolatedNonsendingByDefault` first would move these stats onto the caller's
actor, which for `AppModel` is the main one.

### 004. [Unconfirmed] Remove waits on a git status that has no timeout

`requestWorktreeRemoval` (`AppModel+WorktreeRemoval.swift:33`) now awaits
`refreshStatus(of:forced: true)` before it shows the confirmation. That read is
`git status` through `GitRunner.output`, which passes no timeout. On a worktree
whose mount stopped answering the read never returns, so the dialog never
appears, and `removalReads` swallows every further click on that row. Before,
the dialog came up at once. A large repository delays it by the length of its
status with nothing on screen. Step: remove a worktree on an unplugged SMB
share. Fix = bound the forced read, a second is what `DirectoryProbe` allows,
and show the dialog with the status already held when it runs out.

### 005. [Unconfirmed] A worktree path resolved while missing stays unresolved

`AppModel.resolvedComponents` (`AppModel+Worktrees.swift:189`) caches
`resolvingSymlinksInPath()` per worktree on first use, for every worktree each
time a report is placed by directory. Foundation returns a missing or dangling
path unchanged, so a worktree whose directory is absent then, on an unmounted
volume or behind a dangling link, is cached with its links unresolved. Once the
directory is back, a report whose `cwd` is the resolved spelling
(`/private/tmp/...` for a `/tmp/...` worktree) matches no worktree until the
worktree is forgotten. Fix = cache only a resolution of a path that exists.

### 006. [Unconfirmed] Ctrl-C at a bash prompt ends the relay's inline fallback

The relay runs in the bash shell's process group, so a Ctrl-C at the prompt
reaches it. The helper ignores INT and QUIT (`Helper.relayIgnores`), but the
inline fallback in `init.bash:30`, which runs when the helper is too old for
`relay`, traps only HUP, TSTP, TTIN and TTOU. A Ctrl-C at the prompt ends that
loop; lines already in the pipe are lost and each later report pays the EPIPE
before falling back to a helper launch. Fix = add INT and QUIT to that `trap`.

### 007. A child that exits as its timeout fires is now and then reported as timed out

A stop checks under `RunningChild`'s lock that the child is not a zombie and not
already exiting (`P_WEXIT`, `RunningChild.swift:48`), then sends SIGHUP. A child
that begins its exit between the check and the signal takes the SIGHUP without
effect, and `stop` records `.timedOut` beside its own status, 0 included. The
harm is a finished hook or git call reported as timed out. Running `sleep 0.05`
with a 50 ms timeout, eight at once, misreported about 1 in 60 runs before the
exiting check and 2 in 3,200 after. Stopping the child first would close the
gap, a stopped process being unable to start its exit, but Subprocess traps on
the stop its `waitid` then reports (`Subprocess+Unix.swift:1009` in the
checkout).

### 008. [Unconfirmed] A drop landing 250 ms after the button comes up can be refused

A tab or project drag whose source view was rebuilt or recycled mid-drag never
hears its drag session end, so `DragRelease.wait` (`DragRelease.swift:7`) polls
`NSEvent.pressedMouseButtons` every 100 ms and ends the drag 250 ms after the
button is seen up (`AppModel+TabDrag.swift:27`,
`AppModel+ProjectDrag.swift:30`). A `performDrop` that arrives later than that,
on a loaded machine, finds no drag in the air: the tab drop is refused and the
tab springs back, and a project drop reorders nothing. Nobody has timed how late
a drop can arrive. Settle it by logging the gap between button-up and
`performDrop` under load. Fix = own the drag as an AppKit `NSDraggingSource`
outside the recycled view, whose `draggingSession(_:endedAt:operation:)` arrives
whatever SwiftUI does to the row. Cost: the tab's click, double click and middle
click move to AppKit with it (tabs-and-columns.md).

## Perf

### 009. The bash relay still forks twice per command

The relay exists so a command costs no process launch, and hooks.zsh dropped its
`$(...)` in the same change because a command substitution forks.
`_multishell_relayed` (`init.bash:55`) runs `theirs="$(trap -p PIPE)"` for both
the started and the finished line, and bash 3.2 forks for every command
substitution. Fix = read the PIPE trap once when the relay starts, or keep
SIGPIPE ignored only in a subshell that does the write.

## CI

### 010. [Unconfirmed] The bundle script has run through xcodebuild only under the newer Xcode

This machine has only Xcode 27. That the older one writes no build path either
rests on its accessor having looked in the bundle's resources since packages
could carry them, not on a run; the helper comes the same way. Step: run
`make build` under `DEVELOPER_DIR=/Applications/Xcode_26.0.1.app` on a macos-26
runner and see `verify_binary` pass for both. Fallback = the newer Xcode.

## Docs

### 011. libintl is LGPL and linked statically, from a libghostty someone else built

GNU gettext 0.24's libintl reaches the executable inside the prebuilt
`libghostty.a` (Ghostty's Zig object calls `bindtextdomain` and `dgettext`).
LGPL-2.1 asks that whoever receives a statically linked copy can relink it
against a modified libintl. `THIRD-PARTY-NOTICES.md` names the pieces for that,
the gettext source, Ghostty's at the pinned commit, libghostty-spm's build
scripts and this repository, but nobody has walked the relink, and libghostty is
built by a third party (`Docs/develop/dependencies.md`). Nothing binds until the
app is distributed. Fix = build libghostty from source before a release, which
dependencies.md already asks for, and try the relink once.
