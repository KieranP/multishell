@testable import MultishellAppCore
@testable import MultishellGitKit

extension AllChangesReading {
  /// Each file read as `rows`, or with the content given, in the order given.
  static func sample(_ files: [(String, AllChangesFileContent)]) -> Self {
    let changes = files.map { path, _ in
      AllChangesFileChange(path: path, kind: .modified, lineCounts: nil)
    }
    return Self(
      listed: changes,
      files: zip(changes, files).map { change, file in
        AllChangesFile(change: change, content: file.1, signature: nil)
      },
    )
  }

  static func sample(rows files: [(String, FileTabRows)]) -> Self {
    sample(files.map { ($0.0, .read(FileTabReading(content: .text($0.1), isFileGone: false))) })
  }
}
