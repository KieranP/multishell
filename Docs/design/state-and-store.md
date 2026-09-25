# Persisted state

What is written, what is repaired, how it is tested. Newest at the bottom.

- **Persisted state is repaired, never trusted.** Starting empty and then saving
  deletes the user's sidebar to fix a bug of ours.
- **Projects are strict where other collections are lossy.** A project is the
  one thing git cannot give back, and one unknown pane kind from a newer build
  would otherwise cost every project.
- **References between types are repaired on load**, per-field defaults not
  reaching them. Cost: a hand edit that breaks a reference is tidied quietly.
- **Runtime state stays out of the file.** A shell title would schedule several
  saves a prompt for a string a relaunched tab replaces at once. Cost: a saved
  tab shows its starting title until its shell speaks.
- **Invariants are tested at random, with seeds.** Example tests pin the cases
  someone thought of; selecting a worktree a refresh had just removed was found
  by a seed. Cost: a failing seed has to be replayed.
- **A state file that cannot be read is moved aside.** Unreadable and
  undecodable take one path, so a root-owned file after a restore under `sudo`
  is moved and named in the alert.
- **The move is what frees the path to be written.** An atomic write renames on
  the directory's permission, not the file's, so without the move the first
  autosave replaces the user's projects with an empty workspace.
- **Where even the move fails, saving is off until the file is gone**, silently,
  the failed load having already said it. Each save asks whether it is still
  there, so one the user moves away lets this session save again. Cost: a file
  made readable mid-run is not read until relaunch, this session having started
  without it.
- **Duplicates are dropped after the prune, not before.** First entry wins, so a
  tab id written twice, once naming a worktree that has gone, kept the dead copy
  and lost the live one to the dangling prune.
- **A project is a value, so a copy is only as fresh as the render that made
  it.** It stays a value because saves and git work take it off the main actor,
  where a class would share mutable state.
- **So resolve per render and never store one.** The settings window looks its
  project up each body; the model accessors trust what they are handed rather
  than paying a lookup per row.
- **Whatever holds one past its render cannot**: settings bindings whose
  closures outlive it, a button action run after it, the worktree order whose
  rule the settings window changes from its own scene, a fetch holding a project
  across the network, an export, and the write-back of a read taken before
  awaiting git. Each looks the record up by id.
- **`ProjectTests` is the guard.** `Project` hand-writes its coding keys, `==`
  and `hash` to keep this run's read of a repo's file out of all three, so a
  field added later would be silently unsaved.
- **Saves land off the main actor.** Encoding and writing on it held the window
  for every divider drag, tab move and rename on a network home directory. Cost:
  a failed save is reported a moment after the change.
- **And in order.** The store hands out a snapshot with a ticket; a ticket older
  than the last landed is dropped rather than written over newer state. The
  encode is outside the lock, and so are taking a ticket and asking whether one
  landed. The main actor does both, and a write stalled on a volume would hold
  the window.
- **Quit still writes on the calling thread**, through the same lock, so it
  lands after whatever was in flight.
- **One copy of a build runs at a time.** Two copies both autosaved, and
  whichever wrote last decided what the next launch opened, losing every tab and
  project added in the other.
- **The held socket is what tells the second copy**, so it hands over: the
  running copy comes forward, this one quits and writes nothing meanwhile. The
  socket is per build variant and per worktree, so a debug build beside the
  installed app is not a second copy.
- **A copy that failed to quit starts no shell.** Its tabs' reports would reach
  the running copy's socket, and the engine config each one writes is named by
  the wrapper, so its quit could not tell those files from the running copy's.
- **Debug builds keep their own state file, socket and directories**, so a debug
  run beside the installed app touches none of them.
- **`WorkspaceStore` only grows**: `private(set) var workspace` keeps every
  writer inside it, so each new mutation is another method there. Lookups it
  repeats belong on `Workspace`, where the store's methods share them.
- **A plain shell's title is saved empty**, put in words when drawn: saved as
  the word, a fish or nu tab kept the old language's after a change, those
  shells never retitling. Cost: a build before this one draws such a tab
  untitled until its shell names it.
- **The load forgets a retired agent's id**: a tab restores as a plain shell, a
  preference falls back. Kept, it raised an install alert at every run for an
  agent the app no longer offers. Cost: the next save drops the id, so an older
  build that still has the agent opens those tabs as shells.
