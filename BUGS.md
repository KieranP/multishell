# Bugs

Everything known to be wrong with this build, and everything it is known not to
do. One entry per finding, numbered in the order they are listed here, so a
number is a place in this file and nothing more: renumbering on a fix is
expected, and nothing outside this file cites one.

Ranks, worst first. High is a security risk, data loss, or wrong data written.
Medium is what a user meets in ordinary use. Low needs particular circumstances.
CI covers the build pipeline and the test suite. Perf is what it costs to run,
UI/UX what it costs to read or reach, Code and Docs what it costs to work on;
none of those four is a defect. A title tagged [Unconfirmed] is reasoning nobody
has watched go either way: a screen, a real agent or another machine would
settle it, and the entry is ranked by what it would cost if the reasoning is
wrong. Those come last within their rank.

| #   | Effect | What                                                                                                |
| --- | ------ | --------------------------------------------------------------------------------------------------- |
| 001 | Medium | An OpenCode server reused by a second pane lands the dot on the first pane's tab                    |
| 002 | Medium | [Unconfirmed] Three of the four agents' hook files have never been watched moving a dot             |
| 003 | Medium | [Unconfirmed] The plugin's loader contract and its permission events                                |
| 004 | Medium | [Unconfirmed] One agent's notification types were read out of a binary, not watched arriving        |
| 005 | Medium | [Unconfirmed] One agent's subagent events are asked for in the spelling its payload names           |
| 006 | Medium | [Unconfirmed] Every hook inside a worker is taken to carry a worker id, and a main-session one none |
| 007 | Low    | A subagent roster with no matching stop grows without bound                                         |
| 008 | Low    | The 500-character cap guards `message` and none of the other reported strings                       |
| 009 | Low    | A recycled pid between the hangup and the kill sends SIGKILL to a stranger                          |
| 010 | Low    | A misspelled SF Symbol passes its test and draws nothing                                            |
| 011 | Low    | The short version string is a date and a hash, not a version                                        |
| 012 | Low    | A shell directory variable set system-wide leaves the tab without hooks                             |
| 013 | Low    | A greeting line shaped like an assignment swallows the login shell's first variable                 |
| 014 | Low    | A tab drag released where nothing takes it never ends                                               |
| 015 | Low    | A repository's file is read from the project path, which a bare repository has no checkout at       |
| 016 | Low    | A git under the floor fails the worktree list with no fallback                                      |
| 017 | Low    | A tag named exactly like a local trunk decides the base                                             |
| 018 | Low    | A hand-written hook group with a bare command keeps ours after Remove                               |
| 019 | Low    | Saving stays off for the session after an unreadable, unmovable state file                          |
| 020 | Low    | Two ways past the under-construction hold-back remain                                               |
| 021 | Low    | Two overlapping creates share one Cancel                                                            |
| 022 | Low    | One agent keys a worker by name, so two of one kind share a roster place                            |
| 023 | Low    | A user's list entry naming somewhere else places nothing, silently                                  |
| 024 | Low    | Two agents left the catalogue and a stored id still names them                                      |
| 025 | Low    | A copy that handed over leaves its generated config behind                                          |
| 026 | Low    | Neither a file list nor the checkout has a timeout                                                  |
| 027 | Low    | [Unconfirmed] The hardened runtime over a long session and over the CLI install                     |
| 028 | Low    | [Unconfirmed] Cancel against a real checkout held by LFS or a credential helper                     |
| 029 | Low    | [Unconfirmed] The generated config directory's sweep at quit                                        |
| 030 | Low    | [Unconfirmed] The focus report's deferred hop and its first-responder check                         |
| 031 | Low    | [Unconfirmed] The engine's own path is untested and its zsh chain checked against a stand-in        |
| 032 | Low    | [Unconfirmed] An include line in that config is not followed                                        |
| 033 | Low    | [Unconfirmed] Whether the view is updated when every stored value compares equal                    |
| 034 | Low    | [Unconfirmed] The debug-trap claim under bash's array-form prompt command                           |
| 035 | Low    | [Unconfirmed] A promised drop where a source reports once for several files                         |
| 036 | Low    | [Unconfirmed] Drops reach the frame through an undocumented search order                            |
| 037 | Low    | [Unconfirmed] Which type raised the banner that prompted that narrowing is unestablished            |
| 038 | Low    | [Unconfirmed] Neither half of the banner grouping has been seen on screen                           |
| 039 | Low    | [Unconfirmed] A withdrawal can race the add that follows it                                         |
| 040 | Low    | [Unconfirmed] Whether the engine puts anything between the shell and the app                        |
| 041 | Low    | [Unconfirmed] The plugin bridge's directory filter                                                  |
| 042 | Low    | [Unconfirmed] An interrupted fan-out keeps its chip until the next prompt                           |
| 043 | Low    | [Unconfirmed] An owed Done can pay in the middle of the next turn under an older helper             |
| 044 | Low    | [Unconfirmed] A displaced failure comes back with a fresh age                                       |
| 045 | Low    | [Unconfirmed] A child's first message arriving before its creation would empty the roster           |
| 046 | Low    | [Unconfirmed] The plugin's cap on ended child ids                                                   |
| 047 | Low    | [Unconfirmed] A child worker's kind where the session info lacks the field                          |
| 048 | CI     | CI never runs `make-app.sh`, so bundling and signing can break with it green                        |
| 049 | CI     | CI pins the runner image but selects no Xcode, so it builds under the default                       |
| 050 | CI     | CI has no concurrency cancellation and no job timeouts                                              |
| 051 | CI     | CI runs neither the Markdown formatter nor a shell linter                                           |
| 052 | CI     | Six tests sleep a fixed interval and then assert a count did not grow                               |
| 053 | CI     | Two suites read the process-wide descriptor count without `.serialized`                             |
| 054 | CI     | Two watcher tests sample the descriptor count over a fifth of a second                              |
| 055 | CI     | A main-actor AppKit suite spins the run loop without `.serialized`                                  |
| 056 | CI     | A parser test asserts two counts are not negative, which cannot fail                                |
| 057 | CI     | Three tests skip silently when node or python3 is absent                                            |
| 058 | CI     | Nothing tests the four appearance setters, each of which writes and persists                        |
| 059 | CI     | [Unconfirmed] The bundle script has run through xcodebuild only under the newer Xcode               |
| 060 | CI     | [Unconfirmed] Nothing drives a terminal host against a real child                                   |
| 061 | CI     | [Unconfirmed] Linux has never been compiled, locally or in CI                                       |
| 062 | Perf   | One commit on the trunk re-asks every branch's merge verdict                                        |
| 063 | Perf   | `git status` runs for worktrees that are collapsed or filtered out of sight                         |
| 064 | Perf   | A drag rebuilds the sidebar or the tab strip at pointer rate                                        |
| 065 | Perf   | Theme colours are parsed out of hex on every access                                                 |
| 066 | Perf   | Rows hold fresh closures, so SwiftUI can never skip one                                             |
| 067 | Perf   | The branch scan spawns a git process per project per tick, serially                                 |
| 068 | Perf   | A `cwd`-only report resolves every worktree's symlinks on the main actor                            |
| 069 | Perf   | The agent board is rebuilt whole on every body evaluation                                           |
| 070 | Perf   | The whole tab strip sits inside a `GeometryReader`                                                  |
| 071 | Perf   | The sidebar filter folds every worktree name per keystroke                                          |
| 072 | Perf   | Row order and block height are recomputed on every sidebar rebuild                                  |
| 073 | Perf   | The directory watcher stats every watched directory on the main actor                               |
| 074 | Perf   | The dropped-file sweep runs synchronously on the main actor at launch                               |
| 075 | Perf   | A drag over a pane re-reads the pasteboard on every mouse move                                      |
| 076 | Perf   | The directory check before a shell starts runs on the main thread                                   |
| 077 | UI/UX  | The two sidebar header buttons carry no accessibility label                                         |
| 078 | UI/UX  | Project settings' Hooks tab overflows the window it opens in                                        |
| 079 | UI/UX  | While the board is up, two commands act on a worktree nothing on screen names                       |
| 080 | UI/UX  | English only, so no layout has been seen in another language                                        |
| 081 | UI/UX  | A number inside a phrase carries no locale                                                          |
| 082 | UI/UX  | A tab title persisted before a language change keeps the old word                                   |
| 083 | UI/UX  | Agent settings is the one page nothing holds                                                        |
| 084 | UI/UX  | The find bar shows no match count and no wrapped mark                                               |
| 085 | UI/UX  | [Unconfirmed] The rename field's accessibility container under VoiceOver                            |
| 086 | UI/UX  | [Unconfirmed] The tab strip's two split buttons have never been watched on a screen                 |
| 087 | UI/UX  | [Unconfirmed] A cancelled divider drag                                                              |
| 088 | UI/UX  | [Unconfirmed] A wheel that sends lines, and a trackpad's vertical turn                              |
| 089 | UI/UX  | [Unconfirmed] A turn over the New Tab or split buttons scrolls nothing                              |
| 090 | UI/UX  | [Unconfirmed] An edit to that config lands only at the next launch                                  |
| 091 | UI/UX  | [Unconfirmed] Whether a reused surface frame leaves the keyboard in the right place                 |
| 092 | UI/UX  | [Unconfirmed] The notifications settings page has never been seen on screen                         |
| 093 | UI/UX  | [Unconfirmed] The settings window has never been seen on screen                                     |
| 094 | UI/UX  | [Unconfirmed] Tab-group drawing is unverified on screen                                             |
| 095 | UI/UX  | [Unconfirmed] Whether a SwiftUI overlay composites above the engine's surface                       |
| 096 | UI/UX  | [Unconfirmed] The find bar has never been seen on a screen                                          |
| 097 | UI/UX  | [Unconfirmed] Reordering at the edges of a strip whose tabs differ widely in width                  |
| 098 | UI/UX  | [Unconfirmed] The git badge's new width is unverified on screen                                     |
| 099 | UI/UX  | [Unconfirmed] The reordered board card and the git indicator picker have not been seen drawn        |
| 100 | UI/UX  | [Unconfirmed] Agents board drawing is unverified on screen                                          |
| 101 | UI/UX  | [Unconfirmed] Neither agent-flags row has been seen on screen                                       |
| 102 | UI/UX  | [Unconfirmed] A click on the blank part of the New Tab menu's frame                                 |
| 103 | UI/UX  | [Unconfirmed] The subagent chip's popover                                                           |
| 104 | UI/UX  | [Unconfirmed] The New Tab menu's rendered agent marks                                               |
| 105 | Code   | A view measures the drop indicator's hit split, so nothing tests it                                 |
| 106 | Code   | `claimedPaths` is read by seven tests and nothing in production                                     |
| 107 | Code   | `warmWorktrees` is absent from the one place per-worktree state is dropped                          |
| 108 | Code   | `AppModel+Runtime` is four unrelated concerns under a name that says none                           |
| 109 | Code   | Agent, shell and editor detection sits in a file named Agents                                       |
| 110 | Code   | `WorkspaceStore` writes the same index lookup sixteen times                                         |
| 111 | Code   | The two translation test files duplicate their scanner and have drifted                             |
| 112 | Code   | The window header chrome is written out twice                                                       |
| 113 | Code   | The centred-caption styling is written out twice                                                    |
| 114 | Code   | `public` declarations named by no other target                                                      |
| 115 | Code   | Catalogue keys are split by a stray `s`, which breaks the sort into groups                          |
| 116 | Code   | A general SVG path parser lives in the Agents view folder                                           |
| 117 | Code   | Three unrelated extensions share one file                                                           |

