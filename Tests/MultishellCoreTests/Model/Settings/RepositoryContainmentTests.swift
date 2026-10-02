import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// What a repository's own `.multishell.json` may name on the reader's disk:
/// only what is under the checkout; see Docs/design/settings.md.
@Suite
struct RepositoryContainmentTests {
  private let project = Project(path: URL(fileURLWithPath: "/Users/dev/Work/multishell"))

  private func holdsDirectory(_ directory: String) -> Bool {
    RepositoryContainment.holds(
      directory: WorktreeSettings(worktreeDirectory: directory).worktreeContainer(for: project),
      under: project.path)
  }

  @Test func aDirectoryUnderTheCheckoutStands() {
    #expect(holdsDirectory(".worktrees"))
    #expect(holdsDirectory("trees/{project}"))
    #expect(holdsDirectory("  .worktrees  "))
  }

  @Test func everyDirectoryOutsideTheCheckoutIsRefused() {
    let outside = [
      "~/.claude/skills", "~", "/tmp/trees", "/", "../{project}-worktrees", "..",
      ".worktrees/../..", "", "   ", ".", "./",
    ]
    for directory in outside {
      #expect(!holdsDirectory(directory), "\(directory.debugDescription)")
    }
  }

  @Test func aCommittedSymlinkCannotCarryTheDirectoryOutOfTheCheckout() throws {
    let root = try Scratch.directory("confined")
    defer { Scratch.remove(root) }
    let repository = root.appendingPathComponent("repo", isDirectory: true)
    let elsewhere = root.appendingPathComponent("elsewhere", isDirectory: true)
    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: repository.appendingPathComponent("trees"), withDestinationURL: elsewhere)
    #expect(
      !RepositoryContainment.holds(
        directory: repository.appendingPathComponent("trees"), under: repository))
  }

  @Test func aCommittedSymlinkCannotCarryADirectoryNotYetMadeOutOfTheCheckout() throws {
    let root = try Scratch.directory("confined-unmade")
    defer { Scratch.remove(root) }
    let repository = root.appendingPathComponent("repo", isDirectory: true)
    let elsewhere = root.appendingPathComponent("elsewhere", isDirectory: true)
    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: repository.appendingPathComponent("wt"), withDestinationURL: elsewhere)
    try FileManager.default.createSymbolicLink(
      at: repository.appendingPathComponent("dangling"),
      withDestinationURL: root.appendingPathComponent("nowhere"))

    #expect(
      !RepositoryContainment.holds(
        directory: repository.appendingPathComponent("wt/new/deeper"), under: repository))
    #expect(
      !RepositoryContainment.holds(
        directory: repository.appendingPathComponent("dangling/new"), under: repository),
      "a link to nothing yet could be made to point anywhere")
    #expect(
      RepositoryContainment.holds(
        directory: repository.appendingPathComponent("trees/new"), under: repository),
      "a plain directory still to be made stays inside")
  }

  @Test func aListedPathUnderTheCheckoutStands() {
    for path in [
      ".env", "config/local.yml", "a/../b", "./vendor", "*.env", "a/b/../c", "  .env  ",
      "deep/nested/path/file.txt", "cost$.txt", "src/a$b/c",
    ] {
      #expect(
        RepositoryContainment.holds(listedPath: path, under: project.path),
        "\(path.debugDescription)")
    }
  }

  @Test func aListedPathReachingOutsideTheCheckoutIsRefused() {
    let outside = [
      "~/.ssh/id_ed25519", "~", "~root/.ssh", "/Users/dev/.ssh/id_ed25519", "/etc/passwd", "/",
      "$HOME/.aws.json", "${HOME}/.aws.json", "../secrets", "a/../../b", "..", "../",
      "a/b/../../../c", "./../x", ".", "./", "", "   ", "a/../..",
    ]
    for path in outside {
      #expect(
        !RepositoryContainment.holds(listedPath: path, under: project.path),
        "\(path.debugDescription)")
    }
  }
}
