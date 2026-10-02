import Testing

@testable import MultishellAppCore

@Suite
struct ProjectDropTargetTests {
  private let target = ProjectDropTarget(projectID: "/repos/demo", placement: .below)

  @Test func theLineIsDrawnOnTheBlockUnderThePointerOnTheSideItIsOn() {
    #expect(target.insertionPlacement(on: "/repos/demo", isDragging: true) == .below)
  }

  @Test func anotherBlockDrawsNoLine() {
    #expect(target.insertionPlacement(on: "/repos/other", isDragging: true) == nil)
  }

  @Test func aTargetLeftOverFromAnEndedDragDrawsNoLine() {
    #expect(target.insertionPlacement(on: "/repos/demo", isDragging: false) == nil)
  }
}