## Medium

### 001. An OpenCode server reused by a second pane lands the dot on the first pane's tab

`Sources/MultishellCore/Integrations/Agents/OpenCodePlugin.swift:38`. The plugin
spawns the helper from the OpenCode server's process, and the helper reads
`MULTISHELL_SESSION` from its environment (Helper.swift:15). An OpenCode server
started from one pane and reused by another therefore reports that first pane's
session, so the dot lands on the wrong tab. Only the plugin has this: every
other agent's hook runs in the session's own process.

### 002. [Unconfirmed] Three of the four agents' hook files have never been watched moving a dot

All four are written from each agent's documented shape and only one has been
watched in a real session. Run each once: check its events fire, that the pid
reported is the agent and not a wrapper outliving the hook, and that the one
requiring trust holds.

### 003. [Unconfirmed] The plugin's loader contract and its permission events

It has been driven against a stub helper. Unconfirmed: that the agent loads a
plugin exporting a function rather than an object, its loader having two
generations of that contract, and that the two permission events arrive under
the names it listens for.

### 004. [Unconfirmed] One agent's notification types were read out of a binary, not watched arriving

Which of them only announce was decided from their names. What was checked is
the helper's end, over synthetic payloads. An announcing type added later reads
as waiting until someone notices and names it.

### 005. [Unconfirmed] One agent's subagent events are asked for in the spelling its payload names

Its reference documents the other spelling. Not seen firing; if it does not, the
file needs the camel spelling and a payload with no event name, which the reader
refuses today.

