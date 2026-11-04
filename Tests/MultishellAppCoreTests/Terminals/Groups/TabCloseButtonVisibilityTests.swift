import Testing

@testable import MultishellAppCore

@Suite
struct TabCloseButtonVisibilityTests {
  @Test func everyGroupsShownTabDrawsItsCloseButtonUnhovered() {
    #expect(TabCloseButtonVisibility.isVisible(onShownTab: true, isHovered: false))
  }

  @Test func aTabBehindTheShownOneDrawsItOnlyUnderThePointer() {
    #expect(!TabCloseButtonVisibility.isVisible(onShownTab: false, isHovered: false))
    #expect(TabCloseButtonVisibility.isVisible(onShownTab: false, isHovered: true))
  }
}
