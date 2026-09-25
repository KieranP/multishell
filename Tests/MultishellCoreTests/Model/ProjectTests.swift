import Foundation
import Testing

@testable import MultishellCore

/// `Project` hand-writes coding keys, `==` and `hash` to keep this run's
/// `sharedSettings` out of all three, so a later field is silently unsaved.
@Suite
struct ProjectTests {
  @Test func everyFieldIsAccountedForInCodingKeysAndEquality() throws {
    let fields = Mirror(reflecting: Project(path: URL(fileURLWithPath: "/r")))
      .children.compactMap(\.label)

    #expect(
      fields == ["path", "isExpanded", "settings", "sharedSettings"],
      """
      A field was added to Project. Put it in CodingKeys, == and hash unless \
      it is per-run state like sharedSettings, then add it here.
      """)
  }

  /// The three that are saved come back; the one that is not resets, or a
  /// restored project would trust a file this run never read.
  @Test func aRoundTripKeepsTheSavedFieldsAndForgetsTheRead() throws {
    var project = Project(
      path: URL(fileURLWithPath: "/r"), isExpanded: false,
      settings: ProjectSettings(branchPrefix: "team/"))
    let shared = SharedProjectSettings(branchPrefix: "theirs/")
    project.sharedSettings.recordParsed(
      shared, confined: shared.confined(to: project), modificationDate: .now)

    let decoded = try JSONDecoder().decode(
      Project.self, from: JSONEncoder().encode(project))

    #expect(decoded.path == project.path && decoded.isExpanded == false)
    #expect(decoded.settings.branchPrefix == "team/")
    #expect(decoded.sharedSettings == .unread, "and nothing of the file survives")
  }
}
