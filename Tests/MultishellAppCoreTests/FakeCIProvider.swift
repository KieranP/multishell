import Foundation
import Synchronization

@testable import MultishellServices

/// A CI provider answering from runs the test sets, recording each call.
final class FakeCIProvider: CIProvider {
  private struct State {
    var recent: [CIRun] = []
    var byBranch: [String: CIRun] = [:]
    var workflows: [CIWorkflow] = []
    var history: [CIRun] = []
    var failsHistory = false
    var failingBranches: Set<String> = []
    var recentFailure: ServiceReadFailure?
    var canRead = true
    var holdsRecent = false
    var holdsWorkflows = false
    var holdsReports = false
    var calls: [String] = []
  }

  let configurationPath = ".fake-ci.yml"
  private let state = Mutex(State())
  private let heldReads = AsyncStream<Void>.makeStream()

  var calls: [String] { state.withLock { $0.calls } }

  func answer(
    recent: [CIRun],
    byBranch: [String: CIRun] = [:],
    workflows: [CIWorkflow] = [],
    history: [CIRun] = [],
  ) {
    state.withLock { state in
      state.recent = recent
      state.byBranch = byBranch
      state.workflows = workflows
      state.history = history
    }
  }

  func failRecent(_ failure: ServiceReadFailure) {
    state.withLock { $0.recentFailure = failure }
  }

  func holdRecent() {
    state.withLock { $0.holdsRecent = true }
  }

  func recentRuns(in directory: URL) async throws -> [CIRun] {
    let holds = state.withLock { state in
      state.calls.append("recent")
      return state.holdsRecent
    }
    if holds {
      for await _ in heldReads.stream {}
    }
    return try state.withLock { state in
      if let failure = state.recentFailure { throw failure }
      return state.recent
    }
  }

  func failHistory() {
    state.withLock { $0.failsHistory = true }
  }

  func failLookUp(ofBranch branch: String) {
    state.withLock { _ = $0.failingBranches.insert(branch) }
  }

  func runs(onBranch branch: String, limit: Int, in directory: URL) async throws -> [CIRun] {
    try state.withLock { state in
      state.calls.append(limit == 1 ? "branch \(branch)" : "history \(branch)")
      if limit > 1, state.failsHistory { throw ServiceReadFailure.failed("offline") }
      if limit == 1, state.failingBranches.contains(branch) {
        throw ServiceReadFailure.failed("offline")
      }
      return limit == 1 ? state.byBranch[branch].map { [$0] } ?? [] : state.history
    }
  }

  func holdReports() {
    state.withLock { $0.holdsReports = true }
  }

  func failureReport(of run: CIRun, in directory: URL) async throws -> CIFailureReport {
    let holds = state.withLock { state in
      state.calls.append("report \(run.id)")
      return state.holdsReports
    }
    if holds {
      for await _ in heldReads.stream {}
    }
    return CIFailureReport(excerpts: [
      CIFailureExcerpt(workflow: "build", job: "test-macos", text: "test-macos failed")
    ])
  }

  /// Every workflows read waits, as a slow `circleci` would, until released.
  func holdWorkflows() {
    state.withLock { $0.holdsWorkflows = true }
  }

  func releaseHeldReads() {
    heldReads.continuation.finish()
  }

  func workflows(of run: CIRun, in directory: URL) async throws -> [CIWorkflow] {
    let holds = state.withLock { state in
      state.calls.append("workflows \(run.id)")
      return state.holdsWorkflows
    }
    if holds {
      for await _ in heldReads.stream {}
    }
    return state.withLock { $0.workflows }
  }

  func openJob(id: String, in directory: URL) async throws {
    state.withLock { $0.calls.append("open job \(id)") }
  }

  func openRuns(onBranch branch: String, in directory: URL) async throws {
    state.withLock { $0.calls.append("open \(branch)") }
  }

  func refuseReads() {
    state.withLock { $0.canRead = false }
  }

  func allowReads() {
    state.withLock { $0.canRead = true }
  }

  func canRead() async -> Bool {
    state.withLock { $0.canRead }
  }

  func toolStatus() async -> ServiceToolStatus {
    .ready(version: "1.0.0", account: nil)
  }
}
