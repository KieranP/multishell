import Foundation
import Testing

@testable import MultishellServices

@Suite
struct CircleCIRunRecordTests {
  @Test func eachBranchRunReadsWithItsCommitSubjectStatusAndTime() throws {
    let runs = try CircleCIRunRecord.runs(from: Data(CircleCIFixtures.runList.utf8))

    #expect(runs.map(\.branch) == ["issue-8", "main", "spike/kitty-keys"])
    #expect(runs.map(\.status) == [.passed, .failed, .cancelled])
    #expect(runs[0].id == "58596572-0000-4000-8000-000000000001")
    #expect(runs[0].commit == "aaa1111", "the short form CircleCI prints")
    #expect(runs[0].repository == RemoteRepository(owner: "acme", name: "app"))
    #expect(runs[0].subject == "Read the pull request")
    #expect(runs[0].createdAt == Date(timeIntervalSince1970: 1_793_063_100))
    #expect(runs.map(\.isFinished) == [true, true, true])
  }

  /// Go encodes an empty list it never made as `null`.
  @Test func aNullListIsNoRuns() throws {
    #expect(try CircleCIRunRecord.runs(from: Data("null\n".utf8)) == [])
  }

  @Test func aRunIsUnderWayUntilItsPhaseEndsThoughOneJobHasFailed() throws {
    let json = "[\(CircleCIFixtures.run(id: "a", phase: "running", currentOutcome: "failing"))]"
    let run = try #require(try CircleCIRunRecord.runs(from: Data(json.utf8)).first)
    #expect(run.status == .failed, "said as soon as one job fails")
    #expect(!run.isFinished)
  }

  @Test func aTagRunAndARunOfAnUnknownStatusAreLeftOut() throws {
    let json = """
      [\(CircleCIFixtures.run(id: "a", branch: nil)),
       \(CircleCIFixtures.run(id: "b", currentOutcome: "mystery")),
       \(CircleCIFixtures.run(id: "c"))]
      """
    #expect(try CircleCIRunRecord.runs(from: Data(json.utf8)).map(\.id) == ["c"])
  }

  @Test func aTimeThatWillNotParseCostsTheTimeAlone() throws {
    let json = "[\(CircleCIFixtures.run(id: "a", createdAt: "yesterday"))]"
    let run = try #require(try CircleCIRunRecord.runs(from: Data(json.utf8)).first)
    #expect(run.createdAt == nil)
  }

  @Test func aRunsWorkflowsListTheirNamedJobsInOrderWithTheirIds() throws {
    let workflows = try CircleCIRunRecord.workflows(from: Data(CircleCIFixtures.runGet.utf8))

    #expect(workflows.map(\.name) == ["prep_and_test"])
    #expect(workflows[0].status == .failed)
    #expect(
      workflows[0].jobs == [
        CIJob(id: "eb605493-0000-4000-8000-000000000001", name: "prep", status: .passed),
        CIJob(id: "0c137413-0000-4000-8000-000000000002", name: "playwright", status: .failed),
        CIJob(id: "63084dd4-0000-4000-8000-000000000003", name: "vitest", status: .passed),
      ]
    )
  }

  @Test func outputThatIsNotJsonFailsTheRead() {
    #expect(throws: ServiceReadFailure.self) {
      try CircleCIRunRecord.runs(from: Data("Error: not logged in".utf8))
    }
  }

  @Test func aJobOfAnUnknownStatusIsLeftOutRatherThanCalledRunning() throws {
    let json = """
      {"id":"r","phase":"ended","current_outcome":"succeeded","branch":"main","revision":"aaa1111",\
      "workflows":[{"name":"build","phase":"ended","outcome":"succeeded","jobs":[\
      {"id":"1","name":"test","phase":"ended","outcome":"succeeded"},\
      {"id":"2","name":"new-kind","phase":"ended","outcome":"mystery"}]}]}
      """
    let workflows = try CircleCIRunRecord.workflows(from: Data(json.utf8))
    #expect(workflows.first?.jobs.map(\.name) == ["test"])
  }
}
