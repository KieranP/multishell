# Persisted state

What is written, what is repaired, how it is tested.
Newest at the bottom.

## Persisted state never loses data, repaired rather than trusted

Silently starting empty and then saving deletes the user's sidebar to fix a bug
of ours. Projects strict where other collections are lossy: a project is the
one thing git cannot give back, and one unknown pane kind from a newer build
would otherwise cost every project. Per-field defaults do not cover references
between types -> references repaired on load. Runtime state stays out of the
file: a shell title would schedule several saves per prompt for a string a
relaunched tab replaces within a second. Costs: a hand edit that breaks a
reference is tidied quietly; a saved tab shows its starting title until its
shell speaks.

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
the first autosave, which a mutation in `AppModel.init` alone is enough to
schedule, replaces the user's projects with an empty workspace and no copy.

Where even the move fails the state is still where a save would land, so
`WorkspaceStore.refusesToSave` turns saving off for the session. Silent, the
failed load having already said it: every change schedules a save and would
raise the same alert again. Cost: a session's work is discarded at quit after
one warning at launch, and the check is made once at restore, so permissions
fixed while the app runs are not noticed until relaunch.

## Duplicates are dropped after the prune, not before

`uniqued(by:)` is first entry wins, so a tab id written twice by hand, once
naming a worktree that has gone and once a live one, kept the dead copy and
lost the live one to the dangling prune a few lines later, sessions and all.
Tabs are deduped after that prune for exactly this; the collections with no
prune of their own stay where they were.
