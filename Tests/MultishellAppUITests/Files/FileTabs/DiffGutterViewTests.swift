import AppKit
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DiffGutterViewTests {
  private static func gutter(_ line: DiffLine, numbering: DiffSide) -> DiffGutterView {
    let gutter = DiffGutterView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    gutter.displayText = DiffDisplayText([line], marksStaging: true)
    gutter.numbering = numbering
    return gutter
  }

  @Test func aSplitsCommittedSideIsAsWideAsHeadsNumbers() {
    let shifted = DiffLine(kind: .context, oldNumber: 10_000, newNumber: 9, text: "x")
    let aligned = DiffLine(kind: .context, oldNumber: 10_000, newNumber: 10_000, text: "x")

    #expect(
      Self.gutter(shifted, numbering: .committed).preferredWidth
        == Self.gutter(aligned, numbering: .committed).preferredWidth
    )
  }
}
