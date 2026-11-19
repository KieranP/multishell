import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct MergePathStepItemsTests {
  private static let path = MergePath.sample(
    .sample(review: .changesRequested),
    checks: [.sample(name: "lint"), .sample(name: "test", status: .failed)],
    unresolvedThreadCount: 1,
  )

  private static func items(of kind: MergePath.Step.Kind) throws -> MergePathStepItems {
    let step = try #require(path.steps.first { $0.kind == kind })
    return MergePathStepItems(of: step, in: path, headCommit: "tip", threads: [.sample()])
  }

  @Test func theChecksStepCarriesItsFailingChecksAlone() throws {
    let items = try Self.items(of: .checks)

    #expect(items.checkCandidates.keys.map(\.name) == ["test"])
    #expect(items.threads.isEmpty)
    #expect(items.showsCheckSlot)
    #expect(items.collapsibleList == .checks)
  }

  @Test func theStepHoldingTheThreadsCarriesThemAndNoChecks() throws {
    let items = try Self.items(of: .review)

    #expect(items.threads.map(\.id) == ["t1"])
    #expect(items.candidates == [items.candidate(of: .sample())].compactMap(\.self))
    #expect(!items.showsCheckSlot)
    #expect(items.collapsibleList == .threads)
  }

  @Test func anyOtherStepCarriesNothing() throws {
    let items = try Self.items(of: .conflicts)

    #expect(items.candidates.isEmpty)
    #expect(items.collapsibleList == nil)
  }
}