### 006. [Unconfirmed] Every hook inside a worker is taken to carry a worker id, and a main-session one none

Read from the documented payloads, not watched. Should a main-session tool call
carry one too, each would put a worker keyed by the session on the roster and
the turn would stop clearing it, so the pane would hold Working with a Done owed
to a worker that does not exist.

## Low

### 007. A subagent roster with no matching stop grows without bound

`Sources/MultishellAppCore/States/SessionStates+Entry.swift:61`. `keep(_:)`
appends a `Subagent` for every unseen id, and only `settleTurn()` empties the
roster, on a new turn, on idle or error, on a finished command, or when the pid
goes. An agent that emits `SubagentStart` with fresh ids, never a matching
`SubagentStop` and never a `UserPromptSubmit` grows `entry.workers` for as long
as it runs, and `SubagentList` draws a row for each. The
`.done where !entry.workers.isEmpty` arm of `settlingOwn` also holds the agent's
Done, so the tab never shows it finished.

### 008. The 500-character cap guards `message` and none of the other reported strings

`Sources/MultishellCore/Sessions/SessionStateReport.swift:86` and `:116`.
`message` is capped both in and out, with the reasoning at line 115 that any
process of the user's may write a line so the cap is the reader's rule.
`subagent.type`, which `SubagentList.swift:30` draws verbatim through
`displayName`, along with `subagent.id`, `agent` and `cwd`, carry no cap:
`SubagentReport` stores all three unchecked. Any local process writes one line
of about 60 KB, under the 64 KB `UnixSocketServer.maximumLineLength`, with a 60
KB `subagent.type`; the string is kept in the roster and laid out by SwiftUI on
every render of the pane row and the board card.

### 009. A recycled pid between the hangup and the kill sends SIGKILL to a stranger

`Sources/MultishellProcess/ProcessStopper.swift:73`. After `kill(-pid, SIGHUP)`,
a block three seconds later probes with `kill(-pid, 0)` and then sends
`kill(-pid, SIGKILL)`. The `leadsGroup` branch checks neither
`process.isRunning` nor the identity of the group that answered, where the
`!leadsGroup` branch four lines above does check `process.isRunning`. So if the
hook's group exits at once and the kernel recycles the pid onto a new group
leader of the same user within `killGrace`, the kill lands on an unrelated
group. The comment there says an empty group answers ESRCH so what answers is
ours, which is the assumption pid recycling breaks. The missing check is in the
code; the race needs a heavily loaded machine and nobody has seen it fire.

### 010. A misspelled SF Symbol passes its test and draws nothing

`Apps/macOS/Tests/MultishellTests/Controls/ProjectIconSymbolTests.swift:32` does
`else { continue }` on a symbol that will not resolve, so a bad name in
`ProjectIcon.symbols` passes and draws nothing in the app.
`AgentMarkResourceTests.swift:14` uses `Issue.record` for the same shape.

### 011. The short version string is a date and a hash, not a version

`CFBundleShortVersionString` comes from `bundle_version` in
`Scripts/build-lib.sh:20`, which prints `<commit date>-<short hash>`, giving
`2026.09.19-a0393d1`. Any DMG, Sparkle feed or update path needs this changed
first. TODO.md's release-workflow entry covers it.

### 012. A shell directory variable set system-wide leaves the tab without hooks

zsh reads the rest of the chain from wherever the variable points at that
moment, so a system file relocating it after our first file steers zsh past our
files, as it would past any user's. The user's own files relocating it are
followed. No fallback short of appending to that directory's rc file, which the
design refuses.

### 013. A greeting line shaped like an assignment swallows the login shell's first variable

The captured environment is read from the first line that looks like an
assignment, so an rc file's greeting is skipped unless it happens to look like
one, in which case it is taken for the first variable and the real one, usually
PATH, is lost. Not decidable from the text; the fallback is the process's own
PATH.

### 014. A tab drag released where nothing takes it never ends

The drag API has no cancellation callback and only a drop clears the state, so
the drag state stays true and every column keeps its bands mounted. The bands
stay hidden, so the cost is a clear drop target and its accessibility label over
the terminal area until the next drag. Not seen on screen.

### 015. A repository's file is read from the project path, which a bare repository has no checkout at

So a bare project never picks up a shared `.multishell.json`.

### 016. A git under the floor fails the worktree list with no fallback

The NUL-terminated form is unknown to it, the read fails, and the row says so
and names the option. Left because the supported macOS ships a newer one; fix if
it bites = retry without that flag on the one failure.

### 017. A tag named exactly like a local trunk decides the base

The worktree's branch goes to git as a refname and the base does not, being the
short print form, so every merge read for that project would be measured against
the tag. It needs a repository whose default resolves to a local trunk with a
tag of the same name beside it.

### 018. A hand-written hook group with a bare command keeps ours after Remove

No agent writes that shape and Add never produces it, so it is reachable only by
hand-editing; the two shapes are handled separately and the bare one is taken as
ours whole.

### 019. Saving stays off for the session after an unreadable, unmovable state file

The check is made once at restore, so permissions fixed while the app runs are
not noticed until relaunch, and the session's work goes at quit with only the
launch alert having said so.

### 020. Two ways past the under-construction hold-back remain

A checkout run in a terminal, where the app learns of the row from the watcher
and knows nothing of it; and a symlinked volume, where git's resolved path and
the planned one differ. Either shows the row's changed count reading a half-made
tree until the next poll. Fix = read git's own initializing mark rather than the
planned path.

### 021. Two overlapping creates share one Cancel

The create stop handle and the step slot are one each, so the first to end
clears both: the second sheet's Cancel does nothing, its hook and its checkout
cannot be stopped, and its later steps are dropped. The row hold-back is counted
per create and is unaffected.

### 022. One agent keys a worker by name, so two of one kind share a roster place

Nothing in its payload separates them, so no report under that place answers a
prompt raised there while another worker is on it: a prompt the asking worker
answered stays on the dot until its sibling's next report. The chip counts
workers rather than places, so the number is right.

### 023. A user's list entry naming somewhere else places nothing, silently

A home-relative or absolute entry is resolved against the repository and skipped
for not being there; a parent-relative one resolves, but its destination mirrors
it out of the worktree and nothing is written outside one. What a user's entry
lacks is a spelling for where it lands.

### 024. Two agents left the catalogue and a stored id still names them

A saved tab or a preferred agent naming either raises one missing-agent alert
per run before falling back to a shell, and the flags kept against that id are
never read again.

### 025. A copy that handed over leaves its generated config behind

Only the copy holding the instance socket may sweep the shared directory, so the
file waits for a later launch that owns it.

### 026. Neither a file list nor the checkout has a timeout

