import Foundation
import MultishellProcess
import Synchronization

@testable import MultishellServices

/// A pull request host answering from a list the test sets, recording each
/// call by what it asked.
final class FakePullRequestHost: PullRequestHost {
  private struct State {
    var answer: Result<[PullRequest], ServiceReadFailure> = .success([])
    var checks: [PullRequestCheck] = []
    var calls: [String] = []
    var holdsList = false
    var holdsChecks = false
    var holdsToolStatus = false
    var mergeOptions: Result<PullRequestMergeOptions, ServiceReadFailure>?
    var mergeFailure: ProcessFailure?
    var holdsMerges = false
    var holdsMergeOptions = false
    var heldOptionsReads: [AsyncStream<Void>.Continuation] = []
  }

  private let state = Mutex(State())
  private let heldReads = AsyncStream<Void>.makeStream()
  private let heldWrites = AsyncStream<Void>.makeStream()

  var calls: [String] { state.withLock { $0.calls } }

  func answer(_ answer: Result<[PullRequest], ServiceReadFailure>) {
    state.withLock { $0.answer = answer }
  }

  /// Every list read waits, as a hung `gh` would, until `releaseHeldReads`.
  func holdList() {
    state.withLock { $0.holdsList = true }
  }

  func holdChecks() {
    state.withLock { $0.holdsChecks = true }
  }

  func releaseHeldReads() {
    heldReads.continuation.finish()
  }

  func pullRequests(in directory: URL) async throws -> [PullRequest] {
    let holds = state.withLock { state in
      state.calls.append("list")
      return state.holdsList
    }
    if holds {
      for await _ in heldReads.stream {}
    }
    return try state.withLock { try $0.answer.get() }
  }

  func answerChecks(_ checks: [PullRequestCheck]) {
    state.withLock { $0.checks = checks }
  }

  func checks(of pullRequest: PullRequest, in directory: URL) async throws -> [PullRequestCheck] {
    let holds = state.withLock { state in
      state.calls.append("checks #\(pullRequest.number)")
      return state.holdsChecks
    }
    if holds {
      for await _ in heldReads.stream {}
    }
    return state.withLock { $0.checks }
  }

  func open(_ pullRequest: PullRequest, in directory: URL) async throws {
    state.withLock { $0.calls.append("open #\(pullRequest.number)") }
  }

  func openNewPullRequest(
    head: String,
    in headRepository: RemoteRepository?,
    base: String,
    directory: URL,
  ) async throws {
    let owner = headRepository.map { "\($0.owner):" } ?? ""
    state.withLock { $0.calls.append("create \(owner)\(head) into \(base)") }
  }

  func answerMergeOptions(_ options: Result<PullRequestMergeOptions, ServiceReadFailure>) {
    state.withLock { $0.mergeOptions = options }
  }

  /// Every merge after this fails as `gh` would, with `message` on stderr.
  func failMerges(saying message: String) {
    state.withLock { state in
      state.mergeFailure = ProcessFailure(
        executable: "gh",
        arguments: ["pr", "merge"],
        status: 1,
        message: message,
      )
    }
  }

  /// Every merge and auto-merge cancelling waits, as one on a slow network
  /// would, until `releaseHeldWrites`.
  func holdMerges() {
    state.withLock { $0.holdsMerges = true }
  }

  func releaseHeldWrites() {
    heldWrites.continuation.finish()
  }

  /// Each options read answers what was set as it began, once
  /// `releaseMergeOptionsRead` lets that one go, in the order they began.
  func holdMergeOptions() {
    state.withLock { $0.holdsMergeOptions = true }
  }

  func releaseMergeOptionsRead(_ index: Int) {
    state.withLock { $0.heldOptionsReads[index].finish() }
  }

  func mergeOptions(
    of pullRequest: PullRequest,
    in directory: URL,
  ) async throws -> PullRequestMergeOptions {
    let held = AsyncStream<Void>.makeStream()
    let (answer, holds) = state.withLock { state in
      state.calls.append("merge options #\(pullRequest.number)")
      if state.holdsMergeOptions { state.heldOptionsReads.append(held.continuation) }
      return (state.mergeOptions, state.holdsMergeOptions)
    }
    if holds {
      for await _ in held.stream {}
    }
    guard let answer else { throw ServiceReadFailure.failed("no merge options set") }
    return try answer.get()
  }

  func merge(
    _ pullRequest: PullRequest,
    as merge: PullRequestMerge,
    in directory: URL,
  ) async throws {
    let message = merge.message.map { " \($0.subject)|\($0.body)" } ?? ""
    let auto = merge.waitsForChecks ? " auto" : ""
    let (holds, failure) = state.withLock { state in
      state.calls.append(
        "merge #\(pullRequest.number) \(merge.method) at \(merge.headCommit)\(message)\(auto)"
      )
      return (state.holdsMerges, state.mergeFailure)
    }
    if holds {
      for await _ in heldWrites.stream {}
    }
    if let failure { throw failure }
  }

  func disableAutoMerge(of pullRequest: PullRequest, in directory: URL) async throws {
    let holds = state.withLock { state in
      state.calls.append("disable auto-merge #\(pullRequest.number)")
      return state.holdsMerges
    }
    if holds {
      for await _ in heldWrites.stream {}
    }
  }

  func holdToolStatus() {
    state.withLock { $0.holdsToolStatus = true }
  }

  func toolStatus() async -> ServiceToolStatus {
    if state.withLock({ $0.holdsToolStatus }) {
      for await _ in heldReads.stream {}
    }
    return .ready(version: "2.0.0", account: "tester")
  }
}
