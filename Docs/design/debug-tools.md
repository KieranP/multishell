# Debug tools

What View > Enable Debug Tools measures, how, and why. Newest at the bottom.

- **For finding where sluggishness comes from**, in every build. The sidebar's
  quick stats show FPS, CPU and memory; a click opens Debug Info in the detail
  area, covering the panes as the Agents board does.
- **The toggle is runtime state, not a preference.** Sampling costs a process
  table read a second, so it never outlives the launch it was turned on in.
- **Frame rate is the main thread answering a display link**, not Ghostty's
  render rate, which runs on its own thread. A busy main thread answers late,
  which is what sluggish feels like. The link runs in the common run loop modes,
  event tracking among them, so a frame held up by a scroll or a resize still
  counts.
- **A second is judged by its longest frame, not its count.** 60 fps is smooth
  on a 60 Hz display and half speed on a 120 Hz one; a 50 ms frame is a hitch
  and a 100 ms one a stall on both. The strips band every stalled slot red.
- **A display that stops is not a stall.** A sleeping display sends no frames,
  and the gap to its first frame on waking read as one long stall. The sampler
  runs on the main thread too, so a frameless reading that came on time means
  the thread was free and the gap is dropped; a stall holds the reading late and
  the gap is kept.
- **Git runs are timed in `GitRunner`**, which every git the app starts goes
  through. The log is shared by the runner a later PATH builds, and keeps
  nothing while off, so nothing grows undrained. A run still going is shown: a
  git hung on a dead mount stays running.
- **Memory and CPU are `proc_pid_rusage`'s**: the footprint Activity Monitor's
  Memory column shows, and CPU time in mach ticks, not the nanoseconds the
  header says. A tick on Apple silicon is 125/3 ns, so read as nanoseconds it is
  nearly 42 times short.
- **Panes are matched by terminal, then foreground pid, never environment.**
  Each shell carries its session in `MULTISHELL_SESSION`, but macOS leaves the
  environment out of `KERN_PROCARGS2` for any process but one's own.
- **The engine names the tty and foreground pid**, and a pane whose shell has no
  pty yet has neither. Where it cannot, every pane's processes land under Other
  processes and the totals stay right: they read every child of the app.
- **An expanded tab is a tree of who started whom**, each process under its
  parent. Siblings go by what their whole tree holds, so a small shell running a
  large agent comes first. The parent is the one the scan walked down from, so
  the tree costs no syscall beyond the walk.
- **Self and Total both, so the gap is what a shell started.** A tab's Self is
  its terminals and its panes' shells. A tab the engine could not place shows
  its terminal alone: its processes are under Other processes meanwhile, so the
  rows still add up, and a sample or two places it. With no terminal reading
  either it shows neither, rather than a zero that reads as measured.
- **Child processes means everything the app started**, git and hooks as well as
  panes, so a burst of git runs shows in the totals rather than nowhere.
- **One sample a second, fifteen minutes kept**, the spans a load average is
  taken over. A point of a longer range is several seconds: the worst frame
  rate, the mean rates, the latest memory. Slots are counted from the first
  sample, so a slot holds the same seconds each time it is drawn.
- **A rate or a CPU share is counted over the time its samples covered**, not
  per sample. A stall holds the sampler too, and a sample it held four seconds
  holds four seconds of git runs, reports and CPU.
- **The strips share one time axis and one pointer**, so a stall lines up with
  the git burst or CPU spike in the same second.
- **The memory strip stacks the terminals between the app and its children**, as
  the table takes them out of the app's row. CPU stays in two: a terminal's work
  is the app's own threads, which the kernel does not split. Naming three series
  widened every strip's label column from 17 ems to 26, the chart's loss
  (DebugStripLabelTests).
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
- **The display link wakes the main thread every refresh while the tools are
  on**, 120 times a second on ProMotion, with the panel closed too: the sidebar
  shows the frame rate as well. Another reason the toggle is not kept.
- **A tab's terminal counts in the tab's row, taken out of the app's.** Ghostty
  runs in the app's process, so its screens and scrollback sit in the app's
  footprint. Our patch 0006 reads each surface's page and image bytes, the
  figure libghostty-vt reports since ghostty#14499, which the surface API lacks.
  The Terminal line heads an open tab with its shells under it, since they run
  in it. GPU buffers and the font atlas stay in the app's row: Ghostty counts
  neither, and surfaces share the atlas.
- **The terminal read is on the main thread, under Ghostty's terminal lock**, as
  a copy of a selection is: the surface is freed there too, so the pointer
  cannot go stale mid-read. It walks every page, so it runs once a sample, and
  only while the tools are on.
- **The app's row stops at zero.** Ghostty counts a page at its full allocated
  size, an estimate, so the terminals can read more than the footprint holds.
  The Total row stays the footprint and children as measured.
- **Freed memory stays in the footprint until macOS wants it.** On macOS 27
  `malloc_zone_pressure_relief` releases nothing, and freed blocks of 256 KB and
  up held for a minute in a probe, so closing a tab drops the number late.
- **A process that leaves the app's tree leaves the totals.** The scan walks
  down from the app, so a daemon that double-forks, or anything reparented to
  launchd, stops counting though the app started it.
- **The scan reads the whole process table once a tick.** Asking per pid cost a
  `proc_listchildpids` per process, and each call walks the whole table. An
  interpreter's arguments are read only to name its script, at two sysctls each.
- **Most of an idle app's footprint is the terminal's render buffers.** Measured
  on macOS 27 with one shell open and the debug tools off: 193 MB, of which 95
  MB is the three IOSurfaces Ghostty's Metal renderer draws in turn, each the
  pane's size in pixels, 3554×2326 there. An empty window that size holds 17 MB.
  They scale with the panes on screen; Ghostty frees a pane's when it leaves the
  window or is covered.
- **The strips are shapes, not a `Canvas`.** On macOS 27 one `Canvas` makes
  SwiftUI draw its whole hosting view through Metal, into three buffers that
  size: 105 MB with Debug Info open, and as much under `.drawingGroup()`. The
  same strips as shapes held 23 MB in a probe, at the same CPU at one update a
  second, and about 2 points more of WindowServer at 60. A colour is a shape of
  its own.
