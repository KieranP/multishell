import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct SharedSettingsCacheTests {
  private let project = Project(path: URL(fileURLWithPath: "/tmp/demo")).id

  @Test func aProjectNeverReadHasNothingAndItsFileCountsAsMoved() {
    let cache = SharedSettingsCache()
    #expect(cache[project] == nil)
    #expect(cache.problem(of: project) == nil)
    #expect(cache.hasRead(project) == false)
    #expect(cache.hasMoved(.distantPast, for: project), "a first read is never skipped")
  }

  @Test func aReadIsSkippedOnlyWhenTheStampMatchesTheOneRecorded() {
    var cache = SharedSettingsCache()
    let stamp = Date(timeIntervalSince1970: 1000)
    cache.note(SharedProjectSettings(branchPrefix: "team/"), stamp: stamp, for: project)

    #expect(cache.hasMoved(stamp, for: project) == false)
    #expect(cache.hasMoved(stamp.addingTimeInterval(1), for: project))
  }

  /// What the hook question turns on: the same file read twice must not
  /// count as a change, or every tick would ask again.
  @Test func noteReportsAChangeOnlyWhenTheSettingsThemselvesMove() {
    var cache = SharedSettingsCache()
    let shared = SharedProjectSettings(postCreateHook: "npm ci")

    let first = cache.note(shared, stamp: Date(timeIntervalSince1970: 1), for: project)
    let again = cache.note(shared, stamp: Date(timeIntervalSince1970: 2), for: project)
    let edited = cache.note(
      SharedProjectSettings(postCreateHook: "npm ci --force"),
      stamp: Date(timeIntervalSince1970: 3), for: project)

    #expect(first)
    #expect(again == false)
    #expect(edited)
  }

  /// A repository with no file is not a change on first sight, so a launch
  /// does not ask about projects that carry nothing.
  @Test func aFirstReadFindingNoFileIsNotAChange() {
    var cache = SharedSettingsCache()
    let changed = cache.note(nil, stamp: .distantPast, for: project)

    #expect(changed == false)
    #expect(cache.hasRead(project), "read, and found nothing")
  }

  @Test func aFileThatWillNotParseCostsTheSettingsAndIsLoggedOnce() {
    var cache = SharedSettingsCache()
    cache.note(SharedProjectSettings(branchPrefix: "team/"), stamp: .distantPast, for: project)

    let isNew = cache.note(problem: "bad json", stamp: Date(timeIntervalSince1970: 1), for: project)
    let repeated = cache.note(
      problem: "bad json", stamp: Date(timeIntervalSince1970: 2), for: project)

    #expect(isNew)
    #expect(cache[project] == nil, "the project keeps its own settings, not the file's")
    #expect(cache.problem(of: project) == "bad json")
    #expect(repeated == false, "the same unparsable file is logged once, not on every tick")
  }

  @Test func aFileThatParsesAgainClearsTheProblem() {
    var cache = SharedSettingsCache()
    cache.note(problem: "bad json", stamp: .distantPast, for: project)
    cache.note(SharedProjectSettings(branchPrefix: "team/"), stamp: .now, for: project)

    #expect(cache.problem(of: project) == nil)
    #expect(cache[project]?.branchPrefix == "team/")
  }

  /// All three facts leave together, so a project re-added reads its file
  /// afresh rather than answering from what the last run found.
  @Test func forgettingAProjectTakesEveryFactWithIt() {
    var cache = SharedSettingsCache()
    cache.note(SharedProjectSettings(branchPrefix: "team/"), stamp: .now, for: project)
    cache.note(problem: "bad json", stamp: .now, for: project)

    cache.forget(project)

    #expect(cache[project] == nil)
    #expect(cache.problem(of: project) == nil)
    #expect(cache.hasRead(project) == false)
    #expect(cache.hasMoved(.distantPast, for: project))
  }
}
