# Memory

Where the app's footprint goes, how to measure it, and what was tried. Measured
on macOS 27, Apple silicon, the debug build, in October 2026. The decisions that
came out of it are in design/debug-tools.md.

## Measuring

- **The footprint is RAM and GPU together.** It is `phys_footprint`, the figure
  Activity Monitor's Memory column and Debug Info show. On Apple silicon the GPU
  draws from the same RAM, so a Metal texture or IOSurface counts like a malloc.
- **`footprint -p <pid>` splits it by category**, `vmmap -summary <pid>` adds
  the malloc zones with what is allocated against what is held free, and
  `heap <pid>` counts live objects by class. A leak shows as a class whose count
  does not return to its baseline after the thing is closed.
- **Compare totals, not GPU categories.** The same render targets read as
  `IOSurface` in one run and as `Owned physical footprint (unmapped) (graphics)`
  in the next. The kernel's graphics count, `ledger_tag_graphics_footprint` in
  `TASK_VM_INFO`, saw 2 MB of a probe's 95 MB of targets.
- **For stacks, launch the binary with `MallocStackLogging=1`**, not through
  `open`, which passes no environment. `malloc_history <pid> -allBySize` lists
  every allocation, freed ones included; `-callTree -invert` the live ones. The
  logging costs about 64 MB of its own, as `Performance Tool Data`, and
  libghostty's frames show as `???`: it is stripped.
- **Read after the first minute.** Launch peaks around 334 MB, and malloc can
  hold a freed block of 32 to 39 MB, shown as `Malloc Large (empty)`, for a
  minute or for the whole run.
- **A probe outside the app isolates a cause.** A bare window of the app's size,
  2056×1237 pt, holds 17 MB and no GPU memory, with or without a sidebar
  material, which is how the render targets were shown to be Ghostty's.
- **Tests see neither GPU buffers nor main-queue frees.** A window never ordered
  in commits nothing to WindowServer, so no drawables are made. A nested run
  loop inside a test never drains the main queue, so a test of what a deferred
  free releases awaits instead (`GhosttyTerminalHostTests`
  `closedSessionsLetTheirSurfaceViewsGo`).
- **Opening a tab or the panel needs a click**, which an agent may not send
  (TODO.md). Sample once a second with `footprint` in a loop and have the step
  done by hand.

## Where it goes

One shell tab, idle, debug tools off: 193 MB.

| Part                                         | MB       |
| -------------------------------------------- | -------- |
| Ghostty's three render targets               | 95       |
| Ghostty's other GPU memory and terminal heap | 10 to 15 |
| Live heap, mostly SwiftUI and AppKit         | ~33      |
| Freed heap malloc still holds                | ~14      |
| Libraries, CoreAnimation, page tables        | ~25      |

- **A render target is the pane's size in pixels at four bytes a pixel**, 3554 ×
  2326 there, and Ghostty keeps three. It is triple buffering: one on screen,
  one the GPU draws, one the render thread fills, so a slow frame does not stall
  the next. Each target belongs to a frame with its buffers, so all three stay
  though only one is needed while the terminal is idle.
- **Only panes on screen hold them.** A hidden tab's view leaves the window, is
  reported occluded, and Ghostty frees its swap chain; so does a minimised or
  covered window. Five tabs in one group cost one tab's GPU memory, which
  follows visible terminal area rather than tab count.
- **A terminal reserves about 6 MB of screen pages as it opens.** Five tabs
  added 31 MB of live heap.
- **Opening a tab briefly charges about 217 MB of GPU memory** before it settles
  near 117 MB; four 32 MB surfaces were made, not three. Not traced further.
- **Debug Info added 105 to 117 MB while open**, from its `Canvas` strips, now
  shapes (debug-tools.md).

## Freed memory is kept, not leaked

- **macOS 27's malloc keeps freed pages until memory pressure.** In a probe,
  freeing 98% of 30 MB of 16 KB to 256 KB blocks left the footprint at 31 MB for
  three minutes, and `malloc_zone_pressure_relief` returned nothing. Of 4 KB
  blocks, half came back.
- **Five tabs opened and closed** left the app at 94 MB from 64: 26 MB freed but
  held, 6 MB live. Every surface view, Ghostty surface and GPU buffer was gone.
  A second round reached 96 MB, live heap up 0.2 MB, so the held pages are
  reused and the 6 MB is caches built for the first terminal, kept once.

## Strips: `Canvas` against shapes

Five strips of 180 slots and 40 rows of text in a 1777×1237 pt window, three 30
second runs each:

| Rate  | Drawn with | App CPU | WindowServer CPU | Footprint |
| ----- | ---------- | ------- | ---------------- | --------- |
| 1 Hz  | `Canvas`   | 2.2%    | 9.4%             | 169 MB    |
| 1 Hz  | shapes     | 2.0%    | 13.6%            | 23 MB     |
| 60 Hz | `Canvas`   | 42.3%   | 31.6%            | 177 MB    |
| 60 Hz | shapes     | 43.1%   | 33.4%            | 24 MB     |

The 1 Hz WindowServer gap is one outlier run of 23.3%; without it they match.
`Canvas` with `.drawingGroup()` held 170 MB. Most of the CPU is SwiftUI's
update, the same either way.

## Tried and not kept

- **A GPU column in Memory by tab.** A patch reporting each surface's renderer
  bytes worked, but only Ghostty can say: nothing reports the app's own drawing
  or any child's GPU memory, so one split source among many was dropped, and the
  caption says the two are counted together.
- **Shrinking Ghostty's render targets needs a patch**, and none is to be added
  for it. What a patch could do, for an idle pane:

  | Change                                      | Saves         | Cost                                                        |
  | ------------------------------------------- | ------------- | ----------------------------------------------------------- |
  | Mark the two targets not on screen volatile | ~64 MB        | A call a frame; a guard against a race with the main thread |
  | Two targets instead of three                | 32 MB, always | Less slack for a slow frame                                 |
  | Free the two when idle                      | ~64 MB        | Two 32 MB allocations as output resumes                     |

  Volatile was measured in a probe, 103 MB to 39 MB. Ghostty clears every target
  before drawing it, so one macOS purged would only be redrawn.

- **The app's own levers do not reach a visible pane.** Reporting it occluded
  stops it drawing, and Ghostty marks a freed surface empty, the one on screen
  included, so it would likely blank; that is read from the code, not tried. A
  1x content scale quarters the targets and blurs the text. Ghostty's config has
  no buffer count.

## Not yet explained

- **What allocates the freed 32 to 39 MB block at launch.** Logging did not
  catch it as one allocation.
- **Why a new tab makes four render surfaces** and charges twice the settled GPU
  memory for a second or two.
