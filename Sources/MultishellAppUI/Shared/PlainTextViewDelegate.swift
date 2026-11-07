import AppKit
import SwiftUI

/// Hands each edit of a `PlainTextView` to its binding, from its text storage:
/// an Undo edits the storage without the text view's change notification.
@MainActor
final class PlainTextViewDelegate: NSObject, @preconcurrency NSTextStorageDelegate {
  var text: Binding<String>

  init(text: Binding<String>) {
    self.text = text
  }

  func textStorage(
    _ textStorage: NSTextStorage,
    didProcessEditing editedMask: NSTextStorageEditActions,
    range editedRange: NSRange,
    changeInLength delta: Int,
  ) {
    guard editedMask.contains(.editedCharacters), text.wrappedValue != textStorage.string else {
      return
    }
    text.wrappedValue = textStorage.string
  }
}
