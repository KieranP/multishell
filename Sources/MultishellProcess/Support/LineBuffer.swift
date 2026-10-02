/// Bytes from another process cut into newline-ended lines, a line split
/// across reads held until its end arrives. Bytes that are not UTF-8 decode lossily.
public struct LineBuffer: Sendable {
  private var pending: [UInt8] = []

  public init() {}

  var pendingByteCount: Int { pending.count }

  /// The lines `bytes` completes, each without its newline.
  public mutating func append(_ bytes: some Sequence<UInt8>) -> [String] {
    pending.append(contentsOf: bytes)
    var lines: [String] = []
    while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
      lines.append(String(decoding: pending[..<newline], as: UTF8.self))
      pending.removeSubrange(...newline)
    }
    return lines
  }

  /// What follows the last newline, `nil` where nothing does; the buffer is
  /// left empty.
  mutating func takeRest() -> String? {
    guard !pending.isEmpty else { return nil }
    defer { pending.removeAll() }
    return String(decoding: pending, as: UTF8.self)
  }
}