A list runs until done or the pane's Cancel, which lands between paths;
`git worktree add` is unbounded by decision (worktrees.md) and the sheet's
Cancel is what ends it.

### 027. [Unconfirmed] The hardened runtime over a long session and over the CLI install

Two copies have been launched, panes opened and a gated read made in each, which
is the test signing.md records, and codesign and lldb agree. Still unconfirmed:
the AppleScript that links the CLI, which is the one thing this app scripts
itself. Fallback = drop the runtime flag from the signing helper.

### 028. [Unconfirmed] Cancel against a real checkout held by LFS or a credential helper

It is tested against a fake git that sleeps. What git leaves behind when
signalled mid-checkout, and whether the next refresh lists it, has not been
watched.

### 029. [Unconfirmed] The generated config directory's sweep at quit

The quit half runs from the terminate callback and nobody has looked in the temp
directory after one. If a file survives, the system's temp purge takes it within
days.

### 030. [Unconfirmed] The focus report's deferred hop and its first-responder check

The report reaches the store a turn after the engine raises it, a frame showing
a surface already in a window having raised it where a store write is undefined.
The store's half is tested; the hop and the check are not, the engine's path
needing a window and Metal.

### 031. [Unconfirmed] The engine's own path is untested and its zsh chain checked against a stand-in

Click-to-move does not work on the later lines of a multi-line buffer.

### 032. [Unconfirmed] An include line in that config is not followed

The wrapper loads one file and never the recursive form, so a user who splits
their config loses every part those include. The key is not on the allowed list
either. Any other relative path in the file resolves from the temporary
directory the effective config is written to.

### 033. [Unconfirmed] Whether the view is updated when every stored value compares equal

So how often the focus guard was actually firing is unknown. The guard is right
either way; what a screen would settle is whether the keyboard was being pulled
out of the sidebar filter in practice.

### 034. [Unconfirmed] The debug-trap claim under bash's array-form prompt command

The string form is tested against the system bash. The array form arrived in a
later bash this machine does not have, so that half is read off bash's source:
if it is wrong the words appear at every prompt as a command not found, and the
fix is to give the array its own entry.

### 035. [Unconfirmed] A promised drop where a source reports once for several files

The drop waits for as many reader calls as the item promised, which is the
documented contract. A source that reports once instead would make the drop wait
out its patience rather than pasting early. Fallback = retire an item on its
first failing report.

### 036. [Unconfirmed] Drops reach the frame through an undocumented search order

AppKit walks up from an unregistered engine surface to the frame that is
registered: documented for the registration, not for the order. If the engine
ever registers a dragged type the frame stops seeing drops. The same walk
carries a dragged tab past a surface to the band over it.

### 037. [Unconfirmed] Which type raised the banner that prompted that narrowing is unestablished

It followed the turn's Done by about the time a teammate's completion would,
rather than that agent's own idle timer. Both are dropped either way.

### 038. [Unconfirmed] Neither half of the banner grouping has been seen on screen

Unverified: that re-adding a request under a delivered notification's identifier
replaces its row and alerts again rather than being dropped, and that the
withdrawal takes down a banner still on screen rather than only its row in
Notification Centre.

### 039. [Unconfirmed] A withdrawal can race the add that follows it

One between the moment a waiting request leaves the pending list and the add
that follows lands a banner nothing will retract. Microseconds wide, and only
where the permission dialog has not been answered yet.

### 040. [Unconfirmed] Whether the engine puts anything between the shell and the app

The helper's walk stops at the app's own pid, checked against a real shell chain
under the test process rather than under the engine. If something unlisted sits
between, the walk ends there and the dot outlives the shell.

### 041. [Unconfirmed] The plugin bridge's directory filter

It forwards an event only when its directory matches the plugin's; that a child
session's creation and later status pass that filter is read from source, not
seen.

### 042. [Unconfirmed] An interrupted fan-out keeps its chip until the next prompt

The agent fires no hook on an interrupt and the killed workers send no stop.
Whether it sends anything sooner that could stand in has not been checked
against a run.

### 043. [Unconfirmed] An owed Done can pay in the middle of the next turn under an older helper

A worker that outlives its turn pays it there, a Done banner and dot while the
agent is working. Under a current helper the prompt clears what was owed before
its Working lands.

### 044. [Unconfirmed] A displaced failure comes back with a fresh age

The state and the note are put back but the stamp moved when the prompt took the
dot. Needs a failing stop with a worker outliving it, which nobody has seen
happen.

### 045. [Unconfirmed] A child's first message arriving before its creation would empty the roster

The plugin takes a message from a session it has not seen created as the
parent's, and a parent's prompt starts a turn. Bus order is read as creation
first; not seen. A message naming no session at all is covered.

### 046. [Unconfirmed] The plugin's cap on ended child ids

Only an ended child can leave the map, so more children alive at once than the
cap, or children whose end events the filter drops, grow it for the life of the
process. Deleting a live child's id would be worse, its later events reading as
the parent's.

### 047. [Unconfirmed] A child worker's kind where the session info lacks the field

Every such worker would show under the generic name. The kind is also in the
child's title, which the plugin does not parse. Not seen against a run.

## CI

### 048. CI never runs `make-app.sh`, so bundling and signing can break with it green

`.github/workflows/ci.yml`. CI runs `swift build` and `swift test` for both
packages plus `make lint`, and nothing else, while `make build` goes on to
`Scripts/make-app.sh` (Makefile:26), which writes the generated Info.plist
(make-app.sh:49) and signs the bundle (make-app.sh:57). A change that breaks any
of those passes CI, and nothing notices until someone runs `make build`. The
Makefile's own header says the two are meant not to drift. `make build`
completes here in under ten minutes with no warnings, so a fourth job is cheap.

### 049. CI pins the runner image but selects no Xcode, so it builds under the default

`.github/workflows/ci.yml:9`, `:17` and `:23` pin `macos-15` and never run
`xcode-select`, so the toolchain is whatever the image defaults to, which is
neither the 26 the docs state as the floor nor the 27 the developer runs.
swift-format is toolchain-sensitive, so a green CI lint does not mean a green
local one.

### 050. CI has no concurrency cancellation and no job timeouts

`.github/workflows/ci.yml`. Every push runs three full macOS jobs to completion.

### 051. CI runs neither the Markdown formatter nor a shell linter

`Makefile:57` formats Markdown and `Scripts/` holds three non-trivial bash
files. Both trees are clean today and nothing keeps them that way.

### 052. Six tests sleep a fixed interval and then assert a count did not grow

