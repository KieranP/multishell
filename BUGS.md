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

Last checked in full on 2026-09-23 against 61cec24, with claude 2.1.280, codex
0.155.1, gemini 0.46.0, copilot 1.0.87 and opencode 1.18.30.

| #   | Effect | What                                                                                                         |
| --- | ------ | ------------------------------------------------------------------------------------------------------------ |
| 001 | High   | A branch name runs code through a quoted placeholder in the custom agent or editor command                   |
| 002 | High   | A committed symlink carries the worktree directory out of the checkout when the directory does not exist yet |
| 003 | Medium | A zsh tab's history goes to the integration directory, not the user's own file                               |
| 004 | Medium | A Copilot subagent's own prompt and Stop read as the agent's, so the pane goes Done mid-turn                 |
| 005 | Medium | An OpenCode permission prompt reads `[object Object]` before its pattern                                     |
| 006 | Medium | [Unconfirmed] Parts of three agents' hook files have never been watched                                      |
| 007 | Medium | [Unconfirmed] Four announcing Claude notification types are missing from the deny list                       |
| 008 | Low    | Removing a stale worktree record trashes whatever directory now sits at its path                             |
| 009 | Low    | A pane attached to another pane's OpenCode server lands the dot on the server's tab                          |
| 010 | Low    | A subagent roster with no matching stop grows without bound                                                  |
| 011 | Low    | The 500-character cap guards `message` and none of the other reported strings                                |
| 012 | Low    | A recycled pid between the hangup and the kill sends SIGKILL to a stranger                                   |
| 013 | Low    | The short version string is a date and a hash, not a version                                                 |
| 014 | Low    | A shell directory variable set system-wide leaves the tab without hooks                                      |
| 015 | Low    | A greeting line shaped like an assignment swallows the login shell's first variable                          |
| 016 | Low    | A tab drag released where nothing takes it never ends                                                        |
| 017 | Low    | A repository's file is read from the project path, which a bare repository has no checkout at                |
| 018 | Low    | A git under the floor fails the worktree list with no fallback                                               |
| 019 | Low    | A tag named exactly like the base decides every merge read                                                   |
| 020 | Low    | A hand-written hook group mixing the two shapes survives Remove, or loses the user's hook                    |
| 021 | Low    | Saving stays off for the session after an unreadable, unmovable state file                                   |
| 022 | Low    | Two ways past the under-construction hold-back remain                                                        |
| 023 | Low    | Two overlapping creates share one Cancel                                                                     |
| 024 | Low    | A user's list entry naming somewhere else places nothing, silently                                           |
| 025 | Low    | Two agents left the catalogue and a stored id still names them                                               |
| 026 | Low    | A copy that failed to quit after handing over leaves its generated config behind                             |
| 027 | Low    | Neither a file list nor the checkout has a timeout                                                           |
| 028 | Low    | A cancelled create leaves its new branch, so the same name cannot be retried                                 |
| 029 | Low    | An include line in the user's Ghostty config is not followed                                                 |
| 030 | Low    | Click-to-move does not work on the later lines of a multi-line buffer                                        |
| 031 | Low    | On bash before 5.1, an array `PROMPT_COMMAND` in the user's rc silences every hook                           |
| 032 | Low    | An owed Done can pay in the middle of the next turn under an older helper                                    |
| 033 | Low    | A displaced failure comes back with a fresh age                                                              |
| 034 | Low    | Codex clamps two of our hook timeouts and warns at every launch                                              |
| 035 | Low    | Copilot's prompt mode sends SessionStart after the first prompt, clearing Working                            |
| 036 | Low    | A project hook runs wherever the user's rc file leaves the shell, not in the worktree                        |
| 037 | Low    | A misspelt `--agent` on `install-agent-hooks` writes Claude's hooks                                          |
| 038 | Low    | [Unconfirmed] The CLI install's administrator step under the hardened runtime                                |
| 039 | Low    | [Unconfirmed] A promised drop counts every item as one file                                                  |
| 040 | Low    | [Unconfirmed] Neither half of the banner grouping has been seen on screen                                    |
| 041 | Low    | [Unconfirmed] An interrupted Claude turn fires no hook                                                       |
| 042 | Low    | [Unconfirmed] The plugin's map of child ids keeps a child that never ends                                    |
| 043 | Low    | [Unconfirmed] A resumed OpenCode subagent's first message would empty the roster                             |
| 044 | Low    | [Unconfirmed] OpenCode reports Done twice at the end of each turn                                            |
| 045 | Low    | [Unconfirmed] Under fish, two dropped files named for it type a command that runs on Return                  |
| 046 | CI     | The destructive-alert suite fails on macOS 27: an alert button drops its red bezel                           |
| 047 | CI     | CI never runs `make-app.sh`, so bundling and signing can break with it green                                 |
| 048 | CI     | CI builds under Xcode 16.4, below the floor of 26                                                            |
| 049 | CI     | CI has no concurrency cancellation and no job timeouts                                                       |
| 050 | CI     | CI runs neither the Markdown formatter nor a shell linter                                                    |
| 051 | CI     | Nine tests sleep a fixed interval and then assert a count did not grow                                       |
| 052 | CI     | Two suites read the process-wide descriptor count alongside every other suite                                |
| 053 | CI     | Two watcher tests sample the descriptor count over a fifth of a second                                       |
| 054 | CI     | Seven main-actor AppKit suites run beside each other, one spinning the run loop                              |
| 055 | CI     | A parser test asserts two counts are not negative, which cannot fail                                         |
| 056 | CI     | Nine tests skip when node, python3 or a comma locale is absent, three of them as passes                      |
| 057 | CI     | Nothing tests the four appearance setters                                                                    |
| 058 | CI     | The hook-shell tests run the developer's own login shell, and two pass without running under fish or tcsh    |
| 059 | CI     | A watcher test waits out a stale unlink callback with a 900 ms sleep                                         |
| 060 | CI     | A shortcut left out of `AppShortcuts.all` passes every test                                                  |
| 061 | CI     | The project-removal trace exempts two caches `forgetWorktrees` now clears                                    |
| 062 | CI     | [Unconfirmed] The bundle script has run through xcodebuild only under the newer Xcode                        |
| 063 | CI     | [Unconfirmed] Nothing drives a terminal host against a real child                                            |
| 064 | CI     | [Unconfirmed] Linux has never been compiled, and its counted phrases would misbehave                         |
| 065 | Perf   | One fetch of the trunk re-asks every branch's merge verdict                                                  |
| 066 | Perf   | `git status` runs for worktrees that are collapsed or filtered out of sight                                  |
| 067 | Perf   | A worktree the app creates is read about four times slower on every poll until its index is written          |
| 068 | Perf   | Every git call pays about 3.6 ms for the `/usr/bin/git` shim                                                 |
| 069 | Perf   | The untracked-line count re-reads up to 500 files and 8 MiB on every read                                    |
| 070 | Perf   | Theme colours are parsed out of hex on every access                                                          |
| 071 | Perf   | Rows hold fresh closures, so SwiftUI can never skip one                                                      |
| 072 | Perf   | The branch scan spawns a git process per project per tick, serially                                          |
| 073 | Perf   | A `cwd`-only report resolves every worktree's symlinks on the main actor                                     |
| 074 | Perf   | The agent board is rebuilt whole on every body evaluation                                                    |
| 075 | Perf   | The whole tab strip sits inside a `GeometryReader`                                                           |
| 076 | Perf   | The sidebar filter folds every worktree name per keystroke                                                   |
| 077 | Perf   | Row order is recomputed on every sidebar rebuild                                                             |
| 078 | Perf   | The directory watcher stats and opens directories on the main actor                                          |
| 079 | Perf   | The dropped-file sweep runs synchronously on the main actor at launch                                        |
| 080 | Perf   | A drag over a pane re-reads the pasteboard on every mouse move                                               |
| 081 | Perf   | The directory check before a shell starts runs on the main thread                                            |
| 082 | Perf   | A bash tab spawns the helper twice per command, inline                                                       |
| 083 | Perf   | zsh forks twice per command to build the JSON it sends                                                       |
| 084 | Perf   | Export writes, stats and confines the shared file on the main actor                                          |
| 085 | Perf   | [Unconfirmed] A sidebar drag writes its drop target at pointer rate                                          |
| 086 | Perf   | [Unconfirmed] A working Claude's title spinner sets off a status read of its worktree about once a second    |
| 087 | UI/UX  | Five icon-only controls carry no accessibility label                                                         |
| 088 | UI/UX  | Project settings' Hooks tab overflows the window it opens in                                                 |
| 089 | UI/UX  | While the board is up, two commands act on a worktree nothing on screen names                                |
| 090 | UI/UX  | English only, so no layout has been seen in another language                                                 |
| 091 | UI/UX  | A number inside a phrase carries no locale                                                                   |
| 092 | UI/UX  | A tab title persisted before a language change keeps the old word                                            |
| 093 | UI/UX  | Agent settings is the one page nothing holds                                                                 |
| 094 | UI/UX  | The find bar shows no match count and no wrapped mark                                                        |
| 095 | UI/UX  | A turn over the New Tab or split buttons scrolls nothing                                                     |
| 096 | UI/UX  | An edit to the user's Ghostty config lands only at the next launch                                           |
| 097 | UI/UX  | A large git badge overflows a row or card at its minimum width                                               |
| 098 | UI/UX  | The Hooks tab's caption is wrong for csh and tcsh, and for shells the runner swaps for `/bin/sh`             |
| 099 | UI/UX  | [Unconfirmed] The rename field's accessibility container under VoiceOver                                     |
| 100 | UI/UX  | [Unconfirmed] The tab strip's two split buttons have never been watched on a screen                          |
| 101 | UI/UX  | [Unconfirmed] A cancelled divider drag                                                                       |
| 102 | UI/UX  | [Unconfirmed] A wheel that sends lines, and a trackpad's vertical turn                                       |
| 103 | UI/UX  | [Unconfirmed] Whether a reused surface frame leaves the keyboard in the right place                          |
| 104 | UI/UX  | [Unconfirmed] The notifications settings page has never been seen on screen                                  |
| 105 | UI/UX  | [Unconfirmed] The settings window is as tall as its tallest page                                             |
| 106 | UI/UX  | [Unconfirmed] Tab-group drawing is unverified on screen                                                      |
| 107 | UI/UX  | [Unconfirmed] Whether a SwiftUI overlay composites above the engine's surface                                |
| 108 | UI/UX  | [Unconfirmed] The find bar has never been seen on a screen                                                   |
| 109 | UI/UX  | [Unconfirmed] The reordered board card and the git indicator picker have not been seen drawn                 |
| 110 | UI/UX  | [Unconfirmed] Agents board drawing is unverified on screen                                                   |
| 111 | UI/UX  | [Unconfirmed] Neither agent-flags row has been seen on screen                                                |
| 112 | UI/UX  | [Unconfirmed] A click on the blank part of the New Tab menu's frame                                          |
| 113 | UI/UX  | [Unconfirmed] The subagent chip's popover                                                                    |
| 114 | UI/UX  | [Unconfirmed] The New Tab menu's rendered agent marks                                                        |
| 115 | UI/UX  | [Unconfirmed] A later alert layout takes Return off the removal button                                       |
| 116 | Code   | A view measures the drop indicator's hit split, so nothing tests it                                          |
| 117 | Code   | `claimedPaths` is read by four tests and nothing in production                                               |
| 118 | Code   | `warmWorktrees` is absent from the one place per-worktree state is dropped                                   |
| 119 | Code   | `AppModel+Runtime` is four unrelated concerns under a name that says none                                    |
| 120 | Code   | Agent, shell and editor detection sits in a file named Agents                                                |
| 121 | Code   | `WorkspaceStore` writes the same tab index lookup nine times                                                 |
| 122 | Code   | The two translation test files duplicate their scanner                                                       |
| 123 | Code   | The window header chrome is written out twice                                                                |
| 124 | Code   | The centred-caption styling is written out twice                                                             |
| 125 | Code   | `public` declarations named by no other target                                                               |
| 126 | Code   | Catalogue keys are split by a stray `s`, which breaks the sort into groups                                   |
| 127 | Code   | The marks' SVG path parser lives in the Agents view folder                                                   |
| 128 | Code   | The one-worktree status read applies the bulk read's guards differently                                      |
| 129 | Code   | The app imports MultishellProcess, which neither manifest gives it                                           |
| 130 | Code   | A retry and its label are two optionals the alert reads apart                                                |
| 131 | Code   | Two comments state what the code does not                                                                    |
| 132 | Code   | Editor launches are built by `AgentLaunch`                                                                   |
| 133 | Code   | `SocketFailure` and fifteen other types sit in another type's file                                           |
| 134 | Code   | Seven comments outside the tests run past two lines, and 282 inside them                                     |
| 135 | Docs   | libintl is LGPL and linked statically, from a libghostty someone else built                                  |

