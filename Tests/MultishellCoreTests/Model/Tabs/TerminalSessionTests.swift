import Foundation
import Testing

@testable import MultishellCore

struct TerminalSessionTests {
  @Test func aSessionWithoutAnAgentIDIsAPlainShell() throws {
    let session = try decodeJSON(
      TerminalSession.self,
      #"{ "id": "\#(UUID().uuidString)", "worktreeID": "/w", "workingDirectory": "file:///w/", "title": "Shell" }"#
    )
    #expect(session.agentID == nil)
    #expect(session.command == nil)
  }

  @Test func aSessionsShellIsRuntimeOnlyAndNeverSaved() throws {
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w"), title: "Shell",
      shellOverride: "/bin/bash")
    let json = String(decoding: try JSONEncoder().encode(session), as: UTF8.self)
    #expect(!json.contains("/bin/bash"))
    let restored = try JSONDecoder().decode(TerminalSession.self, from: Data(json.utf8))
    #expect(restored.shellOverride == nil, "a relaunched tab reads the setting again")
    #expect(restored.shellPath == ShellCatalogue.loginShellPath())
  }

  @Test func aProgramsTabKeepsTheProgramsName() throws {
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w"), title: "nvim")

    #expect(session.displayTitle == "nvim")
  }
}
