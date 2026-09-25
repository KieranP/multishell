import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppUI

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
}
