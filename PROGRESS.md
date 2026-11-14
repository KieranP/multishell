# Progress: the All changes tab (issue #42)

The plan is [PLAN.md](PLAN.md). Updated as work lands; newest notes at the
bottom of each section.

## Phases

| Phase                         | Status | Notes                                                                                                                                          |
| ----------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| 1. Tab model and persistence  | Done   | Third tab kind, own key, repair, store open/close/move, probe sites switch on the kind, tab face, Changes page button.                         |
| 2. Reading                    | Done   | Path list from the status or Branch read, the tab asks for Branch with the panel shut, per-file reads, pacing, release when hidden.            |
| 3. Unified document           | Done   | One text with headers, folds and notices in gaps, collapse, sticky header, per-file highlighting, steps across files, copy, scroll.            |
| 4. Changes list as index      | Done   | Row click shows the tab at the file, the top file's row lit, header's Open File.                                                               |
| 5. Review comments            | Done   | Cards per file, composer path, re-anchoring per file, lines held open, close asks, Review's reveal, `review add` through the tab.              |
| 6. Split                      | Done   | Per-file sides; a file all added or all removed shows full width (owner's pick, below).                                                        |
| 7. Command line, memory, docs | Done   | `tabs open-all-changes`; `tabs step`, `find` and `review add` reach the tab; Debug Info counts it; memory measured (design doc); docs written. |

## Feedback from the owner

| Feedback                                                              | Status        | What changed                                                                                                                                                                                                                                                                                     |
| --------------------------------------------------------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| In Split, a file all added or all removed shows full width, not half  | Fixed         | Such a file has no rows in either column; a full-width Unified view of it sits in its gap over both, hosted only near the clip and scrolled with the columns.                                                                                                                                    |
| Screenshot the tab and compare with the mockups                       | Done          | Headers and folds now span the gutter, each file sits in a bordered box with a margin, fold rows wear the blue band, the sticky header is opaque.                                                                                                                                                |
| File contents blank in large diffs                                    | Fixed         | TextKit found a scroll's top by summing fragment heights, which left out the gaps; with a header every few rows it laid out rows far below the clip. A fragment's height now counts the gap under it. Test: `theRowsOnScreenAreInTextKitsViewportWithAGapEverySixRows`.                          |
| Clicking a Changes row when files fit in the viewport changes nothing | Fixed         | The clicked row lights at once and stays lit while the view stays where the click left it. Test: `aClickedRowIsLitAtOnceThoughTheTabMayNotScrollItsFileToTheTop`.                                                                                                                                |
| Scrollbar hidden behind the tab's content                             | Fixed         | In Unified the gutter and the header layer sit inside the scroll view under its scrollers; in Split the header layer stops short of the right column's scroller. Needs a look on screen.                                                                                                         |
| Highlight only the files in the viewport                              | Done          | Only files within a clip either side of the view are parsed and coloured; more as it scrolls, parses kept by path.                                                                                                                                                                               |
| Split: the left column scrolls apart from the headers and the right   | Fixed for now | The left has no scroller and turns the right with its wheel; the lock pulls a side back where the other stops short. Tests: `aSideThatStopsShortOfTheOthersScrollPullsItBackToTheSameRows`, `bothSidesStayOnTheSameOffsetWhenGapsAboveTheEndShrink`. A single-scroller rework is proposed below. |
| Split: the left column has its own scrollbar                          | Fixed         | Hidden in the All changes split.                                                                                                                                                                                                                                                                 |
| Comment badge right of the filename, not left of the counts           | Fixed         | The Files and Changes rows put the badge beside the counts, as the mockups do.                                                                                                                                                                                                                   |
| Is two scroll views with layers on top the right approach?            | Answered      | No; one scroll view whose document holds gutters, columns, headers, folds and cards as subviews removes the lock and the overlay layout. Recommended; starting unless told otherwise.                                                                                                            |
| Stop the code review while bugs remain                                | Done          | Review paused.                                                                                                                                                                                                                                                                                   |
| Scrollbar still hidden behind the headers and folds                   | Fixed         | In both layouts the scroller sits in the right margin, outside the file boxes, so nothing hosted lies over it.                                                                                                                                                                                  |
| Split: added/removed files have a different margin than modified ones | Fixed         | Their gutter takes the left column's width and their first row sits under the header as in Unified. Tests: `aGutterIsAsWideAsItsMinimumWhenItsNumbersAreNarrower`, `aFilesHeightBeforeItsViewMeasuresIsItsRowsAloneWithoutTheColumnsGapsOrInsets`.                                            |
| Gap between the comment + and a short file's numbers                 | Left as is    | One gutter for the tab, its numbers right-aligned to the widest in any file; the owner chose to leave it for now.                                                                                                                                                                               |
| Split: the column divider shows above the first file and below the last | Fixed       | The divider runs from the first file's box to the last file's end. Test: `theDividerRunsOnlyOverItsSpanFromTheViewsTop`.                                                                                                                                                                         |
| Fold at the top of a large file: how far it opens                     | Decided       | All of it, for now.                                                                                                                                                                                                                                                                              |
| Remember a collapsed file across relaunches                           | Decided       | Not required; maybe later.                                                                                                                                                                                                                                                                       |
| The memory cap's number                                               | Decided       | The goal is to render only what is on screen, so memory stays small; see "Queued rework".                                                                                                                                                                                                       |

## Found while checking

- **1.43 GB for 1,802 changed files.** Every header and fold was a SwiftUI
  hosting view. Now only those near the clip are hosted: 191 MB.
- **A new file list waited minutes to show.** A read of every file was paced at
  ten times its whole cost; the pace is now the cost per file times the files
  the next read reads.
- **Crash: exclusive access** when a whole file's card changed its height
  mid-layout. The height change now lands a turn later.

## Review rounds

Capped at 5 unless the owner asks otherwise; settled findings go in the design
doc's "Reviewed and left as is".

| Round | Status                                 | Findings |
| ----- | -------------------------------------- | -------- |
| 1     | Stopped by the owner while bugs remain |          |

The work is staged, not committed: the commit before review was refused, the
project committing only when asked.

## Now, in the owner's order

Each is committed when done. Committed so far: the tab and its fixes, `17dedf08`, in PR #43; the
blank rows, `b3e3fcf0`; the wide scrollbar, `c98b4529`.

| Work                                    | Status      | Notes                                                                                                                                                                                                                                  |
| --------------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1. Blank rows after collapsing files    | Committed `b3e3fcf0` | Files collapsed above the first expanded one stack their headers in the gap over row 0, which no row's height counted, so TextKit placed the first rows too high and left them blank. TextKit's container now starts under that gap. Test: `theFirstRowsAreLaidOutUnderATallGapAboveTheFirstRow`. |
| 2. Unified and Split on one canvas      | Done        | One scroller over a canvas, `DiffCanvasView`, for file tabs and the All changes tab: each column's gutter and text, the divider, headers, folds, notices, boxes and Split's whole files all scroll natively. The lock, the wheel forwarding, the left's hidden scroller and the per-scroll overlay layout are gone. Columns scroll sideways together; not yet checked on screen by the owner. |
| 3. The tab stays blank for seconds      | After the rework | It reads every file, one git run each, four at a time, and joins all rows before showing any. Speed it up; where it cannot be fast, show a loading indicator.                                                                          |
| Wide scrollbar after Split to Unified   | Fixed       | The overlay scroller grows to 17 pt under the pointer, which the Unified/Split switch leaves above it, and covered the box's edge from a 12 pt margin. The right margin is now as wide as the scroller. Tests: `noHeaderOrFoldReachesTheVerticalScrollerAtItsWidest`, `noSplitHeaderOrFoldReachesTheVerticalScrollerAtItsWidest`. |
| Sticky header hides the next file's header | Fixed  | The next file's header pushes the sticky copy up and out, clipped at the rows' top. Tests: `AllChangesTopFileTests`. |

## Queued rework

- **Unified and Split on one canvas** (owner: for file tabs too, Split's
  columns sideways together, Unified folded in). Today Split is two scroll
  views locked by offset, with the headers, folds, boxes and whole files in a
  layer over both; the left column has no scroller and forwards its wheel, and
  the lock pulls a side back where the other clamps. Unified has one scroll
  view, but its gutter, headers, folds, notices and boxes sit over the clip and
  are moved on every scroll, so they can trail the text by a frame. The plan:
  one scroller whose document is a canvas holding each column's gutter and
  text, the divider, the headers, folds, notices, boxes and cards as subviews,
  so everything scrolls natively and nothing is re-laid per scroll. Unified is
  one column, Split two. Each column keeps `DiffDocumentView`'s code for cards,
  steps, restores and reveals, scrolled by the canvas's scroller instead of
  its own. That drops the lock, the wheel forwarding, the left's hidden
  scroller and the overlays. Later, putting an added or removed file's rows in
  Split's columns would let find, the arrows and the rotor reach them.
- **Hold only the rows near the screen.** Layout and hosted views are already
  only what is on screen. Every file's rows are still read and held: 13 MB for
  82,895 lines across 1,802 files, plus the per-file reads. Reading each file
  as it nears the clip, from the list's counts for the heights, would make
  memory track the screen and let the 200,000-row cap go.

## Still open on the issue

- Whether `review add` prefers a shown file tab or the All changes tab (now: the
  file tab).
