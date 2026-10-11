struct UsageError: Error {
  let message: String
  /// The command whose help follows the message, the overview where `nil`.
  let topic: String?

  init(_ message: String, topic: String? = nil) {
    self.message = message
    self.topic = topic
  }
}
