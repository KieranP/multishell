import Testing

@testable import MultishellAppCore

struct TerminalTabGlyphTests {
  @Test func aPaneShowsTheActionMarkOnlyWhenAnActionStartedIt() {
    #expect(TerminalTabGlyph(paneIsAction: true) == .action)
    #expect(TerminalTabGlyph(paneIsAction: false) == .terminal)
  }
}