`Tests/MultishellCLITests/HelperTests.swift:125` and `:165` wait 200 ms and then
assert a count did not grow, which tests.md forbids by name. Same shape, at 200
ms to a second, at `PromisedDropTests.swift:206`, `AutosaveTests.swift:91`,
`DispatchDirectoryWatcherTests.swift:102` and
`SessionStateModelTests.swift:445`. `AppModelGitTests+Refresh.swift:294` sleeps
200 ms to land inside a fake git's one-second `status`, which is the same bet
with more headroom.

### 053. Two suites read the process-wide descriptor count without `.serialized`

`Tests/MultishellProcessTests/ProcessRunnerTests.swift:157` and `:198` declare
`ProcessRunnerFailureTests` and `ProcessRunnerCompletionTests` with a bare
`@Suite`; both call `lowestDescriptorCount` on a count other suites move, and
`DescriptorExhaustionTests` at `:251` spawns children in the same process. The
slack in each expectation (300 and 100 against leaks of 600 and 400) is what
holds it together. This is the one real serialization gap in the suite.

### 054. Two watcher tests sample the descriptor count over a fifth of a second

`Tests/MultishellAppCoreTests/Ports/DispatchDirectoryWatcherTests.swift:137` and
`:151` sample over 120 and 240 ms where tests.md says several seconds.

### 055. A main-actor AppKit suite spins the run loop without `.serialized`

`Apps/macOS/Tests/MultishellTests/AppKit/SidewaysWheelTests.swift:9` declares
`@Suite @MainActor` with no `.serialized`, and `settle()` at `:44` spins
`RunLoop.main` for 250 ms alongside four other live `@MainActor` AppKit suites.

### 056. A parser test asserts two counts are not negative, which cannot fail

`Tests/MultishellGitKitTests/Parsers/WorktreeStatusParserTests.swift:71` and
`:74`: `#expect(status.ahead >= 0 && status.behind >= 0)`. It is a crash test
whose name is its only assertion.

### 057. Three tests skip silently when node or python3 is absent

`Tests/MultishellCoreTests/Integrations/Agents/OpenCodePluginRunTests.swift:10`
carries `.enabled(if: openCodeNode != nil)`, and it is the only test of the
generated plugin. `UnixSocketTests.swift:94` and `:194` return early without
`/usr/bin/python3`, so the cross-process claim tests report as passes.

### 058. Nothing tests the four appearance setters, each of which writes and persists

`Sources/MultishellAppCore/Model/AppModel+Appearance.swift`. `setTheme`,
`setFont`, `setUIFontSize` and `reloadThemes` are named by no test in either
tree, and each mutates the workspace, persists it and pushes a theme to every
live surface. `ThemeCatalogue.relocateStrayExamples`, which moves files on disk,
is the same. `Apps/macOS/Sources` is 7,218 lines against 1,880 of test, which is
the deliberate untested-views split, but `MacPlatform.swift`, `TabDrops.swift`
and `ProjectDropDelegate.swift` are logic, not views.

### 059. [Unconfirmed] The bundle script has run through xcodebuild only under the newer Xcode

That the older one writes no build path either rests on its accessor having
looked in the bundle's resources since packages could carry them, not on a run.
The helper comes the same way, so the same expectation covers it. Fallback = the
newer Xcode.

### 060. [Unconfirmed] Nothing drives a terminal host against a real child

Untested: a closed tab's shell ending and being collected, a title reaching the
delegate, an exit code arriving, and a close after it being safe. The surface
needs a window and a GPU. Fix = a host test under a window server.

### 061. [Unconfirmed] Linux has never been compiled, locally or in CI

The counted phrases are the first thing to look at: whether the Linux Foundation
applies a plural rule at all is unchecked. If it does not, every counted phrase
answers with its own key and the number is dropped; the fallback is building
those few forms by hand.

## Perf

### 062. One commit on the trunk re-asks every branch's merge verdict

`Sources/MultishellAppCore/Model/AppModel+Merges.swift:63`, memo type at
line 138. `MergeCheck` holds `baseTip`, so a single commit on the trunk, or a
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

### 063. `git status` runs for worktrees that are collapsed or filtered out of sight

`Sources/MultishellAppCore/Model/AppModel+Runtime.swift:131`. The filter is
`isUnderConstruction`, `missingProjects` and `isDue`, and nothing asks whether
the project is expanded or the row survived the sidebar filter. `statuses` is
read by one view (SidebarView.swift), the board and the removal dialog. A dirty
worktree costs three git calls plus file reads. One
`git --no-optional-locks status --porcelain=v1 --branch` measures 14 ms on this
repository, so 50 worktrees is about 700 ms of git per five-second tick, roughly
14 percent of a core held while the app is frontmost, most of it drawing badges
nobody is looking at. Pass the visible worktree set into `refreshStatuses` and
read the rest on expand.

### 064. A drag rebuilds the sidebar or the tab strip at pointer rate

`Apps/macOS/Sources/Multishell/Sidebar/ProjectDropDelegate.swift:28`, and
`Terminals/TabDrops.swift:40`, `:97` and `:129`. `dropUpdated` and `enter`
assign the same value on every call, about 60 a second for the length of the
drag. The sidebar one writes `SidebarView.dropTarget`, which re-runs the whole
body: `SidebarFilter.apply`, `model.ordered` per project, `blockHeight` per
project and every row. The tab ones write `model.tabDrag`, read by
`TabColumnView.body` and every `TabButton.body`. `TabDragState` is already
`Equatable`, so guarding each of the four with a comparison costs nothing. Bites
from about 20 sidebar rows or six tabs.

### 065. Theme colours are parsed out of hex on every access

`Sources/MultishellCore/Theme/HexColor.swift:43` and
`Apps/macOS/Sources/Multishell/Support/Theme+SwiftUI.swift`. `Theme` keeps hex
strings. `backgroundRGB` and `foregroundRGB` are computed properties that parse
on each access, and `ansiRGB` parses all sixteen and allocates an array, so
`theme.color(for: state)` costs sixteen parses to use one. `WorktreeRow` calls
`color(for:)` once, indexes `ansiRGB` twice and pulls in `ChangeCounts` for
three more. One parse measures 238 ns in a release build, the
`trimmingCharacters` allocation dominating, so a row is about 96 parses at 23 µs
and a 40-row sidebar render is about 1 ms spent turning constants into colours.
Parse once in `Theme.init` and keep the `RGB` beside the hex.

### 066. Rows hold fresh closures, so SwiftUI can never skip one

