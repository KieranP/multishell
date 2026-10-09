import AppKit

/// Asked before a paste libghostty judges unsafe reaches a program that could
/// run it as it lands. Paste takes Return, as in Ghostty's own app.
@MainActor
enum UnsafePasteAlert {
  private static let previewSize = NSSize(width: 420, height: 160)

  static func make(text: String) -> NSAlert {
    let alert = WarningAlert.make(
      title: t("paste.unsafe-title"),
      message: t("paste.unsafe-message"),
      action: t("paste.unsafe-paste"),
    )
    alert.accessoryView = preview(of: text)
    return alert
  }

  /// The text as it would be typed, line breaks and all, to read before it lands.
  private static func preview(of text: String) -> NSScrollView {
    let scroll = NSScrollView(frame: NSRect(origin: .zero, size: previewSize))
    scroll.hasVerticalScroller = true
    scroll.borderType = .bezelBorder
    let textView = NSTextView(frame: NSRect(origin: .zero, size: scroll.contentSize))
    textView.string = text
    textView.isEditable = false
    textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
    textView.autoresizingMask = [.width]
    scroll.documentView = textView
    return scroll
  }
}
