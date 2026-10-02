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
}