## High

### 001. A branch name runs code through a quoted placeholder in the custom agent or editor command

`AgentFlags.expand` (`AgentFlags.swift:53-55`, `:70`), called from
`AppModel+Agents.swift:170-173`, and `EditorCatalogue.customCommandLine`
(`EditorCatalogue.swift:108-114`) drop `ShellQuoting.quote(value)` into the line
the user wrote, and the login shell runs the result. Inside the user's own
double quotes the value's single quotes are plain characters, and inside the
user's single quotes they close and reopen them, so either way a `$(…)` in the
value runs. git accepts `feat$(date>ran)` as a branch name, and the slug keeps
it (`WorktreeSettings.swift:55-58` replaces only `/` and space), so `{path}`
carries it too. Shown against the real `MultishellCore`:
`expand("echo \"on {{branch}}\"", …)` gave `echo "on 'feat$(date>ran-agent)'"`,
`customCommandLine("echo \"{path}\"", …)` gave the same shape, and each run
through `/bin/zsh -c` created its file; a single-quoted placeholder ran too. It
needs the placeholder quoted, which the help text (app `Localizable.strings:32`)
invites by saying only that placeholders are filled in, and a local branch
someone else named, such as a checked-out pull request.
`Docs/design/agents.md:226-229` calls the doubled quoting cosmetic and
`:215-217` says a pushed branch cannot run anything; the zsh check at `:218-221`
never quoted a placeholder. Fix = hand the values over in the environment and
have the line read `"$MULTISHELL_BRANCH"`, or refuse a placeholder that sits
inside quotes.

### 002. A committed symlink carries the worktree directory out of the checkout when the directory does not exist yet

`RepositoryContainment.holds(directory:)` (`RepositoryContainment.swift:8-11`)
checks what `resolvingSymlinksInPath()` gives back, and that returns a path that
does not exist unchanged, so a symlink partway along is never followed. Before
the first create the container has not been made, so this is the ordinary case.
Shown in a scratch repository with `wt -> ../outside` committed and
`"worktreeDirectory": "wt/new"` in `.multishell.json`: `confined(to:)`
(`SharedProjectSettings.swift:138-147`) kept it, the trust dialog read `wt/new`,
and the real `WorktreeCoordinator.add` made the worktree at
`outside/new/feature`. The re-confine at create
(`AppModel+SharedSettings.swift:89-99`) calls the same function. The user still
has to trust the file, but is shown a path that reads as inside the checkout.
`Docs/design/settings.md:25`, "a committed link cannot carry it out", is wrong
for any directory not yet made, including the `~/.claude/skills` case at
`:18-20`. Fix = resolve the deepest ancestor that exists, as
`WorktreeFiles.deepestExistingAncestor` does, append the rest, then check.

## Medium

### 003. A zsh tab's history goes to the integration directory, not the user's own file

macOS's `/etc/zshrc:16` sets `HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history`, and it
runs between our `.zprofile` and our `.zshrc`. Our `.zprofile` hands ZDOTDIR
back to our own directory (`ShellStateHooks.swift:52`, `restoreToSelf`), so at
that moment it names `~/Library/Application Support/Multishell/integration/zsh`.
A user whose own files set no HISTFILE gets a Multishell-only history there, and
`~/.zsh_history` never sees a command typed in a tab. Shown by starting
`zsh -il` with an empty home and ZDOTDIR on a copy of the generated files:
`HISTFILE=<copy>/.zsh_history`. Not seen on this machine because its `.zshrc`
sets HISTFILE. Fix = have our `.zshrc` put HISTFILE back when it still points
into our directory.

### 004. A Copilot subagent's own prompt and Stop read as the agent's, so the pane goes Done mid-turn

Watched against Copilot 1.0.87. A worker's hooks carry the child's own
`session_id` and no `agent_id`, and the child fires its own `UserPromptSubmit`
and `Stop`. The reader keys workers only by snake-case `agent_id`
(`AgentHookPayload.swift:48-50`, `AgentHookEvent.swift:55-67`), so the helper
sends those as the agent's turn and its Done: the pane goes Done in the middle
of the turn, once per subagent. `SubagentStart` fires under the Pascal spelling
the file asks for but with the camel payload (no `hook_event_name`, only
`agentName`), which the guard at `AgentHookPayload.swift:39-42` refuses, so no
worker ever reaches the roster and no chip shows. `SubagentStop` does carry
`agent_id`, a different key from the name the start would give. The comment at
`AgentHooks.swift:147-148` and `Docs/design/agents.md:313-321` describe the name
as the key at both ends, which no longer holds.

`COMPAT.md:51` still answers Yes to workers for Copilot CLI.

### 005. An OpenCode permission prompt reads `[object Object]` before its pattern

Watched against OpenCode 1.18.30. `asked()` at `OpenCodePlugin.swift:17-22`
joins `properties.tool` into the message, but in v2's PermissionRequest that
field is `{messageID, callID}`; the tool's name is `properties.permission`. The
helper was sent `--message "[object Object] echo hi"`. The comment at `:15-16`
misreads the type, and `OpenCodePluginRunTests.swift:52-54` passes `tool` as a
string, so the test cannot catch it; the fix starts by giving that fixture the
real shape.

### 006. [Unconfirmed] Parts of three agents' hook files have never been watched

Claude, Codex and Copilot were run with their hooks pointed at a capture script.
Each event they fired reached the helper as spelled, with the agent's own pid.
Still unwatched: Codex's hook trust (the run bypassed it) and its
PermissionRequest and Interrupt; Gemini past SessionStart, its free tier no
longer authenticating; Copilot's `notification`, and its reading of the
user-level `~/.copilot/hooks` rather than a repository's. Step: trust the hook
once with `/hooks` in Codex and start a session without the bypass flag.

### 007. [Unconfirmed] Four announcing Claude notification types are missing from the deny list

`idle_prompt` was watched arriving 60 s after a Stop and dropped, as intended.
The 2.1.280 binary sends every OS notification through the same hook, and its
type list is fifteen long where `AgentHooks.swift:54` says fourteen. Of those,
`computer_use_enter` and `computer_use_exit` announce, and so do
`elicitation_complete` and `elicitation_response`, which are sent outside the
enum; none is on the list at `AgentHooks.swift:56-58`, so each would read as
Waiting and raise a banner. Probably also `push_notification` and the two
`quota_auto_resume_*` types. None was watched arriving.

## Low

### 008. Removing a stale worktree record trashes whatever directory now sits at its path

`WorktreeCoordinator.swift:212-223` asks only `fileExists` before handing the
path to the Trash, or to `removeItem` under the delete-outright setting, and
never checks that the directory is still this worktree;
`WorktreeListParser.swift:24` keeps `locked` and drops `prunable`. Shown through
the real coordinator: worktree `old` added, its directory deleted, a new
directory holding `notes.txt` made at the same path. git listed the record as
`prunable gitdir file points to non-existent location`, `refresh` still returned
it, and `remove` with a delete closure removed `notes.txt`. It needs a worktree
folder deleted by hand and its path later taken by something git did not make,
since `git worktree add` refuses such a path. Under delete-outright the
directory is gone for good. Fix = refuse to trash a `prunable` record, or one
whose `<path>/.git` does not point back at it, and forget the record alone.

### 009. A pane attached to another pane's OpenCode server lands the dot on the server's tab

`OpenCodePlugin.swift:39` spawns the helper from the server's process, and the
helper reads `MULTISHELL_SESSION` from its environment (`Helper.swift:102`).
Plain `opencode` and `opencode run` serve in their own process, so this needs
`opencode attach <url>` or `run --attach` from a second pane; the report then
carries the first pane's session with the second pane's cwd. Only the plugin has
this: every other agent's hook runs in the session's own process.

### 010. A subagent roster with no matching stop grows without bound

`SessionStates+Entry.swift:66`. `keep(_:)` appends a `Subagent` for every unseen
id (`:87-92`), and only `settleTurn()` empties the roster: on a new turn, on
idle or error, on a finished command, on the user's clear, or when the pid goes
(`SessionStates.swift:48`, `:196`, `:270`, `:308`, `:337`). An agent that emits
`SubagentStart` with fresh ids, never a matching `SubagentStop` and never a
`UserPromptSubmit` grows `entry.workers` for as long as it runs. Every name goes
into the chip's accessibility label on each render
(`AccessibilityText+Agents.swift:30`), and the popover draws a row for each. The
`.done where !entry.workers.isEmpty` arm at `SessionStates.swift:176` also holds
the agent's Done, so the tab never shows it finished.

### 011. The 500-character cap guards `message` and none of the other reported strings

`SessionStateReport.swift:96` and `:128` cap `message`, with the reasoning at
`:126-127` that any process of the user's may write a line. `SubagentReport`'s
`type` and `id` decode uncapped, and so do the report's `agent` and `cwd`, and
the first word of `command` (`:157`). A 61 KB line, under the 64 KB
`UnixSocketServer.maximumLineLength`, decoded with a 60,000-character id and a
1,000-character type kept whole. `type` is joined into the chip's accessibility
label on every render of the pane row and the board card, and `agent` is drawn
verbatim through `AgentCatalogue.displayName` when it names no known agent.

### 012. A recycled pid between the hangup and the kill sends SIGKILL to a stranger

`Sources/MultishellProcess/ProcessStopper.swift:77-87`. After
`kill(-pid, SIGHUP)`, a block three seconds later probes with `kill(-pid, 0)`
and sends `kill(-pid, SIGKILL)`. The `leadsGroup` path checks nothing about who
answered; the comment at `:85` assumes an answering group is ours. The group
must first empty, and macOS hands out pids in sequence, so reuse needs the pid
counter to wrap within `killGrace` and the new process to lead its own group.
Callers are hooks, git runs and worktree creation. Checking `process.isRunning`
would break the grandchild case the group kill exists for (`:84`), so the fix is
an identity check.

### 013. The short version string is a date and a hash, not a version

`CFBundleShortVersionString` comes from `bundle_version` at
`Scripts/build-lib.sh:18-25`, which prints `<commit date>-<short hash>` with
`-dirty` for a modified tree, giving `2026.09.23-7cc99c7-dirty`. That breaks
Apple's three-integer form for the key, so any DMG or store path needs it
changed first. Sparkle compares `CFBundleVersion` by default, which is the
commit count, so an update feed may not. TODO.md's release-workflow entry covers
it.

### 014. A shell directory variable set system-wide leaves the tab without hooks

