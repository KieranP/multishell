import Foundation
import Testing

@testable import MultishellCore

@Suite
struct SharedProjectSettingsTrustTests {
  @Test func theQuestionShowsTheListsAlongsideTheHooks() throws {
    let shared = SharedProjectSettings(
      postCreateHook: "npm ci", linkedPaths: "node_modules", copiedPaths: ".env")
    let text = try #require(shared.trustCoveredText)

    #expect(text.contains("post-create:\nnpm ci"))
    #expect(text.contains("linked:\nnode_modules"))
    #expect(text.contains("copied:\n.env"))
  }

  @Test func aFileWithNeitherHooksNorListsIsNeverAskedAbout() throws {
    let shared = try writtenAndReadBack(
      SharedProjectSettings(branchPrefix: "team/", iconGlyph: "hammer"))
    #expect(!shared.asksForTrust)
    #expect(shared.trustCoveredText == nil)
    #expect(!ProjectSettings().needsTrustDecision(for: shared))
  }

  @Test func theHooksTextNamesEachHookSoTheQuestionSaysWhichStageRunsWhat() {
    let one = SharedProjectSettings(postCreateHook: "npm ci")
    #expect(one.trustCoveredText == "post-create:\nnpm ci")
    let two = SharedProjectSettings(postCreateHook: "npm ci", preDeleteHook: "exit 1")
    #expect(two.trustCoveredText == "post-create:\nnpm ci\n\npre-delete:\nexit 1")
    #expect(one.trustCoveredText != two.trustCoveredText, "a hook added is shown")
    #expect(SharedProjectSettings(branchPrefix: "x/").trustCoveredText == nil)
  }

  @Test func theQuestionNamesEachFieldInTheCataloguesWords() throws {
    let shared = SharedProjectSettings(
      worktreeDirectory: ".trees", preCreateHook: "a", postCreateHook: "b", preDeleteHook: "c",
      postDeleteHook: "d", linkedPaths: "e", copiedPaths: "f")
    let names = try #require(shared.trustCoveredText).split(separator: "\n\n").map {
      String($0.prefix { $0 != ":" })
    }

    #expect(
      names == [
        t("shared-settings.worktree-directory"), t("shared-settings.pre-create"),
        t("shared-settings.post-create"), t("shared-settings.pre-delete"),
        t("shared-settings.post-delete"), t("shared-settings.linked"),
        t("shared-settings.copied"),
      ])
  }

  @Test func everyFieldTheYesCoversIsShownInTheQuestion() throws {
    var shared = SharedProjectSettings()
    for field in SharedProjectSettings.trustCoveredFields { shared[keyPath: field] = "x" }
    let shown = try #require(shared.trustCoveredText).components(separatedBy: "\n\n")
    #expect(shown.count == SharedProjectSettings.trustCoveredFields.count)
  }

  /// Where a checkout lands is the reader's disk too. Inside the repository
  /// is all it may name, and even that waits for the file to be trusted.
  @Test func aRepositorysWorktreeDirectoryWaitsToBeTrusted() throws {
    let shared = try writtenAndReadBack(SharedProjectSettings(worktreeDirectory: ".worktrees"))
    #expect(shared.asksForTrust)
    #expect(try #require(shared.trustCoveredText).contains("worktree directory:\n.worktrees"))

    let untrusted = ProjectSettings().layered(over: shared)
    #expect(untrusted.worktreeDirectory == nil, "the reader's own, so the global default")

    var settings = ProjectSettings()
    settings.recordTrustDecision(digest: try #require(shared.digest), isTrusted: true)
    #expect(settings.layered(over: shared).worktreeDirectory == ".worktrees")
  }

  /// `copiedPaths: .aws.json` would carry a secret into a worktree an agent reads,
  /// so a list waits for a hook's yes. The user's own list wins whole.
  @Test func aRepositorysListOfWhatNewWorktreesAreGivenWaitsToBeTrusted() throws {
    let shared = try writtenAndReadBack(
      SharedProjectSettings(linkedPaths: "node_modules", copiedPaths: ".env\n.env.local"))
    #expect(shared.asksForTrust, "a list reads files, so it is asked about")

    let untrusted = ProjectSettings().layered(over: shared)
    #expect(untrusted.copiedPaths.isEmpty && untrusted.linkedPaths.isEmpty)

    var settings = ProjectSettings()
    settings.recordTrustDecision(digest: try #require(shared.digest), isTrusted: true)
    let trusted = settings.layered(over: shared)
    #expect(trusted.copiedPaths == ".env\n.env.local" && trusted.linkedPaths == "node_modules")

    var own = ProjectSettings(linkedPaths: "vendor", copiedPaths: ".env")
    own.recordTrustDecision(digest: try #require(shared.digest), isTrusted: true)
    #expect(own.layered(over: shared).copiedPaths == ".env", "the user's list wins whole")
    #expect(own.layered(over: shared).linkedPaths == "vendor")
  }
}
