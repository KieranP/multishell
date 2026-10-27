import AppKit
import SwiftUI

/// The quick switcher's field, AppKit's so it shows the text the model made of
/// a typed `>`, and so the arrows, Tab and Escape reach the list, not the editor.
struct QuickSwitcherTextField: NSViewRepresentable {
  let text: String
  let font: NSFont
  let color: NSColor
  let handlers: QuickSwitcherFieldHandlers

  func makeNSView(context: Context) -> QuickSwitcherNSTextField {
    let field = QuickSwitcherNSTextField(string: text)
    field.isBordered = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.lineBreakMode = .byClipping
    field.cell?.isScrollable = true
    field.cell?.usesSingleLineMode = true
    // Undo changes the text without telling the delegate, so the list would
    // go on matching what the field no longer shows.
    field.cell?.allowsUndo = false
    field.setContentHuggingPriority(.defaultLow, for: .horizontal)
    field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    field.delegate = context.coordinator
    return field
  }

  func updateNSView(_ field: QuickSwitcherNSTextField, context: Context) {
    context.coordinator.handlers = handlers
    // Unchanged on most redraws, a composition's each key among them.
    if field.font != font { field.font = font }
    if field.textColor != color { field.textColor = color }
    let editor = field.currentEditor() as? NSTextView
    if let editor, editor.insertionPointColor != color { editor.insertionPointColor = color }
    if !(editor?.hasMarkedText() ?? false), field.stringValue != text { field.stringValue = text }
  }

  func makeCoordinator() -> QuickSwitcherTextFieldDelegate {
    QuickSwitcherTextFieldDelegate(handlers: handlers)
  }
}
