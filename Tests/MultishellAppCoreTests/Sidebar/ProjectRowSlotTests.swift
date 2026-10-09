import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct ProjectRowSlotTests {
  @Test func aRunningFetchTakesTheSlotOverTheCollapsedState() {
    #expect(ProjectRowSlot(isFetching: true, state: .attention) == .fetching)
  }

  @Test func theCollapsedStateTakesTheSlotOverTheIcon() {
    #expect(ProjectRowSlot(isFetching: false, state: .attention) == .state(.attention))
  }

  @Test func theIconShowsWithNoFetchAndNoState() {
    #expect(ProjectRowSlot(isFetching: false, state: nil) == .icon)
  }
}
