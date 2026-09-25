import Foundation
import Testing

@testable import MultishellCore

struct TabGroupTests {
  /// A group written by a build that had neither field, and one whose width
  /// is a number nothing can be laid out in.
  @Test func aTabGroupWithoutAWidthOrAnActiveTabStillLoads() throws {
    let bare = try decodeJSON(
      TabGroup.self, #"{ "id": "\#(UUID())", "worktreeID": "/repos/demo" }"#)
    #expect(bare.weight == 1)
    #expect(bare.activeTabID == nil)

    let zero = try decodeJSON(
      TabGroup.self, #"{ "id": "\#(UUID())", "worktreeID": "/repos/demo", "weight": 0 }"#)
    #expect(zero.weight == 1, "a group of no width would draw nothing")
  }
}
