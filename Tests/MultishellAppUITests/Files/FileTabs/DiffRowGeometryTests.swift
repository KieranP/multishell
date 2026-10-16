import AppKit
import Testing

@testable import MultishellAppUI

@Suite
struct DiffRowGeometryTests {
  private let geometry = DiffRowGeometry(fontFamily: nil, fontSize: 12)

  @Test func aRectOutsideTheViewReachesNoRows() {
    #expect(geometry.rows(in: .null, count: 5).isEmpty)
  }

  @Test func aRectTallerThanAnyDocumentReachesEveryRow() {
    let tall = NSRect(x: 0, y: 0, width: 10, height: CGFloat.greatestFiniteMagnitude)

    #expect(geometry.rows(in: tall, count: 5) == 0..<5)
  }

  @Test func aFamilyThisMacHasIsUsedAndOneItLacksFallsBackToTheSystemMonospace() {
    let menlo = DiffRowGeometry(fontFamily: "Menlo", fontSize: 15)
    let missing = DiffRowGeometry(fontFamily: "No Such Family", fontSize: 15)

    #expect(menlo.font.familyName == "Menlo")
    #expect(menlo.font.pointSize == 15)
    #expect(missing.font == NSFont.monospacedSystemFont(ofSize: 15, weight: .regular))
  }
}
