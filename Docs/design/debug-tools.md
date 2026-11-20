# Debug tools

What View > Enable Debug Tools measures, how, and why. They are for finding
where sluggishness comes from, in every build. Newest at the bottom.

- **The toggle is runtime state, not a preference.** Sampling costs a process
  table read a second, and the display link wakes the main thread every refresh,
  120 times a second on ProMotion, panel closed or not, so the Frame Rate tile
  has the minute before it opened. So it never outlives the launch it was turned
  on in.
- **Frame rate is the main thread answering a display link**, not Ghostty's
  render rate, which runs on its own thread. A busy main thread answers late,
  which is what sluggish feels like. The link runs in the common run loop modes,
  event tracking among them, so a frame held up by a scroll or a resize still
  counts.
- **A second is judged by its longest frame, not its count.** 60 fps is smooth
  on a 60 Hz display and half speed on a 120 Hz one; a 50 ms frame is a hitch
  and a 100 ms one a stall on both.
- **A display that stops is not a stall.** A sleeping display sends no frames,
  and the gap to its first frame on waking read as one long stall. The sampler
  runs on the main thread too, so a frameless reading that came on time means
  the thread was free and the gap is dropped; a stall holds the reading late and
  the gap is kept.
- **Every git, `gh` and `circleci` run is timed into one log**, named with its
  program so the CLI Activity table says which tool ran. The log keeps nothing
  while off, so nothing grows undrained. A run still going is shown: a git hung
  on a dead mount stays running.
- **Memory and CPU are `proc_pid_rusage`'s**: the footprint Activity Monitor's
  Memory column shows, and CPU time in mach ticks, not the nanoseconds the
  header says. A tick on Apple silicon is 125/3 ns, so read as nanoseconds it is
  nearly 42 times short.
- **Panes are matched by terminal, then foreground pid, never environment.**
  Each shell carries its session in `MULTISHELL_SESSION`, but macOS leaves the
  environment out of `KERN_PROCARGS2` for any process but one's own.
- **A pane whose shell has no pty yet has no tty or foreground pid.** Its
  processes land under Other processes meanwhile and the totals stay right, as
  they read every child of the app.
- **An expanded tab is a tree of who started whom.** Siblings go by what their
  whole tree holds, so a small shell running a large agent comes first. The
  parent is the one the scan walked down from, so the tree costs no syscall
  beyond the walk.
- **Self and Total both, so the gap is what a shell started.** A tab the engine
  could not place yet shows its terminal alone, so the rows still add up. With
  no terminal reading either it shows neither, rather than a zero that reads as
  measured.
- **Child processes means everything the app started**, git and hooks as well as
  panes, so a burst of git runs shows in the totals.
- **One sample a second, fifteen minutes kept**, the spans a load average is
  taken over. Slots are counted from the first sample, so a slot holds the same
  seconds each time it is drawn.
- **A rate or a CPU share is counted over the time its samples covered**, not
  per sample. A stall holds the sampler too, and a sample it held four seconds
  holds four seconds of git runs, reports and CPU.
- **The tiles share one time axis and one pointer**, so a stall lines up with
  the git burst or CPU spike in it.
- **CPU splits by thread: main, the terminals', the rest, then children.** The
  terminals' are Ghostty's `renderer`, `cf_release`, `io`, `io-reader`,
  `io-gather` and `search`, and CoreVideo's `CVDisplayLink`, which a terminal's
  renderer starts while it draws; the app's own frame link starts no such
  thread. The rest is what the app's CPU leaves after the other two, so a thread
  that came and went between readings lands there.
- **State Reports, not Worker Reports**: every report on the socket counts,
  shell prompts and agent hooks as well as workers, each handled on the main
  thread.
- **The quick stats read the model in their own body**, so the sample landing
  each second redraws three cells, not the sidebar.
- **Pause holds the panel, not the sampling**, so a slow second can be read
  while the sidebar keeps counting, and resuming shows the seconds paused over.
- **A git run's memory and CPU are read as it exits**, while it is a zombie and
  before Subprocess reaps it: most runs finish between two samples, and no scan
  ever sees them. It is git's own lifetime peak footprint and CPU time, its
  children left out, and read only while the log records, so no other run pays
  the syscall. The CPU counts in the sample it ended in, less what a scan
  already counted.
- **A sample begun before a stop lands nowhere.** Every start and stop bumps a
  generation the sample checks after its scan, so turning the tools off, or off
  and on, never lets the last run's numbers into the next.
- **A tab's terminal counts in the tab's row, taken out of the app's.** Ghostty
  runs in the app's process, so its screens and scrollback sit in the app's
  footprint. Our patch 0006 reads each surface's page and image bytes, the
  figure libghostty-vt reports since ghostty#14499, which the surface API lacks.
  GPU buffers and the font atlas stay in the app's row: Ghostty counts neither,
  and surfaces share the atlas.
- **The terminal read is on the main thread, under Ghostty's terminal lock**, as
  a copy of a selection is: the surface is freed there too, so the pointer
  cannot go stale mid-read. It walks every page, so it runs once a sample, and
  only while the tools are on.
- **The app's row stops at zero.** Ghostty counts a page at its full allocated
  size, an estimate, so the terminals can read more than the footprint holds.
  The Total row stays the footprint and children as measured.
