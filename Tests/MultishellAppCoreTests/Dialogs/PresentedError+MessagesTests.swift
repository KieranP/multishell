import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct PresentedErrorMessagesTests {
  @Test func eachMessageNamesWhatItIsAbout() {
    #expect(
      PresentedError.notARepository(URL(fileURLWithPath: "/w/notes")).message.hasPrefix("notes is")
    )
    #expect(PresentedError.worktreeDirectoryMissing("/w/t").message.hasPrefix("/w/t does not"))
    #expect(PresentedError.agentNotInstalled("Codex").title == "Codex is not installed")
    #expect(PresentedError.editorNotInstalled("Zed").message.contains("Install Zed"))
    #expect(PresentedError.noEditorCommand.message.contains("{path}"))
    #expect(PresentedError.themeUnreadable("bad json").message == "bad json")
  }
}
