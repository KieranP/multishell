import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

extension GitHarness {
  /// The model's git holds every fetch until `gate` exists, having touched `fetching`;
  /// `during` runs in the worktree as the fetch begins.
  func holdFetches(
    until gate: URL,
    touching fetching: URL,
    during: String = ":",
  ) throws {
    try wrapGit(
      in: """
        if [ "$1" = fetch ]; then
          \(during)
          touch '\(fetching.path)'
          \(holdLine(until: gate))
        fi
        """
    )
  }

  func awaitFetch(_ fetching: URL) async throws {
    try await waitUntil({ FileManager.default.fileExists(atPath: fetching.path) }, seconds: 10)
    try #require(FileManager.default.fileExists(atPath: fetching.path))
  }
}
