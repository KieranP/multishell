import Testing

@testable import MultishellAppCore

@Suite
struct TabHoverWashTests {
  @Test func aTabBehindTheShownOneIsWashedOnlyUnderThePointer() {
    #expect(TabHoverWash.isWashed(onShownTab: false, isHovered: true))
    #expect(!TabHoverWash.isWashed(onShownTab: false, isHovered: false))
  }

  @Test func theShownTabKeepsItsFillUnderThePointer() {
    #expect(!TabHoverWash.isWashed(onShownTab: true, isHovered: true))
  }
}