`ShellStateHooks.swift:13-63` and `SessionEnvironment.swift:46-54`; the cost is
recorded at `Docs/design/terminals.md:55-56`. zsh reads the rest of the chain
from wherever ZDOTDIR points at that moment. A system file relocating it steers
zsh past our files: `/etc/zshenv` runs before any of ours and cannot be
overridden, so a ZDOTDIR set there skips all three, and one set in
`/etc/zprofile` skips `.zprofile` and `.zshrc`. Both shown in a scratch ZDOTDIR.
The user's own files relocating it are followed. No fallback short of appending
to that directory's rc file, which the design refuses.

### 015. A greeting line shaped like an assignment swallows the login shell's first variable

`LoginShellEnvironment.swift:62-88`. The captured environment is read from the
first line that looks like an assignment, so an rc file's greeting is skipped
unless it looks like one, in which case it is taken for the first variable and
swallows the real one. Shown with `motd=welcome back` in a scratch `.zshrc`:
HOME was lost and a `motd` key appeared. Only PATH is read
(`AppModel+Agents.swift:23`, `:39`), so it bites only when PATH is the first
variable env prints; the fallback is the process's own PATH. Fix = a marker
printed by the `-c` command before `env -0`, which the greeting always precedes.

### 016. A tab drag released where nothing takes it never ends

The bands mount on `drag.isDragging` (`TabColumnView.swift:53`), the drag starts
at `TabButton.swift:41-42`, and only a drop clears it (`TabDrops.swift:18`,
`SidebarView.swift:232`); `begin` clears it on the next drag
(`TabDragState.swift:33`). `.onDrag` has no cancellation callback at the macOS
14 floor, so every column keeps its clear drop target and its accessibility
label over the terminal area until then. The bands stay hidden (`:29`). Whether
the stale overlay's content shape takes clicks meant for the terminal is
unchecked, which would raise the rank. macOS 26 has `onDragSessionUpdated` with
an ended phase; whether it fires for an `.onDrag` drag is unchecked.

### 017. A repository's file is read from the project path, which a bare repository has no checkout at

`AppModel+SharedSettings.swift:52-54` and `:77-79`,
`SharedProjectSettings.swift:82-92`. `project.path` is the first record of
`git worktree list`, which for a bare repository is the `.git` directory itself,
so a bare project never picks up a shared `.multishell.json`. Reading it through
git instead skips the checkout-based symlink confinement (`confined(to:)`), so
that design would need revisiting. It already misses a directory not yet made
(002).

### 018. A git under the floor fails the worktree list with no fallback

`WorktreeService.swift:34` (the list), `:55` (`mainWorktree`, so adding a
project fails too) and `:234` (`isListed`, where nil counts as listed, the safe
way round) all pass `-z`, which git gained in 2.36, the floor in
`Docs/develop/dependencies.md`. An older git refuses the switch; the row dims
and one alert shows git's error (`AppModel+Projects.swift:112-120`). Left
because the supported macOS ships a newer one; fix if it bites = retry without
`-z` at `:34` and `:55`.

### 019. A tag named exactly like the base decides every merge read

The base is stored in git's short form (`DefaultBranch.swift:49`) and passed
bare to `branch --merged`, `cherry`, `rev-list` and `diff`
(`WorktreeService+Merges.swift:17`, `:39`, `:49`, `:62-63`); only the branch
side is qualified (`:10`). git resolves the ambiguous name to the tag. Shown in
scratch repositories: a tag `main` at an old commit hid merged work, and a tag
`main` at the tip of an unlanded branch listed that branch as merged, which
`WorktreeCoordinator+Merges.swift:57-59` then records as `.merged(.ancestor)`. A
tag named `origin/main` ties with the remote-tracking ref the same way, so
`Docs/design/merged-branch.md:85-87` is wrong where it says one cannot.

### 020. A hand-written hook group mixing the two shapes survives Remove, or loses the user's hook

`AgentHookIntegration+Install.swift:95-115`. `isMultishellGroup` counts a
group's own `command` as ours, and `withoutOurHooks` filters only the group's
`hooks` list, dropping the group whole when it has none. Replayed on copies of
those functions: our bare command beside the user's `hooks` list survives
Remove, and the user's bare command beside our `hooks` list is deleted with it.
No agent writes that shape and Add never produces it, so both need hand-editing.

### 021. Saving stays off for the session after an unreadable, unmovable state file

`refusesToSave` is set once in `restored()` (`WorkspaceStore.swift:35`) and
never cleared; a recorded cost at `Docs/design/state-and-store.md:24-26`.
Permissions fixed while the app runs are not noticed until relaunch, and the
session's work goes at quit. The launch alert (`Localizable.strings:97`) says
nothing will be saved "until it is readable or moved away", which promises the
recovery the code does not make.

### 022. Two ways past the under-construction hold-back remain

The create claims its planned path (`AppModel+WorktreeCreation.swift:70-73`,
`:204-209`, standardized but not symlink-resolved), and the status and merge
reads skip what is claimed (`AppModel+Worktrees.swift:77-79`). A checkout run in
a terminal is never claimed, and on a symlinked volume git lists the resolved
path, which differs from the planned one. Either shows the row reading a
half-made tree until the next poll. Fix = git's own mark: the list prints
`locked initializing` for a worktree still being made, and
`WorktreeListParser.swift:24` keeps only `isLocked` and drops the reason.

### 023. Two overlapping creates share one Cancel

`WorktreeWorkInFlight.swift:13` holds one `creation` slot, which `beginCreation`
overwrites and `endCreation` clears whoever owns it (`:61-67`); the create's
`defer` also clears the step slot (`AppModel+WorktreeCreation.swift:74-79`). So
the first to end clears both: the second sheet's Cancel does nothing, its hook
and checkout cannot be stopped, and its later steps are dropped (`:46-49`). The
row hold-back is counted per create and is unaffected. The route to a second
sheet is Cmd-N, which is not gated while the first creates
(`MultishellCommands.swift:18`); not watched on screen.

### 024. A user's list entry naming somewhere else places nothing, silently

`WorktreeFiles.swift:40-44` joins every entry onto the repository and skips an
absent source, and `:57-61` skips a destination outside the worktree. Replayed:
`~/.zshrc` became `repo/~/.zshrc` and `$HOME/.zshrc` `repo/Users/…/.zshrc`, both
skipped for not existing; `../shared/.env` resolved, but its destination was the
source file itself, outside the worktree, and was skipped. None records a
failure. What a user's entry lacks is a spelling for where it lands.

### 025. Two agents left the catalogue and a stored id still names them

Aider (`aider`) and Cursor Agent (`cursor-agent`) left `AgentCatalogue.swift`
in 9026745. A saved tab's `agentID` (`TerminalSession.swift:14`) or a preferred
agent (`Workspace.swift:27`, `ProjectSettings.swift:28`) naming either fails the
lookup at `AppModel+Agents.swift:176-179` and raises one missing-agent alert per
id per run before falling back to a shell. The alert names the raw id, so it
reads "Install aider…" about a tool that may be installed. The flags kept
against that id never reach a launch, but Settings still shows and edits them
while it is the preferred agent.

### 026. A copy that failed to quit after handing over leaves its generated config behind

A hand-over returns from `start()` before `claimSharedFiles` and before any
session opens (`AppModel.swift:290`), then terminates with no terminals open, so
the ordinary case writes no file. Only the "still here" fallback
(`AppModel+SessionState.swift:16-18`), where terminate did not exit, runs on
without the instance socket; a tab opened in it writes a config its quit will
not sweep (`GhosttyTerminalHost.swift:37-40`), and it waits for a later launch
that owns the directory. `Docs/design/terminals.md:184-188` and `:346-348` say a
copy that handed over keeps its terminals, which the code contradicts.

### 027. Neither a file list nor the checkout has a timeout

A list runs until done or the pane's Cancel, which is checked once per path
(`WorktreeFiles.swift:39`), so one large copied path cannot be stopped partway
(`:71-72`). `git worktree add` is unbounded by decision
(`Docs/design/worktrees.md:121-125`, `WorktreeService.swift:190-205`) and the
sheet's Cancel is what ends it, which 023 can take away. The hooks do have a
timeout (`WorktreeCoordinator.swift:182-189`).

### 028. A cancelled create leaves its new branch, so the same name cannot be retried

Cancel stops `git worktree add` through `ProcessStopper.end`, and the app
returns without cleaning up (`AppModel+WorktreeCreation.swift:96-100`). Shown
with a smudge filter that hangs, both from a script and through the app's own
`coordinator.add`: git removes the worktree directory and its record, and the
next refresh lists only main, but the new branch stays, so retrying the same
name fails with `a branch named '…' already exists`. An empty container
directory stays too, which `Docs/design/worktrees.md:118-120` says a refused add
never makes. Fix = after a stopped add that created its branch, delete the
branch if no worktree lists it.

### 029. An include line in the user's Ghostty config is not followed

`GhosttyUserConfig.swift:35-52` is the allow list and `config-file` is not on
it, so `usable` (`:83-88`) drops the line; the wrapper calls only
`ghostty_config_load_file` and never `load_recursive_files` (libghostty-spm
`TerminalController+Config.swift:181-182`). Shown with a test: a user file
including another that sets `font-size = 21` gave 13. A user who splits their
config loses every part those include. Any other relative path in the file
resolves from the temporary directory the effective config is written to
(untested). Fix = bind `load_recursive_files` in a wrapper patch, or expand
`config-file` lines before filtering.

### 030. Click-to-move does not work on the later lines of a multi-line buffer

They need continuation-prompt marks, which neither integration writes;
`Docs/design/terminals.md:105-107` records it as the cost of writing no end
mark. The zsh chain's test runs against a stand-in bootstrap
(`PromptMarkTests.swift:352-378`); run once against the pinned engine's real
file, both halves loaded and every mark appeared.

### 031. On bash before 5.1, an array `PROMPT_COMMAND` in the user's rc silences every hook

`init.bash:125-128` takes the array form when the user's `PROMPT_COMMAND` is an
array, whatever the bash. Bash 3.2, the system bash, runs only element 0, so the
claim, the marks and the arm never run and the tab reports nothing; the helper
log stayed empty. On bash 5.2 the array form works: the trap is claimed, taken
back from a late installer and chained. Fix = take the array branch only when
`BASH_VERSINFO` is 5.1 or later.

`COMPAT.md:30` promises state dots on bash 3.2 and newer without this caveat.

### 032. An owed Done can pay in the middle of the next turn under an older helper

A worker that outlives its turn pays its Done when it ends, and without a
`startsTurn` on the next prompt nothing clears what was owed
(`SessionStates.swift:48`, `:161`, `:203-206`, `:235-242`). Replayed through
`SessionStates` in the older helper's shape: the worker's end returned `.done`
while the agent worked; with `startsTurn` it returned `.running`. The current
helper sends `turn`, so only a helper link left by a build between f84fed6 and
8ca4d32 (2026-09-12 to 2026-09-18) hits it.

### 033. A displaced failure comes back with a fresh age

`restore` at `SessionStates.swift:243-249` puts the state and note back, and
`stampChanges` (`:344-351`) then sees a state change and stamps the current
time. Replayed: a failure stamped at 1000 came back at 1040. The real trigger
needs a failing stop with a worker outliving it, emptied by `settleTurn`
(`:195-197`) and brought back by a later tool call (`:88-92`), which nobody has
seen happen.

### 034. Codex clamps two of our hook timeouts and warns at every launch

We write `timeout: 5` for every event (`AgentHooks.swift:15`); Codex 0.155.1
prints `warning: clamping SessionEnd hook timeout to 3s` and the same for
Interrupt on each start. Seen with the hooks given through `-c`; that it also
prints for `~/.codex/hooks.json` is expected but unwatched.

### 035. Copilot's prompt mode sends SessionStart after the first prompt, clearing Working

