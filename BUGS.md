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
30d243f. Agent behaviour last checked on 2026-09-23 with claude 2.1.280, codex
0.155.1, gemini 0.46.0, copilot 1.0.87 and opencode 1.18.30.

| #   | Effect | What                                                                                  |
| --- | ------ | ------------------------------------------------------------------------------------- |
| 001 | Medium | [Unconfirmed] Parts of three agents' hook files have never been watched               |
| 002 | Low    | [Unconfirmed] A drop landing 250 ms after the button comes up can be refused          |
| 003 | CI     | [Unconfirmed] The bundle script has run through xcodebuild only under the newer Xcode |
| 004 | Docs   | libintl is LGPL and linked statically, from a libghostty someone else built           |

## Medium

### 001. [Unconfirmed] Parts of three agents' hook files have never been watched

Claude, Codex and Copilot were run with their hooks pointed at a capture script.
Each event they fired reached the helper as spelled, with the agent's own pid.
Still unwatched: Codex's hook trust (the run bypassed it) and its
PermissionRequest and Interrupt; Gemini past SessionStart, its free tier no
longer authenticating; Copilot's `notification`, and its reading of the
user-level `~/.copilot/hooks` rather than a repository's. Step: trust the hook
once with `/hooks` in Codex and start a session without the bypass flag.

## Low

### 002. [Unconfirmed] A drop landing 250 ms after the button comes up can be refused

A tab or project drag whose source view was rebuilt or recycled mid-drag never
hears its drag session end, so `DragRelease.wait` (`DragRelease.swift:5`) polls
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

### 003. [Unconfirmed] The bundle script has run through xcodebuild only under the newer Xcode

This machine has only Xcode 27. That the older one writes no build path either
rests on its accessor having looked in the bundle's resources since packages
could carry them, not on a run; the helper comes the same way. Step: run
`make build` under `DEVELOPER_DIR=/Applications/Xcode_26.0.1.app` on a macos-26
runner and see `verify_binary` pass for both. Fallback = the newer Xcode.

## Docs

### 004. libintl is LGPL and linked statically, from a libghostty someone else built

GNU gettext 0.24's libintl reaches the executable inside the prebuilt
`libghostty.a` (Ghostty's Zig object calls `bindtextdomain` and `dgettext`).
LGPL-2.1 asks that whoever receives a statically linked copy can relink it
against a modified libintl. `THIRD-PARTY-NOTICES.md` names the pieces for that,
the gettext source, Ghostty's at the pinned commit, libghostty-spm's build
scripts and this repository, but nobody has walked the relink, and libghostty is
built by a third party (`Docs/develop/dependencies.md`). Nothing binds until the
app is distributed. Fix = build libghostty from source before a release, which
dependencies.md already asks for, and try the relink once.
