import Foundation
import Testing

@testable import MultishellCore

/// `Project` hand-writes coding keys, `==` and `hash` to keep this run's
/// `sharedSettings` out of all three, so a later field is silently unsaved.
@Suite
struct ProjectTests {
  @Test func aFieldAddedToProjectIsCaughtHere() throws {
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

  /// Identity reads the stored path, so every way in must normalise it.
  @Test func everySpellingOfADirectoryGivesTheSameIdentity() throws {
    let spellings = ["/repos/demo", "/repos/demo/", "/repos/x/../demo", "/repos/./demo//"]
    let projects = spellings.map { Project(path: URL(fileURLWithPath: $0)) }
    #expect(Set(projects.map(\.id)) == ["/repos/demo"])
    let worktrees = spellings.map {
      Worktree(path: URL(fileURLWithPath: $0), projectID: "/p", head: "h")
    }
    #expect(Set(worktrees.map(\.id)) == ["/repos/demo"])

    let decoded = try decodeJSON(Project.self, #"{ "path": "file:///repos/x/../demo" }"#)
    #expect(decoded.id == "/repos/demo")
  }
}
