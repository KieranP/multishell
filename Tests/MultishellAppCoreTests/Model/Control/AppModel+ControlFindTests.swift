import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlFindTests {
  @Test func aFindOpensThePanesBarSearchesAndShowsWhatTheEngineCounted() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id

    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .search("error")))
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .total(3), in: pane)
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .selected(0), in: pane)
    let reply = try #require(await harness.stateSource.ask(.describePane(id: pane)))

    #expect(harness.model.findBarSessionIDs.contains(pane))
    #expect(harness.engine.searched.last?.command == .find("error"))
    let find = try #require(reply.outputFields["find"] as? [String: Any])
    #expect(find["text"] as? String == "error")
    #expect(find["total"] as? Int == 3)
    #expect(find["selected"] as? Int == 0)
  }

  @Test func aStepNeedsTheBarUpAndCloseTakesItDownAndItsCount() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id

    #expect(
      await harness.stateSource.ask(.findInPane(id: pane, action: .next))
        == .refused(.noFindBar(id: pane))
    )
    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .search("x")))
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .total(1), in: pane)
    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .next))
    #expect(harness.engine.searched.last?.command == .nearest)
    let closed = try #require(await harness.stateSource.ask(.findInPane(id: pane, action: .close)))

    #expect(closed.outputFields["find"] == nil)
    #expect(harness.model.searchCounts[pane] == nil)
  }

  @Test func aCloseLeavesTheKeyboardWhereItWas() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id
    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .search("x")))
    let focusedBefore = harness.engine.focused

    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .close))

    #expect(!harness.model.findBarSessionIDs.contains(pane))
    #expect(harness.engine.focused == focusedBefore)
  }

  @Test func theSameTextAgainOrInAnotherCaseKeepsTheCountTheEngineWillNotResend() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id
    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .search("error")))
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .total(3), in: pane)

    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .search("error")))
    #expect(harness.model.searchCounts[pane]?.total == 3)
    harness.model.setFindText("ERROR", of: pane)
    #expect(harness.model.searchCounts[pane]?.total == 3)
    harness.model.setFindText("warning", of: pane)
    #expect(harness.model.searchCounts[pane]?.total == nil)
  }

  @Test func theSameTextSearchedAgainKeepsTheSelectionSoTheNextStepMovesOn() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id
    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .search("x")))
    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .next))

    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .search("x")))
    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .next))

    #expect(harness.engine.searched.last?.command == .next)
  }

  @Test func aStepDropsTheSelectionItLeavesUntilTheEngineSaysTheNewOne() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id
    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .search("x")))
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .total(5), in: pane)
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .selected(4), in: pane)

    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .next))

    #expect(harness.model.searchCounts[pane]?.selected == nil)
    #expect(harness.model.searchCounts[pane]?.total == 5)
  }

  @Test func aStepOverTheOnlyMatchKeepsTheSelectionTheEngineWillNotResend() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id
    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .search("x")))
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .total(1), in: pane)
    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .next))
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .selected(0), in: pane)

    _ = await harness.stateSource.ask(.findInPane(id: pane, action: .next))

    #expect(harness.model.searchCounts[pane]?.selected == 0)
  }

  @Test func anEmptyFindTextIsRefusedAsNothingToFind() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id

    #expect(
      await harness.stateSource.ask(.findInPane(id: pane, action: .search("")))
        == .refused(.noFindText(id: pane))
    )
    harness.model.showFind()
    #expect(
      await harness.stateSource.ask(.findInPane(id: pane, action: .next))
        == .refused(.noFindText(id: pane))
    )
  }
}
