/// One file of the All changes tab: how the Changes list counts it and what
/// its read gave, if it was read.
public struct AllChangesFile: Equatable, Sendable {
  public let change: AllChangesFileChange
  public let content: AllChangesFileContent
  /// What the file looked like when read, `nil` for gone, so an event in its
  /// folder reads it again only where it moved.
  let signature: FileSignature?

  public var path: String { change.path }

  /// The file tab's reading of it, where it was read.
  public var reading: FileTabReading? {
    if case .read(let reading) = content { reading } else { nil }
  }

  /// The rows, where the read gave some.
  public var rows: FileTabRows? {
    guard case .text(let rows) = reading?.content else { return nil }
    return rows
  }
}
