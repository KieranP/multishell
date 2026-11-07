import AppKit
import SwiftUI
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct ViewFieldEditorColorsTests {
  enum Field: Sendable { case first, second }

  private struct TwoFields: View {
    let focus: Field
    @FocusState private var focused: Field?
    @State private var first = "first"
    @State private var second = "second"

    var body: some View {
      VStack {
        TextField("", text: $first)
          .focused($focused, equals: .first)
          .fieldEditorColors(selection: .red, caret: .red, isFocused: focused == .first)
        TextField("", text: $second)
          .focused($focused, equals: .second)
          .fieldEditorColors(selection: .blue, caret: .blue, isFocused: focused == .second)
      }
      .onAppear { focused = focus }
      .onChange(of: focus) { focused = focus }
    }
  }

  private static func colour(of field: Field) -> NSColor {
    NSColor(field == .first ? Color.red : Color.blue)
  }

  private static func expectEditor(in window: NSWindow, wearing field: Field) throws {
    let editor = try #require(window.firstResponder as? NSTextView)
    let selection = editor.selectedTextAttributes[.backgroundColor] as? NSColor
    #expect(FocusedFieldEditor.isSame(selection, as: colour(of: field)))
    #expect(FocusedFieldEditor.isSame(editor.insertionPointColor, as: colour(of: field)))
  }

  @Test(arguments: [(Field.first, Field.second), (.second, .first)])
  func focusMovingStraightToAnotherFieldLeavesTheEditorInThatFieldsColours(
    from: Field,
    to: Field,
  ) throws {
    let host = NSHostingView(rootView: TwoFields(focus: from))
    host.frame = NSRect(x: 0, y: 0, width: 300, height: 100)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    OffscreenWindow.settle(within: 0.2)
    try Self.expectEditor(in: window, wearing: from)

    host.rootView = TwoFields(focus: to)
    OffscreenWindow.settle(within: 0.2)

    try Self.expectEditor(in: window, wearing: to)
  }
}
