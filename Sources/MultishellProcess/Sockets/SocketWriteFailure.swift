/// Why `UnixSocket.write` stopped short: the write failed with this `errno`, or
/// the deadline of this length passed while the reader was full.
enum SocketWriteFailure: Error {
  case system(code: Int32)
  case timedOut(after: Duration)
}