Watched in `copilot -p`: `UserPromptSubmit` arrived 86 ms before `SessionStart`,
so the start's idle report takes the Working off until the first tool call. An
interactive session was not run.

### 036. A project hook runs wherever the user's rc file leaves the shell, not in the worktree

`runScript` (`ShellCommand.swift:56-78`) sets the child's directory and starts
`$SHELL -l -i -c` (`:146-151`), so the rc files run before the script, and a
`.zshrc` that ends in `cd ~/code` moves every pre-create, post-create and delete
hook there; a post-create `npm install` runs in the wrong tree. Shown with the
suite's own test: under `SHELL=/bin/zsh` and a scratch ZDOTDIR whose `.zshrc` is
`cd /`, `aScriptStopsAtItsFirstFailingLineWhereTheShellCanBeTold` fails at
`ProcessRunnerTests.swift:344`, `first.txt` not written where it was asked.
`Docs/design/hooks.md:9` does not record it. Fix = prepend a `cd` to the hook's
directory where `set -e` and the stderr marker are prepended (`:94-111`).

### 037. A misspelt `--agent` on `install-agent-hooks` writes Claude's hooks

`Helper.swift:72-75` reads the agent through `agentID(in:)` (`:211-218`), which
falls back to Claude when `--agent` is missing; its comment gives the reason for
a hook, not for a command a person types. `state`, `command-started` and
`command-finished` go through `Options`, which refuses an argument it does not
know (`:265-287`). Shown by building the helper and running
`multishell install-agent-hooks --agnet codex --print`: it printed Claude's hook
set, each entry `agent-hook --agent claude`. Without `--print` the same line
writes `~/.claude/settings.json`, and `remove-agent-hooks` with the same slip
removes Claude's. Fix = parse both through `Options`, with `--print` a flag and
`--agent` required, and keep the lenient read for `agent-hook` and
`claude-hook`.

### 038. [Unconfirmed] The CLI install's administrator step under the hardened runtime

`AppleScriptHandler.swift:9-14` runs
`do shell script … with administrator privileges` through an event sent to the
app itself (`:31-41`). A probe signed with the runtime flag and no entitlements
ran the same handler with a plain `do shell script`, so the runtime does not
block that; the running app is hardened, so a long session is covered too.
Unconfirmed: the authorization prompt. Step: Settings > Agents > Install, enter
the password, then `ls -l /usr/local/bin/multishell`. Fallback = drop the
runtime flag from the signing helper.

### 039. [Unconfirmed] A promised drop counts every item as one file

`PromisedDrop.swift:34` builds the collector from `fileNames.count` before
`receivePromisedFiles` is called (`:40-44`), and the SDK header says `fileNames`
is empty until then; a headless probe read `[]` for both of two promises. So
every item expects one report, whatever it promised. A legacy source promising
several files in one item would retire on its first report, answer the drop, and
the later files would land in the directory but never be pasted. Needs such a
source to watch. `PromisedDropTests` pass explicit counts, so the `fileNames`
path is untested. Fix = read `fileNames` after the promise is called in, or
retire an item on its first report.

### 040. [Unconfirmed] Neither half of the banner grouping has been seen on screen

`UserNotificationNotifier.swift:34-38` and `:57-58`. Apple documents a reused
identifier replacing a scheduled request, not a delivered one, and the
withdrawal as leaving Notification Centre, not the screen. Unverified: that a
re-add under a delivered identifier replaces its row and alerts again, and that
the withdrawal takes down a banner still showing. Step: get two Done banners
from one unfocused pane a few seconds apart, check Notification Centre holds one
row, then focus the pane while a banner is up.

### 041. [Unconfirmed] An interrupted Claude turn fires no hook

Watched in 2.1.280: Escape mid-turn fired nothing, and the next hook came 37 s
later when background work finished, so the dot stayed Working meanwhile. That
run's subagents were async, which is all 2.1.280 launched even when asked for
foreground, and Escape did not kill them; they sent their own SubagentStop. A
fan-out an interrupt kills was not produced, so whether its chip holds until the
next prompt is unwatched. Step: start a turn with a foreground subagent, press
Escape, kill it from the tasks view, and see whether any hook fires.

### 042. [Unconfirmed] The plugin's map of child ids keeps a child that never ends

`OpenCodePlugin.swift:50-67`. Only an ended child can leave the map (cap 64 at
`:60`), so one that never sends an idle or an error stays for the life of the
process. None is known in 1.18.30: a child's idle and status events pass the
bridge's directory filter. An interrupted fan-out has not been run. Deleting a
live child's id would be worse, its later events reading as the parent's.

### 043. [Unconfirmed] A resumed OpenCode subagent's first message would empty the roster

A task resumed by `task_id` reuses its session and publishes no
`session.created` (opencode `tool/task.ts:136-137`, `:157`). If its id is no
longer in the plugin's map, after an opencode restart for instance, its first
message reads as the parent's prompt and starts a turn. Not run.

### 044. [Unconfirmed] OpenCode reports Done twice at the end of each turn

Both `session.status` idle and the deprecated `session.idle` arrive, and
`OpenCodePlugin.swift:91` and `:112` each send `state done`; the capture shows
two helper calls. Whether the app raises two Done banners is untraced.

### 045. [Unconfirmed] Under fish, two dropped files named for it type a command that runs on Return

A drop always gets POSIX single quotes (`FileDrop.swift:11`,
`ShellQuoting.swift:12-18`), and the catalogue offers fish and nu
(`ShellCatalogue.swift:15`). Fish treats `\'` and `\\` as escapes inside single
quotes, so a first file named `a\` becomes `'/dir/a\' ` and runs on into the
second name, and a second named `x; touch pwned; #` then reaches the shell
unquoted. Nothing runs until Return, which is what a user presses after a drop,
and both names can come from one unpacked download. Under nu a name holding `'`
breaks the line instead. Reasoned from fish's documented quoting; fish is not
installed here. Fix = quote for the pane's shell, or leave out a name carrying a
backslash, as control characters already are.

## CI

### 046. The destructive-alert suite fails on macOS 27: an alert button drops its red bezel

`DestructiveAlertTests.theLeadChoiceIsPaintedRedOverTheDefaultButtonsAccent`
fails at `DestructiveAlertTests.swift:40` on this machine: `bezelColor` reads
back nil. On an NSAlert's button, setting `.systemRed`
(`DestructiveAlert.swift:33`) is lost at every step, where a free-standing
NSButton keeps it. So the removal confirmations are probably not drawn red on
macOS 27 either; not looked at on screen. CI's macos-15 runner is on an older OS
and may stay green.

Still failing at 61cec24, `alert.buttons.first?.bezelColor → nil`; the suite's
other five tests pass, including
`aLayoutTakesReturnOffTheLeadChoiceAndItGoesBackOn`.

### 047. CI never runs `make-app.sh`, so bundling and signing can break with it green

`.github/workflows/ci.yml:12-13`, `:20`, `:26-27` run `swift build`,
`swift test` and `make lint`, and nothing else, while `make build` goes on to
`Scripts/make-app.sh` (Makefile:29), which checks the binaries (`verify_binary`,
make-app.sh:33, :38), writes the Info.plist (:49) and signs (:64-66). A change
that breaks any of those passes CI. The Makefile's header (:1-2) says the two
are meant not to drift.

Nor do CI or `make test` compile a release configuration, so the `#else` arm of
`Paths.swift:27`, which names the installed app's state, socket and integration
without a suffix, and any optimiser-only diagnostic are seen only by
`make release`.

### 048. CI builds under Xcode 16.4, below the floor of 26

`ci.yml:9`, `:17` and `:23` pin `macos-15` and never select an Xcode, so the
image's default, 16.4 (image 20260907), builds it: below COMPAT.md's floor of 26
and far from the 27 developers run. The image carries 26.0.1 to 26.3, so
`DEVELOPER_DIR` can pick one. swift-format is toolchain-sensitive, so a green CI
lint does not mean a green local one.

### 049. CI has no concurrency cancellation and no job timeouts

`.github/workflows/ci.yml`. `:3-5` trigger on both `push` and `pull_request`
with no branch filter, so a push to a branch with a pull request open runs the
three macOS jobs twice, six in all, each to completion.

### 050. CI runs neither the Markdown formatter nor a shell linter

`Makefile:62` formats Markdown, and `Scripts/` holds three bash files of 198, 68
and 97 lines. `prettier --check` passes today; the shell half is unchecked, no
shellcheck being installed here. Nothing keeps either clean.

### 051. Nine tests sleep a fixed interval and then assert a count did not grow

tests.md:300-301 forbids it by name. `HelperTests.swift:125` and `:165`,
`PromisedDropTests.swift:206` and `:220`, `AutosaveTests.swift:91`,
`DispatchDirectoryWatcherTests.swift:102`, `SessionStateModelTests.swift:445`
and `:517`, and `AppModelTests.swift:387`, waiting 200 ms to a second.
`AppModelGitTests+Refresh.swift:294` sleeps 200 ms to land inside a fake git's
one-second `status`, the same bet with more headroom, and
`DispatchDirectoryWatcherTests.swift:120` and `:169` wait a second for nothing.

### 052. Two suites read the process-wide descriptor count alongside every other suite

`ProcessRunnerTests.swift:157` and `:198` declare `ProcessRunnerFailureTests`
and `ProcessRunnerCompletionTests`; both read `lowestDescriptorCount`
(`:190-192`, `:240-242`) while other suites open and close descriptors. The
slack in each expectation (300 against a leak of 600, 100 against 400) is what
holds it together. `.serialized` would order only each suite's own tests, not
stop the others. `DescriptorExhaustionTests` (`:251`) runs only under
`MULTISHELL_EXHAUST_DESCRIPTORS`.

### 053. Two watcher tests sample the descriptor count over a fifth of a second

`DispatchDirectoryWatcherTests.swift:137` and `:151` sample over 120 and 240 ms,
where `ProcessRunnerTests.swift:178-192` samples over 2 and 4 s and
`Tests/TestScratch/Polling.swift:13-16` says why.

### 054. Seven main-actor AppKit suites run beside each other, one spinning the run loop

`SidewaysWheelTests.swift:9` declares `@Suite @MainActor` with no `.serialized`,
and `settle()` at `:43-44` spins `RunLoop.main` for 250 ms, alongside six other
live AppKit suites: `SettingsPageSizeTests.swift:42`,
`DetailMinimumWidthTests.swift:10`, `SurfaceFrameTests.swift:9`,
`ScrollToTopTests.swift:6`, `DestructiveAlertTests.swift:6` and
`QuitAlertTests.swift:6`.

### 055. A parser test asserts two counts are not negative, which cannot fail

`WorktreeStatusParserTests.swift:71`,
`#expect(status.ahead >= 0 && status.behind >= 0)`, and `:74`,
`#expect(all.changedFiles >= 0)`. No fixture carries a negative count, so it is
a crash test whose name is its only assertion.

### 056. Nine tests skip when node, python3 or a comma locale is absent, three of them as passes

`OpenCodePluginRunTests.swift:10` gates its six tests on node, the only suite
that runs the generated plugin; they report as skipped, which is still green.
`UnixSocketTests.swift:94` and `:194` return early without `/usr/bin/python3`,
so the cross-process claim tests report as passes.

`HelperTests.swift:458` passes the same way when zsh under `de_DE.UTF-8` prints
no comma. About twenty more return early without `/bin/zsh` or `/bin/bash`:
thirteen in `PromptMarkTests.swift`, `HelperTests.swift:390`, `:453`, `:738`,
`:796` and `:839`, `ProcessRunnerTests.swift:309` and
`LoginShellEnvironmentTests.swift:36`. Those bite only on Linux (064).

### 057. Nothing tests the four appearance setters

