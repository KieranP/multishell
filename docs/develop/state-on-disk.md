# State on disk

Where state lives and what is in it.

## State on disk

`~/Library/Application Support/Multishell/` on macOS,
`$XDG_CONFIG_HOME/multishell/` on Linux. Debug build uses `state.debug.json`,
`multishell.debug.sock`, `integration.debug/`, `drops.debug/`; themes and the
helper link are shared. A debug build made in a git worktree adds that
worktree's name, `state.debug-fix1.json` and so on, so two of them can run at
once: `make-app.sh` writes the name into `MultishellVariant` in the bundle's
`Info.plist`, `open` passing no environment to what it launches. The name is
cut to 16 characters and spelled `[A-Za-z0-9_-]`, a socket path having 104
bytes to fit in. Settings > General prints the state file, which is how you
see which one a running copy has.

- `state.json`: sidebar, tabs, the columns they sit in with each column's
  width and active tab, pane trees, worktree names, each worktree's directory
  creation date, every setting. Not: processes, shell titles, the shell a tab
  resolved to, a branch's last commit time. Nor anything about the Agents
  board: whether it is showing and whether it is filtered to agents are
  runtime state, so the filter is off after a relaunch, the Dock badge having
  to read the same flag a view-local `@AppStorage` could not offer it.
  A file written before columns existed names no group on any tab and carries
  an `activeTabByWorktree` this build has no property for: `Workspace` reads
  that key for which tab was active, and `repairReferences` gathers each
  worktree's ungrouped tabs into the one column they were saved as.
- `state.<timestamp>.broken.json`: a state file that failed to read or to
  decode. Where the move itself failed the original is still at `state.json`
  and nothing saves over it; see docs/design/state-and-store.md.
- `themes/*.json`, `themes/examples/` not loaded.
- `multishell.sock`, mode 0600. Bound at `multishell.sock.b` and renamed into
  place, so it is never briefly world-readable: the mode comes from the umask
  at bind, and umask is process-wide.
- `multishell.sock.lock`, empty, never removed. A running instance holds an
  exclusive `fcntl` record lock on it for as long as it listens, which is what
  tells a second launch that the socket has a live owner. Not `flock`: a child
  forked while one is held keeps it until it execs, and this process spawns
  freely. A connect alone cannot: a
  listener whose accept backlog is full refuses one exactly as a dead
  socket does.
- `bin/multishell`: symlink to the helper in the current bundle, refreshed at
  launch. Hook lines reference this path.
- `integration/`: generated at launch.
- `drops/<uuid>/`: files a drag promised rather than handed over, swept at
  launch once a week old.

Agent hooks, written only when asked: Claude Code `~/.claude/settings.json`,
Codex `~/.codex/hooks.json`, Gemini `~/.gemini/settings.json`, each keeping a
`.before-multishell` copy the first time; Copilot
`~/.copilot/hooks/multishell.json` and OpenCode's plugin
`~/.config/opencode/plugin/multishell.js`, both ours alone, deleted to remove.
Sidebar width lives in `UserDefaults`.

A repository may carry `.multishell.json` at its root, written by Export in
project settings, same keys as a project's settings. Read at launch, when a
project's worktree records change, and on any tick where its modification date
moved. A field it ships fills only a gap the user left, so adding one to
`SharedProjectSettings` also means a line in `ProjectSettings.layered`, a
decode that costs the key and not the file, and an `OverrideSection` in the
tab seeded from `InheritedSetting`.

Decide what a blank one means: `Self.text` where "none" and "no opinion"
agree; nothing for worktree path, prefix and default branch, where blank is
how "none" is spelled. Not cosmetic: a blank hook left uncoerced counts as a
hook, and the trust question then asks about an empty script. Trust is held
per file against its sha256 (`FileDigest`, `ProjectSettings.sharedHooks`);
`docs/design/settings.md` has why.
