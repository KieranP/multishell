import MultishellGitKit

/// What a file tab shows in place of rows, or the rows themselves.
public enum FileTabContent: Equatable, Sendable {
  /// Not text: a zero byte early on, an encoding nothing reads, or git calls
  /// it binary.
  case binary(bytes: Int)
  /// A file whose name types it as an image and whose bytes decode as one.
  case image(FileTabImage)
  /// Neither on disk nor on the committed side.
  case missing
  /// A hidden tab's rows or image let go, keeping the dot they gave; read again
  /// when shown, so content nobody sees holds no memory.
  case released(changeKind: StatusChange.Kind?)
  /// The same for a file that came back while hidden: its kept rows are no
  /// diff of what came back, so the dot follows the status as it reads.
  case releasedFollowingStatus
  case text(FileTabRows)
  /// Past `FileTabReader.sizeLimit`, on disk or on the committed side.
  case tooLarge(bytes: Int)
  /// Git could not say what the file is counted from, nor any rows kept.
  case unreadable

  /// Drawn as a notice in place of rows, with no arrows or find bar.
  public var isNotice: Bool {
    switch self {
    case .binary, .missing, .tooLarge, .unreadable: true
    case .image, .released, .releasedFollowingStatus, .text: false
    }
  }

  /// A notice or an image, with no arrows or find bar over it.
  public var drawsNoRows: Bool {
    switch self {
    case .binary, .image, .missing, .tooLarge, .unreadable: true
    case .released, .releasedFollowingStatus, .text: false
    }
  }

  /// The file's rows or image, which a read git cannot place keeps.
  var showsTheFile: Bool {
    switch self {
    case .image, .text: true
    case .binary, .missing, .released, .releasedFollowingStatus, .tooLarge, .unreadable: false
    }
  }

  /// Already what a gone file's tab keeps: text with no removed rows, or the
  /// copy on disk alone.
  var isLastOnDisk: Bool {
    switch self {
    case .image(let image): image.onDisk != nil && image.committed == nil
    case .text(let rows): !rows.lines.contains { $0.kind == .removed }
    case .binary, .missing, .released, .releasedFollowingStatus, .tooLarge, .unreadable: false
    }
  }

  /// Rows let go while hidden, either way.
  var isReleased: Bool {
    switch self {
    case .released, .releasedFollowingStatus: true
    case .binary, .image, .missing, .text, .tooLarge, .unreadable: false
    }
  }

  /// What a tab keeps showing once its file goes, the text or copy it last read
  /// on disk; `nil` where it showed none.
  func lastOnDisk() -> Self? {
    switch self {
    case .image(let image): image.lastCopyOnDisk().map(Self.image)
    case .text(let rows): rows.holdsTextOnDisk ? .text(rows.lastTextOnDisk()) : nil
    case .binary, .missing, .released, .releasedFollowingStatus, .tooLarge, .unreadable: nil
    }
  }
}
