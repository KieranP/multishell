import Foundation
import Testing

@testable import MultishellCore

extension PaneNodeTests {
  @Test func aSplitWithoutWeightsGetsEqualShares() throws {
    let a = UUID()
    let b = UUID()
    let node = try decodeJSON(
      PaneNode.self,
      #"""
      { "split": { "axis": "horizontal", "children": [
        { "terminal": { "_0": "\#(a.uuidString)" } },
        { "terminal": { "_0": "\#(b.uuidString)" } } ] } }
      """#)
    #expect(node == .split(axis: .horizontal, children: [.terminal(a), .terminal(b)]))
  }

  @Test func weightsThatDoNotMatchTheChildrenAreReplacedNotTrusted() throws {
    // `removing` zips children with weights; a short list would drop a pane.
    let a = UUID()
    let b = UUID()
    for weights in ["[1]", "[1, 2, 3]", "[1, -1]", "[0, 1]"] {
      let node = try decodeJSON(
        PaneNode.self,
        #"""
        { "split": { "axis": "vertical", "weights": \#(weights), "children": [
          { "terminal": { "_0": "\#(a.uuidString)" } },
          { "terminal": { "_0": "\#(b.uuidString)" } } ] } }
        """#)
      #expect(
        node == .split(axis: .vertical, children: [.terminal(a), .terminal(b)]), "\(weights)")
    }
  }

  @Test func paneTreesRoundTripThroughTheSynthesizedEncoder() throws {
    let tree = PaneNode.split(
      axis: .vertical,
      children: [
        .terminal(UUID()),
        .split(
          axis: .horizontal, children: [.terminal(UUID()), .terminal(UUID())], weights: [3, 1]),
      ],
      weights: [0.25, 0.75])
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
      """#)
    #expect(node == .split(axis: .horizontal, children: [.terminal(a), .terminal(b)]))
  }
}
