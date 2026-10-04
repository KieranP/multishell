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

Code references last checked on 2026-10-02 against the uncommitted tree on
6e6eff2. Agent behaviour last checked on 2026-09-23 with claude 2.1.280, codex
0.155.1, gemini 0.46.0, copilot 1.0.87 and opencode 1.18.30.

| #   | Effect | What                                                                                  |
| --- | ------ | ------------------------------------------------------------------------------------- |
| 001 | Medium | [Unconfirmed] Parts of three agents' hook files have never been watched               |
| 002 | Medium | [Unconfirmed] A tab started with a command waits for a key after the command exits    |
| 003 | Low    | [Unconfirmed] A drop landing 250 ms after the button comes up can be refused          |
| 004 | CI     | [Unconfirmed] The bundle script has run through xcodebuild only under the newer Xcode |

## Medium

### 001. [Unconfirmed] Parts of three agents' hook files have never been watched

Claude, Codex and Copilot were run with their hooks pointed at a capture script.
Each event they fired reached the helper as spelled, with the agent's own pid.
Still unwatched: Codex's hook trust (the run bypassed it) and its
PermissionRequest and Interrupt; Gemini past SessionStart, its free tier no
longer authenticating; Copilot's `notification`, and its reading of the
user-level `~/.copilot/hooks` rather than a repository's. Step: trust the hook
once with `/hooks` in Codex and start a session without the bypass flag.

### 002. [Unconfirmed] A tab started with a command waits for a key after the command exits

libghostty turns `wait-after-command` on for any surface given a command
(`ThirdParty/ghostty/src/apprt/embedded.zig:572`). Agent tabs, bash tabs
(through `/bin/sh -c`, `ShellLaunch.overrideCommand`) and shells other than the
login one are all given one, so when the command exits the pane prints "Process
exited. Press any key to close the terminal." and stays. The session stays in
`liveSessionIDs` until a key is pressed, and only then does `close_surface_cb`
reach `SessionReconciler.terminalHost(_:didExit:)`. A zsh tab on the login shell
is given no command and closes at once. libghostty-spm carried no patch for it
either. Found by reading, not watched. Step: run `exit` in a bash tab. Fix = a
sixth Ghostty patch leaving `wait-after-command` to the config, once it is
decided whether an agent tab should keep its last screen.

## Low

### 003. [Unconfirmed] A drop landing 250 ms after the button comes up can be refused

A tab or project drag whose source view was rebuilt or recycled mid-drag never
hears its drag session end, so `DragRelease.wait` (`DragRelease.swift:8`) polls
`NSEvent.pressedMouseButtons` every 100 ms and ends the drag 250 ms after the
button is seen up (`AppModel+TabDrag.swift:30`,
`AppModel+ProjectDrag.swift:35`). A `performDrop` that arrives later than that,
on a loaded machine, finds no drag in the air: the tab drop is refused and the
tab springs back, and a project drop reorders nothing. Nobody has timed how late
a drop can arrive. Settle it by logging the gap between button-up and
`performDrop` under load. Fix = own the drag as an AppKit `NSDraggingSource`
outside the recycled view, whose `draggingSession(_:endedAt:operation:)` arrives
whatever SwiftUI does to the row. Cost: the tab's click, double click and middle
click move to AppKit with it (tabs-and-groups.md).

## CI

### 004. [Unconfirmed] The bundle script has run through xcodebuild only under the newer Xcode

This machine has only Xcode 27. That the older one writes no build path either
rests on its accessor having looked in the bundle's resources since packages
could carry them, not on a run; the helper comes the same way. Step: run
`make build` under `DEVELOPER_DIR=/Applications/Xcode_26.0.1.app` on a macos-26
runner and see `verify_binary` pass for both. Fallback = the newer Xcode.
