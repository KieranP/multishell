import CoreGraphics
import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlTabDescriptionTests {
  @Test func aTabIsShownWithItsPaneTreeEachSplitsSharesAndEachPanesFrame() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.splitActivePane(.horizontal)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.engine.frames[tab.sessionIDs[0]] = CGRect(x: 0, y: 40, width: 300, height: 500)

    let reply = try #require(await harness.messageSource.ask(.describeTab(id: tab.id)))

    #expect(reply.outputFields["worktree"] as? String == ControlID.worktree(harness.main.id))
    let layout = try #require(reply.outputFields["layout"] as? [String: Any])
    #expect(layout["axis"] as? String == "horizontal")
    #expect(layout["shares"] as? [Double] == [0.5, 0.5])
    let children = try #require(layout["children"] as? [[String: Any]])
    #expect(children.compactMap { $0["pane"] as? String } == tab.sessionIDs.map(\.uuidString))
    let frame = try #require(children.first?["frame"] as? [String: Double])
    #expect(frame == ["x": 0, "y": 40, "width": 300, "height": 500])
    #expect(children.last?["frame"] == nil, "a pane the engine has no frame for")
  }
}
