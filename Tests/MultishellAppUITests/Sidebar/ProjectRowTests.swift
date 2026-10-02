import Foundation
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct ProjectRowTests {
  private let project = Project(path: URL(fileURLWithPath: "/w/acme"))
  private let metrics = UIMetrics(fontSize: 13)

  private func projectRow(
    isFetching: Bool = false, toggleExpansion: @escaping () -> Void = {}
  )
    -> ProjectRow
  {
    ProjectRow(
      project: project, isExpanded: true, settings: ProjectSettings(), isMissing: false,
      state: nil,
      worktreeCount: 2, isFetching: isFetching, theme: .multishellDark, metrics: metrics,
      toggleExpansion: toggleExpansion, requestNewWorktree: {})
  }

  @Test func aProjectRowRebuiltWithFreshClosuresIsTheSameRowUntilItsStateMoves() {
    #expect(projectRow() == projectRow(toggleExpansion: { print("another") }))
    #expect(projectRow() != projectRow(isFetching: true))
  }
}
