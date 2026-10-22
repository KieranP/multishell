import AppKit
import MultishellAppCore
import MultishellCore

/// The text storage `show` fills: whole on a first show or a new theme, and
/// on a re-read only between the rows left as they were.
extension DiffTextView {
  /// From the end of the last row of `top` to the start of the first of
  /// `bottom`, the newlines between them included.
  private static func unitsBetween(top: Int, bottom: Int, of text: DiffDisplayText) -> Range<Int> {
    let length = text.string.utf16.count
    let lower = top == 0 ? 0 : text.range(ofRow: top - 1).upperBound
    let upper = bottom == 0 ? length : text.rowStarts[text.lines.count - bottom]
    return lower..<max(lower, upper)
  }

  /// The runs outside `replaced`, cut at its edges, those after it moved.
  private static func runs(
    _ runs: [HighlightSpan],
    around replaced: Range<Int>,
    shiftedBy shift: Int,
  ) -> [HighlightSpan] {
    var kept: [HighlightSpan] = []
    kept.reserveCapacity(runs.count)
    for run in runs {
      let range = run.range
      if range.upperBound <= replaced.lowerBound {
        kept.append(run)
      } else if range.lowerBound >= replaced.upperBound {
        kept.append(HighlightSpan(range: range.shifted(by: shift), role: run.role))
      } else {
        if range.lowerBound < replaced.lowerBound {
          kept.append(HighlightSpan(range: range.lowerBound..<replaced.lowerBound, role: run.role))
        }
        if range.upperBound > replaced.upperBound {
          let after = (replaced.upperBound..<range.upperBound).shifted(by: shift)
          kept.append(HighlightSpan(range: after, role: run.role))
        }
      }
    }
    return kept
  }

  /// A 1 MiB file replaced whole took 80 ms on the main actor; the rows a
  /// save left keep their storage, layout and colours.
  func replaceChangedRows(
    of previous: DiffDisplayText,
    with text: DiffDisplayText,
    drawn: String,
    theme: Theme,
  ) {
    guard let storage = textStorage else { return }
    let (old, new) = (previous.lines, text.lines)
    let shared = min(old.count, new.count)
    let isSame = { (first: DiffLine, second: DiffLine) in
      first.kind == second.kind && first.text == second.text
    }
    var top = 0
    while top < shared, isSame(old[top], new[top]) { top += 1 }
    var bottom = 0
    while bottom < shared - top, isSame(old[old.count - 1 - bottom], new[new.count - 1 - bottom]) {
      bottom += 1
    }
    let replaced = Self.unitsBetween(top: top, bottom: bottom, of: previous)
    let replacing = Self.unitsBetween(top: top, bottom: bottom, of: text)
    guard !(replaced.isEmpty && replacing.isEmpty) else { return }
    storage.replaceCharacters(
      in: NSRange(replaced),
      with: attributedText(text, drawn: drawn, units: replacing, theme: theme),
    )
    appliedRuns = appliedRuns.map { runs in
      Self.runs(runs, around: replaced, shiftedBy: replacing.count - replaced.count)
    }
  }

  /// `units` of the drawn text, a removed row's held back.
  func attributedText(
    _ text: DiffDisplayText,
    drawn: String,
    units: Range<Int>,
    theme: Theme,
  ) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.minimumLineHeight = geometry.rowHeight
    paragraph.maximumLineHeight = geometry.rowHeight
    paragraph.lineBreakMode = .byClipping
    let attributed = NSMutableAttributedString(
      string: (drawn as NSString).substring(
        with: NSRange(units)
      ),
      attributes: [
        .font: geometry.font, .foregroundColor: theme.fileText, .paragraphStyle: paragraph,
      ],
    )
    colorRemovedRows(
      of: text,
      in: units,
      of: attributed,
      startingAt: units.lowerBound,
      theme: theme,
    )
    return attributed
  }
}
