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
    var checksFailure: ServiceReadFailure?
    var headCommit: String?
    var calls: [String] = []
    var branchAnswers: [String: Result<[PullRequest], ServiceReadFailure>] = [:]
    var askedBranches: [String] = []
    var holdsList = false
    var holdsChecks = false
    var holdsToolStatus = false
    var mergeOptions: Result<PullRequestMergeOptions, ServiceReadFailure>?
    var mergeFailure: ProcessFailure?
    var holdsMerges = false
    var holdsMergeOptions = false
    var heldOptionsReads: [AsyncStream<Void>.Continuation] = []
    var renamedRepositories: [String: RemoteRepository] = [:]
    var askedRemoteURLs: [String] = []
    var repositoryFailures: [ServiceReadFailure] = []
    var logs: [URL: Result<String, ServiceReadFailure>] = [:]
    var threads: Result<[PullRequestThread], ServiceReadFailure> = .success([])
    var holdsLogs = false
    var holdsThreads = false
  }

  private let state = Mutex(State())
  private let heldReads = AsyncStream<Void>.makeStream()
  private let heldWrites = AsyncStream<Void>.makeStream()

  var calls: [String] { state.withLock { $0.calls } }
  /// Each remote URL asked which repository it names, apart from `calls`.
  var askedRemoteURLs: [String] { state.withLock { $0.askedRemoteURLs } }
  /// Each branch asked alone, apart from `calls`, which count the list reads.
  var askedBranches: [String] { state.withLock { $0.askedBranches } }

  func answer(_ answer: Result<[PullRequest], ServiceReadFailure>) {
    state.withLock { $0.answer = answer }
  }

  /// Every list read waits, as a hung `gh` would, until `releaseHeldReads`.
  func holdList() {
    state.withLock { $0.holdsList = true }
  }

  /// The head a pull request has moved to since the list was read.
  func answerHeadCommit(_ commit: String) {
    state.withLock { $0.headCommit = commit }
  }

  func holdChecks() {
    state.withLock { $0.holdsChecks = true }
  }

  func releaseHeldReads() {
    heldReads.continuation.finish()
  }

  /// The host answers `repository` for `remoteURL`, as GitHub does after a rename.
  func rename(_ remoteURL: String, to repository: RemoteRepository) {
    state.withLock { $0.renamedRepositories[remoteURL] = repository }
  }

  /// The next asks fail in turn, as a timed-out or logged-out `gh` would.
  func failRepositoryAsks(_ failures: [ServiceReadFailure]) {
    state.withLock { $0.repositoryFailures = failures }
  }

  func repository(namedBy remoteURL: String, in directory: URL) async throws -> RemoteRepository {
    try state.withLock { state in
      state.askedRemoteURLs.append(remoteURL)
      if !state.repositoryFailures.isEmpty { throw state.repositoryFailures.removeFirst() }
      if let renamed = state.renamedRepositories[remoteURL] { return renamed }
      guard let named = RemoteRepository(remoteURL: remoteURL) else {
        throw ServiceReadFailure.notHosted
      }
      return named
    }
  }

  /// A branch with no answer set heads none.
  func answer(branch: String, _ answer: Result<[PullRequest], ServiceReadFailure>) {
    state.withLock { $0.branchAnswers[branch] = answer }
  }

  func pullRequests(headedBy branch: String, in directory: URL) async throws -> [PullRequest] {
    try state.withLock { state in
      state.askedBranches.append(branch)
      return try (state.branchAnswers[branch] ?? .success([])).get()
    }
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

  /// Every check read fails as `failure`, as a logged-out `gh` would.
  func failChecks(_ failure: ServiceReadFailure) {
    state.withLock { $0.checksFailure = failure }
  }

  func checks(of pullRequest: PullRequest, in directory: URL) async throws -> [PullRequestCheck] {
    let holds = state.withLock { state in
      state.calls.append("checks #\(pullRequest.number)")
      return state.holdsChecks
    }
    if holds {
      for await _ in heldReads.stream {}
    }
    return try state.withLock { state in
      if let failure = state.checksFailure { throw failure }
      return state.checks
    }
  }

  /// A check whose link has no log set is from another CI, and has none.
  func answerLog(of link: URL, _ answer: Result<String, ServiceReadFailure>) {
    state.withLock { $0.logs[link] = answer }
  }

  /// Every log read waits, as a slow `gh` would, until `releaseHeldReads`.
  func holdLogs() {
    state.withLock { $0.holdsLogs = true }
  }

  func readsFailedLog(of check: PullRequestCheck, on pullRequest: PullRequest) -> Bool {
    state.withLock { state in check.link.flatMap { state.logs[$0] } != nil }
  }

  func failedLog(
    of check: PullRequestCheck,
    on pullRequest: PullRequest,
    keepingLast lineLimit: Int,
    in directory: URL,
  ) async throws -> FailedCheckLog? {
    let holds = state.withLock { state in
      state.calls.append("log \(check.name)")
      return state.holdsLogs
    }
    if holds {
      for await _ in heldReads.stream {}
    }
    return try state.withLock { state in
      try check.link.flatMap { state.logs[$0] }?.get()
    }
    .map { FailedCheckLog(text: $0, earlierLineCount: 0) }
  }

  func answerThreads(_ answer: Result<[PullRequestThread], ServiceReadFailure>) {
    state.withLock { $0.threads = answer }
  }

  /// Every thread read waits until `releaseHeldReads`.
  func holdThreads() {
    state.withLock { $0.holdsThreads = true }
  }

  func unresolvedThreads(
    of pullRequest: PullRequest,
    in directory: URL,
  ) async throws -> [PullRequestThread] {
    let holds = state.withLock { state in
      state.calls.append("threads #\(pullRequest.number)")
      return state.holdsThreads
    }
    if holds {
      for await _ in heldReads.stream {}
    }
    return try state.withLock { try $0.threads.get() }
  }

  func headCommit(of pullRequest: PullRequest, in directory: URL) async throws -> String {
    state.withLock { $0.headCommit } ?? pullRequest.headCommit
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
