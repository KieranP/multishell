import Foundation
import MultishellCore
import TestSupport
import Testing

@testable import MultishellGitKit

extension WorktreeCoordinatorMergesTests {
  @Test func severalProjectsReadTogetherStartNoMoreGitThanOneDoes() async throws {
    let fake = try FakeGit.make(
      """
      case "$1" in
        cherry)
          mkdir -p "$SCRATCH/running"
          touch "$SCRATCH/running/$$"
          ls "$SCRATCH/running" | wc -l >> "$SCRATCH/counts"
          sleep 0.5
          rm "$SCRATCH/running/$$"
          echo "+ 1111111111111111111111111111111111111111" ;;
      esac
      """)
    defer { fake.tearDown() }
    let coordinator = WorktreeCoordinator(
      git: WorktreeGit(runner: fake.runner, settlesNewIndex: false))
    let projects = try ["one", "two"].map { name in
      let path = fake.directory.appendingPathComponent(name, isDirectory: true)
      try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
      return Project(path: path)
    }
    let inputs = stubInputs(baseTip: "a")
    let branches = (1...SharedGitReads.maxConcurrentReads).map { "b\($0)" }

    async let first = coordinator.readMerges(of: branches, in: projects[0], inputs: inputs)
    async let second = coordinator.readMerges(of: branches, in: projects[1], inputs: inputs)
    let read = await [first, second]

    #expect(read.map(\.count) == [branches.count, branches.count])
    let counts = try String(
      contentsOf: fake.directory.appendingPathComponent("counts"), encoding: .utf8)
    let peak = counts.split(whereSeparator: \.isNewline).compactMap {
      Int($0.trimmingCharacters(in: .whitespaces))
    }.max()
    #expect(peak.map { $0 <= SharedGitReads.maxConcurrentReads } == true, "\(peak ?? 0)")
  }
}
