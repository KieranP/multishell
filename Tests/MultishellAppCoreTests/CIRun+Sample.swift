import Foundation

@testable import MultishellServices

extension CIRun {
  static func sample(
    id: String = "run",
    branch: String = "feat",
    commit: String = "tip",
    status: CIRunStatus = .passed,
    isFinished: Bool? = nil,
    repository: RemoteRepository? = nil,
    createdAt: Date? = nil,
  ) -> Self {
    CIRun(
      id: id,
      branch: branch,
      commit: commit,
      subject: nil,
      status: status,
      isFinished: isFinished ?? (status != .running && status != .onHold),
      createdAt: createdAt,
      repository: repository,
    )
  }
}