`Apps/macOS/Sources/Multishell/Sidebar/WorktreeRow.swift:25`, `ProjectRow.swift`
and `AgentsRow.swift`. Each row stores freshly allocated closures and conforms
to no `Equatable`, which SwiftUI's structural comparison cannot match, so a
child body always re-runs when its parent does, and on every one of those it
builds `.help` strings and an accessibility label that are usually never read.
`.contextMenu` takes a non-escaping closure, so its content is built when the
modifier is applied rather than when the menu is opened: SidebarView.swift is
eight lookups per project per rebuild, TabButton.swift six per tab. An
accessibility label measures 5.5 µs and eight `String(format:)` calls 12 µs, so
about 10 to 15 µs a row, half a millisecond per sidebar rebuild at 40 rows and
2.5 ms at 200. Give the rows an `==` that ignores the closures and apply
`.equatable()`, or pass the model and an id instead.

### 067. The branch scan spawns a git process per project per tick, serially

`Sources/MultishellAppCore/Model/AppModel+Merges.swift:19`. `refreshMergeStates`
loops the projects with an `await` inside, and each runs `git for-each-ref` over
`refs/heads` and `refs/remotes` unconditionally; the `MergeCheck` memo
suppresses the follow-up queries but not the scan. Refs are not watched so it
has to poll, which worktrees.md records, but the loop is serial and unpaced. Ten
projects is ten spawns every five seconds, about 200 ms of the tick. Run the
projects in a task group and pace the scan per project.

### 068. A `cwd`-only report resolves every worktree's symlinks on the main actor

`Sources/MultishellAppCore/Model/AppModel+SessionState.swift:111`.
`worktree(atPath:)` calls `resolvingSymlinksInPath()` on every worktree in the
workspace, a `realpath` chain each, plus one for the reported path, and it runs
on the main actor for every socket report carrying no session id, which is the
hooks of an agent started outside a Multishell tab. With 50 worktrees that is 51
chains per report and an agent turn sends several; on a network-mounted worktree
each can block. Resolve each path once when `replaceWorktrees` stores it. The
per-worktree `realpath` is in the code; the blocking has not been instrumented.

### 069. The agent board is rebuilt whole on every body evaluation

`Apps/macOS/Sources/Multishell/Agents/AgentBoardView.swift` into
`Sources/MultishellAppCore/Model/AppModel+AgentBoard.swift:7`, whose own comment
says it is rebuilt each read. The body builds three dictionaries over all
projects, worktrees and tabs, then a card per live session with title, status,
subagent list and occupant name, then sorts and buckets. It re-evaluates on the
ten-second tick and on any change to `workspace`, `statuses`, `sessionStates`,
`liveSessions`, `reportedAgents` or `sessionTitles`, so a title change in one
pane rebuilds every card. Noticeable from about 30 live panes. Move the tick
into a child view and hold the board in a stored property the model invalidates.

### 070. The whole tab strip sits inside a `GeometryReader`

`Apps/macOS/Sources/Multishell/Terminals/TabBar.swift:43`. `tabViews(layout)` is
called at `:68` and `:73`, both inside the reader, so every resize frame of the
window or of a column divider rebuilds every `TabButton`, each calling
`model.state(of:)`, `model.title(of:)` and `model.agentID(of:)` and building an
accessibility label and a context menu. Read the width in the reader and hand
`layout` to a child whose body can be skipped when it has not changed. Bites
from about eight tabs per column.

### 071. The sidebar filter folds every worktree name per keystroke

`Sources/MultishellAppCore/Worktrees/SidebarFilter.swift:27`, called from
`SidebarView.swift` inside `body`. `foldedContains` is `range(of:options:)` with
case and diacritic folding, up to twice per worktree, and it drags the full row
rebuild behind it. Measured 0.53 ms for ten projects of 200 worktrees, 0.05 ms
at 40. Matters past about 300 worktrees, or sooner because it is on the
keystroke path. Fold the names once into a side table when the workspace
changes.

### 072. Row order and block height are recomputed on every sidebar rebuild

`Apps/macOS/Sources/Multishell/Sidebar/SidebarView.swift:102` and `:166`.
`model.ordered` sorts with comparators that call `workspace.displayName` and
`isActive` per comparison and use `localizedStandardCompare`, and
`worktreeOrder(for:)` scans for the project and reads `effectiveSettings` per
project. `blockHeight` additionally scans all tabs once per project. None is
cached, so all of it runs on every invalidation from 133 and from a status or
session write, not only when the list changes. Reasoned statically.

### 073. The directory watcher stats every watched directory on the main actor

`Sources/MultishellAppCore/Ports/DispatchDirectoryWatcher.swift:44` and `:57`.
`watch(_:)` runs `isStale` over every currently watched directory, each an
`Identity(ofPath:)` stat, on the main actor, and `rearmWatcher` calls it after
every refresh. The stat loop is in the code; what nobody has watched is the
stall. Microseconds locally, but a worktree on a stalled mount blocks the
window. Do the staleness check off the main actor, or only for the directories
the tick named.

### 074. The dropped-file sweep runs synchronously on the main actor at launch

`Sources/MultishellAppCore/Model/AppModel.swift:297`. `DroppedFiles.sweep()`
runs synchronously on the main actor inside `start()`, and each expired drop is
a recursive `removeItem`. Wrap it in `Self.offMain`. `host.claimSharedFiles()`
nine lines above is the same shape: a recursive `removeItem` of the generated
config directory, on the main actor, and it must stay ahead of the first
controller, so moving it off needs an await rather than a detached task.

### 075. A drag over a pane re-reads the pasteboard on every mouse move

`Apps/macOS/Sources/Multishell/Terminals/SurfaceView.swift:113` and `:159`.
`draggingUpdated` calls `draggingEntered`, which goes through `hasFiles` and so
re-reads the pasteboard, both `readObjects` and `PromisedDrop.receivers`, on
every mouse move over a pane. Re-asking the receivers is deliberate, because the
shell can exit mid-drag; re-reading the pasteboard is not. Cache the file URLs
against the `draggingSequenceNumber`.

### 076. The directory check before a shell starts runs on the main thread

A network volume that has gone away blocks until the mount times out. The
polling paths' checks run off it.

## UI/UX

### 077. The two sidebar header buttons carry no accessibility label

`Apps/macOS/Sources/Multishell/Sidebar/SidebarHeader.swift:25`. The shared
icon-button helper sets `.help` and no `.accessibilityLabel`, making the filter
and Add Project buttons the only icon-only controls in the app without one.
`IconButton.swift:17`, `TabButton.swift:169`, `DetailView.swift:104`,
`ScrollingTabStrip.swift:92`, `SidebarFilterField.swift:36` and
`TabBar.swift:154` all pair the two.

### 078. Project settings' Hooks tab overflows the window it opens in