`AppModel+Appearance.swift:5`, `:10`, `:15`, `:19`. `setTheme` and `setFont`
write the workspace, persist it and push a theme to every live surface;
`setUIFontSize` writes and persists; `reloadThemes` rereads the folder and may
raise an error. None is named by a test. `Apps/macOS/Sources` is 7,432 lines
against 2,123 of test, which is the deliberate untested-views split, but
`TabDrops.swift` and `ProjectDropDelegate.swift` are logic and untested, and
`MacPlatform.swift` is reached only for its logging subsystem.

### 058. The hook-shell tests run the developer's own login shell, and two pass without running under fish or tcsh

`ProcessRunnerTests.swift:111`, `:119-124`, `:136-139`, `:338-350`, `:364-365`
and `:599` call `ShellCommand()` with no HOME and no shell path, so they run
`$SHELL -l -i -c` over the developer's rc files, which
`Docs/develop/tests.md:302-304` forbids by name; 036 fails one of them on an rc
file that changes directory. `:339` and `:365` also return when `$SHELL` is in
neither `errexitShells` nor `markingShells`: under `SHELL=/bin/tcsh`,
`aScriptStopsAtItsFirstFailingLineWhereTheShellCanBeTold` and
`aFailingScriptsMessageIsItsOwnStderrNotTheRcFiles` passed in a few
milliseconds. Fix = pass `shellPath: "/bin/zsh"` and a scratch HOME and ZDOTDIR,
as `:320-322` does.

### 059. A watcher test waits out a stale unlink callback with a 900 ms sleep

`DispatchDirectoryWatcherTests.aDirectoryDeletedAndRemadeAtOnePathIsWatchedAgain`
sleeps 900 ms at `:81` against a 400 ms coalesce and then installs its counter,
where the suite's own comment at `:32-36` records deliveries taking over ten
seconds. A stale unlink arriving after the sleep counts as the new directory's
event, so the test would pass with the regression present. It is not the
count-did-not-grow shape of 051, and a false pass has not been watched. Fix =
count the old callback's arrival and reset before writing the file.

### 060. A shortcut left out of `AppShortcuts.all` passes every test

`AppShortcut.swift:108-117` says so ("nothing can check a shortcut left out of
this list"), and `Docs/develop/adding.md:89-90` repeats it. A missing one is a
menu shortcut the terminal eats in a pane. All 26 declared shortcuts are listed
today. Fix = a source scan of `static let … = AppShortcut(` against `all`, the
way `TranslationTests` scans lookups.

### 061. The project-removal trace exempts two caches `forgetWorktrees` now clears

`ProjectRemovalTraceTests.swift:20-24` skips `_statuses`, as pruned by the next
refresh, and `pendingStatusRefreshes`, as a refresh that finds its worktree
gone. Both reasons are stale: `forgetWorktrees` filters `statuses`
(`AppModel+Runtime.swift:91`) and cancels and clears the pending refreshes
(`:101-102`). The suite passed on a scratch copy with both exemptions removed
and both caches asserted non-empty before `removeProject`, so a regression in
either clear stays green today. Fix = delete both entries; `warmWorktrees`'s
waits on 118.

### 062. [Unconfirmed] The bundle script has run through xcodebuild only under the newer Xcode

This machine has only Xcode 27. That the older one writes no build path either
rests on its accessor having looked in the bundle's resources since packages
could carry them, not on a run; the helper comes the same way. Step: run
`make build` under `DEVELOPER_DIR=/Applications/Xcode_26.0.1.app` on a macos-15
runner and see `verify_binary` pass for both. Fallback = the newer Xcode.

### 063. [Unconfirmed] Nothing drives a terminal host against a real child

The only tests constructing `GhosttyTerminalHost`
(`GeneratedConfigSweepTests.swift`) call `init`, `shutDown` and
`claimSharedFiles`. Untested: a closed tab's shell ending and being collected, a
title reaching the delegate, an exit code arriving, and a close after it being
safe. The surface needs a window and a GPU. Fix = a host test that opens a
session under a window server.

### 064. [Unconfirmed] Linux has never been compiled, and its counted phrases would misbehave

No CI job and no Linux SDK here. The counted phrases are the twelve entries of
`Sources/MultishellCore/Resources/en.lproj/Localizable.stringsdict`, looked up
through `NSLocalizedString` (`Translation.swift:6`). swift-corelibs-foundation
applies no plural rule: `CFBundle_Strings.c:92-129` merges each stringsdict
entry into the table as a dictionary, and `Bundle.localizedString` bitcasts it
to a string, so each lookup is undefined behaviour, likely a crash. Read from
source, not run. The first Linux run should call `t("count.terminals", 2)`.
Fallback = build those forms by hand.

`Docs/develop/tests.md:252-253` says Foundation-only imports are checked by hand
in a Linux container, which this entry and `TODO.md:69-70` contradict. One of
them is wrong.

## Perf

### 065. One fetch of the trunk re-asks every branch's merge verdict

`AppModel+Merges.swift:63`; the memo type `MergeCheck` at `:139` holds
`baseTip`. The base prefers `origin/main` over a local trunk
(`DefaultBranch.swift:21`), so a fetch, pull or push moving it invalidates every
worktree at once; a local trunk commit does only where there is no remote. Each
re-asked branch costs one git process, `cherry` if unmerged or `log -g` if
merged (`WorktreeService+Merges.swift:24`, `:36`), up to four where its upstream
is gone (`:46`, `:57-76`), plus one `branch --merged` per project (`:14`), eight
at a time (`WorktreeCoordinator.swift:72`). Thirty worktrees is 31 to 121
processes, usually near 31, with `git cherry`'s patch ids the most expensive
read in the app. Pace the re-verdict the way `StatusPollPace` paces status, or
key the memo on the branch tip and the merge-base. Timed on a 7,700-commit
repository: `git cherry` takes 0.6 to 1.3 s per branch, growing with how far the
trunk has moved since the fork (1.31 s for a branch 7,544 behind), against 7.2
ms for `branch --merged`. Thirty long-lived branches re-asked after one fetch is
roughly 20 to 40 s of git CPU.

### 066. `git status` runs for worktrees that are collapsed or filtered out of sight

`AppModel+Runtime.swift:131-135` filters on `isUnderConstruction`,
`missingProjects` and `isDue`, and nothing asks whether the project is expanded
or the row survived the sidebar filter. A dirty worktree costs `status`,
`diff --numstat` and `ls-files` (`WorktreeService.swift:65-120`). One status
measures 9 ms against git directly and 14 ms through the `/usr/bin/git` shim
(068). A dirty worktree adds `diff HEAD` at 7 to 9 ms and `ls-files` at 8 to 10
ms, 25 to 35 ms in all, and a fresh one about double that (067). So 50 worktrees
is about 0.5 s of git per five-second tick when clean and up to 1.75 s when
dirty. Passing the visible set into `refreshStatuses` must keep what else reads
`statuses`: the board shows cards in collapsed projects, and
`refreshProjectsWhoseBranchMoved` (`:160`) uses each status's branch to catch a
checkout in an unwatched main worktree.

### 067. A worktree the app creates is read about four times slower on every poll until its index is written

`WorktreeService.swift:71-72` and `:92` pass `--no-optional-locks`, so git never
writes back refreshed stat data and re-reads the files it cannot trust from the
index on every call, and a fresh `git worktree add`
(`AppModel+WorktreeCreation.swift:83`) leaves every file that way. Measured in a
clone of this repository, 511 files: status took 40.5 ms in a new worktree
before one plain `git status` in it and 9.3 ms after. On a 7,793-file repository
it was 81.9 ms against 19.1 ms, and a dirty tree's `diff --numstat HEAD` 38 ms
against 7 ms. It lasts until the user runs `git add`, a commit or a plain status
there. Fix = one `git update-index -q --refresh` right after the add, while the
path is still claimed (`:71`) and no terminal is open. Checkouts made outside
the app would need the reason at `Docs/design/worktrees.md:11-13` revisited.

### 068. Every git call pays about 3.6 ms for the `/usr/bin/git` shim

`ExecutableLookup.swift:8-18` and `GitRunner.swift:27-33`, rebuilt at
`AppModel+Agents.swift:39`. A Finder PATH, and any login PATH without Homebrew
or Nix git, finds the xcrun shim. Measured: `--version` 8.27 ms through it
against 4.65 ms for the Xcode binary, `status` 12.84 against 8.93 ms,
`for-each-ref` 8.91 against 5.54 ms. At 50 worktrees that is about 180 ms of CPU
per tick before the merge reads. Fix = resolve `/usr/bin/git` once with
`xcrun --find git` and run that, again whenever the login environment is
captured.

### 069. The untracked-line count re-reads up to 500 files and 8 MiB on every read

`UntrackedLineCounter.swift:14-38`, called from `WorktreeService.swift:101-120`,
remembers nothing between reads, so it recurs every tick. Measured on a copy in
a release build over 500 files of 16 KB: 51.5 ms per read, 23 ms of it stat,
open and read and 28 ms `count(where:)` (`:34`) at about 290 MB/s. An un-ignored
`node_modules` of 20,000 files also has `ls-files` list every one (27 ms, 640 KB
down the pipe), and `paths(from:)` (`:42-45`) splits the whole output before
taking 500. Fix = count with `memchr`, which measured 25 ms for the same set,
and memo the lines by path, size and mtime.

### 070. Theme colours are parsed out of hex on every access

`HexColor.swift:43-56` and `Support/Theme+SwiftUI.swift:40-52`. `Theme` keeps
hex strings; `backgroundRGB` and `foregroundRGB` parse on each access, and
`ansiRGB` parses all sixteen and allocates an array, so `color(for:)` costs
sixteen parses to use one. One parse measures 238 ns in a release build. The six
`ansiRGB` sites (`WorktreeRow.swift:45`, `:66`, `:81`, `ChangeCounts.swift:16`,
`:18`, `:22`) never all draw together: a clean idle row is about 5 parses, a
busy dirty one 50 to 70, so a 40-row sidebar render is about 0.05 to 0.7 ms.
Parse once in `Theme.init` and keep the `RGB` beside the hex.

### 071. Rows hold fresh closures, so SwiftUI can never skip one

`WorktreeRow.swift:26-28`, `ProjectRow.swift:20-21` and `AgentsRow.swift:12`.
Each row stores freshly allocated closures and conforms to no `Equatable`, so a
child body always re-runs when its parent does, building `.help` strings and an
accessibility label that are usually never read. `.contextMenu` builds its
content when applied: `projectMenu` (`SidebarView.swift:252-269`) is seven
lookups per project per rebuild, `TabButton.menu` (`:173-193`) three to five per
tab. An accessibility label measures 5.5 µs and eight `String(format:)` calls 12
µs, so about half a millisecond per sidebar rebuild at 40 rows. Give the rows an
`==` that ignores the closures and apply `.equatable()`, or pass the model and
an id instead.

### 072. The branch scan spawns a git process per project per tick, serially

`AppModel+Merges.swift:19-23` loops the projects with an `await` inside, and
each runs `for-each-ref` over `refs/heads` and `refs/remotes` unconditionally
(`WorktreeCoordinator+Merges.swift:9`, `WorktreeService.swift:124-141`); the
`MergeCheck` memo suppresses the follow-up queries but not the scan. Refs are
not watched so it has to poll, which worktrees.md records, but the loop is
serial and unpaced: ten projects is ten spawns every five seconds.
`for-each-ref` measures 5.5 ms against git directly, 8.9 ms through the shim and
6.8 ms on a 7,800-file repository, so 55 to 90 ms of the tick, serially. Run the
projects in a task group and pace the scan per project.

### 073. A `cwd`-only report resolves every worktree's symlinks on the main actor

`AppModel+SessionState.swift:146-157`, called from `apply` at `:55`.
`worktree(atPath:)` calls `resolvingSymlinksInPath()` on every worktree in the
workspace plus the reported path, on the main actor, for every socket report
carrying no session id, which is the hooks of an agent started outside a
Multishell tab. With 50 worktrees that is 51 `realpath` chains per report; on a
network-mounted worktree each can block. Resolve each path once when
`replaceWorktrees` stores it. On a local disk the 51 resolves measure about 0.5
ms per report, and a tool call sends two; the network-mount blocking has not
been instrumented.

### 074. The agent board is rebuilt whole on every body evaluation

`AgentBoardView.swift:21` builds `model.agentBoard`
(`AppModel+AgentBoard.swift:5-7`, whose comment says it is rebuilt each read):
three dictionaries over all projects, worktrees and tabs, then a card per live
session, then a sort and buckets. It depends on `workspace`, `statuses`,
`sessionStates`, `liveSessions`, `reportedAgents`, `sessionTitles`,
`commandAgents`, `showsAllTerminals` and the shell-path settings, so a title
change in one pane rebuilds every card. The ten-second `now` is read only inside
the `GeometryReader` (`:52`), so whether the tick re-runs `body` is unproven.
Noticeable from about 30 live panes. Hold the board in a stored property the
model invalidates.

### 075. The whole tab strip sits inside a `GeometryReader`

`TabBar.swift:43-44`; `tabViews(layout)` is called at `:68` and `:72`, inside
the reader, so every resize frame of the window or a column divider rebuilds
every `TabButton`, each asking the model for state, title and agent and building
an accessibility label and a context menu. `TabStripLayout.tabWidth`
(`TabStripLayout.swift:33-34`) changes with the width between its clamps, so a
child that skips unchanged layouts saves only the frames where the tabs sit at
their maximum or minimum width.

### 076. The sidebar filter folds every worktree name per keystroke

`SidebarFilter.swift:27` and `:31`, called from `SidebarView.swift:29` and `:97`
inside `body`: case- and diacritic-folded `range(of:)` up to twice per worktree,
with the full row rebuild behind it. Measured 0.53 ms for ten projects of 200
worktrees, 0.05 ms at 40. With the filter empty nothing is folded, but
`workspace.worktrees(of:)` (`Workspace.swift:198`) still scans every worktree
once per project. Fold the names once into a side table when the workspace
changes.

### 077. Row order is recomputed on every sidebar rebuild

`SidebarView.swift:102`. `WorktreeOrder.sort` (`WorktreeOrder.swift:36-53`)
builds a key per worktree, then calls `localizedStandardCompare` per comparison
(`:94`), and `worktreeOrder(for:)` scans for the project and resolves its
settings per project (`AppModel+WorktreeOrder.swift:20-25`), which is quadratic
in projects. None is cached, so it runs on every invalidation, including 085's
and every status or session write. The name sort alone measures 85 µs at 40
rows, 318 µs at 200 and 703 µs at 400, before settings are resolved.

### 078. The directory watcher stats and opens directories on the main actor

`DispatchDirectoryWatcher.swift:7`, `:44`, `:57` and `:70`. `watch(_:)` runs
`isStale` over every watched directory, each a stat, and `makeWatch` opens each
new one, on the main actor; `rearmWatcher` calls it after every refresh that
changed the worktree list (`AppModel+Refresh.swift:31-36`). The watched
directories are each repository's `.git` and `.git/worktrees/*`, so a repository
on a stalled mount blocks the window. Nobody has watched the stall.

### 079. The dropped-file sweep runs synchronously on the main actor at launch

`AppModel.swift:300`. `DroppedFiles.sweep()` runs inside `start()` on the main
actor, each expired drop a recursive `removeItem`. Wrap it in `Self.offMain`.
`host.claimSharedFiles()` at `:291` is the same shape and must stay ahead of the
first controller, so moving it needs an await rather than a detached task;
`HelperLink.refresh` and `ShellIntegration.refresh` (`:293-294`) write files
there too.

### 080. A drag over a pane re-reads the pasteboard on every mouse move

`SurfaceView.swift:112` calls `draggingEntered` on every update, which re-reads
`PromisedDrop.receivers` (itself a `readObjects`) and, when nothing is promised,
`fileURLs` (`:155-159`). Only `acceptsDrop` (`:93`) needs asking each move,
because the shell can exit mid-drag. Cache both reads against the
`draggingSequenceNumber`.

### 081. The directory check before a shell starts runs on the main thread

`requireDirectory(of:)` at `AppModel+Worktrees.swift:98-104` is a synchronous
`fileExists` on the main actor, reached from `select` (`:12`), `readyForShell`
(`AppModel+Tabs.swift:29`) and `openHeldBackTab`
(`AppModel+WorktreeCreation.swift:300`). So a click on a worktree whose network
volume has gone away freezes the window until the mount times out. The polling
paths' checks run off it (`AppModel+Projects.swift:86`).

### 082. A bash tab spawns the helper twice per command, inline

`init.bash:48` and `:103`. Under bash 3.2 a command-started and command-finished
pair measures 9.4 ms, each spawn 4.5 to 6.4 ms against 1.4 ms for
`/usr/bin/true`; one delays the command's start and the other the prompt. Nearly
all of it is launch: the helper's `--version` alone is 4.3 ms. Fix = one
long-lived relay per shell, opened with `exec 9> >("$_multishell_bin" relay)`,
which works on 3.2 and keeps the order down one pipe. The helper has no relay
command yet, and the cost is a resident process per bash tab.

### 083. zsh forks twice per command to build the JSON it sends

`hooks.zsh:80`, `:94` and `:98` build each line through
`"$(_multishell_json …)"`. The preexec and precmd pair measures 1.47 ms, 1.2 to
1.4 ms of it the two command substitutions, where `zsocket` and `print` take 37
µs. Fix = have `_multishell_json` set a global with `typeset -g` and send that.

### 084. Export writes, stats and confines the shared file on the main actor

`exportSharedSettings` (`AppModel+SharedSettings.swift:183-210`) writes the file
(`:193`), reads its modification date (`:197`) and confines it through
`noteSharedSettings` (`:210`, `:103-110`), which resolves symlinks per listed
path (`RepositoryContainment.swift:9-10`), all on the main actor.
`readSharedSettings` (`:50-57`) and `reconfineSharedSettings` (`:92`) go through
`offMain`, and the confinement expression is written twice (`:56`, `:108`).
`Docs/design/settings.md:23-24` records the main-actor export; on a slow volume
it costs what 081 does. Reasoned. Fix = all three in one `offMain`, passing a
`SharedSettingsReading` back.

### 085. [Unconfirmed] A sidebar drag writes its drop target at pointer rate

`ProjectDropDelegate.swift:28` assigns `SidebarView.dropTarget`, an Equatable
`@State` (`SidebarView.swift:11`), on every `dropUpdated`, about 60 a second. If
SwiftUI re-runs the body for an equal write, that is the whole sidebar rebuild
per move. The tab strip's writes (`TabDrops.swift:40`, `:97`, `:129`) go to
`@Observable` `model.tabDrag`, and a probe showed an equal write there notifies
nothing, so they cost nothing after the first. A comparison guard is free either
way.

### 086. [Unconfirmed] A working Claude's title spinner sets off a status read of its worktree about once a second

A retitle counts as activity (`GhosttyTerminalHost.swift:237-239`,
`SessionRegistry.swift:81-86`), which schedules `refreshStatus(of:)` 250 ms
later (`AppModel+Runtime.swift:193-212`, `:174-187`), and
`StatusPollPace.swift:20-25` lets through any read after 500 ms. Claude
2.1.280's binary alternates its title between ◐ and ◑ every 960 ms while it
works in a focused terminal, so the focused worktree is read about once a second
rather than every five: status, and on a dirty tree `diff HEAD` and `ls-files`,
25 to 35 ms and three spawns each. Each retitle also writes `sessionTitles`,
which re-runs every `TabButton` and `PaneRows`. The zsh preexec retitle likewise
schedules a read 250 ms into every command, before it has changed anything.
Reasoned from our source and Claude's binary; not watched in the app. Fix =
schedule the read from command-finished and the bell, not a retitle, or hold
activity reads to one per poll interval.

## UI/UX

### 087. Five icon-only controls carry no accessibility label

The sidebar header's shared helper (`SidebarHeader.swift:25-36`, the filter and
Add Project buttons), `CopyButton.swift:19-33`, `InfoButton.swift:13-22` and the
tint swatch at `ProjectIconSection.swift:47-66` set `.help` and no
`.accessibilityLabel`. `IconButton.swift:15-16`, `TabButton.swift:169`,
`DetailView.swift:107-108`, `ScrollingTabStrip.swift:92-93`,
`SidebarFilterField.swift:36` and `TabBar.swift:152-153` pair the two.

