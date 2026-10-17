import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitIgnoredPathsTests {
  @Test func gitNamesTheIgnoredDirectoriesButNotOneHoldingATrackedFile() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try fixture.write("node_modules/\ndist\n", to: ".gitignore")
    for directory in ["node_modules/a", "packages/p/node_modules", "src", "dist"] {
      try FileManager.default.createDirectory(
        at: path.appendingPathComponent(directory),
        withIntermediateDirectories: true,
      )
    }
    try fixture.write("x\n", to: "dist/forced.js")
    _ = try await fixture.runner.run(["add", "-f", "dist/forced.js"], in: path)
    let git = WorktreeGit(runner: fixture.runner)

    let ignored = await git.ignoredPaths(
      ["node_modules", "node_modules/a", "packages", "packages/p/node_modules", "src", "dist"],
      in: path,
    )

    #expect(ignored == ["node_modules", "node_modules/a", "packages/p/node_modules"])
    #expect(await git.ignoredPaths(["src"], in: path) == [], "none ignored is an answer")
  }
}
