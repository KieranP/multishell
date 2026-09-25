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
    defer { try? FileManager.default.removeItem(at: root) }
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
    defer { try? FileManager.default.removeItem(at: root) }
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

  @Test func theRefusedDirectoryLeavesTheReadersOwnValueStanding() {
    var shared = SharedProjectSettings(worktreeDirectory: "~/.claude/skills", branchPrefix: "team/")
    shared = shared.confined(to: project)
    #expect(shared.worktreeDirectory == nil)
    #expect(shared.branchPrefix == "team/", "only the one field is dropped")

    let layered = ProjectSettings().layered(over: shared)
    let defaults = WorktreeSettings(worktreeDirectory: "/global/trees")
    #expect(layered.effective(defaults: defaults).worktreeDirectory == "/global/trees")
  }

  @Test func aDirectoryUnderTheCheckoutSurvivesConfinement() {
    let shared = SharedProjectSettings(worktreeDirectory: ".worktrees").confined(to: project)
    #expect(shared.worktreeDirectory == ".worktrees")
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

  @Test func onlyTheReachingEntriesAreDroppedFromAList() {
    let shared = SharedProjectSettings(
      linkedPaths: "vendor\n~/.ssh/id_ed25519\nnode_modules",
      copiedPaths: "/etc/passwd\n../../.aws/credentials"
    ).confined(to: project)
    #expect(shared.linkedPaths == "vendor\nnode_modules")
    #expect(shared.copiedPaths == nil, "a list of nothing but escapes leaves the reader's standing")
  }

  @Test func aListWithNothingToDropComesBackAsItWasWritten() {
    let list = "# what the build needs\nvendor\n\nnode_modules"
    let shared = SharedProjectSettings(linkedPaths: list, copiedPaths: ".env")
      .confined(to: project)
    #expect(shared.linkedPaths == list, "export writes this text back over the file")
    #expect(shared.copiedPaths == ".env")
  }

  @Test func aKeyLinkedFromHomeNeverReachesTheReadersWorktree() {
    let shared = SharedProjectSettings(
      linkedPaths: "~/.ssh/id_ed25519", copiedPaths: "~/.aws/credentials")
    let layered = ProjectSettings().layered(over: shared.confined(to: project))
    #expect(layered.linkedPaths.isEmpty && layered.copiedPaths.isEmpty)
  }

  @Test func confiningLeavesTheDigestAloneSoAHookAnswerStillHolds() throws {
    let root = try Scratch.directory("confined-digest")
    defer { try? FileManager.default.removeItem(at: root) }
    try SharedProjectSettings(worktreeDirectory: "/tmp/trees", postCreateHook: "npm ci")
      .write(to: root)
    let read = try #require(try SharedProjectSettings.load(from: root))
    let confined = read.confined(to: Project(path: root))
    #expect(confined.digest == read.digest)
    #expect(confined.postCreateHook == "npm ci")
  }
}
