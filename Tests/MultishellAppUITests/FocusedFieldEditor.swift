import AppKit
import SwiftUI
import Testing

@testable import MultishellCore

/// A view's first text field given the keyboard in a window never shown, and
/// a theme that tells its selection colour from its caret's.
@MainActor
enum FocusedFieldEditor {
  static let selection = NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1)
  static let caret = NSColor(srgbRed: 0, green: 1, blue: 1, alpha: 1)

  /// `section`'s `selection_background` in `selection` and `caretKey` in `caret`.
  static func theme(_ section: InterfaceSection, caretKey: InterfaceColorKey) throws -> Theme {
    let colours =
      ##""selection_background": "#ff00ff", "\##(caretKey.rawValue)": "#00ffff""##
    let json =
      #"{ "id": "fields", "name": "Fields", "ui": { "\#(section.rawValue)": { \#(colours) } } }"#
    return try JSONDecoder().decode(Theme.self, from: Data(json.utf8))
  }

  /// The editor `content`'s first editable field edits in, once it has the keyboard.
  static func editor(
    of content: some View,
    size: CGSize = CGSize(width: 320, height: 60),
  ) throws -> (NSTextView, NSWindow) {
    let host = NSHostingView(rootView: content)
    host.frame = NSRect(origin: .zero, size: size)
    let window = OffscreenWindow.holding(host, deferred: false)
    OffscreenWindow.settle(within: 0.1)
    let editable = host.descendants(of: NSTextField.self).filter(\.isEditable)
    let field = try #require(editable.first)
    if field.currentEditor() == nil { #expect(window.makeFirstResponder(field)) }
    OffscreenWindow.settle(within: 0.1)
    let editor = try #require(field.currentEditor() as? NSTextView)
    return (editor, window)
  }

  static func expectThemeColours(
    in editor: NSTextView,
    sourceLocation: SourceLocation = #_sourceLocation,
  ) {
    let selection = editor.selectedTextAttributes[.backgroundColor] as? NSColor
    #expect(isSame(selection, as: Self.selection), "selection", sourceLocation: sourceLocation)
    #expect(
      isSame(editor.insertionPointColor, as: caret),
      "caret",
      sourceLocation: sourceLocation,
    )
  }

  static func isSame(_ drawn: NSColor?, as expected: NSColor) -> Bool {
    guard let drawn = drawn?.usingColorSpace(.sRGB), let expected = expected.usingColorSpace(.sRGB)
    else { return false }
    return [
      drawn.redComponent - expected.redComponent,
      drawn.greenComponent - expected.greenComponent,
      drawn.blueComponent - expected.blueComponent,
      drawn.alphaComponent - expected.alphaComponent,
    ].allSatisfy { abs($0) < 0.01 }
  }
}
