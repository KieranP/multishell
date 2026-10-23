import Foundation
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

extension WorktreeCoordinatorMergesTests {
  /// Each run holds its slot for a second, as the status reads' width test does: at half
  /// a second a slow runner saw waves leave before the next arrived, testing no width.
  @Test func severalProjectsReadTogetherStartNoMoreGitThanOneDoes() async throws {
    let fake = try FakeGit.make(
      """
      case "$1" in
        cherry)
          mkdir -p "$SCRATCH/running"
          touch "$SCRATCH/running/$$"
          ls "$SCRATCH/running" | wc -l >> "$SCRATCH/counts"
          sleep 1
          rm "$SCRATCH/running/$$"
          echo "+ 1111111111111111111111111111111111111111" ;;
      esac
      """
    )
    defer { fake.tearDown() }
    let coordinator = fake.coordinator
    let projects = try ["one", "two"].map { name in
      let path = fake.directory.appendingPathComponent(name, isDirectory: true)
      try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
      return Project(path: path)
    }
    let inputs = stubInputs(defaultBranchTip: "a")
    let branches = (1...SharedReadState.maximumConcurrentReads).map { "b\($0)" }

    async let first = coordinator.readMerges(of: branches, in: projects[0], inputs: inputs)
    async let second = coordinator.readMerges(of: branches, in: projects[1], inputs: inputs)
    let read = await [first, second]

    #expect(read.map(\.count) == [branches.count, branches.count])
    let counts = try String(
      contentsOf: fake.directory.appendingPathComponent("counts"),
      encoding: .utf8,
    )
    let peak = counts.split(whereSeparator: \.isNewline).compactMap { line in
      Int(line.trimmingCharacters(in: .whitespaces))
    }.max()
    #expect(peak.map { $0 <= SharedReadState.maximumConcurrentReads } == true, "\(peak ?? 0)")
    #expect(peak ?? 0 >= 4, "runs did not overlap: \(peak ?? 0)")
  }
}
