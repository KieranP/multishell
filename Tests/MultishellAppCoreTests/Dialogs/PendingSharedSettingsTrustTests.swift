import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct PendingSharedSettingsTrustTests {
  @Test func theSharedSettingsQuestionShowsWhatIsAskedForAndNamesTheFile() {
    let pending = PendingSharedSettingsTrust(
      projectID: "/r", projectName: "acme",
      trustCoveredText: "post-create:\nnpm ci\n\ncopied:\n.env",
      digest: FileDigest.sha256(of: Data()))
    #expect(pending.title == "Trust what acme's .multishell.json asks for?")
    #expect(pending.message.hasSuffix("post-create:\nnpm ci\n\ncopied:\n.env"))
    #expect(pending.trustLabel == "Trust" && pending.declineLabel == "Ignore")
  }
}
