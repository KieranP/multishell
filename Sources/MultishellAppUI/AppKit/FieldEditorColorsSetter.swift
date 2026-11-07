import SwiftUI

struct FieldEditorColorsSetter: NSViewRepresentable {
  let selection: Color
  let caret: Color
  let isFocused: Bool

  func makeNSView(context: Context) -> FieldEditorColorsView { FieldEditorColorsView() }

  func updateNSView(_ view: FieldEditorColorsView, context: Context) {
    view.update(selection: NSColor(selection), caret: NSColor(caret), isFocused: isFocused)
  }
}
