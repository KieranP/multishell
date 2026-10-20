import AppKit
import SwiftUI

/// Keeps the branch name field and its binding showing the same text: each
/// edit goes to the binding, and what the binding makes of it comes back.
@MainActor
final class NewWorktreeBranchNameFieldDelegate: NSObject, NSTextFieldDelegate {
  var text: Binding<String>
  private var storageObservers: [any NSObjectProtocol] = []
  private weak var followedEditor: NSTextView?

  init(text: Binding<String>) {
    self.text = text
  }

  func controlTextDidChange(_ notification: Notification) {
    guard let editor = fieldEditor(in: notification), !editor.hasMarkedText() else { return }
    let typed = editor.string
    text.wrappedValue = typed
    let fixed = text.wrappedValue
    if fixed != typed { replaceText(of: editor, with: fixed) }
  }

  // Undo and redo change the editor's storage without `controlTextDidChange`,
  // which left the draft holding a name the field no longer showed.
  func controlTextDidBeginEditing(_ notification: Notification) {
    guard let editor = fieldEditor(in: notification) else { return }
    startFollowingEdits(of: editor)
  }

  func controlTextDidEndEditing(_ notification: Notification) {
    stopFollowingEdits()
  }

  private func fieldEditor(in notification: Notification) -> NSTextView? {
    (notification.object as? NSTextField)?.currentEditor() as? NSTextView
  }

  /// Through the editor's change calls, so undo records the replacement as an
  /// edit; the caret keeps its distance from the end.
  private func replaceText(of editor: NSTextView, with replacement: String) {
    let wholeRange = NSRange(location: 0, length: (editor.string as NSString).length)
    let charactersAfterCaret = wholeRange.length - editor.selectedRange().location
    guard editor.shouldChangeText(in: wholeRange, replacementString: replacement) else { return }
    editor.replaceCharacters(in: wholeRange, with: replacement)
    editor.didChangeText()
    let caret = max(0, (replacement as NSString).length - charactersAfterCaret)
    editor.setSelectedRange(NSRange(location: caret, length: 0))
  }

  private func startFollowingEdits(of editor: NSTextView) {
    stopFollowingEdits()
    guard let storage = editor.textStorage else { return }
    followedEditor = editor
    let storageEdited: @MainActor @Sendable (NewWorktreeBranchNameFieldDelegate) -> Void = {
      delegate in delegate.copyFollowedEditorTextToBinding()
    }
    storageObservers = NotificationCenter.default.observe(
      [(NSTextStorage.didProcessEditingNotification, storageEdited)],
      for: self,
      from: storage,
    )
  }

  private func stopFollowingEdits() {
    for observer in storageObservers { NotificationCenter.default.removeObserver(observer) }
    storageObservers = []
    followedEditor = nil
  }

  private func copyFollowedEditorTextToBinding() {
    guard let editor = followedEditor, !editor.hasMarkedText(), editor.string != text.wrappedValue
    else { return }
    text.wrappedValue = editor.string
  }

  isolated deinit {
    stopFollowingEdits()
  }
}
