import AppKit

extension NSPasteboard {
  /// A pasteboard of the test's own; release it with `releaseGlobally()`.
  static func holding(_ data: Data, as type: PasteboardType = .png) -> NSPasteboard {
    let pasteboard = Self.withUniqueName()
    pasteboard.clearContents()
    pasteboard.setData(data, forType: type)
    return pasteboard
  }
}
