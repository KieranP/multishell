import MultishellProcess

/// A request over the line the app reads, which it would drop unanswered.
struct ControlRequestTooLong: Error, CustomStringConvertible {
  let byteCount: Int

  var description: String {
    "the request is too long: \(byteCount) bytes, and Multishell reads "
      + "\(UnixSocketServer.maximumLineLength / 1024) KB at most; send long text in parts"
  }
}
