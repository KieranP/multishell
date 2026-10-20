import AppKit
import MultishellAppCore
import Observation
import SwiftUI
import Testing

@testable import MultishellAppUI

/// The new-worktree sheet's branch rows, a task field and a default button, in
/// a window. Each action goes through the field editor and lets the view settle.
@MainActor
final class BranchNameFieldHarness {
  @Observable
  final class SheetState {
    var draft = NewWorktreeDraft(projectID: "/repos/a")
    var defaultButtonPresses = 0
  }

  private struct Sheet: View {
    @Bindable var state: SheetState
    @State private var task = ""

    var body: some View {
      Form {
        NewWorktreeBranchFields(draft: $state.draft, prefix: "", checkedOut: [])
        TextField("Task", text: $task)
        Button("Create") { state.defaultButtonPresses += 1 }.keyboardShortcut(.defaultAction)
      }
    }
  }

  private let state = SheetState()
  private let host: NSHostingView<Sheet>
  private let window: NSWindow

  var draft: NewWorktreeDraft { state.draft }
  var defaultButtonPresses: Int { state.defaultButtonPresses }

  /// The text field the window is editing, whichever it is.
  var focusedTextField: NSTextField? {
    (window.firstResponder as? NSTextView)?.delegate as? NSTextField
  }

  init() {
    host = NSHostingView(rootView: Sheet(state: state))
    window = OffscreenWindow.holding(
      host,
      rect: NSRect(x: 0, y: 0, width: 400, height: 300),
      deferred: false,
    )
    settle()
  }

  func field() throws -> NSTextField {
    try #require(host.descendants(of: NSTextField.self).first { $0.isEditable })
  }

  /// Focusing a field selects all of it, which the next insert would replace,
  /// so a field already being edited is left as it is.
  func editor() throws -> NSTextView {
    let field = try field()
    if field.currentEditor() == nil { #expect(window.makeFirstResponder(field)) }
    return try #require(field.currentEditor() as? NSTextView)
  }

  func undoManager() throws -> UndoManager {
    try #require(try editor().undoManager)
  }

  func type(_ text: String) throws {
    let editor = try editor()
    editor.insertText(text, replacementRange: editor.selectedRange())
    settle()
  }

  func paste(_ text: String) throws {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("branch-field-\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    let editor = try editor()
    #expect(editor.readSelection(from: pasteboard))
    settle()
  }

  func placeCaret(at location: Int) throws {
    try editor().setSelectedRange(NSRange(location: location, length: 0))
  }

  func undo() throws {
    try undoManager().undo()
    settle()
  }

  func redo() throws {
    try undoManager().redo()
    settle()
  }

  func pressTab() throws {
    try editor().insertTab(nil)
    settle()
  }

  /// Whether a key equivalent took the press.
  func pressReturn() throws -> Bool {
    let handled = window.performKeyEquivalent(with: try keyDown("\r", keyCode: 36))
    settle()
    return handled
  }

  func refocusField() throws {
    #expect(window.makeFirstResponder(try field()))
    settle()
  }

  /// A change made to the draft by something other than the field.
  func changeDraft(_ change: (inout NewWorktreeDraft) -> Void) {
    change(&state.draft)
    settle()
  }

  private func settle() {
    OffscreenWindow.settle(within: 0.1)
  }
}
