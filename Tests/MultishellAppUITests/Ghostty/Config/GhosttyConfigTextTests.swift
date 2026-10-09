import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyConfigTextTests {
  @Test func linesRenderInTheOrderSetSoALaterOneWins() {
    let text = GhosttyConfigText { config in
      config.set("font-size", "12")
      config.set("font-size", "13")
    }
    #expect(text.rendered == "font-size = 12\nfont-size = 13")
  }

  @Test func aFractionalSizeKeepsItsPointAndAWholeOneHasNone() {
    let text = GhosttyConfigText { $0.set("font-size", 13.5) }
    #expect(text.rendered == "font-size = 13.5")
    #expect(GhosttyConfigText { $0.set("font-size", 14) }.rendered == "font-size = 14")
  }

  @Test func aValueThatWouldStartAnotherLineIsLeftOut() {
    let text = GhosttyConfigText { config in
      config.set("background", "#000000\ncommand = /bin/false")
      config.set("foreground", "#ffffff\rcommand = /bin/false")
      config.set("cursor-color", "#808080")
    }
    #expect(text.rendered == "cursor-color = #808080")
  }
}
