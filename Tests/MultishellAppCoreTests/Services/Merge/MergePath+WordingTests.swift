import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct MergePathWordingTests {
  private static func titles(of path: MergePath) -> [String] {
    path.steps.map { path.title(of: $0, base: "main") }
  }

  private static func hints(of path: MergePath) -> [String] {
    path.steps.compactMap { path.hint(of: $0, base: "main", host: "GitHub") }
  }

  @Test func eachStepIsTitledByWhereItStands() {
    let path = MergePath.sample(
      .sample(state: .draft, review: .required, blocker: .behindBase),
      checks: [.sample(status: .failed)],
    )
    let rule = MergePath.sample(.sample(review: .approved, blocker: .blocked), checks: [])
    #expect(
      Self.titles(of: path)
        == [
          "Still a draft", "No conflicts with main", "Behind main", "Checks", "Waiting on a review",
        ]
    )
    #expect(
      Self.titles(of: rule) == ["No conflicts with main", "Review approved", "A rule on main"]
    )
  }

  @Test func conflictsNotYetWorkedOutAreSaidAsChecking() {
    let path = MergePath.sample(.sample(hasConflictAnswer: false), checks: [])
    #expect(Self.titles(of: path).first == "Checking for conflicts with main")
  }

  @Test func aStepThatNeedsTheUserSaysWhatFixesIt() {
    let path = MergePath.sample(.sample(state: .draft, blocker: .conflicts), checks: [])
    #expect(
      Self.hints(of: path)
        == ["Mark it ready for review on GitHub", "Merge main into this branch and push"]
    )
  }

  @Test func theChecksStepCountsTheRequiredAndTheOptionalThatFailed() {
    let path = MergePath.sample(
      .sample(),
      checks: [
        .sample(name: "test", status: .failed),
        .sample(name: "build", status: .passed),
        .sample(name: "unit", status: .running),
        .sample(name: "lint", status: .failed, isRequired: false),
      ],
    )
    #expect(
      Self.hints(of: path) == ["1 of 3 required passed, 1 failing, 1 running. 1 optional failed"]
    )
  }

  @Test func aRequiredCheckThatDidNotRunIsNamedApartFromThosePassed() {
    let path = MergePath.sample(
      .sample(),
      checks: [.sample(name: "build"), .sample(name: "deploy", status: .cancelled)],
    )
    #expect(Self.hints(of: path) == ["1 of 2 required passed, 1 not run"])
  }

  @Test func aRequiredCheckOnHoldOrUnknownIsNamedAsNotRun() {
    let path = MergePath.sample(
      .sample(),
      checks: [
        .sample(name: "deploy", status: .onHold), .sample(name: "scan", status: .unknown),
      ],
    )
    #expect(Self.hints(of: path) == ["0 of 2 required passed, 2 not run"])
  }

  @Test func checksWithNoneRequiredSayTheyAreNotRequired() {
    let path = MergePath.sample(.sample(), checks: [.sample(isRequired: false)])
    #expect(Self.hints(of: path) == ["None required"])
  }

  @Test func checksNotYetReadAreReadingUntilAReadFails() {
    let reading = MergePath.sample(.sample(), checks: nil)
    let failed = MergePath.sample(.sample(), checks: nil, checksReadProblem: "gh pr checks: 502")
    let step = MergePath.Step(kind: .checksNotRead, status: .running)
    #expect(reading.title(of: step, base: "main") == "Reading the checks")
    #expect(reading.hint(of: step, base: "main", host: "GitHub") == nil)
    #expect(reading.endHint(host: "GitHub") == "Once the checks are read")
    #expect(failed.title(of: step, base: "main") == "Checks not read")
    #expect(
      failed.hint(of: step, base: "main", host: "GitHub")
        == "Multishell reads again at the next poll. Last read: gh pr checks: 502"
    )
    #expect(failed.endHint(host: "GitHub") == "Once Multishell can read the checks")
  }

  @Test func aReadProblemEndingInAFullStopKeepsItsOwnAlone() {
    let path = MergePath.sample(
      .sample(),
      checks: nil,
      checksReadProblem: "It did not answer in time.",
    )
    let step = MergePath.Step(kind: .checksNotRead, status: .running)
    #expect(path.hint(of: step, base: "main", host: "GitHub")?.contains("..") == false)
  }

  @Test func theEndIsTitledAndHintedByWhatItOffers() {
    let ready = MergePath.sample(.sample(review: .approved), checks: [.sample()])
    let running = MergePath.sample(.sample(), checks: [.sample(status: .running)])
    let queued = MergePath.sample(.sample(autoMergesWhenReady: true), checks: [])
    let taken = MergePath.sample(.sample(), checks: [], isMergeTaken: true)
    let held = MergePath.sample(.sample(review: .required, blocker: .conflicts), checks: [])
    #expect(ready.endTitle(base: "main") == "Merge into main")
    #expect(ready.endHint(host: "GitHub") == nil)
    #expect(running.endTitle(base: "main") == "Merge when ready")
    #expect(
      running.endHint(host: "GitHub") == "Merges once the steps above clear, after you confirm"
    )
    #expect(queued.endTitle(base: "main") == "Merges into main by itself")
    #expect(queued.endHint(host: "GitHub") == "Once the steps above clear")
    #expect(
      taken.endHint(host: "GitHub") == "GitHub took the merge; the list shows it at the next read"
    )
    #expect(held.endHint(host: "GitHub") == "2 steps above to clear first")
  }

  @Test func aSettledPullRequestEndsOnWhatBecameOfIt() {
    let closed = MergePath.sample(.sample(state: .closed), checks: [])
    let outgrown = MergePath.sample(.sample(state: .merged), checks: [], isOutgrown: true)
    let merged = MergePath.sample(.sample(state: .merged), checks: [])
    #expect(closed.endTitle(base: "main") == "Closed without merging")
    #expect(
      closed.endHint(host: "GitHub") == "Open a new one, or reopen it on GitHub where it allows"
    )
    #expect(outgrown.endHint(host: "GitHub") == "Open a new pull request for the commits since")
    #expect(merged.endTitle(base: "main") == "Merged into main")
    #expect(merged.endHint(host: "GitHub") == nil)
  }
}
