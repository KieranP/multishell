import SwiftUI

extension View {
  /// A text field's selection and caret in the theme's colours while
  /// `isFocused`, the field's own focus; SwiftUI's `tint` lightens the selection.
  func fieldEditorColors(selection: Color, caret: Color, isFocused: Bool) -> some View {
    background {
      FieldEditorColorsSetter(selection: selection, caret: caret, isFocused: isFocused)
    }
  }
}
