import MultishellCore
import SwiftUI
import Testing

@testable import Multishell

@Suite
struct AgentMarkResourceTests {
  /// A mark that fails to parse draws nothing, and nothing on screen is what
  /// nobody notices until it ships.
  @Test func everyDrawnMarkLoadsFromItsFileAndFillsItsSquare() {
    for mark in AgentMark.drawn {
      guard let path = AgentMarkShape.unitPath(of: mark) else {
        Issue.record("\(mark) has no path; check Resources/Marks")
        continue
      }
      let bounds = path.boundingRect
      #expect(!bounds.isEmpty, "\(mark) is an empty path")
      #expect(
        bounds.minX >= -0.01 && bounds.minY >= -0.01 && bounds.maxX <= 16.01
          && bounds.maxY <= 16.01,
        "\(mark) runs outside its 16-point square: \(bounds)")
      #expect(
        bounds.width >= 8 && bounds.height >= 8,
        "\(mark) is too small in its square to read: \(bounds)")
    }
  }

  @Test func aMonogramHasNoFileAndDrawsNothing() {
    #expect(AgentMarkShape.resourceName(of: .monogram("Ai")) == nil)
    #expect(AgentMarkShape.unitPath(of: .monogram("Ai")) == nil)
    #expect(
      AgentMarkShape(mark: .monogram("Ai")).path(in: CGRect(x: 0, y: 0, width: 16, height: 16))
        .isEmpty)
  }

  @Test func theShapeScalesAndCentresWhatTheFileHolds() {
    let path = AgentMarkShape(mark: .gemini).path(in: CGRect(x: 4, y: 10, width: 32, height: 32))
    let bounds = path.boundingRect
    #expect(abs(bounds.midX - 20) < 0.01 && abs(bounds.midY - 26) < 0.01, "centred: \(bounds)")
    #expect(bounds.width > 16, "scaled up with the rect: \(bounds)")
  }

  @Test func theParserTakesWhatTheGeneratorWritesAndRefusesTheRest() {
    #expect(SVGPathParser.path(fromData: "M1 2L3 4Z") != nil)
    #expect(SVGPathParser.path(fromData: "M1 2C3 4 5 6 7 8Q9 10 11 12Z") != nil)
    #expect(SVGPathParser.path(fromData: "M1-2L-3-4Z") != nil, "a minus separates two numbers")
    #expect(SVGPathParser.path(fromData: "M1 2L3") == nil, "a command short of its numbers")
    #expect(SVGPathParser.path(fromData: "M1 2A5 5 0 0 1 3 4") == nil, "no arcs are written")
    #expect(SVGPathParser.path(fromData: "m1 2l3 4") == nil, "nor relative commands")
    #expect(SVGPathParser.path(fromData: "") == nil)
    #expect(SVGPathParser.path(fromSVG: "<svg><path/></svg>") == nil)
  }

  /// `id="…"` holds a `d="` of its own, and a mark whose data came out of an
  /// id would draw nothing at all.
  @Test func theAttributeIsTheWholeOneAndNotTheEndOfAnother() {
    let svg = #"<svg viewBox="0 0 16 16"><path id="round" d="M1 2L3 4L1 4Z"/></svg>"#
    #expect(SVGPathParser.path(fromSVG: svg) != nil)
    #expect(SVGPathParser.path(fromSVG: #"<svg><path id="round"/></svg>"#) == nil)
  }

  /// `M x y x2 y2` is a move and then a line, which is what every generator
  /// writes a polygon as; reading the second pair as another move drops it.
  @Test func aMoveWithMorePairsDrawsLinesRatherThanMoreMoves() throws {
    let repeated = try #require(SVGPathParser.path(fromData: "M0 0 4 0 4 4 0 4Z"))
    let spelled = try #require(SVGPathParser.path(fromData: "M0 0L4 0L4 4L0 4Z"))
    #expect(repeated == spelled)
  }
}