Its last editors are below the fold with nothing saying so. Six monospaced
editors were never going to fit a window the other pages share, and
SettingsPageSizeTests records this one as deliberate so the next page to
overflow is not lost in it.

### 079. While the board is up, two commands act on a worktree nothing on screen names

Open in Editor and New Worktree still act on the selected worktree, and no
sidebar row draws as selected then. Left because neither is destructive; fix =
route them through the same predicate the pane commands use.

### 080. English only, so no layout has been seen in another language

What is unproven is the layouts, not the lookup. Several settings pages already
fit their fixed window with little to spare, and a language running much longer
than English would be what overflows them. Rows, strips and columns size
themselves off measured text, so those should give rather than clip.

### 081. A number inside a phrase carries no locale

The board's elapsed time reads with a point in a language that would write a
comma. Deliberate, the alternative making every test of it read the machine's
region; fix if it grates = a locale in the lookup and those tests pinned to one.

### 082. A tab title persisted before a language change keeps the old word

A plain shell's title starts as the translated word for Shell. It corrects
itself under zsh and bash, whose integration retitles on the next command;
another shell keeps it until the tab closes. Fix = store the default as absent
and translate where it is drawn, which changes a persisted field.

### 083. Agent settings is the one page nothing holds

Its refresh on appear reads the machine, so the page is as tall as whatever is
installed and a test would be measuring a laptop. Measured headlessly it fits
with every supported agent's hooks installed; a sixth would put it over and
nothing would say so. Fix then: the hooks rows want their own scroll.

### 084. The find bar shows no match count and no wrapped mark

The engine sends both through two actions the wrapper's bridge logs under its
default arm and forwards to no delegate, on the pinned tag and its main branch
alike. Fix = a patch to the bridge, upstreamed and the pin moved, or the wrapper
carried here. Decided against: a count is not worth carrying it.

### 085. [Unconfirmed] The rename field's accessibility container under VoiceOver

The field is inside one only while renaming; whether VoiceOver lands on it once
the Rename action opens it has not been read, the labels never having been.

### 086. [Unconfirmed] The tab strip's two split buttons have never been watched on a screen

### 087. [Unconfirmed] A cancelled divider drag

A split or column divider holds its weights in the view and writes the model
once when the drag ends, the end read off the gesture state resetting so a drag
the system cancels commits too. Nobody has watched a cancelled one; if it snaps
back, the fallback is the model's last saved weights. The sidebar divider reads
its start width the same way and is unconfirmed the same way.

### 088. [Unconfirmed] A wheel that sends lines, and a trackpad's vertical turn

The sideways scroll is watched with a mouse whose turns arrive as points. A
wheel sending lines is held to the scroller's own rate, so a notch may read as
slow; fallback = scale the swapped deltas. A trackpad's vertical gesture opens
with an event whose deltas are both zero, which the catcher does not answer for.

### 089. [Unconfirmed] A turn over the New Tab or split buttons scrolls nothing

The arrow gutters are outside the scroller but under the catcher, so a turn over
an arrow scrolls the tabs, which is wanted; over the buttons it does nothing.
Known and not fixed.

### 090. [Unconfirmed] An edit to that config lands only at the next launch

The files are read once, when the host is created, and nothing says so.

### 091. [Unconfirmed] Whether a reused surface frame leaves the keyboard in the right place

A frame asks for focus whenever the surface it holds changes, which is what
closing a pane does to the frame that keeps its index. That frames really are
reused is read off the view's identity choice rather than watched.

### 092. [Unconfirmed] The notifications settings page has never been seen on screen

Its height is held under the window's, so what is left is how it reads. The tab
band is measurable by nothing, being drawn outside the AppKit hierarchy; if it
clips, the page wants more width.

### 093. [Unconfirmed] The settings window has never been seen on screen

It is as tall as the tallest page needs, so the shortest page shows a few rows
above a great deal of nothing. Fix if it reads badly = the tall pages scroll and
the window shrinks to the rest.

### 094. [Unconfirmed] Tab-group drawing is unverified on screen

Whether bands appear as a tab crosses a terminal area, whether the insertion
line lands in the right strip, how an unfocused column reads, and whether the
scroll arrows read better than the fade they replaced. Store, model and wording
are tested; drawing is not.

### 095. [Unconfirmed] Whether a SwiftUI overlay composites above the engine's surface

The surface is Metal-backed. The focus ring has always been drawn that way, and
now the unfocused fade and the find bar too. If none appears, the fade would
have to become a view inside the frame, as its drop highlight is.

### 096. [Unconfirmed] The find bar has never been seen on a screen

Unconfirmed: the first step landing on the match nearest the prompt, the menu
acting on the bar whose field has the keyboard, the shifted Return stepping up,
the menu items enabling as bars open and close, Escape in a pane under an open
bar reaching the program, and a bar a worktree switch brings back leaving the
keyboard in the pane.

### 097. [Unconfirmed] Reordering at the edges of a strip whose tabs differ widely in width

Reordering happens as the pointer passes each tab. Such a strip could in
principle move a tab back and forth across one boundary, the tab landing under
the pointer being what stops that.

### 098. [Unconfirmed] The git badge's new width is unverified on screen

It is several times the dot and count it replaced, and it is fixed-size, so a
sidebar or board column out of room truncates the worktree name instead of the
numbers. Fallback if it crowds the row: drop the file count to the tooltip,
which already names those files.

### 099. [Unconfirmed] The reordered board card and the git indicator picker have not been seen drawn

That picker is one more section on a page whose height the settings test bounds
and which needs a window server to measure.

### 100. [Unconfirmed] Agents board drawing is unverified on screen

Whether a card reads at the column floor, where the worktree name and the badge
share a line; whether a partial column reads as more this way without arrows;
whether nested scrolling feels right to a trackpad; whether the Dock badge
appears under this build's signing. Fallback = the tab strip's arrows.

### 101. [Unconfirmed] Neither agent-flags row has been seen on screen

The value they write and the command line it builds are tested; the rows' width,
and how an empty one reads with no prompt text, are not.

### 102. [Unconfirmed] A click on the blank part of the New Tab menu's frame

Its label paints the chrome colour over the whole frame and carries a content
shape; that a click there opens the menu is not confirmed. The sidebar's sort
menu is the same shape and unconfirmed the same way.

### 103. [Unconfirmed] The subagent chip's popover

Opened on hover and held briefly after the pointer leaves so it can be crossed
onto. Whether it takes the keyboard from the terminal under it, whether crossing
onto it keeps it up, and whether one in a sidebar row survives the row's tap
gesture are all unconfirmed. Fallback = a multi-line tooltip.

### 104. [Unconfirmed] The New Tab menu's rendered agent marks

