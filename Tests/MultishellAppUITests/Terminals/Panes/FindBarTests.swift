import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct FindBarTests {
  @Test func itsTextIsSelectedInTheBarsSelectionWithACaretInItsFieldText() throws {
    let harness = ModelHarness()
    let theme = try FocusedFieldEditor.theme(.findBar, caretKey: .fieldText)
    let bar = FindBar(model: harness.model, targetID: UUID(), theme: theme)

    let (editor, window) = try FocusedFieldEditor.editor(
      of: bar,
      size: CGSize(width: 400, height: 80),
    )
    defer { withExtendedLifetime(window) {} }

    FocusedFieldEditor.expectThemeColours(in: editor)
  }
}
