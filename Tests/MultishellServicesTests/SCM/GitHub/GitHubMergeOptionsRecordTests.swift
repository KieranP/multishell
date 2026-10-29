import Foundation
import Testing

@testable import MultishellServices

@Suite
struct GitHubMergeOptionsRecordTests {
  private func options(_ json: String) throws -> PullRequestMergeOptions {
    try GitHubMergeOptionsRecord.options(from: Data(json.utf8))
  }

  @Test func theAllowedMethodsTheViewersDefaultAndGitHubsMessagesAreRead() throws {
    let options = try options(GitHubFixtures.mergeOptions)

    #expect(options.methods == [.squash, .rebase])
    #expect(options.defaultMethod == .squash)
    #expect(options.allowsAutoMerge)
    #expect(options.viewerMayMerge)
    #expect(
      options.messages[.squash]
        == PullRequestMergeMessage(
          subject: "Add Antigravity CLI hooks and port the OpenCode plugin to OpenCode 2 (#26)",
          body: "Google stopped serving Gemini CLI on personal plans.\n\nCo-authored-by: Claude",
        )
    )
    #expect(options.messages[.merge]?.subject == "Merge pull request #26 from KieranP/agents")
  }

  @Test func aDefaultTheRepositoryNoLongerAllowsFallsToTheFirstAllowed() throws {
    let json = GitHubFixtures.mergeOptions.replacingOccurrences(
      of: #""viewerDefaultMergeMethod":"SQUASH""#,
      with: #""viewerDefaultMergeMethod":"MERGE""#,
    )

    #expect(try options(json).defaultMethod == .squash)
  }

  @Test func aViewerWhoMayOnlyReadOrTriageMayNotMerge() throws {
    for role in ["READ", "TRIAGE"] {
      let json = GitHubFixtures.mergeOptions.replacingOccurrences(
        of: #""viewerPermission":"ADMIN""#,
        with: #""viewerPermission":"\#(role)""#,
      )
      #expect(try !options(json).viewerMayMerge)
    }
  }

  @Test func aRoleGitHubDidNotAnswerIsLeftForGitHubToJudge() throws {
    let json = GitHubFixtures.mergeOptions.replacingOccurrences(
      of: #""viewerPermission":"ADMIN""#,
      with: #""viewerPermission":null"#,
    )

    #expect(try options(json).viewerMayMerge)
  }

  @Test func aRepositoryWithAutoMergeOffSaysSo() throws {
    let json = GitHubFixtures.mergeOptions.replacingOccurrences(
      of: #""autoMergeAllowed":true"#,
      with: #""autoMergeAllowed":false"#,
    )

    #expect(try !options(json).allowsAutoMerge)
  }

  @Test func anAnswerAllowingNoMethodFailsTheRead() {
    let json = GitHubFixtures.mergeOptions
      .replacingOccurrences(
        of: #""squashMergeAllowed":true"#,
        with: #""squashMergeAllowed":false"#,
      )
      .replacingOccurrences(
        of: #""rebaseMergeAllowed":true"#,
        with: #""rebaseMergeAllowed":false"#,
      )

    #expect(throws: ServiceReadFailure.self) { try options(json) }
  }

  @Test func anAnswerWithNoRepositoryFailsTheRead() {
    #expect(throws: ServiceReadFailure.self) { try options(#"{"data":{"repository":null}}"#) }
  }
}
