import AppKit
import Testing

@testable import Multishell

@Suite
struct AboutPanelTests {
  @Test func theBracketedVersionCarriesTheCommitBesideTheBuildNumber() {
    let options = AboutPanel.options(
      from: ["CFBundleVersion": "412", AboutPanel.commitKey: "1a2b3c4-dirty"])

    #expect(options[.version] as? String == "412, 1a2b3c4-dirty")
  }

  @Test func aBundleWithNoCommitKeepsThePanelsOwnVersion() {
    #expect(AboutPanel.options(from: ["CFBundleVersion": "412"]).isEmpty)
  }
}
