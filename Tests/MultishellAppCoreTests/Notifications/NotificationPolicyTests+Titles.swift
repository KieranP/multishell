import Testing

@testable import MultishellAppCore

extension NotificationPolicyTests {
  @Test func theTitlePutsTheSubjectBeforeWhereItIs() {
    #expect(
      NotificationPolicy.title(subject: "claude", project: "acme", worktree: "feat")
        == "claude · acme › feat")
  }
}
