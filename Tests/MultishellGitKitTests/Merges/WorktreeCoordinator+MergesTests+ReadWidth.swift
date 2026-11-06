import Foundation
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

extension WorktreeCoordinatorMergesTests {
  @Test func severalProjectsReadTogetherStartNoMoreGitThanOneDoes() async throws {
    let fake = try FakeGit.countingOverlap(
      replying: #"echo "+ 1111111111111111111111111111111111111111""#,
      toOnly: "cherry",
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
    let peak = fake.overlaps.max()
    #expect(peak.map { $0 <= SharedReadState.maximumConcurrentReads } == true, "\(peak ?? 0)")
    #expect(peak ?? 0 >= 4, "runs did not overlap: \(peak ?? 0)")
  }
}
