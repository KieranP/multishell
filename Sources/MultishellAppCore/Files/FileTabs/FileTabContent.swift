import MultishellGitKit

/// What a file tab shows in place of rows, or the rows themselves.
public enum FileTabContent: Equatable, Sendable {
  /// Not text: a zero byte early on, an encoding nothing reads, or git calls
  /// it binary.
  case binary(bytes: Int)
  /// Neither on disk nor in `HEAD`.
  case missing
  /// A hidden tab's rows let go, keeping the dot they gave; read again when
  /// shown, so content nobody sees holds no memory.
  case released(changeKind: StatusChange.Kind?)
  /// The same for a file that came back while hidden: its kept rows are no
  /// diff of what came back, so the dot follows the status as it reads.
  case releasedFollowingStatus
  case text(FileTabRows)
  /// Past `FileTabReader.sizeLimit`, on disk or in `HEAD`.
  case tooLarge(bytes: Int)

  /// Rows let go while hidden, either way.
  var isReleased: Bool {
    switch self {
    case .released, .releasedFollowingStatus: true
    case .binary, .missing, .text, .tooLarge: false
    }
  }
}
