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
