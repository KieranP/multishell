/// One row of a file tab: a line of the file on disk, or one `HEAD` had that
/// the file no longer does.
public struct DiffLine: Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    case added
    case context
    /// A split side's empty row across from a change on the other side.
    case padding
    case removed
  }

  static let padding = Self(kind: .padding, oldNumber: nil, newNumber: nil, text: "")

  public let kind: Kind
  /// The change is in the index as well as on disk, drawn hollow in the gutter.
  public let isStaged: Bool
  /// In `HEAD`; `nil` for an added line.
  public let oldNumber: Int?
  /// In the file on disk; `nil` for a removed line, which has none to show.
  public let newNumber: Int?
  /// Without its line ending, a CRLF's `\r` dropped with it.
  public let text: String
  /// The words it differs in from the line it replaced or that replaced it,
  /// in UTF-16 units of `text`.
  public let changedParts: [Range<Int>]

  public var isChange: Bool { kind == .added || kind == .removed }

  init(
    kind: Kind,
    oldNumber: Int?,
    newNumber: Int?,
    text: String,
    isStaged: Bool = false,
    changedParts: [Range<Int>] = [],
  ) {
    self.kind = kind
    self.isStaged = isStaged
    self.oldNumber = oldNumber
    self.newNumber = newNumber
    self.text = text
    self.changedParts = changedParts
  }

  /// The line's number in that side's file.
  public func number(on side: DiffSide) -> Int? {
    side == .committed ? oldNumber : newNumber
  }

  func staged() -> Self {
    Self(
      kind: kind,
      oldNumber: oldNumber,
      newNumber: newNumber,
      text: text,
      isStaged: true,
      changedParts: changedParts,
    )
  }

  func marking(changedParts: [Range<Int>]) -> Self {
    Self(
      kind: kind,
      oldNumber: oldNumber,
      newNumber: newNumber,
      text: text,
      isStaged: isStaged,
      changedParts: changedParts,
    )
  }
}
