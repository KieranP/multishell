import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct SidebarFilterFieldTests {
  @Test func itsTextIsSelectedInThePanelsSelectionWithACaretInItsText() throws {
    let theme = try FocusedFieldEditor.theme(.projectsPanel, caretKey: .text)
    let field = SidebarFilterField(
      text: .constant("main"),
      isFiltering: true,
      theme: theme,
      metrics: UIMetrics(fontSize: 13, fontFamily: nil),
      focusRequests: 0,
      close: {},
    )

    let (editor, window) = try FocusedFieldEditor.editor(of: field)
    defer { withExtendedLifetime(window) {} }

    FocusedFieldEditor.expectThemeColours(in: editor)
  }

  @Test func askingAgainTakesTheKeyboardBackFromAViewBesideIt() throws {
    let theme = try FocusedFieldEditor.theme(.projectsPanel, caretKey: .text)
    func field(asked requests: Int) -> SidebarFilterField {
      SidebarFilterField(
        text: .constant(""),
        isFiltering: false,
        theme: theme,
        metrics: UIMetrics(fontSize: 13, fontFamily: nil),
        focusRequests: requests,
        close: {},
      )
    }
    let host = NSHostingView(rootView: field(asked: 0))
    host.frame = NSRect(x: 0, y: 0, width: 320, height: 60)
    let pane = KeyboardTakingView(frame: NSRect(x: 0, y: 60, width: 320, height: 60))
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 120))
    container.addSubview(host)
    container.addSubview(pane)
    let window = OffscreenWindow.holding(container, deferred: false)
    defer { withExtendedLifetime(window) {} }
    OffscreenWindow.settle(within: 0.2)
    let editable = host.descendants(of: NSTextField.self).filter(\.isEditable)
    let textField = try #require(editable.first)
    #expect(textField.currentEditor() != nil)

    #expect(window.makeFirstResponder(pane))
    OffscreenWindow.settle(within: 0.2)
    #expect(textField.currentEditor() == nil)

    host.rootView = field(asked: 1)
    OffscreenWindow.settle(until: { textField.currentEditor() != nil }, within: 1)

    #expect(textField.currentEditor() != nil)
  }
}
