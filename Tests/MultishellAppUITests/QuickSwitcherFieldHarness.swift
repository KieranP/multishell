import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@MainActor
final class QuickSwitcherFieldHarness {
  let models = ModelHarness()
  let worktree: Worktree
  private let host: NSHostingView<QuickSwitcherLayer>
  private let otherField = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 20))
  private let window: NSWindow

  var model: MultishellAppUI.AppModel { models.model }

  init(scope: QuickSwitcherScope = .commands, text: String = "") {
    worktree = models.addPrimaryWorktree()
    models.model.quickSwitcher = QuickSwitcherState(
      scope: scope,
      text: text,
      commands: [
        PlatformMenuItem(path: ["Terminal", "Split Right"], isEnabled: true, isChecked: false),
        PlatformMenuItem(path: ["Terminal", "Split Down"], isEnabled: true, isChecked: false),
      ],
    )
    let frame = NSRect(x: 0, y: 0, width: 800, height: 600)
    host = NSHostingView(rootView: QuickSwitcherLayer(model: models.model))
    host.frame = frame
    let content = NSView(frame: frame)
    content.addSubview(otherField)
    content.addSubview(host)
    window = OffscreenWindow.holding(content, rect: frame, deferred: false)
    settle()
  }

  func field() throws -> NSTextField {
    try #require(editableFields().first)
  }

  private func editableFields() -> [NSTextField] {
    host.descendants(of: NSTextField.self).filter(\.isEditable)
  }

  func editor() throws -> NSTextView {
    try #require(try field().currentEditor() as? NSTextView)
  }

  func typeWithoutARedrawBetween(_ keys: [String]) throws {
    let editor = try editor()
    for key in keys { editor.insertText(key, replacementRange: editor.selectedRange()) }
    settle()
  }

  func type(_ text: String) throws {
    let editor = try editor()
    editor.insertText(text, replacementRange: editor.selectedRange())
    settle()
  }

  func press(_ command: Selector) throws {
    try editor().doCommand(by: command)
    settle()
  }

  func typeInTheOtherFieldThenComeBack(_ text: String) throws {
    giveTheKeyboardToAnotherField()
    let editor = try #require(otherField.currentEditor() as? NSTextView)
    editor.insertText(text, replacementRange: editor.selectedRange())
    models.model.quickSwitcher = QuickSwitcherState(scope: .commands, commands: [])
    OffscreenWindow.settle(until: { self.editableFields().count == 1 }, within: 2)
  }

  func setTextInTheModel(_ text: String) {
    model.setQuickSwitcherText(text)
    settle()
  }

  func undo() throws {
    (window.firstResponder as? NSTextView)?.undoManager?.undo()
    settle()
  }

  func giveTheKeyboardToAnotherField() {
    #expect(window.makeFirstResponder(otherField))
    settle()
  }

  private func settle() {
    OffscreenWindow.settle(within: 0.1)
  }
}
