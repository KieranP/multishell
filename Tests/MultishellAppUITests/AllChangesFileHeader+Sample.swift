import Foundation
import SwiftUI

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

extension AllChangesFileHeader {
  private static let sampleHarness = ModelHarness()

  /// A header for one file of `document`, in a tab of no worktree of the harness.
  static func sample(of document: AllChangesDocument, section: Int = 0) -> Self {
    AllChangesFileHeader(
      model: sampleHarness.model,
      tabID: UUID(),
      worktreeID: "/repos/demo",
      section: document.sections[section],
      pendingComments: 0,
      theme: Theme.builtins[0],
    )
  }
}
