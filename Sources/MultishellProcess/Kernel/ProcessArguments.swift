/// The arguments `KERN_PROCARGS2` holds for one process, after its argc and
/// executable path. The environment after them is left unread: macOS hides it.
struct ProcessArguments: Equatable {
  let arguments: [String]

  /// `nil` for a buffer too short to hold a count and a path.
  init?(sysctlBuffer buffer: ArraySlice<UInt8>) {
    let countSize = MemoryLayout<Int32>.size
    guard buffer.count > countSize else { return nil }
    let argc = Int(buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
    let afterCount = buffer.dropFirst(countSize)
    // The path is padded with NULs to an alignment before the arguments.
    guard argc >= 0, let pathEnd = afterCount.firstIndex(of: 0),
      let argumentsStart = afterCount[pathEnd...].firstIndex(where: { $0 != 0 })
    else { return nil }
    arguments = afterCount[argumentsStart...]
      .split(separator: 0, maxSplits: argc, omittingEmptySubsequences: false)
      .prefix(argc)
      .map { String(decoding: $0, as: UTF8.self) }
  }
}