### 088. Project settings' Hooks tab overflows the window it opens in

`ProjectHooksTab.swift:14-71` measures 973 pt against the 600 pt window, so its
last editors sit below the fold with nothing saying so. Six monospaced editors
were never going to fit a window the other pages share, and
`SettingsPageSizeTests.swift:77-80` records this one as deliberate so the next
page to overflow is not lost in it.

### 089. While the board is up, two commands act on a worktree nothing on screen names

Open in Editor reads `workspace.selectedWorktree`
(`AppModel+Editor.swift:19-22`), and New Worktree pre-picks that worktree's
project in its sheet (`AppModel+WorktreeCreation.swift:9-11`); no sidebar row
draws as selected then (`SidebarView.swift:160-162`). Left because neither is
destructive; fix = route them through `worktreeInView`
(`AppModel+Tabs.swift:16-18`), as the pane commands do.

### 090. English only, so no layout has been seen in another language

Only `en.lproj` exists, in `Apps/macOS/Sources/Multishell/Resources/` and
`Sources/MultishellCore/Resources/`. What is unproven is the layouts, not the
lookup. Several settings pages fit their fixed window with little to spare, and
a language running much longer than English would overflow them. Rows, strips
and columns size themselves off measured text, so those should give rather than
clip.

### 091. A number inside a phrase carries no locale

`String(format:)` takes no locale
(`Sources/MultishellCore/Text/Translation.swift:8`,
`Apps/macOS/Sources/Multishell/Text/Translation.swift:9`), so the board's
elapsed time (`ElapsedText.swift:33`, `"%.1fs"`) reads with a point in a
language that writes a comma. Deliberate, the alternative making every test of
it read the machine's region; fix if it grates = a locale in the lookup and
those tests pinned to one.

### 092. A tab title persisted before a language change keeps the old word

A plain shell's title starts as `t("tab.shell")` (`WorkspaceStore.swift:479`,
`:485-486`) and is persisted in `TerminalSession.title`. It corrects itself
under zsh and bash, whose integration retitles on the next command; another
shell keeps it until the tab closes. Fix = store the default as absent and
translate where it is drawn, which changes a persisted field.

### 093. Agent settings is the one page nothing holds

`AgentSettingsTab.swift:13-70` is left out of
`SettingsPageSizeTests.swift:21-25` because its refresh on appear (`:69`) reads
the machine. Measured at 560 wide: 357 pt with one hooks row, 41.5 pt per
further row, 564 pt with five and the flags row, so a sixth agent puts it over
the 600 pt window. A row's Show file adds 166 pt (`:97-116`), which with a
preferred agent and two rows is over already, and nothing says so. Fix: the
hooks rows want their own scroll.

### 094. The find bar shows no match count and no wrapped mark

The engine sends both as `GHOSTTY_ACTION_SEARCH_TOTAL` and `_SEARCH_SELECTED`,
which the wrapper's bridge logs under its default arm
(`TerminalCallbackBridge.swift:171`, libghostty-spm 1.5.20260906) and forwards
to no delegate. Fix = a patch to the bridge, upstreamed and the pin moved, or
the wrapper carried here. Decided against: a count is not worth carrying it.

