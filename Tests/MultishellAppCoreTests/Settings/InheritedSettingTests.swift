import Testing

@testable import MultishellAppCore
@testable import MultishellCore

/// What a settings form says about a flag the project leaves alone. The
/// global stopped being the only answer when the file gained these keys.
@Suite @MainActor
struct InheritedSettingTests {
  @Test func aFlagTheRepositorySuppliesIsNamedAsItsOwn() {
    let fromFile = InheritedSetting<Bool>(value: true, isFromRepository: true)
    #expect(fromFile.caption == "Using the value in .multishell.json: on.")
    let fromGlobal = InheritedSetting<Bool>(value: false, isFromRepository: false)
    #expect(fromGlobal.caption == "Using the global value: off.")
  }

  @Test func aPathCaptionNamesTheFileOnlyWhileTheFileChoseAndNothingOverridesIt() {
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
