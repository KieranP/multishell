# Architecture

What the core is, what it refuses, and how work reaches it.
Newest at the bottom.

## Core decides what exists, GUI how it appears

Engines disagree on pty ownership -> core never sees a descriptor, byte stream
or view. AppModel holds the runtime state the core refuses, in a library not
the Mac app, so a Linux frontend need not copy it out. Windows same way, never
built. Cost: `public` on every moved type, one `Platform` conformance per
frontend.

## Reconcile, don't command

One path for tab open, tab close, worktree removed, project removed, process
exited, relaunch. Cost: a session that fails to open is removed after, not
prevented.

## Identity is the path

Worktrees rediscovered from git every refresh; a minted id would change under
persisted selection. Cost: moving a repository = a new project.

## Shell out to git

libgit2's worktree support is its worst part, gitoxide's incomplete, porcelain
formats a stable contract. Cost: git must be installed, every operation is a
spawn.

## Nothing in the core blocks a thread

Waits inside `Task`s held one cooperative-pool thread per core until GCD ran
out of threads and the suite hung. Both pipes drain at once, else the second
fills its 64 KiB buffer and blocks the child; EOFs count as arrived one second
after the exit, a backgrounded server holding them open. Running out of
descriptors is an error, never an empty answer: at the limit `Pipe()` cannot
fail and hands back stdin, so `git worktree list` read as a project with no
worktrees and the store dropped every tab. Hence the `pipe` syscall, the
refused empty list, the raised limit.
