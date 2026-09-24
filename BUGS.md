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

Code references last checked on 2026-09-24 against the uncommitted tree on
f302af7. Agent behaviour last checked on 2026-09-23 with claude 2.1.280, codex
0.155.1, gemini 0.46.0, copilot 1.0.87 and opencode 1.18.30.

| #   | Effect | What                                                                                  |
| --- | ------ | ------------------------------------------------------------------------------------- |
| 001 | Medium | [Unconfirmed] Parts of three agents' hook files have never been watched               |
| 002 | Medium | [Unconfirmed] A /clear after an interrupted turn leaves the pane Working              |
| 003 | Low    | A dead mount can hold every cooperative-pool thread                                   |
| 004 | Low    | [Unconfirmed] Remove waits on a git status that has no timeout                        |
| 005 | Low    | A failed cd in a csh or tcsh hook runs the script where the rc files left it          |
| 006 | Low    | [Unconfirmed] A worktree path resolved while missing stays unresolved                 |
| 007 | Low    | [Unconfirmed] Ctrl-C at a bash prompt ends the relay's inline fallback                |
| 008 | Perf   | The bash relay still forks twice per command                                          |
| 009 | CI     | [Unconfirmed] The bundle script has run through xcodebuild only under the newer Xcode |
| 010 | Docs   | libintl is LGPL and linked statically, from a libghostty someone else built           |

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
`SessionStates.report` (`SessionStates.swift:52`) drops such a report while the
pane is Running or Waiting and the shell did not report the Working. Claude
fires no hook when Esc interrupts a turn, so the pane stays Running; a `/clear`
or `/resume` then sends SessionStart, which used to reset it to Idle and is now
dropped. The dot says Working until the next prompt. The comment names Copilot's
prompt mode as the reason, but the flag is on all four agents. Step: interrupt a
Claude turn with Esc, run `/clear`, watch the dot. Fix = set `startsSession` for
Copilot alone, or let a SessionStart with `source` `clear` or `resume` through.

## Low

### 003. A dead mount can hold every cooperative-pool thread

`WorktreeService.untrackedCounts`, `AppModel.offMain` and the scan in
`DispatchDirectoryWatcher.watch` run blocking file reads in `Task.detached`,
which shares the cooperative pool, one thread per core. A probe of 64 blocking
detached tasks peaked at 12 running on 12 cores. With enough worktrees on a
mount that stopped answering, those reads can hold every pool thread, and every
other task in the app waits behind them. `DirectoryProbe` already runs its stat
on `DispatchQueue.global`, which grows past the core count. Fix = run the other
three the same way.

### 004. [Unconfirmed] Remove waits on a git status that has no timeout

`requestRemoval` (`AppModel+WorktreeRemoval.swift:33`) now awaits
`refreshStatus(of:forced: true)` before it shows the confirmation. That read is
`git status` through `GitRunner.output`, which passes no timeout. On a worktree
whose mount stopped answering the read never returns, so the dialog never
appears, and `removalReads` swallows every further click on that row. Before,
the dialog came up at once. A large repository delays it by the length of its
status with nothing on screen. Step: remove a worktree on an unplugged SMB
share. Fix = bound the forced read, a second is what `DirectoryProbe` allows,
and show the dialog with the status already held when it runs out.

### 005. A failed cd in a csh or tcsh hook runs the script where the rc files left it

`ShellCommand.entering` (`ShellCommand.swift:103`) prefixes every hook with
`cd <dir> >/dev/null || exit 1`. csh and tcsh abort the rest of a line whose
builtin fails, so the `|| exit 1` never runs and the next line does. Run here:
`tcsh -i -c "cd '/nonexistent/zz' >/dev/null || exit 1<newline>echo after"`
prints the error, then `after`, and exits 0; `/bin/csh` does the same. The
directory existed when the shell was spawned, so this needs it to go or lose
search permission while the rc files run. Fix = for the csh family, put the `cd`
and the exit on separate lines behind `if ( ! -d <dir> ) exit 1`, or test
`$status` on the next line.

### 006. [Unconfirmed] A worktree path resolved while missing stays unresolved

`AppModel.resolvedComponents` (`AppModel+SessionState.swift:164`) caches
`resolvingSymlinksInPath()` per worktree on first use, for every worktree each
time a report is placed by directory. Foundation returns a missing or dangling
path unchanged, so a worktree whose directory is absent then, on an unmounted
volume or behind a dangling link, is cached with its links unresolved. Once the
directory is back, a report whose `cwd` is the resolved spelling
(`/private/tmp/...` for a `/tmp/...` worktree) matches no worktree until the
worktree is forgotten. Fix = cache only a resolution of a path that exists.

### 007. [Unconfirmed] Ctrl-C at a bash prompt ends the relay's inline fallback

The relay runs in the bash shell's process group, so a Ctrl-C at the prompt
reaches it. The helper ignores INT and QUIT (`Helper.relayIgnores`), but the
inline fallback in `init.bash:30`, which runs when the helper is too old for
`relay`, traps only HUP, TSTP, TTIN and TTOU. A Ctrl-C at the prompt ends that
loop; lines already in the pipe are lost and each later report pays the EPIPE
before falling back to a helper launch. Fix = add INT and QUIT to that `trap`.

## Perf

### 008. The bash relay still forks twice per command

The relay exists so a command costs no process launch, and hooks.zsh dropped its
`$(...)` in the same change because a command substitution forks.
`_multishell_relayed` (`init.bash:55`) runs `theirs="$(trap -p PIPE)"` for both
the started and the finished line, and bash 3.2 forks for every command
substitution. Fix = read the PIPE trap once when the relay starts, or keep
SIGPIPE ignored only in a subshell that does the write.

## CI

### 009. [Unconfirmed] The bundle script has run through xcodebuild only under the newer Xcode

This machine has only Xcode 27. That the older one writes no build path either
rests on its accessor having looked in the bundle's resources since packages
could carry them, not on a run; the helper comes the same way. Step: run
`make build` under `DEVELOPER_DIR=/Applications/Xcode_26.0.1.app` on a macos-26
runner and see `verify_binary` pass for both. Fallback = the newer Xcode.

## Docs

### 010. libintl is LGPL and linked statically, from a libghostty someone else built

GNU gettext 0.24's libintl reaches the executable inside the prebuilt
`libghostty.a` (Ghostty's Zig object calls `bindtextdomain` and `dgettext`).
LGPL-2.1 asks that whoever receives a statically linked copy can relink it
against a modified libintl. `THIRD-PARTY-NOTICES.md` names the pieces for that,
the gettext source, Ghostty's at the pinned commit, libghostty-spm's build
scripts and this repository, but nobody has walked the relink, and libghostty is
built by a third party (`Docs/develop/dependencies.md`). Nothing binds until the
app is distributed. Fix = build libghostty from source before a release, which
dependencies.md already asks for, and try the relink once.
