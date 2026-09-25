import Foundation
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct ProjectRowTests {
  private let project = Project(path: URL(fileURLWithPath: "/w/acme"))
  private let metrics = UIMetrics(fontSize: 13)

  private func projectRow(
    isFetching: Bool = false, toggle: @escaping () -> Void = {}
  )
    -> ProjectRow
  {
    ProjectRow(
      project: project, settings: ProjectSettings(), isMissing: false, state: nil,
      worktreeCount: 2, isFetching: isFetching, theme: .multishellDark, metrics: metrics,
      toggle: toggle, newWorktree: {})
  }

  @Test func aProjectRowRebuiltWithFreshClosuresIsTheSameRowUntilItsStateMoves() {
    #expect(projectRow() == projectRow(toggle: { print("another") }))
    #expect(projectRow() != projectRow(isFetching: true))
  }
}
