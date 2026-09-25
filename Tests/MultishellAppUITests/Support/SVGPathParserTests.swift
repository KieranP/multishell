import Testing

@testable import MultishellAppUI

@Suite
struct SVGPathParserTests {
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