- **File tabs share one line, estimated from the text and image bytes the model
  keeps** (files/file-tabs.md), under the app's heap in use, since malloc holds
  them. All changes tabs count in it too (files/all-changes-tab.md). The layout
  a shown tab adds, up to 186 MB at the 1 MiB cap, and a shown image's decoded
  picture, up to 36 MB a copy, are not in the estimate.
- **Freed memory stays in the footprint until macOS wants it**, so closing a tab
  leaves its terminal's pages counted until the next tab reuses them. Not a leak
  (develop/memory.md).
- **A process that leaves the app's tree leaves the totals.** The scan walks
  down from the app, so a daemon that double-forks, or anything reparented to
  launchd, stops counting though the app started it.
- **The scan reads the whole process table once a tick.** Asking per pid cost a
  `proc_listchildpids` per process, and each call walks the whole table. An
  interpreter's arguments are read only to name its script, at two sysctls each.
- **The largest part of an idle app's footprint is Ghostty's three render
  targets**, which scale with the panes on screen (develop/memory.md).
- **Memory is RAM and GPU together, and the caption says so.** On Apple silicon
  the GPU draws from the same RAM, and the footprint counts both. A GPU column
  per tab would need a patch from Ghostty and has no source for a child's GPU
  memory, so only the app's row splits GPU out, as a whole (develop/memory.md).
- **The charts are shapes, not a `Canvas`.** On macOS 27 one `Canvas` makes
  SwiftUI draw its whole hosting view through Metal into three window-sized
  buffers, 105 MB with Debug Info open, `.drawingGroup()` or not; shapes held 23
  MB at the same CPU (develop/memory.md).
- **The command line reads the live history, not the paused panel**, so a
  script's samples run on while someone holds Debug Info still. With the tools
  off a reading is refused rather than answered empty
  (AppModelControlDebugTests).
- **`debug samples --summary` weighs each mean by the seconds its samples
  covered**, as a slot weighs its rates, so a held sample counts for the seconds
  it held.
- **Git runs are also kept one by one, the newest 1,000**, each with the sample
  it ended in: the tallies add runs up per command and lose which one was slow.
  A burst of status reads is hundreds.
- **A mark goes into the next sample and into Instruments' Points of Interest.**
  The signpost is sent with the tools off too, so a trace taken without the
  display link's wake-ups still shows where the action fell.
- **The banners posted are logged whether the tools are on or not**, the newest
  50, since the notification centre says nothing of a banner once shown. Only
  the newest about a pane or worktree can still be up, the centre having
  replaced the rest, so `debug notifications` reports only that one as standing.
- **The Multishell row opens into what its footprint holds**, read in the app
  about itself each sample: GPU, the heap in use with the file tabs under it,
  freed heap malloc keeps, and libraries, stacks and other as the rest. Its
  tabs' terminals stay out, in their tabs' rows; Ghostty's pages carry an
  app-specific VM tag, neither malloc's nor the GPU's, so they come out of the
  rest. Checked against `footprint` on one tab: 112 MB GPU against its 112, 43
  MB heap against its 44.
- **A terminal's Kitty images can count twice.** Patch 0006 puts their bytes in
  the tab's terminal, and a release build's Ghostty mallocs them, so they sit in
  the heap too and the rest shrinks by as much, to zero at worst. Splitting them
  out needs the patch to report images apart, and no patch is to be added.
- **GPU is the kernel's graphics ledger and the IOSurfaces mapped in.**
  Ghostty's render targets read as one or the other from run to run
  (develop/memory.md), and the ledger counts mapped IOAccelerator memory
  already, so adding that tag would count it twice. A whole-app figure needs no
  patch, unlike a per-tab one.
- **The heap is malloc's dirty pages by VM tag; in use is
  `malloc_zone_statistics`**, so the gap is freed memory malloc has not given
  back. Each part is capped at what the ones before it left, so the parts add up
  to the row though the readings come a moment apart.
- **The region walk steps over submaps.** Entering the shared library cache, one
  submap of thousands of regions holding a few MB, made it 15 times as long: 2
  ms against 31 in a probe. What is skipped lands in the rest.
- **CPU Breakdown nests threads under the CPU tile's groups**, not under one
  another: macOS records no thread starting another. Nor can the terminals'
  split by tab: every terminal's threads share the same seven names.
- **The tiles run from the most telling of a slow app to the least**: frame
  rate, CPU, memory and memory pressure, then wakeups and disk, then the app's
  own work, then the leak signs, and peak memory, history, last.
- **Disk, wakeups and peak memory are the app's own**, from `proc_pid_rusage`'s
  fourth version. Disk counts what reached the disk, not what was written to its
  cache.
- **Threads are read in the app, with `task_threads`**, each one's CPU and its
  pthread name. The SDK has no public call naming another thread the main one,
  so its id is read on the main actor as sampling starts and handed to the scan.
- **Memory pressure is the system's level, polled each sample** from the
  `kern.memorystatus_vm_pressure_level` sysctl: a dispatch source tells only of
  changes after it starts.
- **A save is timed from the encode to the write**, the hop back to the main
  actor left out. File events are counted, not timed: what they start awaits
  git, which CLI Activity times.
- **Wakeups are the interrupt count, package idle drawn inside it.** XNU adds a
  package idle wakeup only where it has just added an interrupt one, so the two
  summed counted those twice.

## Reviewed and left as is

- **A missed activity reading counts two samples' disk and wakeups in the next**
  (bug hunt, 2026-11-20): a slot sums its samples, so its rate is right; only
  one sample's own figure doubles, and the read almost never fails.
