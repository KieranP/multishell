import Testing

@testable import MultishellAppCore

@Suite
struct DiffLineTests {
  @Test func aLineIsNumberedByTheSideItIsShownOn() {
    let moved = DiffLine(kind: .context, oldNumber: 7, newNumber: 3, text: "x")
    let removed = DiffLine(kind: .removed, oldNumber: 4, newNumber: nil, text: "y")

    #expect(moved.number(on: .committed) == 7)
    #expect(moved.number(on: .onDisk) == 3)
    #expect(removed.number(on: .onDisk) == nil)
  }
}
