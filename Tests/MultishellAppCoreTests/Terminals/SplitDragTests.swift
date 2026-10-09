import Testing

@testable import MultishellAppCore

@Suite
struct SplitDragTests {
  private func move(_ drag: inout SplitDrag, by translation: Double, over weights: [Double]) {
    drag.move(
      dividerAfter: 0,
      by: translation,
      over: weights,
      available: 600,
      minimumPane: 80,
    )
  }

  @Test func anUntouchedDragShowsTheModelsWeightsAndHandsNothingBack() {
    var drag = SplitDrag()
    #expect(drag.shown(over: [1, 1, 1]) == [1, 1, 1])
    #expect(drag.end(over: [1, 1, 1]) == nil)
  }

  @Test func eachMoveIsMeasuredFromTheWeightsTheDragBeganWith() {
    var drag = SplitDrag()
    move(&drag, by: 100, over: [1, 1, 1])
    #expect(drag.shown(over: [1, 1, 1]) == [1.5, 0.5, 1])
    move(&drag, by: 50, over: [1, 1, 1])
    #expect(drag.shown(over: [1, 1, 1]) == [1.25, 0.75, 1], "50 from the start, not from 1.5")
  }

  @Test func theEndHandsBackWhatTheDragMovedOnceAndStartsOver() {
    var drag = SplitDrag()
    move(&drag, by: 100, over: [1, 1, 1])
    #expect(drag.end(over: [1, 1, 1]) == [1.5, 0.5, 1])
    #expect(drag.shown(over: [1, 1, 1]) == [1, 1, 1])
    #expect(drag.end(over: [1, 1, 1]) == nil)
  }

  @Test func aDragThatEndsWhereItBeganHandsNothingBack() {
    var drag = SplitDrag()
    move(&drag, by: 100, over: [1, 1, 1])
    move(&drag, by: 0, over: [1, 1, 1])
    #expect(drag.end(over: [1, 1, 1]) == nil)
  }

  @Test func newWeightsFromTheModelReplaceWhatTheDragShowedButNotWhereItBegan() {
    var drag = SplitDrag()
    move(&drag, by: 100, over: [1, 1, 1])
    drag.forgetShownWeights()
    #expect(drag.shown(over: [2, 1, 1]) == [2, 1, 1])
    move(&drag, by: 50, over: [2, 1, 1])
    #expect(drag.shown(over: [2, 1, 1]) == [1.25, 0.75, 1])
  }
}
