import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// Deterministic, so a failing shape can be replayed from its seed.
private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64
  init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
  mutating func next() -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}

@Suite
struct IconGridWalkTests {
  private let groups = [
    ProjectIcon.Group(name: "One", glyphs: ["a", "b", "c", "d", "e"]),
    ProjectIcon.Group(name: "Two", glyphs: ["f", "g", "h"]),
  ]

  private var rows: [[String]] { IconGridWalk.rows(of: groups, columns: 4) }

  @Test func aGroupStartsANewRowHoweverShortTheLastOneIs() {
    #expect(rows == [["a", "b", "c", "d"], ["e"], ["f", "g", "h"]])
    #expect(IconGridWalk.rows(of: groups, columns: 0).isEmpty)
  }

  @Test func leftAndRightRunOnThroughTheRows() {
    #expect(IconGridWalk.destination(from: "a", step: .right, in: rows) == "b")
    #expect(IconGridWalk.destination(from: "d", step: .right, in: rows) == "e")
    #expect(IconGridWalk.destination(from: "e", step: .right, in: rows) == "f")
    #expect(IconGridWalk.destination(from: "f", step: .left, in: rows) == "e")
    #expect(IconGridWalk.destination(from: "a", step: .left, in: rows) == "a", "nowhere before it")
    #expect(IconGridWalk.destination(from: "h", step: .right, in: rows) == "h", "nowhere after it")
  }

  @Test func upAndDownHoldTheColumnAndTakeTheLastOfAShorterRow() {
    #expect(IconGridWalk.destination(from: "a", step: .down, in: rows) == "e")
    #expect(
      IconGridWalk.destination(from: "c", step: .down, in: rows) == "e",
      "the row below has one cell, so the column clamps rather than skipping the row")
    #expect(IconGridWalk.destination(from: "e", step: .down, in: rows) == "f")
    #expect(IconGridWalk.destination(from: "h", step: .up, in: rows) == "e")
    #expect(IconGridWalk.destination(from: "a", step: .up, in: rows) == "a")
    #expect(IconGridWalk.destination(from: "g", step: .down, in: rows) == "g")
  }

  @Test func theFirstKeyLandsOnTheFirstSymbolWhenNothingIsHighlighted() {
    #expect(IconGridWalk.destination(from: nil, step: .down, in: rows) == "a")
    #expect(
      IconGridWalk.destination(from: "gone", step: .right, in: rows) == "a",
      "a search dropped what was highlighted")
    #expect(IconGridWalk.destination(from: "a", step: .up, in: []) == nil)
  }

  @Test func anEmptyRowIsNoLandingPlaceAndIsSteppedOver() {
    #expect(IconGridWalk.destination(from: "a", step: .down, in: [["a"], []]) == "a")
    #expect(IconGridWalk.destination(from: "a", step: .down, in: [["a"], [], ["b"]]) == "b")
    #expect(IconGridWalk.destination(from: "b", step: .left, in: [[], ["b"]]) == "b")
    #expect(IconGridWalk.destination(from: "a", step: .up, in: [[]]) == nil)
  }

  /// Any shape of groups, any key: the walk stays inside the palette, the
  /// ends hold, and stepping one way and back is where it started.
  @Test(arguments: [1, 2, 5, 8, 13, 21, 34, 55] as [UInt64])
  func anyShapeOfGroupsWalksWithoutLeavingThePalette(seed: UInt64) {
    var rng = SeededGenerator(seed: seed)
    let columns = Int.random(in: 1...6, using: &rng)
    var next = 0
    let groups = (0..<Int.random(in: 1...5, using: &rng)).map { index in
      ProjectIcon.Group(
        name: "g\(index)",
        glyphs: (0..<Int.random(in: 1...14, using: &rng)).map { _ in
          defer { next += 1 }
          return "s\(next)"
        })
    }
    let rows = IconGridWalk.rows(of: groups, columns: columns)
    let all = Set(rows.flatMap { $0 })
    #expect(all.count == next, "every symbol laid out exactly once")
    #expect(rows.allSatisfy { $0.count <= columns && !$0.isEmpty })

    let steps: [IconGridWalk.Step] = [.left, .right, .up, .down]
    var at = rows[0][0]
    for step in 0..<200 {
      let key = steps[Int.random(in: 0..<4, using: &rng)]
      let to = IconGridWalk.destination(from: at, step: key, in: rows)
      let landed = try! #require(to, "seed \(seed) step \(step)")
      #expect(all.contains(landed), "seed \(seed) step \(step): walked off the palette")
      if key == .right, landed != at {
        #expect(
          IconGridWalk.destination(from: landed, step: .left, in: rows) == at,
          "seed \(seed) step \(step): right then left is not where it started")
      }
      at = landed
    }
    #expect(IconGridWalk.destination(from: rows[0][0], step: .left, in: rows) == rows[0][0])
    #expect(IconGridWalk.destination(from: rows[0][0], step: .up, in: rows) == rows[0][0])
    let last = rows[rows.count - 1].last!
    #expect(IconGridWalk.destination(from: last, step: .right, in: rows) == last)
    #expect(IconGridWalk.destination(from: last, step: .down, in: rows) == last)
  }

  @Test func theRealPaletteWalksFromTheFirstSymbolToTheLast() {
    let rows = IconGridWalk.rows(of: ProjectIcon.symbolGroups, columns: 10)
    #expect(rows.flatMap { $0 } == ProjectIcon.symbols, "every symbol, in order, exactly once")
    var at: String? = ProjectIcon.symbols.first
    for _ in ProjectIcon.symbols {
      at = IconGridWalk.destination(from: at, step: .right, in: rows)
    }
    #expect(at == ProjectIcon.symbols.last)
  }
}
