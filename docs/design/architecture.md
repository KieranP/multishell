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

Two halves, because a poll reaches this too. `reconcileSessions` brings the
surfaces in line and leaves the keyboard alone; `sync` is that plus focusing
the active session and marking what is shown as seen, and only a user's own
action calls it. A refresh runs from the watcher and from any branch moving, so
focusing there takes first responder off whatever the user is typing in, the
sidebar filter included, every few seconds. A refresh still has to reconcile: a
worktree removed outside the app loses its tabs and sessions in the store, and
without it the host keeps the surfaces and the shells run on with nothing able
to reach them.

## Identity is the path

Worktrees rediscovered from git every refresh; a minted id would change under
persisted selection. Cost: moving a repository = a new project.

## Shell out to git

libgit2's worktree support is its worst part, gitoxide's incomplete, porcelain
formats a stable contract. Cost: git must be installed, every operation is a
spawn.

Found on the login shell's PATH, like every other tool the app looks up. The
process's own, which from the Finder is the system directories alone, misses a
git from Nix or a version manager, and the app would then be unusable for
someone whose terminals all have one. That PATH arrives after the coordinator
is built, so the lookup is made twice: once at launch, and again when the login
environment lands, which takes the launch report back if it finds git. Cost: a
user with no git at all sees the alert a moment before it is confirmed, and the
second lookup stats the PATH on the main actor beside the other detections.

## Nothing in the core blocks a thread

Waits inside `Task`s held one cooperative-pool thread per core until GCD ran
out of threads and the suite hung. Both pipes drain at once, else the second
fills its 64 KiB buffer and blocks the child; EOFs count as arrived one second
after the exit, a backgrounded server holding them open. Running out of
descriptors is an error, never an empty answer: at the limit `Pipe()` cannot
fail and hands back stdin, so `git worktree list` read as a project with no
worktrees and the store dropped every tab. Hence the `pipe` syscall, the
refused empty list, the raised limit.
