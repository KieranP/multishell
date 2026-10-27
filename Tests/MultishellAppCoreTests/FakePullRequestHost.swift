import Foundation
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
  }

  private let state = Mutex(State())
  private let heldReads = AsyncStream<Void>.makeStream()

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
