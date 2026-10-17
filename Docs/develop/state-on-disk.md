# State on disk

Under `~/Library/Application Support/Multishell`.

- **A debug build keeps its own state file, socket, integration and drops
  directories, and its own helper link**; themes and the hooks' helper link are
  shared.
- **A debug build made in a git worktree adds that worktree's name**, so two can
  run at once. The bundling script writes the name into the Info.plist, `open`
  passing no environment to what it launches.
- **The name is cut short and spelled conservatively**, a socket path having
  only `sun_path` to fit in, some of it taken by the staging suffix. A name cut
  or respelled ends in a hash of the whole, so `feature-auth-login` and
  `feature-auth-logout` keep their own files. A state file from before the hash,
  under the plain cut name, is moved to the new one at launch where nothing is
  there yet. Cost: two worktrees that shared the cut name shared one file, which
  the first to launch takes.
- **Settings prints the state file**, and `multishell info` the state file and
  socket of the copy that answered.
- **`state.json`**: sidebar, terminal tabs and file tabs by path with their
  scroll, the groups they sit in with their widths, order and shown tab, pane
  trees, worktree names and creation dates, every setting.
- **Not in it**: processes, shell titles, the shell a tab resolved to, a
  branch's last commit time, the sidebar filter or a project collapsed under it,
  a file tab's text, whether the Files panel is open, its filter and the folders
  opened in it, or anything about the Agents board or the debug tools. Those are
  runtime state, so Show all terminals is off after a relaunch, the Files panel
  starts shut, and the debug tools start off at every launch and write nothing
  to disk or defaults.
- **A file written before groups existed names no group**, and carries a key for
  the active tab this build has no property for; the repair gathers each
  worktree's ungrouped tabs into the one group they were saved as.
- **A file written before file tabs gives no group an order**, so the repair
  takes each group's from the order of its tabs (design/files.md).
- **An agent id the catalogue retired is forgotten on load**
  (design/state-and-store.md).
- **A broken state file is moved aside with a timestamp**
  (design/state-and-store.md).
- **Themes are JSON in a themes folder**, with the examples in an `examples`
  folder inside it, written when the user opens the folder and not loaded. Each
  is a copy of a built-in theme, and one that differs is rewritten then.
- **The socket is mode 0600**, bound under a staging name and renamed into
  place, so it is never briefly world-readable: the mode comes from the umask at
  bind, and umask is process-wide. The command line's requests come in on it
  too, so that mode is all that stops another account running a command in a
  pane (design/agents.md).
- **So the longest path that binds is two bytes shorter than `sun_path`
  allows**, the `.b` of the staging name, and the refusal names the socket
  rather than the staging file, which is no concern of the user's.
- **A lock file beside it is never removed**: unlinked at quit, a launch that
  opened it just before would lock the orphan while the next made a fresh one,
  and both would own the socket. A running instance holds an exclusive record
  lock on it while it listens, which tells a second launch the socket has a live
  owner (design/state-and-store.md).
- **A record lock, not `flock`**: a child forked while one is held keeps it
  until it execs, and this process spawns freely.
- **A connect alone cannot tell**: a listener whose accept backlog is full
  refuses one exactly as a dead socket does.
- **Symlinks to the helper in the current bundle are refreshed at launch**: the
  shared one in `bin/`, which hook lines reference through the home directory,
  and the build's own in `cli/`.
- **`/usr/local/bin/multishell` is a link to the build's own link**, `cli/`
  beside `bin/` with the variant in its name, made only when the user installs
  the tool, through an administrator prompt. It once named the shared link, so
  after a debug launch the installed tool drove the debug app; an install still
  naming it, or a link left dangling, reads as not installed, and Settings
  offers it again. Another build's link or a file of the user's own counts as
  installed, so two builds do not take it from each other.
- **The integration directory is generated at launch** from the scripts bundled
  in MultishellCore, so an edit there lasts until the next launch.
- **The drops directory holds files a drag promised rather than handed over**,
  swept at launch once a week old.
- **The merged Ghostty config passes through the temporary directory**, a file
  per load, gone once libghostty has read it (design/terminals.md).
- **`multishell debug screenshot` writes its PNG from the helper**, to the file
  named or a new one under `/tmp`, so the app writes to no path a request names.
- **libghostty is built without its crash reporter**, so it keeps no crash
  directory, and it never opens the user's Ghostty config, which the app reads
  and never writes.
- **Agent hooks are written only when asked**, each in that agent's own config
  directory; launch leaves alone even one an older build wrote
  (design/agents.md). Three of them keep a copy of the file as it was the first
  time, beside it; the other two are files of ours alone and are deleted to
  remove.
- **Those directories are under `$HOME`**, as the agents read it, and under the
  account's home only where `HOME` is unset or empty: the account's home alone
  sent a test's helper into the developer's own files.
- **Gemini's own settings are read where Gemini reads them** (design/agents.md);
  the hook file does not follow them to the temporary directory under an empty
  `HOME`.
- **The sidebar's and the Files panel's widths live in user defaults**, in the
  `io.multishell.app` domain every build shares, debug ones included.
- **A repository may carry `.multishell.json` at its root**, written by Export,
  with the same keys as a project's settings less the agent, its flags and the
  shell. Read at launch, when a project's worktree records change, and when its
  modification date has moved, which an event on the file or the project's
  `.git` and each minute's round check. What it said is never saved in the state
  file, where a restored copy would trust a file nobody looked at.
- **A field it ships needs a line in the layering**, a decode that costs the key
  and not the file, and an override section on the page (design/settings.md).
- **A field naming a path on the reader's disk needs more**: confinement, the
  trust text, the gate, and the export's carry-over, the last so export does not
  drop it while it is untrusted.
- **Decide what a blank one means.** Coerce to "none" where that and "no
  opinion" agree, and leave it alone where blank is how "none" is spelled. Left
  uncoerced, a blank hook counts as a hook, and the trust question asks about an
  empty script.
