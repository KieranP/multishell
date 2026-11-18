import Darwin

/// How many descriptors a process holds open: files, pipes and sockets alike.
public enum OpenDescriptorCount {
  /// Room past what the sizing call reported, for descriptors opened between
  /// the two calls; the list is cut, not overrun, if more appear.
  private static let headroom = 16

  /// `nil` for a process that has gone or is not ours to read.
  public static func of(_ pid: Int32) -> Int? {
    let stride = MemoryLayout<proc_fdinfo>.stride
    let reportedSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
    guard reportedSize > 0 else { return nil }
    var descriptors = [proc_fdinfo](
      repeating: proc_fdinfo(),
      count: Int(reportedSize) / stride + headroom,
    )
    let filledSize = descriptors.withUnsafeMutableBytes { buffer in
      proc_pidinfo(pid, PROC_PIDLISTFDS, 0, buffer.baseAddress, Int32(buffer.count))
    }
    return filledSize > 0 ? Int(filledSize) / stride : nil
  }
}
