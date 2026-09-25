import Testing

@testable import MultishellAppCore

/// Below a floor the icon, the title and the close button run into each other and into
/// the next tab, so a full strip scrolls instead.
@Suite
struct TabStripLayoutTests {
  private func layout(_ available: Double, _ count: Int) -> TabStripLayout {
    TabStripLayout(available: available, count: count, minimum: 100, maximum: 190)
  }

  @Test func tabsTakeTheirFullWidthWhereThereIsRoom() {
    #expect(layout(800, 2).tabWidth == 190)
    #expect(layout(800, 2).scrolls == false)
  }

  @Test func tabsShrinkTogetherAsMoreArrive() {
    #expect(layout(600, 4).tabWidth == 150)
    #expect(layout(600, 5).tabWidth == 120)
    #expect(layout(600, 4).scrolls == false)
  }

  @Test func pastTheFloorTheStripScrollsInsteadOfSqueezing() {
    let tight = layout(600, 7)
    #expect(tight.tabWidth == 100, "the floor, not 85")
    #expect(tight.scrolls)
  }

  /// A strip divides exactly between its tabs, and asking whether the total
  /// overruns the room would be a floating-point coin toss.
  @Test func aStripThatDividesExactlyDoesNotScroll() {
    #expect(layout(300, 3).tabWidth == 100)
    #expect(layout(300, 3).scrolls == false)
  }

  @Test func aStripWithNothingInItOrNotYetLaidOutIsNotScrolling() {
    #expect(layout(800, 0).scrolls == false)
    #expect(layout(.nan, 3).scrolls == false)
    #expect(layout(.nan, 3).tabWidth == 190, "the cap, until it has been laid out")
  }

  /// A narrow window can leave a group less room than the New Tab button. Read as not
  /// scrolling, that spills a full-width tab over the group beside it.
  @Test func aStripWithNoRoomAtAllStillScrolls() {
    #expect(layout(0, 3).scrolls)
    #expect(layout(-40, 3).scrolls)
    #expect(layout(-40, 3).tabWidth == 100, "the floor, and the row clips")
  }

  @Test func aFloorAboveTheCapWins() {
    let odd = TabStripLayout(available: 600, count: 2, minimum: 200, maximum: 100)
    #expect(odd.tabWidth == 200)
  }
}
