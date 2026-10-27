import AppKit
import MultishellCore

/// Hands each edit to the model, and the keys the list answers to its
/// handlers before the field editor sees them.
@MainActor
final class QuickSwitcherTextFieldDelegate: NSObject, NSTextFieldDelegate {
  /// Backspace, and with Option or Command.
  private static let backspaces: Set<Selector> = [
    #selector(NSResponder.deleteBackward(_:)),
    #selector(NSResponder.deleteWordBackward(_:)),
    #selector(NSResponder.deleteToBeginningOfLine(_:)),
  ]

  var handlers: QuickSwitcherFieldHandlers

  init(handlers: QuickSwitcherFieldHandlers) {
    self.handlers = handlers
  }

  func controlTextDidChange(_ notification: Notification) {
    guard let editor = (notification.object as? NSTextField)?.currentEditor() as? NSTextView
    else { return }
    handlers.onCompose(editor.hasMarkedText())
    guard !editor.hasMarkedText() else { return }
    // Now, not on the next redraw: a key typed before it would send the old text.
    let kept = handlers.setText(editor.string)
    if kept != editor.string { editor.string = kept }
  }

  func controlTextDidEndEditing(_ notification: Notification) {
    handlers.onEndEditing()
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
    let isEmptyBackspace = textView.string.isEmpty && Self.backspaces.contains(selector)
    switch selector {
    case #selector(NSResponder.moveUp(_:)): handlers.move(.previous)
    case #selector(NSResponder.moveDown(_:)): handlers.move(.next)
    case #selector(NSResponder.insertTab(_:)): handlers.stepScope(.next)
    case #selector(NSResponder.insertBacktab(_:)): handlers.stepScope(.previous)
    case #selector(NSResponder.insertNewline(_:)): handlers.choose()
    case #selector(NSResponder.cancelOperation(_:)): handlers.close()
    case _ where isEmptyBackspace: handlers.onBackspaceWhenEmpty()
    default: return false
    }
    return true
  }
}
