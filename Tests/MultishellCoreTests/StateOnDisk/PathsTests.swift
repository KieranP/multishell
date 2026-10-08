import Foundation
import Testing

@testable import MultishellCore

@Suite
struct PathsTests {
  /// Tests are debug builds, so they see the debug variant. Reading it walks up for an
  /// `.app`, and a walk that never ends would hang the run rather than fail it.
  @Test(.timeLimit(.minutes(1)))
  func debugBuildsKeepTheirOwnStateSocketAndIntegration() {
    #expect(Paths.stateFile.lastPathComponent == "state\(Paths.variant).json")
    #expect(Paths.socketFile.lastPathComponent == "multishell\(Paths.variant).sock")
    #expect(Paths.integrationDirectory.lastPathComponent == "integration\(Paths.variant)")
    #expect(Paths.helperLink.lastPathComponent == "multishell", "shared: hooks reference it")
    #if DEBUG
      // A test process is no app bundle, so it carries no worktree name.
      #expect(Paths.variant == ".debug")
    #endif
  }
}
