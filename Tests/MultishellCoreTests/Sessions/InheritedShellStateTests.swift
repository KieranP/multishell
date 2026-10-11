import Testing

@testable import MultishellCore

@Suite
struct InheritedShellStateTests {
  @Test func theStateAShellsToolsKeepAboutItsOwnSessionIsNamedForDropping() {
    let environment = [
      "__MISE_ORIG_PATH": "/usr/bin:/Applications/Multishell.app/Contents/MacOS",
      "__MISE_DIFF": "x",
      "__MISE_SESSION": "y",
      "DIRENV_DIFF": "z",
      "DIRENV_DIR": "-/w",
      "DIRENV_LOG_FORMAT": "",
      "MISE_DATA_DIR": "/m",
      "__CF_USER_TEXT_ENCODING": "0x1F5:0x0:0x0",
      "PATH": "/usr/bin",
    ]

    #expect(
      InheritedShellState.names(in: environment)
        == ["DIRENV_DIFF", "DIRENV_DIR", "__MISE_DIFF", "__MISE_ORIG_PATH", "__MISE_SESSION"]
    )
  }
}
