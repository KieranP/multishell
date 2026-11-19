import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct HandoffChoicesTests {
  private static let lint = HandoffCandidate(.check(name: "lint", link: nil, headCommit: "tip"))
  private static let danger = HandoffCandidate(
    .check(name: "danger", link: nil, headCommit: "tip"),
    startsChecked: false,
  )

  @Test func aFailingRequiredCheckStartsCheckedAndAnOptionalOneUnchecked() {
    let choices = HandoffChoices()

    #expect(choices.state(of: Self.lint) == .checked)
    #expect(choices.state(of: Self.danger) == .unchecked)
  }

  @Test func theStepsBoxIsMixedWhileSomeUnsentItemsAreChecked() {
    let choices = HandoffChoices()

    #expect(choices.groupState(of: [Self.lint, Self.danger]) == .mixed)
    #expect(choices.groupState(of: [Self.lint]) == .checked)
    #expect(choices.groupState(of: [Self.danger]) == .unchecked)
  }

  @Test func aClickOnAMixedStepBoxChecksEveryItemAndASecondUnchecksThem() {
    var choices = HandoffChoices()

    choices.toggleGroup([Self.lint, Self.danger])
    #expect(choices.groupState(of: [Self.lint, Self.danger]) == .checked)

    choices.toggleGroup([Self.lint, Self.danger])
    #expect(choices.groupState(of: [Self.lint, Self.danger]) == .unchecked)
  }

  @Test func aSentItemWearsTheAgentAndLeavesTheStepsBoxToTheUnsentOnes() {
    var choices = HandoffChoices()

    choices.markSent([Self.lint.id], to: "Claude Code")

    #expect(choices.state(of: Self.lint) == .sent(agentName: "Claude Code"))
    #expect(choices.groupState(of: [Self.lint, Self.danger]) == .unchecked)
    #expect(choices.groupState(of: [Self.lint]) == nil)
  }

  @Test func aStepToggleLeavesASentItemSent() {
    var choices = HandoffChoices()
    choices.markSent([Self.lint.id], to: "Claude Code")

    choices.toggleGroup([Self.lint, Self.danger])

    #expect(choices.state(of: Self.lint) == .sent(agentName: "Claude Code"))
    #expect(choices.state(of: Self.danger) == .checked)
  }

  @Test func aClickOnTheSentBubbleChecksTheItemToSendAgain() {
    var choices = HandoffChoices()
    choices.markSent([Self.danger.id], to: "Claude Code")

    choices.unmarkSent(Self.danger.id)

    #expect(choices.state(of: Self.danger) == .checked)
  }

  @Test func keepingOnlyWhatIsListedDropsThePicksAndMarksOfItemsGone() {
    var choices = HandoffChoices()
    choices.markSent([Self.lint.id], to: "Claude Code")
    choices.set(Self.danger.id, checked: true)

    choices.keepOnly([Self.danger.id], from: .checks)

    #expect(choices.state(of: Self.lint) == .checked)
    #expect(choices.state(of: Self.danger) == .checked)
  }
}
