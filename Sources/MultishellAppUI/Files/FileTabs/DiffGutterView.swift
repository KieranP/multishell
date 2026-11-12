import AppKit
import MultishellAppCore
import MultishellCore

/// Line numbers, change bars and the + to comment, redrawn as the clip scrolls:
/// `NSRulerView` went stale across programmatic scrolls on macOS 26.
@MainActor
final class DiffGutterView: NSView {
  private static let signWidth: CGFloat = 12
  private static let barWidth: CGFloat = 3
  private static let trailing: CGFloat = 6

  /// New text ends a drag and the +, their rows being the old text's.
  var displayText = DiffDisplayText.empty {
    didSet {
      draggedRows = nil
      hoveredRow = nil
    }
  }
  /// Whose line numbers the rows carry: the committed side's on a split's left.
  var numbering = DiffSide.onDisk
  /// A split column's side; `nil` in Unified, where a removed row's is the committed side.
  var commentSide: DiffSide?
  var onCommentOnRows: ((_ start: Int, _ end: Int) -> Void)?
  var hoveredRow: Int? { didSet { if hoveredRow != oldValue { needsDisplay = true } } }
  /// The row a drag started on and the one under the pointer.
  var draggedRows: (start: Int, end: Int)? { didSet { needsDisplay = true } }
  /// The text's, its review card gaps included.
  var geometry: DiffRowGeometry { didSet { needsDisplay = true } }
  /// The clip's top in the document. A scroll clears the +, the pointer reporting no move.
  var scrolledTo: CGFloat = 0 {
    didSet {
      guard scrolledTo != oldValue else { return }
      hoveredRow = nil
      needsDisplay = true
    }
  }
  private var colors: (number: NSColor, added: NSColor, removed: NSColor, background: NSColor) =
    (.secondaryLabelColor, .systemGreen, .systemRed, .clear)
  /// The + on its mark, and a drag's rows, in the theme's file colours.
  private(set) var commentColors: (mark: NSColor, plus: NSColor, dragged: NSColor) =
    (.clear, .clear, .clear)

  override var isFlipped: Bool { true }

  /// Follows the widest number, five digits having collided with the sign
  /// at a fixed 52 pt.
  var preferredWidth: CGFloat {
    let largest = displayText.lines.compactMap { $0.number(on: numbering) }.max() ?? 1
    let digits = CGFloat(String(largest).count)
    return plusColumnWidth + digits * digitWidth + Self.signWidth + Self.barWidth + Self.trailing
  }

  /// Left of the numbers, so a click on a number never opens a composer.
  var plusColumnWidth: CGFloat { geometry.rowHeight }

  private var digitWidth: CGFloat {
    ("0" as NSString).size(withAttributes: [.font: geometry.font]).width
  }

  init(geometry: DiffRowGeometry) {
    self.geometry = geometry
    super.init(frame: .zero)
    clipsToBounds = true
  }

  required init?(coder: NSCoder) { nil }

  func apply(_ theme: Theme) {
    colors = (
      theme.lineNumberText, theme.addedLineMark, theme.removedLineMark, theme.fileBackground,
    )
    commentColors = (theme.commentMark, theme.fileBackground, theme.fileSelection)
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    colors.background.setFill()
    dirtyRect.intersection(bounds).fill()
    let visible = NSRect(x: 0, y: scrolledTo, width: bounds.width, height: bounds.height)
    let numberAttributes: [NSAttributedString.Key: Any] = [
      .font: geometry.font, .foregroundColor: colors.number,
    ]
    let numberRight = bounds.width - Self.signWidth - Self.barWidth - Self.trailing
    for row in geometry.rows(in: visible, count: displayText.lines.count) {
      let line = displayText.lines[row]
      let top = geometry.top(ofRow: row) - scrolledTo
      drawCommentMarks(onRow: row, top: top)
      let textTop =
        top + (geometry.rowHeight - geometry.font.ascender + geometry.font.descender) / 2
      if let number = line.number(on: numbering) {
        let text = String(number) as NSString
        let width = text.size(withAttributes: numberAttributes).width
        text.draw(
          at: NSPoint(x: numberRight - width, y: textTop),
          withAttributes: numberAttributes,
        )
      }
      drawMark(for: line, top: top, textTop: textTop)
    }
  }

  /// A staged change draws its bar hollow and an unstaged one filled, as Zed
  /// does, with the sign beside it so colour never says it alone.
  private func drawMark(for line: DiffLine, top: CGFloat, textTop: CGFloat) {
    let color: NSColor
    let sign: String
    switch line.kind {
    case .added: (color, sign) = (colors.added, "+")
    case .removed: (color, sign) = (colors.removed, "−")
    case .context, .padding: return
    }
    let barX = bounds.width - Self.barWidth - Self.trailing / 2
    (sign as NSString).draw(
      at: NSPoint(x: barX - Self.signWidth + 2, y: textTop),
      withAttributes: [.font: geometry.font, .foregroundColor: color],
    )
    let bar = NSRect(x: barX, y: top + 1, width: Self.barWidth, height: geometry.rowHeight - 2)
    color.set()
    if line.isStaged {
      let outline = NSBezierPath(rect: bar.insetBy(dx: 0.5, dy: 0.5))
      outline.lineWidth = 1
      outline.stroke()
    } else {
      bar.fill()
    }
  }
}
