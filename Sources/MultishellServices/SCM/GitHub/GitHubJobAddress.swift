import Foundation

/// An Actions job from a check's link, `…/<owner>/<repo>/actions/runs/<run>/job/<job>`;
/// a check from any other CI links elsewhere.
struct GitHubJobAddress: Equatable {
  let host: String
  private let repository: RemoteRepository
  private let jobID: String

  var logsEndpoint: String {
    "repos/\(repository.owner)/\(repository.name)/actions/jobs/\(jobID)/logs"
  }

  init?(_ url: URL) {
    guard let path = GitHubRepositoryPath(url), path.pageParts.count >= 5,
      path.pageParts[0] == "actions", path.pageParts[1] == "runs", path.pageParts[3] == "job",
      UInt64(path.pageParts[4]) != nil
    else { return nil }
    host = path.host
    repository = path.repository
    jobID = path.pageParts[4]
  }
}
