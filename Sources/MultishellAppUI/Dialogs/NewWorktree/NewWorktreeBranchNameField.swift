import AppKit
import SwiftUI

/// The new-branch name field. SwiftUI's `TextField` never shows a binding changed
/// while it is edited, and the draft fixes the name as it arrives; see worktrees.md.
struct NewWorktreeBranchNameField: NSViewRepresentable {
  @Binding var text: String
  let prompt: String

  func makeNSView(context: Context) -> NSTextField {
    let field = NSTextField(string: text)
    field.bezelStyle = .roundedBezel
    field.lineBreakMode = .byClipping
    field.cell?.isScrollable = true
    field.cell?.usesSingleLineMode = true
    field.setContentHuggingPriority(.defaultLow, for: .horizontal)
    field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    field.delegate = context.coordinator
    return field
  }

  func updateNSView(_ field: NSTextField, context: Context) {
    context.coordinator.text = $text
    field.placeholderString = prompt
    let isComposing = (field.currentEditor() as? NSTextView)?.hasMarkedText() ?? false
    if !isComposing, field.stringValue != text { field.stringValue = text }
  }

  func makeCoordinator() -> NewWorktreeBranchNameFieldDelegate {
    NewWorktreeBranchNameFieldDelegate(text: $text)
  }
}
