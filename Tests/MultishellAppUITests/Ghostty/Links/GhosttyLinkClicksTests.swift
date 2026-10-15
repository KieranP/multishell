import Foundation
import Synchronization
import TestScratch
import Testing

@testable import MultishellAppUI

/// Each gate stands in for a share that stopped answering.
@Suite
@MainActor
struct GhosttyLinkClicksTests {
  private func click(_ text: String, isHyperlink: Bool = false) -> GhosttyClickedLink {
    GhosttyClickedLink(
      text: text,
      directory: URL(filePath: "/unused"),
      isHyperlink: isHyperlink,
    )
  }

  private func inEditor(_ text: String) -> GhosttyLinkRule.Opening {
    .inEditor(URL(filePath: "/\(text)"))
  }

  @Test func aClickJudgedSlowlyHoldsBackNoLaterClickAndIsDroppedWhenItAnswers() async throws {
    let gate = DispatchSemaphore(value: 0)
    let slowAnswered = Mutex(false)
    let clicks = GhosttyLinkClicks { click in
      if click.text == "slow" {
        gate.wait()
        slowAnswered.withLock { $0 = true }
      }
      return .inEditor(URL(filePath: "/\(click.text)"))
    }
    var acted: [GhosttyLinkRule.Opening?] = []

    clicks.judge(click("slow")) { acted.append($0) }
    clicks.judge(click("fast")) { acted.append($0) }
    try await waitUntil { acted == [inEditor("fast")] }
    gate.signal()
    try await waitUntil { slowAnswered.withLock { $0 } }
    clicks.judge(click("after")) { acted.append($0) }
    try await waitUntil { acted.count == 2 }

    #expect(acted == [inEditor("fast"), inEditor("after")])
  }

  @Test func aClickRepeatedWhileStillBeingJudgedIsJudgedOnceAndActsAsTheLatest() async throws {
    let gate = DispatchSemaphore(value: 0)
    let judged = Mutex(0)
    let clicks = GhosttyLinkClicks { click in
      if click.text == "stuck" {
        judged.withLock { $0 += 1 }
        gate.wait()
      }
      return .inEditor(URL(filePath: "/\(click.text)"))
    }
    var acted: [GhosttyLinkRule.Opening?] = []

    clicks.judge(click("stuck")) { acted.append($0) }
    clicks.judge(click("fast")) { acted.append($0) }
    try await waitUntil { acted == [inEditor("fast")] }
    clicks.judge(click("stuck")) { acted.append($0) }
    gate.signal()
    try await waitUntil { acted.count == 2 }

    #expect(judged.withLock { $0 } == 1)
    #expect(acted == [inEditor("fast"), inEditor("stuck")])
  }

  @Test func aClickAnsweredAfterALaterClickWasMadeOpensNothingThoughThatOneIsSlowerStill()
    async throws
  {
    let firstGate = DispatchSemaphore(value: 0)
    let secondGate = DispatchSemaphore(value: 0)
    let firstAnswered = Mutex(false)
    let clicks = GhosttyLinkClicks { click in
      if click.text == "first" {
        firstGate.wait()
        firstAnswered.withLock { $0 = true }
      } else {
        secondGate.wait()
      }
      return .inEditor(URL(filePath: "/\(click.text)"))
    }
    var acted: [GhosttyLinkRule.Opening?] = []

    clicks.judge(click("first")) { acted.append($0) }
    clicks.judge(click("second")) { acted.append($0) }
    firstGate.signal()
    try await waitUntil { firstAnswered.withLock { $0 } }
    secondGate.signal()
    try await waitUntil { !acted.isEmpty }

    #expect(acted == [inEditor("second")])
  }

  @Test func anOsc8ClickIsJudgedByTheHyperlinkRuleByDefault() async throws {
    let clicks = GhosttyLinkClicks()
    var acted: [GhosttyLinkRule.Opening?] = []

    clicks.judge(click("https://example.com", isHyperlink: true)) { acted.append($0) }
    try await waitUntil { !acted.isEmpty }

    #expect(acted == [nil])
  }
}
