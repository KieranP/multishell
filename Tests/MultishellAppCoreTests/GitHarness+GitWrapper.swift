import Foundation
import TestScratch
import TestSupport

@testable import MultishellAppCore
@testable import MultishellGitKit

extension GitHarness {
  /// The model's git becomes a script that runs `prelude` and then the real git.
  func wrapGit(in prelude: String) throws {
    model.coordinator = TestGit.coordinator(
      runner: try TestGit.runner(
        wrappingRealGitIn: prelude,
        at: root.appendingPathComponent("fake-git"),
      )
    )
  }
}
