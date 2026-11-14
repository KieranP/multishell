import AppKit
import SwiftUI
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct ThemedButtonStyleTests {
  private static func fittedHeight(minHeight: Double?) -> Double {
    let theme = Theme.multishellDark
    let host = NSHostingView(
      rootView: Button("Add comment") {}
        .buttonStyle(
          ThemedButtonStyle(
            fill: theme.fileTab.fill,
            text: theme.fileTab.text,
            minHeight: minHeight,
          )
        )
        .controlSize(.small)
        .fixedSize()
    )
    let window = OffscreenWindow.holding(
      host,
      rect: NSRect(x: 0, y: 0, width: 300, height: 100),
      deferred: false,
    )
    return withExtendedLifetime(window) { host.fittingSize.height }
  }

  @Test func aButtonGivenAHeightStandsThatTall() {
    #expect(Self.fittedHeight(minHeight: 24) == 24)
  }

  @Test func aButtonGivenNoHeightHugsItsTitle() {
    #expect(Self.fittedHeight(minHeight: nil) < 24)
  }
}
