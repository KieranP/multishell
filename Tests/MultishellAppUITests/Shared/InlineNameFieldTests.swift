import AppKit
import SwiftUI
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct InlineNameFieldTests {
  @Test(arguments: [InterfaceSection.projectsPanel, .tabBar, .terminalTab])
  func itsTextIsSelectedInItsAreasSelectionWithACaretInItsText(
    section: InterfaceSection
  ) throws {
    let theme = try FocusedFieldEditor.theme(section, caretKey: .text)
    let field = InlineNameField(
      initial: "name",
      prompt: "",
      font: .body,
      palette: AreaPalette(theme, section),
      commit: { _ in },
      cancel: {},
    )

    let (editor, window) = try FocusedFieldEditor.editor(of: field)
    defer { withExtendedLifetime(window) {} }

    FocusedFieldEditor.expectThemeColours(in: editor)
  }
}
