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
      close: {},
    )

    let (editor, window) = try FocusedFieldEditor.editor(of: field)
    defer { withExtendedLifetime(window) {} }

    FocusedFieldEditor.expectThemeColours(in: editor)
  }
}
