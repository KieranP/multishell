import MultishellProcess

/// A request over the line the app reads, which it would drop unanswered.
struct ControlRequestTooLong: Error, CustomStringConvertible {
  let byteCount: Int
  /// What gets under the limit, which only text typed or pasted can be sent in parts for.
  var advice = "send long text in parts"

  var description: String {
    "the request is too long: \(byteCount) bytes, and Multishell reads "
      + "\(UnixSocketServer.maximumLineLength / 1024) KB at most; \(advice)"
  }
}
