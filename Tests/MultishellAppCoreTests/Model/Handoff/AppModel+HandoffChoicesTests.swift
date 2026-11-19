import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@MainActor
@Suite
struct AppModelHandoffChoicesTests {
  private static let lint = HandoffCandidate(.check(name: "lint", link: nil, headCommit: "tip"))
  private static let danger = HandoffCandidate(
    .check(name: "danger", link: nil, headCommit: "tip"),
    startsChecked: false,
  )

  @Test func aCollapsedListSaysHowManyOfItsItemsSendCarries() {
    let harness = Harness()

    let text = harness.model.handoffToSendText(
      of: [Self.lint, Self.danger],
      isCollapsed: true,
      in: harness.main.id,
    )

    #expect(text == "1 to send")
  }

  @Test func anOpenListOrOneWithNothingCheckedSaysNothing() {
    let harness = Harness()

    let open = harness.model.handoffToSendText(
      of: [Self.lint],
      isCollapsed: false,
      in: harness.main.id,
    )
    let unchecked = harness.model.handoffToSendText(
      of: [Self.danger],
      isCollapsed: true,
      in: harness.main.id,
    )

    #expect(open == nil)
    #expect(unchecked == nil)
  }
}
