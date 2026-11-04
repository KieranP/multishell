@testable import MultishellGitKit

extension TrackedFiles {
  static func sample(
    paths: [String],
    submodulePaths: Set<String> = [],
    notCheckedOutPaths: Set<String> = [],
    isCapped: Bool = false,
  ) -> TrackedFiles {
    TrackedFiles(
      paths: paths,
      submodulePaths: submodulePaths,
      notCheckedOutPaths: notCheckedOutPaths,
      isCapped: isCapped,
    )
  }

  static func sample(count: Int) -> TrackedFiles {
    sample(paths: (0..<count).map { "src/file\($0).txt" })
  }
}
