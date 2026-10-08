import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct InheritedSettingWorktreeCaptionsTests {
  @Test func aCaptionNamesTheFileOnlyWhileTheFileChoseAndNothingOverridesIt() {
    let fromFile = InheritedSetting<String>(value: ".worktrees", isFromRepository: true)
    #expect(
      fromFile.containerCaption("/r/.worktrees", isOverridden: false)
        == "Resolves to /r/.worktrees, from .multishell.json.")
    #expect(fromFile.containerCaption("/r/own", isOverridden: true) == "Resolves to /r/own.")
    let fromGlobal = InheritedSetting<String>(value: "../trees", isFromRepository: false)
    #expect(fromGlobal.containerCaption("/trees", isOverridden: false) == "Resolves to /trees.")

    #expect(
      fromFile.prefixExampleCaption(branch: "me/tabs", path: "/t/me-tabs", isOverridden: false)
        == "Typing tabs creates me/tabs at /t/me-tabs. The prefix comes from .multishell.json.")
    #expect(
      fromFile.prefixExampleCaption(branch: "tabs", path: "/t/tabs", isOverridden: true)
        == "Typing tabs creates tabs at /t/tabs.")
  }
}
