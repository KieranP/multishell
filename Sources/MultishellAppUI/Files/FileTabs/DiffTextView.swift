import AppKit
import MultishellAppCore
import MultishellCore

/// A file tab's text: read-only, never wrapped, every row's geometry forced
/// so it sits where `DiffRowGeometry` says; see Docs/design/files.md.
@MainActor
final class DiffTextView: NSTextView {
  /// Room after the widest line, so its last glyph is not against the edge.
  private static let trailingPadding: CGFloat = 24
  /// AppKit's default tab stop, which no line's tab can pass in one step.
  private static let tabStopWidth: CGFloat = 28
  /// U+FDFD, the widest glyph measured, is 5.3 monospace spaces in one UTF-16
  /// unit; no font's widest ASCII glyph is narrower than its space.
  private static let widestUnitInASCIIAdvances: CGFloat = 6

  /// Held here: a layout manager holds its delegate weakly.
  private let rowLayout: FixedRowLayoutDelegate
  private(set) var displayText = DiffDisplayText([])
  /// Unified copies a selection touching a change as `git diff` prints it;
  /// a split side copies plain text.
  var copiesAsDiff = true
  var onFocus: (() -> Void)?
  /// The selected text as it changes, `nil` for none, for Cmd+F to find.
  var onSelectionChange: ((String?) -> Void)?
  private var lineTints: (added: NSColor, removed: NSColor) = (.clear, .clear)
  private(set) var partTints: (added: NSColor, removed: NSColor) = (.clear, .clear)
  private var paddingTint = NSColor.clear
  /// The find bar's, painted under the text with the line tints; see
  /// `showFindMatches`.
  var findMatchPaint: (matches: [Range<Int>], tint: NSColor) = ([], .clear)
  private var documentWidth: CGFloat = 0
  /// The highlight runs the text carries at its current offsets, so the next
  /// apply changes only what differs; `nil` while unknown, mid-apply.
  var appliedRuns: [HighlightSpan]? = []
  /// Counts each `show`, so an apply spread over turns stops at the next.
  private(set) var shownGeneration = 0
  private var shownTheme: Theme?
  /// Set while `show` swaps the text: rows sized to the new one would be laid
  /// out against the old storage.
  private(set) var isReplacingText = false

  var geometry: DiffRowGeometry { rowLayout.geometry }

  init(geometry: DiffRowGeometry) {
    rowLayout = FixedRowLayoutDelegate(geometry: geometry)
    let layoutManager = NSTextLayoutManager()
    let contentStorage = NSTextContentStorage()
    contentStorage.addTextLayoutManager(layoutManager)
    let container = NSTextContainer(
      size: CGSize(width: 1, height: CGFloat.greatestFiniteMagnitude)
    )
    container.widthTracksTextView = false
    container.heightTracksTextView = false
    container.lineFragmentPadding = 0
    layoutManager.textContainer = container
    layoutManager.delegate = rowLayout
    super.init(frame: NSRect(x: 0, y: 0, width: 1, height: 1), textContainer: container)
    isEditable = false
    isSelectable = true
    isRichText = false
    allowsUndo = false
    usesFindBar = false
    isHorizontallyResizable = true
    isVerticallyResizable = true
    autoresizingMask = []
    maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
    textContainerInset = NSSize(width: 0, height: DiffRowGeometry.verticalInset)
  }

  required init?(coder: NSCoder) { nil }

  /// Sized to the widest line before the text lands: an unbounded container,
  /// or a view narrower than its container, laid out the whole file at once.
  func show(_ text: DiffDisplayText, theme: Theme) {
    isReplacingText = true
    defer { isReplacingText = false }
    let selected = selectedRanges
    let previous = displayText
    displayText = text
    rowLayout.text = text
    lineTints = (theme.addedLineTint, theme.removedLineTint)
    partTints = (theme.addedPartTint, theme.removedPartTint)
    paddingTint = theme.paddingRowTint
    backgroundColor = theme.fileBackground
    let drawn = text.drawnString
    documentWidth = widestLine(of: text, drawn: drawn) + Self.trailingPadding
    textContainer?.size = CGSize(width: documentWidth, height: .greatestFiniteMagnitude)
    setFrameSize(frame.size)
    shownGeneration += 1
    if shownTheme == theme, appliedRuns != nil, !previous.lines.isEmpty {
      replaceChangedRows(of: previous, with: text, drawn: drawn, theme: theme)
    } else {
      let whole = 0..<drawn.utf16.count
      textStorage?.setAttributedString(
        attributedText(text, drawn: drawn, units: whole, theme: theme)
      )
      appliedRuns = []
    }
    shownTheme = theme
    let carried = selected.compactMap { value -> NSValue? in
      let range = value.rangeValue
      guard let moved = text.carriedSelection(range.location..<NSMaxRange(range), from: previous)
      else { return nil }
      return NSValue(range: NSRange(location: moved.lowerBound, length: moved.count))
    }
    selectedRanges = carried.isEmpty ? [NSValue(range: NSRange(location: 0, length: 0))] : carried
    needsDisplay = true
  }