### 095. A turn over the New Tab or split buttons scrolls nothing

The catcher overlays only the arrows and the scroller
(`ScrollingTabStrip.swift:49-60`), and the buttons are siblings outside it
(`TabBar.swift:60-70`), so a turn over them has nowhere to go; over an arrow it
scrolls the tabs, which is wanted. Known and not fixed.

### 096. An edit to the user's Ghostty config lands only at the next launch

`GhosttyUserConfig.base()` is read once, when the host's controller is built
(`GhosttyTerminalHost.swift:26-34`); `apply` (`:140-149`) only sets the theme,
and nothing watches the files (`GhosttyUserConfig.swift:9-16`). Nothing tells
the user.

### 097. A large git badge overflows a row or card at its minimum width

The badge is `.fixedSize()` (`ChangeCounts.swift:32`), placed at
`WorktreeRow.swift:181-183` and `AgentCardView.swift:92-95`. Measured at font
13: 37.5 pt for `+42 −7`, 138.5 pt for `+12345 −6789 ~12 ↑3 ↓2`. A typical badge
fits both. The large one needs 229.5 pt in a sidebar row against 164 pt at the
180 pt minimum sidebar, and 202.5 pt against 192 pt on a board card at the
column floor, so past truncating the name it overflows. Fallback: drop the file
count to the tooltip, which already names those files.

### 098. The Hooks tab's caption is wrong for csh and tcsh, and for shells the runner swaps for `/bin/sh`

`hooks.environment-info` (app `Localizable.strings:91`) says a hook runs through
the project's shell as an interactive login shell and stops at its first failing
line except in fish. csh and tcsh are in `/etc/shells` here, so the picker
offers them, and neither is in `errexitShells` (`ShellCommand.swift:93`), so a
failing line does not stop them. A shell outside `interactiveLoginShells`
(`:143-153`), such as nu, pwsh, xonsh or elvish, runs as `/bin/sh -c`, which is
neither the project's shell nor a login one, so the rc files' PATH is missing.
Fix = name both cases in the caption and at `COMPAT.md:35`.

### 099. [Unconfirmed] The rename field's accessibility container under VoiceOver

The row contains its children only while renaming (`WorktreeRow.swift:123`), and
the field is labelled (`InlineNameField.swift:24`). Step: with VoiceOver on, use
a worktree row's Rename action and check the cursor lands on the field.

### 100. [Unconfirmed] The tab strip's two split buttons have never been watched on a screen

`TabBar.swift:114-123` and `:197-206`, shown when `stripShowsSplits`
(`UIMetrics.swift:52-55`) says the column is wide enough. Step: widen a column
until the two split glyphs appear after the + and click each.

### 101. [Unconfirmed] A cancelled divider drag

A split or column divider holds its weights in the view and writes the model
once when the drag ends (`WeightedSplit.swift:48-52`, `:140-164`), the end read
off the gesture state resetting so a drag the system cancels commits too. If it
snaps back, the fallback is the model's last saved weights. The sidebar divider
writes its width live and reads only its start width that way
(`RootView.swift:13-15`, `:55-64`). Step: start a divider drag, press Cmd-Tab
mid-drag, come back, and see whether the panes keep the dragged sizes.

### 102. [Unconfirmed] A wheel that sends lines, and a trackpad's vertical turn

The sideways scroll is watched with a mouse whose turns arrive as points. A
wheel sending lines is held to the scroller's own rate, so a notch may read as
slow; fallback = scale the swapped deltas. A trackpad's vertical gesture opens
with an event whose deltas are both zero, which `isVertical`
(`ScrollWheel.swift:77-79`) answers false for, so the gesture passes through.
Step: with a strip full enough to scroll, swipe vertically on the trackpad over
the tabs.

### 103. [Unconfirmed] Whether a reused surface frame leaves the keyboard in the right place

Frames are reused: a probe of the same `ForEach` shape as
`PaneTreeView.swift:49` removed the first of three and made no new view, the old
one now showing the second. A frame asks for focus whenever its surface changes,
and `SurfaceFrameTests` shows the request moves with the surface. Unwatched: the
engine view taking first responder after it. Step: split a tab into three, close
the leftmost, type, and check the text lands in the pane that took its place.

### 104. [Unconfirmed] The notifications settings page has never been seen on screen

It measures 226 pt of the 600 pt window, so what is left is how it reads. The
tab band is drawn outside the AppKit hierarchy and measurable by nothing; if it
clips, the page wants more width. Step: open Settings > Notifications and check
all six tab labels and the rows show unclipped.

### 105. [Unconfirmed] The settings window is as tall as its tallest page

Both windows are fixed at 560 by 600 (`SettingsView.swift:10`, `:42`,
`ProjectSettingsWindow.swift:39`), the height set by Project General at 581.5
pt. App pages measure General 159, Terminal 164, Notifications 226, Appearance
262, Agents 357 to 564 and Worktrees 364, so General shows its rows above about
440 pt of nothing. Fix if it reads badly = the tall pages scroll and the window
shrinks to the rest. Step: open Settings > General and judge.

### 106. [Unconfirmed] Tab-group drawing is unverified on screen

Whether bands appear as a tab crosses a terminal area
(`TabGroupBands.swift:7-66`), whether the insertion line lands in the right
strip (`TabButton.swift:37-39`), how an unfocused column reads, and whether the
scroll arrows (`ScrollingTabStrip.swift:73-98`) read better than the fade they
replaced. Store, model and wording are tested; drawing is not. Step: drag a tab
over a column's terminal area and watch for the bands and the line.

### 107. [Unconfirmed] Whether a SwiftUI overlay composites above the engine's surface

The surface is Metal-backed. The focus ring, the unfocused fade and the find bar
are overlays (`PaneTreeView.swift:33-39`); the built-in themes fade to 0.8
(`Theme.swift:117`, `:135`). If none appears, the fade would have to become a
view inside the frame, as its drop highlight is. Step: split a tab and check the
unfocused pane is dimmed.

### 108. [Unconfirmed] The find bar has never been seen on a screen

`FindBar.swift:20-69`, `AppModel+Find.swift`, menu items at
`MultishellCommands.swift:59-73`. Unconfirmed: the first step landing on the
match nearest the prompt, the menu acting on the bar whose field has the
keyboard, the shifted Return stepping up, the menu items enabling as bars open
and close, Escape in a pane under an open bar reaching the program, and a bar a
worktree switch brings back leaving the keyboard in the pane. Step: Cmd-F in a
pane with output, type a word, Return then Shift-Return.

### 109. [Unconfirmed] The reordered board card and the git indicator picker have not been seen drawn

The picker (`WorktreeSettingsTab.swift:44-50`) is on a page measuring 364 pt of
600, which `SettingsPageSizeTests` holds, so only the drawing is left. Step:
open Settings > Worktrees and look at the picker, then a board card with
changes.

### 110. [Unconfirmed] Agents board drawing is unverified on screen

Whether a card reads at the 208 pt column floor (`UIMetrics.swift:64`), where
the worktree name and the badge share a line (097 measures that); whether a
partial column reads as more without arrows (`AgentBoardView.swift:41-63`);
whether nested scrolling feels right to a trackpad
(`AgentBoardColumnView.swift:18-26`); whether the Dock badge
(`MacPlatform.swift:95`) appears under this build's signing. Fallback = the tab
strip's arrows. Step: narrow the window until board columns scroll.

### 111. [Unconfirmed] Neither agent-flags row has been seen on screen

Their widths are measured, 279 pt in Settings (`AgentSettingsTab.swift:32-36`)
and 436 pt in project settings (`ProjectAgentTab.swift:35-48`), and neither sets
a placeholder. What is left is how an empty one reads. Step: pick an agent in
Settings > Agents and check the empty Flags field reads as a field.

### 112. [Unconfirmed] A click on the blank part of the New Tab menu's frame

The label paints the chrome colour over the whole frame and carries a content
shape (`TabBar.swift:158-172`); the comment at `:156-157` says it is not a
content shape, which is stale. The sidebar's sort menu
(`SidebarSortMenu.swift:28-37`) is the same shape. Step: click the empty space
right of the chevron inside the + frame.

### 113. [Unconfirmed] The subagent chip's popover

Opened on hover and held 250 ms after the pointer leaves so it can be crossed
onto (`SubagentChip.swift:18`, `:33-57`). Whether it takes the keyboard from the
terminal under it, whether crossing onto it keeps it up, and whether one in a
sidebar row survives the row's tap gesture are all unconfirmed. Fallback = a
multi-line tooltip. Step: hover a chip on a card and in a row, cross onto the
popover, and type.

### 114. [Unconfirmed] The New Tab menu's rendered agent marks

`TabBar.swift:127-187`, `AgentMarkImage.swift:24-37`. SwiftUI builds the menu
only when it opens, so there is no NSMenu to inspect beforehand. It may drop the
icon, in which case the items read as they did before. Fallback = the titles,
which say the same thing. Step: with an agent on the PATH, open a strip's +
menu.

### 115. [Unconfirmed] A later alert layout takes Return off the removal button

`NSAlert.layout()` clears the key equivalent of a `hasDestructiveAction` button,
which is why `DestructiveAlert` sets it after presenting and again a turn later
(`DestructiveAlert.swift:41-46`, `View+DestructiveAlert.swift:36-53`). In a
probe only an explicit `layout()` cleared it again; appearance flips, forced
layout passes, `display()`, a parent resize and a system colour change did not,
and nothing in the app calls `layout()` on an alert. The probe's sheet never
attached, so it only approximates the real path. Fallback = the mouse and
Escape. Step: raise a worktree removal and press Return, and say whether the
button is drawn red (046).

## Code

### 116. A view measures the drop indicator's hit split, so nothing tests it

`SidebarView.swift:166-177`. `blockHeight(of:metrics:)` does arithmetic over row
heights, pane counts and rename state inside a view, read by
`ProjectDropDelegate.swift:14` and `:56`, and layout.md says views measure
nothing and are untested. Extract it beside `UIMetrics` in `Support/`, where it
stays because it names a Mac measurement, and cover it in
`MetricsAndColourTests.swift`.

### 117. `claimedPaths` is read by four tests and nothing in production

`WorktreeWorkInFlight.swift:88`. Its seven reads are in
`WorktreeWorkInFlightTests.swift:48`, `:54`, `:60` and
`AppModelGitTests+Refresh.swift:398`, `:423`, `:426`, `:433`; its doc comment at
`:86-87` describes a refresh reader that is gone. Delete it and have the tests
assert through `isClaimed(_:)`; `twoCreatesAtOnceEachHoldTheirOwnRow` polls the
count before either worktree exists, so it needs both planned paths worked out
first.

### 118. `warmWorktrees` is absent from the one place per-worktree state is dropped

`AppModel.swift:107`, keyed by `Worktree.ID`, written from four places and read
at `AppModel+Runtime.swift:27`. `forgetWorktrees` (`AppModel+Runtime.swift:88`),
which `Docs/design/worktrees.md:168-173` and `Docs/develop/adding.md:147-148`
name as the single place this state is dropped, does not touch it. The only
reason given is the exemption in `ProjectRemovalTraceTests.swift:17-19`, which
covers a removed project, not a worktree re-made at the same path. Either add it
there or write the reason into worktrees.md.

SessionStates' `.worktree` entries are not dropped there either, but by
`pruneStates` (`AppModel+SessionState.swift:225-228`) in the reconcile both
callers run next. Nothing leaks, but the two docs understate it.

### 119. `AppModel+Runtime` is four unrelated concerns under a name that says none

