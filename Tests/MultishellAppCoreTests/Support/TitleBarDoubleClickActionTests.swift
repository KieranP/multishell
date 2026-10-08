import Testing

@testable import MultishellAppCore

@Suite
struct TitleBarDoubleClickActionTests {
  @Test func theSystemSettingPicksMinimizeOrNothingAndAnythingElseZooms() {
    #expect(TitleBarDoubleClickAction(systemSetting: "Minimize") == .minimize)
    #expect(TitleBarDoubleClickAction(systemSetting: "None") == .ignore)
    #expect(TitleBarDoubleClickAction(systemSetting: "Maximize") == .zoom)
    #expect(TitleBarDoubleClickAction(systemSetting: nil) == .zoom)
  }
}
