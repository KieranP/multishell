import Foundation
import Testing

@testable import MultishellCore

struct PaneNodeDecodingTests {
  @Test func aSplitWithoutWeightsGetsEqualShares() throws {
    let a = UUID()
    let b = UUID()
    let node = try decodeJSON(
      PaneNode.self,
      #"""
      { "split": { "axis": "horizontal", "children": [
        { "terminal": { "_0": "\#(a.uuidString)" } },
        { "terminal": { "_0": "\#(b.uuidString)" } } ] } }
      """#,
    )
    #expect(node == .split(axis: .horizontal, children: [.terminal(a), .terminal(b)]))
  }

  @Test func weightsThatDoNotMatchTheChildrenAreReplacedNotTrusted() throws {
    // The pane view sizes children by weight index; a short list leaves one unsized.
    let a = UUID()
    let b = UUID()
    for weights in ["[1]", "[1, 2, 3]", "[1, -1]", "[0, 1]"] {
      let node = try decodeJSON(
        PaneNode.self,
        #"""
        { "split": { "axis": "vertical", "weights": \#(weights), "children": [
          { "terminal": { "_0": "\#(a.uuidString)" } },
          { "terminal": { "_0": "\#(b.uuidString)" } } ] } }
        """#,
      )
      #expect(
        node == .split(axis: .vertical, children: [.terminal(a), .terminal(b)]),
        "\(weights)",
      )
    }
  }

  @Test func paneTreesRoundTripThroughTheSynthesizedEncoder() throws {
    let tree = PaneNode.split(
      axis: .vertical,
      children: [
        .terminal(UUID()),
        .split(
          axis: .horizontal,
          children: [.terminal(UUID()), .terminal(UUID())],
          weights: [3, 1],
        ),
      ],
      weights: [0.25, 0.75],
    )
    let json = try JSONEncoder().encode(tree)
    #expect(try JSONDecoder().decode(PaneNode.self, from: json) == tree)
  }

  @Test func anUnknownSplitAxisFallsBackToHorizontal() throws {
    let a = UUID()
    let b = UUID()
    let node = try decodeJSON(
      PaneNode.self,
      #"""
      { "split": { "axis": "diagonal", "children": [
        { "terminal": { "_0": "\#(a.uuidString)" } },
        { "terminal": { "_0": "\#(b.uuidString)" } } ] } }
      """#,
    )
    #expect(node == .split(axis: .horizontal, children: [.terminal(a), .terminal(b)]))
  }
}
