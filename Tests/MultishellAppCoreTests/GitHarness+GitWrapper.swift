import Foundation
import TestScratch
import TestSupport

@testable import MultishellAppCore
@testable import MultishellGitKit

extension GitHarness {
  /// The model's git becomes a script that runs `prelude` and then the real git.
  func wrapGit(in prelude: String) throws {
    let wrapper = try Scratch.script(
      prelude + "\nexec git \"$@\"",
      at: root.appendingPathComponent("fake-git"),
    )
    model.coordinator = TestGit.coordinator(
      runner: try TestGit.runner(executable: wrapper)
    )
  }
}
