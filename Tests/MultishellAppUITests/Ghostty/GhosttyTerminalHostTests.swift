import Foundation
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
@MainActor
struct GhosttyTerminalHostTests {
  @Test func aTabsCommandRunsInsteadOfItsChosenShellAsOneQuotedLine() {
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w"), title: "Agent",
      command: ["claude", "--resume", "a b"], shellOverride: "/opt/homebrew/bin/fish")
    #expect(GhosttyTerminalHost.command(for: session) == "claude --resume 'a b'")
  }
}
