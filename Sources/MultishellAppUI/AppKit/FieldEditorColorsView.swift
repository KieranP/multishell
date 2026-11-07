import AppKit

/// Gives the window's field editor the theme's selection and caret while the
/// field it sits behind has the keyboard. AppKit's are the system accent's.
final class FieldEditorColorsView: AccessibilityHiddenView {
  private var selection = NSColor.clear
  private var caret = NSColor.clear
  private var isFocused = false
  private var firstResponderWatch: NSKeyValueObservation?

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  /// The editor takes the keyboard after SwiftUI's focus says the field has
  /// it, so the window's responder is watched rather than read once.
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    firstResponderWatch = window?.observe(\.firstResponder) { [weak self] _, _ in
      MainActor.assumeIsolated { self?.recolourEditor() }
    }
    recolourEditor()
  }

  func update(selection: NSColor, caret: NSColor, isFocused: Bool) {
    self.selection = selection
    self.caret = caret
    self.isFocused = isFocused
    recolourEditor()
  }

  /// Background only, so the selected text keeps the field's own colour.
  private func recolourEditor() {
    guard isFocused, let editor = window?.firstResponder as? NSTextView, editor.isFieldEditor
    else { return }
    editor.selectedTextAttributes = [.backgroundColor: selection]
    editor.insertionPointColor = caret
  }
}
