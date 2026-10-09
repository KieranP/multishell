import Foundation
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite
struct WorktreeCoordinatorTests {
  @Test func theGitALaterPathFindsKeepsTheRunLogOfTheOneItReplaces() async throws {
    let directory = try Scratch.directory("coordinatorrunlog")
    defer { Scratch.remove(directory) }
    try Scratch.script("echo ran", at: directory.appendingPathComponent("git"))
    let first = try await WorktreeCoordinator.resolved(searchPath: directory.path, replacing: nil)

    let second = try await WorktreeCoordinator.resolved(
      searchPath: directory.path,
      replacing: first,
    )

    #expect(second.git.runLog === first.git.runLog)
  }
}
