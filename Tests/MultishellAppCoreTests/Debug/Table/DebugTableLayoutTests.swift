import Testing

@testable import MultishellAppCore

@Suite
struct DebugTableLayoutTests {
  @Test func aTableStacksItsRowsBelowTheWidthItsColumnsNeedAtTheFontSize() {
    #expect(DebugTableLayout.of(width: 520, columnsWidthInEms: 40, fontSize: 13) == .columns)
    #expect(DebugTableLayout.of(width: 519, columnsWidthInEms: 40, fontSize: 13) == .stacked)
    #expect(DebugTableLayout.of(width: 600, columnsWidthInEms: 40, fontSize: 16) == .stacked)
  }
}