A menu item draws a title and an image and nothing else, and nobody has watched
one of those menus open. SwiftUI may drop the icon, in which case the items read
as they did before. Fallback = the titles, which say the same thing.

## Code

### 105. A view measures the drop indicator's hit split, so nothing tests it

`Apps/macOS/Sources/Multishell/Sidebar/SidebarView.swift:166`.
`blockHeight(of:metrics:)` does arithmetic over row heights, pane counts and
rename state inside a view, and layout.md says views measure nothing and are
untested. A wrong answer here is a user-visible bug with no test. Extract it
beside `UIMetrics` in `Apps/macOS/Sources/Multishell/Support/`, where it stays
because it names a Mac measurement, and cover it.

### 106. `claimedPaths` is read by seven tests and nothing in production

`Sources/MultishellAppCore/Worktrees/WorktreeWorkInFlight.swift:88`. Its only
readers are `WorktreeWorkInFlightTests` and `AppModelGitTests+Refresh`. Delete
it and have the tests assert through `isClaimed(_:)`.

### 107. `warmWorktrees` is absent from the one place per-worktree state is dropped

`Sources/MultishellAppCore/Model/AppModel.swift:107`. It is keyed by
`Worktree.ID`, written from four places, and `forgetWorktrees`
(AppModel+Runtime.swift:88), which adding.md names as the single place this
state is dropped, does not touch it. The comment says it never shrinks and gives
no reason. Either add it there or write the reason into worktrees.md.

### 108. `AppModel+Runtime` is four unrelated concerns under a name that says none

`Sources/MultishellAppCore/Model/AppModel+Runtime.swift`, 229 lines: session
reconcile and error reporting at 5 to 64, the `offMain`, `setIfChanged` and
`forgetWorktrees` utilities at 66 to 107, status polling at 109 to 188, and
activity and title notes at 190 to 229. Split into `AppModel+Reconcile`,
`AppModel+StatusPolling` and `AppModel+Activity`, and move the two utilities to
`Support/`.

### 109. Agent, shell and editor detection sits in a file named Agents

`Sources/MultishellAppCore/Model/AppModel+Agents.swift:9`.
`refreshLoginEnvironment` captures the login shell and then detects agents,
shells and editors, and rebuilds the `WorktreeCoordinator` besides. Move it into
`AppModel+Detection.swift`; the rest of the file is named correctly.

### 110. `WorkspaceStore` writes the same index lookup sixteen times

`Sources/MultishellCore/Store/WorkspaceStore.swift` holds sixteen
`firstIndex(where:)` calls, nine of them the identical
`workspace.tabs.firstIndex(where: { $0.id == id })` and two more the same over
`tabID`. `Workspace` has value lookups and no index ones, and the file defines
no `tabIndex` or `groupIndex`. Add the two and collapse all sixteen. The file's
588 lines are justified and documented, because `private(set) var workspace`
means every writer shares it, but state-and-store.md should say that this file
only grows.

### 111. The two translation test files duplicate their scanner and have drifted

`Tests/MultishellCoreTests/Text/TranslationTests.swift` (221 lines) and
`Apps/macOS/Tests/MultishellTests/Text/TranslationTests.swift` (302). About 100
lines of scanning machinery, `callSites`, `arguments`, `placeholders`,
`catalogue` and `swiftFiles`, exist in both, and they have already drifted:
`aCountedPhraseReadsAsSingularAndPlural` (:65) and
`aKeyWithNoEntryAnswersWithItself` (:136) have no app counterpart. The package
split forces the duplication. Equalise the check lists and record the pairing in
tests.md.

### 112. The window header chrome is written out twice

`Apps/macOS/Sources/Multishell/Terminals/DetailView.swift:82` and
`Agents/AgentBoardHeader.swift:26` apply the same four modifiers,
`.padding(.horizontal, 14)`, `.frame(height: UIMetrics.headerHeight)`,
`.background(theme.chromeColor)` and `.titleBarDoubleClick()`, to the same
window header. `SidebarHeader.swift:20` repeats three of the four. Make it one
`View` extension so it cannot drift.

### 113. The centred-caption styling is written out twice

`Apps/macOS/Sources/Multishell/Terminals/WorktreeOperationView.swift:27` and
`EmptyStateView.swift:24`: the same five modifiers, down to `maxWidth: 380` and
`padding(.top, 6)`.

### 114. `public` declarations named by no other target

Many `public` declarations are nested types reached through a public signature
and genuinely need it. These are confinable:
`Sources/MultishellGitKit/GitRunner.swift:11` and
`Worktrees/WorktreeService.swift:5`, public only to serve inits that only
`@testable` tests call;
`Sources/MultishellCore/Integrations/Shells/ShellStateHooks.swift:5`, `:13` and
`:67`, called from `ShellIntegration.swift` in the same module;
`Sources/MultishellCore/Store/FileDigest.swift:5` and `:7`, called only from
`SharedProjectSettings.swift`;
`Sources/MultishellCore/Model/Workspace+Repair.swift`;
`Integrations/Agents/AgentHooks.swift:62`, where `claude` is public while
`codex`, `gemini`, `copilot` and `openCode` beside it are internal and used
identically, along with `helperReference` at `:19` and `AgentHookEvent.swift`;
and `Sources/MultishellAppCore/Worktrees/WorktreeWorkInFlight.swift`, where
twelve members are public in an 89-line file nothing outside the module names,
with `AppModel.workInFlight`, `StatusReadLog.invalidate`,
`WorktreeOperations.advance` and the mutating funcs in `SessionStates.swift` the
same pattern.

### 115. Catalogue keys are split by a stray `s`, which breaks the sort into groups

Across the two catalogues: fourteen keys under `action.` and ten under
`actions.`, so `action.remove` sorts away from `actions.remove-worktree` and
`action.refresh` away from `actions.fetch`. Four under `notification.` against
nine under `notifications.`, and one `worktree.` key alone against seventeen
`worktrees.`. translation.md says the catalogue is sorted by key so that it
groups by part of the app, which this defeats. Pick one spelling per group.

### 116. A general SVG path parser lives in the Agents view folder

`Apps/macOS/Sources/Multishell/Agents/SVGPathParser.swift`, 105 lines. layout.md
gives view folders to the part of the window they draw and this draws none. Move
it to `Support/`.

### 117. Three unrelated extensions share one file

`Sources/MultishellAppCore/Detection/DisplayNames.swift` extends
`AgentCatalogue`, `EditorCatalogue` and `ShellCatalogue` in one file. The style
rule is `Type+Concern.swift` per extension, so this is three files named
`+DisplayName`. The folder's other seven files each hold one type, so this is
the only one out of line.
