import Testing

@testable import MultishellAppCore

/// How wide a column is drawn, and when the board gives up sharing and
/// scrolls instead.
@Suite
struct AgentBoardLayoutTests {
  private let floor = 208.0

  @Test func columnsShareTheRoomWhileThereIsEnoughOfIt() {
    let layout = AgentBoardLayout(available: 1000, count: 4, minimum: floor)
    #expect(layout.columnWidth == 250)
    #expect(!layout.scrolls)
  }

  /// No cap, unlike the tab strip: a card's message line uses whatever width
  /// it is given, where a tab holds a fixed icon, title and close button.
  @Test func aWideBoardGivesTheWholeWidthAway() {
    #expect(AgentBoardLayout(available: 2000, count: 4, minimum: floor).columnWidth == 500)
  }

  @Test func pastTheFloorItScrollsRatherThanSqueezing() {
    let layout = AgentBoardLayout(available: 600, count: 4, minimum: floor)
    #expect(layout.columnWidth == floor)
    #expect(layout.scrolls)
  }

  @Test func exactlyTheFloorDoesNotScroll() {
    let layout = AgentBoardLayout(available: floor * 4, count: 4, minimum: floor)
    #expect(layout.columnWidth == floor)
    #expect(!layout.scrolls, "asked of the share, so a board that divides exactly is not a toss-up")
  }

  /// A window dragged narrow enough reaches this, and reading it as "no
  /// scrolling" would draw a full column in a space a few points wide.
  @Test func noRoomAtAllScrollsAndClips() {
    let layout = AgentBoardLayout(available: 0, count: 4, minimum: floor)
    #expect(layout.columnWidth == floor)
    #expect(layout.scrolls)
    #expect(AgentBoardLayout(available: -40, count: 4, minimum: floor).scrolls)
  }

  @Test func aBoardNotYetLaidOutTakesTheFloorAndDoesNotScroll() {
    let layout = AgentBoardLayout(available: .infinity, count: 4, minimum: floor)
    #expect(layout.columnWidth == floor)
    #expect(!layout.scrolls)
    #expect(AgentBoardLayout(available: 900, count: 0, minimum: floor).columnWidth == floor)
  }

  @Test func theGapsAndThePaddingComeOffBeforeAColumnIsMeasured() {
    #expect(AgentBoardLayout.available(width: 1000, count: 4, gap: 10, padding: 12) == 946)
    #expect(AgentBoardLayout.available(width: 1000, count: 1, gap: 10, padding: 12) == 976)
    #expect(AgentBoardLayout.available(width: 1000, count: 0, gap: 10, padding: 12) == 0)
  }
}
