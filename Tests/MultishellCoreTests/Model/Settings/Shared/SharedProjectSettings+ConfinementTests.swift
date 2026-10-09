import Foundation
import Testing

@testable import MultishellCore

/// A repository's file held to its checkout: what is dropped and what stands;
/// see Docs/design/settings.md.
@Suite
struct SharedProjectSettingsConfinementTests {
  private let project = Project(path: URL(fileURLWithPath: "/Users/dev/Work/multishell"))

  @Test func theRefusedDirectoryLeavesTheReadersOwnValueStanding() {
    var shared = SharedProjectSettings(
      worktreeDirectory: "~/.claude/skills",
      branchPrefix: "team/",
    )
    shared = shared.confined(to: project)
    #expect(shared.worktreeDirectory == nil)
    #expect(shared.branchPrefix == "team/", "only the one field is dropped")

    let layered = ProjectSettings().layered(over: shared)
    let defaults = WorktreeSettings(worktreeDirectory: "/global/trees")
    #expect(
      layered.effectiveWorktreeSettings(defaults: defaults).worktreeDirectory == "/global/trees"
    )
  }

  @Test func aDirectoryUnderTheCheckoutSurvivesConfinement() {
    let shared = SharedProjectSettings(worktreeDirectory: ".worktrees").confined(to: project)
    #expect(shared.worktreeDirectory == ".worktrees")
  }

  @Test func onlyTheReachingEntriesAreDroppedFromAList() {
    let shared = SharedProjectSettings(
      linkedPaths: "vendor\n~/.ssh/id_ed25519\nnode_modules",
      copiedPaths: "/etc/passwd\n../../.aws/credentials",
    ).confined(to: project)
    #expect(shared.linkedPaths == "vendor\nnode_modules")
    #expect(
      shared.copiedPaths == nil,
      "a list of nothing but escapes leaves the reader's standing",
    )
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
      linkedPaths: "~/.ssh/id_ed25519",
      copiedPaths: "~/.aws/credentials",
    )
    let layered = ProjectSettings().layered(over: shared.confined(to: project))
    #expect(layered.linkedPaths.isEmpty && layered.copiedPaths.isEmpty)
  }

  @Test func confiningLeavesTheDigestAloneSoAHookAnswerStillHolds() throws {
    let read = try writtenAndReadBack(
      SharedProjectSettings(worktreeDirectory: "/tmp/trees", postCreateHook: "npm ci")
    )
    let confined = read.confined(to: Project(path: URL(fileURLWithPath: "/repos/demo")))
    #expect(confined.digest == read.digest)
    #expect(confined.postCreateHook == "npm ci")
  }
}
