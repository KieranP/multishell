import Testing

@testable import MultishellAppCore

@Suite
struct ArrayNestedWorkersTests {
  private func drawnOrder(_ workers: [Worker]) -> [String] {
    workers.nested.map { String(repeating: "  ", count: $0.depth) + $0.id }
  }

  @Test func eachWorkerFollowsItsParentAndSiblingsKeepTheirStartOrder() {
    let out = [
      Worker(id: "review", type: nil),
      Worker(id: "package", type: nil),
      Worker(id: "angle-a", type: nil, parentID: "review"),
      Worker(id: "deep", type: nil, parentID: "angle-a"),
      Worker(id: "angle-b", type: nil, parentID: "review"),
    ]
    #expect(drawnOrder(out) == ["review", "  angle-a", "    deep", "  angle-b", "package"])
  }

  @Test func aWorkerWhoseParentIsNotOutIsDrawnAtTheTop() {
    let out = [Worker(id: "a", type: nil), Worker(id: "b", type: nil, parentID: "gone")]
    #expect(drawnOrder(out) == ["a", "b"])
  }

  @Test func workersNamingEachOtherAreAllDrawnOnce() {
    let out = [
      Worker(id: "a", type: nil, parentID: "b"),
      Worker(id: "b", type: nil, parentID: "a"),
      Worker(id: "c", type: nil, parentID: "c"),
    ]
    #expect(drawnOrder(out) == ["a", "  b", "c"])
  }
}
