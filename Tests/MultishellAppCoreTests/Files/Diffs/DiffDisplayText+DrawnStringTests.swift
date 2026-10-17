import Testing

@testable import MultishellAppCore

@Suite
struct DiffDisplayTextDrawnStringTests {
  @Test func aBreakInsideALineIsDrawnAsItsPictureUnitForUnit() {
    let text = DiffDisplayText([
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "a\rb\u{2029}c"),
      DiffLine(kind: .context, oldNumber: 2, newNumber: 2, text: "d"),
    ])

    #expect(text.drawnString == "a\u{240D}b\u{00B6}c\nd")
    #expect(text.drawnString.utf16.count == text.string.utf16.count)
  }
}
