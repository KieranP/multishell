import GhosttyTerminal
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyConfigRepairTests {
  /// Two shapes get past the key list: a family member the pinned build lacks, and a
  /// value it does not take on a key it has.
  @MainActor
  @Test func aLineLibghosttyRefusesIsDroppedAndTheRestOfTheFileStands() {
    let base = GhosttyUserConfig.base(userContents: [
      """
      font-not-a-real-key = 3
      copy-on-select = sideways
      cursor-style = bar
      """
    ])
    let controller = TerminalController(configSource: .generated(base))
    #expect(controller.lastConfigurationIssue != nil)

    GhosttyConfigRepair.repair(controller, base: base)

    #expect(controller.lastConfigurationIssue == nil)
    #expect(controller.renderedConfig.contains("cursor-style = bar"))
    #expect(!controller.renderedConfig.contains("font-not-a-real-key"))
    #expect(!controller.renderedConfig.contains("copy-on-select"))
  }

  /// `repair` cannot place a complaint that names no line. Only a theme does that
  /// today, and a theme is dropped earlier, so this guards whatever does it next.
  @MainActor
  @Test func aComplaintThatNamesNoLineFallsBackToTheAppsDefaults() {
    let base = GhosttyUserConfig.defaults.rendered + "\ntheme = no-such-theme"
    let controller = TerminalController(configSource: .generated(base))
    #expect(controller.lastConfigurationIssue != nil)

    GhosttyConfigRepair.repair(controller, base: base)

    #expect(controller.lastConfigurationIssue == nil)
    // `renderedConfig` is the effective one, the controller's own default
    // theme included, so the app's defaults are its opening lines.
    #expect(controller.renderedConfig.hasPrefix(GhosttyUserConfig.defaults.rendered))
    #expect(!controller.renderedConfig.contains("no-such-theme"))
  }
}
