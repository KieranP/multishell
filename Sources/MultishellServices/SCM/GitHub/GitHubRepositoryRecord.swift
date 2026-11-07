import Foundation
import MultishellCore

/// `gh repo view <url> --json nameWithOwner`: the repository a remote's URL
/// names, under its current owner and name where it was renamed or moved.
struct GitHubRepositoryRecord: Decodable {
  static let fields = "nameWithOwner"

  let nameWithOwner: String?

  static func repository(from json: Data) throws -> RemoteRepository {
    let record = try ToolAnswer.decode(Self.self, from: json)
    guard let nameWithOwner = record.nameWithOwner,
      let slash = nameWithOwner.lastIndex(of: "/"),
      slash != nameWithOwner.startIndex,
      nameWithOwner.index(after: slash) != nameWithOwner.endIndex
    else {
      throw ServiceReadFailure.failed(t("integration.unreadable-answer"))
    }
    return RemoteRepository(
      owner: String(nameWithOwner[..<slash]),
      name: String(nameWithOwner[nameWithOwner.index(after: slash)...]),
    )
  }
}
