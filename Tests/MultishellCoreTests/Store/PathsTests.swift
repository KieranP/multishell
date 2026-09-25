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

  /// A debug bundle built from a worktree gets its own state file, socket,
  /// integration directory and drops, so two worktrees can both `make run`.
  @Test func aWorktreesDebugBundleNamesItself() {
    #expect(Paths.debugVariant(named: "fix1") == ".debug-fix1")
    #expect(Paths.debugVariant(named: nil) == ".debug", "the checkout keeps the plain files")
    #expect(Paths.debugVariant(named: "") == ".debug", "make-app.sh writes the key empty")
  }

  /// `sun_path` holds 103 bytes, two spent on the `.b` the socket binds under, and this
  /// directory plus `multishell.debug-.sock` takes about 75, so the name is cut.
  @Test func aLongOrOddWorktreeNameIsCutAndSpelledSafely() {
    let longest = Paths.debugVariant(named: String(repeating: "\u{1F600}", count: 40))
    #expect(longest == ".debug-" + String(repeating: "-", count: 14))
    #expect(Paths.debugVariant(named: "feat.two wds/x") == ".debug-feat-two-wds-x")
    let socket =
      "/Users/averylongusername/Library/Application Support/Multishell"
      + "/multishell\(longest).sock"
    #expect(socket.utf8.count + ".b".utf8.count <= 103, "\(socket.utf8.count) bytes: \(socket)")
  }
}
