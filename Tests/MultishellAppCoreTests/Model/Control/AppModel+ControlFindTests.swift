import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlFindTests {
  @Test func aFindOpensThePanesBarSearchesAndShowsWhatTheEngineCounted() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id

    _ = await harness.messageSource.ask(.findInPane(id: pane, action: .open("error")))
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .total(3), in: pane)
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .selected(0), in: pane)
    let reply = try #require(await harness.messageSource.ask(.describePane(id: pane)))

    #expect(harness.model.findBarTargetIDs.contains(pane))
    #expect(harness.engine.searched.last?.step == .find("error"))
    let find = try #require(reply.outputFields["find"] as? [String: Any])
    #expect(find["text"] as? String == "error")
    #expect(find["total"] as? Int == 3)
    #expect(find["selected"] as? Int == 0)
  }

  @Test func aStepNeedsTheBarUpAndCloseTakesItDownAndItsCount() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id

    #expect(
      await harness.messageSource.ask(.findInPane(id: pane, action: .next))
        == .refused(.noFindBar(id: pane))
    )
    _ = await harness.messageSource.ask(.findInPane(id: pane, action: .open("x")))
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .total(1), in: pane)
    _ = await harness.messageSource.ask(.findInPane(id: pane, action: .next))
    #expect(harness.engine.searched.last?.step == .nearest)
    let closed = try #require(
      await harness.messageSource.ask(.findInPane(id: pane, action: .close))
    )

    #expect(closed.outputFields["find"] == nil)
    #expect(harness.model.searchCounts[pane] == nil)
  }

  @Test func aCloseLeavesTheKeyboardWhereItWas() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id
    _ = await harness.messageSource.ask(.findInPane(id: pane, action: .open("x")))
    let focusedBefore = harness.engine.focused

    _ = await harness.messageSource.ask(.findInPane(id: pane, action: .close))

    #expect(!harness.model.findBarTargetIDs.contains(pane))
    #expect(harness.engine.focused == focusedBefore)
  }

  @Test func theSameTextSearchedAgainKeepsTheCountTheEngineWillNotResend() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id
    _ = await harness.messageSource.ask(.findInPane(id: pane, action: .open("error")))
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .total(3), in: pane)

    _ = await harness.messageSource.ask(.findInPane(id: pane, action: .open("error")))

    #expect(harness.model.searchCounts[pane]?.total == 3)
  }

  @Test func theSameTextSearchedAgainKeepsTheSelectionSoTheNextStepMovesOn() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id
    _ = await harness.messageSource.ask(.findInPane(id: pane, action: .open("x")))
    _ = await harness.messageSource.ask(.findInPane(id: pane, action: .next))

    _ = await harness.messageSource.ask(.findInPane(id: pane, action: .open("x")))
    _ = await harness.messageSource.ask(.findInPane(id: pane, action: .next))

    #expect(harness.engine.searched.last?.step == .next)
  }

  @Test func anEmptyFindTextIsRefusedAsNothingToFind() async throws {
    let (harness, onlyPane) = Harness.withOnePane()
    let pane = onlyPane.id

    #expect(
      await harness.messageSource.ask(.findInPane(id: pane, action: .open("")))
        == .refused(.noFindText(id: pane))
    )
    harness.model.showFind()
    #expect(
      await harness.messageSource.ask(.findInPane(id: pane, action: .next))
        == .refused(.noFindText(id: pane))
    )
  }
}
