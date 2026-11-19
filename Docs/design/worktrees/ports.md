# Ports per worktree

The block of ports each worktree's shells are given. Newest at the bottom.

- **Each worktree with shells holds a block of ports**, in `MULTISHELL_PORT`, so
  dev servers in two worktrees, or two projects, never collide. Blocks are
  unique across projects, the ports being the machine's.
- **Unique within one copy of the app only.** A debug build keeps its own state
  file, so it hands out 3000 again beside the installed app. Cost: a debug
  build's servers stay clear only under a starting port of its own.
- **The block is stored as an index from a global start**, not as a port, so a
  change of start or size moves every block's ports and no worktree with a port
  changes block.
- **Kept beside the worktrees, as a name is**, and dropped wherever the store
  forgets one, so a worktree removed outside the app frees its block at the next
  refresh.
- **A block that would end past 65535 is not given**, and a caption in Settings
  names every such worktree. A setting that moves a held block past the end
  keeps the index until a lower block that fits is free, then moves there:
  otherwise removing a worktree freed a block the next new worktree took.
- **What a launching pane was given is dropped at launch**, as mise's state is
  (terminals/sessions.md): a debug build started from a pane handed that pane's
  `MULTISHELL_PORT` to every shell and hook given none, its session and socket
  to every hook, whose reports reached the other app, and a custom agent
  command's worktree variables to every pane.
- **A caption, not an alert, for what a setting caused**, chosen 2026-10-24. The
  defaults leave 6,253 blocks, so in practice only a start or size change leaves
  a worktree without a port, and the caption says so where it was changed. An
  alert sharing the one slot every alert uses took four review passes of
  bookkeeping to be neither lost under another nor raised twice.
- **An alert only when a created worktree gets no block**, raised by the create
  and never over another alert, the caption keeping the record.
- **That alert belongs to no command line request.** Filed under the one that
  caused it, a `worktrees add` that succeeded answered "refused" and took the
  alert down unread.
- **A stored block no setting could fit is given again on load**: a hand-edited
  index of 10^18 overflowed the multiply and crashed every launch.
- **The port fields are read tolerantly**: a value past Int or of the wrong type
  costs itself, not the sidebar.
- **The pre-create hook gets no port**, the block coming with the refresh after
  `git worktree add`.
- **A worktree re-added outside the app at a kept path takes a fresh block**,
  never the one the removal's hook may be stopping servers on.
- **Costs of a port read once at launch**: a tab dragged to another worktree
  keeps the old one's port, and a start or size change can give a new shell a
  port an open one still uses, both until reopened. A worktree removed outside
  the app frees its block at once, whatever it left listening; nothing checks.
- **Settings clamps a start or size; `config global` refuses one.** As the hook
  timeout does: a typed field has no refusal to show, and a command line write
  reads back as given or not at all.
- **No UI shows the port**; the variable is enough. Cost: nothing checks whether
  another program already holds a port in the block.
