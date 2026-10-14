import Foundation

extension UnixSocket {
  /// Every byte, a full buffer waited out in the deadline's `poll` or, with none,
  /// in a blocking write. Renewed on progress, it bounds a stall, not the whole.
  static func write(
    _ bytes: [UInt8],
    to descriptor: Int32,
    until deadline: SocketDeadline?,
    renewingOnProgress: Bool = false,
  ) throws(SocketWriteFailure) {
    var deadline = deadline
    var written = 0
    while written < bytes.count {
      let count = bytes[written...].withUnsafeBufferPointer { buffer in
        Darwin.write(descriptor, buffer.baseAddress, buffer.count)
      }
      if count >= 0 {
        written += count
        if count > 0, renewingOnProgress, let previous = deadline {
          deadline = SocketDeadline(after: previous.timeout)
        }
        continue
      }
      if errno == EINTR { continue }
      guard let deadline, errno == EAGAIN || errno == EWOULDBLOCK else {
        throw .system(code: errno)
      }
      guard deadline.waitUntil(descriptor, isReadyFor: POLLOUT) else {
        throw .timedOut(after: deadline.timeout)
      }
    }
  }
}
