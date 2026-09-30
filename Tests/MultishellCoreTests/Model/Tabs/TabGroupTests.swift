import Foundation
import Testing

@testable import MultishellCore

struct TabGroupTests {
  /// A group written by a build that had neither field, and one whose width
  /// is a number nothing can be laid out in.
  @Test func aTabGroupWithoutAWidthOrAShownTabStillLoads() throws {
    let bare = try decodeJSON(
      TabGroup.self, #"{ "id": "\#(UUID())", "worktreeID": "/repos/demo" }"#)
    #expect(bare.weight == 1)
    #expect(bare.shownTabID == nil)

    let zero = try decodeJSON(
      TabGroup.self, #"{ "id": "\#(UUID())", "worktreeID": "/repos/demo", "weight": 0 }"#)
    #expect(zero.weight == 1, "a group of no width would draw nothing")
  }

  @Test func theShownTabIsSavedAndReadUnderTheKeyEarlierBuildsWrote() throws {
    let tab = UUID()
    let saved = try decodeJSON(
      TabGroup.self,
      #"{ "id": "\#(UUID())", "worktreeID": "/repos/demo", "activeTabID": "\#(tab)" }"#)
    #expect(saved.shownTabID == tab)

    let written = try JSONSerialization.jsonObject(with: JSONEncoder().encode(saved))
    #expect((written as? [String: Any])?["activeTabID"] as? String == tab.uuidString)
  }
}
