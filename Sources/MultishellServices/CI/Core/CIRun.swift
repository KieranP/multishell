import Foundation
import MultishellCore

/// One CI run of a branch, its newest as the service lists them. Runtime
/// only; see Docs/develop/state-on-disk.md.
public struct CIRun: Hashable, Sendable, Identifiable {
  public let id: String
  /// The branch it ran on, by its name on the remote.
  public let branch: String
  /// The commit it ran, which may be one the local branch does not have yet.
  public let commit: String
  /// The commit's subject line, where the service says.
  public let subject: String?
  public let status: CIRunStatus
  /// Whether it has ended. A run can have failed, one job down, and still be
  /// running the rest; only an ended one stops changing.
  public let isFinished: Bool
  public let createdAt: Date?
  /// The repository it ran in, where the service says.
  public let repository: RemoteRepository?

  /// The commit as git abbreviates it, which is all 1.11 prints anyway.
  public var shortCommit: String { commit.abbreviatedCommit }

  /// Its phase's word, not its status's, which says failed while jobs still
  /// run; one on hold waits on a person, perhaps for days.
  public var isUnderWay: Bool { !isFinished && status != .onHold }

  init(
    id: String,
    branch: String,
    commit: String,
    subject: String?,
    status: CIRunStatus,
    isFinished: Bool,
    createdAt: Date?,
    repository: RemoteRepository? = nil,
  ) {
    self.id = id
    self.branch = branch
    self.commit = commit
    self.subject = subject
    self.status = status
    self.isFinished = isFinished
    self.createdAt = createdAt
    self.repository = repository
  }

  /// Whether it ran `commit`, which a provider may name by a prefix of it.
  public func ran(_ commit: String?) -> Bool {
    commit?.namesSameCommit(as: self.commit) ?? false
  }
}
