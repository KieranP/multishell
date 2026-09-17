# Persisted state

What is written, what is repaired, how it is tested. Newest at the bottom.

## Persisted state never loses data, repaired rather than trusted

Silently starting empty and then saving deletes the user's sidebar to fix a bug
of ours. Projects strict where other collections are lossy: a project is the one
thing git cannot give back, and one unknown pane kind from a newer build would
otherwise cost every project. Per-field defaults do not cover references between
types -> references repaired on load. Runtime state stays out of the file: a
shell title would schedule several saves per prompt for a string a relaunched
tab replaces within a second. Costs: a hand edit that breaks a reference is
tidied quietly; a saved tab shows its starting title until its shell speaks.

## Invariants are tested at random, with seeds

Example tests pin the cases someone thought of; the selection of a worktree a
refresh had just removed was found by a seed. Cost: a failing seed has to be
replayed to understand.

## A state file that cannot be read is moved aside, or nothing is saved at all

Unreadable and undecodable take the same path: the read sits inside the `do`
with the decode, so a file that exists and will not open, root-owned after a
restore under `sudo`, is moved to `.broken.json` and named in the alert. It is
the move that frees the path to be written, and `.atomic` renames over the
destination on the directory's permission rather than the file's, so without it
the first autosave replaces the user's projects with an empty workspace and no
copy.

Where even the move fails the state is still where a save would land, so
`WorkspaceStore.refusesToSave` turns saving off for the session. Silent, the
failed load having already said it: every change schedules a save and would
raise the same alert again. Cost: a session's work is discarded at quit after
one warning at launch, and the check is made once at restore, so permissions
fixed while the app runs are not noticed until relaunch.

## Duplicates are dropped after the prune, not before

`uniqued(by:)` is first entry wins, so a tab id written twice by hand, once
naming a worktree that has gone and once a live one, kept the dead copy and lost
the live one to the dangling prune a few lines later, sessions and all. Tabs are
deduped after that prune for exactly this; the collections with no prune of
their own stay where they were.

## Saves land off the main actor, and in order

Every debounced save encoded the workspace and wrote it on the main actor, so on
a home directory on a network volume each divider drag, tab move or rename held
the window for the write. Now the store hands out a `WorkspaceSave`, the
workspace as a value with a ticket from `WorkspaceSnapshot`, and the model
encodes and writes it in a detached utility task; only the failure report comes
back to the main actor. The ticket is what keeps two saves 300 ms apart on a
slow volume from landing out of order: writes take one lock, and a ticket older
than the last landed is dropped rather than written over the newer state. The
encode is outside the lock. `saveNow` at quit still writes on the calling
thread, through the same lock, so it lands after whatever was in flight and the
process does not exit before the write. Cost: a failed save is reported a moment
after the change, not with it.

## One copy of a build runs at a time

A second copy that found the socket held used to report it and carry on. Both
loaded one workspace file, both autosaved 300 ms after each change, and
whichever wrote last decided what the next launch opened: every tab, split and
project added in the other copy was gone. The refusal is what tells the second
copy the first is there, so it now hands over: the platform brings the running
copy forward and quits this one, and until it has gone this copy writes nothing,
`saveNow` at quit included. A platform that cannot quit is left with the alert
and an inert copy. The socket is per build variant and per worktree, so a debug
build beside the installed app is not a second copy.
