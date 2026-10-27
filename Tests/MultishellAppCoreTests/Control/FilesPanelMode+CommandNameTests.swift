import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct FilesPanelModeCommandNameTests {
  @Test(arguments: [FilesPanelMode.files, .changes, .pullRequest, .ciRuns])
  func eachPageIsNamedAndReadBackByItsCommandName(mode: FilesPanelMode) {
    #expect(FilesPanelMode(commandName: mode.commandName) == mode)
  }
}
