# State on disk

Application support on macOS, the XDG config directory on Linux.

- **A debug build keeps its own state file, socket, integration and drops
  directories**; themes and the helper link are shared.
- **A debug build made in a git worktree adds that worktree's name**, so two can
  run at once. The bundling script writes the name into the Info.plist, `open`
  passing no environment to what it launches.
- **The name is cut short and spelled conservatively**, a socket path having
  only `sun_path` to fit in, some of it taken by the staging suffix.
- **Settings prints the state file**, which is how you see which one a running
  copy has.
- **`state.json`**: sidebar, tabs, the columns they sit in with their widths and
  active tab, pane trees, worktree names and creation dates, every setting.
- **Not in it**: processes, shell titles, the shell a tab resolved to, a
  branch's last commit time, or anything about the Agents board, which is
  runtime state, so its filter is off after a relaunch.
- **A file written before columns existed names no group**, and carries a key
  for the active tab this build has no property for; the repair gathers each
  worktree's ungrouped tabs into the one column they were saved as.
- **An agent id the catalogue retired is forgotten on load**: its tab comes back
  a plain shell and a preference naming it falls back, since a kept id raised an
  install alert at every launch. `WorkspaceRetiredAgentsTests` holds it.
- **A broken state file is moved aside with a timestamp.** Where the move itself
  failed the original is still in place and nothing saves over it; once the user
  moves it away, that session saves again (state-and-store.md).
- **Themes are JSON in a themes folder**, with the examples beside them not
  loaded.
- **The socket is mode 0600**, bound under a staging name and renamed into
  place, so it is never briefly world-readable: the mode comes from the umask at
  bind, and umask is process-wide.
- **So the longest path that binds is two bytes shorter than `sun_path`
  allows**, the `.b` of the staging name, and the refusal names the socket
  rather than the staging file, which is no concern of the user's.
- **A lock file beside it is never removed.** A running instance holds an
  exclusive record lock on it while it listens, which is what tells a second
  launch the socket has a live owner (state-and-store.md).
- **A record lock, not `flock`**: a child forked while one is held keeps it
  until it execs, and this process spawns freely.
- **A connect alone cannot tell**: a listener whose accept backlog is full
  refuses one exactly as a dead socket does.
- **A symlink to the helper in the current bundle** is refreshed at launch. Hook
  lines reference that path through the home directory.
- **The integration directory is generated at launch**; the drops directory
  holds files a drag promised rather than handed over, swept at launch once old.
- **The merged Ghostty config lives in the temporary directory**, written by the
  wrapper when the first terminal opens and again when the app comes to the
  front with the user's files changed, and cleared at launch and quit by the
  copy holding the instance socket (terminals.md).
- **Agent hooks are written only when asked**, each in that agent's own config
  directory; launch leaves alone even one an older build wrote (agents.md).
  Three of them keep a copy of the file as it was the first time; the other two
  are files of ours alone and are deleted to remove.
- **Sidebar width lives in user defaults.**
- **A repository may carry `.multishell.json` at its root**, written by Export,
  with the same keys as a project's settings. Read at launch, when a project's
  worktree records change, and on any tick where its modification date moved.
- **A field it ships fills only a gap the user left**, so adding one means a
  line in the layering, a decode that costs the key and not the file, and an
  override section in the tab.
- **A field naming a path on the reader's disk needs more**: confinement, the
  trust text, the gate, and the export keep, the last so export does not drop it
  while it is untrusted.
- **Decide what a blank one means.** Coerce to "none" where that and "no
  opinion" agree, and leave it alone for the fields where blank is how "none" is
  spelled.
- **Not cosmetic**: a blank hook left uncoerced counts as a hook, and the trust
  question then asks about an empty script.
- **Trust is held per file against its digest** (settings.md).
