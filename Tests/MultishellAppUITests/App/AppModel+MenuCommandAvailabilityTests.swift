import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct AppModelMenuCommandAvailabilityTests {
  @Test func withNoWorktreeInViewItsCommandsCannotActButTheOthersCan() {
    let models = ModelHarness()
    let worktreeCommands = [
      t("menu.new-tab"), t("menu.split-right"), t("menu.close-pane"), t("menu.next-tab"),
      t("menu.files-panel"),
    ]

    for title in worktreeCommands {
      #expect(!models.model.isMenuCommandAvailable(titled: title), "\(title)")
    }
    #expect(models.model.isMenuCommandAvailable(titled: t("menu.new-worktree")))
    #expect(models.model.isMenuCommandAvailable(titled: t("label.agents")))
  }
}
