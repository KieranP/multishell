import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

extension GitHarness {
  /// In the main worktree, returned beside the tab.
  func openFileTab(_ path: String = "README.md") throws -> (FileTab, Worktree) {
    let main = try #require(worktree(onBranch: "main"))
    return (try #require(model.openFileTab(path, in: main)), main)
  }

  /// The tab's rows once a read has given it some, `nil` if none came.
  func rowsArrive(in id: FileTab.ID) async throws -> FileTabRows? {
    let rows = { () -> FileTabRows? in
      if case .text(let rows) = self.model.fileTabReadings[id]?.content { rows } else { nil }
    }
    try await waitUntil { rows() != nil }
    return rows()
  }

  /// Yields until a read of the tab is under way, so a test can act while it runs; a wait
  /// that slept could miss a read that starts and ends between two looks.
  func readBegins(in id: FileTab.ID) async {
    var turns = 0
    while !model.fileTabReadLog.isReading(id), turns < 1_000_000 {
      await Task.yield()
      turns += 1
    }
  }
}
