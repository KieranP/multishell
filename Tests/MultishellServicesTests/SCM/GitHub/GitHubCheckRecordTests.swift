import Foundation
import Testing

@testable import MultishellServices

@Suite
struct GitHubCheckRecordTests {
  /// `gh pr checks 3` on this repository: a rerun's `test` beside the run it replaced.
  private let rerun = """
    [{"bucket":"fail","description":"","link":"https://github.com/KieranP/multishell/actions/runs/39731994397/job/119668904437","name":"test","state":"FAILURE","workflow":"CI"},\
    {"bucket":"pass","description":"","link":"https://github.com/KieranP/multishell/actions/runs/39731994397/job/119668904259","name":"lint","state":"SUCCESS","workflow":"CI"},\
    {"bucket":"pass","description":"","link":"https://github.com/KieranP/multishell/actions/runs/39731990771/job/119668892232","name":"test","state":"SUCCESS","workflow":"CI"},\
    {"bucket":"pass","description":"","link":"https://github.com/KieranP/multishell/actions/runs/39731990771/job/119668892423","name":"lint","state":"SUCCESS","workflow":"CI"}]
    """

  @Test func aRerunCheckIsListedOnceAsItsNewestRun() throws {
    let checks = try GitHubCheckRecord.checks(from: Data(rerun.utf8), required: [])

    #expect(checks.map(\.name) == ["test", "lint"], "in the order gh first listed them")
    #expect(checks[0].status == .failed, "the job with the higher number is the rerun")
    #expect(checks[0].workflow == "CI")
    #expect(
      checks[0].link
        == URL(
          string: "https://github.com/KieranP/multishell/actions/runs/39731994397/job/119668904437"
        )
    )
  }

  @Test func aCheckTheRequiredListNamesIsRequired() throws {
    let checks = try GitHubCheckRecord.checks(
      from: Data(rerun.utf8),
      required: [CheckKey(workflow: "CI", name: "lint")],
    )
    #expect(checks.map(\.isRequired) == [false, true])
  }

  @Test(arguments: [
    ("pass", CIRunStatus.passed), ("fail", .failed), ("pending", .running),
    ("skipping", .cancelled), ("cancel", .cancelled),
  ])
  func eachBucketReadsAsItsStatus(bucket: String, status: CIRunStatus) throws {
    let json = #"[{"name":"build","bucket":"\#(bucket)"}]"#
    #expect(
      try GitHubCheckRecord.checks(from: Data(json.utf8), required: []).first?.status == status
    )
  }

  @Test func aCheckOfAnUnknownBucketCostsItselfAlone() throws {
    let json = #"[{"name":"a","bucket":"mystery"},{"name":"b","bucket":"pass"}]"#
    #expect(try GitHubCheckRecord.checks(from: Data(json.utf8), required: []).map(\.name) == ["b"])
  }
}
