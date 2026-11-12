import AppKit
import MultishellAppCore
import MultishellCore

extension DiffTextView {
  /// The rows the selection touches, or the caret's row.
  private var selectedRows: ClosedRange<Int>? {
    let range = selectedRange()
    guard range.location != NSNotFound, !displayText.lines.isEmpty else { return nil }
    return displayText.rows(touching: range.location..<NSMaxRange(range))
  }

  /// Comment on Lines first, the way to a comment from the keyboard and
  /// VoiceOver, neither of which reaches the gutter's +.
  override func menu(for event: NSEvent) -> NSMenu? {
    let menu = super.menu(for: event) ?? NSMenu()
    guard onCommentOnRows != nil, let rows = selectedRows,
      ReviewLineSelection(
        from: rows.lowerBound,
        to: rows.upperBound,
        in: displayText.lines,
        side: commentSide,
      ) != nil
    else { return menu }
    let item = NSMenuItem(
      title: t("review.comment-on-lines"),
      action: #selector(commentOnSelectedLines),
      keyEquivalent: "",
    )
    item.target = self
    menu.insertItem(item, at: 0)
    menu.insertItem(.separator(), at: 1)
    return menu
  }

  @objc private func commentOnSelectedLines() {
    guard let rows = selectedRows else { return }
    onCommentOnRows?(rows)
  }
}