`AppModel+Runtime.swift`, 229 lines: session reconcile, error reporting and
focus at 5 to 64, the `offMain`, `setIfChanged` and `forgetWorktrees` utilities
at 66 to 107, status polling at 109 to 188, and activity and title notes at 190
to 229, with `scheduleStatusRefresh` (`:204`) among them. Split into
`AppModel+Reconcile`, `AppModel+StatusPolling` and `AppModel+Activity`, and move
`offMain` and `setIfChanged` to `Support/`.

### 120. Agent, shell and editor detection sits in a file named Agents

`AppModel+Agents.swift:9`. `refreshLoginEnvironment` captures the login shell,
detects agents, shells and editors (`:24-35`), and rebuilds the
`WorktreeCoordinator` (`:39`). Move it into `AppModel+Detection.swift`; the rest
of the file is named correctly.

### 121. `WorkspaceStore` writes the same tab index lookup nine times

`WorkspaceStore.swift` (595 lines) holds nineteen index lookups. Seven are the
identical `workspace.tabs.firstIndex(where: { $0.id == id })` (`:207`, `:217`,
`:235`, `:249`, `:266`, `:284`, `:317`) and two more the same over `tabID`
(`:448`, `:464`). `Workspace` has value lookups (`:163`, `:167`) and no index
ones. Add `tabIndex` and collapse those nine. The file's size is justified at
`:4-9`, because `private(set) var workspace` means every writer shares it, but
state-and-store.md should say this file only grows.

### 122. The two translation test files duplicate their scanner

`Tests/MultishellCoreTests/Text/TranslationTests.swift` (221 lines) and
`Apps/macOS/Tests/MultishellTests/Text/TranslationTests.swift` (302) each carry
about 80 lines of the same scanning machinery (core `:140-220`, app `:218-301`).
The package split forces the duplication. They have drifted once:
`aCountedPhraseReadsAsSingularAndPlural` (core `:65`) has no app counterpart.
Equalise the check lists and record the pairing in tests.md.

### 123. The window header chrome is written out twice

`DetailView.swift:86-89` and `AgentBoardHeader.swift:26-29` apply the same four
modifiers, `.padding(.horizontal, 14)`,
`.frame(height: UIMetrics.headerHeight)`, `.background(theme.chromeColor)` and
`.titleBarDoubleClick()`, to the same window header; `SidebarHeader.swift:20-22`
repeats three. Make it one `View` extension so it cannot drift.

### 124. The centred-caption styling is written out twice

`WorktreeOperationView.swift:28-32` and `EmptyStateView.swift:24-28`: the same
five modifiers, down to `maxWidth: 380` and `padding(.top, 6)`. The title above
each repeats three more (`:24-26`, `:16-18`).

### 125. `public` declarations named by no other target

Most are nested types reached through a public signature and need it. These are
confinable:

- `Workspace+Repair.swift:6`, called only from `WorkspaceStore.swift:31`.
- `WorktreeWorkInFlight.swift`: the type and eleven members, nothing outside the
  module naming them; `AppModel.workInFlight` (`AppModel.swift:85`),
  `StatusReadLog.invalidate` (`:39`), `WorktreeOperations.advance` (`:35`) and
  the nine mutating funcs in `SessionStates.swift` are the same.
- `AgentHookEvent.swift`: the init (`:31`), `name` (`:7`), `reported` (`:10`),
  `subagent` (`:26`) and the `startsTurn` property (`:29`); the type itself the
  CLI reads.

These are confinable once a test switches to `@testable`:
`WorktreeService.swift:6` (`GitHarness.swift`), `ShellStateHooks.swift:5`, `:13`
and `:67` (`HelperTests.swift`), `FileDigest.swift:5` and `:7`
(`PresentedErrorTests.swift`), and `AgentHooks.claude` at `AgentHooks.swift:62`
(`HelperTests.swift:905`). `GitRunner` stays public, the `TestSupport` target
calling it, and so does `helperReference`, a default argument of public
functions.

Also confinable now, their tests already `@testable`: `AppModel.removeWorktree`
(`AppModel+WorktreeRemoval.swift:52`), `pidPollInterval` (`AppModel.swift:111`),
`statusReads` (`:174`) and with it `StatusReadLog` (`StatusReadLog.swift:6`) and
`StatusPollPace` and its `.standard` (`StatusPollPace.swift:5`, `:11`),
`PresentedError.saysGitIsMissing` (`PresentedError.swift:17`),
`WorkspaceStore.refusesToSave` (`WorkspaceStore.swift:16`) and
`AgentDescriptor.markTint` (`AgentCatalogue.swift:20`). `WorktreeFileEscape`
(`WorktreeFileFailures.swift:43`) needs `PresentedErrorTests.swift:3` switched
to `@testable` first.

### 126. Catalogue keys are split by a stray `s`, which breaks the sort into groups

Across the two `Localizable.strings`: fourteen keys under `action.` and ten
under `actions.`, so `action.remove` sorts away from `actions.remove-worktree`;
four under `notification.` against nine under `notifications.`; one `worktree.`
key alone against nineteen `worktrees.`. translation.md:6-8 says the catalogue
is sorted by key so that it groups by part of the app, which this defeats. Pick
one spelling per group.

### 127. The marks' SVG path parser lives in the Agents view folder

`Apps/macOS/Sources/Multishell/Agents/SVGPathParser.swift`, 105 lines, used only
by `AgentMarkShape.swift:43` and accepting absolute M, L, C, Q and Z alone.
layout.md gives view folders to the part of the window they draw and this draws
none. Move it to `Support/`, with its tests in
`AgentMarkResourceTests.swift:45-67`.

### 128. The one-worktree status read applies the bulk read's guards differently

The bulk read (`AppModel+Runtime.swift:128-146`) skips worktrees in
`missingProjects` (`:133`) and, after its await, drops only what
`workInFlight.isClaimed` (`:138`). `refreshStatus(of:)` (`:174-187`) has no
missing-project check, so a live pane in a missing project spawns `git status`
whenever its activity and the pace allow. After its await it checks the fuller
`isUnderConstruction` (`:182`, `AppModel+Worktrees.swift:77-79`), which also
counts a running removal stage, so a bulk read landing after a removal has begun
is applied where the single read's is dropped. Both small and unwatched. Fix =
one predicate for whether a worktree may take a status read, used before and
after both awaits.

### 129. The app imports MultishellProcess, which neither manifest gives it

`AppDelegate.swift:4` imports it to call `DescriptorLimit.raise()` (`:14`),
while the root package exports no such product (`Package.swift:8-15`) and the
app target lists Core, GitKit and AppCore (`Apps/macOS/Package.swift:20-26`); it
compiles because the module arrives transitively. The class is also not
`@MainActor` where `MacPlatform.swift:7` and `UserNotificationNotifier.swift:8`
are, so two witnesses wrap their bodies in `MainActor.assumeIsolated` (`:18`,
`:26`) and `quitAlert` carries its own (`:36`); a probe of that shape under
Swift 6 and the macOS 27 SDK needed neither. Fix = a product and a dependency,
or the call moved behind AppCore, and the class marked `@MainActor` without the
wrappers, checked under the older Xcode too.

### 130. A retry and its label are two optionals the alert reads apart

`PresentedError.swift:13-14`. `PresentedErrorAlert.swift:10` decides the alert
is retryable from `retry != nil`, and `:25` builds the button from `retryLabel`,
so a retry set without a label shows only Cancel and cannot be reached. The one
writer (`AppModel+WorktreeRemoval.swift:93-97`) sets both today. Fix = one
optional `Retry` holding the label and the action.

### 131. Two comments state what the code does not

`GhosttyTerminalHost.swift:249-250` says Ghostty's resources carry shell
integration for zsh, bash and fish; the pinned bundle's
`Ghostty/shell-integration` holds bash and zsh only, the host enters only zsh's
(`:84-85`), and `COMPAT.md:31` and `:35` say fish gets nothing.
`Apps/macOS/Package.swift:33-34` says the app suite covers error mapping and
that views stay untested, but `PresentedError`'s mapping is tested in AppCore
(`PresentedErrorTests.swift`), and `DetailMinimumWidthTests.swift:12-30` hosts
`DetailView` and reads its pixels.

### 132. Editor launches are built by `AgentLaunch`

`EditorLaunch.swift:29` and `:43` pass an editor's shim to
`AgentLaunch.command(customLine:…)` and `command(agent:…)`, the same two the
agents use (`AppModel+Agents.swift:172`, `:188`), which wrap any program in the
login shell with an exec fallback. The names say agent and half their callers
are not. Fix = move and rename the two for what they do, and leave
`arguments(for:resume:)` in `AgentLaunch`.

### 133. `SocketFailure` and fifteen other types sit in another type's file

`Docs/develop/layout.md:44-49` allows two exceptions to one type per file: an
error thrown from that file alone, at its bottom, and small same-shape types
read together. `SocketFailure` opens `UnixSocketAddress.swift:5` and is thrown
there, in `UnixSocketServer.swift:59-151` and in `UnixSocketClient.swift:24`,
where `ProcessFailures.swift` and `WorktreeFailures.swift` are the pattern.
Public types read elsewhere under another's name: `ProcessOutput`
(`ProcessRunner.swift:3`), `ProcessStop` (`ProcessStopper.swift:4`),
`WorktreeFileList` (`WorktreePlacement.swift:5`), `SplitAxis`
(`PaneNode.swift:3`), `AgentPlaceholder` (`AgentFlags.swift:5`),
`SharedSettingsDecision` (`SharedProjectSettings.swift:285`), `WorkspaceSave`
(`WorkspaceStore.swift:57`), `TerminalHostDelegate` (`TerminalHost.swift:50`),
`AgentDescriptor` (`AgentCatalogue.swift:4`) and `EditorDescriptor`
(`EditorCatalogue.swift:4`). Internal ones: `MergeCheck`
(`AppModel+Merges.swift:139`), `AppShortcuts` (`AppShortcut.swift:67`),
`SurfaceFrame` (`SurfaceView.swift:32`, which has its own suite),
`ProjectDropTarget` (`ProjectDropDelegate.swift:5`) and `SplitMetrics`
(`WeightedSplit.swift:73`). `GitUnavailable` (`GitRunner.swift:4`) and
`HookFailure` (`WorktreeHooks.swift:7`) qualify but sit at the top. Fix = a
`SocketFailure.swift`, and either a file each for the rest or a looser rule in
layout.md.

### 134. Seven comments outside the tests run past two lines, and 282 inside them

CLAUDE.md caps a comment at two lines. Two are in production, both from 686ed34:
`DestructiveAlert.swift:26-29` (four lines) and
`View+DestructiveAlert.swift:5-7` (three). Five are in the manifests:
`Package.swift:17-22`, `:33-35` and `:42-45`, and
`Apps/macOS/Package.swift:9-12` and `:27-30`. The tests hold 282 in 80 files,
261 of them `///` on suites and cases, the longest
`SettingsPageSizeTests.swift:7` at 35 lines, and the checked-in comment rule
wants none in tests at all. Fix = move the seven reasons to `Docs/design/`
behind a pointer, and either say in CLAUDE.md that the cap covers sources only
or give the suites a pass.

## Docs

### 135. libintl is LGPL and linked statically, from a libghostty someone else built

GNU gettext 0.24's libintl reaches the executable inside the prebuilt
`libghostty.a` (Ghostty's Zig object calls `bindtextdomain` and `dgettext`).
LGPL-2.1 asks that whoever receives a statically linked copy can relink it
against a modified libintl. `THIRD-PARTY-NOTICES.md` names the pieces for that,
the gettext source, Ghostty's at the pinned commit, libghostty-spm's build
scripts and this repository, but nobody has walked the relink, and libghostty is
built by a third party (`Docs/develop/dependencies.md`). Nothing binds until the
app is distributed. Fix = build libghostty from source before a release, which
dependencies.md already asks for, and try the relink once.