  /// `NSTextView` resets its width to the clip's during layout; held here to
  /// the widest line and the rows' height.
  override func setFrameSize(_ newSize: NSSize) {
    let clip = enclosingScrollView?.contentSize ?? .zero
    super.setFrameSize(
      NSSize(
        width: max(newSize.width, documentWidth, clip.width),
        height: max(geometry.documentHeight(rows: displayText.lines.count), clip.height),
      )
    )
  }

  /// The tints run edge to edge past a short line and while scrolled sideways.
  override func drawBackground(in dirtyRect: NSRect) {
    // TextKit 2 asks for more than the view holds; filling it all painted
    // over the views above the file.
    let rect = dirtyRect.intersection(bounds)
    backgroundColor.setFill()
    rect.fill()
    for row in geometry.rows(in: rect, count: displayText.lines.count) {
      switch displayText.lines[row].kind {
      case .added: lineTints.added.setFill()
      case .removed: lineTints.removed.setFill()
      case .context: continue
      case .padding: paddingTint.setFill()
      }
      NSRect(
        x: rect.minX,
        y: geometry.top(ofRow: row),
        width: rect.width,
        height: geometry.rowHeight,
      )
      .fill()
    }
    drawChangedParts(in: rect)
    drawFindMatches(in: rect)
  }

  override func setSelectedRanges(
    _ ranges: [NSValue],
    affinity: NSSelectionAffinity,
    stillSelecting: Bool,
  ) {
    super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
    guard !stillSelecting, let onSelectionChange else { return }
    let range = selectedRange()
    onSelectionChange(
      range.length > 0 ? (displayText.string as NSString).substring(with: range) : nil
    )
  }

  override func becomeFirstResponder() -> Bool {
    let became = super.becomeFirstResponder()
    if became { onFocus?() }
    return became
  }

  /// Copy, a drag of the selection and Services all write through here.
  override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
    guard type == .string else { return super.writeSelection(to: pboard, type: type) }
    return pboard.setString(selectionCopy(), forType: .string)
  }

  override func writeSelection(
    to pboard: NSPasteboard,
    types: [NSPasteboard.PasteboardType],
  ) -> Bool {
    pboard.declareTypes([.string], owner: nil)
    return pboard.setString(selectionCopy(), forType: .string)
  }

  private func selectionCopy() -> String {
    let selections = selectedRanges.map(\.rangeValue).map { $0.location..<NSMaxRange($0) }
    guard copiesAsDiff else { return displayText.plainCopy(selections: selections) }
    return displayText.diffCopy(selections: selections)
  }

  /// Measured from glyphs as drawn, not UTF-16 columns, which are wrong for
  /// tabs and CJK; a line whose widest possible width is narrower is never measured.
  private func widestLine(of text: DiffDisplayText, drawn: String) -> CGFloat {
    let advance = geometry.widestASCIIAdvance
    // Only a fixed-pitch font's ASCII line is as wide as its bound.
    let isFixedPitch = geometry.font.isFixedPitch
    let drawnText = drawn as NSString
    var widest: CGFloat = 0
    var unmeasured: [(row: Int, bound: CGFloat)] = []
    for (row, line) in text.lines.enumerated() {
      var isPlainASCII = true
      var bound: CGFloat = 0
      for unit in line.text.utf16 {
        if unit >= 0x20, unit < 0x7F {
          bound += advance
        } else {
          isPlainASCII = false
          bound += unit == 0x09 ? Self.tabStopWidth : advance * Self.widestUnitInASCIIAdvances
        }
      }
      if isPlainASCII, isFixedPitch {
        widest = max(widest, bound)
      } else {
        unmeasured.append((row, bound))
      }
    }
    // Widest bound first: a proportional font measured every line, 190 ms
    // for 20,000, its bounds two to four times the width.
    for (row, bound) in unmeasured.sorted(by: { $0.bound > $1.bound }) {
      guard bound > widest else { break }
      let drawnLine = drawnText.substring(with: NSRange(text.range(ofRow: row)))
      widest = max(
        widest,
        (drawnLine as NSString).size(withAttributes: [.font: geometry.font]).width,
      )
    }
    return widest.rounded(.up)
  }
}
