import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct ReviewCommentCardTests {
  private static func height(ofCardAtWidth width: CGFloat) -> CGFloat {
    let card = ReviewCommentCard(
      comment: ReviewComment(
        path: "Sources/App.swift",
        side: .onDisk,
        scope: .modified,
        lines: 120...145,
        quote: ["let a = 1"],
        text: "Guard it.",
      ),
      isSelected: false,
      theme: .multishellDark,
      metrics: UIMetrics(fontSize: Appearance.uiFontSizes.upperBound, fontFamily: nil),
      edit: {},
      remove: {},
    )
    return OffscreenHost.read(
      card,
      atWidth: width,
      windowSize: CGSize(width: width, height: 400),
    ) { $0.fittingSize.height }
  }

  @Test func inTheLargestFontANarrowCardKeepsItsHeaderOnOneLine() {
    #expect(Self.height(ofCardAtWidth: 240) <= Self.height(ofCardAtWidth: 600))
  }
}
