import AppKit

extension NSPasteboard {
  func replaceContents(withText text: String) {
    clearContents()
    setString(text, forType: .string)
  }
}
