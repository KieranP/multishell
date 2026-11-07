import AppKit

/// Takes the keyboard as it lands in the window, the switcher opening over
/// whichever pane had it.
final class QuickSwitcherNSTextField: NSTextField {
  /// The theme's selection, for the editor made as the field takes the keyboard.
  var selection: NSColor?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard let window, window.makeFirstResponder(self) else { return }
    guard let editor = currentEditor() as? NSTextView else { return }
    // Taking the keyboard selects every character; see field-keys-and-look.md.
    editor.selectedRange = NSRange(location: stringValue.utf16.count, length: 0)
    // The editor is made here, after the first update gave the field its colours.
    if let textColor { editor.insertionPointColor = textColor }
    if let selection { editor.selectedTextAttributes = [.backgroundColor: selection] }
  }
}
