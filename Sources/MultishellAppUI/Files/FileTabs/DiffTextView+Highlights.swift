import AppKit
import MultishellAppCore
import MultishellCore

extension DiffTextView {
  /// Each turn's share of an apply: 150,000 runs of a 1 MiB file took 75 ms
  /// at once on the main actor.
  private static let editsPerTurn = 20_000

  /// Both in text order: the runs carried that are not wanted, and the
  /// wanted that are not carried.
  private static func difference(
    from carried: [HighlightSpan],
    to wanted: [HighlightSpan],
  ) -> (stale: [HighlightSpan], fresh: [HighlightSpan]) {
    var stale: [HighlightSpan] = []
    var fresh: [HighlightSpan] = []
    var (old, new) = (0, 0)
    while old < carried.count || new < wanted.count {
      guard old < carried.count else {
        fresh.append(wanted[new])
        new += 1
        continue
      }
      guard new < wanted.count else {
        stale.append(carried[old])
        old += 1
        continue
      }
      let (was, will) = (carried[old], wanted[new])
      if was == will {
        old += 1
        new += 1
      } else if was.range.lowerBound <= will.range.lowerBound {
        stale.append(was)
        old += 1
      } else {
        fresh.append(will)
        new += 1
      }
    }
    return (stale, fresh)
  }

  /// Colours the shown text, a comment italic too, changing only runs that
  /// differ from those it carries; the main actor's time, `nil` if stopped.
  func applyHighlights(
    _ runs: [HighlightSpan],
    for text: DiffDisplayText,
    theme: Theme,
  ) async -> Duration? {
    guard displayText == text, let storage = textStorage else { return nil }
    let clock = ContinuousClock()
    var busy = Duration.zero
    var turnStart = clock.now
    let generation = shownGeneration
    let length = storage.length
    let (stale, fresh) = Self.difference(from: appliedRuns ?? [], to: runs)
    appliedRuns = nil
    let italic = NSFontManager.shared.convert(geometry.font, toHaveTrait: .italicFontMask)
    var colors: [HighlightRole: NSColor] = [:]
    let edits = stale.map { ($0, false) } + fresh.map { ($0, true) }
    for start in stride(from: 0, to: edits.count, by: Self.editsPerTurn) {
      if start > 0 {
        busy += turnStart.duration(to: clock.now)
        await Task.yield()
        guard shownGeneration == generation, !Task.isCancelled else { return nil }
        turnStart = clock.now
      }
      storage.beginEditing()
      for (run, isFresh) in edits[start..<min(start + Self.editsPerTurn, edits.count)]
      where run.range.upperBound <= length {
        if isFresh {
          let color = colors[run.role] ?? theme.color(for: run.role)
          colors[run.role] = color
          let range = NSRange(run.range)
          storage.addAttribute(.foregroundColor, value: color, range: range)
          if run.role == .comment { storage.addAttribute(.font, value: italic, range: range) }
        } else {
          restorePlainText(in: run.range, of: text, theme: theme)
        }
      }
      storage.endEditing()
    }
    appliedRuns = runs
    return busy + turnStart.duration(to: clock.now)
  }

  /// A run no longer highlighted, back to the text `show` set.
  private func restorePlainText(in units: Range<Int>, of text: DiffDisplayText, theme: Theme) {
    guard let storage = textStorage, !units.isEmpty else { return }
    let range = NSRange(units)
    storage.addAttribute(.foregroundColor, value: theme.fileText, range: range)
    storage.addAttribute(.font, value: geometry.font, range: range)
    colorRemovedRows(of: text, in: units, of: storage, startingAt: 0, theme: theme)
  }
}
