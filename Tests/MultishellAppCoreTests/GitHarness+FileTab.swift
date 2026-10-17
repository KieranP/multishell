import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

extension GitHarness {
  /// Selects `main` and opens `path` in a file tab there, the reconcile handing
  /// it the keyboard as a click would.
  func openFileTab(_ path: String = "README.md") throws -> (FileTab, Worktree) {
    let main = try #require(worktree(onBranch: "main"))
    model.select(main)
    let tab = try #require(store.openFileTab(path: path, in: main.id))
    model.reconcileSessions(takingFocus: true)
    return (tab, main)
  }

  /// The tab's rows once a read has given it some, `nil` if none came.
  func rowsArrive(in id: FileTab.ID) async throws -> FileTabRows? {
    let rows = { () -> FileTabRows? in
      if case .text(let rows) = self.model.fileTabReadings[id]?.content { rows } else { nil }
    }
    try await waitUntil { rows() != nil }
    return rows()
  }
}
