@testable import MultishellGitKit

extension DefaultBranch {
  public static func sample(
    _ name: String,
    remote: String? = nil,
    tip: String = "abc",
  ) -> DefaultBranch {
    guard let remote else {
      return DefaultBranch(
        shortName: name,
        nameWithoutRemote: name,
        tip: tip,
        fullName: "refs/heads/\(name)",
      )
    }
    return DefaultBranch(
      shortName: "\(remote)/\(name)",
      nameWithoutRemote: name,
      tip: tip,
      fullName: "refs/remotes/\(remote)/\(name)",
    )
  }
}
